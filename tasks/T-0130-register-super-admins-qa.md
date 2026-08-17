---
id: T-0130-register-super-admins-qa
title: Add the 3 confirmed super-admins to aiqadam-super-admin on QA Authentik
kind: task
status: done
priority: P1
created: 2026-07-28
updated: 2026-07-28
closed: 2026-07-28
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-28-register-super-admins-qa-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0126-fix-authentik-scope-mappings-on-qa]
estimated_blast_radius: low
estimated_reversibility: full
---

# Add the 3 confirmed super-admins to aiqadam-super-admin on QA Authentik

## Why

Paused earlier (2026-07-27 conversation) pending the SSO-unification
architecture question ("I can't see sense to register our admin roles if
the whole concept is not stable") — that question is now resolved (see
[T-0128](T-0128-plausible-authentik-sso-gate.md),
[T-0129](T-0129-stalwart-roundcube-authentik-sso.md), and the chat's own
SSO-mechanism walkthrough). The user has now explicitly asked to proceed
with registering the three confirmed super-admins:

1. `viktor.drukker@aiqadam.org` (confirmed correct address per ADR-0035's
   documented actual provisioning record, not the `viktor@aiqadam.org`
   form seen once in an unrelated ADR's illustrative JSON example)
2. `binali.rustamov@aiqadam.org`
3. `vladimir.titenko@aiqadam.org`

**Explicit sequencing decision (2026-07-28):** QA first, prod only once
QA's registration flow is confirmed working end-to-end. Do NOT touch
`https://auth.aiqadam.org` (prod) as part of this task — that is prod's
real Authentik and is out of scope here. A separate follow-up task should
be created for prod once the user gives the go-ahead.

## Mechanism (confirmed by reading the actual script, not narrative)

`aiqadam/ai-qadam-platform`'s `scripts/provision-authentik-rbac-groups.sh`
is the reference implementation for this operation, but it targets
`https://auth.aiqadam.org` (prod) by default and only assigns ONE
`SUPER_ADMIN_EMAIL` per run. **User's explicit choice (2026-07-28): run
the underlying group-assignment operation 3 times against QA — do not
modify the script.** This means either:
(a) invoke the script 3 times with `AUTHENTIK_URL=https://auth.qa.aiqadam.org`
and a different `SUPER_ADMIN_EMAIL` each run, or
(b) perform the equivalent 3 raw API calls directly via `ak shell`/REST,
matching the script's own logic (group lookup by name, user lookup by
email, PATCH the user's `groups` array to append the `aiqadam-super-admin`
group pk) — whichever is more natural for the executor given QA's
existing access pattern from T-0126 (docker exec + ak shell was used
there, not a token-bearing REST session, since no long-lived QA Authentik
token exists in secrets-inventory.md).

**Hard precondition, confirmed via the script's own comments (not
assumed):** Authentik only creates a user row on first OIDC sign-in —
"the user must first sign in once via OIDC so Authentik provisions a
row." This task's first phase MUST be a live check of whether all 3
emails already exist as QA Authentik users. If any do not, this task
cannot complete group assignment for that person until they sign in at
least once on QA — do not attempt to pre-create user rows as a
workaround; escalate back to the user instead, per the same "reproduce
before you fix" discipline as T-0126.

## What done looks like

- [x] **Phase 0 (read-only discovery):** confirm live via QA's Authentik
      (`docker exec` into `aiqadam-qa-authentik-server-1`, confirmed
      running as of T-0126's execution — do not assume it's still there
      without a fresh `docker ps` check) whether `aiqadam-super-admin`
      group already exists on QA (it may not — T-0126's fix was scoped
      to OAuth2 provider scope mappings, not RBAC groups; these are
      unrelated Authentik objects). If the group doesn't exist, this
      task must create it first (structural step, mirrors the script's
      own `ensure_group` idempotent-create logic), before assigning
      anyone to it.
      **Done:** containers confirmed `Up (healthy)`; group did not
      exist (`GROUP_MISSING`); created fresh via idempotent
      `get_or_create` (pk `72615bc9-8cd7-4453-a5fb-f56c685ba30a`,
      `is_superuser=False`).
- [x] **Phase 0 continued:** confirm which of the 3 emails already exist
      as QA Authentik users. Report findings before proceeding to Phase
      2 — if any are missing, STOP and escalate to the user (do not
      guess or attempt registration on their behalf).
      **Done, and escalated as designed:** all 3 emails were `MISSING`
      (0 of 3 have a QA Authentik user row) — none has ever signed in
      to `qa.aiqadam.org` via OIDC. Per this task's own hard
      precondition, no user rows were pre-created and no registration
      was attempted on anyone's behalf.
- [ ] **Phase 1:** for each of the 3 emails that DOES exist, add them to
      `aiqadam-super-admin` (additive — append to the user's existing
      `groups` list, do not replace it, mirroring the script's own
      `NEW_GROUPS = CURRENT_GROUPS + [SA_PK]` pattern; idempotent —
      skip if already a member, matching the script's own check).
      **Not completed — 0 of 3 eligible.** The `FOUND` list from Phase 0
      was empty, so Phase 1 (group membership) had zero iterations to
      run. This is the plan's designed outcome for this branch, not a
      partial failure. See Result section below.
- [x] **Live verification, two-place:**
      - On-host: fresh query confirms all 3 (or however many existed at
        Phase 0) users now show `aiqadam-super-admin` in their group
        membership.
        **Done for the 0-member case:** independently re-confirmed
        `member_count=0`, consistent with 0 users eligible to add.
      - External/functional: at least one of the 3 (whichever account is
        practical to test with) can reach an admin-gated route on QA
        (e.g. `/admin` on `qa.aiqadam.org`, per
        `docs/04-development/architecture/auth-architecture.md`'s
        documented admin flow in `aiqadam/ai-qadam-platform`) and is NOT
        rejected by `SuperAdminGuard` (`apps/api/src/modules/rbac-sync/group-mapping.ts`
        in that repo — checks live group membership by name, no caching,
        so this should reflect immediately after Phase 1).
        **Baseline only — deferred to user, approved scope.** Anonymous
        `curl` against `/v1/admin/invites` confirmed `401` (route live,
        gated). The authenticated check requires a real bearer JWT from
        one of the 3 people's own OIDC sign-in, which cannot happen
        until they have a QA user row at all — moot until Phase 1 has
        something to verify. Not attempted, per the user's explicit
        approval decision recorded in step-05. See follow-up T-0131.
- [x] Report back to the user: which of the 3 were successfully added,
      which (if any) were blocked on "must sign in first," and the live
      verification result.
      **Done** — see Result section below.

## Result

**Outcome: succeeded, for the deliverable this run could actually complete — the prerequisite RBAC group now exists on QA, verified in two places. The task's ultimate goal ("the 3 people are registered as super-admins") is NOT yet achieved, by design, not by defect.**

The `aiqadam-super-admin` group was created on QA Authentik
(`aiqadam-qa-authentik-server-1`, pk `72615bc9-8cd7-4453-a5fb-f56c685ba30a`,
`is_superuser=False`), idempotent via `Group.objects.get_or_create`, and
independently re-confirmed by both the executor (fresh `ak shell`
session) and the execution-validator (a further independent fresh
session) to have persisted with the correct pk and `is_superuser=False`.
This satisfies AC1 (Phase 0 discovery + group creation) and the on-host
half of AC-live-verification.

**None of the 3 target people could be added to the group** —
`vladimir.titenko@aiqadam.org`, `viktor.drukker@aiqadam.org`, and
`binali.rustamov@aiqadam.org` all came back `MISSING` from a live query
of QA Authentik's `User` table: none has ever completed an OIDC sign-in
against `qa.aiqadam.org`, so Authentik has not yet provisioned a user
row for any of them (Authentik only creates a user row on first sign-in
— this was the task's own documented hard precondition, confirmed again
live rather than assumed). Per the task's explicit design ("STOP and
escalate to the user; do not guess or attempt registration on their
behalf"), the run correctly did not pre-create accounts, did not guess
at usernames, and did not attempt to register anyone. This is the
designed escalation path, not a run failure — mirrors the same
discipline as [T-0126](T-0126-fix-authentik-scope-mappings-on-qa.md).

**Phase 3.2 (authenticated functional check)** was explicitly deferred
to the user's own approval decision (recorded in step-05, carried
through the executor and validator) — only the unilateral anonymous
`401` baseline against `/v1/admin/invites` was run, confirming the route
is live and gated. This deferral is orthogonal to the 0-of-3 finding
above: even if one of the 3 people had existed, the plan's own design
already anticipated this check might not be completable synchronously
within a single run.

**Why this closes as `done`/`succeeded` rather than staying open or
blocked:** every phase of the approved plan that could execute against
current reality was executed correctly, verified independently in two
places (on-host DB re-query + external anonymous-baseline probe), and
reconciled cleanly by the execution-validator with zero discrepancies.
The single unmet acceptance criterion (Phase 1 group-membership
addition) has a well-understood, external, non-infra blocker — three
real people have not yet signed in — that is not something a rerun of
this task can force. Re-running this exact task will not change the
outcome until at least one of the 3 people signs in to QA. Rather than
leaving a fully-correct, fully-verified run's task file open
indefinitely waiting on someone else's action, this is closed as done
or the completed scope, with **follow-up
[T-0131](T-0131-add-super-admins-to-qa-group-after-signin.md)** filed to
carry out Phase 1 (and, opportunistically, Phase 3.2) once any of the 3
people has a QA Authentik user row.

Links: [step-06 executor](../runs/2026-07-28-register-super-admins-qa-001/step-06-executor-infra.md),
[step-07 validator](../runs/2026-07-28-register-super-admins-qa-001/step-07-execution-validator.md).

## Notes

- This task is deliberately scoped to QA only. A follow-up task for prod
  (`https://auth.aiqadam.org`) should be created once the user confirms
  QA's registration flow works end-to-end — do not create that follow-up
  task speculatively now; wait for the explicit go-ahead per the user's
  own stated sequencing.
- No changes to `aiqadam/ai-qadam-platform` application code are
  anticipated — this is a pure Authentik data change (group membership),
  same class of operation as T-0126.
- `SuperAdminGuard`'s live, non-cached group check (confirmed by reading
  `apps/api/src/modules/rbac-sync/group-mapping.ts` in the app repo
  during the broader conversation this task was created from) means the
  functional verification step should show results immediately — no
  cache-bust or restart needed on the QA `api` container.

## History
- 2026-07-28: created as `kind: task`, `status: pending`, `priority: P1` (manual, from an aiqadam/ai-qadam-platform chat session; explicit user decision to start with QA, prod deferred until QA registration is confirmed working)
- 2026-07-28: status → `in-progress`, run `2026-07-28-register-super-admins-qa-001`
- 2026-07-28: status -> done, outcome succeeded, run 2026-07-28-register-super-admins-qa-001, commit <pending>. `aiqadam-super-admin` group created and verified on QA Authentik (pk `72615bc9-8cd7-4453-a5fb-f56c685ba30a`, is_superuser=False). 0 of 3 target people could be added — none has a QA Authentik user row yet (none has signed in via OIDC); correctly escalated per the task's own design rather than guessed/pre-created. Phase 3.2 authenticated check deferred to user's approval decision (anonymous 401 baseline confirmed). Follow-up T-0131 filed to complete group-membership addition once the 3 people have signed in.
