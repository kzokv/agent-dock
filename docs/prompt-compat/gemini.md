# Gemini Overlay

Apply this overlay only when the runtime is Gemini or a closely related Google model/tooling surface.

## What this family tends to do well

- Follow structured prompts with explicit task boundaries.
- Work well with concise system or instruction layers plus clear output requirements.
- Benefit from explicit separation of context, task, and desired answer shape.

## Preferred prompt choices

- Front-load the task and expected deliverable.
- Keep formatting simple and stable.
- Prefer short examples to long demonstrations.
- Keep tool expectations explicit rather than implied.

## Avoid

- Long policy dumps before the actual task.
- Deeply nested formatting.
- Provider-specific semantics in the shared contract.

## Compatibility note

- The shared prompt should read cleanly without any special roles, tags, or runtime-specific controls.

