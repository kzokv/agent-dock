# Tier Selection Heuristics

Use this table to recommend a tier. Score each signal, then use the highest tier that any signal triggers.

---

## Selection criteria

| Signal | Tier 1 (Solo) | Tier 2 (Squad) | Tier 3 (Full Team) |
|--------|---------------|----------------|-------------------|
| **Files likely changed** | 1-2 | 3-8 | 9+ or new module |
| **Layers touched** | 1 (e.g., just API) | 2 (e.g., API + tests) | 3+ (API + UI + DB + tests) |
| **Spec complexity** | "Fix this bug", typo, config | "Add this endpoint with tests" | PRD, multi-story feature |
| **Risk level** | Low, isolated, well-understood | Moderate, known area | High, cross-cutting, new territory |

**Rule: The highest tier triggered by any single signal wins.**

If a task scores Tier 1 on files but Tier 3 on risk, recommend Tier 3.

---

## Examples

| Task | Files | Layers | Complexity | Risk | Tier |
|------|-------|--------|------------|------|------|
| Fix typo in error message | 1 | 1 | Low | Low | **1** |
| Add input validation to 2 API routes | 2 | 1 | Low | Low | **1** |
| New API endpoint with auth + unit tests | 4 | 2 | Moderate | Moderate | **2** |
| Bug fix touching API handler + UI component + test updates | 5 | 2 | Moderate | Moderate | **2** |
| OAuth identity resolution (new module, API + UI + DB + e2e) | 12 | 3+ | High | High | **3** |
| Database schema migration with API + UI updates | 10+ | 3+ | High | High | **3** |

---

## Edge cases

- **Refactoring:** Even if touching many files, if the change is mechanical (rename, move) and low-risk, Tier 2 is usually sufficient.
- **Security fixes:** Escalate risk by one tier. A "simple" auth fix that touches 2 files is still Tier 2 because the blast radius of getting it wrong is high.
- **Unknown territory:** If you're unsure how many files will be affected (new codebase, unfamiliar module), start at Tier 2 and use `/team scale-up` if needed.

---

## Recommendation format

```
Recommended: Tier N ([Solo/Squad/Full Team])
Reasoning:
- Files: ~N files ([list key ones])
- Layers: [which layers]
- Complexity: [assessment]
- Risk: [assessment with reason]

Approve? [y/n]
```

Always wait for user approval before spawning.

---

## Cost estimates

Approximate cost per team run, assuming Anthropic API pricing. Estimates assume 1-2 iterations for Tier 1, 2-3 for Tier 2, 2-4 for Tier 3.

| Tier | Teammates | Opus agents | Sonnet agents | Est. cost range |
|------|-----------|-------------|---------------|-----------------|
| 1 (Solo) | 4 | 2 (Architect, Implementer) | 2 (QA, Validator) | **~$2-5** |
| 2 (Squad) | 6 | 3 (Architect, Implementer, QA) | 3 (Fixer, Validator, Reviewer) | **~$5-15** |
| 3 (Full Team) | 8 | 3 (Architect, Implementer, QA) | 5 (Fixer, Validator, Reviewer, Writer, Curator) | **~$15-40** |

**Cost multipliers:**
- Each additional iteration adds ~30-50% of base cost
- Reaching the 5-iteration hard ceiling can 2-3x the estimate
- Complex codebases with large context reads increase input token costs

Include the cost estimate in the tier recommendation so the user can make an informed decision.
