import datetime
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Query, Request, UploadFile, File
from fastapi.responses import FileResponse
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
    row = (await db.execute(text("SELECT avatar FROM users WHERE id=:i"),
                            {"i": user["id"]})).mappings().first()
    avatar = None
    if row and row["avatar"]:
        avatar = f"/v1/users/avatar/{user['username']}"
    return {"username": user["username"], "role": user["role"],
            "avatar_url": avatar,
            "permissions": await _perms(db, user["role"])}


class PasswordIn(BaseModel):
    old_password: str
    new_password: str


@router.patch("/password")
async def change_password(body: PasswordIn, db: AsyncSession = Depends(get_db),
                          user=Depends(get_current_user)):
    from app.core.security import verify_pw
    if len(body.new_password) < 4:
        raise HTTPException(400, "password baru min 4 karakter")
    row = (await db.execute(text("SELECT password_hash FROM users WHERE id=:i"),
                            {"i": user["id"]})).mappings().first()
    if not row or not verify_pw(body.old_password, row["password_hash"]):
        raise HTTPException(400, "password lama salah")
    await db.execute(text("UPDATE users SET password_hash=:p WHERE id=:i"),
                     {"p": hash_pw(body.new_password), "i": user["id"]})
    await db.commit()
    return {"ok": True}


def _avatar_dir() -> Path:
    from app.core.config import settings
    p = Path(settings.upload_dir) / "avatars"
    p.mkdir(parents=True, exist_ok=True)
    return p


@router.post("/avatar", status_code=201)
async def upload_avatar(file: UploadFile = File(...),
                        db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    if not (file.content_type or "").startswith("image/"):
        raise HTTPException(400, "file harus gambar")
    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(413, "foto maks 5MB")
    ext = {"image/jpeg": ".jpg", "image/png": ".png",
           "image/webp": ".webp", "image/gif": ".gif"}.get(
        file.content_type, Path(file.filename or "").suffix[:5] or ".jpg")
    stored = f"{user['id']}{ext}"
    for old in _avatar_dir().glob(f"{user['id']}.*"):
        try:
            old.unlink()
        except OSError:
            pass
    (_avatar_dir() / stored).write_bytes(content)
    await db.execute(text("UPDATE users SET avatar=:a WHERE id=:i"),
                     {"a": stored, "i": user["id"]})
    await db.commit()
    return {"avatar_url": f"/v1/users/avatar/{user['username']}"}


@router.get("/avatar/{username}")
async def avatar(username: str, token: str | None = None,
                 request: Request = None,
                 db: AsyncSession = Depends(get_db)):
    # <img> tak bisa kirim header Authorization: terima ?token= juga.
    from app.core.security import decode_token
    tok = token
    if not tok and request is not None:
        auth = request.headers.get("authorization", "")
        if auth.lower().startswith("bearer "):
            tok = auth[7:]
    if not tok:
        raise HTTPException(401, "Butuh login")
    try:
        payload = decode_token(tok)
    except Exception:
        raise HTTPException(401, "Token tidak valid")
    row = (await db.execute(text("SELECT avatar FROM users WHERE username=:u"),
                            {"u": username})).mappings().first()
    if not row or not row["avatar"]:
        raise HTTPException(404, "belum ada foto")
    path = _avatar_dir() / row["avatar"]
    if not path.is_file():
        raise HTTPException(404, "file hilang di server")
    return FileResponse(path)


@router.get("/notifications")
async def notifications(db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    """Kombinasi: 5 import terakhir + 5 aktivitas terbaru."""
    p = {} if user["role"] == "admin" else {"u": user["username"]}
    w = "" if user["role"] == "admin" else "WHERE uploaded_by=:u"
    imps = (await db.execute(text(
        f"SELECT id::text AS id, filename, sheet, status, ok_rows, fail_rows, "
        f"total_rows, uploaded_by, created_at FROM imports {w} "
        f"ORDER BY created_at DESC LIMIT 5"), p)).mappings().all()
    acts = (await db.execute(text(
        "SELECT a.id::text AS id, a.date::text AS date, a.title, a.category, "
        "a.cn, a.created_by, a.created_at, "
        "(SELECT count(*) FROM activity_photos x WHERE x.activity_id=a.id) AS photos "
        "FROM activities a ORDER BY a.created_at DESC LIMIT 5"))).mappings().all()
    return {"imports": [dict(r) for r in imps],
            "activities": [dict(r) for r in acts]}


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


@admin_router.get("/audit", dependencies=[Depends(require_role("admin"))])
async def audit_logs(date_from: datetime.date | None = None,
                     date_to: datetime.date | None = None,
                     username: str | None = None,
                     path: str | None = None,
                     page: int = Query(1, ge=1),
                     page_size: int = Query(20, ge=1, le=100),
                     db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    """Log aktivitas: siapa, akses ke mana, dari mana. Terbaru dulu."""
    import datetime as _dt
    conds, p = [], {"lim": page_size, "off": (page - 1) * page_size}
    if date_from:
        conds.append("created_at >= :df"); p["df"] = _dt.datetime.combine(date_from, _dt.time.min)
    if date_to:
        conds.append("created_at <= :dt"); p["dt"] = _dt.datetime.combine(date_to, _dt.time.max)
    if username:
        conds.append("username ILIKE :un"); p["un"] = f"%{username}%"
    if path:
        conds.append("path ILIKE :pa"); p["pa"] = f"%{path}%"
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    total = (await db.execute(text(f"SELECT count(*) FROM audit_logs {where}"), p)).scalar()
    rows = (await db.execute(text(
        f"SELECT id, created_at, username, role, method, path, status, ip, user_agent "
        f"FROM audit_logs {where} ORDER BY id DESC LIMIT :lim OFFSET :off"), p)
    ).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "data": [dict(r) for r in rows]}
