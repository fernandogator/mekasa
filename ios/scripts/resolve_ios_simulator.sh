#!/usr/bin/env bash
# Print a single unambiguous xcodebuild -destination for an available iPhone 16.
# Prefer iOS 18.x (Xcode 16 SDK) over newer beta runtimes when both exist.
set -euo pipefail

python3 - <<'PY'
import re
import subprocess
import sys

out = subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available"], text=True
)
current_os = None
preferred = []
fallback = []
for line in out.splitlines():
    m = re.match(r"-- iOS ([0-9.]+) --", line.strip())
    if m:
        current_os = m.group(1)
        continue
    m = re.search(r"iPhone 16 \(([A-F0-9-]{36})\)", line)
    if not m or current_os is None:
        continue
    udid, osver = m.group(1), current_os
    entry = (osver, udid)
    if osver.startswith("18."):
        preferred.append(entry)
    else:
        fallback.append(entry)

def os_key(ver: str):
    return [int(p) for p in ver.split(".")]

chosen = sorted(preferred, key=lambda x: os_key(x[0]), reverse=True)
if not chosen:
    chosen = sorted(fallback, key=lambda x: os_key(x[0]), reverse=True)
if not chosen:
    sys.stderr.write(out + "\n")
    raise SystemExit("No iPhone 16 simulator available")

osver, udid = chosen[0]
sys.stderr.write(f"Selected iPhone 16 OS={osver} id={udid}\n")
print(f"platform=iOS Simulator,id={udid}")
PY
