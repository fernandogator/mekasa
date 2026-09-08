"""Mekasa API entrypoint."""

from fastapi import FastAPI

from app.config import get_settings
from app.routers import (
    api_router,
    barcode_router,
    health_router,
    inventory_router,
    shopping_list_router,
)


def create_app() -> FastAPI:
    """Build the FastAPI application."""
    settings = get_settings()
    application = FastAPI(
        title="Mekasa API",
        version="0.4.0",
        description=(
            "Mekasa API: Firebase Auth, household onboarding, inventory CRUD, "
            "shopping list sync, and Open Food Facts barcode lookup."
        ),
    )
    application.include_router(health_router)
    application.include_router(api_router)
    application.include_router(inventory_router)
    application.include_router(shopping_list_router)
    application.include_router(barcode_router)
    application.state.settings = settings  # type: ignore[attr-defined]
    return application


app = create_app()
