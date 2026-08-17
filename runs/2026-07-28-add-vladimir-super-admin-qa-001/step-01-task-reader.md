---
run_id: 2026-07-28-add-vladimir-super-admin-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-28T00:00:00Z
task_id: T-0131-add-super-admins-to-qa-group-after-signin
inputs_read:
  - tasks/T-0131-add-super-admins-to-qa-group-after-signin.md
artifacts_changed: []
next_step_hint: landscape-reader should load landscape/hosts/pro-data-tech-qa.md (RBAC-groups note, Authentik container name aiqadam-qa-authentik-server-1) before task-validator runs; the very first live action of this run should be the ak shell query confirming whether vladimir.titenko@aiqadam.org now has a QA Authentik User row.
---

## Summary
Register `vladimir.titenko@aiqadam.org` as a member of the `aiqadam-super-admin` RBAC group on QA Authentik — but only if a live on-host check confirms Authentik has provisioned a `User` row for that email (which requires at least one prior OIDC sign-in), per task T-0131 narrowed to this single email for this run.

## Details
- **Workflow:** infrastructure
- **Target scope:**
  - [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md)
- **Constraints stated by user:**
  - This run is scoped to `vladimir.titenko@aiqadam.org` only. The task's original acceptance criteria also name `viktor.drukker@aiqadam.org` and `binali.rustamov@aiqadam.org`, but those two are explicitly out of scope for this run per the task's "Current run scope" note (added 2026-07-28) and the orchestrator's step-specific input — they remain future incremental work under the same task file and must not be touched, queried for group-add, or reported as done/failed by this run.
  - Task design permits and expects incremental/subset execution — this is not a partial failure, it is the intended shape of this run.
- **Information gaps for downstream steps:**
  - Unknown (must be checked live, not assumed): does `vladimir.titenko@aiqadam.org` currently have a QA Authentik `User` row? This is the hard precondition called out in the task's "Why" section — Authentik only creates a user row after first OIDC sign-in to `https://qa.aiqadam.org`, and as of T-0131's creation, none of the 3 emails had signed in yet. This run must re-check live, fresh, on-host — not rely on the prior task's finding, which is now stale.
  - If the live check finds no user row yet for this email, the task's own design says this run should not attempt to pre-create the row or register on the user's behalf — it should escalate/BLOCK (mirroring T-0130's prior correct behavior), not silently no-op or fail as if it were an error.
  - Exact current membership/count of `aiqadam-super-admin` group is not yet known to this step — landscape-reader (step 02) should surface it from [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md).
  - The task also has verification and landscape-update acceptance criteria (see below) that only apply if the group-add actually happens this run.

### Why (quoted from task, verbatim)
> [T-0130](../../tasks/T-0130-register-super-admins-qa.md) created the
> `aiqadam-super-admin` RBAC group on QA Authentik
> (`aiqadam-qa-authentik-server-1`, pk `72615bc9-8cd7-4453-a5fb-f56c685ba30a`,
> `is_superuser=False`) — this prerequisite infrastructure is done and
> independently verified in two places (fresh on-host `ak shell` re-query
> by both the executor and the execution-validator).
>
> However, a live query at execution time found that **none of the 3
> intended super-admins** — `vladimir.titenko@aiqadam.org`,
> `viktor.drukker@aiqadam.org`, `binali.rustamov@aiqadam.org` — has a QA
> Authentik `User` row yet. Authentik only provisions a user row on first
> OIDC sign-in (confirmed via the reference script's own comments, and
> reconfirmed live by this task, not assumed). Per T-0130's own explicit
> design, the run correctly did not pre-create user rows or attempt
> registration on anyone's behalf — it escalated instead.
>
> This means the group-membership addition (the actual point of "register
> these 3 as super-admins") has not happened yet, and cannot happen until
> at least one of the 3 people signs in to `https://qa.aiqadam.org` at
> least once. This task exists to track and complete that remaining work
> once that precondition is met, rather than silently letting it drop now
> that T-0130 is closed.

### Acceptance criteria relevant to this run's scope (vladimir.titenko@aiqadam.org only)
Translated from the task's "What done looks like", filtered to this run's narrowed scope:

1. **Precondition check (must run first):** live query — `docker exec -i aiqadam-qa-authentik-server-1 ak shell -c "<query>"` — confirming whether `vladimir.titenko@aiqadam.org` now has a QA Authentik `User` row. Must use the non-interactive `ak shell -c "<code>"` invocation form (T-0130 found the interactive-stdin form swallows multi-line `print()` output).
2. **Conditional group-add:** if and only if step 1 finds a user row, add `vladimir.titenko@aiqadam.org` to `aiqadam-super-admin` via additive `.groups.add()` — idempotent, skip if already a member.
3. **On-host live verification:** a fresh, independent `ak shell` session (separate from the add step) confirms `aiqadam-super-admin` group membership for `vladimir.titenko@aiqadam.org`.
4. **External/functional verification (best-effort, deferred-friendly):** with cooperation from vladimir.titenko, confirm a real bearer JWT from his live QA sign-in is NOT rejected by `SuperAdminGuard` on `/v1/admin/invites` (expect `200`, not `403 {"message":"not_super_admin"}`). This step depends on human cooperation outside this run's control — solution-designer (step 04) should decide whether this is in-run or explicitly deferred/open-question.
5. **Landscape update:** update [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md)'s RBAC-groups note to reflect the new member (only if step 2 actually happened).
6. **Task closure decision:** since only 1 of 3 people is in scope for this run, and even a fully successful outcome here leaves 2 people un-added, this run cannot close T-0131 as `done` — at most it makes partial progress. The task should remain open (`in-progress` → likely back to `pending` or stay `in-progress` awaiting the other two) unless the user says otherwise. This is a step-08 (landscape-updater) decision, but flagged here so downstream steps don't assume full closure is in scope.

If step 1 finds no user row for `vladimir.titenko@aiqadam.org`, none of criteria 2-5 can be attempted this run; the run should proceed toward a `BLOCKED`/escalation outcome (likely at task-validator step 03 or executor step 06, once the live check is actually performed) rather than downstream steps assuming success.

## Issues / risks
- The core precondition (Authentik user row existing) is unverified as of this handoff — it is explicitly deferred to a live on-host check that only the executor (or landscape-reader/task-validator, if they probe live state) can perform. This step-01 handoff does not assert an answer either way.
- Scope discipline risk: because the task file's checkbox list still literally names all 3 emails, downstream steps must not over-read those checkboxes as this run's scope. This run's scope is vladimir.titenko@aiqadam.org only, per the task's own "Current run scope" note and the orchestrator's explicit instruction.
- Criterion 4 (external functional verification via a real user's live sign-in JWT) depends on human cooperation outside this repo's control and may not be completable synchronously within this run — downstream steps should treat it as best-effort/optionally-deferred rather than a hard blocker on task progress, consistent with how T-0130 treated the equivalent deferred Phase 3.2 item.

## Open questions (optional)
none — task and scope are clear enough to proceed to step 02.
