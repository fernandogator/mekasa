-- Rollback of 0003_retire_store_catalog_prototype: recreates the prototype
-- tables with the DDL the API used to apply at startup
-- (backend/app/store_catalog.sql, PR #106). Rows are not restored.

BEGIN;

CREATE TABLE IF NOT EXISTS stores (
    id          text PRIMARY KEY,
    name        text NOT NULL,
    address     text,
    created_at  timestamptz NOT NULL,
    updated_at  timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS store_items (
    store_id      text NOT NULL REFERENCES stores (id) ON DELETE CASCADE,
    id            text NOT NULL,
    receipt_text  text,
    name          text NOT NULL,
    category      text NOT NULL,
    last_price    numeric(10, 2),
    status        text NOT NULL
        CHECK (status IN ('confirmed', 'conflict', 'receipt_only', 'manual_only')),
    photo_id      uuid,
    updated_at    timestamptz NOT NULL,
    PRIMARY KEY (store_id, id)
);

CREATE TABLE IF NOT EXISTS store_item_codes (
    store_id    text NOT NULL,
    item_id     text NOT NULL,
    code        text NOT NULL,
    kind        text NOT NULL CHECK (kind IN ('upc', 'sku')),
    sources     text[] NOT NULL,
    seen_count  integer NOT NULL DEFAULT 1,
    first_seen  timestamptz NOT NULL,
    last_seen   timestamptz NOT NULL,
    PRIMARY KEY (store_id, item_id, code),
    FOREIGN KEY (store_id, item_id) REFERENCES store_items (store_id, id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS photos (
    id            uuid PRIMARY KEY,
    household_id  text NOT NULL,
    store_id      text,
    item_id       text,
    content_type  text NOT NULL,
    data          bytea NOT NULL,
    created_at    timestamptz NOT NULL,
    FOREIGN KEY (store_id, item_id) REFERENCES store_items (store_id, id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS store_item_codes_code_idx ON store_item_codes (code);

CREATE TABLE IF NOT EXISTS household_latest_receipts (
    household_id  text PRIMARY KEY,
    store_id      text NOT NULL REFERENCES stores (id),
    item_ids      text[] NOT NULL,
    scanned_at    timestamptz NOT NULL
);

COMMIT;
