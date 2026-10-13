---
name: frontend-design
description: Design a frontend feature, page, or screen before implementation — information hierarchy, component choice against the baseline, UI states, and responsive behavior. Use when the user wants to design a new UI, plan a page/screen layout, or asks how a feature should look and behave before code is written.
---

# Frontend Design

A plan-before-code discipline for UI work. The output is a written plan the user has seen — not a component tree in your head.

## 1. Gather constraints

Check for `CONTEXT.md`, existing design docs, and the project's `/baseline-ui` tokens/components before proposing anything new. Note target devices/breakpoints and any brand constraints already in the repo.

## 2. Information hierarchy

Before layout, decide what's primary, secondary, and tertiary on the screen. Content drives hierarchy — chrome (nav, decoration) is placed around it, not the reverse.

## 3. Component plan

Map each piece of the screen to an existing baseline-ui component first. Only propose a new component when nothing in the baseline set fits — mark it explicitly as a **candidate for baseline-ui** promotion once it ships and gets reused (see `/baseline-ui`).

## 4. States

Plan every state up front, not after the happy path is built:

- [ ] Empty
- [ ] Loading
- [ ] Error
- [ ] Success
- [ ] Edge content (overflow, very long/short text, zero/huge counts)

A design that only covers the happy path isn't done.

## 5. Responsive plan

State the behavior **at each breakpoint** — stack, reflow, hide, or resize — not just "make it responsive". A layout with no stated behavior at a breakpoint is an unplanned one.

## 6. Validate before handoff

Sanity-check contrast and semantic structure against `/fixing-accessibility`'s categories before implementation starts — cheaper to catch here than after code exists.

## Completion criterion

A layout + states + breakpoint plan, shown to the user, before implementation begins.
