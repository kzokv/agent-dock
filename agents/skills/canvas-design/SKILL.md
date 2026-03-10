---
name: canvas-design
description: Create original static visual designs in PNG or PDF.
license: Complete terms in LICENSE.txt
---

# Canvas Design

## Purpose
Create original static visual artifacts such as posters, covers, diagrams, or art pieces. The output should prioritize composition, typography, spacing, and export quality rather than interactive behavior.

## Use This Skill When
- The user wants a static visual deliverable such as a poster, cover, flyer, sheet, or art print.
- PDF or PNG output quality matters.
- The task needs strong layout, typography, and visual hierarchy.

## Do Not Use This Skill When
- The task should be generative or interactive.
- The request is primarily about application UI rather than a static artifact.
- The user wants a direct imitation of a copyrighted artist or brand campaign.

## Required Inputs
- The subject, audience, or intended mood.
- Output format: PDF, PNG, or both.
- Size or aspect ratio when known.
- Any text that must appear in the composition.

If size, palette, or text density are unspecified, choose defaults that fit the subject and medium.

## Default Behavior
- Produce a single-page artifact unless the user asks for multiple pages.
- Keep text minimal and purposeful unless the task is explicitly information-dense.
- Use local fonts from `canvas-fonts/` before introducing new ones.
- Favor a limited palette and a clear compositional system.
- Keep all elements within safe margins and export bounds.

## Workflow
1. Reduce the request to a design direction: subject, tone, density, palette, and typography approach.
2. Decide the layout system: grid, asymmetry, diagrammatic composition, or image-led composition.
3. Gather only the assets needed: text, images, fonts, and output dimensions.
4. Build the composition with attention to hierarchy, spacing, and export fidelity.
5. Inspect the output for overlap, clipping, margin issues, and legibility.
6. Export the final PDF or PNG and include a short note on the design direction when useful.

## Tooling
- Local font source: `canvas-fonts/`.
- Output artifacts: `.pdf`, `.png`, and optional `.md` notes when the user wants design rationale.
- Reuse existing repo scripts or rendering helpers when the task already has a preferred path.

## Output Contract
Return:
- The final static artifact in the requested format.
- Any required companion text file only if the user asked for rationale or if the workflow requires one.
- A short description of the visual direction and major constraints.
- Verification status, including whether layout was visually checked after export.

## Guardrails
- Keep the work original; do not replicate living artists or copyrighted campaigns.
- Do not inflate simple requests into multi-page packages unless asked.
- Do not let text, marks, or images spill outside the canvas.
- Prefer concrete design decisions over abstract manifestos.
- Use additional fonts only when the local set is insufficient.

## Fallback
- If PDF generation is unreliable, export PNG and note the limitation.
- If fonts or imagery are unavailable, use simple geometric composition and system-safe assets already in the repo.
- If visual review is not possible, state that the artifact was checked structurally but not rendered end to end.

## References
- `canvas-fonts/` for local type options.
