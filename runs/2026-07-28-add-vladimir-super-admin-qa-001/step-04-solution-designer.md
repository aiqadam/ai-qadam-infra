---
run_id: 2026-07-28-add-vladimir-super-admin-qa-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-07-28T05:55:00Z
task_id: T-0131-add-super-admins-to-qa-group-after-signin
inputs_read:
  - runs/2026-07-28-add-vladimir-super-admin-qa-001/step-01-task-reader.md
  - runs/2026-07-28-add-vladimir-super-admin-qa-001/step-02-landscape-reader.md
  - runs/2026-07-28-add-vladimir-super-admin-qa-001/step-03-task-validator.md
  - tasks/T-0131-add-super-admins-to-qa-group-after-signin.md
  - landscape/hosts/pro-data-tech-qa.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-07-28-register-super-admins-qa-001/step-06-executor-infra.md
artifacts_changed: []
next_step_hint: verdict is PASS — orchestrator should skip step 05 and advance directly to executor-infra (step 06). Executor must run Phase 0 first and branch strictly on its live result; if Branch B (no user row) is hit, executor stops after Phase 0 and reports BLOCKED-equivalent escalation rather than attempting Phase 1 or treating it as a failure.
---

## Summary
Plan to (Phase 0) live-check via non-interactive `ak shell -c` whether `vladimir.titenko@aiqadam.org` now has a QA Authentik `User` row, and only if so (Branch A) idempotently add him to the existing `aiqadam-super-admin` group (pk `72615bc9-8cd7-4453-a5fb-f56c685ba30a`) on `aiqadam-qa-authentik-server-1`, re-verify independently on-host, and update the landscape; if no row exists (Branch B), the run ends in escalation with no mutation attempted.

## Details

### Plan

**Phase 0 — Live discovery (must run first, read-only, no mutation)**

0.1. Confirm the Authentik containers are healthy (cheap precondition check):
   - Command: `ssh pro-data-tech-qa "docker ps --filter name=aiqadam-qa-authentik --format '{{.Names}}\t{{.Image}}\t{{.Status}}'"`
   - Verification: both `aiqadam-qa-authentik-server-1` and `aiqadam-qa-authentik-worker-1` listed as `Up ... (healthy)`. If not, stop and report BLOCKED (infrastructure precondition failure, not this task's fault).

0.2. Check whether `vladimir.titenko@aiqadam.org` has a QA Authentik `User` row (non-interactive `-c` form — required; the interactive piped-stdin form was confirmed in T-0126/T-0130 to swallow multi-line `print()` output):
   - Command:
     ```
     ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell -c \"from authentik.core.models import User; u = User.objects.filter(email='vladimir.titenko@aiqadam.org').first(); print(f'USER_FOUND pk={u.pk} is_active={u.is_active}') if u else print('USER_MISSING')\""
     ```
   - Verification: stdout is exactly one line, either `USER_FOUND pk=<pk> is_active=<bool>` or `USER_MISSING`. Exit code 0 in both cases (this is a query, not an error state).
   - **Decision point:** this single line of output determines which branch runs next. Do not proceed to Phase 1 unless output is `USER_FOUND ...`.

0.3. Re-confirm the target group's pk and flags live (do not hardcode blindly, per landscape-reader's note — cheap, read-only, always safe to run regardless of branch):
   - Command:
     ```
     ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell -c \"from authentik.core.models import Group; g = Group.objects.get(name='aiqadam-super-admin'); print(f'GROUP pk={g.pk} is_superuser={g.is_superuser}')\""
     ```
   - Verification: output is `GROUP pk=72615bc9-8cd7-4453-a5fb-f56c685ba30a is_superuser=False`, matching the landscape record. If the pk differs or the group is missing, stop and report BLOCKED — this would mean T-0130's group was altered or removed out-of-band, which is outside this task's scope to fix silently.

---

**Branch A — Phase 0.2 returned `USER_FOUND` (user row exists)**

1.1. Idempotent additive group-add (append, do not replace existing group memberships; skip if already a member):
   - Command:
     ```
     ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell -c \"from authentik.core.models import User, Group; u = User.objects.get(email='vladimir.titenko@aiqadam.org'); g = Group.objects.get(name='aiqadam-super-admin'); already = g.users.filter(pk=u.pk).exists(); g.users.add(u) if not already else None; print(f'ADD_RESULT user_pk={u.pk} group_pk={g.pk} already_member={already} member_count={g.users.count()}')\""
     ```
   - Why this is idempotent and additive: `g.users.add(u)` is Django's M2M `add()`, which is a no-op if the relation already exists and never touches any other membership row belonging to `u` or to `g`. The `already` pre-check is only for accurate reporting (so re-running the whole plan twice produces the same end state and the same class of output, satisfying the workflow's idempotency rule) — it does not gate correctness, since `add()` alone is already safe to re-run.
   - Verification: stdout line shows `member_count=1` (or higher, if run after an out-of-band change) and `already_member=False` on first run (or `True` on any re-run — both are correct, non-error outcomes).

**Branch B — Phase 0.2 returned `USER_MISSING` (no user row)**

1.1 (Branch B only). No further host mutation is attempted. Do not pre-create a `User` row, do not attempt registration/invitation on vladimir's behalf, and do not touch the group. This branch ends the run's execution with an escalation outcome: the executor (step 06) should report this as a blocked/deferred precondition — mirroring T-0130's prior correct behavior for all 3 emails — not as a FAIL. Steps 2–5 below do not run in this branch.

---

**Phase 2 — On-host verification (Branch A only, fresh independent `ak shell` session)**

2.1. Separate `ak shell -c` invocation (new container exec, not reusing 1.1's session) that only reads state:
   - Command:
     ```
     ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell -c \"from authentik.core.models import Group; g = Group.objects.get(name='aiqadam-super-admin'); print('VERIFY_GROUP', g.pk, 'is_superuser=', g.is_superuser, 'member_count=', g.users.count(), 'members=', list(g.users.values_list('email', flat=True)))\""
     ```
     (Note: `g.users` is the correct reverse accessor per T-0130's step-06 finding — `g.user_set` raised `AttributeError` there; do not repeat that mistake.)
   - Verification: `member_count=` is ≥1 and `members=` includes `'vladimir.titenko@aiqadam.org'`. `pk` and `is_superuser=False` match the values re-confirmed in Phase 0.3.

**Phase 3 — External/functional verification (Branch A only, best-effort, non-blocking)**

3.1. Unilateral baseline probe (always safe, no cooperation needed) — confirms the guarded endpoint is still live and still gated:
   - Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/v1/admin/invites"`
   - Verification: `401` (anonymous rejection baseline, matching T-0130's confirmed baseline). This does NOT prove vladimir's access works — it only confirms the route is still live/gated.

3.2. Authenticated check — **best-effort, explicitly deferred, not a blocking requirement of this plan.** Requires vladimir.titenko to sign in to `https://qa.aiqadam.org` live and supply his bearer JWT for a manual `curl -H "Authorization: Bearer <token>" https://qa.aiqadam.org/v1/admin/invites` check (expect `200`, not `403 {"message":"not_super_admin"}`). The executor must not wait, poll, or attempt to obtain this token by any other means. If not completed synchronously within this run, this is recorded as deferred, not as an incomplete/failed step — consistent with how T-0130 treated its own Phase 3.2.

**Phase 4 — Landscape update note (Branch A only, applied at step 08, not by this design)**

4.1. `landscape/hosts/pro-data-tech-qa.md`'s RBAC-groups note (in the `aiqadam-qa-authentik-server-1` container-table row and/or the host's `last_verified_note`) should be updated to state: `aiqadam-super-admin` now has 1 member (`vladimir.titenko@aiqadam.org`, added <date> via T-0131/this run); `viktor.drukker@aiqadam.org` and `binali.rustamov@aiqadam.org` remain without a QA Authentik user row / not yet added, tracked by the still-open T-0131. This is a landscape-updater (step 08) action, not performed by this plan directly.

### Rollback

- **Phase 0 (0.1–0.3):** read-only; no rollback needed.
- **Branch A, step 1.1 (group-add):** fully reversible. Rollback command (removes only vladimir's membership, leaves the group and all other members untouched):
  ```
  ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell -c \"from authentik.core.models import User, Group; u = User.objects.get(email='vladimir.titenko@aiqadam.org'); g = Group.objects.get(name='aiqadam-super-admin'); g.users.remove(u); print(f'ROLLBACK_DONE member_count={g.users.count()}')\""
  ```
  Trigger condition: run only if Phase 2 verification fails to show vladimir as a member (indicating 1.1 did not actually persist), or if the user explicitly requests reversal after the fact.
- **Branch B:** no mutation occurred; nothing to roll back.
- **Phase 2, 3.1:** read-only; no rollback needed.
- No backup file is required per workflow rule 2 ("backup before destructive changes") — this plan contains no file overwrite and no data deletion; the only mutation is an additive M2M row insert on a group that was itself created empty and confirmed to have caused no prior grants (per T-0130). Rollback is a live inverse-command (`g.users.remove(u)`), not a file restore.

### Verification (for step 07)

- **On-host:**
  - Phase 0.2 output line captured in the execution log, showing which branch was taken and why.
  - If Branch A: Phase 2.1's independent `ak shell` session output showing `member_count>=1` and `vladimir.titenko@aiqadam.org` present in `members=`.
  - Group pk in Phase 2.1's output matches `72615bc9-8cd7-4453-a5fb-f56c685ba30a` and `is_superuser=False` (unchanged from Phase 0.3 / T-0130).
- **External:**
  - Phase 3.1's `curl` baseline returns `401` for the anonymous request to `/v1/admin/invites` (confirms the endpoint remains live and gated; does not by itself confirm vladimir's access).
  - Phase 3.2 (authenticated `200` check) is best-effort/deferred — execution-validator should not treat its absence as a verification failure, only note it as an open item if not completed.
- **If Branch B ran:** verification consists solely of confirming Phase 0.2's `USER_MISSING` output was captured correctly and that no Phase 1/2/3/4 commands were run — the execution-validator should confirm absence of any mutating command in the execution log for this run.

### Resources used
- Secrets (by name): none — no persisted Authentik admin credential exists for QA; access is entirely via host SSH (operator user `tvolodi`, already provisioned) + `ak shell` Django-shell mechanism.
- Files modified on host: none.
- Files modified in this repo (landscape/): [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) — RBAC-groups note update, to be applied at step 08, only if Branch A ran.
- External APIs called: `https://qa.aiqadam.org/v1/admin/invites` (unauthenticated baseline probe only, Phase 3.1).

### Estimated impact
- Downtime: none — no service restart, no config file change, no container recreate.
- Affected services: `aiqadam-qa-authentik-server-1` (one Postgres-backed `Group`-`User` M2M row, additive only, if Branch A runs).
- Reversibility: fully reversible (single inverse `g.users.remove(u)` command, does not touch the group or any other member).

## Issues / risks
- None high-severity. The only branch-selection risk (misreading which of `USER_FOUND`/`USER_MISSING` was returned) is mitigated by making Phase 0.2's exact one-line output the sole, explicit gate for whether Phase 1 runs at all — the executor must not proceed to Branch A's mutation without that literal string in hand.
- This run is scoped to `vladimir.titenko@aiqadam.org` only; `viktor.drukker@aiqadam.org` and `binali.rustamov@aiqadam.org` must not be queried, added, or reported on by this run's execution, per step-01's scope note. The Phase 0.2/1.1/2.1 queries above are all written to filter by vladimir's email specifically (not the 3-email list from T-0130's script) to keep blast radius bounded to this one person.
- Task T-0131 cannot close as `done` from this run even on full Branch-A success, since 2 of 3 named people remain unaddressed — step 08 should keep it `in-progress`, per step-01/03's note.

## Verdict rationale
`PASS` (auto-approved) — all conditions in `shared/approval-protocol.md` are met:
1. Task file's `estimated_blast_radius: low` — confirmed.
2. Task file's `estimated_reversibility: full` — confirmed, and the plan's own rollback step demonstrates this concretely (single inverse command, no other side effects).
3. No irreversible steps: no data deletion, no credential rotation, no DNS change, no prod touch (QA only).
4. No designer doubts: the plan mirrors T-0130's identical, already-auto-approved mechanism (same group, same host, same container, same `ak shell -c` invocation pattern) with one additional guardrail (branch strictly gated on live Phase 0.2 output) and a tighter scope (single email, not 3).
5. No high-severity "Issues / risks" item — the two risk bullets above are process/scope-discipline notes already fully mitigated by the plan's own design, not open safety concerns.

This matches T-0130's own auto-approval precedent for the same group/host/mechanism.
