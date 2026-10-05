from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/fleet", tags=["fleet"])

@router.get("/alerts", dependencies=[Depends(require_role("viewer", "inputer", "admin"))])
async def fleet_alerts(
    prefix: str = Query(..., min_length=2, max_length=2),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    q = text("""
        SELECT vesselid, unit_id, model, sample_date, "condition", fe, al
        FROM mv_latest_status
        WHERE vessel_prefix = UPPER(:prefix) AND "condition" IS DISTINCT FROM 'NORMAL'
        ORDER BY sample_date DESC LIMIT :lim
    """)
    rows = (await db.execute(q, {"prefix": prefix, "lim": limit})).mappings().all()
    return {"prefix": prefix.upper(), "data": list(rows)}

@router.get("/latest", dependencies=[Depends(require_role("viewer", "inputer", "admin"))])
async def fleet_latest(
    prefix: str | None = Query(None, min_length=2, max_length=2),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    q = text("""
        SELECT vesselid, unit_id, model, sample_date, "condition"
        FROM mv_latest_status
        WHERE (:prefix IS NULL OR vessel_prefix = UPPER(:prefix))
        ORDER BY sample_date DESC LIMIT :lim
    """)
    rows = (await db.execute(q, {"prefix": prefix, "lim": limit})).mappings().all()
    return {"data": list(rows)}
