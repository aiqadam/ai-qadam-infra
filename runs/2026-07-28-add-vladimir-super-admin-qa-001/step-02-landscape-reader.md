---
run_id: 2026-07-28-add-vladimir-super-admin-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-28T00:00:00Z
task_id: T-0131-add-super-admins-to-qa-group-after-signin
inputs_read:
  - runs/2026-07-28-add-vladimir-super-admin-qa-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - runs/2026-07-28-register-super-admins-qa-001/step-06-executor-infra.md (cross-reference only, for the ak shell invocation pattern)
artifacts_changed: []
next_step_hint: task-validator (step 03) can proceed directly to confirming this run's scope/feasibility; the first live action of the run (by executor or an earlier validating step) must be the non-interactive `ak shell -c "<python>"` query for vladimir.titenko@aiqadam.org's User row — no landscape file currently answers this, by design (it changes based on live sign-in activity).
---

## Summary
`pro-data-tech-qa` (95.46.211.230) runs the `aiqadam-qa` Docker Compose project (7 containers, host-networked), including `aiqadam-qa-authentik-server-1` (`ghcr.io/goauthentik/server:2024.12.3`), which is `Up (healthy)` as of the last discovery (2026-07-27, T-0126) and hosts QA's Authentik identity provider. The `aiqadam-super-admin` RBAC group was created on this Authentik instance by T-0130 today (2026-07-28): `pk=72615bc9-8cd7-4453-a5fb-f56c685ba30a`, `is_superuser=False` (an app-level RBAC group checked by `SuperAdminGuard`, not Authentik's own admin flag), created idempotently via `Group.objects.get_or_create`, currently documented with **0 members**. As of T-0130's live check, none of the 3 intended super-admins (including `vladimir.titenko@aiqadam.org`) had a QA Authentik `User` row — Authentik only provisions a user row on first OIDC sign-in to `qa.aiqadam.org`. That finding is now several hours old and must be re-checked live by this run, not assumed. The documented, twice-proven operational pattern for querying/mutating this Authentik instance is `docker exec -i aiqadam-qa-authentik-server-1 ak shell -c "<python>"` (non-interactive `-c` form) run over SSH as an operator in the `docker` group (e.g. `tvolodi`) — no persisted Authentik admin credential exists in `secrets-inventory.md` for QA; access is entirely via host SSH + this Django-shell mechanism.

## Details
### Relevant facts (sourced from landscape)
- Host: `pro-data-tech-qa`, IPv4 `95.46.211.230`, SSH as `root` (break-glass) or operator users `tvolodi`/`viktor_d`/`binali_r` (all in `sshusers` + `docker` groups, NOPASSWD sudo). SSH alias `pro-data-tech-qa` on the management workstation authenticates as `tvolodi`. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- The `aiqadam-qa` Compose project runs 7 containers: `aiqadam-qa-oidc-stub-1`, `aiqadam-qa-api-1`, `aiqadam-qa-web-next-1`, `aiqadam-qa-directus-1`, `aiqadam-qa-authentik-server-1`, `aiqadam-qa-authentik-worker-1`, `aiqadam-qa-redis-1` — confirmed 2026-07-27 (T-0126). — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`_
- `aiqadam-qa-authentik-server-1` (image `ghcr.io/goauthentik/server:2024.12.3`, `network_mode: host`, no published ports) status `Up (healthy)` as of the 2026-07-27 discovery. Admin/API reachable externally via nginx at `https://auth.qa.aiqadam.org`. Hosts OAuth2 provider `aiqadam-qa-provider` (pk=1, bound to Application `aiqadam-qa` / "AI Qadam Platform (QA)"), whose `property_mappings` include all three managed scope mappings (openid/email/profile) as of T-0126 (fixed a prior missing-email-claim 401). — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **Admin access mechanism (only documented one):** `docker exec -i aiqadam-qa-authentik-server-1 ak shell` (Django management shell) run by an operator in the `docker` group over SSH. No persisted Authentik admin credential exists in `secrets-inventory.md` for QA. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **RBAC groups note (verbatim, as of T-0130, 2026-07-28):** a project-level `aiqadam-super-admin` group exists (`pk=72615bc9-8cd7-4453-a5fb-f56c685ba30a`, `is_superuser=False`), created idempotently via `Group.objects.get_or_create`. Currently **0 members** — none of the 3 intended members (`vladimir.titenko@aiqadam.org`, `viktor.drukker@aiqadam.org`, `binali.rustamov@aiqadam.org`) has ever signed in to `qa.aiqadam.org` via OIDC, so none has a QA Authentik `User` row to add to the group. Two other groups exist on this instance, both pre-existing Authentik built-ins unrelated to this project: `authentik Admins`, `authentik Read-only`. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Change-log entry for T-0130 (2026-07-28, run `2026-07-28-register-super-admins-qa-001`) confirms the group creation was independently re-verified on-host, and that the "0 of 3 have a user row" finding was itself a live, confirmed result (not assumed) — the run correctly escalated rather than pre-creating user rows or guessing. — _source: `landscape/hosts/pro-data-tech-qa.md`_ (Change log table, last row)
- **Cross-referenced (not landscape, but corroborates the task's claim about the `ak shell` invocation form):** T-0130's own executor handoff (`runs/2026-07-28-register-super-admins-qa-001/step-06-executor-infra.md`) shows every phase (group-existence check, user-row check, group create, verification) was run via `ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell -c \"<python>\""` — the same non-interactive form named in this run's step-01/task, and the one this run should reuse. T-0126's executor handoff independently documents the interactive-stdin form swallowing multi-line `print()` output, which is why the non-interactive `-c` form is the required pattern.
- **Health/verification reference points** (for downstream criterion 4, best-effort/deferred): `GET https://qa.aiqadam.org/health` → 200; `SuperAdminGuard`-gated endpoint is `/v1/admin/invites`; T-0130 confirmed a baseline anonymous 401 (`{"message":"not_super_admin"}` expected shape) on this endpoint pre-group-add. — _source: `landscape/hosts/pro-data-tech-qa.md`_ (T-0130 change-log entry)
- Task file's own "Why" section (quoted in step-01 handoff) states Authentik user-row provisioning is confirmed via the reference script's own comments and reconfirmed live by T-0130 — not merely assumed. — _source: `runs/2026-07-28-add-vladimir-super-admin-qa-001/step-01-task-reader.md`_
- No Cloudflare/DNS involvement for this task — `pro-data-tech-qa` is not behind Cloudflare; irrelevant to this run. — _source: `landscape/hosts/pro-data-tech-qa.md`_ (Network section)
- `secrets-inventory.md` has no Authentik admin credential entries for QA at all (only JWT signing secret, internal API token, and CI deploy key are listed under "AiQadam QA — pro-data-tech-qa") — consistent with the `ak shell`-only access model; nothing to reference by name for this task. — _source: `landscape/secrets-inventory.md`_

### Stale or stub files encountered
- None. `landscape/hosts/pro-data-tech-qa.md` frontmatter `last_verified: 2026-07-28` (today) — current. `landscape/services.md` frontmatter `last_verified: 2026-07-27` — one day old, well within the 30-day staleness threshold, and its `aiqadam-qa` container table matches the host file. `landscape/secrets-inventory.md` has no `last_verified` frontmatter field (it's a git-ignored reference table, not a dated landscape record) — not flagged as stale, just noted as a different kind of file.

### Gaps requiring live discovery
- **The hard precondition itself:** whether `vladimir.titenko@aiqadam.org` now has a QA Authentik `User` row. This is inherently a live fact (it changes the moment he signs in) and cannot be answered from any landscape file — the landscape only documents the state as of T-0130 (0 of 3, several hours stale by task design). This must be checked fresh via `ak shell -c "<python>"` as the run's first live action.
- Exact current membership count/roster of `aiqadam-super-admin` beyond "0 members as of T-0130" is not otherwise available except by live query — landscape does not track group membership deltas outside of task-driven updates.
- No landscape fact establishes *when* (if ever) vladimir.titenko might have signed in since T-0130 ran earlier today — purely a live-state question.

## Issues / risks
- The landscape's "0 members" / "no user row" statement for `aiqadam-super-admin` and vladimir.titenko is time-stamped to T-0130 (earlier today, 2026-07-28) and is explicitly expected to be stale for the purposes of this run — this is not a landscape defect, it is the exact gap T-0131 exists to re-check. Downstream steps must not treat the landscape's "0 members" note as still authoritative; it must be re-verified live before any group-add is attempted.
- Group pk `72615bc9-8cd7-4453-a5fb-f56c685ba30a` and `is_superuser=False` are load-bearing identifiers for the mutation the executor will eventually run — both are corroborated identically in `landscape/hosts/pro-data-tech-qa.md`'s RBAC-groups note and its Change log, and independently in T-0130's own step-06/07 handoffs, so confidence is high, but the executor should still re-confirm the pk live (via `Group.objects.get(name='aiqadam-super-admin')` or equivalent) rather than hardcode it blindly, per the same non-interactive `ak shell -c` pattern.
- No contradiction found between the task's assumptions (step-01) and the landscape's documented state — the two agree on the group pk, group properties, container name, and the "escalate rather than guess" behavior established by T-0130.

## Open questions (optional)
none — landscape is current and sufficient for the task-validator and solution-designer to proceed; the only remaining unknown (vladimir's live user-row status) is by design a live-discovery item, not a landscape gap.
