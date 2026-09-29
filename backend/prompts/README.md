# backend/prompts

Versioned LLM prompt and response-schema contracts. Loaded at runtime by the
Gemini invocation service (phase 2: `app/gemini_receipt_parser.py`); linted in
CI by `scripts/lint_prompts.py` (phase 2).

```
prompts/
  README.md
  <task>/
    v<N>/
      system.md             # system prompt; only whitelisted {{placeholders}}
      corrective.md         # retry turn (optional)
      response.schema.json  # JSON Schema 2020-12; Vertex-compatible subset
      CHANGELOG.md          # one entry per version
```

Rules

- A version directory is immutable once any `llm_parse_jobs` doc references it.
- No secrets, project ids, bucket names, or environment-specific values in
  prompts (GUARDRAILS rule 4).
- Placeholders are `{{snake_case}}` and must be listed in the version's
  CHANGELOG; rendering fails closed on unknown placeholders.
- `response.schema.json` is passed to Vertex AI as `response_schema` **and**
  used for server-side validation, so it must stay within the Vertex-supported
  subset (no `$ref`, `allOf`, `if/then`, `pattern`).

Current tasks

| Task | Latest | Design |
|---|---|---|
| `receipt_parse` | v1 (draft) | `docs/design/gemini-receipt-parser.md` |
