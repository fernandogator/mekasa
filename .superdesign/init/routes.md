# Routes / Screens

Mekasa has no React Router / Next.js routes. Navigation is defined in `design/user-flows.md`
and implemented later in native apps. Design mockup files map to screens as follows:

| Screen | Mockup file | Spec | Notes |
|--------|-------------|------|-------|
| Home Dashboard | `design/mockups/Dashboard.jsx` | UI-001 | Hub after onboarding |
| Onboarding Store Selection | `design/mockups/OnboardingStoreSelection.jsx` | UI-002 | Part of onboarding |
| Shopping List | `design/mockups/ShoppingList.jsx` | UI-003 | From dashboard |
| Add Items | `design/mockups/AddItems.jsx` | UI-004 | Hub for scan/voice/manual/trash |
| Trash Station Mode | `design/mockups/TrashStationMode.jsx` | UI-005 | From Add Items |

## Full onboarding + app flow (from `design/user-flows.md`)

```mermaid
flowchart TD
  Welcome[Welcome / Sign In] --> HouseholdSetup[Household Name + Photo]
  HouseholdSetup --> AddressConfirm[GPS Address Confirmation]
  AddressConfirm --> StoreSelection[Store Selection]
  StoreSelection --> InitialScan[Initial Inventory Scan]
  InitialScan --> InviteMembers[Invite Household Members]
  InviteMembers --> Dashboard[Home Dashboard]

  Dashboard --> InventoryScreen[Inventory Screen]
  Dashboard --> ShoppingList[Shopping List]
  Dashboard --> SpendingReport[Spending Report]
  Dashboard --> AddItems[Add Items]
  Dashboard --> Settings[Settings / Members]

  AddItems --> BarcodeScanner[Barcode Scanner]
  AddItems --> ReceiptScanner[Receipt Scanner]
  AddItems --> VoiceInput[Voice Input]
  AddItems --> ManualEntry[Manual Entry]
  AddItems --> TrashStation[Trash Station Mode]

  ShoppingList --> RequestApproval[Approve / Reject Request]
```

Screens without mockup files yet: Welcome, HouseholdSetup, AddressConfirm, InitialScan,
InviteMembers, InventoryScreen, SpendingReport, Settings, BarcodeScanner, ReceiptScanner,
VoiceInput, ManualEntry, RequestApproval.
