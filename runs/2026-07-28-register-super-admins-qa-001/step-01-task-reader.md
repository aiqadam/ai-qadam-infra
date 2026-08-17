---
run_id: 2026-07-28-register-super-admins-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-28T00:00:00Z
task_id: T-0130-register-super-admins-qa
inputs_read:
  - tasks/T-0130-register-super-admins-qa.md
artifacts_changed: []
next_step_hint: landscape-reader should load landscape/hosts/pro-data-tech-qa.md and confirm current Authentik container/group state before task-validator runs.
---

## Summary
Add the three confirmed super-admins (vladimir.titenko@aiqadam.org, viktor.drukker@aiqadam.org, binali.rustamov@aiqadam.org) to the `aiqadam-super-admin` group on QA Authentik only, after a mandatory read-only discovery phase confirming the group exists (or creating it) and that all three emails already exist as QA Authentik users — prod is explicitly out of scope for this task.

## Details
- **Workflow:** infrastructure
- **Target scope:**
  - landscape/hosts/pro-data-tech-qa.md
- **Constraints stated by user:**
  - QA only for this task; do NOT touch `https://auth.aiqadam.org` (prod) — prod is a separate follow-up task to be created later, only once the user gives explicit go-ahead after QA is confirmed working end-to-end.
  - Do not modify `scripts/provision-authentik-rbac-groups.sh` in `aiqadam/ai-qadam-platform`. Either invoke it 3 times (once per email, `AUTHENTIK_URL=https://auth.qa.aiqadam.org`) or perform the equivalent 3 raw API/`ak shell` calls matching its logic — executor's choice based on QA's existing access pattern (T-0126 used `docker exec` + `ak shell`, not a REST token, since no long-lived QA Authentik token exists in secrets-inventory.md).
  - Group assignment must be additive (append to existing `groups` list, not replace) and idempotent (skip if already a member) — mirrors the script's own logic.
  - Hard precondition: Authentik only creates a user row on first OIDC sign-in. Phase 0 must verify live whether all 3 emails already exist as QA Authentik users. If any do not exist, task must STOP and escalate to the user for that person — do not pre-create user rows as a workaround, do not guess.
  - `aiqadam-super-admin` group's existence on QA must not be assumed — T-0126 only touched OAuth2 provider scope mappings, not RBAC groups. If missing, create it first (idempotent `ensure_group`-style step) before assigning anyone.
  - Live verification required in two places: (1) on-host group membership query for all users successfully added, and (2) functional check that at least one of the three can reach an admin-gated route on QA (e.g. `/admin` on `qa.aiqadam.org`) without being rejected by `SuperAdminGuard` (`apps/api/src/modules/rbac-sync/group-mapping.ts` in `aiqadam/ai-qadam-platform`, which does a live non-cached group-membership check).
  - Must report back to the user which of the 3 were added, which (if any) were blocked on "must sign in first," and the live verification result.
- **Information gaps for downstream steps:**
  - Current QA Authentik state is unconfirmed as of this writing: whether `aiqadam-super-admin` group exists on QA, and whether all 3 target emails already have user rows there. Landscape-reader (step 02) and/or the discovery phase of execution must establish this live — do not assume T-0126's prior session state still holds without a fresh `docker ps` check that `aiqadam-qa-authentik-server-1` is still running.
  - No long-lived QA Authentik API token is recorded in secrets-inventory.md — executor will need `docker exec` + `ak shell` access (or equivalent) rather than a bearer-token REST session.
  - Exact mechanism for the 3x group-assignment operation (script invocation vs. raw `ak shell` calls) is left to the executor's judgment per the task file — not yet decided.

## Issues / risks
- If any of the 3 emails do not yet have a QA Authentik user row (no prior OIDC sign-in), this task cannot complete for that person in this run; per the task file's explicit instruction this must escalate to the user rather than be worked around.
- The `aiqadam-super-admin` group may not yet exist on QA at all (unrelated to T-0126's scope) — first execution step must check and create if absent, which is a small structural change beyond pure data/group-membership edits and should be called out clearly at step 04 (solution-designer) even though the task file estimates `estimated_blast_radius: low` / `estimated_reversibility: full`.
- Prod (`https://auth.aiqadam.org`) must not be touched under any circumstances in this run — any accidental use of the wrong `AUTHENTIK_URL` value would be an out-of-scope, cross-environment mistake.

## Open questions (optional)
none — task is clear and unambiguous; proceeding with verdict PASS.
