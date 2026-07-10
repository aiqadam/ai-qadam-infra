---
name: verdicts
version: 1
description: Verdict vocabulary used by every subagent and consumed by the orchestrator's routing logic.
---

# Verdict vocabulary

Every subagent step emits exactly one verdict in its handoff frontmatter. The orchestrator routes the workflow based on this verdict — not on prose in the body.

## Allowed verdicts

| Verdict | Meaning | Orchestrator action |
|---|---|---|
| `PASS` | Step completed successfully, output is valid, workflow may proceed. | Advance to next step. |
| `FAIL` | Step completed but its output is invalid (validation failed, plan flawed, execution had errors). | If retry budget remaining for this step: re-invoke the step with the failed handoff path as `retry_of`. If budget exhausted: escalate to user via `BLOCKED`-equivalent message. |
| `PASS` (from step 04) | Design is complete AND auto-approved: blast radius is low, fully reversible, no designer doubts, no high-severity risks. Orchestrator advances directly to executor — no step 05 written. | Advance to executor (step 06). Do NOT write a step-05 file. |
| `NEEDS_APPROVAL` | Step produced a plan that requires explicit human sign-off (high/medium blast radius, irreversible steps, or designer has doubts). | Halt the workflow. Present the handoff to the user. Wait for the user to instruct the orchestrator to write a `step-NN-user-approval.md` file with `verdict: APPROVED` or `verdict: REJECTED`. |
| `BLOCKED` | Step cannot proceed for reasons outside its control (missing access, missing landscape data, ambiguous user intent, upstream dependency failure). | Halt the workflow. Report the blocker to the user with a specific ask. Do not retry until the blocker is resolved. |
| `APPROVED` | Used only by the human-approval step. Signals the executor it may proceed. | Advance to the executor step. |
| `REJECTED` | Used only by the human-approval step. Signals the design is rejected. | Halt or restart from the design step with rejection feedback. |

## Retry budget

Default retry budget per step: **2 retries** (i.e., up to 3 total attempts). The orchestrator tracks retries in its working state, not in the handoff files. A retry produces a new handoff file `step-NN-<agent>.md` that overwrites the prior one — but the prior one is archived under `runs/<run_id>/.attempts/step-NN-<agent>-attempt-<M>.md` for audit.

## Approval gate enforcement

The executor MUST verify before taking any state-changing action:

1. Read `runs/<run_id>/step-04-solution-designer.md` and check `verdict:`.
2. If `verdict: PASS` → auto-approved; proceed without a step-05 file.
3. If `verdict: NEEDS_APPROVAL` → read `runs/<run_id>/step-05-user-approval.md`, confirm `verdict: APPROVED`, confirm `inputs_read` references the step-04 handoff.
4. Any other outcome → emit `verdict: BLOCKED`, do not execute.

This is defense-in-depth: even if the orchestrator skips a required step, the executor refuses to act.

## Verdict parsing

The orchestrator extracts the verdict by reading the frontmatter YAML of the most recent step file. The verdict field is case-sensitive (always uppercase letters/underscore). Any value not in the table above MUST be treated as `FAIL`.
