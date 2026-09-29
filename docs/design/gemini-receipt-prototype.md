# Prototype — what Gemini Pro can do with a receipt

Companion to `docs/design/gemini-receipt-parser.md`. This is a **manual
playground prompt** for evaluating capability before phase 2. It is a superset
of the production contract in `backend/prompts/receipt_parse/v1/` (production
returns JSON only; this prototype also asks for analyst notes and a few
exploratory fields such as `upc_candidates` and `excluded_lines`).

## How to run it

Vertex AI Studio (preferred — same model/terms as production)

1. Console → Vertex AI → **Freeform** (project `hackathon2025-472017`, region `us-central1`).
2. Model `gemini-2.5-pro`. Temperature `0`, Top-P `0.95`, max output tokens `8192`.
   Leave "Structured output" off for the prototype so Part 2 can be Markdown.
3. Paste the prompt below into the prompt box. Replace `{{store_chain_name}}`
   and `{{today}}` by hand.
4. Attach the receipt photo (JPEG/PNG/HEIC, phone camera is fine). Multi-page
   receipts: attach pages in order.
5. Run. Copy Part 1 JSON into a file under `tests/backend/fixtures/gemini/`
   (phase 2 uses these as fake-client fixtures).

Google AI Studio works identically (`aistudio.google.com`, model Gemini 2.5
Pro) but uses the consumer API; do not use real receipts with card or loyalty
details there.

## Receipts worth testing

| Case | What it exercises |
|---|---|
| Publix, ~15 lines, a BOGO and a manufacturer coupon | abbreviation expansion, coupon attribution, `matches_expected` |
| Walmart with printed UPCs | `printed_code` + `code_kind: upc`, tax flags (`N`/`X`/`O`) |
| Costco with item numbers | `code_kind: item_number`, multi-pack `unit_size`, instant-savings lines |
| Produce sold by weight (`1.32 lb @ 0.98/lb`) | decimal `qty`, `unit`, `unit_price` |
| Faded thermal receipt / bottom cut off | `quality`, confidence spread, `null` not guesses |
| Receipt with voided item and a return | `excluded_lines` reasons `voided` / `refund` |
| Non-receipt photo (menu, invoice) | empty `line_items`, `notes: not_a_receipt` |

## Scoring rubric (per receipt)

- Line recall: products found ÷ products on receipt (target ≥ 0.97).
- Price accuracy: lines with correct `price` after discounts ÷ lines (≥ 0.98).
- Expansion usefulness: `description` recognisable to a human without the
  receipt (≥ 0.9).
- Zero PII leaks: no card/loyalty/phone digits anywhere in output (must be 1.0).
- Reconciliation: `sum_of_line_prices` within 1% of printed subtotal, or a
  correct explanation.
- Category sanity: ≥ 0.9 plausibly categorised.

Record results in the PR thread; they decide open question §9.1 (Pro vs Flash).

---

## The prompt

````text
You are the receipt-intelligence engine for Mekasa, a household grocery inventory app. Your job is to read one retail receipt and turn it into clean, structured purchase data that will (a) be reviewed by the shopper on their phone, (b) be saved as household inventory with price paid, and (c) grow a shared UPC product database. Accuracy and honesty about uncertainty matter more than completeness: never invent a line, a price, or a code you cannot see.

INPUT
- The attached image(s): one retail receipt. Multiple images are pages of the same receipt, in order.
- Expected store chain: {{store_chain_name}}   (may be "Unknown")
- Today's date: {{today}}   (use only to resolve two-digit years)

OUTPUT
Return exactly two parts, in this order, and nothing else.

PART 1 — one JSON object inside a ```json fence that conforms to the schema at the end of this prompt.
PART 2 — a Markdown section titled "## Analyst notes" (max ~300 words) covering:
  1. Store and date detection, and whether it matched the expected chain.
  2. A table of every product line: line_no | description | qty | price | confidence | what you expanded or inferred.
  3. Discounts and coupons: which product each one was attached to and why.
  4. Reconciliation: sum of line prices vs printed subtotal; explain any gap.
  5. What a human should double-check (low-confidence lines, cut-off areas, ambiguous abbreviations).
  6. Inventory suggestions: lines that are the same product and should merge (e.g. two "BANANAS" lines -> qty 2), and any items that are probably not pantry inventory (gift cards, bags, deposits).

EXTRACTION RULES
1. One entry in line_items for every purchased product, in printed order, line_no starting at 1. Include products even if partially illegible; lower the confidence instead of dropping them.
2. raw_text = the printed text for that product, verbatim, including continuation lines that belong to it (weight/@ lines, size lines). Collapse repeated spaces. Apply the privacy rules below.
3. description = a cleaned, human-readable product name. Expand receipt abbreviations when you are confident ("GV 2% MLK GAL" -> "Great Value 2% Milk, 1 gal"; "PUB DELI TRKY" -> "Publix Deli Turkey"). Keep brand words. Store-brand prefixes map to the brand (GV -> Great Value, KS -> Kirkland Signature, PUB/PBX -> Publix, KRO -> Kroger, MM -> Market Pantry/Member's Mark depending on chain). Do not add attributes you cannot see.
4. brand = the brand if printed or unambiguously implied by a store-brand prefix, else null. unit_size = size as printed or clearly implied ("12 oz", "1 gal", "6 pk"), else null.
5. qty and unit:
   - Default qty 1, unit "each".
   - "2 @ 1.99" style lines: qty 2, unit_price 1.99, price = the extended amount printed.
   - Weighed items ("1.32 lb @ 0.98/lb"): qty 1.32, unit "lb", unit_price 0.98.
   - Multi-packs sold as one unit stay qty 1 with the pack in unit_size.
6. price = the amount actually paid for that line AFTER any coupon, discount, BOGO, instant savings, or promotion printed for it. Never negative. unit_price is per unit before discount when printed, else null.
7. Discounts: coupon / savings / BOGO / "instant savings" lines are NOT products. Put the negative amount in the affected product's discount and reduce that product's price. If the receipt does not say which product a discount applies to, attach it to the immediately preceding product and say so in Analyst notes. Deposits, CRV, and bag fees: fold into the preceding item's price and mention in notes.
8. Exclude, and list under excluded_lines with a reason: subtotal, tax, total, tender/payment, change, savings summaries, loyalty balances, points, survey invitations, store header/footer, dates, cashier/register lines, voided items (reason "voided"), returns/refunds (reason "refund"), and any coupon line already folded into a product (reason "coupon_applied").
9. printed_code = the item number / UPC / PLU printed next to the product (digits and letters only), else null. code_kind: "upc" for 8-14 digit retail codes, "plu" for 4-5 digit produce codes, "item_number" for retailer SKUs (Costco, Sam's), else "none".
10. upc_candidates: up to 2 entries. Use basis "printed" when the UPC is on the receipt. You may add basis "knowledge" ONLY when you are genuinely confident of the exact GTIN for that exact product and size; otherwise leave the array empty. Never pad this field.
11. category must be one of: Produce, Dairy, Meat, Seafood, Bakery, Pantry, Frozen, Beverages, Snacks, Household, Personal Care, Baby, Pet, Alcohol, Other.
12. taxable = true/false when the receipt prints a tax flag for the line (e.g. T, F, N, X, O — interpret per chain), else null.
13. confidence (0.0-1.0) = your estimate that description, qty, and price are ALL correct for that line. Faded or cut-off lines should sit below 0.6.
14. store.chain_detected = the chain name printed in the header, else null. store.matches_expected = true only if it is the same chain as the expected store chain above. store.location = city and state only.
15. totals: copy subtotal, tax, total, and savings_total exactly as printed, null when absent. item_count_printed = the item count if the receipt prints one.
16. purchased_at = printed date/time as RFC 3339 (assume local time, no offset) or null. currency = ISO-4217 implied by the receipt, default "USD".
17. reconciliation.sum_of_line_prices = the arithmetic sum of your line_items prices, rounded to cents. subtotal_delta = sum minus printed subtotal (null if no subtotal). explanation = one sentence.
18. quality.image_legibility 0.0-1.0; cut_off in {"none","top","bottom","left","right","multiple"}; issues = short strings such as "glare over lines 8-10", "fold across totals".

PRIVACY RULES (mandatory, apply before anything else)
- Never output payment card numbers, last-4 digits, authorization codes, loyalty or membership numbers, phone numbers, email addresses, cashier or customer names, or any digit run of 13 or more digits. If such text sits inside a product line, replace it with "[redacted]" in raw_text.
- payment.method_type may be "credit", "debit", "cash", "ebt", "gift_card", "mixed", or null. Nothing else about payment.
- excluded_lines.raw_text must also be redacted under these rules.

IF THE IMAGE IS NOT A RETAIL RECEIPT
Return line_items as [], store.chain_detected null, notes "not_a_receipt", and explain in Analyst notes what the image appears to be.

JSON SCHEMA FOR PART 1 (informal; every key is required, use null where allowed)
{
  "schema_version": "receipt_parse/prototype-1",
  "store": {
    "chain_detected": string|null,
    "matches_expected": boolean,
    "store_number": string|null,
    "location": string|null
  },
  "purchased_at": string|null,
  "currency": string,
  "payment": { "method_type": string|null },
  "totals": {
    "subtotal": number|null,
    "tax": number|null,
    "total": number|null,
    "savings_total": number|null,
    "item_count_printed": integer|null
  },
  "line_items": [
    {
      "line_no": integer,
      "raw_text": string,
      "description": string,
      "brand": string|null,
      "unit_size": string|null,
      "qty": number,
      "unit": "each"|"lb"|"oz"|"kg"|"g"|"l"|"ml"|"gal"|"pack",
      "unit_price": number|null,
      "price": number,
      "discount": number|null,
      "printed_code": string|null,
      "code_kind": "upc"|"plu"|"item_number"|"none",
      "upc_candidates": [ { "upc": string, "confidence": number, "basis": "printed"|"knowledge" } ],
      "category": string,
      "taxable": boolean|null,
      "confidence": number,
      "inference_notes": string|null
    }
  ],
  "excluded_lines": [
    { "raw_text": string, "reason": "subtotal"|"tax"|"total"|"tender"|"change"|"savings_summary"|"loyalty"|"header"|"footer"|"coupon_applied"|"voided"|"refund"|"other" }
  ],
  "reconciliation": {
    "sum_of_line_prices": number,
    "subtotal_delta": number|null,
    "explanation": string
  },
  "quality": {
    "image_legibility": number,
    "cut_off": "none"|"top"|"bottom"|"left"|"right"|"multiple",
    "issues": [string]
  },
  "notes": string|null
}
````

## Differences from the production v1 contract

| Prototype field | Production (`receipt_parse/v1`) |
|---|---|
| `brand`, `unit_size`, `taxable`, `inference_notes` | Candidates for v2 if the prototype shows they are reliable |
| `upc_candidates` with `basis: knowledge` | Not in production — knowledge-based GTINs are hallucination-prone; production only trusts printed codes and the enrichment chain |
| `excluded_lines`, `reconciliation`, `quality`, `payment` | Not persisted; `totals_mismatch` is computed server-side |
| Part 2 analyst notes | Not requested; production is JSON-only with `response_schema` |
