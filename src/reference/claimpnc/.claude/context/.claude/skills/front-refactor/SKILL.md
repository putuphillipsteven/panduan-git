---
name: front-refactor
description: Refactor frontend code for reuse and simplicity — collapse duplicate components/styles into the baseline-ui set, flatten prop drilling, extract shared UI patterns. Use when the user wants frontend code simplified, a UI component refactored, or duplicated markup/styles consolidated.
---

# Front Refactor

A frontend-specific smell baseline, extending `/codebase-design` vocabulary with UI-specific shapes. Each smell is a judgement call, not a hard rule — skip anything the project's own conventions already endorse.

- **Style Duplication** — the same visual pattern implemented with ad-hoc styles in more than one place instead of a `/baseline-ui` component or token. → replace both sites with the shared one; if neither exists yet, that's the signal to create it.
- **Prop Drilling** — data threaded untouched through 3+ component layers just to reach a leaf. → context, composition, or colocate the data closer to where it's used.
- **God Component** — one component owning layout, data-fetching, and business logic together. → split by responsibility; layout stays, logic moves out.
- **Inline Magic Values** — a hardcoded color, `px` value, or z-index instead of a baseline-ui token. → pull from tokens; if the value doesn't exist as a token, that's a `/baseline-ui` gap, not license to inline it.
- **Conditional Soup** — deeply nested ternaries or `&&` chains controlling what renders. → extract to a named variable, early return, or a small state-to-view map.
- **Dead Style** — a CSS class/selector no longer referenced anywhere. → delete it; don't let it linger "in case."

## Process

1. Identify the target (diff, component, or directory).
2. Match against the smells above — cite the smell name and the specific hunk.
3. For any Style Duplication finding, name the baseline-ui equivalent to converge on **before** touching code — don't invent a second bespoke fix.
4. Apply the refactor.
5. Verify the UI is visually and functionally unchanged after the refactor (use the `/run` skill to view it live if available) — a refactor that changes behavior is a bug, not a refactor.
