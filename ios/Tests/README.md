# UI testing layers

| Layer | Location | Runner |
|-------|----------|--------|
| 0 Unit (`MekasaTests`) | `MekasaTests/` | `UnitTests.xctestplan` (scheme default) |
| 1 Structural XCUITest | `Tests/UI/Structure/` | `StructuralTests.xctestplan` |
| 2 Snapshots | `Tests/Snapshots/` | `SnapshotTests.xctestplan` |
| 3 Vision (manual) | `Scripts/verify_ui_vision.py` + `Scripts/ui_vision_cases.json` | local + `ANTHROPIC_API_KEY` |

Shared identifiers + fixtures: `Tests/TestSupport/` (compiled into the app target).

**UI-006 inventory swipe (REQ-INV-014–018):** Layer 1 `UI006StructureTests` (list + empty runnable; swipe/Undo XCTSkip stubs), Layer 2 `UI006SnapshotTests` (skips until baselines recorded), Layer 3 cases in `ui_vision_cases.json` (`inventory_swipe_use_one`, `inventory_swipe_remove`, `inventory_undo_toast`).

**Scan sounds (REQ-004 AC8 · REQ-008 AC4–AC5 · REQ-019 AC5 · UI-005 AC5):** Layer 0 `ScanFeedbackTests` + `ScanCooldownTests`; Layer 1 Family toggle in `UI004StructureTests.testFamily_scanSoundsToggleExists`, trash typed-UPC in `UI005StructureTests`. Feedback is forced off under `--uitesting`.

```bash
cd ios && xcodegen generate

# Preferred local simulator: iPhone 17 Pro (Config/PreferredSimulator.env)
./scripts/run_unit_tests.sh

# Unit tests (default plan — SessionExpiry, API models, inventory/shopping session, …)
xcodebuild test -scheme Mekasa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan UnitTests
# or: -only-testing:MekasaTests  (works because UnitTests is the default plan)

xcodebuild test -scheme Mekasa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan StructuralTests
xcodebuild test -scheme Mekasa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -testPlan SnapshotTests

# Layer 3 — list vision stubs, then compare a captured simulator shot to a baseline
python3 Scripts/verify_ui_vision.py --list-cases
python3 Scripts/verify_ui_vision.py --screen UI-006 \
  --spec design/baselines/ios/InventoryList_baseline.png \
  --actual /path/to/simulator.png
```
