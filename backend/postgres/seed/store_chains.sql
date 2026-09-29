-- Seed: store_chains (idempotent). Apply after 0001_shared_products.
-- Spec version: 1.0 · Satisfies: REQ-RCP-002 (prompt chain name), REQ-RCP-010 AC6 (api_provider)
--
-- Chains come from the Places names already returned by stub_nearby_stores /
-- places_lookup plus H-E-B (first prototype receipt). api_provider names the
-- official store_api adapter; 'none' means the chain has no documented API and
-- gets UPCs only from scan correlation and Open Food Facts (ADR-008).
-- website_domain is informational and is never fetched.

INSERT INTO store_chains (chain_id, name, aliases, website_domain, api_provider, receipt_code_kind) VALUES
  ('unknown', 'Unknown store',      '{}',                                                                        NULL,             'none',   'none'),
  ('heb',     'H-E-B',              '{"H-E-B","HEB","H-E-B Food-Drugs","Central Market","Mi Tienda"}',           'heb.com',        'none',   'none'),
  ('publix',  'Publix',             '{"PUBLIX","PUBLIX SUPER MARKETS","Publix Super Markets"}',                   'publix.com',     'none',   'none'),
  ('walmart', 'Walmart',            '{"WALMART","WAL-MART","Walmart Supercenter","Walmart Neighborhood Market"}', 'walmart.com',    'walmart','item_number'),
  ('costco',  'Costco',             '{"COSTCO","COSTCO WHOLESALE","Costco Wholesale"}',                           'costco.com',     'none',   'item_number'),
  ('kroger',  'Kroger',             '{"KROGER","Ralphs","Fry''s","King Soopers","Smith''s","Fred Meyer","Harris Teeter"}', 'kroger.com', 'kroger', 'upc'),
  ('target',  'Target',             '{"TARGET","Target"}',                                                        'target.com',     'none',   'none')
ON CONFLICT (chain_id) DO UPDATE SET
  name              = EXCLUDED.name,
  aliases           = EXCLUDED.aliases,
  website_domain    = EXCLUDED.website_domain,
  api_provider      = EXCLUDED.api_provider,
  receipt_code_kind = EXCLUDED.receipt_code_kind;
