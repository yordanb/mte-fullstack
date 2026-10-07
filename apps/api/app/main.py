from fastapi import FastAPI, Request
from sqlalchemy import text
from app.api.v1.results import router as results_router
from app.api.v1.fleet import router as fleet_router
from app.api.v1.imports import router as imports_router
from app.api.v1.auth import router as auth_router
from app.api.v1.dbr import router as dbr_router
from app.api.v1.equipment import router as equipment_router
from app.api.v1.activities import router as activities_router
from app.api.v1.users import router as users_router, admin_router
from app.api.v1.fui import router as fui_router
from app.core.config import settings
from app.core.security import hash_pw
from app.core.audit import write_log
from app.db.session import engine, SessionLocal

app = FastAPI(title="MTE Oil Lab API", version="1.0.0")

SKIP_AUDIT = ("/health", "/docs", "/redoc", "/openapi.json", "/v1/auth/login")


def _ip(req: Request) -> str | None:
    fwd = req.headers.get("x-forwarded-for", "")
    if fwd:
        return fwd.split(",")[0].strip()[:45]
    return req.client.host if req.client else None


@app.middleware("http")
async def audit_middleware(req: Request, call_next):
    resp = await call_next(req)
    try:
        path = req.url.path
        if path in SKIP_AUDIT or path.startswith("/docs"):
            return resp
        uid, role, uname = None, None, None
        tok = None
        auth = req.headers.get("authorization", "")
        if auth.lower().startswith("bearer "):
            tok = auth[7:]
        elif req.query_params.get("token"):
            tok = req.query_params["token"]  # <img> foto tak bisa kirim header
        if tok:
            try:
                from app.core.security import decode_token
                p = decode_token(tok)
                uid, role = p.get("sub"), p.get("role")
            except Exception:
                pass
        async with SessionLocal() as db:
            if uid:
                uname = (await db.execute(text(
                    "SELECT username FROM users WHERE id::text=:s"),
                    {"s": uid})).scalar()
            await write_log(db, user_id=uid, username=uname, role=role,
                            method=req.method, path=path, status=resp.status_code,
                            ip=_ip(req), user_agent=req.headers.get("user-agent"))
            await db.commit()
    except Exception:
        pass
    return resp

@app.get("/health")
async def health():
    return {"ok": True}

@app.on_event("startup")
async def seed_admin():
    async with engine.begin() as c:
        await c.execute(text("""
            INSERT INTO users(username, password_hash, role)
            VALUES (:u, :p, 'admin') ON CONFLICT (username) DO NOTHING
        """), {"u": settings.admin_username, "p": hash_pw(settings.admin_password)})

app.include_router(auth_router)
app.include_router(results_router)
app.include_router(fleet_router)
app.include_router(imports_router)
app.include_router(dbr_router)
app.include_router(equipment_router)
app.include_router(activities_router)
app.include_router(users_router)
app.include_router(admin_router)
app.include_router(fui_router)
