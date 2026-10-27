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
from app.api.v1.projects import router as projects_router
from app.api.v1.safety import router as safety_router
from app.api.v1.r1bi import router as r1bi_router
from app.api.v1.fui import router as fui_router
from app.api.v1.staging import router as staging_router
from app.api.v1.mom import router as mom_router
from app.api.v1.riwayat import router as riwayat_router
from app.api.v1.yazu import router as yazu_router, do_sync
from app.api.v1.ewacs import router as ewacs_router
from app.api.v1.ss import router as ss_router
from app.api.v1.proker import router as proker_router
from app.api.v1.booster import router as booster_router
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
    # Start scheduler: yazu sync 06:00 & 18:00 Asia/Makassar (GMT+8)
    global _scheduler
    _scheduler = AsyncIOScheduler(timezone="Asia/Makassar")
    _scheduler.add_job(_yazu_scheduled_sync, CronTrigger(hour=6, minute=0), id="yazu_morning")
    _scheduler.add_job(_yazu_scheduled_sync, CronTrigger(hour=18, minute=0), id="yazu_evening")
    _scheduler.start()
    _yazu_log.info("yazu scheduler started (06:00 & 18:00 Asia/Makassar)")


@app.on_event("shutdown")
async def stop_scheduler():
    global _scheduler
    if _scheduler:
        _scheduler.shutdown(wait=False)
        _scheduler = None

app.include_router(auth_router)
app.include_router(results_router)
app.include_router(fleet_router)
app.include_router(imports_router)
app.include_router(dbr_router)
app.include_router(equipment_router)
app.include_router(activities_router)
app.include_router(users_router)
app.include_router(admin_router)
app.include_router(projects_router)
app.include_router(safety_router)
app.include_router(r1bi_router)
app.include_router(fui_router)
app.include_router(staging_router)
app.include_router(mom_router)
app.include_router(riwayat_router)
app.include_router(yazu_router)
app.include_router(ewacs_router)
app.include_router(ss_router)
app.include_router(proker_router)
app.include_router(booster_router)

# ─── Scheduler: yazu sync 06:00 & 18:00 Asia/Makassar (GMT+8) ───
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import logging as _log
_yazu_log = _log.getLogger("yazu.scheduler")
_scheduler: AsyncIOScheduler | None = None


async def _yazu_scheduled_sync():
    async with SessionLocal() as db:
        try:
            r = await do_sync(db)
            _yazu_log.info("yazu scheduled sync OK: %s", r)
        except Exception as e:
            _yazu_log.exception("yazu scheduled sync error: %s", e)
