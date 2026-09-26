"""Mekasa API entrypoint."""

from fastapi import FastAPI

from app.barcode_lookup import clear_lookup_cache
from app.config import get_settings
from app.routers import (
    api_router,
    barcode_router,
    health_router,
    inventory_router,
    shopping_list_router,
    spending_router,
)


def create_app() -> FastAPI:
    """Build the FastAPI application."""
    settings = get_settings()
    clear_lookup_cache()
    application = FastAPI(
        title="Mekasa API",
        version="0.6.0",
        description=(
            "Mekasa API: Firebase Auth, household onboarding, inventory CRUD, "
            "shopping list sync, spending/purchase events, Places/OCR/invites, "
            "and Open Food Facts family barcode lookup."
        ),
    )
    application.include_router(health_router)
    application.include_router(api_router)
    application.include_router(inventory_router)
    application.include_router(shopping_list_router)
    application.include_router(spending_router)
    application.include_router(barcode_router)
    application.state.settings = settings  # type: ignore[attr-defined]
    return application


app = create_app()
