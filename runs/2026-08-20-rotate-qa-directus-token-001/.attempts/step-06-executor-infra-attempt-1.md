---
run_id: 2026-08-20-rotate-qa-directus-token-001
step: 06
agent: executor-infra
verdict: FAIL
created: 2026-08-20T00:00:00Z
task_id: T-0137-rotate-qa-directus-admin-token
inputs_read:
  - runs/2026-08-20-rotate-qa-directus-token-001/step-04-solution-designer.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-qa.md
artifacts_changed: []
next_step_hint: >-
  Plan's own Phase 0.1 branch was hit: DIRECTUS_TOKEN and DIRECTUS_ADMIN_TOKEN
  are DIFFERENT values on pro-data-tech-qa, not the same secret under two
  names as the task premise assumed. Per step-04's explicit instruction,
  re-route to step 03 (task-validator) / user for a revised task/plan before
  any rotation is attempted. Do not re-invoke this executor step against the
  current plan — it would hit the same halt at 0.1 with no further progress
  possible, since Phases 1-3 as written assume "update both names to the
  identical new value," which is invalidated.
retry_of: null
---

## Summary

Executed only Phase 0.1 of the approved plan (discovery, read-only) before
halting per the plan's own explicit branch instruction: `DIRECTUS_TOKEN` and
`DIRECTUS_ADMIN_TOKEN` in `/opt/apps/aiqadam-qa/deploy/.env` are
**`DIFFERENT_VALUE`**, not the same secret under two names as the task's
premise assumed. No further plan steps (0.2 onward) were run. No state was
changed on any system — this was a pure read-only comparison. The plan
mandates stopping here and returning to step 03/user rather than proceeding,
which this handoff does.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (`runs/2026-08-20-rotate-qa-directus-token-001/step-05-user-approval.md`)
- `inputs_read` in step-05 references step-04: yes
- Design references match: yes

### Execution log

#### Step 1 (Phase 0.1): Re-verify DIRECTUS_TOKEN and DIRECTUS_ADMIN_TOKEN are the same secret under two names
- Command: `ssh pro-data-tech-qa "diff <(grep '^DIRECTUS_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env | md5sum) <(grep '^DIRECTUS_ADMIN_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env | md5sum) >/dev/null && echo SAME_VALUE || echo DIFFERENT_VALUE"`
- Exit code: 0 (the `ssh` invocation itself succeeded; the printed token is the comparison result, not an ssh/command failure)
- Output (trimmed, exact and complete — this command's output space is limited by design to one of two literal tokens):
  ```
  DIFFERENT_VALUE
  ```
- Result: **branch condition hit — plan mandates STOP, not failure of the command itself**
- Backup taken: n/a (Phase 0 is read-only per plan; no backup step reached)

No further steps were executed. Per step-04's Phase 0.1 text (verbatim):

> **Branch:** if `DIFFERENT_VALUE`, STOP this plan and re-route to step 03
> (task-validator) / user — the task's premise (one secret, two names) would
> be false and the rotation steps below (which assume updating both names to
> the same new value) would be wrong. Do not proceed past 0.1 on
> `DIFFERENT_VALUE`.

This executor complied: Phases 0.2–0.6, 1, 2, and 3 were not attempted. No
diagnostic command beyond the plan's exact 0.1 template was run to
investigate further (per this run's explicit constraint against improvised
diagnostics — see step-04 "Issues / risks" and this run's own task framing
re: the T-0136 incident).

### Rollback executed
Not needed — no destructive or state-changing action was taken at any point.
The single command executed was read-only (a `diff`/`md5sum` comparison over
two `grep` matches; nothing was written, generated, or applied).

### Resources changed
- Files on host: none
- Services restarted: none
- External resources changed: none

## Issues / risks

- **The task's foundational premise is false on live evidence.** Task
  T-0137 and step-04's plan both assumed `DIRECTUS_TOKEN` and
  `DIRECTUS_ADMIN_TOKEN` are the same secret stored under two variable
  names in `/opt/apps/aiqadam-qa/deploy/.env`. Phase 0.1's live check
  (the exact command specified by the plan) returned `DIFFERENT_VALUE`.
  This means the two variables currently hold two distinct secret values,
  and the rotation steps in Phases 1–3 — which are written to generate
  ONE new value and write it to BOTH variable names (see plan step 2.4:
  `s|^DIRECTUS_TOKEN=.*|DIRECTUS_TOKEN=$NEW_TOKEN|;
  s|^DIRECTUS_ADMIN_TOKEN=.*|DIRECTUS_ADMIN_TOKEN=$NEW_TOKEN|`) — would be
  incorrect as written if executed against this actual on-host state:
  either they serve genuinely different purposes (e.g. one is the live
  Directus static admin token, the other is stale/unused/a
  differently-scoped credential) and collapsing them to one value could
  break whichever consumer relies on the variable that would be
  overwritten with the wrong new value, or one of the two is already
  stale and rotating only the live one is the correct scope — which is
  which is unknown from this check alone and requires task-validator /
  landscape investigation, not executor-level guessing.
- **No secret value, hash, or digest was captured, printed, or written
  anywhere in this run** — Phase 0.1 was the only command executed, and
  its own design (per step-04) structurally cannot emit anything but the
  two literal strings `SAME_VALUE`/`DIFFERENT_VALUE`. This handoff
  contains no secret material, consistent with this run's zero-secret-
  leakage requirement.
- **This is not an approval-gate or access failure** — the approval gate
  passed cleanly (verified above) and the host was reachable. The `FAIL`
  verdict here reflects "plan flawed" per `shared/verdicts.md`'s
  definition (discovery invalidated the plan's premise), not `BLOCKED`
  (which is reserved for cases where this step itself cannot proceed for
  access/environment reasons outside its control). The correct next
  action per step-04's own text and `shared/verdicts.md`'s `FAIL` routing
  is re-invocation of step 03 (task-validator) with this finding, not a
  retry of this executor step against the unmodified plan.

## Open questions (optional)

- Are `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` two independently-used
  credentials (e.g. different consumers, different scopes/permissions), or
  is one of them stale/orphaned (e.g. left over from a prior config change
  and no longer read by anything)? This determines whether T-0137 should be
  revised to a) rotate both independently with two new distinct values, b)
  rotate only the one that's actually live and separately handle/deprecate
  the other, or c) something else — task-validator and/or a fresh
  discovery run against `deploy/docker-compose.qa.yml` and the app
  containers' actual env consumption (which var name each of `api`,
  `web-next`, and `directus` itself reads) would resolve this.
- Should `landscape/hosts/pro-data-tech-qa.md` or a new landscape file be
  updated to record that `DIRECTUS_TOKEN` ≠ `DIRECTUS_ADMIN_TOKEN` on this
  host, so future tasks don't restate the same false premise? (Step 08's
  scope per the workflow — this executor did not edit any landscape file,
  per its own "Do NOT... edit landscape files" rule.)
