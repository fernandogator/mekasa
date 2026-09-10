#!/usr/bin/env bash
# Bump the marketing version in Config/MarketingVersion.xcconfig.
# Usage: ./scripts/bump_marketing_version.sh [major|minor|patch]
# Default: patch (1.0.0 → 1.0.1)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${ROOT}/Config/MarketingVersion.xcconfig"
part="${1:-patch}"

current="$(
  awk -F'=' '/^MARKETING_VERSION/ {
    gsub(/[[:space:]]/, "", $2); print $2; exit
  }' "${FILE}"
)"
current="${current:-1.0.0}"

IFS='.' read -r major minor patch <<<"${current}"
major="${major:-1}"
minor="${minor:-0}"
patch="${patch:-0}"

case "${part}" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  *)
    echo "usage: $0 [major|minor|patch]" >&2
    exit 1
    ;;
esac

next="${major}.${minor}.${patch}"
cat > "${FILE}" <<EOF
// User-facing marketing version (CFBundleShortVersionString).
// Bump deliberately for releases: 1.0.0 → 1.0.1 / 1.1.0 / 2.0.0
MARKETING_VERSION = ${next}
EOF

echo "Marketing version: ${current} → ${next}"
# Refresh build number alongside marketing bumps.
"${ROOT}/scripts/ensure_unique_build_number.sh"
