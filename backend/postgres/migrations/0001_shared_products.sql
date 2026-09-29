-- Migration 0001_shared_products — shared product catalog (Cloud SQL for PostgreSQL 16)
-- Spec version: 1.0
-- Satisfies: REQ-RCP-007, REQ-RCP-009, REQ-RCP-010, REQ-RCP-011, REQ-RCP-013, REQ-RCP-014
-- Design: docs/design/gemini-receipt-parser.md §4 · Decision: docs/architecture.md ADR-008
--
-- Idempotent: every statement is IF NOT EXISTS / OR REPLACE, so
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f 0001_shared_products.sql
-- can be run repeatedly (deploys, CI, local resets). Rollback: 0001_shared_products.down.sql.
--
-- Household data (receipts, line items, scan events, llm_parse_jobs) stays in
-- Firestore; the only cross-store references are opaque string ids
-- (line_items.matched_product_id / inventory_items.product_id → products.product_id).
--
-- Rules:
--   * No household or user identifiers in any table (NFR-002 AC1). Households are
--     represented only by household_hash = SHA-256(household_id + server salt).
--   * Enumerations are TEXT + named CHECK constraints (not CREATE TYPE) so a
--     later migration can widen them with DROP/ADD CONSTRAINT in one transaction.
--   * Every table has created_at / updated_at maintained by trigger.
--   * Field names follow backend/firestore/migrations/0001_receipt_parser.md as
--     merged in #104; array fields became tables: receipt_aliases → product_aliases,
--     confirming_household_hashes → product_confirmations, enrichment_jobs.steps →
--     enrichment_steps.

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE OR REPLACE FUNCTION catalog_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- Deterministic normalisation shared by the resolver and the alias index:
-- casefold, strip accents, drop punctuation, collapse whitespace.
CREATE OR REPLACE FUNCTION catalog_normalize_name(input text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT btrim(regexp_replace(regexp_replace(lower(unaccent(input)), '[^a-z0-9 ]+', ' ', 'g'), '\s+', ' ', 'g'))
$$;

-- ---------------------------------------------------------------------------
-- store_chains — retail chains referenced by products and receipts.
-- name is injected into the Gemini prompt as {{store_chain_name}} (REQ-RCP-002).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS store_chains (
  chain_id          text PRIMARY KEY,
  name              text NOT NULL,
  aliases           text[] NOT NULL DEFAULT '{}',
  website_domain    text,                       -- informational only; never fetched (ADR-008: no scraping)
  api_provider      text NOT NULL DEFAULT 'none',
  receipt_code_kind text NOT NULL DEFAULT 'none',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT store_chains_chain_id_shape       CHECK (chain_id ~ '^[a-z0-9_-]{1,40}$'),
  CONSTRAINT store_chains_name_len             CHECK (length(name) BETWEEN 1 AND 80),
  CONSTRAINT store_chains_website_domain_len   CHECK (website_domain IS NULL OR length(website_domain) <= 120),
  CONSTRAINT store_chains_api_provider_enum    CHECK (api_provider IN ('none', 'kroger', 'walmart')),
  CONSTRAINT store_chains_receipt_code_enum    CHECK (receipt_code_kind IN ('none', 'upc', 'item_number'))
);
COMMENT ON TABLE store_chains IS 'Retail chains; api_provider selects the official store_api adapter (REQ-RCP-010 AC6).';
COMMENT ON COLUMN store_chains.website_domain IS 'Informational only. The backend never fetches retailer pages (ADR-008).';

CREATE INDEX IF NOT EXISTS store_chains_aliases_gin ON store_chains USING gin (aliases);

CREATE OR REPLACE TRIGGER store_chains_updated_at BEFORE UPDATE ON store_chains
  FOR EACH ROW EXECUTE FUNCTION catalog_set_updated_at();

-- ---------------------------------------------------------------------------
-- products — the shared, provenance-tracked UPC product database (ADR-008).
-- product_id = UPC digits | 'plu:<IFPS code>' | 'llm:<sha1(chain|normalized_name)>'
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  product_id            text PRIMARY KEY,
  code_kind             text NOT NULL,
  upc                   text,
  plu_code              text,
  store_chain_id        text NOT NULL REFERENCES store_chains (chain_id),
  name                  text NOT NULL,
  normalized_name       text NOT NULL,
  brand                 text,
  category              text NOT NULL,
  unit_size             text,
  image_url             text,
  source                text NOT NULL,
  sources_seen          text[] NOT NULL DEFAULT '{}',
  confidence_score      numeric(4,3) NOT NULL,
  confirmation_count    integer NOT NULL DEFAULT 0,
  dispute_count         integer NOT NULL DEFAULT 0,
  status                text NOT NULL DEFAULT 'unverified',
  status_changed_at     timestamptz,
  origin_parse_job_id   text,
  origin_prompt_version text,
  superseded_by         text REFERENCES products (product_id),
  first_seen_at         timestamptz NOT NULL DEFAULT now(),
  last_seen_at          timestamptz NOT NULL DEFAULT now(),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT products_code_kind_enum   CHECK (code_kind IN ('upc', 'plu', 'llm')),
  CONSTRAINT products_upc_shape        CHECK (upc IS NULL OR upc ~ '^[0-9]{8,14}$'),
  CONSTRAINT products_plu_shape        CHECK (plu_code IS NULL OR plu_code ~ '^[0-9]{4,5}$'),
  -- The key scheme is enforced, not conventional: a UPC row is keyed by its UPC,
  -- a PLU row by 'plu:<code>', and an llm row carries no UPC until it is re-keyed
  -- (REQ-RCP-010 AC2 writes a new UPC row and points superseded_by at it).
  CONSTRAINT products_key_shape CHECK (
       (code_kind = 'upc' AND upc IS NOT NULL AND product_id = upc               AND plu_code IS NULL)
    OR (code_kind = 'plu' AND plu_code IS NOT NULL AND product_id = 'plu:' || plu_code AND upc IS NULL)
    OR (code_kind = 'llm' AND product_id ~ '^llm:[0-9a-f]{40}$' AND upc IS NULL AND plu_code IS NULL)
  ),
  CONSTRAINT products_name_len         CHECK (length(name) BETWEEN 1 AND 120),
  CONSTRAINT products_normalized_len   CHECK (length(normalized_name) BETWEEN 1 AND 120),
  CONSTRAINT products_brand_len        CHECK (brand IS NULL OR length(brand) <= 80),
  CONSTRAINT products_category_len     CHECK (length(category) BETWEEN 1 AND 60),
  CONSTRAINT products_unit_size_len    CHECK (unit_size IS NULL OR length(unit_size) <= 40),
  CONSTRAINT products_image_url_len    CHECK (image_url IS NULL OR length(image_url) <= 2048),
  CONSTRAINT products_source_enum      CHECK (source IN ('user_scan', 'store_api', 'gs1_registry', 'llm_ocr')),
  CONSTRAINT products_sources_seen_enum CHECK (sources_seen <@ ARRAY['user_scan', 'store_api', 'gs1_registry', 'llm_ocr']::text[]),
  CONSTRAINT products_confidence_range CHECK (confidence_score >= 0 AND confidence_score <= 1),
  CONSTRAINT products_counts_nonneg    CHECK (confirmation_count >= 0 AND dispute_count >= 0),
  CONSTRAINT products_status_enum      CHECK (status IN ('unverified', 'pending', 'verified')),
  CONSTRAINT products_prompt_version_shape CHECK (origin_prompt_version IS NULL OR origin_prompt_version ~ '^receipt_parse/v[0-9]+$'),
  CONSTRAINT products_not_self_superseded CHECK (superseded_by IS NULL OR superseded_by <> product_id),
  -- REQ-RCP-011: a verified product must have a UPC and at least one
  -- confirmation or an authoritative source.
  CONSTRAINT products_verified_requires_evidence CHECK (
    status <> 'verified'
    OR (upc IS NOT NULL AND (confirmation_count >= 1 OR source IN ('gs1_registry', 'store_api')))
  )
);
COMMENT ON TABLE products IS 'Shared UPC product database (ADR-008). Carries no household or user identifiers (NFR-002).';
COMMENT ON COLUMN products.source IS 'Best provenance so far. store_api = official retailer API only; scraped pages are never a source (ADR-008).';
COMMENT ON COLUMN products.superseded_by IS 'Set on an llm: row once enrichment or scan correlation found its UPC (REQ-RCP-010 AC2).';

-- One row per UPC (partial: llm:/plu: rows have upc IS NULL).
CREATE UNIQUE INDEX IF NOT EXISTS products_upc_unique ON products (upc) WHERE upc IS NOT NULL;

-- Chain-scoped lookups for the resolver (REQ-RCP-007): exact normalized name,
-- trigram similarity for the fuzzy step, curation ordering, re-key chasing.
CREATE INDEX IF NOT EXISTS products_chain_normalized_name_idx ON products (store_chain_id, normalized_name);
CREATE INDEX IF NOT EXISTS products_normalized_name_trgm      ON products USING gin (normalized_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS products_brand_trgm                ON products USING gin (brand gin_trgm_ops) WHERE brand IS NOT NULL;
CREATE INDEX IF NOT EXISTS products_status_confidence_idx     ON products (status, confidence_score DESC);
CREATE INDEX IF NOT EXISTS products_superseded_by_idx         ON products (superseded_by) WHERE superseded_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS products_last_seen_idx             ON products (last_seen_at DESC);

CREATE OR REPLACE TRIGGER products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION catalog_set_updated_at();

-- ---------------------------------------------------------------------------
-- product_aliases — normalized receipt texts seen for a product, per chain.
-- One printed alias maps to exactly one product within a chain (alias step of
-- the resolver, confidence 0.95). Replaces the Firestore receipt_aliases[].
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_aliases (
  store_chain_id text NOT NULL REFERENCES store_chains (chain_id),
  alias          text NOT NULL,
  product_id     text NOT NULL REFERENCES products (product_id) ON DELETE CASCADE,
  seen_count     integer NOT NULL DEFAULT 1,
  first_seen_at  timestamptz NOT NULL DEFAULT now(),
  last_seen_at   timestamptz NOT NULL DEFAULT now(),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT product_aliases_pk         PRIMARY KEY (store_chain_id, alias),
  CONSTRAINT product_aliases_alias_len  CHECK (length(alias) BETWEEN 1 AND 120),
  CONSTRAINT product_aliases_normalized CHECK (alias = catalog_normalize_name(alias)),
  CONSTRAINT product_aliases_seen_pos   CHECK (seen_count >= 1)
);
COMMENT ON TABLE product_aliases IS 'Normalized raw receipt texts per chain → product (REQ-RCP-007 alias step, REQ-RCP-013 AC2).';

CREATE INDEX IF NOT EXISTS product_aliases_product_idx ON product_aliases (product_id);
CREATE INDEX IF NOT EXISTS product_aliases_alias_trgm  ON product_aliases USING gin (alias gin_trgm_ops);

CREATE OR REPLACE TRIGGER product_aliases_updated_at BEFORE UPDATE ON product_aliases
  FOR EACH ROW EXECUTE FUNCTION catalog_set_updated_at();

-- ---------------------------------------------------------------------------
-- product_confirmations — one row per (product, hashed household).
-- products.confirmation_count is the denormalised COUNT(*) of this table and is
-- updated in the same transaction (REQ-RCP-013 AC1: once per household).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_confirmations (
  product_id     text NOT NULL REFERENCES products (product_id) ON DELETE CASCADE,
  household_hash char(64) NOT NULL,
  confirmed_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT product_confirmations_pk         PRIMARY KEY (product_id, household_hash),
  CONSTRAINT product_confirmations_hash_shape CHECK (household_hash ~ '^[a-f0-9]{64}$')
);
COMMENT ON TABLE product_confirmations IS 'Distinct-household confirmations via salted SHA-256 only (REQ-RCP-011 AC5, NFR-002).';

-- ---------------------------------------------------------------------------
-- enrichment_jobs / enrichment_steps — dispatcher state (REQ-RCP-009 / 010).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS enrichment_jobs (
  job_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id    text NOT NULL REFERENCES products (product_id) ON DELETE CASCADE,
  trigger       text NOT NULL,
  chain         text[] NOT NULL,
  status        text NOT NULL DEFAULT 'queued',
  result_source text,
  expires_at    timestamptz NOT NULL DEFAULT now() + interval '180 days',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT enrichment_jobs_trigger_enum CHECK (trigger IN ('unmatched_line', 'manual', 'reverify', 'scan_correlation')),
  CONSTRAINT enrichment_jobs_chain_enum   CHECK (
    cardinality(chain) >= 1
    AND chain <@ ARRAY['store_api', 'openfoodfacts', 'upcitemdb', 'gs1_verify', 'crowdsourced_pending']::text[]
  ),
  CONSTRAINT enrichment_jobs_status_enum  CHECK (status IN ('queued', 'running', 'succeeded', 'exhausted', 'failed')),
  CONSTRAINT enrichment_jobs_result_enum  CHECK (result_source IS NULL OR result_source IN ('user_scan', 'store_api', 'gs1_registry', 'llm_ocr'))
);
COMMENT ON TABLE enrichment_jobs IS 'Adapter chain: discovery (store_api → openfoodfacts → upcitemdb) stops at first UPC; gs1_verify runs only on a known UPC; crowdsourced_pending is terminal (REQ-RCP-010).';

-- REQ-RCP-009 AC3: at most one live job per product.
CREATE UNIQUE INDEX IF NOT EXISTS enrichment_jobs_one_active_per_product ON enrichment_jobs (product_id) WHERE status IN ('queued', 'running');
CREATE INDEX IF NOT EXISTS enrichment_jobs_queue_idx   ON enrichment_jobs (status, created_at) WHERE status IN ('queued', 'running');
CREATE INDEX IF NOT EXISTS enrichment_jobs_product_idx ON enrichment_jobs (product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS enrichment_jobs_expires_idx ON enrichment_jobs (expires_at);

CREATE OR REPLACE TRIGGER enrichment_jobs_updated_at BEFORE UPDATE ON enrichment_jobs
  FOR EACH ROW EXECUTE FUNCTION catalog_set_updated_at();

CREATE TABLE IF NOT EXISTS enrichment_steps (
  job_id      uuid NOT NULL REFERENCES enrichment_jobs (job_id) ON DELETE CASCADE,
  step_no     smallint NOT NULL,
  adapter     text NOT NULL,
  status      text NOT NULL,
  started_at  timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  upc         text,
  note        text,
  CONSTRAINT enrichment_steps_pk           PRIMARY KEY (job_id, step_no),
  CONSTRAINT enrichment_steps_step_pos     CHECK (step_no >= 1),
  CONSTRAINT enrichment_steps_adapter_enum CHECK (adapter IN ('store_api', 'openfoodfacts', 'upcitemdb', 'gs1_verify', 'crowdsourced_pending')),
  CONSTRAINT enrichment_steps_status_enum  CHECK (status IN ('skipped', 'hit', 'miss', 'error', 'not_implemented')),
  CONSTRAINT enrichment_steps_upc_shape    CHECK (upc IS NULL OR upc ~ '^[0-9]{8,14}$'),
  CONSTRAINT enrichment_steps_note_len     CHECK (note IS NULL OR length(note) <= 300)
);
COMMENT ON COLUMN enrichment_steps.note IS 'Operator-facing note; must not contain receipt text or PII.';

-- ---------------------------------------------------------------------------
-- product_conflicts — disagreement with a verified product (REQ-RCP-014).
-- receipt_id / line_item_id are Firestore document ids (opaque, no FK).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_conflicts (
  conflict_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id     text NOT NULL REFERENCES products (product_id),
  household_hash char(64) NOT NULL,
  receipt_id     text NOT NULL,
  line_item_id   text NOT NULL,
  field          text NOT NULL,
  verified_value text NOT NULL,
  observed_value text NOT NULL,
  status         text NOT NULL DEFAULT 'open',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT product_conflicts_hash_shape  CHECK (household_hash ~ '^[a-f0-9]{64}$'),
  CONSTRAINT product_conflicts_ids_len     CHECK (length(receipt_id) BETWEEN 1 AND 128 AND length(line_item_id) BETWEEN 1 AND 128),
  CONSTRAINT product_conflicts_field_enum  CHECK (field IN ('name', 'brand', 'unit_size', 'category', 'upc')),
  CONSTRAINT product_conflicts_values_len  CHECK (length(verified_value) <= 200 AND length(observed_value) <= 200),
  CONSTRAINT product_conflicts_status_enum CHECK (status IN ('open', 'dismissed', 'accepted'))
);
COMMENT ON TABLE product_conflicts IS 'The verified product row is never modified by the parser; disagreements land here for curation (REQ-RCP-014).';

CREATE INDEX IF NOT EXISTS product_conflicts_queue_idx   ON product_conflicts (status, created_at DESC);
CREATE INDEX IF NOT EXISTS product_conflicts_product_idx ON product_conflicts (product_id);

CREATE OR REPLACE TRIGGER product_conflicts_updated_at BEFORE UPDATE ON product_conflicts
  FOR EACH ROW EXECUTE FUNCTION catalog_set_updated_at();
