# Mekasa Design System

Living visual source of truth for Superdesign mockups. Native clients (Jetpack Compose / SwiftUI) implement these tokens structurally, not pixel-for-pixel.

**Style source:** Superdesign library prompt `babybites-sophisticated-palette` (mobile-first, sophisticated-playful). Adapted for household inventory — not a parenting app clone. Do not blend a second library style.

## Product context

**Mekasa** (from “mi casa”) is a household inventory app. Families keep a shared pantry/fridge truth, auto-build shopping lists, track spending by category, and deplete items quickly at the trash station.

**Audience:** household admins and members on iOS and Android. Primary device is a phone.

**Voice:** warm, practical, household-first. Confident, never cutesy. Spanish etymology is a wink, not a theme.

**Jobs to be done**
1. Know what is in the house without opening every cabinet.
2. Shop from a list the household already agrees on.
3. Add items the way the moment allows (barcode, receipt, voice, manual).
4. Mark things gone in two taps when throwing them away.
5. See where the household money went this month.

## Key screens & architecture

Onboarding (no tab bar): Welcome → Household name + photo → GPS address → **Store selection** → Initial inventory scan → Invite members → Dashboard.

Logged-in shell (bottom nav + center Add FAB): **Dashboard** · Inventory · **Shopping List** · Spending · Settings. **Add Items** is the raised center action. **Trash Station** is reached from Add Items.

Mockup set for this project:
- Dashboard (UI-001) — home hub after onboarding
- OnboardingStoreSelection (UI-002) — nearby stores within 15 miles
- ShoppingList (UI-003) — shared list + approve/reject
- AddItems (UI-004) — barcode / receipt / voice / manual / trash
- TrashStationMode (UI-005) — rapid depletion
- OnboardingHouseholdSetup — household name + optional home photo
- SpendingReport — category spend for a period
- FamilyMembers — household roster, roles, invites

## Branding & styling

### Color (light)

| Token | Role | Value |
|-------|------|-------|
| `--color-brand` | Charcoal ink / dark surfaces | `#171e19` |
| `--color-brand-muted` | Sage gray-green secondary | `#b7c6c2` |
| `--color-surface` | Page background (warm off-white) | `#eeebe3` |
| `--color-surface-elevated` | Interactive cards / sheets only | `#ffffff` |
| `--color-text` | Primary text | `#171e19` |
| `--color-text-muted` | Labels, distances, secondary | `#6d7a76` |
| `--color-accent` | CTA / focus / critical action | `#ca0013` |
| `--color-danger` | Destructive (same family as accent) | `#ca0013` |
| `--color-success` | Positive confirmation | `#2f6b4f` |
| `--color-warning` | Low-stock / pending approval | `#c45c12` |
| `--color-overlay` | Sage wash / atmosphere | `rgba(183, 198, 194, 0.20)` |

MUST use `#ca0013` exclusively for primary actions and critical alerts. MUST NOT use pure black — always `#171e19`. MUST NOT introduce purple, indigo, terracotta, cream-serif luxury palettes, or neon.

### Color (dark)

| Token | Role | Value |
|-------|------|-------|
| `--color-brand` | Elevated dark green-charcoal | `#1f2a24` |
| `--color-surface` | Page background | `#121612` |
| `--color-surface-elevated` | Cards / sheets | `#1c241f` |
| `--color-text` | Primary text | `#eeebe3` |
| `--color-text-muted` | Secondary | `#9aada8` |
| `--color-accent` | CTA | `#ff3b4e` (slightly lifted for contrast) |
| `--color-brand-muted` | Borders / inactive icons | `#5e706c` |
| `--color-success` | Positive | `#5dba8a` |

Mockups in this project ship **light mode** as the default canvas. Dark tokens exist so native implementations can map 1:1.

### Atmosphere

Prefer atmosphere over a flat fill: a large sage blob (`--color-overlay`) in the upper-right of the screen, 8–12% grain optional, no full-bleed photography required. Heroes are open type + atmosphere, not card stacks.

### Typography

Google Fonts: **Nunito** for all UI text (400 / 600 / 800 / 900). No Inter, Roboto, Arial, system UI, and no serif display.

| Role | Size | Weight | Notes |
|------|------|--------|-------|
| Brand / hero | 32px | 900 | Wordmark **Mekasa** is a hero-level signal on branded surfaces |
| Screen title | 28–32px | 900 | Sentence case |
| Subhead | 20px | 800 | |
| Body | 16px | 400–600 | Line-height 1.4 |
| Label | 10–12px | 700 | Uppercase, 0.08–0.12em tracking, muted color |
| Mono / barcode | 13px | 600 | `ui-monospace, "SF Mono", Menlo` for UPC only |

### Radius, spacing, elevation

- Spacing scale: `4 / 8 / 12 / 16 / 24 / 32 / 48`
- Main cards / sheets: `40px` (2.5rem)
- Nested items / list rows: `24px` (1.5rem)
- Pills / chips: `999px`
- Icon wells: `16px` square or circle
- Borders: `1px solid #b7c6c2` at 20–30% opacity
- Shadow: `0 20px 50px -12px rgba(0,0,0,0.08)` on elevated interactive surfaces only
- Screen padding: 24px horizontal; header starts ~56px from top (status-bar safe)

### Buttons & controls

- Primary CTA: 56px min height, `#ca0013` fill, white label, 999px or 24px radius, red-tinted shadow
- Secondary: white fill, sage border, charcoal label
- Center Add FAB: 56px circle `#ca0013`, white plus, 4px `--color-surface` ring, offset −32px above the tab bar
- Checkboxes: 40px circular hit target; checked fill `#ca0013`
- Selection rows: selected = charcoal fill + white type, or 2px accent ring — never a purple check

### Layout structure

**Logged-in shell**
- Status bar + greeting header (12px uppercase muted label + 30px household name)
- Scrollable content, 24px gutter
- Fixed bottom pill nav, 8px from screen edges, height 64px, fill `#171e19`
- Destinations: Home, List, **Add (FAB)**, Spend, People
- Active icon white; inactive `#b7c6c2`

**Onboarding shell**
- No tab bar
- Top: step index (`2 / 6`) as 10px uppercase label + Mekasa wordmark
- Bottom: sticky primary CTA (“Continue”, “Confirm stores”)
- Progress as a thin charcoal track, not a rainbow

**Cards** are interaction containers only (tappable store row, list item, method tile). Do not wrap the whole screen in a card. Do not bento-clutter the dashboard hero.

## Motion

- View transitions: 0.25s ease-in-out fade / 8px rise
- FAB press: 0.12s scale 0.96
- Trash Station: a short confirming pulse on deplete (success green flash), not confetti
- No decorative looping animation on lists

## Component patterns (reuse across screens)

- **StoreListRow** — 72px min, name 16/800, distance 12 muted, radio/check on the right
- **ShoppingListItem** — name + qty, optional “Needs approval” warning chip, circular check, requester avatar 32px
- **AddMethodTile** — 56px icon well, title 18/800, one-line subtitle muted
- **MemberRow** — avatar, name, role chip (Admin / Member), overflow
- **SpendCategoryBar** — label, amount, sage track with charcoal fill (accent only for over-budget)
- **EmptyState** — short practical copy, one primary action, no illustration maze

## Content rules

- Use realistic household copy (H-E-B, Costco, “2% milk”, “low: eggs”) — US English
- Distances in miles (15-mile discovery radius)
- Currency USD
- Never placeholder lorem
- Never invent a logo mark, initials-in-a-circle, or emoji wordmark. The brand is the **Mekasa** wordmark in Nunito 900. If a logo position exists, set the wordmark there — do not draw a house icon as the brand.

## Platform notes

Mockups are mobile (390×844). They inform Compose Material 3 / SwiftUI HIG implementations. Semantic structure matters more than CSS tricks. Light + dark token parity is required even when the canvas shows light.
