# Extractable components

No reusable DraftComponents exist yet — mockups are null stubs.
Candidates to extract AFTER Superdesign generates approved screens:

## MobileAppShell
- Source: pending (to be created with first approved mockups)
- Category: layout
- Description: Shared mobile frame with brand mark + primary nav destinations
- Extractable props: activeItem (string, default: "dashboard"), showAddFab (boolean, default: true)
- Hardcoded: Mekasa wordmark treatment, nav labels, icon set, shell spacing

## PrimaryButton
- Source: pending
- Category: basic
- Description: Primary CTA used across onboarding and dashboard actions
- Extractable props: label (string), disabled (boolean, default: false)
- Hardcoded: radius, padding, accent fill, type scale

## StoreListRow
- Source: pending (OnboardingStoreSelection)
- Category: basic
- Description: Selectable nearby-store row within 15-mile discovery
- Extractable props: selected (boolean), storeName (string), distanceLabel (string)
- Hardcoded: row height, selection affordance, typography

## ShoppingListItem
- Source: pending (ShoppingList)
- Category: basic
- Description: Checklist row with approval affordances
- Extractable props: checked (boolean), title (string), requester (string), needsApproval (boolean)
- Hardcoded: checkbox style, spacing, secondary text style

## AddMethodTile
- Source: pending (AddItems)
- Category: basic
- Description: Entry tile for barcode / receipt / voice / manual / trash-station
- Extractable props: method (enum), title (string), subtitle (string)
- Hardcoded: icon mapping, tile layout
