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
    # memory | firestore | auto (prod → firestore, else memory)
    household_persistence: str = "auto"
    # Receipt scanning with Gemini on Vertex AI (needs gcp_project_id + ADC).
    # Gemini 3.x Pro previews are served only from the "global" location.
    receipt_llm_enabled: bool = True
    gemini_receipt_model: str = "gemini-3.1-pro-preview"
    gemini_location: str = "global"
    gemini_timeout_seconds: float = 45.0
    # Postgres (Cloud SQL) for data shared across all accounts: per-store item
    # / UPC tables. Unset → in-memory (local + tests).
    # Cloud Run: postgresql://USER:PASS@/DB?host=/cloudsql/PROJECT:REGION:INSTANCE
    database_url: str | None = None
    database_pool_size: int = 5


@lru_cache
def get_settings() -> Settings:
    """Return cached settings."""
    return Settings()
