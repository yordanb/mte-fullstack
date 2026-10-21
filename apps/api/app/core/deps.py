from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import decode_token
from app.db.session import get_db

bearer = HTTPBearer(auto_error=False)

# Role inheritance: role baru mewarisi izin dari base role.
# Saat require_role("inputer") dipanggil, planner & adm te juga diizinkan
# karena mereka inherit dari inputer. admin selalu bypass semua cek.
ROLE_INHERITS: dict[str, str] = {
    "planner": "inputer",
    "group leader": "mekanik",
    "section head": "viewer",
    "adm te": "inputer",
}

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
        urole = user["role"]
        # admin selalu bypass
        if urole == "admin":
            return user
        # cocok langsung
        if urole in roles:
            return user
        # cek inheritance: jika base role dari user ada di allowed list
        base = ROLE_INHERITS.get(urole)
        if base and base in roles:
            return user
        raise HTTPException(403, "Akses ditolak")
    return _check