"""
GTIN normalisation for product lookups (REQ-004).

Scanners hand us codes in several shapes for the *same* product:

* iOS VisionKit reports UPC-A as EAN-13 with a leading ``0`` (``0049000006346``).
* ML Kit reports UPC-A as 12 digits (``049000006346``).
* Both report UPC-E as the 8-digit compressed form (``04963406``), which Open Food
  Facts stores as a *separate* record from the expanded UPC-A most contributors save.

``candidates`` returns every equivalent code worth querying, most likely first.
"""

from __future__ import annotations

import re


def digits_only(code: str | None) -> str:
    return re.sub(r"\D", "", code or "")


def gtin_check_digit(body: str) -> str:
    """Mod-10 check digit for a GTIN body (all digits except the last)."""
    total = 0
    for index, char in enumerate(reversed(body)):
        weight = 3 if index % 2 == 0 else 1
        total += int(char) * weight
    return str((10 - total % 10) % 10)


def is_valid_gtin(code: str) -> bool:
    if not code.isdigit() or len(code) not in (8, 12, 13, 14):
        return False
    return gtin_check_digit(code[:-1]) == code[-1]


def expand_upce(code: str) -> str | None:
    """
    Expand an 8-digit UPC-E (number system + 6 digits + check) to 12-digit UPC-A.

    Returns None when the input is not a UPC-E shape. 7-digit inputs (some SDKs
    drop the number system) assume number system 0; 6-digit inputs additionally
    get a computed check digit.
    """
    code = digits_only(code)
    if len(code) == 6:
        body = _expand_body("0" + code)
        return None if body is None else body + gtin_check_digit(body)
    if len(code) == 7:
        code = "0" + code
    if len(code) != 8 or code[0] not in "01":
        return None
    body = _expand_body(code)
    if body is None:
        return None
    return body + code[7]


def _expand_body(code: str) -> str | None:
    """UPC-A body (11 digits, no check digit) for a UPC-E number system + 6 data digits."""
    if len(code) < 7 or code[0] not in "01":
        return None
    ns = code[0]
    d1, d2, d3, d4, d5, d6 = code[1:7]
    if d6 in "012":
        manufacturer = f"{d1}{d2}{d6}00"
        product = f"00{d3}{d4}{d5}"
    elif d6 == "3":
        manufacturer = f"{d1}{d2}{d3}00"
        product = f"000{d4}{d5}"
    elif d6 == "4":
        manufacturer = f"{d1}{d2}{d3}{d4}0"
        product = f"0000{d5}"
    else:
        manufacturer = f"{d1}{d2}{d3}{d4}{d5}"
        product = f"0000{d6}"
    return f"{ns}{manufacturer}{product}"


def candidates(code: str | None) -> list[str]:
    """
    Equivalent codes to try against product databases, best first.

    * 8 digits starting 0/1 → UPC-E: expanded EAN-13, UPC-A, then the raw 8 digits
      (it might also be a genuine EAN-8, so the raw form is still tried).
    * 12 digits (UPC-A) → 13-digit zero-padded, then 12.
    * 13 digits starting with 0 → also the 12-digit UPC-A form.
    * 14-digit GTIN-14 with a leading 0 → strip to 13.
    * Anything else with ≥ 6 digits is tried verbatim.
    """
    cleaned = digits_only(code)
    if len(cleaned) < 6:
        return []

    ordered: list[str] = []

    def _add(value: str | None) -> None:
        if value and value not in ordered:
            ordered.append(value)

    if len(cleaned) in (6, 7, 8):
        expanded = expand_upce(cleaned)
        if expanded and is_valid_gtin(expanded):
            _add("0" + expanded)
            _add(expanded)
        _add(cleaned)
    elif len(cleaned) == 12:
        _add("0" + cleaned)
        _add(cleaned)
    elif len(cleaned) == 13:
        _add(cleaned)
        if cleaned.startswith("0"):
            _add(cleaned[1:])
    elif len(cleaned) == 14:
        _add(cleaned)
        if cleaned.startswith("0"):
            _add(cleaned[1:])
    else:
        _add(cleaned)
    return ordered
