# MEKASA Guardrails

1. Spec, code, and tests must always match the same version.
2. AI drafts, humans decide — no autonomous merges ever.
3. No secrets in code, config, markdown, or prompts, ever.
4. Requirement IDs are permanent — mark deprecated, never delete or renumber.
5. No P0 requirement ships without passing test coverage.
6. No application code written without a versioned spec entry first.
7. Every function must include:
   ```
   # Satisfies: REQ-XXX (requirement title)
   # Acceptance criteria: AC1, AC2, AC3
   ```
8. Every UI requirement must link to its design artifact in `design/mockups/`.
9. No UI screen ships without a passing layout test AND a visual verification pass.
10. Visual verification is semantic/structural, not pixel-exact —
    content differences from test data are expected and acceptable.
