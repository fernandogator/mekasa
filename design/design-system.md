# Mekasa Design System

> Living token document. Visual source: Superdesign library style
> `babybites-sophisticated-palette`, adapted for household inventory.
> Native Compose / SwiftUI maps these tokens structurally (not pixel-exact).

## Brand

- Product name: **Mekasa** (from "mi casa")
- Voice: warm, practical, household-first
- Wordmark: Nunito 900. No invented logo mark, initials, or emoji brand.

## Color Tokens

### Light

| Token | Role | Value |
|-------|------|-------|
| `--color-brand` | Charcoal ink / dark surfaces | `#171e19` |
| `--color-brand-muted` | Sage gray-green secondary | `#b7c6c2` |
| `--color-surface` | Page / screen background | `#eeebe3` |
| `--color-surface-elevated` | Interactive surfaces only | `#ffffff` |
| `--color-text` | Primary text | `#171e19` |
| `--color-text-muted` | Secondary text | `#6d7a76` |
| `--color-accent` | CTA / focus | `#ca0013` |
| `--color-danger` | Destructive actions | `#ca0013` |
| `--color-success` | Positive confirmation | `#2f6b4f` |
| `--color-warning` | Low-stock / pending | `#c45c12` |
| `--color-accent-tint` | Alert icon wells, selected receipt tiles | `#fce5e7` |
| `--color-success-tint` | Success icon wells, member chips | `#eaf1ec` |
| `--color-warning-tint` | Pending-approval rows | `#fff5f0` |
| `--color-surface-muted` | Wells, image placeholders, steppers, unselected options | `#f1f4f3` |
| `--color-progress-track` | Progress bar track | `#d5ddd9` |
| `--color-on-brand` | Text and icons on brand / accent / success / warning fills and photos | `#ffffff` |
| `--color-on-brand-muted` | Inactive tab icons on the brand tab bar | `#b7c6c2` |
| `--color-camera-surface` | Camera, scanner and full-screen photo backgrounds | `#000000` |
| `--color-on-camera` | Text, icons and reticle over the camera | `#ffffff` |
| `--color-scrim` | Overlay on photos, used with opacity (iOS black, Android brand) | `#000000` / `#171e19` |
| `--color-shadow` | Drop shadows, used with opacity | `#000000` |
| `--color-grade-a` … `--color-grade-d` | Health grades A–D (E uses accent) | `#1f8a4c` `#6fa82f` `#d9a406` `#e06c1a` |

These roles are the only colors screens may use (spec NFR-005 AC5). The camera, scrim and shadow roles still use pure black from before this rule; the upcoming color scheme should replace them with near-charcoal, and every text/background pair must pass WCAG AA (NFR-005 AC2) before adoption.

### Dark

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
Never use pure black; always `#171e19` (light) / near-charcoal (dark).
Accent red is reserved for primary actions and critical alerts.

## Typography

| Token | Use | Value |
|-------|-----|-------|
| `--font-display` | Brand / hero | Nunito 900, 32px |
| `--font-body` | Body copy | Nunito 400–600, 16px |
| `--font-label` | Eyebrow labels | Nunito 700, 10–12px, uppercase, tracked |
| `--font-mono` | Codes / barcodes | ui-monospace / SF Mono / Menlo, 13px |

Do not use Inter, Roboto, Arial, or system UI as the product typeface.

## Spacing Scale

`4 / 8 / 12 / 16 / 24 / 32 / 48`

- Main cards / sheets: 40px radius
- Nested rows / tiles: 24px radius
- Screen gutter: 24px
- Bottom nav pill: 64px tall, 8px from edges, `#171e19`

## Elevation

Cards (interactive only): `0 20px 50px -12px rgba(0,0,0,0.08)`.
Borders: `1px solid #b7c6c2` at 20–30% opacity.
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
