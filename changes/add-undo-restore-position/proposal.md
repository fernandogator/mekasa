# Proposal: Undo restores item position (REQ-INV-017)

## Why

After a swipe-delete (REQ-INV-015/016) the user can tap Undo, but the spec does
not bound how fast the item comes back or tell the user the restore worked. If
the item reappears late, or at the end of the list instead of where it was, the
user loses their place and may think the undo failed. They might then re-add the
item and create a duplicate.

## What Changes

- **REQ-INV-017** — when the user taps Undo after a swipe-delete, the system
  restores the item at its original list position within 500 ms.
- A confirmation banner appears once the item is restored.
- The restore is applied to the list locally first, so the 500 ms budget does
  not depend on the round trip to Cloud Run / Firestore (`deleted: false`,
  `deleted_at` cleared).
- Applies to both clients: iOS (`ios/`) and Android (`android-fable/`).

## Out of Scope

- Changing the 5-second Undo window or the "Item removed" toast (REQ-INV-016).
- Purge behaviour after the Undo window expires (REQ-INV-018).
- Undo for anything other than swipe-delete (e.g. "Use 1", shopping-list edits).
- Multi-level undo / redo history.
- Restoring an item that another household member has since changed or purged.
