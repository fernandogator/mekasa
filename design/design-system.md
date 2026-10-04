# Mekasa Design System

> Living token document. Visual source: Superdesign library style
> `babybites-sophisticated-palette`, adapted for household inventory.
> Native Compose / SwiftUI maps these tokens structurally (not pixel-exact).

## Brand

- Product name: **Mekasa** (from "mi casa")
- Voice: warm, practical, household-first
- Wordmark: Nunito 900. No invented logo mark, initials, or emoji brand.

## Color Tokens

### Light (Rich & Grounded, 2026-10-04)

| Token | Role | Value |
|-------|------|-------|
| `--color-brand` | Warm charcoal: nav pill, dark fills, progress fill | `#5d5652` |
| `--color-brand-muted` | Decorative sage: blobs, icon wells, tracks (never text) | `#8fa085` |
| `--color-surface` | Page / screen background | `#ede8e0` |
| `--color-surface-elevated` | Cards / sheets | `#faf7f3` |
| `--color-text` | Primary text | `#5d5652` |
| `--color-text-muted` | Secondary text, labels, codes | `#5c6b54` |
| `--color-accent` | Primary buttons, FAB, focus, positive states | `#5a6f4f` |
| `--color-danger` | Destructive actions, errors | `#a44a3f` |
| `--color-success` | Positive confirmation | `#5a6f4f` |
| `--color-warning` | Warning text (Needs scan, low stock, pending) | `#8b5c32` |
| `--color-warning-tint` | Warning chip background | `#f3e6d8` |
| `--color-success-tint` | Match / success chip background | `#dce8d3` |
| `--color-border` | Icons, input borders, chip outlines | `#76896b` |
| `--color-on-brand-muted` | Inactive icons on the brand nav pill | `#c9d6c0` |
| `--color-camera-surface` | Camera viewfinder and full-screen camera | `#1a1918` |
| `--color-on-camera` | Text and icons on the camera surface | `#faf7f3` |
| `--color-overlay` | Sage wash / atmosphere | `rgba(143, 160, 133, 0.15)` |

Decorative only, never text: amber `#c48c5a` and light sage `#b8d4a8`.

Contrast (NFR-005 AC2, light appearance):

| Pair | Ratio | Needs |
|------|-------|-------|
| Text `#5d5652` on surface / elevated | 5.9 / 6.7 | 4.5 |
| Muted text `#5c6b54` on surface / elevated | 4.7 / 5.3 | 4.5 |
| Accent `#5a6f4f` text on surface / elevated | 4.5 / 5.2 | 4.5 |
| White on accent `#5a6f4f` | 5.5 | 4.5 |
| White on brand `#5d5652` | 7.2 | 4.5 |
| Danger `#a44a3f` on surface / elevated | 4.7 / 5.4 | 4.5 |
| Warning `#8b5c32` on surface / warning tint | 4.7 / 4.7 | 4.5 |
| Text `#5d5652` on success tint `#dce8d3` | 5.7 | 4.5 |
| Border `#76896b` on surface / elevated | 3.1 / 3.5 | 3 |
| `#c9d6c0` icon on brand `#5d5652` | 4.8 | 3 |
| `#faf7f3` on camera `#1a1918` | 16.4 | 4.5 |

The palette's original sage `#8fa085` (2.3:1 on surface) and amber `#c48c5a` (2.4:1) fail as text, so the text roles use the darker shades above. White text on amber or sage fills is not allowed.

### Dark

Dark tokens below predate the Rich & Grounded palette and are kept until a matching dark variant is designed; NFR-005 AC5 requires that variant to pass AC2 before the apps adopt the new palette.

| Token | Role | Value |
|-------|------|-------|
| `--color-brand` | Elevated dark green-charcoal | `#1f2a24` |
| `--color-surface` | Page background | `#121612` |
| `--color-surface-elevated` | Cards / sheets | `#1c241f` |
| `--color-text` | Primary text | `#eeebe3` |
| `--color-text-muted` | Secondary | `#9aada8` |
| `--color-accent` | CTA | `#ff3b4e` |
| `--color-brand-muted` | Borders / inactive | `#5e706c` |
| `--color-success` | Positive | `#5dba8a` |

Do not introduce purple, indigo, terracotta, cream-serif luxury, or neon palettes.
Never use pure black; dark fills use `#5d5652` (light) / near-charcoal (dark).
Danger red `#a44a3f` is reserved for destructive actions and errors.

## Typography

| Token | Use | Value |
|-------|-----|-------|
| `--font-display` | Brand / hero | Nunito 900, 32px |
| `--font-body` | Body copy | Nunito 400–600, 16px |
| `--font-label` | Eyebrow labels | Nunito 700, 12px minimum (NFR-005 AC1), uppercase, tracked |
| `--font-mono` | Codes / barcodes | ui-monospace / SF Mono / Menlo, 13px |

Do not use Inter, Roboto, Arial, or system UI as the product typeface.

## Spacing Scale

`4 / 8 / 12 / 16 / 24 / 32 / 48`

- Main cards / sheets: 40px radius
- Nested rows / tiles: 24px radius
- Screen gutter: 24px
- Bottom nav pill: 64px tall, 8px from edges, `#5d5652`

## Elevation

Cards (interactive only): `0 20px 50px -12px rgba(0,0,0,0.08)`.
Borders: decorative card edges `#8fa085` at 20–30% opacity; input borders and chip outlines `1px solid #76896b`.
Atmosphere: sage wash blob on `--color-surface`, not a flat fill and not a card-wrapped page.

## Component Names

| Component | Spec | Mockup |
|-----------|------|--------|
| Dashboard | UI-001 | `design/mockups/Dashboard.jsx` |
| OnboardingStoreSelection | UI-002 | `design/mockups/OnboardingStoreSelection.jsx` |
| ShoppingList | UI-003 | `design/mockups/ShoppingList.jsx` |
| AddItems | UI-004 | `design/mockups/AddItems.jsx` |
| TrashStationMode | UI-005 | `design/mockups/TrashStationMode.jsx` |
| InventoryList | UI-006 | `design/mockups/InventoryList.jsx` (+ `design/pages/inventory-list.html`) |
| ItemDetail | UI-006 | `design/mockups/ItemDetail.jsx` (+ `design/pages/item-detail.html`) |
| OnboardingHouseholdSetup | — | `design/mockups/OnboardingHouseholdSetup.jsx` |
| SpendingReport | — | `design/mockups/SpendingReport.jsx` |
| FamilyMembers | — | `design/mockups/FamilyMembers.jsx` |

### Product image (UI-006 / REQ-004)

| Token / pattern | Rule |
|-----------------|------|
| List thumbnail | 56×56pt (or 56px), 16px radius; OFF `image_front_small_url` preferred |
| Detail hero | ~280–320px tall, contain; OFF `image_front_url` preferred |
| Lightbox | Full-screen dark overlay; tap image or close to dismiss |
| Fallback | Category placeholder when no `image_url` (never block the row) |

## Motion

View changes: 0.25s ease-in-out fade / 8px rise. FAB press: 0.12s scale.
Trash Station deplete: short success pulse. No decorative looping motion on lists.
