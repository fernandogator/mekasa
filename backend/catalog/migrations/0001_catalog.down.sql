-- Rollback of 0001_catalog. Drops every catalog object; household data in
-- Firestore is untouched (it only holds opaque product_id strings).
DROP TABLE IF EXISTS product_conflicts;
DROP TABLE IF EXISTS enrichment_steps;
DROP TABLE IF EXISTS enrichment_jobs;
DROP TABLE IF EXISTS product_confirmations;
DROP TABLE IF EXISTS product_aliases;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS store_chains;

DROP FUNCTION IF EXISTS catalog_normalize_name(text);
DROP FUNCTION IF EXISTS catalog_set_updated_at();

-- Extensions are left installed; other objects may depend on them.
