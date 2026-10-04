from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import decode_token
from app.db.session import get_db

bearer = HTTPBearer(auto_error=False)

async def get_current_user(creds=Depends(bearer), db: AsyncSession = Depends(get_db)):
    if not creds:
        raise HTTPException(401, "Butuh login")
    try:
        payload = decode_token(creds.credentials)
    except Exception:
        raise HTTPException(401, "Token tidak valid")
    row = (await db.execute(
        text("SELECT id, username, role FROM users WHERE id::text = :s"),
        {"s": payload["sub"]})).mappings().first()
    if not row:
        raise HTTPException(401, "User tidak ada")
    return dict(row)

def require_role(*roles: str):
    async def _check(user=Depends(get_current_user)):
        if user["role"] not in roles and user["role"] != "admin":
            raise HTTPException(403, "Akses ditolak")
        return user
    return _check
