# Snapshot baselines

Committed baselines live under `__Snapshots__/` next to each `*SnapshotTests.swift` file
(swift-snapshot-testing default layout).

## Capture / refresh (Mac only)

```bash
cd ios
xcodegen generate
# Temporarily set isRecording = true in a single test, run it, then set false again.
# Or: xcodebuild test -scheme Mekasa -testPlan SnapshotTests ...
```

Never commit `record: true` / `isRecording = true`.
Tolerance / precision is 0.98 (2%) in assertSnapshot calls.
