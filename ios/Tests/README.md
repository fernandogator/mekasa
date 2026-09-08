# UI testing layers

| Layer | Location | Runner |
|-------|----------|--------|
| 1 Structural XCUITest | `Tests/UI/Structure/` | `StructuralTests.xctestplan` |
| 2 Snapshots | `Tests/Snapshots/` | `SnapshotTests.xctestplan` |
| 3 Vision (manual) | `Scripts/verify_ui_vision.py` | local + `ANTHROPIC_API_KEY` |

Shared identifiers + fixtures: `Tests/TestSupport/` (compiled into the app target).

```bash
cd ios && xcodegen generate
xcodebuild test -scheme Mekasa -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan StructuralTests
xcodebuild test -scheme Mekasa -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan SnapshotTests
```
