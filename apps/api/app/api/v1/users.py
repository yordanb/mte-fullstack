from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_role
from app.core.security import hash_pw
from app.db.session import get_db

router = APIRouter(prefix="/v1/users", tags=["users"])
admin_router = APIRouter(prefix="/v1/admin", tags=["admin"])

MENUS = ("dashboard", "dbr", "performance", "activity", "equipment", "vessel", "import")
ROLES = ("admin", "inputer", "viewer")


async def _perms(db: AsyncSession, role: str) -> dict:
    rows = (await db.execute(text(
        "SELECT menu, can_view, can_add, can_edit, can_delete "
        "FROM role_permissions WHERE role=:r"), {"r": role})).mappings().all()
    out = {m: {"view": False, "add": False, "edit": False, "delete": False} for m in MENUS}
    for r in rows:
        if r["menu"] in out:
            out[r["menu"]] = {"view": r["can_view"], "add": r["can_add"],
                              "edit": r["can_edit"], "delete": r["can_delete"]}
    return out


@router.get("/me")
async def me(user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return {"username": user["username"], "role": user["role"],
            "permissions": await _perms(db, user["role"])}


class UserIn(BaseModel):
    username: str
    password: str
    role: str


@admin_router.get("/users", dependencies=[Depends(require_role("admin"))])
async def list_users(db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    rows = (await db.execute(text(
        "SELECT username, role, created_at FROM users ORDER BY username"))).mappings().all()
    return {"data": [dict(r) for r in rows]}


@admin_router.post("/users", dependencies=[Depends(require_role("admin"))], status_code=201)
async def add_user(body: UserIn, db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    uname = body.username.strip()
    if not uname or len(body.password) < 4:
        raise HTTPException(400, "username wajib & password min 4 karakter")
    if body.role not in ROLES:
        raise HTTPException(400, f"role harus salah satu {ROLES}")
    exists = (await db.execute(text("SELECT 1 FROM users WHERE username=:u"),
                               {"u": uname})).scalar()
    if exists:
        raise HTTPException(409, "username sudah ada")
    await db.execute(text(
        "INSERT INTO users(username, password_hash, role) VALUES (:u,:p,:r)"),
        {"u": uname, "p": hash_pw(body.password), "r": body.role})
    await db.commit()
    return {"username": uname, "role": body.role}


class UserPatch(BaseModel):
    role: str | None = None
    password: str | None = None


@admin_router.patch("/users/{username}", dependencies=[Depends(require_role("admin"))])
async def edit_user(username: str, body: UserPatch, db: AsyncSession = Depends(get_db),
                    user=Depends(get_current_user)):
    if body.role is not None and body.role not in ROLES:
        raise HTTPException(400, f"role harus salah satu {ROLES}")
    if body.role is not None and username == user["username"] and body.role != "admin":
        raise HTTPException(400, "tidak bisa menurunkan role diri sendiri")
    if body.password is not None and len(body.password) < 4:
        raise HTTPException(400, "password min 4 karakter")
    # jaga agar minimal 1 admin tersisa
    if body.role is not None and body.role != "admin":
        n = (await db.execute(text(
            "SELECT count(*) FROM users WHERE role='admin' AND username<>:u"),
            {"u": username})).scalar()
        cur = (await db.execute(text("SELECT role FROM users WHERE username=:u"),
                                {"u": username})).scalar()
        if cur == "admin" and (n or 0) == 0:
            raise HTTPException(400, "minimal harus ada 1 admin")
    sets, p = [], {"u": username}
    if body.role is not None:
        sets.append("role=:r"); p["r"] = body.role
    if body.password is not None:
        sets.append("password_hash=:p"); p["p"] = hash_pw(body.password)
    if not sets:
        raise HTTPException(400, "tidak ada yang diubah")
    res = await db.execute(text(f"UPDATE users SET {', '.join(sets)} WHERE username=:u"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "user tidak ditemukan")
    await db.commit()
    return {"username": username}


@admin_router.delete("/users/{username}", dependencies=[Depends(require_role("admin"))])
async def del_user(username: str, db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    if username == user["username"]:
        raise HTTPException(400, "tidak bisa menghapus diri sendiri")
    cur = (await db.execute(text("SELECT role FROM users WHERE username=:u"),
                            {"u": username})).scalar()
    if cur == "admin":
        n = (await db.execute(text(
            "SELECT count(*) FROM users WHERE role='admin'"))).scalar()
        if (n or 0) <= 1:
            raise HTTPException(400, "minimal harus ada 1 admin")
    res = await db.execute(text("DELETE FROM users WHERE username=:u"), {"u": username})
    if res.rowcount == 0:
        raise HTTPException(404, "user tidak ditemukan")
    await db.commit()
    return {"ok": True}


@admin_router.get("/permissions", dependencies=[Depends(require_role("admin"))])
async def get_perms(db: AsyncSession = Depends(get_db),
                    user=Depends(get_current_user)):
    rows = (await db.execute(text(
        "SELECT role, menu, can_view, can_add, can_edit, can_delete "
        "FROM role_permissions ORDER BY role, menu"))).mappings().all()
    return {"data": [dict(r) for r in rows]}


class PermIn(BaseModel):
    role: str
    menu: str
    can_view: bool = False
    can_add: bool = False
    can_edit: bool = False
    can_delete: bool = False


@admin_router.put("/permissions", dependencies=[Depends(require_role("admin"))])
async def set_perm(body: PermIn, db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    if body.role == "admin":
        raise HTTPException(400, "izin admin selalu penuh (terkunci)")
    if body.role not in ROLES or body.menu not in MENUS:
        raise HTTPException(400, "role/menu tidak valid")
    v, a, e, d = body.can_view, body.can_add, body.can_edit, body.can_delete
    if (a or e or d) and not v:
        raise HTTPException(400, "tulis butuh hak lihat")
    await db.execute(text(
        "INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) "
        "VALUES (:r,:m,:v,:a,:e,:d) "
        "ON CONFLICT (role,menu) DO UPDATE SET "
        "can_view=EXCLUDED.can_view, can_add=EXCLUDED.can_add, "
        "can_edit=EXCLUDED.can_edit, can_delete=EXCLUDED.can_delete"),
        {"r": body.role, "m": body.menu, "v": v, "a": a, "e": e, "d": d})
    await db.commit()
    return {"ok": True}
