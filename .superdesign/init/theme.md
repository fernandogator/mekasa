# Theme / Design Tokens

## Part 1 — Compact token summary

**Product:** Mekasa (from "mi casa") — household inventory, warm/practical voice.

**Colors (placeholders — finalize in Superdesign):**

| Token | Role | Value |
|-------|------|-------|
| `--color-brand` | Primary brand | TBD |
| `--color-brand-muted` | Secondary brand | TBD |
| `--color-surface` | Page / screen background | TBD |
| `--color-surface-elevated` | Interactive surfaces only | TBD |
| `--color-text` | Primary text | TBD |
| `--color-text-muted` | Secondary text | TBD |
| `--color-accent` | CTA / focus | TBD |
| `--color-danger` | Destructive actions | TBD |
| `--color-success` | Positive confirmation | TBD |

Light and dark mode required.

**Typography (placeholders):**

| Token | Use | Value |
|-------|-----|-------|
| `--font-display` | Brand / hero | TBD — expressive; avoid Inter/Roboto/Arial/system |
| `--font-body` | Body copy | TBD |
| `--font-mono` | Codes / barcodes | TBD |

**Spacing:** `4 / 8 / 12 / 16 / 24 / 32 / 48` (finalize with Superdesign)

**Motion:** intentional hierarchy/presence; avoid decorative noise.

**Design constraints (from product/frontend rules):**
- Brand name Mekasa is a hero-level signal on branded screens
- No card clutter in heroes; cards only for interaction containers
- Prefer atmosphere (gradients/patterns) over flat single-color backgrounds
- Avoid purple-on-white / purple-indigo gradient clichés; avoid default cream+terracotta+serif cluster
- Target: mobile-first mockups that inform Compose/SwiftUI (not a shipped web app)

No `tailwind.config` or `globals.css` exists yet.

## Part 2 — Raw source dumps

### `design/design-system.md`

```md
# Mekasa Design System (scaffold)

> Living token document. Values will be finalized during the Superdesign session
> (Phase 4). Do not ship UI that invents tokens outside this file.

## Brand

- Product name: **Mekasa** (from "mi casa")
- Voice: warm, practical, household-first

## Color Tokens (placeholders)

| Token | Role | Placeholder |
|-------|------|-------------|
| `--color-brand` | Primary brand | TBD |
| `--color-brand-muted` | Secondary brand | TBD |
| `--color-surface` | Page / screen background | TBD |
| `--color-surface-elevated` | Interactive surfaces only | TBD |
| `--color-text` | Primary text | TBD |
| `--color-text-muted` | Secondary text | TBD |
| `--color-accent` | CTA / focus | TBD |
| `--color-danger` | Destructive actions | TBD |
| `--color-success` | Positive confirmation | TBD |

Light and dark mode variants required (see UI platform requirements).

## Typography (placeholders)

| Token | Use | Placeholder |
|-------|-----|-------------|
| `--font-display` | Brand / hero | TBD — expressive, not Inter/Roboto/Arial/system |
| `--font-body` | Body copy | TBD |
| `--font-mono` | Codes / barcodes | TBD |

## Spacing Scale (placeholders)

`4 / 8 / 12 / 16 / 24 / 32 / 48` — finalize with Superdesign.

## Component Names

Named to align with UI requirements and mockups:

| Component | Spec | Mockup |
|-----------|------|--------|
| Dashboard | UI-001 | `design/mockups/Dashboard.jsx` |
| OnboardingStoreSelection | UI-002 | `design/mockups/OnboardingStoreSelection.jsx` |
| ShoppingList | UI-003 | `design/mockups/ShoppingList.jsx` |
| AddItems | UI-004 | `design/mockups/AddItems.jsx` |
| TrashStationMode | UI-005 | `design/mockups/TrashStationMode.jsx` |

## Motion

Ship intentional motion for hierarchy and presence on visually led surfaces.
Avoid decorative noise. Details TBD with Superdesign.
```
