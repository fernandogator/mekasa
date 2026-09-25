#!/usr/bin/env bash
# Record (or refresh) Layer 2 snapshot baselines on a Mac.
#
#   ./scripts/record_snapshots.sh                 # all snapshot tests
#   ./scripts/record_snapshots.sh UI006SnapshotTests
#   ./scripts/record_snapshots.sh UI006SnapshotTests/testInventoryList_undoToast_iPhone13Pro
#
# Baselines are written to Tests/Snapshots/__Snapshots__/<TestClass>/<test>.png.
# swift-snapshot-testing reports every recorded test as FAILED ("Record mode is on")
# — that is expected. The script re-runs the same tests in verify mode afterwards
# so you leave with a green result and PNGs ready to review + commit.
#
# Record on the same simulator CI verifies against (iPhone 16, iOS 18.x, Xcode 16)
# so rendering matches within the 2% tolerance. Override with
# MEKASA_SNAPSHOT_SIMULATOR="iPhone 16" if resolve_ios_simulator.sh finds nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "${MEKASA_SNAPSHOT_SIMULATOR:-}" ]]; then
  DEST="platform=iOS Simulator,name=${MEKASA_SNAPSHOT_SIMULATOR}"
else
  DEST="$(./scripts/resolve_ios_simulator.sh)"
fi
echo "Destination: ${DEST}"

ONLY=()
for spec in "$@"; do
  ONLY+=("-only-testing:MekasaTests/${spec}")
done

xcodegen generate

echo "== Recording baselines (failures here are expected: record mode) =="
TEST_RUNNER_MEKASA_RECORD_SNAPSHOTS=1 xcodebuild test \
  -scheme Mekasa \
  -destination "${DEST}" \
  -testPlan SnapshotTests \
  -parallel-testing-enabled NO \
  ${ONLY[@]+"${ONLY[@]}"} || true

echo "== Verifying recorded baselines =="
xcodebuild test \
  -scheme Mekasa \
  -destination "${DEST}" \
  -testPlan SnapshotTests \
  -parallel-testing-enabled NO \
  ${ONLY[@]+"${ONLY[@]}"}

echo
echo "Recorded PNGs:"
git -C "$ROOT" status --short -- Tests/Snapshots/__Snapshots__ || true
echo "Review them (open Tests/Snapshots/__Snapshots__), then commit."
