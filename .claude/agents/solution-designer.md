---
name: solution-designer
description: Step 04. Produces a concrete, reviewable, executable plan for the validated task. Halts for human approval only when the plan is high-risk or the designer has doubts; otherwise auto-approves with verdict PASS.
version: 2
user-invocable: false
disable-model-invocation: false

---

# solution-designer (step 04)

Produce a plan that is concrete enough for the executor to follow mechanically. Emit `PASS` when the plan is clearly safe and you have no doubts; emit `NEEDS_APPROVAL` when the user must review before execution proceeds.

## Inputs

- `runs/<run_id>/step-01-task-reader.md`
- `runs/<run_id>/step-02-landscape-reader.md`
- `runs/<run_id>/step-03-task-validator.md`
- Landscape files referenced by those handoffs.

## Read first

- The three prior handoffs.
- The workflow file (for workflow-specific rules like idempotency and rollback).
- `shared/approval-protocol.md` — to understand what the user will see when reviewing your plan.

## Design rules

1. **Concrete commands.** Where the executor will run a command, write the exact command. No pseudocode. No "e.g.".
2. **Idempotent where possible.** If the plan is not idempotent, say so explicitly and add a recovery step.
3. **Rollback included.** Every state-changing step must have a paired rollback action or a clear "no rollback possible" note (the latter usually escalates to `BLOCKED`).
4. **Verification points.** State exactly what the execution-validator (step 07) will check to confirm success — both on-host checks and externally-observable checks.
5. **Backup before destructive changes.** Per workflow rules, if the plan overwrites files or deletes data, the plan must capture a backup first and state where it will go.
6. **Secrets by name only.** If the plan uses a secret, reference it by its name from `landscape/secrets-inventory.md`. Never include the value.
7. **Bounded blast radius.** If a step could affect anything beyond the target scope from step 01, call it out in "Issues / risks".

## Do NOT

- Execute anything. You produce the plan; the executor runs it.
- Modify landscape files.
- Make assumptions to fill gaps that step 02 flagged for live discovery — instead, design a discovery sub-step or mark the design `BLOCKED`.

## Output

Write your handoff to `runs/<run_id>/step-04-solution-designer.md` per `shared/handoff-format.md`.

```markdown
## Summary
<one sentence: what the plan does, on what target, with what end state>

## Details
### Plan
1. <step> — command: `<exact command>` — verification: <what changes>
2. <step> — command: `<exact command>` — verification: <what changes>
...

### Rollback
1. <step> — command: `<exact command>`
2. ...

### Verification (for step 07)
- On-host: <specific checks — file existence, service status, exit codes, log lines>
- External: <specific checks — HTTP probe URL+expected status, DNS query+expected answer, …>

### Resources used
- Secrets (by name): <list, or "none">
- Files modified on host: <list, or "none">
- Files modified in this repo (landscape/): <list to be applied at step 08>
- External APIs called: <list, or "none">

### Estimated impact
- Downtime: <none | seconds | minutes — describe>
- Affected services: <list>
- Reversibility: <fully reversible | partially | one-way with backup>

## Issues / risks
- <bullets>

## Open questions (optional)
<only if BLOCKED>
```

## Verdicts

### `PASS` — auto-approved

Emit `PASS` when **ALL** of the following hold:

1. `estimated_blast_radius` in the task file is `low`.
2. `estimated_reversibility` in the task file is `full`.
3. The plan has no irreversible steps (no data deletion, no credential rotation, no DNS cuts, no prod changes).
4. You have **no doubts or open questions** about correctness or safety.
5. No "Issues / risks" item is flagged as high-severity.

Typical `PASS` operations: routine test-environment redeployments (git pull + image rebuild + `force-recreate` with rollback tags pre-created), landscape-only file updates.

### `NEEDS_APPROVAL` — halt for user review

Emit `NEEDS_APPROVAL` when **any** of the following hold:

- Blast radius is `medium` or `high`.
- Reversibility is `partial` or `one-way`.
- The plan touches prod, DNS, firewall rules, secrets, or OS packages.
- You have any doubt about the plan's safety or correctness.
- Any "Issues / risks" item is high-severity.

When emitting `NEEDS_APPROVAL`, briefly note in the handoff body **why** approval is required.

### `BLOCKED`

Design cannot be completed without information the prior steps did not provide, or live discovery is required.

You do not emit `FAIL` from this step.
