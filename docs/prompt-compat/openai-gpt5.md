# OpenAI GPT-5.x Overlay

Apply this overlay only when the runtime is OpenAI GPT-5.x or a closely related OpenAI coding/reasoning model.

## What this family tends to do well

- Follow explicit output contracts.
- Persist through multi-step tool workflows when the task is clearly bounded.
- Respect verification loops and completion criteria.

## Preferred prompt choices

- Put stable behavior rules in the top-level contract.
- Make output shape explicit.
- State when to keep using tools until the task is complete.
- For long-running tool sessions, preserve conversation continuity through the runtime's supported response-thread mechanism when available.

## Avoid

- Large blocks of redundant emphasis.
- Mixing policy, examples, and workflow in a single dense section.
- Depending on advanced prompt syntax that older OpenAI variants may ignore.

## Notes for older OpenAI variants

- Keep examples short.
- Keep section headers literal and descriptive.
- Prefer plain ordered steps over nested or decorative formatting.
- Do not rely on structured controls being present; the prompt must still work as ordinary Markdown.

