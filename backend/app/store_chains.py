"""
Printed store name → `store_chains.chain_id`.

Satisfies: REQ-RCP-007 AC5
Spec version: 1.0

Mirrors `backend/postgres/seed/store_chains.sql` (kept in step by
`tests/backend/test_store_chains.py`) so the receipt scan can scope alias
lookups without a database round trip. `product_aliases.store_chain_id`
references `store_chains`, so anything else resolves to `unknown`.
"""

from __future__ import annotations

import re

from app.catalog_repository import SHARED_CHAIN_ID

STORE_CHAINS: dict[str, tuple[str, ...]] = {
    "heb": ("H-E-B", "HEB", "H-E-B Food-Drugs", "Central Market", "Mi Tienda"),
    "publix": ("Publix", "PUBLIX SUPER MARKETS"),
    "walmart": ("Walmart", "WAL-MART", "Walmart Supercenter", "Walmart Neighborhood Market"),
    "costco": ("Costco", "COSTCO WHOLESALE"),
    "kroger": ("Kroger", "Ralphs", "Fry's", "King Soopers", "Smith's", "Fred Meyer", "Harris Teeter"),
    "target": ("Target",),
}


def _words(text: str) -> str:
    joined = re.sub(r"[-'’.]", "", text.casefold())
    return " ".join(re.sub(r"[^a-z0-9]+", " ", joined).split())


_PATTERNS: list[tuple[str, str]] = sorted(
    ((chain_id, _words(alias)) for chain_id, aliases in STORE_CHAINS.items() for alias in aliases),
    key=lambda pair: -len(pair[1]),
)


def resolve_store_chain(store_name: str | None) -> str:
    """Whole-word match of a chain name or alias inside the printed store name."""
    name = f" {_words(store_name or '')} "
    if not name.strip():
        return SHARED_CHAIN_ID
    for chain_id, alias in _PATTERNS:
        if f" {alias} " in name:
            return chain_id
    return SHARED_CHAIN_ID


def known_chain(store_chain_id: str | None) -> str:
    """A client-supplied chain id, or `unknown` when it is not seeded."""
    value = (store_chain_id or "").strip().casefold()
    return value if value in STORE_CHAINS else SHARED_CHAIN_ID
