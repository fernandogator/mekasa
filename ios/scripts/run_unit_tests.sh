#!/usr/bin/env bash
# Run Mekasa UnitTests on the preferred local simulator.
# Override with: MEKASA_IOS_SIMULATOR="iPhone 16" ./scripts/run_unit_tests.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f Config/PreferredSimulator.env ]]; then
  # shellcheck disable=SC1091
  source Config/PreferredSimulator.env
fi

SIM="${MEKASA_IOS_SIMULATOR:-iPhone 17 Pro}"
DEST="platform=iOS Simulator,name=${SIM}"

echo "Destination: ${DEST}"
xcodegen generate
xcodebuild test \
  -scheme Mekasa \
  -destination "${DEST}" \
  -testPlan UnitTests \
  "$@"
