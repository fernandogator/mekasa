#!/usr/bin/env bash
# Ensure the Google Sign-In reverse-client URL scheme is present in a built Info.plist.
# Usage: ensure_google_url_scheme.sh /path/to/Info.plist
set -euo pipefail

PLIST="${1:-}"
SCHEME="${GOOGLE_REVERSED_CLIENT_ID:-com.googleusercontent.apps.934775015882-tkn8jri65ijtbadhlkpskdo3j2nh0m0t}"
PB=/usr/libexec/PlistBuddy

if [[ -z "$PLIST" || ! -f "$PLIST" ]]; then
  echo "[mekasa] ensure_google_url_scheme: missing plist path"
  exit 0
fi
if [[ ! -x "$PB" ]]; then
  echo "[mekasa] ensure_google_url_scheme: PlistBuddy unavailable"
  exit 0
fi

# Already present?
if "$PB" -c 'Print :CFBundleURLTypes' "$PLIST" 2>/dev/null | grep -q "$SCHEME"; then
  echo "[mekasa] Google URL scheme already in built Info.plist"
  exit 0
fi

"$PB" -c 'Print :CFBundleURLTypes' "$PLIST" >/dev/null 2>&1 \
  || "$PB" -c 'Add :CFBundleURLTypes array' "$PLIST"

idx=0
while true; do
  name="$("$PB" -c "Print :CFBundleURLTypes:${idx}:CFBundleURLName" "$PLIST" 2>/dev/null || true)"
  [[ -z "$name" ]] && break
  if [[ "$name" == "GoogleSignIn" ]]; then
    "$PB" -c "Delete :CFBundleURLTypes:${idx}:CFBundleURLSchemes" "$PLIST" 2>/dev/null || true
    "$PB" -c "Add :CFBundleURLTypes:${idx}:CFBundleURLSchemes array" "$PLIST"
    "$PB" -c "Add :CFBundleURLTypes:${idx}:CFBundleURLSchemes:0 string ${SCHEME}" "$PLIST"
    echo "[mekasa] Updated Google URL scheme in built Info.plist → ${SCHEME}"
    exit 0
  fi
  idx=$((idx + 1))
done

"$PB" -c 'Add :CFBundleURLTypes: dict' "$PLIST"
"$PB" -c "Add :CFBundleURLTypes:${idx}:CFBundleURLName string GoogleSignIn" "$PLIST"
"$PB" -c "Add :CFBundleURLTypes:${idx}:CFBundleURLSchemes array" "$PLIST"
"$PB" -c "Add :CFBundleURLTypes:${idx}:CFBundleURLSchemes:0 string ${SCHEME}" "$PLIST"
echo "[mekasa] Added Google URL scheme to built Info.plist → ${SCHEME}"
