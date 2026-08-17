---
id: T-0131-add-super-admins-to-qa-group-after-signin
title: Add the 3 confirmed people to aiqadam-super-admin on QA once they have signed in
kind: task
status: in-progress
priority: P2
created: 2026-07-28
updated: 2026-07-28
closed:
outcome:
created_by: 2026-07-28-register-super-admins-qa-001
source_runs: [2026-07-28-register-super-admins-qa-001]
executed_by_runs: [2026-07-28-add-vladimir-super-admin-qa-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0130-register-super-admins-qa]
estimated_blast_radius: low
estimated_reversibility: full
---

# Add the 3 confirmed people to aiqadam-super-admin on QA once they have signed in

## Why

[T-0130](T-0130-register-super-admins-qa.md) created the
`aiqadam-super-admin` RBAC group on QA Authentik
(`aiqadam-qa-authentik-server-1`, pk `72615bc9-8cd7-4453-a5fb-f56c685ba30a`,
`is_superuser=False`) — this prerequisite infrastructure is done and
independently verified in two places (fresh on-host `ak shell` re-query
by both the executor and the execution-validator).

However, a live query at execution time found that **none of the 3
intended super-admins** — `vladimir.titenko@aiqadam.org`,
`viktor.drukker@aiqadam.org`, `binali.rustamov@aiqadam.org` — has a QA
Authentik `User` row yet. Authentik only provisions a user row on first
OIDC sign-in (confirmed via the reference script's own comments, and
reconfirmed live by this task, not assumed). Per T-0130's own explicit
design, the run correctly did not pre-create user rows or attempt
registration on anyone's behalf — it escalated instead.

This means the group-membership addition (the actual point of "register
these 3 as super-admins") has not happened yet, and cannot happen until
at least one of the 3 people signs in to `https://qa.aiqadam.org` at
least once. This task exists to track and complete that remaining work
once that precondition is met, rather than silently letting it drop now
that T-0130 is closed.

## What done looks like

**Current run scope:** this pending pass targets `vladimir.titenko@aiqadam.org`
only, per explicit user request on 2026-07-28. `viktor.drukker@aiqadam.org`
and `binali.rustamov@aiqadam.org` remain future incremental work under this
same task (see the original design below, which already supports
subset/incremental runs) — they are not part of this pass unless the user
separately confirms they have signed in and asks for them to be included.

- [x] Before running: check live whether any of the 3 emails now has a
      QA Authentik user row (`docker exec -i
      aiqadam-qa-authentik-server-1 ak shell -c "<query>"` — see
      T-0130's step-04 plan Phase 0.2 for the exact script; mirror the
      `ak shell -c` invocation method the executor used, not the
      original plan's interactive-stdin form, which was found to swallow
      multi-line print output). **Done 2026-07-28 (run
      2026-07-28-add-vladimir-super-admin-qa-001)** for
      `vladimir.titenko@aiqadam.org` only (this pass's scope) — found
      `USER_FOUND pk=14 is_active=True`. `viktor.drukker@aiqadam.org`
      and `binali.rustamov@aiqadam.org` were not queried by this run
      (out of its explicit scope) — still open for a future pass.
- [x] For each of the (up to 3) emails that now has a user row, add them
      to `aiqadam-super-admin` (additive `.groups.add()`, idempotent —
      skip if already a member). If fewer than 3 have signed in, add
      whichever subset is available; do not block on all 3 being ready
      simultaneously — this task can be re-run incrementally as each
      person signs in, or run once for whichever subset is ready.
      **Done for `vladimir.titenko@aiqadam.org` only** (2026-07-28,
      `already_member=False`, `member_count=1` after add). **Still
      open** for `viktor.drukker@aiqadam.org` and
      `binali.rustamov@aiqadam.org` — no QA Authentik user row confirmed
      for either as of this run (not checked, since they were out of
      this run's scope).
- [x] On-host live verification: fresh, independent `ak shell` session
      confirms `aiqadam-super-admin` group membership for every email
      processed in this task. **Done for the 1 email processed this
      run** (`vladimir.titenko@aiqadam.org`) — independently re-verified
      by both the executor (Phase 2.1) and the execution-validator
      (fresh session): `member_count=1`, `members=['vladimir.titenko@aiqadam.org']`,
      group `is_superuser=False` unchanged, user's own `is_superuser=False`,
      no other group memberships granted. **Still open** for the other
      2 emails (not processed this run).
- [ ] External/functional verification (T-0130's originally-deferred
      Phase 3.2): with cooperation from at least one of the added
      people, confirm a real bearer JWT from their live QA sign-in is
      NOT rejected by `SuperAdminGuard` on `/v1/admin/invites` (expect
      `200`, not `403 {"message":"not_super_admin"}`). Still deferred/
      best-effort — not completed by this run (anonymous baseline 401
      re-confirmed instead; does not by itself prove vladimir's
      authenticated access works).
- [x] Update `landscape/hosts/pro-data-tech-qa.md`'s RBAC-groups note to
      reflect the new member count and which people were added. **Done**
      (step 08 of this run) — RBAC-groups note, frontmatter
      `last_verified`/`last_verified_note`, and Change log updated to
      reflect 1 member (`vladimir.titenko@aiqadam.org`).
- [ ] If all 3 people have been added and verified, this task closes
      `done`. If only a subset has signed in by the time this is picked
      up, consider whether to close partially (documenting who remains)
      or leave open — user's call at execution time. **Decision (step 08,
      2026-07-28): left `in-progress`, not closed.** Only 1 of 3 named
      people is done; the task's own broader acceptance criteria
      (all-3 membership, and the deferred external/functional check)
      are not met. `in-progress` (rather than reverting to `pending`)
      was chosen because concrete, verified work has been completed and
      independently confirmed under this task, and the remaining work
      (`viktor.drukker@aiqadam.org`, `binali.rustamov@aiqadam.org`) is
      the same well-defined, ready-to-execute pattern — `pending` would
      understate progress already made and verified.

## Result

**Not closed — partial progress only, documented here per step 08's
diff-minimal update (this section normally stays empty until closed,
but the task's own checklist is now a mix of done/open items, so a
progress note is recorded to avoid re-deriving it from run history).**

Run [2026-07-28-add-vladimir-super-admin-qa-001](../runs/2026-07-28-add-vladimir-super-admin-qa-001/)
completed the scoped subset of this task for `vladimir.titenko@aiqadam.org`
only (per explicit user request narrowing this pass's scope — see History
below): a live check found he now has a QA Authentik user row (pk=14,
provisioned by his own OIDC sign-in since T-0130 ran earlier the same
day); he was added to `aiqadam-super-admin` (idempotent, additive
`g.users.add()`); the end state was independently re-verified twice (by
the run's own executor and by its execution-validator, in separate fresh
`ak shell` sessions) — group `member_count=1`, sole member
`vladimir.titenko@aiqadam.org`, `is_superuser=False` unchanged on both
the group and the user, no other group memberships granted. Anonymous
baseline probe on `/v1/admin/invites` re-confirmed `401`. See
[step-06 executor handoff](../runs/2026-07-28-add-vladimir-super-admin-qa-001/step-06-executor-infra.md)
and [step-07 execution-validator handoff](../runs/2026-07-28-add-vladimir-super-admin-qa-001/step-07-execution-validator.md)
for full detail.

Deviations from the original "What done looks like" checklist: none for
the in-scope item (vladimir) — it completed exactly as designed. The
checklist's external/functional verification item (Phase 3.2,
authenticated JWT check) remains deferred/best-effort as originally
anticipated, not a deviation. `viktor.drukker@aiqadam.org` and
`binali.rustamov@aiqadam.org` were intentionally not queried or touched
by this run (out of its explicit scope) and remain open work under this
same task.

## Notes

- Low urgency, low blast radius — the underlying group infrastructure
  already exists and is correctly empty (no incorrect grants have been
  made). This task is purely additive once its precondition (a
  sign-in) is met.
- No technical blocker on this repo's side — the blocker is external
  (three real people need to sign in to QA at least once). This task
  should likely be picked up opportunistically rather than scheduled,
  unless the user wants to proactively notify the 3 people to sign in
  sooner.
- Same operational pattern as T-0130: use `docker exec -i
  aiqadam-qa-authentik-server-1 ak shell -c "<code>"` (non-interactive
  form), not piped stdin to an interactive session — the interactive
  form's continuation-prompt echoing was found during T-0130's execution
  to swallow multi-line `print()` output.

## History
- 2026-07-28: created from 2026-07-28-register-super-admins-qa-001 (observation, filed by landscape-updater per T-0130's closure — group-membership addition for all 3 intended people deferred, not silently skipped, pending their first QA sign-in)
- 2026-07-28: promoted observation -> task, priority P2, by user; scope for this run narrowed to vladimir.titenko@aiqadam.org only (user's explicit request named only this email — the other 2 confirmed people remain future incremental work under this task, per its pre-existing subset/incremental-run design)
- 2026-07-28: status -> in-progress, run 2026-07-28-add-vladimir-super-admin-qa-001
- 2026-07-28: run 2026-07-28-add-vladimir-super-admin-qa-001 completed (step 07 verdict PASS) — vladimir.titenko@aiqadam.org added to aiqadam-super-admin and independently re-verified; status remains in-progress (2 of 3 named people — viktor.drukker@aiqadam.org, binali.rustamov@aiqadam.org — still unaddressed, no QA Authentik user row confirmed for either); task stays open, not closed
