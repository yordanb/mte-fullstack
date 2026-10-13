import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_role
from app.db.session import get_db
from app.services.safety_sync import sync_db

router = APIRouter(prefix="/v1/safety", tags=["safety"])

SITE_OFF = datetime.timezone(datetime.timedelta(hours=8))


def _month_utc(y: int, m: int):
    """Batas bulan site (+8) dalam UTC — tanpa butuh tzdata di Postgres."""
    a = datetime.datetime(y, m, 1, tzinfo=SITE_OFF)
    b = a + datetime.timedelta(days=32)
    b = datetime.datetime(b.year, b.month, 1, tzinfo=SITE_OFF)
    return a.astimezone(datetime.timezone.utc), b.astimezone(datetime.timezone.utc)


def _day_utc(d: datetime.date, end=False):
    a = datetime.datetime(d.year, d.month, d.day, tzinfo=SITE_OFF)
    if end:
        a += datetime.timedelta(days=1)
    return a.astimezone(datetime.timezone.utc)

NEG = ("bisa6pas IS DISTINCT FROM 'BISA'",
       "p1_doa IS DISTINCT FROM 'SUDAH'",
       "p2_apd IS DISTINCT FROM 'SIAP'",
       "p2_stretch IS DISTINCT FROM 'SIAP'",
       "p3_housekeeping NOT LIKE 'SESUAI PRINSIP%%'",
       "p4_alat IS DISTINCT FROM 'SUDAH SESUAI'",
       "p5_prosedur IS DISTINCT FROM 'SUDAH SESUAI PROSEDUR'")


@router.post("/sync", dependencies=[Depends(require_role("inputer", "admin"))])
async def sync_now(db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    """Tarik CSV publik Google Sheets lalu upsert. Bisa menit (ribuan baris)."""
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
        "SELECT * FROM safety_sync_log ORDER BY id DESC LIMIT 1"))
    ).mappings().first()
    return dict(row) if row else {}


@router.get("/coverage")
async def coverage(year: int | None = None, month: int | None = None,
                   db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    """Cakupan per section untuk 1 bulan + kepatuhan + daftar section dikenal."""
    now = datetime.datetime.now(SITE_OFF)
    year = year or now.year
    month = month or now.month
    ma, mb = _month_utc(year, month)
    p = {"a": ma, "b": mb}
    w = "submitted_at >= :a AND submitted_at < :b"
    rows = (await db.execute(text(
        "SELECT section, count(*) AS n, "
        "count(DISTINCT mekanik_nama) AS mekanik, "
        "count(DISTINCT pengawas_nama) AS pengawas, "
        "count(DISTINCT submitted_at::date) AS hari, "
        "max(submitted_at) AS terakhir "
        f"FROM safety_pas WHERE {w} "
        "GROUP BY section ORDER BY n DESC"), p)).mappings().all()
    comp = (await db.execute(text(
        "SELECT count(*) AS total, "
        f"{', '.join(f'count(*) FILTER (WHERE NOT ({c})) AS x{i}' for i, c in enumerate(NEG))}, "
        "count(*) FILTER (WHERE p6_tindakan IS NULL OR TRIM(p6_tindakan)='') AS p6_empty, "
        "count(*) FILTER (WHERE followup IS NULL OR TRIM(followup)='') AS fu_empty "
        f"FROM safety_pas WHERE {w}"), p)
    ).mappings().first()
    known = (await db.execute(text(
        "SELECT DISTINCT section FROM safety_pas WHERE section IS NOT NULL "
        "AND TRIM(section) <> '' ORDER BY section"))).scalars().all()
    return {"year": year, "month": month,
            "coverage": [dict(r) for r in rows],
            "compliance": dict(comp) if comp else {},
            "sections": list(known)}


@router.get("/records")
async def records(date_from: datetime.date | None = None,
                  date_to: datetime.date | None = None,
                  section: str | None = None,
                  grade: str | None = None,
                  search: str | None = None,
                  temuan: bool | None = None,
                  page: int = Query(1, ge=1),
                  page_size: int = Query(20, ge=1, le=100),
                  db: AsyncSession = Depends(get_db),
                  user=Depends(get_current_user)):
    conds, p = [], {"lim": page_size, "off": (page - 1) * page_size}
    if date_from:
        conds.append("submitted_at >= :df"); p["df"] = _day_utc(date_from)
    if date_to:
        conds.append("submitted_at < :dt"); p["dt"] = _day_utc(date_to, end=True)
    if section:
        conds.append("section = :sec"); p["sec"] = section
    if grade:
        conds.append("grade = :gr"); p["gr"] = grade
    if search:
        conds.append("(mekanik_nama ILIKE :s OR pengawas_nama ILIKE :s "
                     "OR mekanik_nrp ILIKE :s OR vlog_desc ILIKE :s)")
        p["s"] = f"%{search}%"
    if temuan:
        conds.append("(TRIM(COALESCE(p3_desc,'')) <> '' "
                     "OR TRIM(COALESCE(p4_desc,'')) <> '' "
                     "OR TRIM(COALESCE(p6_desc,'')) <> '' "
                     "OR TRIM(COALESCE(followup,'')) <> '' "
                     "OR TRIM(COALESCE(p3_doc,'')) <> '' "
                     "OR TRIM(COALESCE(p4_doc,'')) <> '' "
                     f"OR {' OR '.join(f'NOT ({c})' for c in NEG)})")
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    total = (await db.execute(text(f"SELECT count(*) FROM safety_pas {where}"), p)).scalar()
    rows = (await db.execute(text(
        f"SELECT * FROM safety_pas {where} "
        f"ORDER BY submitted_at DESC LIMIT :lim OFFSET :off"), p)
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
    """Semua baris sesuai filter (ringkas, maks 5000) untuk salin WA/export."""
    conds, p = [], {}
    if date_from:
        conds.append("submitted_at >= :df"); p["df"] = _day_utc(date_from)
    if date_to:
        conds.append("submitted_at < :dt"); p["dt"] = _day_utc(date_to, end=True)
    if section:
        conds.append("section = :sec"); p["sec"] = section
    if search:
        conds.append("(mekanik_nama ILIKE :s OR pengawas_nama ILIKE :s "
                     "OR mekanik_nrp ILIKE :s OR vlog_desc ILIKE :s)")
        p["s"] = f"%{search}%"
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    rows = (await db.execute(text(
        f"SELECT mekanik_nama, submitted_at FROM safety_pas {where} "
        f"ORDER BY submitted_at DESC LIMIT 5000"), p)).mappings().all()
    return {"total": len(rows), "data": [dict(r) for r in rows]}
