"""Mekasa thin API entrypoint."""

from fastapi import FastAPI

from app.config import get_settings
from app.routers import api_router, health_router, inventory_router


def create_app() -> FastAPI:
    """Build the FastAPI application."""
    settings = get_settings()
    application = FastAPI(
        title="Mekasa API",
        version="0.2.0",
        description=(
            "Mekasa API: Firebase Auth, household onboarding, and household inventory CRUD "
            "(barcode/OCR lookup endpoints come later)."
        ),
    )
    application.include_router(health_router)
    application.include_router(api_router)
    application.include_router(inventory_router)
    application.state.settings = settings  # type: ignore[attr-defined]
    return application


app = create_app()
