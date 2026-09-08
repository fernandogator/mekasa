"""Category → placeholder product image URLs (ADR-006 step 3).

Never hardcode these mappings inside request handlers.
"""

from __future__ import annotations

# Public placeholder art; replaced by real CDN assets later.
_PLACEHOLDER_BASE = "https://placehold.co/400x400/eeebe3/171e19/png"

CATEGORY_ICON_URLS: dict[str, str] = {
    "Produce": f"{_PLACEHOLDER_BASE}?text=Produce",
    "Dairy": f"{_PLACEHOLDER_BASE}?text=Dairy",
    "Pantry": f"{_PLACEHOLDER_BASE}?text=Pantry",
    "Meat": f"{_PLACEHOLDER_BASE}?text=Meat",
    "Frozen": f"{_PLACEHOLDER_BASE}?text=Frozen",
    "Beverages": f"{_PLACEHOLDER_BASE}?text=Beverages",
    "Household": f"{_PLACEHOLDER_BASE}?text=Household",
    "Other": f"{_PLACEHOLDER_BASE}?text=Item",
}

DEFAULT_CATEGORY_ICON_URL = CATEGORY_ICON_URLS["Other"]


def category_placeholder_url(category: str | None) -> str:
    """Return a guaranteed non-empty placeholder URL for a category."""
    if not category:
        return DEFAULT_CATEGORY_ICON_URL
    return CATEGORY_ICON_URLS.get(category.strip(), DEFAULT_CATEGORY_ICON_URL)
