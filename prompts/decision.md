# Decision

## Purpose
Use this when a session produced a real decision that should become an ADR.

## Body
Review the current task or session and determine whether it produced a decision that deserves an ADR.

Use an ADR only if the session contains:
- an architecture decision
- a design tradeoff
- a meaningful implementation strategy choice
- a decision likely to be questioned later
- enough rationale and consequences that future readers would need the record

Do not create an ADR for:
- temporary task status
- minor bug fixes
- obvious routine changes
- diary-style progress notes

If an ADR is justified:
1. Inspect existing ADRs under `docs/adr/` before drafting anything.
2. Propose the next sensible ADR number. If none exists, start at `ADR-0001`.
3. Propose a file name under `docs/adr/` using that ADR number and a short slug.
4. Draft the ADR using this structure:

```md
# ADR-XXXX: Title

## Status
Proposed | Accepted | Superseded

## Context
What problem or constraint led to this decision?

## Decision
What was chosen?

## Consequences
What becomes easier, harder, or constrained by this choice?

## Alternatives considered
Optional, only if useful.
```

If an ADR is not justified:
- say so clearly
- use `no ADR needed` when the threshold is not met
- recommend the better destination instead, such as `docs/notes/` or `.worklog/latest-handoff.md`

## Output Format
## ADR needed?
Yes or No

## Reason
Why this is or is not ADR-worthy.

## Recommended destination
`docs/adr/...` or the better alternative

## Draft
Provide the exact markdown draft if applicable.
