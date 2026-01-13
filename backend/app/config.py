from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    api_title: str = "SushiScout 26 API"
    api_version: str = "v1"
    
    # Database
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/sushiscout26"
    
    # Google Sheets
    google_service_account_json: str = "{}" # JSON string of service account key
    google_sheet_id: str = ""
    
    # Security
    secret_key: str = "change_this_secret_key_in_production"
    allowed_origins: list[str] = ["*"]

    class Config:
        env_file = ".env"

@lru_cache()
def get_settings():
    return Settings()
