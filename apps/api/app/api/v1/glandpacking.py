from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import datetime

from app.core.deps import get_current_user, require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/glandpacking", tags=["glandpacking"])

@router.post("", dependencies=[Depends(require_role("inputer", "admin"))])
async def add_replacement(
    cn: str, hm: int, replace_date: datetime.date,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user)
):
    await db.execute(text("""
        INSERT INTO glandpacking_replacement (cn, hm_replace, replace_date, created_by)
        VALUES (:cn, :hm, :date, :u)
        ON CONFLICT (cn, replace_date) 
        DO UPDATE SET hm_replace = EXCLUDED.hm_replace, updated_at = NOW()
    """), {"cn": cn.upper(), "hm": hm, "date": replace_date, "u": user["username"]})
    await db.commit()
    return {"ok": True}
