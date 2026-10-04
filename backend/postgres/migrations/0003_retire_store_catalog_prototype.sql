-- 0003: retire the pre-ADR-008 prototype per-store tables.
--
-- Satisfies: NFR-002 (no raw household ids in the shared catalog), ADR-008
-- "one Postgres schema" rule (docs/architecture.md). Spec version: 1.0.
--
-- backend/app/store_catalog.sql (PR #106) created these tables from the API at
-- startup. Their job — receipt lines + discovered UPCs per store, manual-scan
-- comparison, user photo bytes behind a public URL — is covered by
-- products / product_aliases / product_confirmations (0001, 0002) and the
-- household-private item photos in Cloud Storage (REQ-INV-019). The data was
-- prototype-only and is dropped, not migrated. Idempotent.

BEGIN;

DROP TABLE IF EXISTS household_latest_receipts;
DROP TABLE IF EXISTS photos;
DROP TABLE IF EXISTS store_item_codes;
DROP TABLE IF EXISTS store_items;
DROP TABLE IF EXISTS stores;

COMMIT;
