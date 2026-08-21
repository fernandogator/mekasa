# Page dependency trees

All mockup "pages" currently depend only on themselves (null stubs). No shared layout or UI imports.

## /dashboard (UI-001 Home Dashboard)
Entry: `design/mockups/Dashboard.jsx`
Dependencies:
- (none — stub returns null)

## /onboarding/store-selection (UI-002)
Entry: `design/mockups/OnboardingStoreSelection.jsx`
Dependencies:
- (none — stub returns null)

## /shopping-list (UI-003)
Entry: `design/mockups/ShoppingList.jsx`
Dependencies:
- (none — stub returns null)

## /add-items (UI-004)
Entry: `design/mockups/AddItems.jsx`
Dependencies:
- (none — stub returns null)

## /trash-station (UI-005)
Entry: `design/mockups/TrashStationMode.jsx`
Dependencies:
- (none — stub returns null)

## Shared context for any first design
Also pass as context when generating:
- `design/design-system.md`
- `design/user-flows.md`
- `.superdesign/init/theme.md` (compact summary)
- `.superdesign/init/routes.md`
