---
name: Interaction Style Feedback
description: How the user prefers Claude to ask questions and clarify requirements
type: feedback
---

Do not lead with a multi-question AskUserQuestion form when requirements are ambiguous. The user rejected a 4-option structured probe in favor of open conversation.

**Why:** The user prefers to clarify interactively rather than answer a structured survey cold. Presenting too many options at once feels like being interrogated before the problem is fully shared.

**How to apply:** When requirements are unclear, ask one focused question — either the single most-blocking ambiguity, or a brief "here are the two paths, which resonates?" prompt. If using AskUserQuestion, limit to 1–2 questions with 2–3 options max. Default to conversational text when the decision space is still open.
