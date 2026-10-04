from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://mte:mte@db:5432/mte"
    max_upload_mb: int = 20

    class Config:
        env_file = ".env"

settings = Settings()
