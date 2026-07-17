---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-14T00:00:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - shared/app-registry.md
artifacts_changed: []
next_step_hint: task-validator and solution-designer should treat the AllowGroups sshusers constraint as the central design fork -- a new deploy user must either be added to sshusers or the sshd drop-in needs a second AllowGroups entry (e.g. "AllowGroups sshusers deploy"), and this is an edit to a project-managed drop-in file on both hosts, not merely a useradd. No deploy user, no deploy-named SSH key, and no host-specific sudoers drop-in for a deploy user exist on either host today.
---

## Summary
Both `pro-data-tech-qa` (95.46.211.230) and `pro-data-tech-prod` (95.46.211.224) are Ubuntu 26.04 hosts with an identical hardening baseline: sshd is locked to key-only auth via two project-managed drop-ins (`40-disable-password.conf`, `40-ai-dala-infra.conf`) under `/etc/ssh/sshd_config.d/`, with `PermitRootLogin prohibit-password` and, critically, `AllowGroups sshusers` — only members of the `sshusers` group (currently `root`, `tvolodi`, `viktor_d`, `binali_r` on both hosts) can pass SSH authentication at all, regardless of a valid key. Operator accounts follow a consistent per-user sudoers drop-in pattern (`/etc/sudoers.d/90-<user>`, mode 0440, `<user> ALL=(ALL) NOPASSWD: ALL`). No `deploy` user, no `deploy`-named SSH key, and no deploy-specific sudoers drop-in exist on either host — confirmed by full-text review of both landscape files (only match for "deploy" is the QA host's own task title, "…-deploy-infra-…"). The two app checkouts are at `/opt/apps/aiqadam-qa/` and `/opt/apps/aiqadam-prod/`, both git checkouts of `aiqadam/ai-qadam-platform` at commit `dfd2a7c`; the landscape documents the `.env` file ownership/mode under each (`mode 600`) but does **not** record the checkout directory's own owner/mode on either host — this is a gap solution-designer must have the executor confirm live before deciding whether a new `deploy` user needs `chown`/ACL changes or can simply be added to an existing group with read/write access.

## Details
### Relevant facts (sourced from landscape)

**Users, groups, sudoers (both hosts, same convention):**
- `sshusers` group gates all SSH auth via `AllowGroups sshusers` in `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf`. Members on both hosts today: `root`, `tvolodi`, `viktor_d`, `binali_r` — no others. — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/hosts/pro-data-tech-prod.md`_
- Operator accounts `tvolodi`/`viktor_d`/`binali_r` exist on both hosts, each password-locked (key-only), in `sudo` + `sshusers` groups, with NOPASSWD sudo via `/etc/sudoers.d/90-<user>` (mode 0440, owner root:root, content `<user> ALL=(ALL) NOPASSWD: ALL`), `visudo -c` clean. — _source: `landscape/hosts/pro-data-tech-qa.md` § Operator users, `landscape/hosts/pro-data-tech-prod.md` § Operator users_
- On `pro-data-tech-prod`, `tvolodi` is additionally in the `docker` group (gid 986); `viktor_d`/`binali_r` are not documented as being in `docker` on either host. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- On `pro-data-tech-qa`, all three operators (`tvolodi`, `viktor_d`, `binali_r`) are in the `docker` group (gid 986). — _source: `landscape/hosts/pro-data-tech-qa.md` § AI Qadam QA stack_
- Root is a **permanent** member of `sshusers` on both hosts (break-glass, governed by `PermitRootLogin prohibit-password`, not by group membership) — this is a stated, deliberate decision, not a gap. — _source: both host files_

**sshd config (identical pattern, both hosts):**
- Drop-ins under `/etc/ssh/sshd_config.d/`, three files, first-wins lexicographic order: `40-disable-password.conf`, `40-ai-dala-infra.conf` (project-managed, contains `AllowGroups sshusers` among other directives), `60-cloudimg-settings.conf` (cloud-init default, superseded). — _source: both host files_
- Effective sshd config: `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `PubkeyAuthentication yes`, `AllowGroups sshusers`, `MaxAuthTries 3`, hardened KexAlgorithms/Ciphers/MACs (no SHA-1/CBC/3DES/RC4). — _source: both host files_
- **This is the central design constraint**: any new SSH-only `deploy` user will fail authentication entirely unless (a) added to the existing `sshusers` group, or (b) the `AllowGroups` directive is edited to admit a second group (e.g. `AllowGroups sshusers deploy`). Both options require editing a project-managed drop-in file (`40-ai-dala-infra.conf`) — this is a real, host-side sshd config change on both hosts, not just a `useradd`/`authorized_keys` operation.

**App checkout paths and what IS documented about them:**
- QA: `/opt/apps/aiqadam-qa/` — git HEAD `dfd2a7c`, Compose project `aiqadam-qa`, Compose file `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml`, env file `/opt/apps/aiqadam-qa/deploy/.env` (mode 600 — owner not stated for this specific file, unlike the legacy `/var/www/ai-qadam-test/.env` which is explicitly `tvolodi:tvolodi`). — _source: `landscape/hosts/pro-data-tech-qa.md`, `shared/app-registry.md`_
- Prod: `/opt/apps/aiqadam-prod/` — git HEAD `dfd2a7c` (pinned, detached HEAD), Compose project `aiqadam-prod`, Compose file `/opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml`, env file `/opt/apps/aiqadam-prod/deploy/.env` (mode 600, owner `tvolodi:tvolodi` — explicitly stated). — _source: `landscape/hosts/pro-data-tech-prod.md`, `shared/app-registry.md`_
- **Gap:** neither host file nor `shared/app-registry.md` states the owner/group/mode of the checkout directory itself (`/opt/apps/aiqadam-qa/` or `/opt/apps/aiqadam-prod/`) — only the `.env` file inside `deploy/` is documented, and only for prod. This must be confirmed live before the solution-designer can decide the deploy user's group membership / ACL needs for `git pull` and `docker compose up` to succeed without sudo.
- Both apps run `network_mode: host` Compose stacks; `tvolodi` is confirmed in the `docker` group on both hosts, which is the model a new `deploy` user would need to replicate (membership in `docker` group) to run `docker compose` without sudo.
- Prod host also runs a live, pre-existing Penpot stack at `/opt/penpot/` (7 containers) — completely separate directory tree from `/opt/apps/aiqadam-prod/`; task file itself already flags this must not be touched by any deploy-user/docker-group work.

**No existing `deploy` user / conflicting key names (confirmed, not assumed):**
- Full-text scan of both host landscape files for "deploy" finds no `deploy` user, no `deploy`-named SSH key, and no `deploy`-specific sudoers drop-in on either host — the only match on the QA host file is the unrelated task-title substring "…-deploy-infra-…" (T-0110's own name). Local-users enumeration on both hosts lists exactly: `root`, `tvolodi`, `viktor_d`, `binali_r`, `nobody` — no fifth account. — _source: both host files § Access_
- This is landscape-level confirmation only (last verified at the dates below) — solution-designer/executor should still do a live `getent passwd deploy` / `id deploy` check on both hosts before creating the account, per standard idempotency practice, since a few days have passed since last verification.

**Secrets inventory conventions (relevant to item 5 of the task's acceptance criteria):**
- Existing entries follow a `<app>-<env>-<purpose>` naming convention (e.g. `aiqadam-qa-jwt-signing-secret`, `aiqadam-prod-postgres-password`), each row stating description + "where stored" (host path or `credentials.md`), never the value itself. The task's proposed names `aiqadam-qa-deploy-ssh-key` / `aiqadam-prod-deploy-ssh-key` fit this convention directly. — _source: `landscape/secrets-inventory.md`_
- This file is git-ignored; the copy read here is the working-tree version, consistent with the project's hard rule that secret values never enter the repo.

### Stale or stub files encountered
- `landscape/hosts/pro-data-tech-qa.md` — `last_verified: 2026-07-13`, `status: populated`. 1 day old as of today (2026-07-14) — not stale.
- `landscape/hosts/pro-data-tech-prod.md` — `last_verified: 2026-07-13`, `status: hardened`. 1 day old as of today (2026-07-14) — not stale.
- `landscape/secrets-inventory.md` — no frontmatter/`last_verified` date (this file is a plain key registry, not a dated landscape doc) — not flagged as stale, but note it is a live-maintained index, not snapshotted at a point in time.
- `shared/app-registry.md` — `last_updated: 2026-07-13`. 1 day old — not stale.
- None of the four inputs are stubs; all are populated with current, detailed state.

### Gaps requiring live discovery
- **Ownership/mode of the checkout directories themselves** — `/opt/apps/aiqadam-qa/` and `/opt/apps/aiqadam-prod/` (not just the `.env` files inside `deploy/`). Needed to decide whether the new `deploy` user needs group co-ownership, an ACL grant, or whether adding it to an existing group (e.g. `docker`, or a group matching the checkout owner) suffices for passwordless `git pull` + `docker compose up`.
- **Live confirmation that no `deploy` user, `deploy` group, or `/home/deploy/.ssh/authorized_keys` exists on either host right now** — landscape says no, but a same-day live check (`getent passwd deploy; getent group deploy; id deploy`) is standard due diligence before creating the account, since a few days may have passed and the landscape is a point-in-time snapshot.
- **Git remote credential path for `git pull`** — neither host file states how the existing checkout authenticates to `https://github.com/aiqadam/ai-qadam-platform.git` for pulls (public repo assumed, given `https://` clone URL and no credential-helper mentioned, but not explicitly confirmed either way). Solution-designer should have this confirmed live or flag it as an assumption in the plan.
- **Exact current `docker` group GID/membership state for a would-be `deploy` user** — GID 986 is documented as the `docker` group on both hosts consistently, so this is likely low-risk, but worth a live `getent group docker` check at execution time rather than assuming.

## Issues / risks
- The `AllowGroups sshusers` constraint is the single biggest design fork for this task: solution-designer must explicitly choose and justify one of (a) add `deploy` to the existing `sshusers` group, or (b) extend `AllowGroups` to a second group — both require editing the project-managed sshd drop-in `40-ai-dala-infra.conf` on both hosts, which is a higher-blast-radius touch than the task's own frontmatter (`estimated_blast_radius: medium`) may have anticipated if read as "just add a user." This should be called out explicitly to the task-validator/solution-designer, not silently resolved.
- If the forced-command `authorized_keys` restriction option (task's own recommendation) is chosen instead of a general shell login, the `AllowGroups` question still applies identically — forced-command restricts what the key can *run*, not whether the *user* can authenticate at all, so the group-membership fork is orthogonal to and does not resolve the sshd constraint above.
- No documented owner/mode for the two checkout directories is a real gap that could block the solution-designer from specifying exact `chown`/`usermod -aG` commands with confidence; recommend the executor's plan include a live `stat`/`ls -la` check as its first verification step before any mutating command.
- Prod host carries a live Penpot workload in a sibling directory (`/opt/penpot/`); any group-membership or docker-socket-adjacent change for the new `deploy` user must be scoped narrowly enough to avoid incidentally granting it access to Penpot's containers/volumes (both stacks share the same Docker daemon under `network_mode: host`).

## Open questions (optional)
none — landscape is sufficiently populated for step 03/04 to proceed; the identified gaps are live-discovery items for the solution-designer's plan / the executor's pre-flight checks, not blockers to reading the landscape itself.
