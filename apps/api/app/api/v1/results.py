from datetime import datetime
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/results", tags=["results"])

@router.get("", dependencies=[Depends(require_role("viewer", "operator", "admin"))])
async def list_results(
    vesselid: str | None = None,
    unit_id: str | None = None,
    limit: int = Query(20, le=100),
    before: datetime | None = None,
    db: AsyncSession = Depends(get_db),
):
    """20 data terbaru per vessel, opsional filter unit_id. Cursor via `before`."""
    conds, params = [], {"lim": limit}
    if vesselid:
        conds.append("vesselid = UPPER(TRIM(:vesselid))")
        params["vesselid"] = vesselid
    if unit_id:
        conds.append("unit_id = :unit_id")
        params["unit_id"] = unit_id
    if before:
        conds.append("sample_date < :before")
        params["before"] = before
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    q = text(f"""
        SELECT lab_no, vesselid, unit_id, model, sample_date, date_taken,
               ROUND(EXTRACT(EPOCH FROM (date_taken - sample_date)) / 86400, 1) AS lead_time,
               oil_weight, unit_time, unit_time_oils,
               visc, fuel, soot, oxi, nitr, water, tbn,
               si, fe, cu, al, cr, pb, na,
               "condition", english_description
        FROM oil_lab_result {where}
        ORDER BY sample_date DESC, lab_no DESC LIMIT :lim
    """)
    return {"data": list((await db.execute(q, params)).mappings().all())}

@router.get("/latest-per-unit", dependencies=[Depends(require_role("viewer", "operator", "admin"))])
async def latest_per_unit(
    limit: int = Query(50, le=200),
    prefix: str | None = Query(None, min_length=2, max_length=2),
    condition: str | None = Query(None, description="cth CRITICAL"),
    db: AsyncSession = Depends(get_db),
):
    """Default dashboard: 1 baris terbaru per (vesselid, unit_id), format report penuh.
    Filter opsional: prefix 2 huruf vessel + condition (untuk radio TL/GS/WP Critical)."""
    conds, params = [], {"lim": limit}
    inner = ""
    if prefix:
        inner = "WHERE vessel_prefix = UPPER(:prefix)"
        params["prefix"] = prefix
    outer = ""
    if condition:
        outer = 'WHERE "condition" = UPPER(:condition)'
        params["condition"] = condition
    q = text(f"""
        SELECT * FROM (
          SELECT DISTINCT ON (vesselid, unit_id)
                 lab_no, vesselid, unit_id, model, sample_date, date_taken,
                 ROUND(EXTRACT(EPOCH FROM (date_taken - sample_date)) / 86400, 1) AS lead_time,
                 oil_weight, unit_time, unit_time_oils,
                 visc, fuel, soot, oxi, nitr, water, tbn,
                 si, fe, cu, al, cr, pb, na,
                 "condition", english_description
          FROM oil_lab_result {inner}
          ORDER BY vesselid, unit_id, sample_date DESC, lab_no DESC
        ) t {outer} ORDER BY sample_date DESC LIMIT :lim
    """)
    return {"data": list((await db.execute(q, params)).mappings().all())}

@router.get("/{lab_no}", dependencies=[Depends(require_role("viewer", "operator", "admin"))])
async def detail(lab_no: int, db: AsyncSession = Depends(get_db)):
    """Detail 1 baris full-column untuk grafik tren / drill-down."""
    row = (await db.execute(
        text("SELECT * FROM oil_lab_result WHERE lab_no=:l"), {"l": lab_no})).mappings().first()
    if not row:
        raise HTTPException(404, "lab_no tidak ditemukan")
    return dict(row)
