#!/usr/bin/env bash
# Copy design/scanner-beep.mp3 into iOS + Android app resource folders.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/design/scanner-beep.mp3"
if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC — drop your scanner beep there first." >&2
  exit 1
fi
mkdir -p "$ROOT/ios/Mekasa/Sounds" "$ROOT/android/app/src/main/res/raw"
cp "$SRC" "$ROOT/ios/Mekasa/Sounds/scanner-beep.mp3"
# Android resource names cannot contain hyphens.
cp "$SRC" "$ROOT/android/app/src/main/res/raw/scanner_beep.mp3"
echo "Synced scanner beep → ios/Mekasa/Sounds + android res/raw"
