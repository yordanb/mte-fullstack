from datetime import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db

router = APIRouter(prefix="/v1/results", tags=["results"])

@router.get("")
async def list_results(
    vesselid: str | None = None,
    unit_id: str | None = None,
    limit: int = Query(20, le=100),
    before: datetime | None = None,
    db: AsyncSession = Depends(get_db),
):
    """20 data terbaru per vessel, opsional filter unit_id. Cursor via `before`."""
    conds = []
    params: dict = {"lim": limit}
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
               fe, al, "condition", english_description
        FROM oil_lab_result {where}
        ORDER BY sample_date DESC, lab_no DESC LIMIT :lim
    """)
    rows = (await db.execute(q, params)).mappings().all()
    return {"data": list(rows)}
