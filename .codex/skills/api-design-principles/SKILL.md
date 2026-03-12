---
name: api-design-principles
description: Design or review REST and GraphQL APIs.
---

# API Design Principles

## Purpose
Shape APIs that are understandable, stable, and easy to evolve. Use this skill for API design or review work where the main job is choosing interface contracts, not implementing a specific backend framework.

## Use This Skill When
- Designing a new REST or GraphQL API.
- Reviewing an API spec before implementation.
- Refactoring an existing API for clarity or consistency.
- Establishing API standards, versioning, pagination, or error-shape conventions.

## Do Not Use This Skill When
- The task is implementation detail inside an already approved API contract.
- The work is Node.js, Python, or database architecture rather than interface design.
- The user only wants framework-specific handler code.

## Required Inputs
- API style: REST, GraphQL, or mixed.
- Primary consumers, if known.
- Existing constraints such as auth model, pagination style, versioning policy, or backward-compatibility requirements.
- Any current schema, endpoint list, or product spec that acts as the source of truth.

If the target style is not specified, infer it from the existing system or recommend the least disruptive option.

## Default Behavior
- Prefer resource-oriented REST paths and schema-first GraphQL design.
- Keep naming, pagination, filtering, and error shapes consistent across the surface area.
- Optimize for consumer clarity before internal implementation convenience.
- Treat backward compatibility and versioning as explicit design concerns.
- Reuse existing repo or product conventions unless the task is to redesign them.

## Workflow
1. Inspect the current API surface, product constraints, and consumers.
2. Decide whether the task is net-new design, incremental change, or review.
3. Define or evaluate resources, operations, schemas, error shape, and versioning impact.
4. Check consistency across naming, filtering, pagination, auth boundaries, and deprecation strategy.
5. Produce the API recommendation or spec change with concrete examples only where they reduce ambiguity.
6. Verify that the proposal is internally consistent and note any compatibility risks.

## Tooling
- REST guidance: `references/rest-best-practices.md`.
- GraphQL guidance: `references/graphql-schema-design.md`.
- Review checklist: `assets/api-design-checklist.md`.
- Example scaffold: `assets/rest-api-template.py`.

## Output Contract
Return:
- The recommended API contract or review findings.
- Important interface decisions such as resource shape, schema shape, error handling, and versioning.
- Compatibility or migration risks.
- Verification status, including whether the design was compared against an existing spec or code surface.

## Guardrails
- Do not let internal database shape dictate the public API without reason.
- Do not mix inconsistent pagination, filtering, or error formats across related endpoints.
- Do not add versioning complexity unless there is a concrete compatibility need.
- Keep example payloads small and illustrative rather than exhaustive.

## Fallback
- If requirements are incomplete, propose the narrowest contract that preserves future evolution.
- If the repo has conflicting API conventions, call out the conflict and choose the convention that minimizes breakage.
- If there is no existing spec, provide a concise contract sketch plus the highest-risk open questions.

## References
- `references/rest-best-practices.md`
- `references/graphql-schema-design.md`
- `assets/api-design-checklist.md`
- `assets/rest-api-template.py`
