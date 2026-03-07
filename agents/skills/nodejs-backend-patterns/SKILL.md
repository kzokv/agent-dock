---
name: nodejs-backend-patterns
description: Build production-ready Node.js backend services with Express or Fastify, with clear architecture, validation, error handling, and operational defaults.
---

# Node.js Backend Patterns

## Purpose
Guide the design or implementation of maintainable Node.js backend services. Use this skill to shape service structure, request handling, validation, data access, and operational concerns without turning the skill file into an inlined framework handbook.

## Use This Skill When
- Building or refactoring a Node.js API or service.
- Choosing between Express, Fastify, or a similar Node.js server runtime.
- Designing middleware, validation, error handling, auth boundaries, or service layers.
- Establishing backend conventions for a Node.js codebase.

## Do Not Use This Skill When
- The task is frontend-only or not Node.js based.
- The user wants language-agnostic API design rather than Node.js implementation guidance.
- The repo already has a rigid backend framework contract the user does not want changed.

## Required Inputs
- Runtime or framework constraints, if any.
- Service shape: API server, worker, webhook processor, CLI, or mixed.
- Existing repo conventions for validation, logging, testing, and persistence.
- Any non-functional requirements that matter, such as latency, auth, or deployment limits.

If the repo already has a backend pattern, preserve it unless the user is explicitly asking for redesign.

## Default Behavior
- Prefer the simplest architecture that fits the service.
- Keep HTTP concerns, business logic, and persistence concerns separated.
- Validate inputs at the boundary and return structured errors.
- Prefer explicit configuration, structured logging, and predictable shutdown behavior.
- Use Fastify for performance-focused typed services and Express when the repo already standardizes on it or simplicity matters more than framework features.

## Workflow
1. Inspect the existing backend shape, framework, and surrounding conventions.
2. Decide whether the task is new service design, incremental feature work, or refactor guidance.
3. Choose or preserve the framework and propose the smallest useful architectural shape.
4. Define request validation, error handling, auth boundaries, and data-access structure.
5. Implement or describe the change using local conventions for config, logging, and tests.
6. Verify behavior with the smallest relevant checks and call out unresolved operational risks.

## Tooling
- Primary runtimes: Node.js with Express or Fastify.
- Preferred validation: use the repo's existing schema library or typed validation approach.
- Prefer nearby service code, tests, and configuration files as the source of truth for conventions.

## Output Contract
Return:
- The backend design or code change for the requested scope.
- The chosen framework and architectural shape, if that decision matters.
- Validation, error-handling, and operational assumptions.
- Verification status, including the checks run or why they were skipped.

## Guardrails
- Do not introduce a new framework or architectural pattern without a concrete reason.
- Do not mix transport logic and business logic unnecessarily.
- Do not leave input validation, error shape, or shutdown behavior implicit in new services.
- Keep examples and comments concise; prefer local conventions over generic boilerplate.

## Fallback
- If the repo has no established backend structure, use a minimal layered shape that separates routes, services, and persistence concerns.
- If framework choice is unclear and the user did not specify one, preserve the existing stack or default to Express for the least disruptive path.
- If runtime verification is unavailable, state that the design was reviewed statically and note the highest-risk assumptions.

## References
- `references/implementation-checklist.md` for a compact service checklist.
