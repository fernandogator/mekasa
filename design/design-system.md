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
| OnboardingHouseholdSetup | — | `design/mockups/OnboardingHouseholdSetup.jsx` |
| SpendingReport | — | `design/mockups/SpendingReport.jsx` |
| FamilyMembers | — | `design/mockups/FamilyMembers.jsx` |

## Motion

View changes: 0.25s ease-in-out fade / 8px rise. FAB press: 0.12s scale.
Trash Station deplete: short success pulse. No decorative looping motion on lists.
