---
id: T-0140-executor-stall-without-handoff-process-gap
title: Executor subagent stalled mid-run after a state-changing action without writing a handoff — process gap in executor-infra.md (or shared protocol)
kind: observation
status: observation
priority: P2
created: 2026-08-20
updated: 2026-08-20
closed:
outcome:
created_by: 2026-08-20-rotate-qa-postgres-password-001
source_runs: [2026-08-20-rotate-qa-postgres-password-001]
executed_by_runs: []
affects:
  - .claude/agents/executor-infra.md
workflow: none
blocks: []
blocked_by: []
related: [T-0138-rotate-qa-postgres-password]
estimated_blast_radius: low
estimated_reversibility: full
---

# Executor subagent stalled mid-run after a state-changing action without writing a handoff — process gap in executor-infra.md (or shared protocol)

## Why

During run `2026-08-20-rotate-qa-postgres-password-001` (task
[T-0138](T-0138-rotate-qa-postgres-password.md)), the subagent
originally assigned to execute the approved rotation plan completed
Phase 0 (discovery) and most of Phase 2 (rotate + apply — `ALTER ROLE`,
both `.env` backups, `POSTGRES_PASSWORD`/`AIQADAM_QA_POSTGRES_PASSWORD`
updated, all four consumer containers recreated), then **stalled**: it
launched a background SSH task and stopped calling tools entirely,
without waiting for or checking that task's result, and without
writing a completed handoff of any kind (not even a `BLOCKED` one).

Per [`step-06-executor-infra.md`](../runs/2026-08-20-rotate-qa-postgres-password-001/step-06-executor-infra.md)
(Issues / risks section):

> The originally-assigned subagent stalled and did not complete its
> own handoff. It performed real, correct work (Phase 0, most of Phase
> 2) but stopped after launching a background task and declaring
> further tool calls "not working," without actually waiting for or
> checking that task's result. This left the system in a
> partially-rotated, live-broken state (`api` crash-looping in what is
> effectively a production-adjacent QA environment) with no handoff
> explaining why. This is a process gap worth flagging for whoever
> maintains this repo's subagent tooling — a stall-without-handoff
> after a state-changing action has already been taken is more
> dangerous than a clean `BLOCKED`, since nothing in the run directory
> signals the true live state until someone checks manually, which is
> what happened here.

This was only caught because the Orchestrator directly checked live
host state and found `aiqadam-qa-api-1` crash-looping — a manual
catch, not a systemic one. The
[`step-07-execution-validator.md`](../runs/2026-08-20-rotate-qa-postgres-password-001/step-07-execution-validator.md)
independently corroborated the stall account (the archived
`.attempts/step-06-executor-infra-attempt-1.md` is a fully-formed
`BLOCKED` handoff against an *earlier, unrelated* pre-revision plan —
there is no second archived attempt for this stall, consistent with a
stall producing no handoff at all rather than a completed retry).

**Why this is worse than a clean `BLOCKED`:** a `BLOCKED` verdict is a
known, structured failure mode — the orchestrator halts and reports a
specific blocker, and nothing further happens until it's resolved. A
stall-after-a-state-changing-action is unstructured: real
infrastructure had already been mutated (Postgres role password
rotated, three of four containers recreated) when the subagent went
silent, but nothing in the run directory recorded that partial state
or explained it. Anyone reading the run directory alone, without
manually checking live host state, would not know the system was
mid-rotation and partially broken.

## What done looks like

- [ ] Whoever maintains `.claude/agents/executor-infra.md` (or the
      shared protocol doc, if the fix belongs there instead, e.g.
      `.claude/agents/` shared conventions or a protocol file governing
      all executor-type agents) reviews whether an explicit instruction
      is needed: an executor that launches a background/async task MUST
      wait for and check that task's result before ending its turn —
      never end a turn with an outstanding background task
      unaccounted-for, especially after a state-changing action has
      already been taken.
- [ ] Decide whether the fix is executor-infra.md-specific or belongs
      in a shared cross-agent doc (this is plausibly not specific to
      infra execution — any executor-shaped agent that can launch
      background work could stall the same way).
- [ ] If a rule is added, consider whether it should also cover the
      degenerate case surfaced here: a subagent that stops calling
      tools because it (incorrectly) believes further calls are "not
      working" — i.e., some guidance on distinguishing a genuine tool
      failure worth halting into `BLOCKED` for, versus a transient
      issue that should be retried before giving up silently.
- [ ] Once a decision is made (fix applied, or explicitly deferred/
      wontfix'd with reasoning), close this task.

## Result

<empty until closed>

## Notes

This is the second distinct agent-behavior gap surfaced in one working
session — [`step-06-executor-infra.md`](../runs/2026-08-20-rotate-qa-postgres-password-001/step-06-executor-infra.md)'s
"Open questions" section explicitly asks whether this should be
written up alongside a similar rule-1 read-only-diagnostic carve-out
recommended by T-0136's own step 07. Worth checking whether that
earlier recommendation was ever acted on, and if so, using the same
mechanism/location for this one.

No destructive or unrecoverable state resulted this time — the
crash-looping `api` container was down, not silently serving wrong
data, and every fix applied going forward used the already-rotated
(new) password. Total incident window (rotation start to `api`
healthy) was approximately 20 minutes, entirely within the session,
before any external report. This task is about closing the process
gap, not about any live damage — there was none.

## History
- 2026-08-20: created from 2026-08-20-rotate-qa-postgres-password-001
