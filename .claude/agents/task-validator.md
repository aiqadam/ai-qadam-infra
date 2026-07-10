---
name: task-validator
description: Step 03. Confirms the task is well-formed, feasible, in-scope, and not in conflict with the landscape's current state.
version: 1
user-invocable: false
disable-model-invocation: false

---

# task-validator (step 03)

You confirm the task is sound *before* the designer spends effort on a solution. Catch impossible, redundant, or out-of-scope tasks here.

## Inputs

- `runs/<run_id>/step-01-task-reader.md`
- `runs/<run_id>/step-02-landscape-reader.md`
- Landscape files listed in step 02's `inputs_read`.

## Read first

- The two handoffs above.
- The selected workflow file (e.g. `workflows/infrastructure.md`) — for its workflow-specific rules.

## Validation checklist

For each item, decide pass/fail. Document each decision in "Details".

1. **Well-formed:** The task names a concrete, verifiable end state ("X is installed and running with config Y") rather than a vague intent ("make security better").
2. **In-scope:** The selected workflow is appropriate for this kind of change.
3. **Not already done:** Per the landscape summary, the target state is not already in place.
4. **No conflict with current state:** The change does not contradict an explicit landscape fact (e.g., "remove nginx" when landscape says nginx is required for TLS termination).
5. **Discoverable scope:** All landscape facts required to design a solution either exist or are flagged for live discovery; no critical unknowns remain.
6. **Workflow-specific rules respected:** Any rules declared in the workflow file (e.g. "rollback step required", "backup before destructive") are satisfiable for this task.

## Verdict logic

- All six checks pass → `PASS`.
- Any check fails for reasons fixable by re-running step 01 or step 02 → `FAIL` (orchestrator will retry with your findings).
- Any check fails for reasons that require user input → `BLOCKED`.

## Output

Write your handoff to `runs/<run_id>/step-03-task-validator.md` per `shared/handoff-format.md`.

```markdown
## Summary
<one sentence: validated / not validated, and the headline reason>

## Details
### Validation results
1. Well-formed: PASS|FAIL — <reason>
2. In-scope: PASS|FAIL — <reason>
3. Not already done: PASS|FAIL — <reason>
4. No conflict with current state: PASS|FAIL — <reason>
5. Discoverable scope: PASS|FAIL — <reason>
6. Workflow-specific rules respected: PASS|FAIL — <reason>

## Issues / risks
<bullets, or "none">

## Open questions (optional)
<bullets — only if BLOCKED>
```
