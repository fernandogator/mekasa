"""
Shared product catalog repository — same assertions against both backends.

Satisfies: REQ-RCP-007, REQ-RCP-009 AC3, REQ-RCP-010 AC2, REQ-RCP-011,
REQ-RCP-013, REQ-RCP-014, REQ-RCP-019 AC3/AC5, REQ-RCP-020 AC2–AC4
Spec version: 1.0

The in-memory backend always runs. The Postgres backend runs when
``TEST_DATABASE_URL`` points at a scratch database (CI: ``services: postgres:16``);
it applies the real migrations from ``backend/postgres`` first.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import pytest

from app.catalog_repository import (
    CAPTURE_CONFIDENCE,
    InMemoryCatalogRepository,
    NoChanges,
    ReceiptLineSave,
    UpcTaken,
    compute_confidence,
    household_hash,
    llm_product_id,
    next_status,
    normalize_name,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
PG_DIR = REPO_ROOT / "backend" / "postgres"
TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL")

HH_A = household_hash("household-a", salt="test-salt")
HH_B = household_hash("household-b", salt="test-salt")
HH_C = household_hash("household-c", salt="test-salt")
PHOTO = "6f1c2d4e-8a3b-4c5d-9e7f-0a1b2c3d4e5f"


def _apply_sql(conn, path: Path) -> None:
    conn.execute(path.read_text())


@pytest.fixture(scope="session")
def pg_schema():
    if not TEST_DATABASE_URL:
        pytest.skip("TEST_DATABASE_URL not set")
    import psycopg

    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        _apply_sql(conn, PG_DIR / "migrations" / "0001_shared_products.sql")
        _apply_sql(conn, PG_DIR / "seed" / "store_chains.sql")
        _apply_sql(conn, PG_DIR / "migrations" / "0002_product_corrections.sql")
    yield TEST_DATABASE_URL


@pytest.fixture(params=["memory", "postgres"])
def repo(request):
    if request.param == "memory":
        yield InMemoryCatalogRepository()
        return
    url = request.getfixturevalue("pg_schema")
    import psycopg

    from app.catalog_repository import PostgresCatalogRepository

    with psycopg.connect(url, autocommit=True) as conn:
        conn.execute("TRUNCATE product_conflicts, enrichment_steps, enrichment_jobs, product_confirmations, product_aliases, products")
    repository = PostgresCatalogRepository(url, pool_size=2)
    yield repository
    repository.close()


def _pg_count(url: str, sql: str, params: tuple = ()) -> int:
    import psycopg

    with psycopg.connect(url) as conn:
        return conn.execute(sql, params).fetchone()[0]


def _jobs(repo) -> list[dict]:
    if isinstance(repo, InMemoryCatalogRepository):
        return repo.enrichment_jobs()
    import psycopg

    with psycopg.connect(TEST_DATABASE_URL) as conn:
        rows = conn.execute("SELECT product_id, trigger, status FROM enrichment_jobs ORDER BY created_at").fetchall()
    return [{"product_id": r[0], "trigger": r[1], "status": r[2]} for r in rows]


def _alias_target(repo, chain: str, raw: str) -> str | None:
    if isinstance(repo, InMemoryCatalogRepository):
        return repo.alias_target(chain, raw)
    import psycopg

    with psycopg.connect(TEST_DATABASE_URL) as conn:
        row = conn.execute(
            "SELECT product_id FROM product_aliases WHERE store_chain_id=%s AND alias=catalog_normalize_name(%s)",
            (chain, raw),
        ).fetchone()
    return row[0] if row else None


# --- pure rules -------------------------------------------------------------


def test_normalize_name_matches_sql_definition() -> None:
    assert normalize_name("  H-E-B Organics  CAULIFLOWER!! ") == "h e b organics cauliflower"
    assert normalize_name("Jalapeño Crème") == "jalapeno creme"
    assert normalize_name("***") == ""


def test_llm_id_is_chain_scoped() -> None:
    assert llm_product_id("heb", "milk") != llm_product_id("kroger", "milk")
    assert re.fullmatch(r"llm:[0-9a-f]{40}", llm_product_id("heb", "milk"))


def test_household_hash_is_salted_sha256() -> None:
    assert re.fullmatch(r"[0-9a-f]{64}", HH_A)
    assert household_hash("household-a", salt="other") != HH_A


def test_confidence_formula_clamped() -> None:
    assert compute_confidence("llm_ocr", 0, 0) == 0.4
    assert compute_confidence("gs1_registry", 5, 0) == 1.0
    assert compute_confidence("llm_ocr", 0, 9) == 0.0


@pytest.mark.parametrize(
    ("status", "count", "source", "has_upc", "expected"),
    [
        ("unverified", 1, "user_scan", True, "unverified"),
        ("unverified", 2, "user_scan", True, "pending"),
        ("unverified", 0, "store_api", True, "pending"),
        ("unverified", 1, "store_api", True, "verified"),  # chains: authoritative + 1 confirmation
        ("pending", 3, "user_scan", True, "verified"),
        ("pending", 3, "user_scan", False, "pending"),  # verified requires a UPC
        ("verified", 0, "llm_ocr", True, "verified"),  # never downgraded
    ],
)
def test_status_transitions(status, count, source, has_upc, expected) -> None:
    assert next_status(status, count, source, has_upc) == expected


# --- receipt save (design §4.1) --------------------------------------------


def test_receipt_save_creates_llm_rows_aliases_and_jobs_idempotently(repo) -> None:
    lines = [
        ReceiptLineSave(raw_text="HEB WHL MILK GAL", description="H-E-B Whole Milk", category="Dairy", parse_job_id="job-1", prompt_version="receipt_parse/v1"),
        ReceiptLineSave(raw_text="CAULIFLOWER", description="Cauliflower", category="Produce"),
        ReceiptLineSave(raw_text="COKE 12PK", description="Coca-Cola 12 pack", category="Beverages", product_id=None),
    ]
    ids = repo.save_receipt_lines("heb", lines)
    assert all(i.startswith("llm:") for i in ids)
    milk = repo.get_product(ids[0])
    assert milk is not None and milk.source == "llm_ocr" and milk.status == "unverified"
    assert milk.confidence_score == 0.4 and milk.origin_prompt_version == "receipt_parse/v1"
    assert _alias_target(repo, "heb", "HEB WHL MILK GAL") == ids[0]
    assert repo.lookup_alias("heb", "heb whl milk gal").id == ids[0]
    assert repo.lookup_alias("kroger", "HEB WHL MILK GAL") is None  # alias is chain-scoped (REQ-RCP-007 AC2)

    jobs = _jobs(repo)
    assert len(jobs) == 3 and {j["trigger"] for j in jobs} == {"unmatched_line"}

    # Second save of the same receipt: no new rows, no new jobs (REQ-RCP-009 AC3)
    assert repo.save_receipt_lines("heb", lines) == ids
    assert len(_jobs(repo)) == 3


def test_receipt_save_with_resolved_product_only_records_alias(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    ids = repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="COKE 12PK", description="Coke", category="Beverages", product_id="041220576037")])
    assert ids == ["041220576037"]
    assert _alias_target(repo, "heb", "COKE 12PK") == "041220576037"


def test_alias_never_repoints_to_a_different_product(repo) -> None:
    repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="MILK", description="Whole Milk", category="Dairy")])
    first = _alias_target(repo, "heb", "MILK")
    repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="MILK", description="Oat Milk", category="Dairy")])
    assert _alias_target(repo, "heb", "MILK") == first  # §9.11: existing mapping wins


# --- confirmations and status (REQ-RCP-011/013) ----------------------------


def test_confirmation_counts_once_per_household_and_transitions(repo) -> None:
    created = repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    assert created.outcome == "created" and created.confirmation_counted
    assert created.product.confirmation_count == 1 and created.product.status == "unverified"
    assert created.product.confidence_score == CAPTURE_CONFIDENCE

    again = repo.confirm("041220576037", HH_A)
    assert not again.confirmation_counted and again.product.confirmation_count == 1

    second = repo.confirm("041220576037", HH_B)
    assert second.confirmation_counted and second.status_changed
    assert second.product.status == "pending" and second.product.status_changed_at is not None
    assert second.product.confidence_score == compute_confidence("user_scan", 2, 0)

    third = repo.confirm("041220576037", HH_C)
    assert third.product.status == "verified"


def test_catalog_holds_only_hashes(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    if TEST_DATABASE_URL and not isinstance(repo, InMemoryCatalogRepository):
        import psycopg

        with psycopg.connect(TEST_DATABASE_URL) as conn:
            hashes = [r[0] for r in conn.execute("SELECT household_hash FROM product_confirmations").fetchall()]
        assert hashes == [HH_A]
        with pytest.raises(psycopg.errors.CheckViolation):
            with psycopg.connect(TEST_DATABASE_URL) as conn:
                conn.execute("INSERT INTO product_confirmations (product_id, household_hash) VALUES ('041220576037', 'household-a')")
    else:
        assert re.fullmatch(r"[0-9a-f]{64}", HH_A)


# --- re-key llm: → UPC (REQ-RCP-010 AC2) -----------------------------------


def test_rekey_merges_confirmations_aliases_and_supersedes(repo) -> None:
    [llm_id] = repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="COKE 12PK", description="Coca-Cola 12 pack", category="Beverages")])
    repo.confirm(llm_id, HH_A)
    repo.confirm(llm_id, HH_B)

    product = repo.rekey_to_upc(llm_id, "049000028904", "store_api", 0.8)
    assert product.id == "049000028904" and product.upc == "049000028904" and product.code_kind == "upc"
    assert product.confirmation_count == 2
    assert set(product.sources_seen) >= {"llm_ocr", "store_api"}
    assert product.status == "verified"  # authoritative + ≥1 confirmation (REQ-RCP-011 AC2)

    old = repo.get_product(llm_id, follow_superseded=False)
    assert old is not None and old.superseded_by == "049000028904"
    assert repo.get_product(llm_id).id == "049000028904"  # readers follow superseded_by
    assert _alias_target(repo, "heb", "COKE 12PK") == "049000028904"

    # Re-keying the same llm row again is a no-op that returns the successor
    assert repo.rekey_to_upc(llm_id, "049000028904", "store_api", 0.8).id == "049000028904"


def test_rekey_into_existing_upc_row_merges_without_double_counting(repo) -> None:
    repo.capture(store_chain_id="heb", upc="049000028904", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    [llm_id] = repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="COKE 12PK", description="Coca-Cola 12 pack", category="Beverages")])
    repo.confirm(llm_id, HH_A)  # same household as the UPC row
    repo.confirm(llm_id, HH_B)
    product = repo.rekey_to_upc(llm_id, "049000028904", "user_scan", 0.7)
    assert product.confirmation_count == 2  # A once, B once


# --- capture (REQ-RCP-020) -------------------------------------------------


def test_capture_unknown_upc_creates_user_scan_product_with_photo_and_job(repo) -> None:
    result = repo.capture(
        store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Cauliflower", fallback_category="Produce",
        alias_text="CAULIFLOWER", name="H-E-B Organics Cauliflower", photo_id=PHOTO,
    )
    assert result.outcome == "created" and result.photo_applied_as == "product_image"
    p = result.product
    assert p.source == "user_scan" and p.sources_seen == ["user_scan"] and p.confidence_score == CAPTURE_CONFIDENCE
    assert p.name == "H-E-B Organics Cauliflower" and p.category == "Produce"
    assert p.image_url == f"/v1/product-photos/{PHOTO}" and p.image_source == "user_photo"
    assert result.enrichment_job_id is not None
    assert [j["trigger"] for j in _jobs(repo)] == ["user_capture"]
    assert _alias_target(repo, "heb", "CAULIFLOWER") == "041220576037"


def test_capture_alias_goes_under_alias_chain_and_is_found_by_lookup(repo) -> None:
    """REQ-RCP-020 AC6, REQ-RCP-007 AC5: shared product, chain-scoped alias."""
    result = repo.capture(
        store_chain_id="unknown", upc="0070852993188", hh=HH_A, fallback_name="A2 Milk", fallback_category="Dairy",
        alias_text="A2 MLK WHL 59OZ", alias_store_chain_id="heb", photo_id=PHOTO,
    )
    assert result.product.store_chain_id == "unknown"
    assert _alias_target(repo, "heb", "A2 MLK WHL 59OZ") == "0070852993188"
    assert _alias_target(repo, "unknown", "A2 MLK WHL 59OZ") is None
    found = repo.lookup_alias("heb", "a2 mlk  whl 59oz")
    assert found is not None and found.image_url == f"/v1/product-photos/{PHOTO}"
    assert repo.lookup_alias("walmart", "A2 MLK WHL 59OZ") is None

    repo.capture(
        store_chain_id="unknown", plu_code="4011", hh=HH_A, fallback_name="Bananas", fallback_category="Produce",
        alias_text="A2 MLK WHL 59OZ", alias_store_chain_id="heb",
    )
    assert _alias_target(repo, "heb", "A2 MLK WHL 59OZ") == "0070852993188"  # never re-pointed


def test_capture_known_upc_links_and_counts(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    result = repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_B, fallback_name="ignored", fallback_category="ignored", name="also ignored")
    assert result.outcome == "linked" and result.confirmation_counted
    assert result.product.name == "Coke" and result.product.confirmation_count == 2
    assert result.enrichment_job_id is None
    assert len(_jobs(repo)) == 1


def test_capture_photo_on_product_with_image_stays_on_line_or_becomes_conflict(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages", photo_id=PHOTO)
    other = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"
    res = repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_B, fallback_name="x", fallback_category="x", photo_id=other)
    assert res.photo_applied_as == "line_image" and res.conflict is None
    assert res.product.image_url == f"/v1/product-photos/{PHOTO}"

    repo.confirm("041220576037", HH_C)  # → verified (3 households)
    res = repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_C, fallback_name="x", fallback_category="x", photo_id=other, receipt_id="r1", line_item_id="l1")
    assert res.product.status == "verified"
    assert res.photo_applied_as == "correction_proposed" and res.conflict is not None
    assert res.conflict.field == "image_url" and res.conflict.observed_value == f"/v1/product-photos/{other}"


def test_capture_rekeys_previous_llm_product(repo) -> None:
    [llm_id] = repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="CAULIFLOWER", description="Cauliflower", category="Produce")])
    result = repo.capture(
        store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Cauliflower", fallback_category="Produce",
        previous_product_id=llm_id, brand="H-E-B",
    )
    assert result.outcome == "rekeyed"
    assert result.product.id == "041220576037" and result.product.brand == "H-E-B"
    assert result.product.confirmation_count == 1
    assert repo.get_product(llm_id).id == "041220576037"
    assert _alias_target(repo, "heb", "CAULIFLOWER") == "041220576037"
    triggers = sorted(j["trigger"] for j in _jobs(repo))
    assert "user_capture" in triggers


def test_capture_rejects_bad_upc(repo) -> None:
    with pytest.raises(ValueError, match="invalid_upc"):
        repo.capture(store_chain_id="heb", upc="12ab", hh=HH_A, fallback_name="x", fallback_category="x")


# --- corrections (REQ-RCP-019 AC3) -----------------------------------------


def test_correction_on_unverified_applies_and_resets_identity(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Caulflower", fallback_category="Frozen")
    res = repo.correct(product_id="041220576037", hh=HH_B, changes={"category": "Produce", "unit_size": "1 head"})
    assert res.applied and res.status_reset  # category is an identity field
    assert res.product.category == "Produce" and res.product.unit_size == "1 head"
    assert res.product.confirmation_count == 0 and res.product.status == "unverified"
    assert "user_scan" in res.product.sources_seen

    # the household can confirm the corrected facts afresh
    assert repo.confirm("041220576037", HH_A).confirmation_counted

    res = repo.correct(product_id="041220576037", hh=HH_B, changes={"unit_size": "2 heads"})
    assert res.applied and not res.status_reset  # unit_size alone keeps confirmations
    assert res.product.confirmation_count == 1


def test_correction_with_photo_sets_user_image(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    res = repo.correct(product_id="041220576037", hh=HH_A, changes={}, photo_id=PHOTO)
    assert res.applied and not res.status_reset
    assert res.product.image_url == f"/v1/product-photos/{PHOTO}" and res.product.image_source == "user_photo"


def test_correction_on_verified_files_conflicts_only(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    repo.confirm("041220576037", HH_B)
    verified = repo.confirm("041220576037", HH_C).product
    assert verified.status == "verified"

    res = repo.correct(
        product_id="041220576037", hh=HH_A, changes={"category": "Soda", "name": "Coca-Cola"},
        photo_id=PHOTO, receipt_id="r1", line_item_id="l1",
    )
    assert not res.applied
    assert {c.field for c in res.conflicts} == {"category", "name", "image_url"}
    untouched = repo.get_product("041220576037")
    assert untouched.category == "Beverages" and untouched.name == "Coke" and untouched.image_url is None
    assert untouched.status == "verified" and untouched.confirmation_count == 3


def test_correction_rejects_no_changes_and_taken_upc(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages")
    repo.capture(store_chain_id="heb", upc="049000028904", hh=HH_A, fallback_name="Coke Zero", fallback_category="Beverages")
    with pytest.raises(NoChanges):
        repo.correct(product_id="041220576037", hh=HH_A, changes={"name": "Coke"})
    with pytest.raises(UpcTaken):
        repo.correct(product_id="041220576037", hh=HH_A, changes={"upc": "049000028904"})


def test_correction_upc_on_llm_product_rekeys(repo) -> None:
    [llm_id] = repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="COKE 12PK", description="Coca-Cola 12 pack", category="Beverages")])
    res = repo.correct(product_id=llm_id, hh=HH_A, changes={"upc": "049000028904"})
    assert res.applied and res.status_reset
    assert res.product.id == "049000028904" and res.product.code_kind == "upc"
    assert repo.get_product(llm_id).id == "049000028904"


# --- search (REQ-RCP-007 fuzzy step) ---------------------------------------


def test_search_is_fuzzy_chain_scoped_and_skips_superseded(repo) -> None:
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="H-E-B Whole Milk", fallback_category="Dairy", brand="H-E-B")
    repo.capture(store_chain_id="kroger", upc="011110000002", hh=HH_A, fallback_name="Kroger Whole Milk", fallback_category="Dairy", brand="Kroger")
    [llm_id] = repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="WHL MILK", description="Whole Milk Gallon", category="Dairy")])
    repo.rekey_to_upc(llm_id, "041220576037", "user_scan", 0.7)

    all_hits = repo.search("whole milk")
    assert {p.id for p in all_hits} == {"041220576037", "011110000002"}
    heb_hits = repo.search("whole milk", store_chain_id="heb")
    assert [p.id for p in heb_hits] == ["041220576037"]
    assert repo.search("whole milk", status="verified") == []
    assert repo.search("zzzz qqqq") == []


def test_release_user_photo_clears_only_that_user_photo(repo) -> None:
    """REQ-RCP-021 AC5: deleting a product photo drops it from products that use it."""
    repo.capture(store_chain_id="heb", upc="041220576037", hh=HH_A, fallback_name="Coke", fallback_category="Beverages", photo_id=PHOTO)
    repo.capture(store_chain_id="heb", upc="049000028904", hh=HH_A, fallback_name="Coke Zero", fallback_category="Beverages")

    assert repo.release_user_photo(PHOTO) == 1
    cleared = repo.get_product("041220576037")
    assert cleared.image_url is None and cleared.image_source is None
    assert repo.release_user_photo(PHOTO) == 0


# --- PLU capture (REQ-RCP-020 AC7) -------------------------------------------


def test_plu_capture_creates_one_shared_product_across_chains(repo) -> None:
    created = repo.capture(
        store_chain_id="heb", plu_code="4011", hh=HH_A, fallback_name="Bananas", fallback_category="Produce",
        alias_text="BANANAS", photo_id=PHOTO,
    )
    product = created.product
    assert created.outcome == "created"
    assert (product.id, product.code_kind, product.plu_code, product.upc) == ("plu:4011", "plu", "4011", None)
    assert product.store_chain_id == "unknown"
    assert product.source == "user_scan" and product.confidence_score == CAPTURE_CONFIDENCE
    assert product.image_url == f"/v1/product-photos/{PHOTO}" and created.photo_applied_as == "product_image"
    assert created.enrichment_job_id is None and _jobs(repo) == []
    assert _alias_target(repo, "heb", "BANANAS") == "plu:4011"

    linked = repo.capture(store_chain_id="walmart", plu_code="4011", hh=HH_B, fallback_name="x", fallback_category="Produce")
    assert linked.outcome == "linked" and linked.product.id == "plu:4011" and linked.confirmation_counted


def test_plu_product_stays_at_most_pending(repo) -> None:
    for hh in (HH_A, HH_B, HH_C, household_hash("household-d", salt="test-salt")):
        result = repo.capture(store_chain_id="heb", plu_code="94011", hh=hh, fallback_name="Organic Bananas", fallback_category="Produce")
    assert result.product.confirmation_count == 4
    assert result.product.status == "pending"


def test_capture_requires_exactly_one_valid_code(repo) -> None:
    with pytest.raises(ValueError, match="exactly_one_code_required"):
        repo.capture(store_chain_id="heb", hh=HH_A, fallback_name="x", fallback_category="Produce")
    with pytest.raises(ValueError, match="exactly_one_code_required"):
        repo.capture(store_chain_id="heb", upc="041220576037", plu_code="4011", hh=HH_A, fallback_name="x", fallback_category="Produce")
    with pytest.raises(ValueError, match="invalid_plu"):
        repo.capture(store_chain_id="heb", plu_code="401", hh=HH_A, fallback_name="x", fallback_category="Produce")


def test_capture_without_code_creates_the_chain_product_with_the_photo(repo) -> None:
    """REQ-RCP-020 AC15: receipt text + photo, no UPC/PLU."""
    result = repo.capture(
        store_chain_id="unknown", hh=HH_A, fallback_name="Deli Turkey", fallback_category="Deli",
        alias_text="HEB DELI TRKY BRST", alias_store_chain_id="heb", photo_id=PHOTO,
    )
    product = result.product
    assert result.outcome == "created" and result.photo_applied_as == "product_image"
    assert product.id == llm_product_id("heb", "deli turkey") and product.code_kind == "llm"
    assert (product.store_chain_id, product.upc, product.plu_code) == ("heb", None, None)
    assert (product.source, product.confidence_score) == ("user_scan", CAPTURE_CONFIDENCE)
    assert product.image_url == f"/v1/product-photos/{PHOTO}" and product.image_source == "user_photo"
    assert result.enrichment_job_id is None and _jobs(repo) == []
    assert _alias_target(repo, "heb", "HEB DELI TRKY BRST") == product.id
    assert _alias_target(repo, "unknown", "HEB DELI TRKY BRST") is None
    assert repo.lookup_alias("heb", "heb deli trky brst").id == product.id


def test_capture_without_code_links_the_existing_alias(repo) -> None:
    """REQ-RCP-020 AC15: a second household links the same product; its photo is only the line image."""
    first = repo.capture(
        store_chain_id="unknown", hh=HH_A, fallback_name="Deli Turkey", fallback_category="Deli",
        alias_text="HEB DELI TRKY BRST", alias_store_chain_id="heb", photo_id=PHOTO,
    )
    second = repo.capture(
        store_chain_id="unknown", hh=HH_B, fallback_name="Turkey breast", fallback_category="Deli",
        alias_text="heb deli trky brst", alias_store_chain_id="heb",
        photo_id="7a2b3c4d-1111-4c5d-9e7f-0a1b2c3d4e5f",
    )
    assert second.outcome == "linked" and second.product.id == first.product.id
    assert second.photo_applied_as == "line_image"
    assert second.product.image_url == f"/v1/product-photos/{PHOTO}"
    assert second.product.confirmation_count == 2


def test_capture_without_code_is_per_chain(repo) -> None:
    heb = repo.capture(
        store_chain_id="unknown", hh=HH_A, fallback_name="Deli Turkey", fallback_category="Deli",
        alias_text="DELI TRKY", alias_store_chain_id="heb",
    )
    walmart = repo.capture(
        store_chain_id="unknown", hh=HH_A, fallback_name="Deli Turkey", fallback_category="Deli",
        alias_text="DELI TRKY", alias_store_chain_id="walmart",
    )
    assert heb.product.id != walmart.product.id
    assert walmart.product.store_chain_id == "walmart"


def test_upc_capture_rekeys_a_photo_only_product(repo) -> None:
    """REQ-RCP-020 AC15 + AC3: the later barcode re-keys the llm product and its alias."""
    first = repo.capture(
        store_chain_id="unknown", hh=HH_A, fallback_name="Deli Turkey", fallback_category="Deli",
        alias_text="HEB DELI TRKY BRST", alias_store_chain_id="heb", photo_id=PHOTO,
    )
    later = repo.capture(
        store_chain_id="unknown", upc="041220576037", hh=HH_A, fallback_name="Deli Turkey",
        fallback_category="Deli", previous_product_id=first.product.id,
    )
    assert later.outcome == "rekeyed" and later.product.id == "041220576037"
    assert later.product.image_url == f"/v1/product-photos/{PHOTO}"
    assert repo.get_product(first.product.id, follow_superseded=False).superseded_by == "041220576037"
    assert _alias_target(repo, "heb", "HEB DELI TRKY BRST") == "041220576037"


def test_plu_capture_rekeys_a_photo_only_product(repo) -> None:
    """REQ-RCP-020 AC15: a PLU typed later takes over the photo-only product, photo and alias."""
    first = repo.capture(
        store_chain_id="unknown", hh=HH_A, fallback_name="Honeycrisp", fallback_category="Produce",
        alias_text="HONEYCRISP APL", alias_store_chain_id="heb", photo_id=PHOTO,
    )
    later = repo.capture(
        store_chain_id="unknown", plu_code="3283", hh=HH_A, fallback_name="Honeycrisp",
        fallback_category="Produce", previous_product_id=first.product.id,
    )
    assert later.outcome == "rekeyed" and later.product.id == "plu:3283"
    assert later.product.code_kind == "plu" and later.product.store_chain_id == "unknown"
    assert later.product.image_url == f"/v1/product-photos/{PHOTO}"
    assert repo.get_product(first.product.id, follow_superseded=False).superseded_by == "plu:3283"
    assert _alias_target(repo, "heb", "HONEYCRISP APL") == "plu:3283"


def test_rekey_keeps_the_photo_when_the_code_product_has_none(repo) -> None:
    repo.capture(store_chain_id="unknown", upc="041220576037", hh=HH_B, fallback_name="Turkey", fallback_category="Deli")
    first = repo.capture(
        store_chain_id="unknown", hh=HH_A, fallback_name="Deli Turkey", fallback_category="Deli",
        alias_text="DELI TRKY", alias_store_chain_id="heb", photo_id=PHOTO,
    )
    later = repo.capture(
        store_chain_id="unknown", upc="041220576037", hh=HH_A, fallback_name="Deli Turkey",
        fallback_category="Deli", previous_product_id=first.product.id,
    )
    assert later.outcome == "rekeyed"
    assert later.product.image_url == f"/v1/product-photos/{PHOTO}"


def test_upc_capture_never_rekeys_a_plu_product(repo) -> None:
    repo.capture(store_chain_id="heb", plu_code="4011", hh=HH_A, fallback_name="Bananas", fallback_category="Produce")
    result = repo.capture(
        store_chain_id="heb", upc="033383000014", hh=HH_A, fallback_name="Bananas bag", fallback_category="Produce",
        previous_product_id="plu:4011",
    )
    assert result.outcome == "created" and result.product.id == "033383000014"
    plu = repo.get_product("plu:4011", follow_superseded=False)
    assert plu.superseded_by is None and plu.code_kind == "plu"
