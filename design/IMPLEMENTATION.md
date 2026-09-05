# Mekasa Design System - Implementation Guide

## 🚀 For Web Developers

### Stack
- **HTML5**: Semantic structure
- **Tailwind CSS**: Utility-first styling via PlayCDN
- **Iconify**: Icon library (lucide icons)
- **View Transition API**: Smooth page transitions

### Quick Start

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="view-transition" content="same-origin">
  
  <!-- Tailwind CSS -->
  <script src="https://cdn.tailwindcss.com"></script>
  
  <!-- Iconify -->
  <script src="https://code.iconify.design/iconify-icon/1.0.7/iconify-icon.min.js"></script>
  
  <!-- Nunito Font -->
  <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap" rel="stylesheet">
  
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap');
    
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
    
    body {
      font-family: 'Nunito', sans-serif;
      background-color: var(--color-surface);
      color: var(--color-text);
    }
    
    /* View Transitions */
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
    
    /* Persistent Elements */
    ::view-transition-old(nav), ::view-transition-new(nav),
    ::view-transition-old(fab), ::view-transition-new(fab),
    ::view-transition-old(sage-blob), ::view-transition-new(sage-blob) {
      animation: none;
      mix-blend-mode: normal;
    }
  </style>
</head>
<body>
  <!-- Your page content here -->
</body>
</html>
```

### Common Patterns

#### Primary CTA Button
```html
<a href="/next-page" 
   class="inline-flex items-center justify-center w-full h-[56px] bg-[#ca0013] text-white rounded-[24px] font-extrabold text-[18px] shadow-[0_8px_20px_rgba(202,0,19,0.25)] active:scale-[0.95] transition-transform">
  Continue
</a>
```

#### Card Container
```html
<div class="bg-white rounded-[40px] p-6 shadow-[0_20px_50px_-12px_rgba(0,0,0,0.08)] border border-[rgba(183,198,194,0.3)]">
  <!-- Card content -->
</div>
```

#### List Item
```html
<div class="flex items-center p-4 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
  <div class="w-12 h-12 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0">
    <iconify-icon icon="lucide:icon-name" class="text-xl text-[#171e19]"></iconify-icon>
  </div>
  <div class="flex-1">
    <p class="font-bold text-[16px]">Item Name</p>
    <p class="text-[12px] font-semibold text-[#6d7a76]">Subtitle</p>
  </div>
</div>
```

#### Bottom Navigation Bar
```html
<div class="absolute bottom-8 left-6 right-6 z-40">
  <div class="bg-[#171e19] h-[64px] rounded-full flex items-center justify-between px-6 shadow-xl relative">
    <a href="/home" class="flex flex-col items-center justify-center text-white w-12">
      <iconify-icon icon="lucide:home" class="text-2xl mb-1"></iconify-icon>
    </a>
    <a href="/list" class="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
      <iconify-icon icon="lucide:list-todo" class="text-2xl mb-1"></iconify-icon>
    </a>
    <div class="w-16"></div> <!-- Spacer for FAB -->
    <a href="/spend" class="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
      <iconify-icon icon="lucide:pie-chart" class="text-2xl mb-1"></iconify-icon>
    </a>
    <a href="/people" class="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
      <iconify-icon icon="lucide:users" class="text-2xl mb-1"></iconify-icon>
    </a>
  </div>
  
  <!-- Center FAB -->
  <a href="/add" class="absolute left-1/2 -top-6 -translate-x-1/2 w-[56px] h-[56px] bg-[#ca0013] rounded-full flex items-center justify-center text-white shadow-[0_8px_16px_rgba(202,0,19,0.3)] border-[4px] border-[#eeebe3] active:scale-95 transition-transform">
    <iconify-icon icon="lucide:plus" class="text-2xl"></iconify-icon>
  </a>
</div>
```

#### Hero Section
```html
<div class="relative h-[150px] w-full shrink-0 overflow-hidden rounded-b-[40px]">
  <div class="absolute inset-0 bg-cover" style="background-image: url('image.jpg'); background-position: center 30%;"></div>
  <div class="absolute inset-0 bg-gradient-to-b from-[#171e19]/10 to-[#171e19]/35"></div>
  <div class="relative h-full flex flex-col items-center justify-center px-6 text-center">
    <p class="text-[10px] font-bold uppercase tracking-[0.12em] text-[#b7c6c2] mb-2">Good Morning</p>
    <h1 class="text-[32px] font-black text-white leading-tight">The Rodriguez House</h1>
  </div>
</div>
```

#### Sage Blob Background
```html
<div class="sage-blob"></div>

<style>
.sage-blob {
  position: absolute;
  top: -50px;
  right: -50px;
  width: 300px;
  height: 300px;
  border-radius: 50%;
  background: rgba(183, 198, 194, 0.20);
  filter: blur(40px);
  z-index: 0;
  pointer-events: none;
}
</style>
```

### Browser Support
- **View Transition API**: Chrome 111+, Safari 17.1+
- **Fallback**: Graceful degradation (no animation)
- **Mobile**: iOS 17+, Android 14+

### Performance Tips
1. **Prefetch Navigation Links**:
   ```html
   <link rel="prefetch" href="/pages/next-page.html" as="document">
   ```

2. **Optimize Images**: Use WebP with fallbacks
3. **Minimize CSS**: Tailwind purges unused styles in production
4. **Lazy Load Icons**: Iconify CDN loads on-demand

---

## 🏗️ For Native Developers (iOS/Android)

### Design System Mapping

This mockup translates directly to native implementations:

| Web Component | SwiftUI | Compose |
|---|---|---|
| 56px button | `Button` with custom frame | `ElevatedButton` with 56.dp height |
| Rounded pill nav | `TabView` with custom overlay | `NavigationBar` with custom background |
| Card container | `RoundedRectangle` with shadow | `Card` with elevation |
| List item | `HStack` in `List` | `ListItem` in `Column` |
| Hero image | `AsyncImage` with overlay | `Image` with `ColorFilter` |

### Spacing Scale in Native Code

```swift
// SwiftUI
enum Spacing {
  static let xs = 4.0
  static let sm = 8.0
  static let md = 12.0
  static let base = 16.0
  static let lg = 24.0
  static let xl = 32.0
  static let xxl = 48.0
}

// Jetpack Compose
object Spacing {
  val xs = 4.dp
  val sm = 8.dp
  val md = 12.dp
  val base = 16.dp
  val lg = 24.dp
  val xl = 32.dp
  val xxl = 48.dp
}
```

### Color Implementation

```swift
// SwiftUI
struct MekasakColor {
  static let brand = Color(red: 0.09, green: 0.12, blue: 0.10)
  static let brandMuted = Color(red: 0.72, green: 0.78, blue: 0.76)
  static let surface = Color(red: 0.93, green: 0.92, blue: 0.89)
  static let surfaceElevated = Color.white
  static let accent = Color(red: 0.79, green: 0, blue: 0.08)
  static let success = Color(red: 0.19, green: 0.42, blue: 0.31)
  static let warning = Color(red: 0.77, green: 0.36, blue: 0.07)
}
```

```kotlin
// Jetpack Compose
object MekasakColor {
  val brand = Color(0xFF171e19)
  val brandMuted = Color(0xFFb7c6c2)
  val surface = Color(0xFFeeebe3)
  val surfaceElevated = Color(0xFFffffff)
  val accent = Color(0xFFca0013)
  val success = Color(0xFF2f6b4f)
  val warning = Color(0xFFc45c12)
}
```

### Typography Implementation

```swift
// SwiftUI
.font(.system(size: 32, weight: .black, design: .default))
  .fontDesign(.none)
  .tracking(0) // tight
```

```kotlin
// Jetpack Compose
Text(
  "Mekasa",
  fontSize = 32.sp,
  fontWeight = FontWeight.Black,
  letterSpacing = 0.sp
)
```

### Navigation Architecture

The 8 screens map to this flow:

```
Onboarding:
┌─────────────────────────────┐
│ Welcome                     │
└────────────┬────────────────┘
             │
        ┌────▼────────────────┐
        │ Household Setup (2/6)│
        └────────┬─────────────┘
                 │
        ┌────────▼──────────────┐
        │ Store Selection (4/6) │
        └────────┬──────────────┘
                 │
        ┌────────▼──────────────┐
        │ Initial Inventory Scan│
        └────────┬──────────────┘
                 │
        ┌────────▼──────────────┐
        │ Invite Members        │
        └────────┬──────────────┘
                 │
        ┌────────▼──────────────┐
        │ Dashboard (Logged In) │
        └──────────────────────┘

Logged-in Shell:
┌──────────────────────────────────┐
│ Dashboard   List   Add   Spend   People
│ (Home)                   (FAB)    (Settings)
│                                  
│ Content scrolls above nav         
│                                  
└──────────────────────────────────┘

Focused Modes:
│ Add Items → Trash Station (modal, no nav)
│             ↓
│            Done → Back to Add Items
```

### Key Principles for Native

1. **Semantic Layout**: Use native components (TabView, NavigationStack, etc.)
2. **Token Consistency**: Use design system colors directly in Material 3/HIG implementations
3. **Platform Conventions**: Follow iOS/Android guidelines for navigation and gestures
4. **Light/Dark Parity**: Implement both light and dark color tokens
5. **Accessibility**: All text should be label-accessible, touch targets 48dp+ minimum

---

## 📱 Screen-Specific Guidelines

### Dashboard
- Hero: Full-width, 150px, image-based
- Quick Stats: Negative margin overlap (-60px)
- Needs Approval: Scrollable list container
- Recent Activity: Timeline format
- Bottom Nav: Always visible

### Onboarding Screens
- No bottom nav
- Step indicator: "X / 6" format
- Sticky CTA button at bottom
- Progress bar below CTA
- Back button if applicable

### Trash Station (Focused Mode)
- Completely separate navigation
- Exit button returns to Add Items
- Done button also returns to Add Items
- No persistent nav elements
- Search + filter UI at top

### Approval Workflow
- Item in need of approval: Warning chip
- Approval buttons: Reject (X) + Approve (✓)
- Success state: Green background + checkmark
- Requester avatar: 32px initials badge

---

## 🔧 Troubleshooting

### View Transitions Not Working
- Check browser support (Chrome 111+)
- Verify meta tag: `<meta name="view-transition" content="same-origin">`
- Ensure navigation is between same-origin pages
- Check browser DevTools for animation errors

### Icons Not Showing
- Verify Iconify CDN script is loaded
- Check icon name format: `lucide:icon-name`
- Ensure `iconify-icon` element is used (not `i` tag)

### Layout Breaking on Mobile
- Verify viewport meta tag: `width=device-width, initial-scale=1.0`
- Check all content fits within 390px
- Use max-w constraints for desktop fallback
- Test on actual device (not just browser preview)

### Tailwind Classes Not Applied
- Via PlayCDN: No build step required, all Tailwind classes available
- Verify script is loading: `<script src="https://cdn.tailwindcss.com"></script>`
- Check class spelling and value syntax

---

## 📚 Resources

- **Tailwind CSS**: https://tailwindcss.com/docs
- **Iconify Icons**: https://icon-sets.iconify.design/lucide/
- **Google Fonts Nunito**: https://fonts.google.com/specimen/Nunito
- **View Transition API**: https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API
- **SwiftUI**: https://developer.apple.com/xcode/swiftui/
- **Jetpack Compose**: https://developer.android.com/jetpack/compose

---

**Questions?** Refer to DESIGN_SYSTEM.md for complete token documentation.
