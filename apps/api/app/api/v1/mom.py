"""Minute of Meeting — meetings + action items CRUD."""
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
    meeting_date: str
    location: str | None = None
    category: str = 'Operasional'
    status: str = 'open'


class MeetingPatch(BaseModel):
    title: str | None = None
    meeting_date: str | None = None
    location: str | None = None
    category: str | None = None
    status: str | None = None


class ItemIn(BaseModel):
    description: str
    pic: str | None = None
    due_date: str | None = None
    priority: str = 'medium'
    status: str = 'open'
    notes: str | None = None


class ItemPatch(BaseModel):
    description: str | None = None
    pic: str | None = None
    due_date: str | None = None
    priority: str | None = None
    status: str | None = None
    notes: str | None = None


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
    try:
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
    except ProgrammingError as e:
        if "does not exist" in str(e):
            raise HTTPException(500, "Tabel mom_meetings belum dibuat — jalankan migration V25")
        raise
    return {"data": [dict(r) for r in rows]}


@router.post("/meetings", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def create_meeting(body: MeetingIn, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    if body.category not in CATS:
        raise HTTPException(400, f"Kategori harus salah satu {CATS}")
    if body.status not in ('open', 'closed'):
        raise HTTPException(400, "Status harus 'open' atau 'closed'")
    try:
        res = await db.execute(text("""
            INSERT INTO mom_meetings(title, meeting_date, location, category, status, created_by)
            VALUES (:t, :d, :loc, :cat, :st, :u) RETURNING id
        """), {"t": body.title.strip(), "d": body.meeting_date, "loc": body.location,
               "cat": body.category, "st": body.status, "u": user["username"]})
        mid = res.scalar_one()
        await db.commit()
    except ProgrammingError as e:
        if "does not exist" in str(e):
            raise HTTPException(500, "Tabel mom_meetings belum dibuat — jalankan migration V25 di VPS: docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V25__mom.sql")
        raise
    return {"id": mid}


@router.get("/meetings/{mid}")
async def get_meeting(mid: int, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    m = (await db.execute(text("SELECT * FROM mom_meetings WHERE id=:id"), {"id": mid})).mappings().first()
    if not m:
        raise HTTPException(404, "Meeting tidak ditemukan")
    items = (await db.execute(text("""
        SELECT * FROM mom_items WHERE meeting_id=:mid ORDER BY item_no, id
    """), {"mid": mid})).mappings().all()
    out = dict(m)
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
                raise HTTPException(400, f"Kategori tidak valid")
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


# ─── Items ────────────────────────────────────────────────

@router.post("/meetings/{mid}/items", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def add_item(mid: int, body: ItemIn, db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    ok = (await db.execute(text("SELECT 1 FROM mom_meetings WHERE id=:id"), {"id": mid})).scalar()
    if not ok:
        raise HTTPException(404, "Meeting tidak ditemukan")
    if body.priority not in ('high', 'medium', 'low'):
        raise HTTPException(400, "Priority harus high/medium/low")
    if body.status not in ('open', 'in_progress', 'closed'):
        raise HTTPException(400, "Status tidak valid")
    # Auto item_no
    max_no = (await db.execute(text(
        "SELECT COALESCE(MAX(item_no), 0) + 1 FROM mom_items WHERE meeting_id=:mid"), {"mid": mid})).scalar()
    res = await db.execute(text("""
        INSERT INTO mom_items(meeting_id, item_no, description, pic, due_date, priority, status, notes)
        VALUES (:mid, :no, :desc, :pic, :due, :pri, :st, :notes) RETURNING id
    """), {"mid": mid, "no": max_no, "desc": body.description.strip(),
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
