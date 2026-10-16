---
name: fixing-accessibility
description: Systematic accessibility (a11y) audit-and-fix loop — automated scan plus manual keyboard and screen-reader passes, triaged by WCAG severity, fixed by category, then re-verified. Use when the user wants an accessibility review, mentions a11y/WCAG/screen-reader/keyboard-nav, or reports something as "not accessible".
---

# Fixing Accessibility

A loop, not a one-shot patch — modeled on `/diagnosing-bugs`: build the check first, then fix against it.

## Phase 1 — Build the check loop

Before fixing anything, assemble a **tight** signal that can go red on real violations:

1. **Automated scan** — axe-core, Lighthouse a11y audit, or `eslint-plugin-jsx-a11y` if already in the project.
2. **Manual keyboard-only pass** — unplug the mouse; tab through the whole flow.
3. **Screen-reader spot check** — at minimum the primary flow, with VoiceOver/NVDA/whatever's available.

If none of these are available, say so explicitly rather than eyeballing markup and guessing.

## Phase 2 — Triage

Bucket findings by WCAG level — **A** and **AA** violations on the critical path first, **AAA** and cosmetic issues after. Fix in that order; don't let a low-severity finding block a blocking one.

## Phase 3 — Fix by category

- **Semantic HTML before ARIA.** No ARIA is better than bad ARIA — reach for the right native element before adding a role.
- **Labels & alt text.** Every input has an associated label; every meaningful image has alt text; decorative images are marked as such (`alt=""`).
- **Focus.** Logical focus order, a visible focus ring, no keyboard traps.
- **Contrast.** 4.5:1 for normal text, 3:1 for large text (per baseline-ui tokens where possible, not one-off colors).
- **Motion.** Respect `prefers-reduced-motion` for anything that moves, flashes, or auto-plays.

## Phase 4 — Re-verify

- [ ] Automated scan re-run — zero new violations (or remaining ones explicitly waived, with a stated reason).
- [ ] Manual keyboard-only pass succeeds end to end.
- [ ] Screen reader announces the fixed element correctly.

## Completion criterion

Automated scan clean or waived-with-reason, keyboard-only pass succeeds, and contrast has been checked — not assumed.
