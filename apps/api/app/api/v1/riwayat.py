"""Riwayat — issue tracking dengan progress timeline + parts requirement."""
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.core.deps import get_current_user, require_role

router = APIRouter(prefix="/v1/riwayat", tags=["riwayat"])

CATS = ('Breakdown Unscheduled', 'Breakdown Scheduled', 'Maintenance Rutin', 'Inspection', 'Modification', 'Lainnya')
STATUSES = ('open', 'in_progress', 'waiting_part', 'waiting_crew', 'closed')
PART_STATUSES = ('needed', 'ordered', 'received', 'installed', 'cancelled')


# ─── Models ─────────────────────────────────────────────

class IssueIn(BaseModel):
    title: str
    cn: str | None = None
    category: str = 'Breakdown Unscheduled'
    status: str = 'open'
    start_date: date
    end_date: date | None = None
    description: str | None = None


class IssuePatch(BaseModel):
    title: str | None = None
    cn: str | None = None
    category: str | None = None
    status: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    description: str | None = None


class ProgressIn(BaseModel):
    description: str
    part_required: bool = False


class ProgressPatch(BaseModel):
    description: str | None = None
    part_required: bool | None = None


class PartIn(BaseModel):
    part_name: str
    qty: int = 1
    status: str = 'needed'
    eta: date | None = None
    notes: str | None = None


class PartPatch(BaseModel):
    part_name: str | None = None
    qty: int | None = None
    status: str | None = None
    eta: date | None = None
    notes: str | None = None


# ─── Issues ───────────────────────────────────────────────

@router.get("/issues")
async def list_issues(status: str | None = Query(None),
                      category: str | None = Query(None),
                      cn: str | None = Query(None),
                      db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    conds, p = [], {}
    if status:
        conds.append("i.status = :st"); p["st"] = status
    if category:
        conds.append("i.category = :cat"); p["cat"] = category
    if cn:
        conds.append("i.cn = :cn"); p["cn"] = cn.upper()
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    rows = (await db.execute(text(f"""
        SELECT i.*,
               (SELECT COUNT(*) FROM riwayat_progress p WHERE p.issue_id = i.id) AS progress_count,
               (SELECT COUNT(*) FROM riwayat_parts pt WHERE pt.issue_id = i.id
                AND pt.status NOT IN ('installed','cancelled')) AS open_parts
        FROM riwayat_issues i
        {where}
        ORDER BY i.start_date DESC, i.id DESC
    """), p)).mappings().all()
    return {"data": [dict(r) for r in rows]}


@router.post("/issues", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))], status_code=201)
async def create_issue(body: IssueIn, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    if body.category not in CATS:
        raise HTTPException(400, f"Kategori tidak valid: {CATS}")
    if body.status not in STATUSES:
        raise HTTPException(400, f"Status tidak valid: {STATUSES}")
    cn = (body.cn or "").strip().upper() or None
    if cn:
        ok = (await db.execute(text("SELECT 1 FROM equipment WHERE cn=:c"), {"c": cn})).scalar()
        if not ok:
            raise HTTPException(400, f"CN {cn} tidak ada di master equipment")
    res = await db.execute(text("""
        INSERT INTO riwayat_issues(title, cn, category, status, start_date, end_date, description, created_by)
        VALUES (:t, :cn, :cat, :st, :sd, :ed, :dsc, :u) RETURNING id
    """), {"t": body.title.strip(), "cn": cn, "cat": body.category,
           "st": body.status, "sd": body.start_date, "ed": body.end_date,
           "dsc": body.description, "u": user["username"]})
    iid = res.scalar_one()
    await db.commit()
    return {"id": iid}


@router.get("/issues/{iid}")
async def get_issue(iid: int,  db: AsyncSession = Depends(get_db),
                    user=Depends(get_current_user)):
    issue = (await db.execute(text("SELECT * FROM riwayat_issues WHERE id=:id"), {"id": iid})).mappings().first()
    if not issue:
        raise HTTPException(404, "Issue tidak ditemukan")
    progress = (await db.execute(text("""
        SELECT * FROM riwayat_progress WHERE issue_id=:iid ORDER BY seq, id
    """), {"iid": iid})).mappings().all()
    parts = (await db.execute(text("""
        SELECT * FROM riwayat_parts WHERE issue_id=:iid ORDER BY id
    """), {"iid": iid})).mappings().all()
    out = dict(issue)
    out["progress"] = [dict(p) for p in progress]
    out["parts"] = [dict(pt) for pt in parts]
    return out


@router.patch("/issues/{iid}", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))])
async def patch_issue(iid: int, body: IssuePatch, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    allowed = ("title", "cn", "category", "status", "start_date", "end_date", "description")
    sets, p = [], {"id": iid}
    for k in allowed:
        v = getattr(body, k)
        if v is not None:
            if k == "category" and v not in CATS:
                raise HTTPException(400, "Kategori tidak valid")
            if k == "status" and v not in STATUSES:
                raise HTTPException(400, "Status tidak valid")
            if k == "cn":
                v = v.strip().upper() or None
                if v:
                    ok = (await db.execute(text("SELECT 1 FROM equipment WHERE cn=:c"), {"c": v})).scalar()
                    if not ok:
                        raise HTTPException(400, f"CN {v} tidak ada di master equipment")
            sets.append(f"{k}=:{k}"); p[k] = v
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE riwayat_issues SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Issue tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/issues/{iid}", dependencies=[Depends(require_role("admin"))])
async def delete_issue(iid: int, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM riwayat_issues WHERE id=:id"), {"id": iid})
    if res.rowcount == 0:
        raise HTTPException(404, "Issue tidak ditemukan")
    await db.commit()
    return {"ok": True}


# ─── Progress ─────────────────────────────────────────────

@router.post("/issues/{iid}/progress", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))], status_code=201)
async def add_progress(iid: int, body: ProgressIn, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    ok = (await db.execute(text("SELECT 1 FROM riwayat_issues WHERE id=:id"), {"id": iid})).scalar()
    if not ok:
        raise HTTPException(404, "Issue tidak ditemukan")
    max_seq = (await db.execute(text(
        "SELECT COALESCE(MAX(seq), -1) + 1 FROM riwayat_progress WHERE issue_id=:iid"), {"iid": iid})).scalar()
    res = await db.execute(text("""
        INSERT INTO riwayat_progress(issue_id, seq, log_date, description, part_required, created_by)
        VALUES (:iid, :seq, now(), :desc, :pr, :u) RETURNING id
    """), {"iid": iid, "seq": max_seq, "desc": body.description.strip(),
           "pr": body.part_required, "u": user["username"]})
    pid = res.scalar_one()
    await db.commit()
    return {"id": pid}


@router.patch("/progress/{pid}", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))])
async def patch_progress(pid: int, body: ProgressPatch, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    sets, p = [], {"id": pid}
    if body.description is not None:
        sets.append("description=:dsc"); p["dsc"] = body.description.strip()
    if body.part_required is not None:
        sets.append("part_required=:pr"); p["pr"] = body.part_required
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE riwayat_progress SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Progress tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/progress/{pid}", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))])
async def delete_progress(pid: int, db: AsyncSession = Depends(get_db),
                          user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM riwayat_progress WHERE id=:id"), {"id": pid})
    if res.rowcount == 0:
        raise HTTPException(404, "Progress tidak ditemukan")
    await db.commit()
    return {"ok": True}


# ─── Parts ────────────────────────────────────────────────

@router.post("/issues/{iid}/parts", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))], status_code=201)
async def add_part(iid: int, body: PartIn, db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    ok = (await db.execute(text("SELECT 1 FROM riwayat_issues WHERE id=:id"), {"id": iid})).scalar()
    if not ok:
        raise HTTPException(404, "Issue tidak ditemukan")
    if body.status not in PART_STATUSES:
        raise HTTPException(400, "Status part tidak valid")
    res = await db.execute(text("""
        INSERT INTO riwayat_parts(issue_id, part_name, qty, status, eta, notes)
        VALUES (:iid, :pn, :qty, :st, :eta, :notes) RETURNING id
    """), {"iid": iid, "pn": body.part_name.strip(), "qty": body.qty,
           "st": body.status, "eta": body.eta, "notes": body.notes})
    ptid = res.scalar_one()
    await db.commit()
    return {"id": ptid}


@router.patch("/parts/{ptid}", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))])
async def patch_part(ptid: int, body: PartPatch, db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    allowed = ("part_name", "qty", "status", "eta", "notes")
    sets, p = [], {"id": ptid}
    for k in allowed:
        v = getattr(body, k)
        if v is not None:
            if k == "status" and v not in PART_STATUSES:
                raise HTTPException(400, "Status part tidak valid")
            sets.append(f"{k}=:{k}"); p[k] = v
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE riwayat_parts SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Part tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/parts/{ptid}", dependencies=[Depends(require_role("inputer", "admin", "mekanik"))])
async def delete_part(ptid: int, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM riwayat_parts WHERE id=:id"), {"id": ptid})
    if res.rowcount == 0:
        raise HTTPException(404, "Part tidak ditemukan")
    await db.commit()
    return {"ok": True}