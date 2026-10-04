from datetime import datetime, timedelta, timezone
import jwt
from passlib.context import CryptContext
from app.core.config import settings

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_pw(p: str) -> str:
    return pwd.hash(p)

def verify_pw(p: str, h: str) -> bool:
    return pwd.verify(p, h)

def make_token(sub: str, role: str, minutes: int | None = None) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=minutes or settings.jwt_exp_min)
    return jwt.encode({"sub": sub, "role": role, "exp": exp}, settings.jwt_secret, algorithm="HS256")

def make_refresh(sub: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(days=settings.jwt_refresh_days)
    return jwt.encode({"sub": sub, "typ": "refresh", "exp": exp}, settings.jwt_secret, algorithm="HS256")

def decode_token(t: str) -> dict:
    return jwt.decode(t, settings.jwt_secret, algorithms=["HS256"])
