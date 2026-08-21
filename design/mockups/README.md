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

| File | Spec | Canvas preview |
|------|------|----------------|
| `Dashboard.jsx` | UI-001 | https://p.superdesign.dev/draft/69d15b18-61b1-45ec-92f6-5f89e59a7ee9 |
| `OnboardingStoreSelection.jsx` | UI-002 | https://p.superdesign.dev/draft/afdeeaad-6431-495e-9674-5231b3993dca |
| `ShoppingList.jsx` | UI-003 | https://p.superdesign.dev/draft/b234a6ab-1837-48a9-84d1-a2ed870ae61c |
| `AddItems.jsx` | UI-004 | https://p.superdesign.dev/draft/eee7d5dd-5cc6-4c4a-8c91-2717e1973660 |
| `TrashStationMode.jsx` | UI-005 | https://p.superdesign.dev/draft/a8a15416-6c7a-4f32-b1b0-c233c57f0cd1 |
| `OnboardingHouseholdSetup.jsx` | — | https://p.superdesign.dev/draft/cf8659c3-ef2d-4f9c-b097-f7774783a2f3 |
| `SpendingReport.jsx` | — | https://p.superdesign.dev/draft/a45a3eab-e709-415e-8a81-19f333a3c88b |
| `FamilyMembers.jsx` | — | https://p.superdesign.dev/draft/248f70a0-c51e-430f-9a3c-ed7d25f68606 |

Project canvas: https://superdesign.dev/teams/97f327bd-7027-43ef-8186-e2aafd35b597/projects/747347d9-34d0-43dd-a1c8-e170f34a7b5c

These mockups are design artifacts for native Compose / SwiftUI implementation. They are not a shipped web app.
