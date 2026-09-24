#!/usr/bin/env bash
# Fail the build if Mekasa/Info.plist is missing the Google Sign-In URL scheme.
# Also re-injects the scheme so a stale/local edit cannot ship a broken app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="${ROOT}/Mekasa/Info.plist"
DEFAULT_SCHEME="com.googleusercontent.apps.934775015882-tkn8jri65ijtbadhlkpskdo3j2nh0m0t"
SCHEME="${GOOGLE_REVERSED_CLIENT_ID:-$DEFAULT_SCHEME}"

if [[ -z "${SCHEME}" || "${SCHEME}" == *'$('* ]]; then
  SCHEME="$DEFAULT_SCHEME"
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "error: missing ${INFO_PLIST}"
  exit 1
fi

# Always re-sync from GoogleService-Info (or default) first.
/bin/bash "${ROOT}/scripts/sync_google_signin_config.sh"

# Prefer whatever sync wrote; fall back to default.
if [[ -f "${ROOT}/Config/GoogleSignIn.xcconfig" ]]; then
  synced="$(grep -E '^GOOGLE_REVERSED_CLIENT_ID' "${ROOT}/Config/GoogleSignIn.xcconfig" | sed 's/.*= *//' | tr -d '[:space:]' || true)"
  if [[ -n "$synced" && "$synced" != *'$('* ]]; then
    SCHEME="$synced"
  fi
fi

if ! grep -q "$SCHEME" "$INFO_PLIST"; then
  echo "error: ${INFO_PLIST} is missing Google URL scheme:"
  echo "       ${SCHEME}"
  echo "       Add it under CFBundleURLTypes → CFBundleURLSchemes, or re-run:"
  echo "         ios/scripts/sync_google_signin_config.sh"
  exit 1
fi

echo "[mekasa] Verified Google URL scheme in Info.plist → ${SCHEME}"
