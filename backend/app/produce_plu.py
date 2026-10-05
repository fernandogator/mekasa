"""
Standard produce PLU codes (IFPS) bundled with the API.

Satisfies: REQ-RCP-022 (Standard Produce PLU List) AC1, AC2, AC3, AC4
Spec version: 1.0

`data/plu_codes.json` is the IFPS-derived list from github.com/ankane/plu
(MIT, see `data/plu_codes.LICENSE.txt`; commit 8dd9c1d). Open Food Facts is not
used for PLUs: its entries are user-contributed and often foreign-language.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

from app.catalog_repository import normalize_name

_DATA = Path(__file__).resolve().parent / "data" / "plu_codes.json"
_NAME_LIMIT = 120
# Words that describe size, grade or organic status; they never identify the produce.
_GENERIC_WORDS = frozenset({"organic", "org", "large", "small", "medium", "regular", "baby", "mini", "loose", "bunch"})


def _display_name(raw: str) -> str:
    without_notes = re.sub(r"\([^)]*\)?", " ", raw)
    return " ".join(without_notes.split())[:_NAME_LIMIT].strip(" -,/")


@lru_cache(maxsize=1)
def _codes() -> dict[str, str]:
    raw: dict[str, str] = json.loads(_DATA.read_text(encoding="utf-8"))
    return {
        code: _display_name(name)
        for code, name in raw.items()
        if not name.startswith("Retailer Assigned") and _display_name(name)
    }


def produce_name(code: str | None) -> str | None:
    """English name for a standard PLU; 9-prefixed 5-digit codes are organic (AC2)."""
    value = (code or "").strip()
    if re.fullmatch(r"[34][0-9]{3}", value):
        return _codes().get(value)
    if re.fullmatch(r"9[34][0-9]{3}", value):
        base = _codes().get(value[1:])
        return f"Organic {base}"[:_NAME_LIMIT] if base else None
    return None


def _singular(word: str) -> str:
    if word.endswith("ies") and len(word) > 4:
        return word[:-3] + "y"
    if word.endswith("oes") or word.endswith(("ches", "shes", "xes", "sses")):
        return word[:-2]
    if word.endswith("s") and not word.endswith("ss"):
        return word[:-1]
    return word


def _stems(text: str | None) -> set[str]:
    stems = set()
    for word in normalize_name(text or "").split():
        if word in _GENERIC_WORDS or len(word) < 3:
            continue
        stems.add(_singular(word))
    return stems


def looks_like(produce: str, *line_texts: str | None) -> bool:
    """True when the receipt line shares a word with the list name (AC4)."""
    wanted = _stems(produce)
    return any(wanted & _stems(text) for text in line_texts)
