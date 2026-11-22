from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user
from app.db.session import get_db

router = APIRouter(prefix="/v1/glandpacking", tags=["glandpacking"])

@router.get("/history")
async def history(db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    q = text("""
        SELECT 
            cn, 
            MAX(replace_date) as last_date,
            MAX(hm_replace) as last_hm,
            ARRAY_AGG(replace_date::text || ' (HM: ' || hm_replace || ')' ORDER BY replace_date DESC) as history
        FROM glandpacking_replacement
        GROUP BY cn
        ORDER BY cn ASC
    """)
    res = await db.execute(q)
    return {"data": [dict(r._mapping) for r in res.all()]}
