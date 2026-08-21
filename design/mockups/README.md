# Design Mockups

Convention for Superdesign-generated React/Tailwind mockups in this folder.

- Each file in `design/mockups/` is a Superdesign-generated React component.
- File names match the screen name exactly (e.g., `Dashboard.jsx`, `ShoppingList.jsx`).
- Each component uses the Mekasa design tokens defined in `design/design-system.md`.
- These files are living design artifacts committed to version control.
- When a screen's UI requirement is updated, the corresponding mockup must also be updated.
- UI requirements in `docs/spec-v1.0.md` reference mockup files using this format:
  `Design Artifact: design/mockups/ScreenName.jsx`

## Current screens

| File | Spec |
|------|------|
| `Dashboard.jsx` | UI-001 |
| `OnboardingStoreSelection.jsx` | UI-002 |
| `ShoppingList.jsx` | UI-003 |
| `AddItems.jsx` | UI-004 |
| `TrashStationMode.jsx` | UI-005 |

Placeholder stubs exist until the Superdesign session generates real mockups.
Do not treat stubs as approved design.
