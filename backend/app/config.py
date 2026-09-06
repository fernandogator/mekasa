"""Application settings loaded from environment variables."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration. Secrets never live in source."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "mekasa-api"
    environment: str = "local"
    gcp_project_id: str | None = None
    firebase_project_id: str | None = None
    # Named Firestore DB id (e.g. mekasa-db). Use "(default)" for the default DB.
    firestore_database_id: str = "mekasa-db"
    google_application_credentials: str | None = None
    allow_test_auth: bool = False
    google_places_api_key: str | None = None
    store_search_radius_miles: float = 15.0


@lru_cache
def get_settings() -> Settings:
    """Return cached settings."""
    return Settings()
