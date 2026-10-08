#!/usr/bin/env bash
# Upload dSYMs to Firebase Crashlytics (NFR-007 AC6).
# Runs as an Xcode build phase; skips quietly unless this is a Release build with the
# real GoogleService-Info.plist bundled (not missing, not the CI stub).
set -euo pipefail

if [[ "${CONFIGURATION:-}" != "Release" ]]; then
  echo "[mekasa] Crashlytics dSYM upload skipped (configuration ${CONFIGURATION:-unknown})"
  exit 0
fi

PLIST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
if [[ ! -f "$PLIST" ]]; then
  echo "[mekasa] Crashlytics dSYM upload skipped (no GoogleService-Info.plist)"
  exit 0
fi
if /usr/libexec/PlistBuddy -c 'Print :MEKASA_CI_STUB' "$PLIST" >/dev/null 2>&1; then
  echo "[mekasa] Crashlytics dSYM upload skipped (CI stub plist)"
  exit 0
fi

RUN="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
if [[ ! -x "$RUN" ]]; then
  echo "[mekasa] Crashlytics dSYM upload skipped (run script not found at $RUN)"
  exit 0
fi

"$RUN"
