"""
Fixed household categories.

Satisfies: REQ-017 (Spending Categorization)
Acceptance criteria: AC4
Spec version: 1.0

Inventory items, receipt lines, purchases and catalog products store only
these eight values. Finer labels from the receipt parser, UPC lookup or the
catalog are mapped before storage; anything unrecognised becomes "Other".
"""

from __future__ import annotations

from typing import Annotated

from pydantic import AfterValidator

CATEGORIES: tuple[str, ...] = (
    "Produce",
    "Dairy",
    "Pantry",
    "Meat",
    "Frozen",
    "Beverages",
    "Household",
    "Other",
)

_CANONICAL = {name.casefold(): name for name in CATEGORIES}

FINER_CATEGORY_MAP: dict[str, str] = {
    "bakery": "Pantry",
    "snacks": "Pantry",
    "seafood": "Meat",
    "alcohol": "Beverages",
    "personal care": "Household",
    "baby": "Household",
    "pet": "Household",
}


def normalize_category(value: str | None) -> str:
    """
    Satisfies: REQ-017 AC4

    Map any category label onto the fixed list (case-insensitive).
    """
    key = " ".join((value or "").split()).casefold()
    if not key:
        return "Other"
    return _CANONICAL.get(key) or FINER_CATEGORY_MAP.get(key) or "Other"


def _normalize_optional(value: str | None) -> str | None:
    return None if value is None else normalize_category(value)


Category = Annotated[str, AfterValidator(normalize_category)]
"""A model field that always holds one of :data:`CATEGORIES`."""

OptionalCategory = Annotated[str | None, AfterValidator(_normalize_optional)]
"""Like :data:`Category`, but ``None`` (field not sent) passes through."""
