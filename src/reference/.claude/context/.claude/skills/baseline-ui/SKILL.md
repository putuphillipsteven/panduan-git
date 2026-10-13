---
name: baseline-ui
description: Maintain the project's baseline UI foundation — design tokens (color, spacing, type), the canonical reusable component set, and Web Platform Baseline (widely-available browser feature) compatibility. Use when establishing or auditing a design system, deciding whether a new component belongs in the shared set, or checking whether a CSS/JS feature is safe to ship without a fallback.
---

# Baseline UI

The **baseline** is the one shared foundation every other frontend skill checks against: a token source, a canonical component set, and a browser-support floor. `/front-review`, `/front-refactor`, and `/ui-ux-pro-max` all point here rather than re-deriving it.

## 1. Design tokens

Locate the token source: theme file, CSS custom properties, Tailwind config, or similar. If none exists, that absence **is** the finding — say so explicitly rather than inventing tokens on the spot.

Once found, tokens are the **single source of truth** for color, spacing, type scale, radii, and shadow — a hex value or raw `px` typed directly in a component is a baseline violation, not a style choice.

## 2. Canonical component set

One implementation per primitive (Button, Input, Modal, Select, ...). A second implementation of an existing primitive is **duplication**, not a new component — point it back at the canonical one.

Before promoting something new into the baseline set, confirm at least one:

- [ ] It's already reused in 2+ places.
- [ ] The design system doc explicitly calls for it.

Otherwise it stays local to its feature until reuse actually shows up — premature promotion is **speculative generality**.

## 3. Browser/platform baseline

Before shipping a new CSS or JS web-platform feature, check its [Baseline status](https://web.dev/baseline) (widely available / newly available / limited availability) — via the project's `.browserslistrc`/`browserslist` field if one exists, or caniuse data otherwise.

- **Widely available** — safe to use directly.
- **Newly available / limited** — needs a documented fallback, a polyfill, or an explicit call that the project's supported-browser matrix tolerates it.

A project's own browserslist/support matrix always overrides generic Baseline guidance — the project's stated floor wins over the general web's.

## Completion criterion

Token source identified (or its absence flagged), and any newly-introduced platform feature has a stated support status — not silently assumed safe.
