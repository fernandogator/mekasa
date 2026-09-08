#!/usr/bin/env python3
"""Layer 3 — AI vision verification (manual pre-release gate, not CI).

Usage:
  export ANTHROPIC_API_KEY=...
  python3 Scripts/verify_ui_vision.py \\
    --screen UI-004 \\
    --spec path/to/mockup.png \\
    --actual path/to/simulator.png
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import sys
from pathlib import Path

SYSTEM_PROMPT = """You are a UI verifier for a mobile app called Mekasa.
You will receive two images: a design spec mockup and
an actual iOS simulator screenshot of the same screen.
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


def _b64_image(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    mime, _ = mimetypes.guess_type(path.name)
    if mime not in {"image/png", "image/jpeg", "image/gif", "image/webp"}:
        mime = "image/png"
    return base64.standard_b64encode(data).decode("ascii"), mime


def main() -> int:
    parser = argparse.ArgumentParser(description="Mekasa Layer-3 UI vision verifier")
    parser.add_argument("--spec", required=True, help="Path to mockup screenshot")
    parser.add_argument("--actual", required=True, help="Path to simulator screenshot")
    parser.add_argument("--screen", required=True, help="Spec entry id, e.g. UI-001")
    args = parser.parse_args()

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
        system=SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": f"Screen id: {args.screen}. Image 1 is the design mockup. Image 2 is the simulator screenshot.",
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
    print(json.dumps(verdict, indent=2))
    return 0 if verdict.get("acceptable") is True else 1


if __name__ == "__main__":
    sys.exit(main())
