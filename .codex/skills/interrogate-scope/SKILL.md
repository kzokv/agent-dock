---
name: interrogate-scope
description: Interview the user relentlessly about a plan or implementation scope until reaching shared understanding, resolving each branch of the decision tree. Use when the user wants to stress-test scope independently.
---

# Interrogate Scope

Interview the user relentlessly about every aspect of this plan until reaching shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one.

If a question can be answered by exploring the codebase, explore the codebase instead or read the memory files.

---

## Interrogation Style

For **every question**:

1. **State your take first** — propose a concrete stance with reasoning
2. **List 2–3 alternatives** — each with explicit pros and cons
3. **Ask the user** — invite them to weigh in or challenge your stance

One question at a time. Resolve each branch fully before moving on.

---

## Pre-Wrap-Up: Gap & Contradiction Check

Before producing the wrap-up, run an `ultrathink` pass over all decisions reached during the interview. For each gap or contradiction found:

- Propose the skill's own stance on how to resolve it
- Classify as **critical** or **non-critical**

**Critical gaps** — hard gate: present to the user and wait for resolution before proceeding to wrap-up.

**Non-critical gaps** — list with proposed stance, non-blocking.

---

## Wrap-Up Section

When shared understanding is reached (and all critical gaps are resolved), produce a structured wrap-up:

### Gap Check Results

- **Critical gaps resolved:** [list each with resolution reached]
- **Non-critical gaps (advisory):** [list each with proposed stance]

### Mockup

*Only if UI changes are detected in scope* — keywords: screen, page, component, layout, modal, form; file path signals: `components/`, `pages/`, `views/`, `src/app/`, CSS/Tailwind references.

> "This scope involves UI changes. Would you like a mockup screenshot of the proposed design?"

If yes → delegate to the `frontend-design` skill, passing the design decisions from the interview as context.

### Recommended Next Steps

*Only if new user-facing flows, authentication/authorization changes, form submissions, or API endpoint additions are detected in scope:*

- [ ] Run `/aaa` to add or update E2E tests covering the flows discussed
