# Mekasa × Superdesign Integration

How Mekasa uses [Superdesign](https://superdesign.dev) to generate React/Tailwind
design artifacts under `design/mockups/`, then hand off to native Android/iOS
implementation.

## What Superdesign is for (in this repo)

| Stage | Tool | Output |
|-------|------|--------|
| Design exploration | Superdesign canvas (via skill + CLI) | Approved layouts on canvas |
| Living design artifacts | Commit to git | `design/mockups/*.jsx` |
| Tokens | Sync from Superdesign design system | `design/design-system.md` |
| Native implementation | Cursor agent (after human approve) | Jetpack Compose / SwiftUI |
| Visual verification | Semantic baselines | `design/baselines/{android,ios}/` |

**Hard rules (see `GUARDRAILS.md`):**
- No UI screen without a `UI-XXX` spec entry and a mockup path.
- Do not implement native screens until a human approves the Superdesign draft
  (or explicitly says "skip design and implement").
- Visual verification is semantic/structural, not pixel-exact.

## One-time setup (local Cursor Desktop)

Run these from the `mekasa/` directory (or the Mekasa repo root once extracted):

```bash
# 1) Skill (already installed under mekasa/.agents/skills/superdesign)
npx skills add superdesigndev/superdesign-skill

# 2) Authenticate (opens browser, or use --no-browser in headless)
npx --yes @superdesign/cli@latest login

# 3) Verify
npx --yes @superdesign/cli@latest
# expect: auth: authenticated as team "…"
```

### Cursor command (Desktop)

1. Open **Cursor Settings → Rules and Commands**.
2. Add a command named `superdesign`.
3. Paste the contents of `.cursor/commands/superdesign.md` (in this folder).
4. Invoke with `/superdesign` in chat.

Alternatively, open this chat and say: `use the superdesign skill` — Cursor
loads `mekasa/.agents/skills/superdesign/SKILL.md` when that skill is in scope.

## Mekasa-specific paths

| Artifact | Path |
|----------|------|
| Skill | `.agents/skills/superdesign/` |
| Cursor command | `.cursor/commands/superdesign.md` |
| Session prompt | `docs/superdesign-session-prompt.md` |
| Design tokens | `design/design-system.md` |
| User flows | `design/user-flows.md` |
| Mockups (commit targets) | `design/mockups/{Dashboard,OnboardingStoreSelection,ShoppingList,AddItems,TrashStationMode}.jsx` |
| Spec links | `docs/spec-v1.0.md` → UI-001…UI-005 |
| Traceability | `traceability/matrix.md` |

## Recommended workflow

1. **Auth + skill** — complete setup above on Desktop (Cloud Agents cannot finish
   browser login for you).
2. **Run the session prompt** — paste `docs/superdesign-session-prompt.md` into a
   Cursor chat with `/superdesign` (or "follow the Superdesign skill").
3. **Design system first** — establish Mekasa brand tokens on the canvas; sync
   approved tokens into `design/design-system.md`.
4. **Flow, then screens** — use Superdesign Flow for onboarding → dashboard, then
   branch the five P0 mockups (UI-001…UI-005).
5. **Human approve** on the canvas URL (`canvas:` link from CLI output).
6. **Export / commit** — replace placeholders in `design/mockups/*.jsx` with the
   approved React/Tailwind components; keep file names stable (spec + matrix
   depend on them).
7. **Baselines** — after mockups are approved, capture structural baselines into
   `design/baselines/{android,ios}/` before CI visual-verify.
8. **Native build** — only then implement Compose / SwiftUI against the mockups
   and UI test stubs.

## Cloud Agent limitations

This Cloud Agent environment can install the skill and run the CLI, but
`superdesign login` needs an interactive browser (or you completing a
`--no-browser` device code). Until auth succeeds, generation commands will fail.
Finish login on Cursor Desktop, then re-run the session prompt.

## CLI cheat sheet

Always prefer on-demand:

```bash
npx --yes @superdesign/cli@latest
npx --yes @superdesign/cli@latest create-project --title "Mekasa v1.0"
npx --yes @superdesign/cli@latest <command> --help
```

Do not invent canvas URLs — copy `canvas:` / `preview:` from CLI output.
