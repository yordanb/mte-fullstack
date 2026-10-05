from pydantic import field_validator
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://mte:mte@db:5432/mte"
    max_upload_mb: int = 50
    jwt_secret: str = "ganti-di-production"
    jwt_exp_min: int = 60
    jwt_refresh_days: int = 7
    admin_username: str = "admin"
    admin_password: str = "ganti-sekarang"
    upload_dir: str = "/data/uploads"

    @field_validator("database_url", mode="before")
    @classmethod
    def _force_asyncpg(cls, v: str) -> str:
        # Kebal terhadap .env / shell yang menulis postgresql:// tanpa driver.
        # SQLAlchemy async engine butuh postgresql+asyncpg://
        if isinstance(v, str):
            v = v.strip().strip('"').strip("'")
            if v.startswith("postgres://"):
                v = "postgresql+asyncpg://" + v[len("postgres://"):]
            elif v.startswith("postgresql://"):
                v = "postgresql+asyncpg://" + v[len("postgresql://"):]
        return v

    class Config:
        env_file = ".env"

settings = Settings()
