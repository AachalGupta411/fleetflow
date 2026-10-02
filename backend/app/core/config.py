from functools import lru_cache
from pathlib import Path

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    """Runtime configuration loaded from the environment and backend/.env."""

    model_config = SettingsConfigDict(
        env_file=BACKEND_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    app_env: str = "development"
    database_url: str
    jwt_secret: str
    jwt_expire_minutes: int = 720
    cors_origins: str = "http://127.0.0.1:8000,http://localhost:8000"
    google_maps_api_key: str = Field(default="", validation_alias="GOOGLE_MAPS_API_KEY")
    geofence_radius_meters: int = 100
    storage_provider: str = "local"
    storage_local_dir: str = ""
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_bucket: str = "fleetflow-pod"
    firebase_credentials_file: str = ""

    @field_validator("google_maps_api_key", "firebase_credentials_file", mode="before")
    @classmethod
    def strip_optional_setting(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip()
        return value

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @model_validator(mode="after")
    def production_guards(self):
        if self.app_env.lower() != "production":
            return self
        if "*" in self.cors_origin_list:
            raise ValueError("Set explicit CORS_ORIGINS when APP_ENV is production")
        if len(self.jwt_secret) < 32:
            raise ValueError("JWT_SECRET must be at least 32 characters when APP_ENV is production")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
