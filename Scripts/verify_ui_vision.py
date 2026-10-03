#!/usr/bin/env python3
"""Layer 3 — AI vision verification (manual pre-release gate, not CI).

Usage:
  export ANTHROPIC_API_KEY=...
  python3 Scripts/verify_ui_vision.py \\
    --screen UI-004 \\
    --platform ios \\
    --spec path/to/mockup.png \\
    --actual path/to/simulator.png

  # Android: compare a device/emulator capture against the recorded Roborazzi baseline
  python3 Scripts/verify_ui_vision.py --screen UI-004 --platform android \\
    --spec design/baselines/android/Dashboard_baseline.png --actual path/to/emulator.png

  # Case registry (optionally filtered by platform)
  python3 Scripts/verify_ui_vision.py --list-cases [--platform android|ios]
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import sys
from pathlib import Path

PLATFORMS = ("ios", "android")

SYSTEM_PROMPT = """You are a UI verifier for a mobile app called Mekasa.
You will receive two images: a design spec mockup and
an actual PLATFORM_SCREENSHOT screenshot of the same screen.
Your job is to compare them structurally — not
pixel-exactly. Ignore differences in text content,
item names, quantities, prices, and dates. Judge only:
layout structure, component hierarchy, spacing
proportions, visual weight distribution, and whether
the correct interactive elements are present.
Return ONLY a JSON object with no preamble:
{
  "screen": "<screen id>",
  "result": "PASS" | "MINOR_DRIFT" | "FAIL",
  "issues": ["list each structural problem found"],
  "acceptable": true | false,
  "notes": "one sentence summary"
}"""

CASES_PATH = Path(__file__).resolve().parent / "ui_vision_cases.json"


def _load_cases(platform: str | None = None) -> list[dict]:
    if not CASES_PATH.is_file():
        return []
    try:
        payload = json.loads(CASES_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    cases = payload.get("cases")
    if not isinstance(cases, list):
        return []
    if platform is None:
        return cases
    # Entries without a platform predate the field and were always iOS.
    return [case for case in cases if case.get("platform", "ios") == platform]


def _platform_label(platform: str) -> str:
    return "Android emulator/device" if platform == "android" else "iOS simulator"


def _b64_image(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    mime, _ = mimetypes.guess_type(path.name)
    if mime not in {"image/png", "image/jpeg", "image/gif", "image/webp"}:
        mime = "image/png"
    return base64.standard_b64encode(data).decode("ascii"), mime


def main() -> int:
    parser = argparse.ArgumentParser(description="Mekasa Layer-3 UI vision verifier")
    parser.add_argument("--spec", help="Path to mockup screenshot")
    parser.add_argument("--actual", help="Path to simulator screenshot")
    parser.add_argument("--screen", help="Spec entry id, e.g. UI-001 / UI-006")
    parser.add_argument(
        "--platform",
        choices=PLATFORMS,
        help="Which platform the --actual capture comes from; also filters --list-cases (default: ios for verification, all for listing)",
    )
    parser.add_argument(
        "--list-cases",
        action="store_true",
        help="Print stub/case registry from Scripts/ui_vision_cases.json and exit",
    )
    args = parser.parse_args()

    if args.list_cases:
        print(json.dumps({"cases": _load_cases(args.platform)}, indent=2))
        return 0

    platform = args.platform or "ios"

    if not args.spec or not args.actual or not args.screen:
        parser.error("--spec, --actual, and --screen are required unless --list-cases")

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print(
            json.dumps(
                {
                    "screen": args.screen,
                    "result": "FAIL",
                    "issues": ["ANTHROPIC_API_KEY is not set"],
                    "acceptable": False,
                    "notes": "Set ANTHROPIC_API_KEY before running vision verification.",
                }
            )
        )
        return 1

    try:
        import anthropic
    except ImportError:
        print(
            json.dumps(
                {
                    "screen": args.screen,
                    "result": "FAIL",
                    "issues": ["anthropic package not installed"],
                    "acceptable": False,
                    "notes": "Run: pip install anthropic",
                }
            )
        )
        return 1

    spec_path = Path(args.spec)
    actual_path = Path(args.actual)
    if not spec_path.is_file() or not actual_path.is_file():
        print(
            json.dumps(
                {
                    "screen": args.screen,
                    "result": "FAIL",
                    "issues": ["spec or actual image path missing"],
                    "acceptable": False,
                    "notes": "Provide existing --spec and --actual image files.",
                }
            )
        )
        return 1

    spec_b64, spec_mime = _b64_image(spec_path)
    actual_b64, actual_mime = _b64_image(actual_path)

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=SYSTEM_PROMPT.replace("PLATFORM_SCREENSHOT", _platform_label(platform)),
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            f"Screen id: {args.screen}. Platform: {platform}. "
                            "Image 1 is the design mockup. Image 2 is the actual screenshot."
                        ),
                    },
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": spec_mime,
                            "data": spec_b64,
                        },
                    },
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": actual_mime,
                            "data": actual_b64,
                        },
                    },
                ],
            }
        ],
    )

    raw = "".join(block.text for block in message.content if getattr(block, "type", None) == "text")
    raw = raw.strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.startswith("json"):
            raw = raw[4:].strip()

    try:
        verdict = json.loads(raw)
    except json.JSONDecodeError:
        verdict = {
            "screen": args.screen,
            "result": "FAIL",
            "issues": ["Model returned non-JSON output"],
            "acceptable": False,
            "notes": raw[:200],
        }

    verdict.setdefault("screen", args.screen)
    verdict.setdefault("platform", platform)
    print(json.dumps(verdict, indent=2))
    return 0 if verdict.get("acceptable") is True else 1


if __name__ == "__main__":
    sys.exit(main())
