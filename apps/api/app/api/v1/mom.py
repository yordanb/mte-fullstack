"""Minute of Meeting — meetings + agendas + action items CRUD."""
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.core.deps import get_current_user, require_role

router = APIRouter(prefix="/v1/mom", tags=["mom"])

CATS = ('Operasional', 'Safety', 'Maintenance', 'Project', 'Lainnya')


# ─── Models ───────────────────────────────────────────────

class MeetingIn(BaseModel):
    title: str
    meeting_date: date
    location: str | None = None
    category: str = 'Operasional'
    status: str = 'open'


class MeetingPatch(BaseModel):
    title: str | None = None
    meeting_date: date | None = None
    location: str | None = None
    category: str | None = None
    status: str | None = None


class AgendaIn(BaseModel):
    title: str
    discussion: str | None = None


class AgendaPatch(BaseModel):
    title: str | None = None
    discussion: str | None = None


class ItemIn(BaseModel):
    description: str
    pic: str | None = None
    due_date: date | None = None
    priority: str = 'medium'
    status: str = 'open'
    notes: str | None = None


class ItemPatch(BaseModel):
    description: str | None = None
    pic: str | None = None
    due_date: date | None = None
    priority: str | None = None
    status: str | None = None
    notes: str | None = None


class CopyMeetingIn(BaseModel):
    from_meeting_id: int
    title: str
    meeting_date: date
    location: str | None = None
    carry_open_items: bool = True


class CarryItemIn(BaseModel):
    target_agenda_id: int


# ─── Meetings ─────────────────────────────────────────────

@router.get("/meetings")
async def list_meetings(status: str | None = Query(None),
                        category: str | None = Query(None),
                        db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    """List semua meeting + jumlah item open."""
    conds, p = [], {}
    if status:
        conds.append("m.status = :st"); p["st"] = status
    if category:
        conds.append("m.category = :cat"); p["cat"] = category
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    rows = (await db.execute(text(f"""
        SELECT m.*,
               COUNT(i.id) AS total_items,
               COUNT(i.id) FILTER (WHERE i.status <> 'closed') AS open_items
        FROM mom_meetings m
        LEFT JOIN mom_items i ON i.meeting_id = m.id
        {where}
        GROUP BY m.id
        ORDER BY m.meeting_date DESC
    """), p)).mappings().all()
    return {"data": [dict(r) for r in rows]}


@router.post("/meetings", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def create_meeting(body: MeetingIn, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    if body.category not in CATS:
        raise HTTPException(400, f"Kategori harus salah satu {CATS}")
    if body.status not in ('open', 'closed'):
        raise HTTPException(400, "Status harus 'open' atau 'closed'")
    res = await db.execute(text("""
        INSERT INTO mom_meetings(title, meeting_date, location, category, status, created_by)
        VALUES (:t, :d, :loc, :cat, :st, :u) RETURNING id
    """), {"t": body.title.strip(), "d": body.meeting_date, "loc": body.location,
           "cat": body.category, "st": body.status, "u": user["username"]})
    mid = res.scalar_one()
    # Auto-create first agenda
    await db.execute(text("""
        INSERT INTO mom_agendas(meeting_id, seq, title) VALUES (:mid, 0, 'Agenda 1')
    """), {"mid": mid})
    await db.commit()
    return {"id": mid}


@router.get("/meetings/{mid}")
async def get_meeting(mid: int, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    m = (await db.execute(text("SELECT * FROM mom_meetings WHERE id=:id"), {"id": mid})).mappings().first()
    if not m:
        raise HTTPException(404, "Meeting tidak ditemukan")
    agendas = (await db.execute(text("""
        SELECT a.*, COUNT(i.id) AS total_items,
               COUNT(i.id) FILTER (WHERE i.status <> 'closed') AS open_items
        FROM mom_agendas a
        LEFT JOIN mom_items i ON i.agenda_id = a.id
        WHERE a.meeting_id = :mid
        GROUP BY a.id
        ORDER BY a.seq, a.id
    """), {"mid": mid})).mappings().all()
    items = (await db.execute(text("""
        SELECT * FROM mom_items WHERE meeting_id=:mid ORDER BY item_no, id
    """), {"mid": mid})).mappings().all()
    out = dict(m)
    out["agendas"] = [dict(a) for a in agendas]
    out["items"] = [dict(i) for i in items]
    return out


@router.patch("/meetings/{mid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def patch_meeting(mid: int, body: MeetingPatch, db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    allowed = ("title", "location", "category", "status")
    sets, p = [], {"id": mid}
    for k in allowed:
        v = getattr(body, k)
        if v is not None:
            if k == "category" and v not in CATS:
                raise HTTPException(400, "Kategori tidak valid")
            if k == "status" and v not in ('open', 'closed'):
                raise HTTPException(400, "Status tidak valid")
            sets.append(f"{k}=:{k}"); p[k] = v
    if body.meeting_date is not None:
        sets.append("meeting_date=:d"); p["d"] = body.meeting_date
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE mom_meetings SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Meeting tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/meetings/{mid}", dependencies=[Depends(require_role("admin"))])
async def delete_meeting(mid: int, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM mom_meetings WHERE id=:id"), {"id": mid})
    if res.rowcount == 0:
        raise HTTPException(404, "Meeting tidak ditemukan")
    await db.commit()
    return {"ok": True}


# ─── Copy / Previous / Carry ─────────────────────────────

@router.post("/meetings/copy", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def copy_meeting(body: CopyMeetingIn, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    """Salin meeting: buat meeting baru + copy agenda + optionally carry open items."""
    src = (await db.execute(text("SELECT * FROM mom_meetings WHERE id=:id"), {"id": body.from_meeting_id})).mappings().first()
    if not src:
        raise HTTPException(404, "Meeting sumber tidak ditemukan")
    # 1. Create new meeting
    res = await db.execute(text("""
        INSERT INTO mom_meetings(title, meeting_date, location, category, status, created_by)
        VALUES (:t, :d, :loc, :cat, 'open', :u) RETURNING id
    """), {"t": body.title.strip(), "d": body.meeting_date, "loc": body.location,
           "cat": src["category"], "u": user["username"]})
    new_mid = res.scalar_one()
    # 2. Copy agendas
    src_agendas = (await db.execute(text(
        "SELECT id, seq, title, discussion FROM mom_agendas WHERE meeting_id=:mid ORDER BY seq"), {"mid": body.from_meeting_id})).mappings().all()
    agenda_map = {}  # old_id → new_id
    for ag in src_agendas:
        r = await db.execute(text("""
            INSERT INTO mom_agendas(meeting_id, seq, title, discussion)
            VALUES (:mid, :seq, :t, :disc) RETURNING id
        """), {"mid": new_mid, "seq": ag["seq"], "t": ag["title"], "disc": None})  # discussion kosong untuk meeting baru
        agenda_map[ag["id"]] = r.scalar_one()
    # 3. Optionally carry open items
    if body.carry_open_items:
        open_items = (await db.execute(text("""
            SELECT * FROM mom_items WHERE meeting_id=:mid AND status <> 'closed' ORDER BY agenda_id, item_no
        """), {"mid": body.from_meeting_id})).mappings().all()
        for it in open_items:
            target_agenda = agenda_map.get(it["agenda_id"])
            if not target_agenda:
                continue
            max_no = (await db.execute(text(
                "SELECT COALESCE(MAX(item_no), 0) + 1 FROM mom_items WHERE meeting_id=:mid"), {"mid": new_mid})).scalar()
            await db.execute(text("""
                INSERT INTO mom_items(meeting_id, agenda_id, item_no, description, pic, due_date, priority, status, notes)
                VALUES (:mid, :aid, :no, :desc, :pic, :due, :pri, 'open', :notes)
            """), {"mid": new_mid, "aid": target_agenda, "no": max_no,
                   "desc": it["description"], "pic": it["pic"], "due": it["due_date"],
                   "pri": it["priority"], "notes": it["notes"]})
    await db.commit()
    return {"id": new_mid}


@router.get("/meetings/{mid}/previous")
async def get_previous_meeting(mid: int, db: AsyncSession = Depends(get_db),
                               user=Depends(get_current_user)):
    """Cari meeting sebelumnya (same category, tanggal lebih awal) + open items."""
    cur = (await db.execute(text("SELECT category, meeting_date FROM mom_meetings WHERE id=:id"), {"id": mid})).mappings().first()
    if not cur:
        raise HTTPException(404, "Meeting tidak ditemukan")
    prev = (await db.execute(text("""
        SELECT m.id, m.title, m.meeting_date, m.status,
               COUNT(i.id) FILTER (WHERE i.status <> 'closed') AS open_count
        FROM mom_meetings m
        LEFT JOIN mom_items i ON i.meeting_id = m.id
        WHERE m.category = :cat AND m.meeting_date < :d AND m.id <> :id
        GROUP BY m.id
        ORDER BY m.meeting_date DESC LIMIT 1
    """), {"cat": cur["category"], "d": cur["meeting_date"], "id": mid})).mappings().first()
    if not prev:
        return {"data": None}
    # Get open items with agenda title
    items = (await db.execute(text("""
        SELECT i.id, i.description, i.pic, i.due_date, i.priority, i.status, i.notes,
               a.title AS agenda_title
        FROM mom_items i
        LEFT JOIN mom_agendas a ON a.id = i.agenda_id
        WHERE i.meeting_id = :mid AND i.status <> 'closed'
        ORDER BY a.seq, i.item_no
    """), {"mid": prev["id"]})).mappings().all()
    out = dict(prev)
    out["items"] = [dict(i) for i in items]
    return {"data": out}


@router.post("/meetings/{mid}/carry/{item_id}", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def carry_item(mid: int, item_id: int, body: CarryItemIn,
                     db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    """Pindahkan (copy) satu item dari meeting lain ke agenda di meeting ini."""
    # Validate target
    ag = (await db.execute(text("SELECT meeting_id FROM mom_agendas WHERE id=:id"), {"id": body.target_agenda_id})).mappings().first()
    if not ag or ag["meeting_id"] != mid:
        raise HTTPException(400, "Agenda target tidak valid untuk meeting ini")
    # Get source item
    src = (await db.execute(text("SELECT * FROM mom_items WHERE id=:id"), {"id": item_id})).mappings().first()
    if not src:
        raise HTTPException(404, "Item tidak ditemukan")
    if src["meeting_id"] == mid:
        raise HTTPException(400, "Item sudah ada di meeting ini")
    max_no = (await db.execute(text(
        "SELECT COALESCE(MAX(item_no), 0) + 1 FROM mom_items WHERE meeting_id=:mid"), {"mid": mid})).scalar()
    res = await db.execute(text("""
        INSERT INTO mom_items(meeting_id, agenda_id, item_no, description, pic, due_date, priority, status, notes)
        VALUES (:mid, :aid, :no, :desc, :pic, :due, :pri, 'open', :notes) RETURNING id
    """), {"mid": mid, "aid": body.target_agenda_id, "no": max_no,
           "desc": src["description"], "pic": src["pic"], "due": src["due_date"],
           "pri": src["priority"], "notes": src["notes"]})
    new_id = res.scalar_one()
    await db.commit()
    return {"id": new_id}


# ─── Agendas ──────────────────────────────────────────────

@router.post("/meetings/{mid}/agendas", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def add_agenda(mid: int, body: AgendaIn, db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    ok = (await db.execute(text("SELECT 1 FROM mom_meetings WHERE id=:id"), {"id": mid})).scalar()
    if not ok:
        raise HTTPException(404, "Meeting tidak ditemukan")
    max_seq = (await db.execute(text(
        "SELECT COALESCE(MAX(seq), -1) + 1 FROM mom_agendas WHERE meeting_id=:mid"), {"mid": mid})).scalar()
    res = await db.execute(text("""
        INSERT INTO mom_agendas(meeting_id, seq, title, discussion)
        VALUES (:mid, :seq, :t, :disc) RETURNING id
    """), {"mid": mid, "seq": max_seq, "t": body.title.strip(), "disc": body.discussion})
    aid = res.scalar_one()
    await db.commit()
    return {"id": aid}


@router.patch("/agendas/{aid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def patch_agenda(aid: int, body: AgendaPatch, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    sets, p = [], {"id": aid}
    if body.title is not None:
        sets.append("title=:t"); p["t"] = body.title.strip()
    if body.discussion is not None:
        sets.append("discussion=:d"); p["d"] = body.discussion
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE mom_agendas SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Agenda tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/agendas/{aid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_agenda(aid: int, db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM mom_agendas WHERE id=:id"), {"id": aid})
    if res.rowcount == 0:
        raise HTTPException(404, "Agenda tidak ditemukan")
    await db.commit()
    return {"ok": True}


# ─── Items ────────────────────────────────────────────────

@router.post("/agendas/{aid}/items", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def add_item(aid: int, body: ItemIn, db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    ag = (await db.execute(text("SELECT meeting_id FROM mom_agendas WHERE id=:id"), {"id": aid})).mappings().first()
    if not ag:
        raise HTTPException(404, "Agenda tidak ditemukan")
    mid = ag["meeting_id"]
    if body.priority not in ('high', 'medium', 'low'):
        raise HTTPException(400, "Priority harus high/medium/low")
    if body.status not in ('open', 'in_progress', 'closed'):
        raise HTTPException(400, "Status tidak valid")
    max_no = (await db.execute(text(
        "SELECT COALESCE(MAX(item_no), 0) + 1 FROM mom_items WHERE meeting_id=:mid"), {"mid": mid})).scalar()
    res = await db.execute(text("""
        INSERT INTO mom_items(meeting_id, agenda_id, item_no, description, pic, due_date, priority, status, notes)
        VALUES (:mid, :aid, :no, :desc, :pic, :due, :pri, :st, :notes) RETURNING id
    """), {"mid": mid, "aid": aid, "no": max_no, "desc": body.description.strip(),
           "pic": body.pic, "due": body.due_date, "pri": body.priority,
           "st": body.status, "notes": body.notes})
    iid = res.scalar_one()
    await db.commit()
    return {"id": iid}


# Keep old endpoint for backward compat
@router.post("/meetings/{mid}/items", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def add_item_legacy(mid: int, body: ItemIn, db: AsyncSession = Depends(get_db),
                          user=Depends(get_current_user)):
    ok = (await db.execute(text("SELECT 1 FROM mom_meetings WHERE id=:id"), {"id": mid})).scalar()
    if not ok:
        raise HTTPException(404, "Meeting tidak ditemukan")
    # Find first agenda for this meeting
    ag = (await db.execute(text(
        "SELECT id FROM mom_agendas WHERE meeting_id=:mid ORDER BY seq LIMIT 1"), {"mid": mid})).mappings().first()
    aid = ag["id"] if ag else None
    if body.priority not in ('high', 'medium', 'low'):
        raise HTTPException(400, "Priority harus high/medium/low")
    if body.status not in ('open', 'in_progress', 'closed'):
        raise HTTPException(400, "Status tidak valid")
    max_no = (await db.execute(text(
        "SELECT COALESCE(MAX(item_no), 0) + 1 FROM mom_items WHERE meeting_id=:mid"), {"mid": mid})).scalar()
    res = await db.execute(text("""
        INSERT INTO mom_items(meeting_id, agenda_id, item_no, description, pic, due_date, priority, status, notes)
        VALUES (:mid, :aid, :no, :desc, :pic, :due, :pri, :st, :notes) RETURNING id
    """), {"mid": mid, "aid": aid, "no": max_no, "desc": body.description.strip(),
           "pic": body.pic, "due": body.due_date, "pri": body.priority,
           "st": body.status, "notes": body.notes})
    iid = res.scalar_one()
    await db.commit()
    return {"id": iid}


@router.patch("/items/{iid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def patch_item(iid: int, body: ItemPatch, db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    allowed = {"description": "desc", "pic": "pic", "priority": "pri", "status": "st", "notes": "notes"}
    sets, p = [], {"id": iid}
    for k, col in allowed.items():
        v = getattr(body, k)
        if v is not None:
            if k == "priority" and v not in ('high', 'medium', 'low'):
                raise HTTPException(400, "Priority tidak valid")
            if k == "status" and v not in ('open', 'in_progress', 'closed'):
                raise HTTPException(400, "Status tidak valid")
            sets.append(f"{k}=:{col}"); p[col] = v
    if body.due_date is not None:
        sets.append("due_date=:due"); p["due"] = body.due_date
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE mom_items SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Item tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/items/{iid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_item(iid: int, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM mom_items WHERE id=:id"), {"id": iid})
    if res.rowcount == 0:
        raise HTTPException(404, "Item tidak ditemukan")
    await db.commit()
    return {"ok": True}
