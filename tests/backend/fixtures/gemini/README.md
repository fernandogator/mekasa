# Gemini fixtures

Scripted responses for the phase-2 `FakeReceiptLLMClient`
(`docs/design/gemini-receipt-parser.md` §7). Each `*.v1.json` file must
validate against `backend/prompts/receipt_parse/v1/response.schema.json`
(checked by `test_prompt_contract.py`).

| File | Source | Notes |
|---|---|---|
| `heb_round_rock_40_lines.v1.json` | Real Gemini 2.5 Pro output from the prototype prompt, reduced to v1 fields | 40 lines / 54 units, weighed produce, 2-for pricing, one taxable line; sums reconcile exactly. Header/tender/transaction lines were not carried over. |

Fixtures contain purchase lines only — never card, loyalty, phone, cashier,
or transaction identifiers.
