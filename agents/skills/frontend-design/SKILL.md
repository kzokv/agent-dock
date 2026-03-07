---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Generates creative, polished code and UI design that avoids generic AI aesthetics.
license: Complete terms in LICENSE.txt
---

# Frontend Design

## Purpose
Design and implement distinctive frontend interfaces that are both usable and visually intentional. The deliverable should be working code aligned with the existing product context or, when no system exists, a clear and specific visual direction.

## Use This Skill When
- The user wants a web page, component, dashboard, landing page, or interface polish.
- The task requires both implementation and design judgment.
- Visual differentiation matters, not just functional correctness.

## Do Not Use This Skill When
- The task is backend-only or non-visual.
- The user only wants a bug fix with no design change.
- The repo already has a strict design system the user does not want changed.

## Required Inputs
- Product or page goal.
- Framework or stack constraints.
- Existing design-system constraints, if any.
- Responsiveness, accessibility, or performance requirements when known.

If the request is underspecified, infer a clear design direction from the product context and keep changes easy to integrate.

## Default Behavior
- Preserve existing design language when working in an established product.
- When no design system exists, choose a distinctive direction and apply it consistently.
- Prioritize typography, spacing, hierarchy, color, and responsive behavior before adding decorative effects.
- Use motion sparingly and with purpose.
- Keep the implementation production-grade, not a visual mockup.

## Workflow
1. Identify the product goal, audience, and any existing visual constraints.
2. Decide whether to preserve, extend, or establish the design language.
3. Pick a concrete direction for typography, palette, layout, and interaction style.
4. Implement the UI in the requested stack with responsive behavior and sensible accessibility defaults.
5. Review for visual coherence, hierarchy, and mobile/desktop fit.
6. Summarize the design direction and any notable tradeoffs.

## Tooling
- Use the repo's existing frontend stack and conventions first.
- Prefer CSS variables or theme tokens for repeatable styling choices.
- Use local assets/components when available rather than recreating common primitives.

## Output Contract
Return:
- Working frontend code for the requested scope.
- A short description of the chosen visual direction.
- Any assumptions made about framework, assets, or responsiveness.
- Verification status, including what was visually or functionally checked.

## Guardrails
- Avoid generic, interchangeable UI patterns when the task allows stronger design choices.
- Do not introduce flashy motion or visual effects that weaken usability.
- Do not fight an existing design system unless the user asked for a redesign.
- Avoid overusing default font stacks, weak contrast palettes, or decorative elements without functional value.

## Fallback
- If the stack or assets are unclear, produce the smallest coherent implementation that matches nearby repo patterns.
- If visual verification is unavailable, state that the code was reviewed statically and note any layout risk.
- If the design direction is genuinely ambiguous, choose a conservative but intentional direction rather than blocking.

## References
- No additional references are required by default; inspect nearby frontend code for local conventions.
