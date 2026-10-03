# Validation Checklist: add-undo-restore-position

- [x] Has an EARS statement
- [x] Has acceptance criteria
- [x] Has a linked test case name
- [x] REQ-ID assigned (REQ-INV-017)
- [x] Out of scope section present
- [ ] No existing requirement conflicts
  - `docs/spec-v1.0.md` already defines **REQ-INV-017: Undo Soft Delete**
    (AC1 `deleted: false` / `deleted_at` cleared, AC2 original list position).
    Either reclassify this delta as MODIFIED or give it a new REQ-ID.
