-- Rollback of 0002_product_corrections. Restores the 0001 enumerations.
-- Rows that only 0002 made legal (image_url conflicts, user_capture /
-- image_removed jobs) are removed first so the narrower CHECKs can be re-added.

BEGIN;

DELETE FROM enrichment_steps
 WHERE job_id IN (SELECT job_id FROM enrichment_jobs WHERE trigger IN ('user_capture', 'image_removed'));
DELETE FROM enrichment_jobs WHERE trigger IN ('user_capture', 'image_removed');
ALTER TABLE enrichment_jobs DROP CONSTRAINT IF EXISTS enrichment_jobs_trigger_enum;
ALTER TABLE enrichment_jobs ADD CONSTRAINT enrichment_jobs_trigger_enum
  CHECK (trigger IN ('unmatched_line', 'manual', 'reverify', 'scan_correlation'));

DELETE FROM product_conflicts WHERE field = 'image_url';
ALTER TABLE product_conflicts DROP CONSTRAINT IF EXISTS product_conflicts_values_len;
ALTER TABLE product_conflicts ADD CONSTRAINT product_conflicts_values_len
  CHECK (length(verified_value) <= 200 AND length(observed_value) <= 200);
ALTER TABLE product_conflicts DROP CONSTRAINT IF EXISTS product_conflicts_field_enum;
ALTER TABLE product_conflicts ADD CONSTRAINT product_conflicts_field_enum
  CHECK (field IN ('name', 'brand', 'unit_size', 'category', 'upc'));

DROP INDEX IF EXISTS products_user_photo_idx;
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_image_source_pairing;
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_image_source_enum;
ALTER TABLE products DROP COLUMN IF EXISTS image_source;

COMMIT;
