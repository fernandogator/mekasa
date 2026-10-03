# Mekasa User Flows (v1.0)

Screen-to-screen navigation for Mekasa v1.0.

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

  InventoryScreen --> ItemDetail[Item Detail]
  ItemDetail --> ImageLightbox[Product Image Lightbox]

  AddItems --> BarcodeScanner[Barcode Scanner]
  AddItems --> ReceiptScanner[Receipt Scanner]
  AddItems --> VoiceInput[Voice Input]
  AddItems --> ManualEntry[Manual Entry]
  AddItems --> TrashStation[Trash Station Mode]

  ShoppingList --> RequestApproval[Approve / Reject Request]

  Settings --> ScanSounds[Scan sounds toggle]
  BarcodeScanner -.->|beep + haptic| ScanFeedback[ScanFeedback]
  TrashStation -.->|beep + haptic / 5s cooldown| ScanFeedback
  ScanSounds -.->|mute| ScanFeedback
```

**Scan feedback:** accepted barcodes play `design/scanner-beep.mp3` plus haptic/vibrate; unknown lookups use a nack tone. Family / Settings → **Scan sounds** (default on) mutes both. Trash station also enforces a 5-second cooldown after each accepted scan.
