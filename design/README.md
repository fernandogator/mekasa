# Mekasa Design System

🏠 **Mekasa** (mi casa — your home) is a household inventory app that helps families keep a shared pantry/fridge truth, auto-build shopping lists, track spending by category, and deplete items quickly at the trash station.

This folder contains the **complete design system**: 8 production-ready screens, design tokens, and implementation guides for web and native developers.

---

## 📱 What's Inside

### 🎨 Design Screens (8 total)

All screens are **390×844** (mobile-first, iPhone SE/13 mini) with full navigation and view transitions.

| # | Screen | Purpose | File |
|---|--------|---------|------|
| UI-001 | Dashboard | Home hub after onboarding | `pages/dashboard.html` |
| UI-002 | Store Selection | Onboarding step 4 — choose stores | `pages/store-selection.html` |
| UI-003 | Shopping List | Shared list with approval workflow | `pages/shopping-list.html` |
| UI-004 | Add Items | Multi-method input hub (barcode, voice, manual) | `pages/add-items.html` |
| UI-005 | Trash Station | Focused rapid depletion mode | `pages/trash-station.html` |
| UI-006 | Household Setup | Onboarding step 2 — name & photo | `pages/onboarding-household.html` |
| UI-007 | Spending Report | Category analytics & budget tracking | `pages/spending-report.html` |
| UI-008 | Family Members | Household roster & member roles | `pages/family-members.html` |

### 📚 Documentation

- **DESIGN_SYSTEM.md** — Complete color palette, typography, spacing, component patterns, and design tokens
- **IMPLEMENTATION.md** — Developer guides for web (HTML/Tailwind), iOS (SwiftUI), and Android (Jetpack Compose)
- **README.md** — This file

### 🎯 Key Features

✅ **View Transition API** — Smooth 0.25s fade + 8px rise animations between pages  
✅ **Responsive Mobile-First** — 390px canvas with proper safe areas  
✅ **Design System Tokens** — All colors, typography, spacing as CSS variables  
✅ **Persistent Navigation** — Bottom pill nav + center FAB across logged-in screens  
✅ **Focused Modes** — Trash Station modal with no global nav  
✅ **Onboarding Flow** — 6-step progression with step indicators  
✅ **Approval Workflows** — List items with request/approval patterns  
✅ **Accessibility** — Semantic HTML, high contrast, ARIA labels  

---

## 🚀 Quick Start

### View Locally

1. Clone this repository:
   ```bash
   git clone https://github.com/fernandogator/mekasa.git
   cd mekasa/design
   ```

2. Open any page in your browser:
   ```bash
   open pages/dashboard.html
   # or
   python -m http.server 8000
   # then visit http://localhost:8000/pages/dashboard.html
   ```

3. Click navigation to preview view transitions (modern browsers only: Chrome 111+, Safari 17.1+)

### View on GitHub Pages

Once deployed (see Deployment section below), view live at:
```
https://fernandogator.github.io/mekasa/design/pages/dashboard.html
```

---

## 🎨 Design Highlights

### Color Palette (Light Mode)

| Token | Color | Usage |
|-------|-------|-------|
| Brand | `#171e19` | Charcoal text, nav bar, dark surfaces |
| Brand Muted | `#b7c6c2` | Sage borders, secondary text |
| Surface | `#eeebe3` | Warm off-white page background |
| Surface Elevated | `#ffffff` | Card fills, input backgrounds |
| Accent | `#ca0013` | Primary CTAs, FAB, alerts |
| Success | `#2f6b4f` | Positive states, confirmations |
| Warning | `#c45c12` | Pending approvals, low stock |

**Full tokens** in `DESIGN_SYSTEM.md`

### Typography

- **Font**: Nunito (Google Fonts, all weights)
- **Scale**: 10px (labels) → 32px (hero)
- **Hierarchy**: 900 (hero) → 800 (subheads) → 600 (body) → 400 (light text)

### Spacing

All spacing follows an 8px scale: `4 / 8 / 12 / 16 / 24 / 32 / 48px`

### Components

- **Bottom Pill Nav**: 64px height, 5 destinations + center FAB
- **Primary CTA**: 56px min height, red (#ca0013), 24px radius
- **Cards**: 40px radius, white background, subtle shadow
- **List Items**: 56–72px height, 24px radius, sage hover state
- **FAB**: 56px circle, red accent, −32px offset above nav

**Full component specs** in `DESIGN_SYSTEM.md`

---

## 🔗 Navigation Flow

### Onboarding
```
Welcome
  ↓
Household Setup (Step 2/6)
  ↓
Store Selection (Step 4/6)
  ↓
Inventory Scan
  ↓
Invite Members
  ↓
Dashboard (Logged In)
```

### Logged-in Shell (Bottom Tab Navigation)

```
┌────────────────────────────────────┐
│  🏠 Home  📋 List  ➕ Add  📊 Spend  👥 People
│                                    
│  [Main Content - Scrollable]       
│                                    
└────────────────────────────────────┘
```

- **Home**: Dashboard with quick stats & activity
- **List**: Shared shopping list with approvals
- **Add**: Multi-method input (barcode, receipt, voice, manual, trash)
- **Spend**: Category breakdown & budget tracking
- **People**: Family roster & member management
- **FAB (Center)**: Opens Add Items hub

### Focused Mode

**Trash Station** modal (no global nav):
```
Add Items
  ↓
Trash Station (modal, no nav bar)
  ↓
Done → Back to Add Items
```

---

## 💾 File Structure

```
mekasa/design/
├── README.md                         # This file
├── DESIGN_SYSTEM.md                  # Design tokens & component specs
├── IMPLEMENTATION.md                 # Developer guides (Web/iOS/Android)
├── pages/
│   ├── dashboard.html                # Home hub
│   ├── store-selection.html          # Onboarding step 4
│   ├── shopping-list.html            # Shared list
│   ├── add-items.html                # Add items hub
│   ├── trash-station.html            # Focused trash mode
│   ├── onboarding-household.html     # Onboarding step 2
│   ├── spending-report.html          # Analytics
│   └── family-members.html           # Roster
├── css/
│   └── design-tokens.css             # CSS variables (optional, included in each HTML)
└── assets/
    └── images/
        ├── home-exterior-hero.png    # Dashboard hero (150px height)
        ├── home-interior.png         # Reference interior photo
        └── home-exterior-thumb.png   # Thumbnail variant
```

---

## 🛠️ Tech Stack

- **HTML5**: Semantic structure, no build required
- **Tailwind CSS**: Utility-first via PlayCDN (no npm install)
- **Iconify**: Icon system (Lucide icons)
- **View Transition API**: Native browser API for smooth transitions
- **Google Fonts**: Nunito font (OFL license)

### Browser Support

| Feature | Support |
|---------|---------|
| View Transitions | Chrome 111+, Safari 17.1+, Edge 111+ |
| CSS Flexible Box | All modern browsers |
| HTML5 Semantics | All modern browsers |
| Mobile | iOS 12+, Android 6+ |

**Fallback**: If View Transition API isn't supported, pages still load perfectly with no animations.

---

## 🎯 Implementation Paths

### Web Developers

This design system is ready to deploy as-is:

1. **Copy HTML files** to your web server
2. **Update image URLs** if hosting images elsewhere
3. **Customize icon library** (currently using Iconify CDN)
4. **Add your own styling** while keeping design tokens consistent

**Full guide**: `IMPLEMENTATION.md` → "For Web Developers"

### iOS Developers

Use this design as your source of truth for SwiftUI:

1. Map color tokens to SwiftUI `Color` extensions
2. Use spacing scale for layout padding/margins
3. Implement navigation with `NavigationStack` + `TabView`
4. Reference component patterns for button/card/list styles

**Full guide**: `IMPLEMENTATION.md` → "For Native Developers (iOS/Android)"

### Android Developers

Use this design for Jetpack Compose:

1. Map color tokens to Compose `Color` objects
2. Use spacing scale with `.dp` modifiers
3. Implement navigation with `Scaffold` + `BottomAppBar`
4. Reference component patterns for Material 3 compliance

**Full guide**: `IMPLEMENTATION.md` → "For Native Developers (iOS/Android)"

---

## 📦 Deployment

### GitHub Pages (Recommended)

1. Go to your GitHub repo Settings → Pages
2. Select "Deploy from branch" → `main` branch
3. Select folder: `/design` (or root)
4. Pages will be live at: `https://fernandogator.github.io/mekasa/design/pages/dashboard.html`

### Other Hosting

- **Vercel**: Auto-deploys on push, supports View Transition API
- **Netlify**: Full support for static HTML + Tailwind
- **Firebase Hosting**: Works great for web design systems

### Local Development

```bash
# Python
python -m http.server 8000

# Node (npx)
npx http-server

# Then visit: http://localhost:8000/pages/dashboard.html
```

---

## ✅ Quality Checklist

- [x] All 8 screens fully designed & wired
- [x] View Transition API implemented
- [x] Prefetch links for performance
- [x] Mobile-first responsive (390×844)
- [x] Design tokens extracted
- [x] Semantic HTML structure
- [x] Accessibility basics (ARIA, contrast, labels)
- [x] Production-grade code quality
- [x] Complete documentation

---

## 📋 Product Context

### The Household

**Mekasa** (from "mi casa" — your home) is designed for households using a shared inventory system.

**Primary Users:**
- Household admins who manage the pantry
- Family members who add/remove items
- Mobile-first (phone is the primary device)

**Jobs to be Done:**
1. Know what is in the house without opening every cabinet
2. Shop from a list the household already agrees on
3. Add items the way the moment allows (barcode, receipt, voice, manual)
4. Mark things gone in two taps when throwing them away
5. See where the household money went this month

### Design Voice

- **Warm & Practical**: Household-focused, never cutesy
- **Confident**: Clear actions, no ambiguity
- **Efficient**: Two-tap interactions, smart workflows
- **Consistent**: Recognizable patterns across all screens

---

## 🎓 Learning Resources

- **Design System**: See `DESIGN_SYSTEM.md` for complete tokens & components
- **Implementation**: See `IMPLEMENTATION.md` for web/iOS/Android guides
- **CSS Variables**: All color/spacing defined in `<style>` blocks
- **Icon Library**: Lucide icons via Iconify — https://icon-sets.iconify.design/lucide/
- **Typography**: Nunito from Google Fonts — https://fonts.google.com/specimen/Nunito

---

## 📄 License & Attribution

- **Design**: Mekasa Design System (Proprietary)
- **Font**: Nunito (Google Fonts, OFL License)
- **Icons**: Lucide Icons (MIT License)
- **CSS Framework**: Tailwind CSS (MIT License)

---

## 🚀 Next Steps

### For Design Implementation
1. Review all 8 screens in `pages/` folder
2. Read `DESIGN_SYSTEM.md` for complete token specifications
3. Use `IMPLEMENTATION.md` to guide web/native development

### For Team Collaboration
1. Share this repo with your development team
2. Reference design tokens when building components
3. Keep component patterns consistent across implementations

### For Product Development
1. Use these screens as your app's wireframes
2. Layer business logic on top of UI patterns
3. Maintain token consistency as you expand the design system

---

## 💬 Questions?

Refer to the appropriate guide:
- **Design tokens & components?** → `DESIGN_SYSTEM.md`
- **How to implement?** → `IMPLEMENTATION.md`
- **Navigation flows?** → This README (Navigation Flow section)
- **Tech stack details?** → `IMPLEMENTATION.md` (Quick Start section)

---

**Last Updated**: Current version  
**Status**: ✅ Production Ready  
**Platform**: Mobile-first (iOS/Android compatible)  
**Browser Support**: Chrome 111+, Safari 17.1+, modern evergreen browsers  

🎉 **Ready to build!** Start with Dashboard or explore the full flow in sequential order.

