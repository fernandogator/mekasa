#!/usr/bin/env bash
# Compile the Mekasa app for the iOS Simulator (no specific device needed) with phone-sized output:
# only errors, a warning count and the final result. The full log goes to
# build/last-build.log. Meant for running remotely (SSH / Claude Code from a phone).
#
#   ./scripts/build.sh           # build
#   ./scripts/build.sh --pull    # git pull --ff-only first
#   ./scripts/build.sh --clean   # clean build
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PULL=0
ACTION=build
for arg in "$@"; do
  case "$arg" in
    --pull) PULL=1 ;;
    --clean) ACTION="clean build" ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [[ $PULL -eq 1 ]]; then
  git pull --ff-only
fi
echo "$(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"

LOG="build/last-build.log"
mkdir -p build

xcodegen generate --quiet

START=$(date +%s)
set +e
# shellcheck disable=SC2086
xcodebuild $ACTION \
  -scheme Mekasa \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  >"$LOG" 2>&1
STATUS=$?
set -e
ELAPSED=$(( $(date +%s) - START ))

# De-duplicate (xcodebuild repeats diagnostics) and strip the repo prefix to keep lines short.
grep -E ': (error|fatal error):' "$LOG" | sed "s|${ROOT}/||" | sort -u | head -30 || true
WARNINGS=$( (grep -E ': warning:' "$LOG" || true) | sort -u | wc -l | tr -d ' ')

if [[ $STATUS -eq 0 ]]; then
  echo "✅ BUILD SUCCEEDED in ${ELAPSED}s (${WARNINGS} warnings)"
else
  # Errors outside compiler diagnostics (signing, SPM resolution) — show the tail.
  if ! grep -qE ': (error|fatal error):' "$LOG"; then
    tail -20 "$LOG"
  fi
  echo "❌ BUILD FAILED in ${ELAPSED}s (${WARNINGS} warnings) — full log: ios/${LOG}"
fi
exit $STATUS
