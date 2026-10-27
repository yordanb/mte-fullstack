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

# Nama kolom matriks izin untuk tiap aksi halaman.
_MENU_COL = {"view": "can_view", "add": "can_add", "edit": "can_edit", "delete": "can_delete"}

def require_menu(menu: str, action: str = "view"):
    """Cek izin per menu pada tabel role_permissions (admin selalu lolos).

    Berbeda dari require_role (berbasis nama role), dependency ini mengikuti
    centang di halaman Users sehingga menu baru tidak perlu aturan role baru.
    Role turunan (ROLE_INHERITS) ikut diwarisi bila belum punya baris sendiri.
    """
    col = _MENU_COL.get(action)
    if not col:
        raise ValueError(f"action tidak dikenal: {action}")

    async def _check(user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
        if user["role"] == "admin":
            return user
        roles = [user["role"]]
        base = ROLE_INHERITS.get(user["role"])
        if base:
            roles.append(base)
        params = {f"r{i}": r for i, r in enumerate(roles)}
        ph = ",".join(f":r{i}" for i in range(len(roles)))
        ok = (await db.execute(
            text(f"SELECT bool_or({col}) FROM role_permissions "
                 f"WHERE menu=:m AND role IN ({ph})"),
            {**params, "m": menu})).scalar()
        if not ok:
            raise HTTPException(403, "Akses ditolak")
        return user
    return _check