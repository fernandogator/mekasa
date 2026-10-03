# ADR-009: Enum Strategy — TEXT + CHECK vs Native PostgreSQL Enums

- **Status:** Under Review
- **Date:** 2026-10-03
- **Author:** Fernando Guerrero (with Claude Fable 5.1)
- **Related:** ADR-008 (`docs/architecture.md` §5), migrations
  `backend/postgres/migrations/0001_shared_products.sql` and
  `0002_product_corrections.sql`, PR #106 (prototype `store_catalog.sql`)

## Context

In the shared product catalog (ADR-008), enumerated columns are
implemented as `TEXT` columns with named `CHECK` constraints
(`<table>_<column>_enum`) rather than native `CREATE TYPE ... AS ENUM`
types. ADR-008 recorded the reason in one line: values can be added in
one transaction.

That choice has already been exercised once: migration 0002 widened
three enumerations (`product_conflicts.field` gained `image_url`,
`enrichment_jobs.trigger` gained `user_capture` and `image_removed`,
and the new `products.image_source` column was added) by
`DROP CONSTRAINT IF EXISTS` / `ADD CONSTRAINT` inside one idempotent
script.

Before the PR #106 cleanup and the retirement of the prototype
`store_catalog.sql`, we want to confirm whether that trade-off still
holds while the schema is young and cheap to change.

## Decision

Keep `TEXT` + named `CHECK` for every enumerated column in the
catalog. Do not migrate any column to a native enum now. Add an
automated check that the Python `Literal` types match the SQL `CHECK`
lists (see Follow-ups), because a mismatch between the two is the
real source of risk.

## Rationale

1. **The database already rejects invalid values.** A `CHECK (status
   IN ('unverified', 'pending', 'verified'))` stops `'verfied'` exactly
   as a native enum would, with SQLSTATE `23514` instead of `22P02`.
   The remaining typo risk is in the *definition*: a misspelled value
   inside the `CHECK` list or in a Python `Literal`. A native enum has
   the same exposure in its `CREATE TYPE` list.
2. **Values change, and some must be removable.** Native enums can
   gain values (`ALTER TYPE ... ADD VALUE`) and rename them, but cannot
   drop or reorder them without rebuilding the type and rewriting every
   dependent column, index, and constraint. Adapter names and job
   triggers are expected to change as integrations are tried and
   retired.
3. **Several constraints combine the enum with other columns or with
   arrays.** `products_key_shape` ties `code_kind` to the shape of
   `product_id`; `products_verified_requires_evidence` ties `status` to
   `upc` and confirmation counts; `sources_seen` and `chain` are `text[]`
   checked with `<@ ARRAY[...]`. These work identically on `TEXT`;
   converting to enums means enum-array types and casts in every
   literal array.
4. **Partial indexes reference the values.**
   `enrichment_jobs_one_active_per_product` and
   `enrichment_jobs_queue_idx` use `WHERE status IN ('queued',
   'running')`. On `TEXT` these are plain comparisons. On an enum they
   still work, but a value added later with `ADD VALUE` cannot be used
   in the same transaction that adds it, which makes a single-script
   "add state + update index predicate" migration impossible.
5. **The driver layer is simpler.** The backend uses psycopg 3 with
   `dict_row` and maps rows into Pydantic models with `Literal` fields.
   `TEXT` round-trips as `str` with no adapter registration; native
   enums need either registered types or `::text` casts.
6. **One pattern across the schema.** Mixing native enums for "stable"
   columns with `CHECK` for "volatile" ones would make every reviewer
   decide which pattern a new column belongs to.

## Tradeoffs

| Concern | TEXT + CHECK (current) | Native enum |
|---|---|---|
| Adding a value | Drop and re-add the named `CHECK` in one transaction; new value usable immediately | `ALTER TYPE ... ADD VALUE` (allowed in a transaction since PG 12), but the new value cannot be used until that transaction commits |
| Removing a value | Drop and re-add the `CHECK` after migrating rows | Not supported: create a new type, rewrite columns, drop the old type |
| Typo protection | Database rejects values outside the list; the list itself is only as correct as the migration | Same: database rejects values outside the type; the type definition is only as correct as the migration |
| Renaming a value | Update rows and re-add the `CHECK` | `ALTER TYPE ... RENAME VALUE` (no row rewrite) |
| Storage / comparison | Variable-length text (values are ≤ 20 chars) | 4 bytes, ordered by declaration |
| Arrays (`text[] <@ ARRAY[...]`) | Native | Needs an enum array type and casts |
| Driver / ORM mapping | `str` everywhere; validated by Pydantic `Literal` | Needs type registration or casts in psycopg |
| Discoverability | Values live in the constraint definition (`\d+ table`) | Values listed by `\dT+` / `pg_enum` |

## Assessment of existing columns

**Load-bearing for the enrichment state machine or adapter chain —
must stay flexible:**

| Column | Why |
|---|---|
| `enrichment_jobs.status` | State machine (`queued → running → succeeded/exhausted/failed`); referenced by both partial indexes; a new state (e.g. `cancelled`, `retry_wait`) must be added together with the index predicate |
| `enrichment_jobs.trigger` | Already widened by 0002; grows with each new entry point |
| `enrichment_jobs.chain` (`text[]`) | Ordered adapter list; adapters will be added and retired |
| `enrichment_steps.adapter` | Same value set as `chain`; must change in lockstep |
| `enrichment_steps.status` | `not_implemented` is a transitional value expected to be removed once adapters land — removal is exactly what native enums cannot do |
| `products.source`, `products.sources_seen` (`text[]`), `enrichment_jobs.result_source` | Provenance set drives the confidence weights; a new source (e.g. `openfoodfacts` as a provenance) changes all three together |
| `products.image_source` | New in 0002; also part of the `products_image_source_pairing` constraint |
| `product_conflicts.field` | Already widened by 0002; grows whenever a new product attribute becomes correctable |
| `store_chains.api_provider` | Grows with each store API integration |

**Stable — could be native enums, but no benefit justifies breaking
the single pattern:**

| Column | Notes |
|---|---|
| `products.code_kind` | Tied to `products_key_shape`; three values follow from the key scheme |
| `products.status` | Lifecycle is fixed by ADR-008 and ordered; native enum ordering would allow `status >= 'pending'`, but no query needs that today |
| `product_conflicts.status` | Small curation lifecycle |
| `store_chains.receipt_code_kind` | Small, slow-changing |

None of these is worth migrating now: the database already enforces
the value set, and the only gain (4-byte storage and declaration
order) is negligible at catalog scale.

## Open Question

Should the Python `Literal` types in `backend/app/catalog_repository.py`
(`ProductStatus`, `ProductSource`, `ImageSource`, `ConflictField`, and
the inline `code_kind` and conflict `status` literals) become the
single source of truth, with migrations checked against them, or should
the SQL `CHECK` lists be authoritative and the Python types be checked
against the database?

## Follow-ups

- Add a backend test (Postgres variant, `TEST_DATABASE_URL`) that reads
  each `*_enum` constraint from `pg_constraint` and asserts its value
  list equals the matching Python `Literal`. This closes the "typo in
  the definition" gap for both layers.
- Enumerations for `enrichment_jobs.trigger`, `enrichment_jobs.chain`,
  `enrichment_steps.adapter`/`status`, and `enrichment_jobs.result_source`
  have no Python `Literal` yet; add them when the enrichment worker is
  implemented.
- The prototype `store_catalog.sql` (PR #106) is out of scope here; it
  is being retired rather than aligned with this pattern.

## References

- ADR-008: Shared, Provenance-Tracked UPC Product Database
  (`docs/architecture.md` §5)
- `backend/postgres/migrations/0001_shared_products.sql`
- `backend/postgres/migrations/0002_product_corrections.sql`
- `backend/app/catalog_repository.py`
- PR #106 (Gemini receipt parser + Postgres prototype)
- PostgreSQL 16 documentation: `ALTER TYPE`, enumerated types (§8.7)
