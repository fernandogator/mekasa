"""Mekasa thin onboarding API entrypoint."""

from fastapi import FastAPI

from app.config import get_settings
from app.routers import api_router, health_router


def create_app() -> FastAPI:
    """Build the FastAPI application."""
    settings = get_settings()
    application = FastAPI(
        title="Mekasa API",
        version="0.1.0",
        description=(
            "Thin onboarding API: Firebase Auth verification, household create, "
            "address confirm, nearby store selection."
        ),
    )
    application.include_router(health_router)
    application.include_router(api_router)
    application.state.settings = settings  # type: ignore[attr-defined]
    return application


app = create_app()
