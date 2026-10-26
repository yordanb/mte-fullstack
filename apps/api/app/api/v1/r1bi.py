import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_role
from app.db.session import get_db
from app.services.r1bi_sync import sync_db

router = APIRouter(prefix="/v1/r1bi", tags=["r1bi"])

SITE_OFF = datetime.timezone(datetime.timedelta(hours=8))


@router.post("/sync", dependencies=[Depends(require_role("inputer", "admin"))])
async def sync_now(db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    """Tarik CSV R1BI publik lalu upsert (±16rb baris, bisa menit)."""
    from fastapi import HTTPException
    try:
        return await sync_db(db, by=user["username"])
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(502, f"gagal tarik Google Sheets: {e}")


@router.get("/latest-sync")
async def latest_sync(db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    row = (await db.execute(text(
        "SELECT * FROM safety_sync_log WHERE source='r1bi' "
        "ORDER BY id DESC LIMIT 1"))).mappings().first()
    return dict(row) if row else {}


@router.get("/coverage")
async def coverage(year: int | None = None, month: int | None = None,
                   db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    """Cakupan per section + sorot HIGH RISK untuk 1 bulan (tanggal R1BI)."""
    now = datetime.datetime.now(SITE_OFF)
    year = year or now.year
    month = month or now.month
    y2, m2 = (year + 1, 1) if month == 12 else (year, month + 1)
    p = {"df": datetime.date(year, month, 1), "dt": datetime.date(y2, m2, 1)}
    w = "tanggal >= :df AND tanggal < :dt"
    rows = (await db.execute(text(
        "SELECT section, count(*) AS n, "
        "count(DISTINCT nama) AS pekerja, "
        "count(*) FILTER (WHERE aktivitas='HIGH RISK') AS high, "
        "count(DISTINCT tanggal) AS hari, "
        "max(tanggal) AS terakhir "
        f"FROM safety_r1bi WHERE {w} "
        "GROUP BY section ORDER BY n DESC"), p)).mappings().all()
    comp = (await db.execute(text(
        "SELECT count(*) AS total, "
        "count(*) FILTER (WHERE aktivitas='HIGH RISK') AS high "
        f"FROM safety_r1bi WHERE {w}"), p)).mappings().first()
    known = (await db.execute(text(
        "SELECT DISTINCT section FROM safety_r1bi WHERE section IS NOT NULL "
        "AND TRIM(section) <> '' ORDER BY section"))).scalars().all()
    return {"year": year, "month": month,
            "coverage": [dict(r) for r in rows],
            "compliance": dict(comp) if comp else {},
            "sections": list(known)}


@router.get("/records")
async def records(date_from: datetime.date | None = None,
                  date_to: datetime.date | None = None,
                  section: str | None = None,
                  risk: str | None = None,
                  search: str | None = None,
                  page: int = Query(1, ge=1),
                  page_size: int = Query(20, ge=1, le=100),
                  db: AsyncSession = Depends(get_db),
                  user=Depends(get_current_user)):
    conds, p = [], {"lim": page_size, "off": (page - 1) * page_size}
    if date_from:
        conds.append("tanggal >= :df"); p["df"] = date_from
    if date_to:
        conds.append("tanggal <= :dt"); p["dt"] = date_to
    if section:
        conds.append("section = :sec"); p["sec"] = section
    if risk:
        conds.append("aktivitas = :rk"); p["rk"] = risk.upper()
    if search:
        conds.append("(nama ILIKE :s OR nrp ILIKE :s OR staff_ribi ILIKE :s "
                     "OR bahaya_desc ILIKE :s OR pengendalian_desc ILIKE :s)")
        p["s"] = f"%{search}%"
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    total = (await db.execute(text(f"SELECT count(*) FROM safety_r1bi {where}"), p)).scalar()
    rows = (await db.execute(text(
        f"SELECT * FROM safety_r1bi {where} "
        f"ORDER BY tanggal DESC, submitted_at DESC LIMIT :lim OFFSET :off"), p)
    ).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "data": [dict(r) for r in rows]}


@router.get("/export")
async def export_all(date_from: datetime.date | None = None,
                     date_to: datetime.date | None = None,
                     section: str | None = None,
                     search: str | None = None,
                     db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    """Semua baris sesuai filter (ringkas, maks 5000) untuk salin WA."""
    conds, p = [], {}
    if date_from:
        conds.append("tanggal >= :df"); p["df"] = date_from
    if date_to:
        conds.append("tanggal <= :dt"); p["dt"] = date_to
    if section:
        conds.append("section = :sec"); p["sec"] = section
    if search:
        conds.append("(nama ILIKE :s OR nrp ILIKE :s OR staff_ribi ILIKE :s)")
        p["s"] = f"%{search}%"
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    rows = (await db.execute(text(
        f"SELECT nama, tanggal, staff_ribi FROM safety_r1bi {where} "
        f"ORDER BY tanggal DESC LIMIT 5000"), p)).mappings().all()
    return {"total": len(rows), "data": [dict(r) for r in rows]}
