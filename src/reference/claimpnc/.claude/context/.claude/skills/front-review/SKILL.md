---
name: front-review
description: Review frontend/UI changes along two axes — Consistency (does it reuse baseline-ui tokens and components rather than reinventing them?) and UX (does it meet usability, responsive, and accessibility basics?). Use when the user wants a frontend PR or diff reviewed, or asks to review a UI change.
---

# Front Review

Two-axis review of a frontend diff, mirroring `/code-review`'s split — reported side by side, never merged, because a change can pass one axis and fail the other.

## Process

### 1. Pin the diff

Same as `/code-review`: `git diff <fixed-point>...HEAD`, confirm it resolves and is non-empty before spawning anything.

### 2. Axis: Consistency

Check every component/style touched against `/baseline-ui`:

- New colors, spacing, or type values not pulled from tokens.
- A component pattern that duplicates an existing baseline primitive instead of reusing it.
- Inconsistent naming against the existing component set.
- A newly-used platform feature without a stated Baseline support status.

### 3. Axis: UX

Walk the diff against this checklist:

- [ ] Loading / error / empty states present for anything async.
- [ ] Keyboard-operable, with a visible focus state.
- [ ] Responsive at the project's common breakpoints.
- [ ] Contrast plausible (flag anything that looks under 4.5:1, don't just assume).
- [ ] Touch targets sized reasonably (~44px) on touch surfaces.

This axis **flags**, it doesn't deep-fix — hand accessibility findings to `/fixing-accessibility` and consistency/duplication findings to `/front-refactor` rather than patching inline.

### 4. Spawn in parallel

Send both axes to parallel sub-agents (as in `/code-review`) so neither pollutes the other's context, each reporting under 400 words.

### 5. Aggregate

Present `## Consistency` and `## UX` side by side, verbatim or lightly cleaned. Don't rerank across axes — that reranking is `/ui-ux-pro-max`'s job, not this skill's.
