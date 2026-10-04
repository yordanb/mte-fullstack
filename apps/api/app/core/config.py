from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://mte:mte@db:5432/mte"
    max_upload_mb: int = 20
    jwt_secret: str = "ganti-di-production"
    jwt_exp_min: int = 60
    jwt_refresh_days: int = 7
    admin_username: str = "admin"
    admin_password: str = "ganti-sekarang"

    class Config:
        env_file = ".env"

settings = Settings()
