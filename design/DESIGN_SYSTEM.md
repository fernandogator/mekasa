# Mekasa Design System - Complete Reference

## 🎨 Color Palette (Light Mode)

| Token | Role | Value | Usage |
|-------|------|-------|-------|
| `--color-brand` | Charcoal ink / dark surfaces | `#171e19` | Primary text, backgrounds, nav bar |
| `--color-brand-muted` | Sage gray-green secondary | `#b7c6c2` | Borders, secondary text, inactive icons |
| `--color-surface` | Page background (warm off-white) | `#eeebe3` | Main page background, safe area |
| `--color-surface-elevated` | Interactive cards / sheets | `#ffffff` | Card fills, input backgrounds |
| `--color-text` | Primary text | `#171e19` | All body copy |
| `--color-text-muted` | Labels, distances, secondary | `#6d7a76` | Secondary labels, hints |
| `--color-accent` | CTA / focus / critical action | `#ca0013` | Primary buttons, FAB, alerts |
| `--color-danger` | Destructive (same family as accent) | `#ca0013` | Delete actions, critical warnings |
| `--color-success` | Positive confirmation | `#2f6b4f` | Checkmarks, successful states, green accents |
| `--color-warning` | Low-stock / pending approval | `#c45c12` | Warning chips, pending states |
| `--color-overlay` | Sage wash / atmosphere | `rgba(183, 198, 194, 0.20)` | Sage blob background, subtle washes |

### CSS Variables
```css
:root {
  --color-brand: #171e19;
  --color-brand-muted: #b7c6c2;
  --color-surface: #eeebe3;
  --color-surface-elevated: #ffffff;
  --color-text: #171e19;
  --color-text-muted: #6d7a76;
  --color-accent: #ca0013;
  --color-danger: #ca0013;
  --color-success: #2f6b4f;
  --color-warning: #c45c12;
  --color-overlay: rgba(183, 198, 194, 0.20);
}
```

## 📝 Typography

**Font Family**: Nunito (Google Fonts)

| Role | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|--------|-------------|----------------|-------|
| Brand / Hero | 32px | 900 | 1.2 | tight | Wordmark **Mekasa** |
| Screen Title | 28–32px | 900 | 1.2 | tight | Sentence case, page headers |
| Subhead | 20px | 800 | 1.3 | tight | Section titles |
| Body | 16px | 400–600 | 1.4 | normal | Default text, descriptions |
| Label | 10–12px | 700 | 1.2 | 0.08–0.12em | Uppercase, secondary text |
| Mono / Barcode | 13px | 600 | 1.2 | normal | UPC codes only |

### Import
```html
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap" rel="stylesheet">
```

## 📏 Spacing Scale

All spacing follows this 8px-based scale:
```
4px, 8px, 12px, 16px, 24px, 32px, 48px
```

**Usage**:
- Micro gaps: 4px
- Small gutters: 8px
- Content padding: 16px–24px
- Section spacing: 24px–32px
- Hero/large sections: 48px

## 🎯 Radius & Elevation

| Element | Radius | Shadow | Notes |
|---------|--------|--------|-------|
| Main cards/sheets | 40px | `0 20px 50px -12px rgba(0,0,0,0.08)` | Large interactive containers |
| Nested items/list rows | 24px | None (hover bg only) | Items within cards |
| Pills/chips | 999px | None | Badge-style elements |
| Icon wells | 16px | None | Circular icon containers |
| Input fields | 24px | None (border only) | Form inputs |
| Buttons | 24px or 999px | Varies by state | CTA 56px min height |
| FAB | 56px (circle) | `0 8px 16px rgba(202,0,19,0.3)` | Center action button |

### Borders
```css
border: 1px solid #b7c6c2;
opacity: 20-30%;
```

## 🎨 Component Patterns

### Navigation Bar (Bottom Pill)
- Height: 64px
- Radius: 999px (full pill)
- Background: `#171e19` (brand color)
- Position: 8px from screen edges, above tab bar safe area
- Icons: 24px, white (active) / `#b7c6c2` (inactive)
- Active state: White icon
- Inactive state: Muted gray icon
- Hover: Color transition 0.15s

### Center Add FAB
- Size: 56px circle
- Background: `#ca0013` (accent)
- Icon: Plus (lucide:plus)
- Border: 4px solid `#eeebe3`
- Offset: −32px above nav bar
- Shadow: `0 8px 16px rgba(202,0,19,0.3)`
- Active press: scale-95 (0.12s transition)

### Primary CTA Button
- Height: 56px min
- Radius: 24px
- Background: `#ca0013` (accent)
- Text: White, 18px / 900
- Shadow: `0 8px 20px rgba(202,0,19,0.25)` (red tint)
- Active state: scale-95 (0.12s)
- Hover: opacity-90

### Secondary Button
- Height: 56px min
- Radius: 24px
- Background: `#ffffff` (surface-elevated)
- Border: 1px solid `#b7c6c2`
- Text: `#171e19`, 18px / 900
- Hover: bg-`#f1f4f3`
- Active state: scale-95

### Card Container
- Radius: 40px
- Background: `#ffffff`
- Border: 1px solid `rgba(183, 198, 194, 0.3)`
- Shadow: `0 20px 50px -12px rgba(0,0,0,0.08)`
- Padding: 16px–24px
- Gap (list items): 4px

### List Item Row
- Height: 56px–72px
- Radius: 24px
- Padding: 12px–16px horizontal, 12px vertical
- Hover: bg-`#f8f9f8` (light gray)
- Active: No background change
- Divider: None (gap between items)

### Input Field
- Height: 56px
- Radius: 24px
- Background: `#ffffff`
- Border: 1px solid `rgba(183, 198, 194, 0.3)`
- Padding: 16px left/right
- Font: 16px / 600
- Focus: ring-2 ring-`#ca0013`

### Stat Card
- Icon well: 32px–40px, rounded full or square
- Icon background: Colored tint (e.g., `#fce5e7` for alerts, `#eaf1ec` for success)
- Label: 10px / 700 uppercase, muted color
- Value: 24px / 900, brand color

### Hero Section
- Height: 150px (dashboard)
- Background: Full-bleed image, 30–50% position
- Overlay: Gradient from `rgba(23,30,25,0.1)` to `rgba(23,30,25,0.35)`
- Text: Centered, white
- Bell icon: 40px, bg-white/20, backdrop-blur

### Sage Blob Atmosphere
- Size: 300×300px
- Border-radius: 50%
- Background: `rgba(183, 198, 194, 0.20)`
- Filter: blur(40px)
- Position: top -50px, right -50px (upper right corner)
- z-index: 0 (behind all content)
- pointer-events: none

## ✨ Motion & Transitions

### View Transitions (Page Navigation)
```css
@view-transition { navigation: auto; }
::view-transition-old(main-content) { animation: 0.25s ease-out both fade-out; }
::view-transition-new(main-content) { animation: 0.25s ease-in 0.1s both fade-in; }

@keyframes fade-out {
  from { opacity: 1; transform: translateY(0); }
  to { opacity: 0; transform: translateY(-8px); }
}
@keyframes fade-in {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
```

### Persistent Elements (No Transition)
```css
::view-transition-old(nav), ::view-transition-new(nav),
::view-transition-old(fab), ::view-transition-new(fab),
::view-transition-old(sage-blob), ::view-transition-new(sage-blob) {
  animation: none;
  mix-blend-mode: normal;
}
```

### Micro-Interactions
- Button press: 0.12s scale 0.96
- Icon hover: 0.15s color transition
- Background hover: 0.15s opacity/color shift
- FAB tap: 0.12s scale 0.95

## 🔥 Approval Workflow Colors

| State | Background | Text | Icon | Chip Color |
|-------|-----------|------|------|-----------|
| Pending | `#fff5f0` | `#c45c12` | warning (orange) | "Needs approval" orange chip |
| Approved | `#eaf1ec` | `#2f6b4f` | success (green) | "Added to list" green chip |
| Rejected | Normal | Muted | X icon | None |

## 📱 Layout Grid & Padding

### Screen Dimensions
- Mobile: 390px width × 844px height
- Safe area top: ~56px (status bar + safe inset)
- Safe area bottom: ~68px (home indicator)
- Horizontal gutter: 24px left/right

### Header Layout
- Padding top: 56px from top of screen
- Padding left/right: 24px
- Content height: 40–60px (depends on content)

### Content Area
- Padding top: 16px–24px after header
- Padding left/right: 24px
- Padding bottom: 160px (for fixed nav + FAB)

### Bottom Navigation
- Position: fixed, 8px from left/right edges
- Bottom: 32px (above safe area)
- Height: 64px
- Spacing between icons: Even distribution
- FAB offset: −32px above nav

## 🏗️ Component Hierarchy

```
Screen
├── Sage Blob (background)
├── Header (if applicable)
│   ├── Status label
│   ├── Title
│   └── Actions (settings, more)
├── Main Content (scrollable)
│   ├── Hero / Intro
│   ├── Section headers
│   ├── Cards/Containers
│   │   └── List items / Content
│   └── CTAs
└── Fixed Bottom
    ├── Navigation Bar (persistent)
    └── FAB (persistent)
```

## 🎯 Design Principles

1. **Warm & Practical**: Household-focused, never cutesy
2. **Clear Hierarchy**: Charcoal text on warm backgrounds
3. **Intentional Color**: Red (#ca0013) only for critical actions
4. **Efficient Space**: Asymmetric layouts, generous gaps
5. **Smooth Motion**: 0.25s transitions, subtle easing
6. **Consistent Components**: Reusable patterns across all screens
7. **Accessible**: 1.4+ line height, high contrast, clear labeling

## 📊 Dark Mode (Future)

Tokens exist for dark implementation parity:
```css
/* Dark Mode Overrides */
--color-brand: #1f2a24;              /* Elevated dark green-charcoal */
--color-surface: #121612;            /* Dark background */
--color-surface-elevated: #1c241f;   /* Dark cards */
--color-text: #eeebe3;               /* Light text */
--color-text-muted: #9aada8;         /* Light secondary */
--color-accent: #ff3b4e;             /* Lifted red for contrast */
--color-brand-muted: #5e706c;        /* Dark borders */
--color-success: #5dba8a;            /* Light green */
```

---

**Last Updated**: Current version
**Platform**: Mobile-first (iOS/Android compatible)
**Font License**: Nunito (Google Fonts, OFL)

