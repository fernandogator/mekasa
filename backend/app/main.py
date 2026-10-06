"""Mekasa API entrypoint."""

import logging

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from app.barcode_lookup import clear_lookup_cache
from app.capture_routes import capture_router
from app.catalog_repository import CatalogSaltMissing
from app.catalog_routes import products_router
from app.config import get_settings
from app.observability import RequestTracingMiddleware, configure_logging
from app.product_photo_routes import product_photos_router
from app.routers import (
    api_router,
    barcode_router,
    health_router,
    inventory_router,
    shopping_list_router,
    spending_router,
)

logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    """Build the FastAPI application."""
    settings = get_settings()
    configure_logging(settings.log_level, settings.log_format, settings.gcp_project_id)
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
    application.include_router(products_router)
    application.include_router(product_photos_router)
    application.include_router(capture_router)
    application.add_exception_handler(CatalogSaltMissing, _catalog_salt_missing)
    application.add_middleware(RequestTracingMiddleware)
    application.state.settings = settings  # type: ignore[attr-defined]
    return application


async def _catalog_salt_missing(_request: Request, exc: Exception) -> JSONResponse:
    logger.error("Catalog write refused: %s (REQ-RCP-009 AC5)", exc)
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"detail": "catalog_unavailable"},
    )


app = create_app()
