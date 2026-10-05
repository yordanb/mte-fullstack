from fastapi import FastAPI
from sqlalchemy import text
from app.api.v1.results import router as results_router
from app.api.v1.fleet import router as fleet_router
from app.api.v1.imports import router as imports_router
from app.api.v1.auth import router as auth_router
from app.api.v1.dbr import router as dbr_router
from app.core.config import settings
from app.core.security import hash_pw
from app.db.session import engine

app = FastAPI(title="MTE Oil Lab API", version="1.0.0")

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
