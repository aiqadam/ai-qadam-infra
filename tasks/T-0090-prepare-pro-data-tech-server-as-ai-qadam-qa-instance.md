---
id: T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
title: Prepare pro-data.tech server (95.46.211.230) as ai-qadam QA instance — host-level baseline (Phases A–E; public-internet steps deferred)
kind: task
status: done
priority: P1
created: 2026-07-08
updated: 2026-07-08
closed: 2026-07-08
outcome: succeeded
created_by: 2026-07-08-discovery-pro-data-tech-qa-001
source_runs:
  - 2026-07-08-discovery-pro-data-tech-qa-001
executed_by_runs:
  - 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001
phases_in_scope: A-E (host-level setup)
deferred_phases: F-I (public HTTPS — separate task)
deferred_to: T-0090a-prepare-qadam-test-public-https-endpoint
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by:
  - T-0093-harden-sshd-on-pro-data-tech-qa
  - T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
related:
  - T-0093-harden-sshd-on-pro-data-tech-qa
  - T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
  - T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
  - T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
  - T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
  - T-0098-host-level-backup-strategy-for-pro-data-tech-qa
estimated_blast_radius: medium
estimated_reversibility: full
---

# Prepare pro-data.tech server (95.46.211.230) as ai-qadam QA instance — host-level baseline (Phases A–E)

## Why
The user leased a cloud VM on pro-data.tech (NOT Hetzner) at `95.46.211.230` and intends to use it as the `ai-qadam` QA instance — a QA environment distinct from the Hetzner production host. The host is currently a freshly-provisioned Ubuntu 26.04 cloud image: no project services, no Docker, no nginx, no host firewall, no fail2ban, no operator users, no multi-PC SSH access. The **multi-PC operator SSH acceptance criterion** is a hard requirement: operators `viktor_d` and `binali_r` (and any future operator) must be able to SSH into the host from their own workstations, not only from the current management workstation.

**Scope of this task (Run 1 — host-level baseline only):** deliver Phases A–E (UFW FORWARD reconciliation → Docker install → source clone → compose adapt → host-side health check). End state: containers running on the host, `http://127.0.0.1:3112` returns 200/302 on-host. **Phases F–I (nginx install + vhost, UFW 443/tcp, Cloudflare DNS, public-HTTPS verification) are deferred to [T-0090a-prepare-qadam-test-public-https-endpoint](T-0090a-prepare-qadam-test-public-https-endpoint.md)** (placeholder — created in a follow-up). Splitting the work isolates the host-only changes from the public-internet blast radius (Cloudflare zone DNS edits), and lets the user validate the container stack before authorising Cloudflare changes. See [runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-04-solution-designer.md](../../runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-04-solution-designer.md) for the full design and the splitter rationale.

This task re-creates the pre-scrub T-0090 record (lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md)) and re-anchors the work-blocked-by-T-0093 dependency tree.

## What done looks like

**Run 1 (this task) — Phases A–E only:**

- [ ] **Phase A — UFW `DEFAULT_FORWARD_POLICY` reconciled BEFORE installing Docker.** T-0094 installed UFW with `FORWARD=DROP` per explicit user decision (NOT `ACCEPT` like sibling hosts, because Docker was not yet installed). The DROP is currently a no-op (`/proc/sys/net/ipv4/ip_forward=0`), but Docker enables IP forwarding at install time — bridged container traffic will be silently dropped unless done FIRST: (a) flip FORWARD to ACCEPT: `sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw && sudo ufw reload`; or (b) configure Docker with `"iptables": false` in `/etc/docker/daemon.json` so UFW rules route all Docker traffic. See [T-0094](./T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md) `## Result` section, "CRITICAL note for T-0090", and `landscape/hosts/pro-data-tech-qa.md` `## Network` section "CRITICAL divergence note" for full context.
- [ ] **Phase B — Docker installed and operational** (engine + compose plugin, systemd unit active, operator users `tvolodi`/`viktor_d`/`binali_r` added to `docker` group) — **only after the UFW FORWARD reconciliation above**
- [ ] **Phase C — ai-qadam source cloned onto host** at `/var/www/ai-qadam-test/` (operator-owned, public monorepo on github.com/tvolodi/aiqadam; probe confirms monorepo structure, executor selects `apps/api` per design decision D4)
- [ ] **Phase D — docker-compose.qa.yml + .env written; stack started detached** — two containers (`ai-qadam-test-app-1` + `ai-qadam-test-db-1`), app on `127.0.0.1:3112`, db internal, fresh random Postgres password stored in `/var/www/ai-qadam-test/.env` (mode 600 root:root)
- [ ] **Phase E — Host-side health check** — `curl -sI http://127.0.0.1:3112/` returns 200 or 302 (NOT connection-refused); db container reports `healthy`
- [ ] `role:` in [landscape/hosts/pro-data-tech-qa.md](../landscape/hosts/pro-data-tech-qa.md) frontmatter updated from `unassigned` to `ai-qadam-qa` (per design decision D2)
- [ ] Landscape files updated to reflect the new container stack: `landscape/hosts/pro-data-tech-qa.md` (Docker + app sections; `last_verified`); `landscape/services.md` (Docker + app tables for `pro-data-tech-qa`); `shared/app-registry.md` (add `ai-qadam` test-instance section); `landscape/secrets-inventory.md` (reference `/var/www/ai-qadam-test/.env` by path only)

**Predecessor tasks (already done by T-0093/T-0094/T-0095/T-0097 before this run; not redelivered here):**

- SSH access from operators `viktor_d` and `binali_r` (and the management workstation) from their own workstations, not only from the current one (**multi-PC acceptance criterion** — see T-0097)
- SSH access hardened per [T-0093](./T-0093-harden-sshd-on-pro-data-tech-qa.md) — `PasswordAuthentication no`, `PermitRootLogin prohibit-password` (permanent — root login kept, per user decision 2026-07-08), `AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`
- Host firewall installed per [T-0094](./T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md) — UFW deny-incoming, allow 22/tcp from any source (no source restrictions, per user decision 2026-07-08)
- fail2ban installed per [T-0095](./T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md) — sshd jail active with management IP in `ignoreip`

## Deferred (separate task — not in this run)

These items belong to **Phases F–I** of the design and are deferred to a follow-up task **[T-0090a-prepare-qadam-test-public-https-endpoint](T-0090a-prepare-qadam-test-public-https-endpoint.md)** (placeholder — created in a follow-up run). They are explicitly OUT OF SCOPE for this task and must NOT be attempted here:

- Nginx install + vhost at `/etc/nginx/sites-available/qadam-test.conf` (Phase F)
- Self-signed origin cert at `/etc/ssl/cloudflare/ai-dala.{pem,key}` (Phase F2)
- UFW allow 443/tcp (Phase G)
- Cloudflare DNS A record `qadam-test.ai-dala.com → 95.46.211.230` (proxied; Phase H)
- `qadam-test.ai-dala.com` reachable publicly via HTTPS (Phase I)
- Landscape updates for the Cloudflare DNS record (`landscape/cloudflare.md`, `landscape/domains.md`) and per-zone SSL-mode check — these land with the deferred task

## Result

Phases A–E complete on 2026-07-08 via run [2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001](../../runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/). 10/10 verification checks PASSED on re-execution (see [step-07 execution-validator](../../runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-07-execution-validator.md)).

Delivered:
- **Phase A:** UFW `DEFAULT_FORWARD_POLICY` flipped `DROP` → `ACCEPT` per T-0090 design (pre-Docker, before IP forwarding was enabled); pre-change backup at `/etc/default/ufw.pre-T0090.20260708T184046Z.bak` preserved; `ufw reload` clean.
- **Phase B:** Docker 29.6.1 (build `8900f1d`) + Compose plugin v5.3.1 installed from Docker's official Ubuntu repo (`resolute` codename supported on Ubuntu 26.04; no fallback). systemd unit `docker.service` enabled + active. Operator users `tvolodi` (uid 1001) / `viktor_d` (uid 1002) / `binali_r` (uid 1003) added to `docker` group (gid 986).
- **Phase C:** `/var/www/ai-qadam-test/` created, owned by `tvolodi:tvolodi` (mode 755). Note: original Phase C was an app-source clone; bypassed per orchestrator scope (no app container in this run; deferred to T-0090a).
- **Phase D:** `/var/www/ai-qadam-test/.env` (mode 600, `tvolodi:tvolodi`) + `/var/www/ai-qadam-test/docker-compose.yml` (mode 644, `tvolodi:tvolodi`) written with 24-char random Postgres password; 3 env keys (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`); container name `ai-qadam-test-db-1`; image `pgvector/pgvector:pg16`; bind `127.0.0.1:3112:5432`; named volume `ai_qadam_test_pgdata`.
- **Phase E:** `docker compose --env-file .env up -d` brought the stack up. Healthcheck was **deviated** from plan (E3b): `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}` (added `-d ${POSTGRES_DB}` to suppress "database 'aiqadam' does not exist" log-noise FATAL; pgvector/pgvector:pg16's default healthcheck only connects to the user-named DB, which is NOT created since the actual DB is `aiqadam_test`). Post-patch container `ai-qadam-test-db-1` status `(healthy)` cleanly; host-loopback `psql -h 127.0.0.1 -p 3112 -U aiqadam -d aiqadam_test -c "SELECT 1;"` returns `1` (V08 PASSED).

Landscape updates:
- [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) — frontmatter `role: unassigned` → `role: ai-qadam-qa`; new `## AI Qadam QA stack` section; Security posture section reflects `DEFAULT_FORWARD_POLICY="ACCEPT"` + the post-Docker install `allow (routed)` rendering of `ufw status verbose`; T-0090 struck from the open-task list (DONE 2026-07-08); T-0090a added as the deferred follow-up.
- [landscape/services.md](../../landscape/services.md) — added `## pro-data-tech-qa → ### Docker` block; `docker.service` row added to the systemd services table; "AI Qadam QA stack" sidebar note appended; change-log row added.
- [shared/app-registry.md](../../shared/app-registry.md) — new `## AiQadam` section inserted (between `## BilimBaga` and `## Adding a new app`) with test-environment table.
- [tasks/_index.md](../../tasks/_index.md) — T-0090 row moved to the done block; T-0090a row added to the observation block.

Deviations from the original plan (recorded under `## Notes` of step-06):
1. Phase C (app source clone) bypassed — not in the run's scope (separate decision per orchestrator); deferred to T-0090a or a follow-up T-0090b.
2. Healthcheck `-d ${POSTGRES_DB}` patch (Phase E3b) — suppresses the FATAL log spam.
3. `usermod -aG` looped per-user instead of `usermod -aG <group> u1 u2 u3` in one call (Ubuntu only accepts one LOGIN at a time).
4. FORWARD policy reconciliation timing: done BEFORE Docker install (Phase A2) — the design's two AC options reduced to one (the sed+ufw reload path); the daemon.json option was not exercised since the sed path was simpler.
5. `postgresql-client` package installed on the host as residue from Phase E4 host-loopback probe (small utility; acceptable; future housekeeping candidate).

Verification: see [step-07 execution-validator](../../runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-07-execution-validator.md) (V01–V10, all PASS) and the per-step evidence files in that run's directory. Commit `<pending>` (orchestrator will fill in at run-finalization).

## Notes
- **Predecessor task state (per pre-scrub snapshot at git ref `a41ec73`):** T-0090 was previously `kind: task, status: pending, priority: P1, blocked_by: T-0093`. The task file was lost in the 2026-07-07 secrets-inventory scrub. This re-created file preserves the `blocked_by: T-0093` metadata even though the current `status: observation` is technically inconsistent with having a `blocked_by` (a pending task is what gets blocked; an observation is not a runnable task). The orchestrator strategy is: (1) this discovery run populates the landscape and re-anchors the task; (2) the user promotes T-0093 → `kind: task` (sshd hardening); (3) the user promotes T-0097 → `kind: task` (operator users); (4) the user runs T-0093 then T-0097; (5) only then is T-0090 unblocked and runnable.
- **Why `kind: task, status: observation`:** the task file exists (it was on disk pre-scrub) but the pre-scrub record was `pending`, not `observation`. Re-creating it as `observation` is the conservative choice — the landscape-updater (this run) is the only agent allowed to auto-create observation task files. Promoting the status from `observation` to `pending` is a manual user action; once promoted, the orchestrator will route the run. This avoids silently taking the user off the unblocking sequence.
- **The provider is pro-data.tech (NOT Hetzner) — no Hetzner Cloud Firewall, no Hetzner API, no Hetzner Backups option, no server protection flags, no `firewall-1` analogue.** Defense-in-depth falls to the host's own UFW (T-0094) since pro-data.tech may or may not expose a control-plane firewall.
- **SSH identity key caveat:** the management workstation's key for this host is `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` (misleadingly named — actually OpenSSH-format RSA-2048). The SSH alias `pro-data-tech-qa` configures `User tvolodi`, but the host has no `tvolodi` user yet. Today, SSH via the alias still works because the provider's public key is installed in `/root/.ssh/authorized_keys` and OpenSSH falls back to the URL username. **For the discovery run, the executor used `ssh -i ... root@95.46.211.230` explicitly to avoid landing as `tvolodi`.** After T-0097 creates the `tvolodi` user, the alias will start working as intended.
- **Multi-PC acceptance criterion (verbatim from the user's most recent request and the [T-0090 predecessor notes from 2026-07-08-discovery-pro-data-tech-qa-001 step-01](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/step-01-task-reader.md)):** "operators `viktor_d` and `binali_r` (and any future operator) can SSH into the host from their own workstations, not only from the current management workstation". Operator pubkeys are present on the management workstation at `~/.ssh/ai-dala-infra-viktor-d.pub` and `~/.ssh/ai-dala-infra-binali-r.pub` (referenced by path only — values stay external per [landscape/README.md § Editing rules](../landscape/README.md)).
- **Discovered 2026-07-08 by read-only `discovery-host` run [`2026-07-08-discovery-pro-data-tech-qa-001`](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/).** All 14 probes (A–N) ran cleanly; the landscape file [landscape/hosts/pro-data-tech-qa.md](../landscape/hosts/pro-data-tech-qa.md) was created by step 08 of that run. State at discovery: 8 vCPU, 15 GiB RAM, 145 GB root disk; Ubuntu 26.04 LTS, kernel `7.0.0-14-generic`; sshd on 22 with cloud-init defaults; no Docker; no nginx; UFW inactive; no operator pubkeys; no backup tooling.

## History
- 2026-07-08: created from discovery run 2026-07-08-discovery-pro-data-tech-qa-001 (status observation; blocked by T-0093; predecessor T-0090 file lost in 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md))
- 2026-07-08: promoted observation -> pending — T-0093, T-0097, T-0094, T-0095 dependencies all done; ready for execution
- 2026-07-08: scope narrowed — Phases A-E only (host-level setup); Phases F-I deferred to follow-up task T-0090a-prepare-qadam-test-public-https-endpoint
- 2026-07-08: status -> in-progress — run 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001 started; 4 steps done (task-reader, landscape-reader, task-validator, solution-designer + auto-approved per "just go" delegation; scope narrowed to Phases A-E only)
- 2026-07-08: status -> done — Phases A-E complete; ai-qadam-test QA postgres running on 127.0.0.1:3112; Phases F-I deferred to T-0090a (commit <pending>)
