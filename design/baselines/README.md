# Baseline Screenshots

Convention for approved visual baselines used by semantic visual verification.

- Baseline screenshots are captured from approved mockup renders on simulators/emulators.
- They represent approved structural layout, not pixel-perfect content.
- Stored in `design/baselines/android/` and `design/baselines/ios/`.
- Named to match screen (e.g., `Dashboard_baseline.png`).
- Regenerated only when a UI requirement is explicitly updated and approved.
- Visual verification compares structure and layout, not text content.

## Visual Verification Approach (semantic, not pixel-exact)

Visual verification in this project is **SEMANTIC**, not pixel-exact.

1. **Structural assertion:** Use the accessibility/semantic tree to verify
   the correct components exist in the expected hierarchy and positions.
   This is insensitive to text content — a product name or price
   changing in test data does not constitute a failure.

2. **Screenshot comparison:** Capture a screenshot and compare structural
   layout against the baseline image. Use a tolerance threshold of **15%**
   for color/content differences. Flag only structural layout divergence.

3. **AI-assisted judgment (optional, for CI):** Feed the captured screenshot
   and the baseline to a vision model with this prompt:

   > Does this screen match the intended design in spirit?
   > The layout, component placement, color scheme, and visual hierarchy
   > should match. Differences in text content or data values are expected
   > and acceptable. Return: PASS, MINOR_DRIFT, or FAIL with a one-sentence
   > reason.

Baselines are empty until approved mockup renders are captured.
