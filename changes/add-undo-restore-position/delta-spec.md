# Delta Spec: add-undo-restore-position

Target spec: `docs/spec-v1.0.md`

## ADDED Requirements

### REQ-INV-017: Undo Restores Original Position
Priority: P0

**EARS:** WHEN the user taps Undo after a swipe-delete action, the system SHALL
restore the deleted inventory item to its original list position within 500ms
and display a confirmation banner.

Acceptance Criteria:
- AC1: The restored item appears at the same index it held before the
  swipe-delete, with neighbouring items in their original order
- AC2: The item is visible in the list no more than 500 ms after Undo is tapped
- AC3: A confirmation banner is shown once the item is restored
- AC4: The item's `deleted` flag is `false` and `deleted_at` is cleared

Linked Test Cases:
- iOS: `InventorySwipeSessionTests.testUndo_restoresOriginalPositionWithin500ms_showsBanner`
- Android: `InventoryScreenUITest.undo_restoresOriginalPositionWithin500ms_showsBanner`
