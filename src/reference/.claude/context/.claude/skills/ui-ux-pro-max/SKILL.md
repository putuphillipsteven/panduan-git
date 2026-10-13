---
name: ui-ux-pro-max
description: Comprehensive top-to-bottom UI/UX polish pass — visual design, interaction design, responsiveness, and accessibility, evaluated against Nielsen's usability heuristics and the project's baseline. Use when the user wants a full UI/UX audit, asks to "make this look and feel better/professional", or wants a holistic design pass rather than a single fix.
---

# UI/UX Pro Max

The composite pass. Where `/front-review` deliberately keeps its two axes separate, this skill exists specifically to produce **one** prioritized backlog across all of them — it's the one place cross-axis reranking is correct.

## Process

### 1. Baseline check

Run `/baseline-ui` first. Judging anything on top of a broken or undocumented foundation produces noise — fix or flag the foundation before evaluating what's built on it.

### 2. Design check (new/changed screens only)

Apply `/frontend-design`'s checklist — hierarchy, component reuse, states, responsive plan — to anything new or materially changed.

### 3. Heuristic pass

Walk the current UI against Nielsen's 10 usability heuristics. For each, note violations at severity: cosmetic / minor / major / catastrophe.

1. Visibility of system status
2. Match between system and the real world
3. User control and freedom
4. Consistency and standards
5. Error prevention
6. Recognition rather than recall
7. Flexibility and efficiency of use
8. Aesthetic and minimalist design
9. Help users recognize, diagnose, and recover from errors
10. Help and documentation

### 4. Accessibility pass

Hand off to `/fixing-accessibility` for the audit-fix loop rather than re-deriving it here.

### 5. Consistency/refactor pass

Hand off to `/front-refactor` for any duplication or baseline drift found along the way.

### 6. Synthesize

Merge findings from steps 2–5 into **one** ranked punch list, scored by severity × effort, highest-value first. This is the deliverable — not five separate reports.
