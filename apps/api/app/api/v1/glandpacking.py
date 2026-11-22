from fastapi import APIRouter, Depends, Body
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import datetime

from app.core.deps import get_current_user, require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/glandpacking", tags=["glandpacking"])

class ReplacementIn(BaseModel):
    cn: str
    hm: int
    replace_date: datetime.date

@router.post("", dependencies=[Depends(require_role("inputer", "admin"))])
async def add_replacement(
    body: ReplacementIn = Body(...),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user)
):
    await db.execute(text("""
        INSERT INTO glandpacking_replacement (cn, hm_replace, replace_date, created_by)
        VALUES (:cn, :hm, :date, :u)
        ON CONFLICT (cn, replace_date) 
        DO UPDATE SET hm_replace = EXCLUDED.hm_replace, updated_at = NOW()
    """), {"cn": body.cn.upper(), "hm": body.hm, "date": body.replace_date, "u": user["username"]})
    await db.commit()
    return {"ok": True}
