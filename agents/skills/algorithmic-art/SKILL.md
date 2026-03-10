---
name: algorithmic-art
description: Build original algorithmic art with p5.js.
license: Complete terms in LICENSE.txt
---

# Algorithmic Art

## Purpose
Create original generative art as working code, not a static mockup. Prefer reproducible systems with seeded randomness, clear parameter controls, and an output artifact the user can run or inspect.

## Use This Skill When
- The user wants generative art, p5.js sketches, flow fields, particle systems, or interactive algorithmic visuals.
- The deliverable should be code-driven and reproducible.
- The user wants exploration through parameters, seeds, or multiple variants.

## Do Not Use This Skill When
- The request is for a static poster, print, or single raster composition without algorithmic behavior.
- The user wants a faithful copy of another artist or copyrighted work.
- The task is primarily UI/product design rather than art generation.

## Required Inputs
- Creative prompt, subject, or mood.
- Output target: single HTML artifact, HTML plus JS, or another repo-specific format.
- Any technical constraints such as canvas size, runtime, controls, or library limits.

If key details are missing, infer sensible defaults and proceed unless the missing information changes the medium or output format.

## Default Behavior
- Use p5.js unless the user requests another runtime.
- Make the system deterministic with a seed.
- Expose only the parameters that materially change the composition.
- Favor one coherent visual system over multiple unrelated effects.
- If `templates/viewer.html` fits the task, use it as a starting scaffold and adapt branding/layout to the request instead of preserving template-specific styling.

## Workflow
1. Distill the request into a short artistic direction: visual goal, motion/structure, palette, and interaction level.
2. Define the algorithm in plain terms before coding: primitives, forces, randomness, temporal behavior, and stopping conditions.
3. Choose the artifact structure:
   - Single-file viewer when portability matters.
   - HTML plus separate JS only when the repo or user prefers split files.
4. Implement seeded randomness and parameter controls.
5. Verify that the sketch renders, stays within performance limits, and produces meaningful seed variation.
6. Save the final artifact and include a brief note on what each main parameter controls.

## Tooling
- Primary runtime: p5.js.
- Preferred scaffold: `templates/viewer.html`.
- Output artifacts: `.html`, optional `.js`, and optional short `.md` notes when the user asks for explanation or philosophy.

## Output Contract
Return:
- A runnable generative-art artifact.
- Reproducibility details: seed behavior and exposed parameters.
- A short explanation of the visual system and how to vary it.
- Verification status, including whether the artifact was executed or only reviewed statically.

## Guardrails
- Keep the work original; do not mimic a living artist or reproduce copyrighted imagery.
- Do not pad the result with abstract philosophy if the user asked for code.
- Keep controls focused; too many parameters make the system harder to steer.
- Avoid hard-coding decorative UI assumptions from templates when they do not fit the request.
- Prefer plain Markdown and code comments over rhetorical framing.

## Fallback
- If p5.js is unsuitable for the environment, produce the algorithm in plain JavaScript with a simple canvas loop and note the tradeoff.
- If no interactive viewer is needed, provide a minimal reproducible HTML artifact without side panels or controls.
- If visual execution cannot be verified locally, state that clearly and describe the expected runtime behavior.

## References
- `templates/viewer.html` for an optional viewer scaffold.
