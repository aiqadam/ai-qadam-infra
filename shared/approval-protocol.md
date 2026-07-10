---
name: approval-protocol
version: 3
description: How the human approval gate works between solution-designer and executor steps, and when it is skipped or auto-approved.
---

# Approval protocol

The approval gate sits between the solution-designer step and the executor step. **It exists to prevent any executor agent from making changes the user has not seen and accepted.** It applies to **state-changing workflows** only.

## Two ways approval is skipped entirely

### 1. Read-only workflows

A workflow may declare `state_changing: false` in its frontmatter. When set, step 05 (user approval) is skipped. This is allowed ONLY when ALL of the following hold:

1. The workflow's frontmatter declares `state_changing: false`.
2. The workflow's executor subagent's `tools:` allowlist contains NO write/mutation capabilities.
3. The executor's instructions explicitly forbid any state-changing action and require it to emit `BLOCKED` if asked to perform one.

The orchestrator MUST verify all three before skipping. If any check fails, the gate runs anyway.

### 2. Auto-approved designs (low-risk, no designer doubts)

When the solution-designer emits `verdict: PASS` (instead of `NEEDS_APPROVAL`), the orchestrator **skips step 05 entirely** and advances directly to the executor. No user interaction is needed.

The solution-designer may only emit `PASS` when **ALL** of the following hold:

1. `estimated_blast_radius` in the task file is `low`.
2. `estimated_reversibility` in the task file is `full`.
3. The plan has no steps rated as irreversible (no data deletion, no credential rotation, no DNS cuts).
4. The designer has **no doubts or open questions** about the plan.
5. No "Issues / risks" item is flagged as high-severity.

If **any** condition above is not met, the designer MUST emit `NEEDS_APPROVAL`.

**Typical auto-approved operations:** routine redeployments of an existing app to the test environment, git pulls with image rebuilds where rollback images are tagged first, read/write to `landscape/` files only.

**Always requires `NEEDS_APPROVAL`:** first-time deploys to prod, DNS changes, firewall rule changes, secret rotations, package installs, any destructive operation, any operation the designer is uncertain about.

## When `NEEDS_APPROVAL` — the gate sequence

1. **Solution-designer** writes its handoff with `verdict: NEEDS_APPROVAL`.
2. **Orchestrator** halts and presents the user with:
   - A one-line summary of the proposed change.
   - The path to the design handoff: `runs/<run_id>/step-<NN>-solution-designer.md`.
   - An explicit prompt: *"Approve this plan? Reply with `APPROVE`, `REJECT <reason>`, or `MODIFY <changes>`."*
3. **User** responds.
4. **Orchestrator** writes the approval handoff file:

   ```
   runs/<run_id>/step-<NN+1>-user-approval.md
   ```

   With frontmatter:

   ```yaml
   ---
   run_id: <run_id>
   step: <NN+1>
   agent: user-approval
   verdict: APPROVED | REJECTED
   created: <ISO-8601 UTC>
   inputs_read:
     - runs/<run_id>/step-<NN>-solution-designer.md
   artifacts_changed: []
   approved_by: <user identifier or "user">
   ---

   ## Summary
   User <approved|rejected> the design.

   ## Details
   <verbatim user response>

   ## Issues / risks
   <if REJECTED: the user's reason. If MODIFY: list of requested changes.>
   ```

5. **Routing:**
   - `APPROVED` → orchestrator advances to the executor step.
   - `REJECTED` → orchestrator halts and reports. The user decides whether to abandon, modify, or re-run from design.
   - `MODIFY <changes>` → orchestrator re-invokes solution-designer with the modification notes; archives the prior step-04 to `.attempts/`.

## When `PASS` — auto-approval sequence

1. **Solution-designer** writes its handoff with `verdict: PASS`.
2. **Orchestrator** does NOT write a step-05 file, does NOT halt for user input.
3. **Orchestrator** records in its status update: *"Design verdict PASS — auto-approved (low blast radius, fully reversible, no designer doubts). Advancing to executor."*
4. **Executor** sees no step-05 file. It checks step-04's verdict directly (see below).

## Executor verification (defense-in-depth)

Before any state-changing action the executor MUST:

1. Read `runs/<run_id>/step-04-solution-designer.md` and check its `verdict:`.
   - If `verdict: PASS` → auto-approved path. Proceed.
   - If `verdict: NEEDS_APPROVAL` → a step-05 file is required. Go to check 2.
2. (Only if step-04 verdict was `NEEDS_APPROVAL`) Read `runs/<run_id>/step-05-user-approval.md`. Confirm `verdict: APPROVED` and that `inputs_read` references the step-04 handoff.
3. If any check fails: write `verdict: BLOCKED`, do not execute.

This means even if the orchestrator skips a step it shouldn't, the executor refuses to act.

## What does and does not need approval

**Always `NEEDS_APPROVAL`:**
- Prod deployments (first-time or update).
- DNS changes, Cloudflare rule changes, firewall changes.
- Secret rotations or credential changes.
- Package installs or OS-level changes.
- Any destructive operation (data deletion, volume drops, file overwrites without backup).
- Any plan the designer is uncertain about.

**Auto-approved (`PASS`) when all conditions met:**
- Routine test-environment redeployments (git pull + image rebuild + `force-recreate`, rollback tags in place).
- Landscape-only updates (no host changes).

**Never needs approval (read-only workflows):**
- Landscape discovery runs.
- Validation steps that only read state.
- Handoff file writes inside `runs/<run_id>/`.
