---
name: "debate-end"
description: "Terminate a running debate session and dismiss the team. Use when: user wants to end, close, or stop a debate."
---

# /debate:end

Terminate the current multi-question debate session. Relay `[USER] end session` to the Moderator, who will write the debate note and send `[SHUTDOWN]`.

Load the debate skill from `debate/SKILL.md` and execute the `end` / `close` flow.
