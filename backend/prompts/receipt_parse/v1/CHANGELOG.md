# receipt_parse — prompt/schema changelog

Prompt versions are immutable once a `llm_parse_jobs` document references
them. To change behaviour, copy the directory to `vN+1/` and add an entry here.
`prompt_version` recorded on jobs is `receipt_parse/vN`; `prompt_sha256` is the
SHA-256 of `system.md` (REQ-RCP-017).

## v1 — 2026-09-26 (draft, awaiting review)

- Initial contract. Whole-receipt single call; store chain injected via
  `{{store_chain_name}}`.
- Response schema `response.schema.json`: `store`, `purchased_at`, `currency`,
  `totals`, `line_items[]` (raw_text, description, qty/unit, price, discount,
  printed_code, category, confidence), `notes`.
- Corrective retry turn `corrective.md` with `{{attempt}}`,
  `{{validation_errors}}` (REQ-RCP-004).
- Privacy rules: redact payment/loyalty identifiers; forbid ≥ 13-digit runs.
- 2026-09-29 (still draft, no jobs reference v1 yet): after the H-E-B
  prototype run (`docs/design/gemini-receipt-prototype.md` → Results),
  `purchased_at` is naive store-local time (no offset) instead of strict
  RFC 3339; system prompt gained store-brand prefix hints (HEB/CM/Mi Tienda),
  a "lower confidence when the product noun is inferred" rule, and a note
  that tax-status letters must not alter qty/unit/price.
- 2026-09-29 (draft): `brand` and `unit_size` added as required nullable
  line-item fields after the name→UPC evaluation (prototype Run 2) showed
  brand-gated search removes all wrong-brand matches. Rule 4 added; later
  rules renumbered.

Allowed placeholders (enforced by the phase-2 prompt lint):
`system.md` → `{{store_chain_name}}`; `corrective.md` → `{{attempt}}`,
`{{validation_errors}}`.
