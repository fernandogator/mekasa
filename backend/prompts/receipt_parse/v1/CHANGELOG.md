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

Allowed placeholders (enforced by the phase-2 prompt lint):
`system.md` → `{{store_chain_name}}`; `corrective.md` → `{{attempt}}`,
`{{validation_errors}}`.
