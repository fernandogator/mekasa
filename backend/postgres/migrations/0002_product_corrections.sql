-- 0002_product_corrections — user corrections, in-store capture, product photos
-- Spec version: 1.0 · Satisfies: REQ-RCP-019, REQ-RCP-020, REQ-RCP-021
-- Design: docs/design/gemini-receipt-parser.md §3.11 · Decision: ADR-008
--
-- Idempotent: safe to apply repeatedly. Enumerations are TEXT + named CHECK
-- constraints (see README), so widening one is DROP + ADD in a transaction.
--
-- Still true after this migration: no table carries a raw household or user
-- id (NFR-002 AC1). User photos reach the catalog only as the opaque URL
-- '/v1/product-photos/<uuid>'; the uploading household is recorded in
-- Firestore, never here.

BEGIN;

-- ---------------------------------------------------------------------------
-- products.image_source — provenance of image_url. 'user_photo' means the URL
-- is a Mekasa photo id URL (REQ-RCP-019 AC4, REQ-RCP-021). NULL when there is
-- no image yet.
-- ---------------------------------------------------------------------------
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_source text;

ALTER TABLE products DROP CONSTRAINT IF EXISTS products_image_source_enum;
ALTER TABLE products ADD CONSTRAINT products_image_source_enum CHECK (
  image_source IS NULL
  OR image_source IN ('user_photo', 'store_api', 'openfoodfacts', 'gs1_registry', 'placeholder')
);

-- image_url and image_source go together: a user photo must be a photo-id URL,
-- and an image_url always says where it came from.
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_image_source_pairing;
ALTER TABLE products ADD CONSTRAINT products_image_source_pairing CHECK (
     (image_url IS NULL AND image_source IS NULL)
  OR (image_url IS NOT NULL AND image_source IS NOT NULL
      AND (image_source <> 'user_photo'
           OR image_url ~ '^/v1/product-photos/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'))
) NOT VALID;
-- NOT VALID: pre-existing rows written by 0001 may hold an image_url without
-- a source. Backfill below, then validate.
UPDATE products SET image_source = 'openfoodfacts'
 WHERE image_url IS NOT NULL AND image_source IS NULL AND image_url ~ 'openfoodfacts\.org';
UPDATE products SET image_source = 'store_api'
 WHERE image_url IS NOT NULL AND image_source IS NULL;
ALTER TABLE products VALIDATE CONSTRAINT products_image_source_pairing;

COMMENT ON COLUMN products.image_source IS
  'Provenance of image_url: user_photo (/v1/product-photos/<uuid>, REQ-RCP-021), store_api, openfoodfacts, gs1_registry, placeholder. NULL iff image_url is NULL.';

-- Find every product whose image is a given user photo (DELETE …/product-photos
-- fallback, REQ-RCP-021 AC5) without a sequential scan.
CREATE INDEX IF NOT EXISTS products_user_photo_idx
  ON products (image_url) WHERE image_source = 'user_photo';

-- ---------------------------------------------------------------------------
-- product_conflicts.field — a user may propose a different image for a
-- verified product; it is filed as a conflict like any other field
-- (REQ-RCP-019 AC3). verified_value / observed_value hold the two URLs.
-- ---------------------------------------------------------------------------
ALTER TABLE product_conflicts DROP CONSTRAINT IF EXISTS product_conflicts_field_enum;
ALTER TABLE product_conflicts ADD CONSTRAINT product_conflicts_field_enum
  CHECK (field IN ('name', 'brand', 'unit_size', 'category', 'upc', 'image_url'));

-- image URLs can exceed the 200-char value cap that suits names and sizes.
ALTER TABLE product_conflicts DROP CONSTRAINT IF EXISTS product_conflicts_values_len;
ALTER TABLE product_conflicts ADD CONSTRAINT product_conflicts_values_len
  CHECK (length(verified_value) <= 2048 AND length(observed_value) <= 2048);

-- ---------------------------------------------------------------------------
-- enrichment_jobs.trigger — two new reasons to run the adapters:
--   user_capture  : a product was created from a scan (+photo); adapters fill
--                   brand / unit_size / a catalog image (REQ-RCP-020 AC4)
--   image_removed : the household deleted the photo backing image_url; find
--                   the next-best image or fall back to a placeholder
--                   (REQ-RCP-021 AC5)
-- ---------------------------------------------------------------------------
ALTER TABLE enrichment_jobs DROP CONSTRAINT IF EXISTS enrichment_jobs_trigger_enum;
ALTER TABLE enrichment_jobs ADD CONSTRAINT enrichment_jobs_trigger_enum
  CHECK (trigger IN ('unmatched_line', 'manual', 'reverify', 'scan_correlation', 'user_capture', 'image_removed'));

COMMIT;
