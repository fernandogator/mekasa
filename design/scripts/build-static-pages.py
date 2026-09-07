#!/usr/bin/env python3
"""Convert design/mockups/*.jsx into self-contained design/pages/*.html for GitHub Pages."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOCK_DIR = ROOT / "design" / "mockups"
OUT_DIR = ROOT / "design" / "pages"

MAPPING = {
    "dashboard.html": "Dashboard.jsx",
    "onboarding-household.html": "OnboardingHouseholdSetup.jsx",
    "store-selection.html": "OnboardingStoreSelection.jsx",
    "shopping-list.html": "ShoppingList.jsx",
    "add-items.html": "AddItems.jsx",
    "trash-station.html": "TrashStationMode.jsx",
    "spending-report.html": "SpendingReport.jsx",
    "family-members.html": "FamilyMembers.jsx",
}

TITLES = {
    "dashboard.html": "Mekasa — Dashboard",
    "onboarding-household.html": "Mekasa — Household setup",
    "store-selection.html": "Mekasa — Store selection",
    "shopping-list.html": "Mekasa — Shopping list",
    "add-items.html": "Mekasa — Add items",
    "trash-station.html": "Mekasa — Trash station",
    "spending-report.html": "Mekasa — Spending",
    "family-members.html": "Mekasa — Family members",
}

NAV = """
<nav class="fixed bottom-0 left-0 right-0 z-50 px-4 pb-4 pt-2 pointer-events-none">
  <div class="pointer-events-auto mx-auto max-w-md flex gap-2 justify-center flex-wrap text-[11px] font-bold">
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="dashboard.html">Home</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="onboarding-household.html">Onboard</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="store-selection.html">Stores</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="shopping-list.html">List</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="add-items.html">Add</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="trash-station.html">Trash</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="spending-report.html">Spend</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="family-members.html">Family</a>
    <a class="px-3 py-2 rounded-full bg-white/90 border border-[rgba(183,198,194,0.4)]" href="../">Index</a>
  </div>
</nav>
"""

SHELL_HEAD = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <meta name="view-transition" content="same-origin" />
  <title>{title}</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap" rel="stylesheet" />
  <style>
    body {{ margin: 0; background: #eeebe3; }}
    @view-transition {{ navigation: auto; }}
  </style>
</head>
<body>
"""

SHELL_TAIL = """
</body>
</html>
"""


def camel_to_kebab(name: str) -> str:
    return re.sub(r"([A-Z])", lambda m: "-" + m.group(1).lower(), name)


def style_obj_to_attr(match: re.Match[str]) -> str:
    inner = match.group(1)
    parts: list[str] = []
    for kv in re.finditer(r"(\w+)\s*:\s*[\"']([^\"']+)[\"']", inner):
        parts.append(f"{camel_to_kebab(kv.group(1))}: {kv.group(2)}")
    if not parts:
        return ""
    joined = "; ".join(parts)
    return f'style="{joined}"'


def jsx_to_html_fragment(jsx_text: str) -> str:
    style_m = re.search(r"<style>\{\`(.*?)\`\}</style>", jsx_text, re.S)
    style_html = f"<style>{style_m.group(1)}</style>\n" if style_m else ""

    body = jsx_text[style_m.end() :] if style_m else jsx_text
    body = re.sub(r"\{/\*.*?\*/\}", "", body, flags=re.S)
    body = body.replace("className=", "class=")
    body = re.sub(r"style=\{\{(.*?)\}\}", style_obj_to_attr, body, flags=re.S)
    body = body.replace("<>", "").replace("</>", "")
    body = re.sub(r"\);\s*\}\s*$", "", body)
    body = re.sub(r"\s+>", ">", body)
    body = body.replace("strokeWidth=", "stroke-width=")
    body = body.replace("strokeLinecap=", "stroke-linecap=")
    body = body.replace("strokeLinejoin=", "stroke-linejoin=")
    body = body.replace("fillRule=", "fill-rule=")
    body = body.replace("clipRule=", "clip-rule=")
    # Drop empty JSX expression remnants if any remain as `{...}` with only whitespace
    body = re.sub(r"\{\s*\}", "", body)
    return style_html + body


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for page, jsx_name in MAPPING.items():
        jsx = (MOCK_DIR / jsx_name).read_text()
        fragment = jsx_to_html_fragment(jsx)
        html = SHELL_HEAD.format(title=TITLES[page]) + fragment + NAV + SHELL_TAIL
        (OUT_DIR / page).write_text(html)
        print(f"wrote {page} ({len(html)} bytes)")


if __name__ == "__main__":
    main()
