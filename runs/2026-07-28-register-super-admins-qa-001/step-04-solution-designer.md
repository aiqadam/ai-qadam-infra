---
run_id: 2026-07-28-register-super-admins-qa-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-28T00:00:00Z
task_id: T-0130-register-super-admins-qa
inputs_read:
  - runs/2026-07-28-register-super-admins-qa-001/step-01-task-reader.md
  - runs/2026-07-28-register-super-admins-qa-001/step-02-landscape-reader.md
  - runs/2026-07-28-register-super-admins-qa-001/step-03-task-validator.md
  - tasks/T-0130-register-super-admins-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
next_step_hint: Orchestrator must present this plan to the user for explicit APPROVE/REJECT/MODIFY before invoking executor-infra. Phase 0 (discovery) is read-only; Phase 1 (idempotent group-create) and Phase 2 (idempotent, additive group-membership append) are the state-changing parts. The plan branches per-person at Phase 0.2 (escalate rather than guess for any of the 3 emails missing a QA user row) exactly as the task file requires. Phase 3's external/functional check cannot be fully executed by the executor alone — it requires one of the 3 named people to complete an interactive sign-in — so the plan defines a fallback probe and flags this explicitly for the executor and validator.
---

## Summary
Create the `aiqadam-super-admin` group on QA Authentik if it does not already exist, then — for each of the 3 confirmed emails that already has a QA Authentik user row — append them to that group's membership via `docker exec -i aiqadam-qa-authentik-server-1 ak shell` (Django ORM, mirroring `scripts/provision-authentik-rbac-groups.sh`'s `ensure_group`/append logic), skipping and escalating (not guessing) for any email with no existing user row, then verify on-host via a fresh ORM query and externally via a live `/v1/admin/invites` probe against `SuperAdminGuard`.

## Details

### Plan

**Phase 0 — Read-only discovery (no state change). Hard gate before Phase 1.**

0.0. Confirm the QA Authentik containers are still running today (landscape's last confirmation is 2026-07-27, one day old; task file explicitly requires a fresh check, not an assumption).
   — command: `ssh pro-data-tech-qa "docker ps --filter name=aiqadam-qa-authentik --format '{{.Names}}\t{{.Image}}\t{{.Status}}'"`
   — verification: two lines returned, `aiqadam-qa-authentik-server-1` and `aiqadam-qa-authentik-worker-1`, both status containing `Up`. If either is missing or not `Up`, STOP — re-route to `BLOCKED`, do not attempt to start/repair the container under this task's identity (out of scope; would need its own task).

0.1. Check live whether the `aiqadam-super-admin` group already exists on QA Authentik.
   — command: `ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell"` with the following piped via stdin:
     ```python
     from authentik.core.models import Group
     g = Group.objects.filter(name="aiqadam-super-admin").first()
     if g:
         print(f"GROUP_EXISTS pk={g.pk} is_superuser={g.is_superuser}")
     else:
         print("GROUP_MISSING")
     ```
   — verification: output is either `GROUP_EXISTS pk=<uuid> is_superuser=<bool>` or `GROUP_MISSING`. Record verbatim. If it exists, also record `is_superuser` — expected `False` (this is the app-level RBAC group, not Authentik's own admin flag); if it is unexpectedly `True`, STOP and escalate to the user before proceeding (would mean the existing group was created with broader intent than this task assumes — do not silently reuse it).

0.2. Check live which of the 3 target emails already have QA Authentik user rows.
   — command: same `ak shell` session pattern, piped via stdin:
     ```python
     from authentik.core.models import User
     emails = ["vladimir.titenko@aiqadam.org", "viktor.drukker@aiqadam.org", "binali.rustamov@aiqadam.org"]
     found = list(User.objects.filter(email__in=emails).values_list("email", "pk", "is_active"))
     found_emails = {e for e, _, _ in found}
     missing = [e for e in emails if e not in found_emails]
     print("FOUND:", found)
     print("MISSING:", missing)
     ```
   — verification: output lists `FOUND` (email, pk, is_active tuples) and `MISSING` (emails with no user row). Record verbatim.

**Decision point (end of Phase 0):**
- If Phase 0.0 fails (containers not running): STOP, re-route to `BLOCKED`.
- If Phase 0.2 finds any of the 3 emails in `MISSING`: this is NOT a full-run blocker per the task file's own design — proceed with Phase 1/2 only for the emails found in `FOUND`, and report the `MISSING` ones back to the user as "must sign in to QA at least once before they can be added" rather than guessing, pre-creating a user row, or attempting registration on their behalf. If all 3 are missing, Phase 2 has nothing to do — still run Phase 1 (group must-exist is independent of user existence) and report all 3 as blocked.
- If Phase 0.2 finds a `FOUND` user with `is_active=False`: flag this explicitly in the report; still add them to the group per the task's literal instructions (group membership is independent of active status in Authentik's data model), but call out in the final report that an inactive account being a super-admin may need separate follow-up — do not silently skip without flagging.
- Otherwise: proceed to Phase 1 using the group pk (if found in 0.1) or "must create" (if `GROUP_MISSING`).

**Phase 1 — Ensure the `aiqadam-super-admin` group exists (idempotent create).**

1.1. If Phase 0.1 found `GROUP_MISSING`, create it — mirrors `scripts/provision-authentik-rbac-groups.sh`'s `ensure_group()` exactly: name only, `is_superuser=False`.
   — command: same `ak shell` session pattern, piped via stdin:
     ```python
     from authentik.core.models import Group
     g, created = Group.objects.get_or_create(name="aiqadam-super-admin", defaults={"is_superuser": False})
     print(f"GROUP_ENSURE pk={g.pk} created={created} is_superuser={g.is_superuser}")
     ```
   — verification: output shows `created=True` on first run (or `created=False` if a concurrent process created it between 0.1 and 1.1 — `get_or_create` handles that race safely, still idempotent). Record the pk — this is the pk used in Phase 2.
   — idempotency note: `get_or_create` is safe to re-run unconditionally; if Phase 0.1 already found the group, this step can be skipped entirely (use the pk already recorded) or re-run harmlessly (same output, `created=False`).

**Phase 2 — Add each existing user to the group (additive, idempotent, per-person).**

2.1. For each email in Phase 0.2's `FOUND` list, append the group to that user's `groups` if not already present. Run once per email (loop or 3 separate invocations — executor's choice), piped via stdin to a fresh or continued `ak shell` session:
     ```python
     from authentik.core.models import User, Group
     email = "<one of the FOUND emails>"
     sa = Group.objects.get(name="aiqadam-super-admin")
     u = User.objects.get(email=email)
     if sa in u.groups.all():
         print(f"ALREADY_MEMBER {email}")
     else:
         u.groups.add(sa)
         print(f"ADDED {email}")
     print("CURRENT_GROUPS", email, sorted(u.groups.values_list("name", flat=True)))
     ```
   — verification: output is either `ALREADY_MEMBER <email>` (no-op, already correct — idempotent skip) or `ADDED <email>` (state changed), followed by `CURRENT_GROUPS` showing `aiqadam-super-admin` present in the printed list alongside anything the user already had (nothing removed — `.add()` on a Django M2M is additive-only, matching the task's explicit requirement not to replace the list).
   — repeat for each of the (up to 3) `FOUND` emails, logging each invocation's output separately in the execution log.

**Phase 3 — Two-place verification (per workflow rule "Verify in two places").**

3.1. On-host: fresh, independent `ak shell` session (not reusing Phase 2's in-memory state) re-querying group membership for all processed emails.
   — command: piped via stdin:
     ```python
     from authentik.core.models import User
     emails = [<the FOUND emails processed in Phase 2>]
     for e in emails:
         u = User.objects.get(email=e)
         groups = sorted(u.groups.values_list("name", flat=True))
         print(e, "aiqadam-super-admin" in groups, groups)
     ```
   — verification: for every processed email, `True` appears as the second field (membership confirmed persisted independently of the write session).

3.2. External/functional: confirm `SuperAdminGuard` (`apps/api/src/modules/rbac-sync/../admin-invites/super-admin.guard.ts`, group literal `aiqadam-super-admin`) actually grants access to an admin-gated route on `qa.aiqadam.org` for one of the added accounts.
   — **Constraint discovered during design:** `SuperAdminGuard` runs after `AuthGuard` on `/v1/admin/invites` (`GET`/`POST`), which requires a full authenticated session (bearer JWT obtained via real OIDC sign-in) — the executor cannot mint this token unilaterally; it requires one of the 3 named people to sign in interactively via `https://qa.aiqadam.org`.
   — command (baseline, executor can run this unilaterally): `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/v1/admin/invites` — expect `401` (no token at all), confirming the route is live and gated, establishing a pre-change-equivalent baseline that the route itself works and rejects anonymous access.
   — command (authenticated check — requires one of the 3 people's cooperation, run by them or provided to the executor as a bearer token): `curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer <their JWT from a live qa.aiqadam.org sign-in>" https://qa.aiqadam.org/v1/admin/invites` — expect `200` (or `204`/empty-list JSON body), NOT `403 {"message":"not_super_admin"}`.
   — verification: if a bearer token from one of the 3 people is obtainable within this run, run the authenticated check and require `200`. If not obtainable (e.g. all 3 are unavailable to sign in synchronously during this run), this sub-step is marked **deferred** in the execution log — Phase 3.1's on-host DB check remains the authoritative verification for this run, and the report to the user must explicitly ask one of the 3 to sign in and confirm `/admin` access themselves as a follow-up, rather than the run silently treating Phase 3.1 alone as sufficient closure of the task's stated two-place verification requirement.

### Rollback

1. Rollback of Phase 2 (remove a specific email from the group) — only if a specific addition needs reverting (e.g. wrong person added by mistake), NOT a blanket rollback of all 3:
   — command: piped via stdin to `ak shell`:
     ```python
     from authentik.core.models import User, Group
     email = "<email to revert>"
     sa = Group.objects.get(name="aiqadam-super-admin")
     u = User.objects.get(email=email)
     u.groups.remove(sa)
     print(f"REMOVED {email}", sorted(u.groups.values_list("name", flat=True)))
     ```
   — this is symmetric with Phase 2's `.add()`, safe, and does not touch the other 2 people's membership or any other group the user belongs to.

2. Rollback of Phase 1 (group creation) — only relevant if the group was created fresh by this run AND needs to be fully undone (e.g. task is abandoned entirely before any real use):
   — command: piped via stdin to `ak shell`, only if Phase 1.1 logged `created=True` AND no other unrelated process/task has since relied on the group's existence:
     ```python
     from authentik.core.models import Group
     g = Group.objects.get(name="aiqadam-super-admin")
     assert g.user_set.count() == 0, "refusing to delete a non-empty group"
     g.delete()
     print("GROUP_DELETED")
     ```
   — the `assert` guards against deleting a group that already has members (from this run or otherwise) — if any member exists, this rollback step must not run; remove members individually via rollback step 1 first.
   — **Not expected to be needed in the normal case.** This is a defensive option, not a default action.

3. No rollback needed/possible for Phase 0 (read-only) or Phase 3 (read-only verification) — nothing changed.

4. Rollback trigger condition: only roll back if Phase 3.1's on-host verification shows unexpected state (e.g. a person was added who should not have been) or the user explicitly requests a revert after reviewing the report. Do NOT roll back merely because Phase 3.2's authenticated external check was deferred (see Phase 3.2 note) — that is a verification-completeness gap, not evidence the change itself is wrong.

### Verification (for step 07)

- **On-host:** fresh `ak shell` session — `User.objects.get(email=<each processed email>).groups.values_list("name", flat=True)` includes `aiqadam-super-admin` for every email that was in Phase 0.2's `FOUND` list. Also re-confirm `Group.objects.get(name="aiqadam-super-admin").is_superuser == False`.
- **External:** baseline `curl https://qa.aiqadam.org/v1/admin/invites` (no auth) → `401`. If a bearer token from one of the 3 people was obtained during execution, `curl` with that token → `200` (not `403 not_super_admin`). If no token was obtainable, execution-validator should note this as a deferred check and confirm the run's report to the user explicitly asks for this follow-up rather than treating it as silently satisfied.

### Resources used
- Secrets (by name): none. No stored credential is used — access is via SSH (operator key already on the management workstation, per `landscape/hosts/pro-data-tech-qa.md`) + `docker exec ... ak shell` (Authentik's own in-container Django ORM session, ephemeral, never persisted), same pattern as T-0126. No Authentik API token exists in `landscape/secrets-inventory.md` for QA and none is created by this plan.
- Files modified on host: none. No config file is edited. The only changes are database-backed object mutations inside Authentik's own Postgres-backed store (a `Group` row possibly created, and up to 3 `User`–`Group` M2M rows added), performed via Authentik's ORM inside its running container — identical resource class to T-0126's `property_mappings` change.
- Files modified in this repo (landscape/): `landscape/hosts/pro-data-tech-qa.md` — step 08 (landscape-updater) should add a note under the Authentik container's existing documentation recording that the `aiqadam-super-admin` RBAC group now exists on QA (pk, creation date, this run) and which of the 3 named people were added, mirroring the granularity of T-0126's existing entry for the OAuth2 provider's scope mappings.
- External APIs called: none from the executor's own credentials. The Phase 3.2 authenticated probe, if performed, uses a bearer token supplied by one of the 3 named people from their own live sign-in — the executor does not sign in on anyone's behalf.

### Estimated impact
- Downtime: none. No container restart or recreate. Database object mutations only, on a running Authentik instance — existing sessions/tokens for all other users are unaffected.
- Affected services: QA Authentik's RBAC group directory (`aiqadam-super-admin` group), and — for the up-to-3 people actually added — their authorization outcome when calling `SuperAdminGuard`-gated routes (`/v1/admin/*`) on `qa.aiqadam.org`. No other QA service, no prod service, no other user's access is touched.
- Reversibility: fully reversible. Group-membership addition is undone by `.remove()` (Phase-rollback 1); group creation (if this run created it) is undone by `.delete()` guarded against non-empty state (Phase-rollback 2). No data is deleted destructively, no file is overwritten, no credential is rotated.

## Issues / risks

- **MEDIUM — Group may not exist yet; this run may create new RBAC infrastructure, not just add data to an existing record.** Per step-01/02/03, there is zero landscape record of this group on QA. Phase 1 handles this as a small, additive structural step (mirrors the reference script's own idempotent `ensure_group` logic exactly), but it is a qualitatively different action from "just append to a list" — flagging per this step's own instructions even though it does not, on its own, push this plan to a blast radius the task file didn't already anticipate.
- **MEDIUM — Phase 0.2 may find one or more of the 3 emails missing a QA user row**, in which case this run cannot complete group assignment for that person (by explicit task-file design: escalate, don't guess/pre-create). This is an expected, designed-for branch, not a plan defect — but it means the run's outcome for up to all 3 people could be "blocked, ask them to sign in first," which the user should understand going in as a plausible result, not a certainty of full completion.
- **MEDIUM — Phase 3.2 (functional/external verification) cannot be fully executed unilaterally by the executor.** `SuperAdminGuard` sits behind `AuthGuard`, which requires a real bearer JWT from an actual OIDC sign-in by one of the 3 named people — the executor has no mechanism to obtain this on their behalf (and should not attempt to, e.g. by using someone else's session or a service credential — this would be its own security concern, not a shortcut). The plan provides a baseline anonymous-401 check the executor can run alone, but the task's own two-place verification requirement is only fully satisfied once one of the 3 people cooperates with an interactive sign-in test, which may not happen synchronously within this run. This is the primary reason for `NEEDS_APPROVAL` rather than `PASS`: I have a genuine, not-fully-resolved gap in how the second verification place gets satisfied within a single automated run, and per `shared/approval-protocol.md` any doubt about the plan requires `NEEDS_APPROVAL`.
- **LOW — `ak shell` is a broad-privilege mechanism** (full Django ORM access inside the Authentik container), same as T-0126's precedent. The plan bounds its use strictly to the Group/User queries and mutations listed above — the executor must not run any other ORM operation in that shell.
- **LOW — This touches real people's live admin access,** even though the target is QA (not prod) and the task file rates it `estimated_blast_radius: low` / `estimated_reversibility: full`. Given the change grants elevated (`aiqadam-super-admin`) capability to 3 real individuals' accounts, and per this step's own instruction to weigh "touches real people's admin access on a live system" carefully even on QA, I am treating this as warranting a human's eyes before execution rather than leaning solely on the task file's low/full labels.

## Verdict rationale

This plan is `NEEDS_APPROVAL`, not `PASS`, because:

1. Per `shared/approval-protocol.md` condition 4, `PASS` requires the designer to have **no doubts or open questions**. I have an unresolved design gap in Phase 3.2: the task's own workflow-mandated two-place verification cannot be fully executed by the executor alone within a single run, since it requires an interactive sign-in from one of three real people that this run cannot compel or simulate. That is a genuine doubt about how completion will be confirmed, not a cosmetic caveat.
2. Per `shared/approval-protocol.md`'s explicit list, "any operation the designer is uncertain about" always requires `NEEDS_APPROVAL` — this qualifies.
3. Although the task file rates `estimated_blast_radius: low` and `estimated_reversibility: full` (which this plan's design does not contradict — the change is additive, idempotent, and has a clean, tested rollback path), this run's own briefing explicitly asked me to judge risk given that "this touches real people's admin access on a live (albeit QA) system" — granting elevated app-level admin capability to 3 named individuals is a meaningful access-control change even in a non-prod environment, and I judge a human should see the exact plan (which emails, which group, which fallback for missing users) before it runs, rather than this being auto-approved purely on the task file's blast-radius label.
4. No irreversible step is present (satisfying condition 3 of the `PASS` criteria on its own), but conditions 1 and 4 are not met, so `PASS` is not available per the protocol's "ALL must hold" rule.

## Open questions (optional)
- Will any of the 3 named people be available to complete a live sign-in against `qa.aiqadam.org` synchronously during this run's execution window, to satisfy Phase 3.2's authenticated check? If not, the orchestrator/user should decide upfront whether Phase 3.1 (on-host DB verification) alone is accepted as sufficient for this run's closure, with Phase 3.2 explicitly logged as a follow-up ask to the 3 people rather than a blocking condition — recommend the user confirm this preference as part of approving this plan.
