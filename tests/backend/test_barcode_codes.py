"""Unit tests for GTIN normalisation used by barcode lookup (REQ-004)."""

from app.barcode_codes import candidates, expand_upce, gtin_check_digit, is_valid_gtin


def test_gtin_check_digit_matches_known_codes() -> None:
    assert gtin_check_digit("004900000634") == "6"  # Coca-Cola 12 oz can (EAN-13 form)
    assert gtin_check_digit("301762401070") == "1"  # Nutella
    assert is_valid_gtin("0049000006346")
    assert is_valid_gtin("049000006346")
    assert not is_valid_gtin("049000006345")


def test_expand_upce_coke_can() -> None:
    """The UPC-E printed on a Coke can expands to the UPC-A most databases store."""
    assert expand_upce("04963406") == "049000006346"


def test_expand_upce_reference_vectors() -> None:
    assert expand_upce("01278907") == "012000007897"  # last digit 7 → product 0000d6
    assert expand_upce("1278907") == "012000007897"  # number system dropped by SDK
    assert expand_upce("127890") == "012000007897"  # 6 digits → check digit computed
    assert expand_upce("04252614") == "042100005264"  # d6 = 1 → manufacturer d1 d2 d6 0 0
    assert expand_upce("02345632") == "023400000562"  # d6 = 3 → manufacturer 3 digits
    assert expand_upce("04252644") == "042520000064"  # d6 = 4 → manufacturer 4 digits


def test_expand_upce_rejects_other_shapes() -> None:
    assert expand_upce("5449000000996") is None
    assert expand_upce("24963406") is None  # number system must be 0 or 1
    assert expand_upce("") is None


def test_candidates_upce_tries_expanded_forms_first() -> None:
    assert candidates("04963406") == ["0049000006346", "049000006346", "04963406"]


def test_candidates_upca_and_ean13_are_equivalent() -> None:
    assert candidates("049000006346") == ["0049000006346", "049000006346"]
    assert candidates("0049000006346") == ["0049000006346", "049000006346"]
    assert candidates("0049-0000-06346") == ["0049000006346", "049000006346"]


def test_candidates_ean13_and_gtin14() -> None:
    assert candidates("5449000000996") == ["5449000000996"]
    assert candidates("00049000006346") == ["00049000006346", "0049000006346"]


def test_candidates_genuine_ean8_keeps_raw_when_expansion_is_invalid() -> None:
    # 12345678 would expand to an invalid GTIN → only the raw EAN-8 is tried.
    assert candidates("12345678") == ["12345678"]


def test_candidates_rejects_short_codes() -> None:
    assert candidates("12345") == []
    assert candidates("") == []
    assert candidates(None) == []
