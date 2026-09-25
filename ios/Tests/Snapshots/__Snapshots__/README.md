# Snapshot baselines

Committed baselines live under `__Snapshots__/<TestClass>/<testName>.png` next to each
`*SnapshotTests.swift` file (swift-snapshot-testing default layout). Until a baseline
exists the test skips, so CI stays green while the set is still being recorded.

## Capture / refresh (Mac only)

```bash
cd ios
./scripts/record_snapshots.sh                     # everything
./scripts/record_snapshots.sh UI006SnapshotTests  # one class
./scripts/record_snapshots.sh UI006SnapshotTests/testInventoryList_undoToast_iPhone13Pro
```

The script runs the SnapshotTests plan with `MEKASA_RECORD_SNAPSHOTS=1` (record mode —
every recorded test is reported as failed, which is expected), then re-runs it in verify
mode, then lists the new PNGs. Review them, then commit.

Record on the simulator CI verifies against (iPhone 16 / iOS 18.x / Xcode 16, picked by
`scripts/resolve_ios_simulator.sh`); a different runtime can drift past the 2% tolerance.

Never commit code with record mode hard-coded on. Tolerance / precision is 0.98 (2%).
