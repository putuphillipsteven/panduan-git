# Project TEKNO Body Repair - Agent Instructions

## Available Skills (All Installed)

### Core Engineering Skills
- /setup-matt-pocock-skills - Configure this repo for engineering skills
- /grilling - Relentless interview to stress-test plans/decisions, one question at a time
- /grill-me - Quick start a grilling session
- /grill-with-docs - Grilling session backed by documentation
- /domain-modeling - Build/sharpen domain model, glossary, ADRs, CONTEXT.md
- /research - Investigate questions against primary sources
- /to-spec - Turn conversation into spec/PRD
- /to-tickets - Break spec into actionable tickets
- /triage - Triage issues with label vocabulary
- /wayfinder - Plan large work as decision tickets
- /implement - Implement a ticket
- /tdd - Test-driven development
- /prototype - Build rough artifact to react to
- /code-review - Review code changes
- /codebase-design - Deep module design principles
- /improve-codebase-architecture - Improve codebase architecture
- /diagnosing-bugs - Systematic bug diagnosis
- /resolving-merge-conflicts - Resolve merge conflicts
- /handoff - Hand off context between sessions
- /ask-matt - Ask Matt Pocock a question
- /teach - Personalized learning
- /find-skills - Discover relevant skills
- /writing-great-skills - Guide for authoring skills

## Project Context

This is a legacy ASP.NET Web Forms (VB.NET) application for body repair shop management (TEKNO Body Repair). The codebase contains:
- .aspx pages with .aspx.vb code-behind files
- Classic ASP .asp pages (legacy)
- Crystal Reports .rpt files
- No modern build system - direct IIS deployment

## Working Principles

- Explore the codebase thoroughly before making claims
- Use /grilling for requirement elicitation and BRD development
- Use /domain-modeling to build the domain glossary
- Use /to-spec to produce formal specs/BRD
- Use /research for investigating existing functionality
- Facts are looked up; decisions belong to the human

## Agent skills

### Issue tracker

Local markdown under `.scratch/<feature-slug>/` — this repo is Mercurial-based with no external tracker wired up. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), used as-is. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
