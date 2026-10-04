from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import verify_pw, make_token, make_refresh, decode_token
from app.core.deps import get_current_user
from app.db.session import get_db

router = APIRouter(prefix="/v1/auth", tags=["auth"])

class LoginIn(BaseModel):
    username: str
    password: str

@router.post("/login")
async def login(body: LoginIn, db: AsyncSession = Depends(get_db)):
    row = (await db.execute(
        text("SELECT id, username, password_hash, role FROM users WHERE username=:u"),
        {"u": body.username.strip()})).mappings().first()
    if not row or not verify_pw(body.password, row["password_hash"]):
        raise HTTPException(401, "Username/password salah")
    return {"access_token": make_token(str(row["id"]), row["role"]),
            "refresh_token": make_refresh(str(row["id"])),
            "role": row["role"], "username": row["username"]}

class RefreshIn(BaseModel):
    refresh_token: str

@router.post("/refresh")
async def refresh(body: RefreshIn, db: AsyncSession = Depends(get_db)):
    try:
        p = decode_token(body.refresh_token)
        assert p.get("typ") == "refresh"
    except Exception:
        raise HTTPException(401, "Refresh tidak valid")
    row = (await db.execute(text("SELECT id, role FROM users WHERE id::text=:s"),
                            {"s": p["sub"]})).mappings().first()
    if not row:
        raise HTTPException(401, "User tidak ada")
    return {"access_token": make_token(str(row["id"]), row["role"])}

@router.get("/me")
async def me(user=Depends(get_current_user)):
    return user
