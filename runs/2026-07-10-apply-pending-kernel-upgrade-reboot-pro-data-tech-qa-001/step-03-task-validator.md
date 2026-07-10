---
step: 03
agent: task-validator
run_id: 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001
task_id: T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa
verdict: PASS
inputs_read:
  - runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-02-landscape-reader.md
  - tasks/T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa.md
  - tasks/README.md
  - tasks/T-0027-check-kernel-upgrade.md (verified scope = hetzner-prod only)
  - workflows/audit-host.md (verified ">14 days → P1" threshold authority)
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-08-landscape-updater.md (verified audit run is closed)
---

# Step 03 — task-validator

## Well-formedness
**PASS** — frontmatter is valid and complete:
- `id` matches filename (`T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa`).
- `status: in-progress`, `kind: task`, `priority: P2`, `workflow: infrastructure` all consistent with the run's nature and `tasks/README.md` schema.
- Required body sections all present: `Why`, `What done looks like`, `Notes`, `History` (append-only with 3 dated entries: observation creation → promotion → in-progress). `Result` is correctly absent (only required when status transitions to a closed state).
- `executed_by_runs` correctly lists this run.
- `affects` correctly names `landscape/hosts/pro-data-tech-qa.md` (single, accurate).
- Minor cosmetic note (not a fail): the `Why` section cites `tasks/README.md` / workflow Findings policy as the source of the ">14 days → P1" threshold. The authoritative source is `workflows/audit-host.md` line 323 ("pending security upgrades > 14 days → P1"). The conclusion (P2 for ~3 days drift) is correct; only the citation is wrong. Acceptable to fix at landscape-updater step if convenient; not a blocker.

## Feasibility
**PASS** — each acceptance criterion is realistic and verifiable:

| # | Criterion | Verifiable via | Feasible |
|---|---|---|---|
| 1 | Apply 9 apt upgrades (kernel + meta) | `apt -y full-upgrade` exit code + `dpkg -l` post-check | yes |
| 2 | Reboot into new kernel | `systemctl reboot` via `nohup`/`setsid`/`< /dev/null` so the SSH session survives the disconnect (executor must guard against `PowerShell-native-command-stderr` false-positive on `Connection to … closed by remote host`) | yes |
| 3 | `uname -r` shows 7.0.0-27-generic | direct shell check after reboot | yes |
| 4 | `/var/run/reboot-required` cleared | `test -f /var/run/reboot-required` returns non-zero | yes |
| 5 | Postgres container healthy post-reboot | `docker ps` shows `(healthy)` + loopback `psql -h 127.0.0.1 -p 3112 -U aiqadam -d aiqadam_test -c 'SELECT 1'` returns `1`. Compose `restart: unless-stopped` + containerd on-boot bring-up make this highly likely | yes |
| 6 | sshd / UFW / fail2ban active post-reboot | `systemctl is-active sshd ufw fail2ban` | yes — all 3 services are `enabled` (per landscape) |

All criteria map to a single shell command each. The reboot-connection-drop risk is real but well-understood and mitigated by backgrounding `systemctl reboot` (step 02 surfaces this; executor must apply the nohup/setsid/disown discipline that the project's prior `repo/ufw-rollback-timer-*.md` and `ufw-atd-fallback-nohup.md` memories already encode).

## In-scope
**PASS** — `workflows/infrastructure.md` (state-changing infrastructure) is the correct workflow:
- Target is a single managed host (`pro-data-tech-qa`, `95.46.211.230`).
- All changes are reversible-by-reinstall (apt) except the kernel itself (one-way into `7.0.0-27-generic`), matching `estimated_reversibility: partial`.
- Blast radius `medium` is justified: only public listener is SSH :22 (so host stays manageable); `ai-qadam-test-db-1` is published on `127.0.0.1:3112` only, so no external users depend on it during the reboot window; no cross-host dependencies; no provider control-plane state to coordinate (this is pro-data.tech, not Hetzner — no firewall API, no snapshots).
- Approval gate will trigger before execution (state-changing workflow, `medium` blast) — orchestrator must invoke `shared/approval-protocol.md`.

## Conflict-free
**PASS** — verified no concurrent or competing work on this host:

- **Audit run** `2026-07-10-audit-host-pro-data-tech-qa-001`: closed through `step-08-landscape-updater` (verdict: PASS). Created T-0099 + T-0100 observations and updated `landscape/hosts/pro-data-tech-qa.md`'s `last_verified`. No further activity expected.
- **T-0096 (auditd install)**: separate task, NOT in this run. The user's explicit sequencing decision (T-0099 before T-0096) is correctly captured in T-0099's History entry and the task's `blocks`/`blocked_by` lists being empty (this is a sequencing choice documented in History, not a hard dependency).
- **T-0100 (Postgres container hardening)**: observation only, not yet promoted; explicitly out of scope per step 01.
- **T-0098 (host-level backup)**: still open P3 observation; no automated rollback path for the Postgres volume — this is a known risk, flagged by both step 01 and step 02, and the task's `What done looks like` does NOT require a backup step. Executor may propose a manual `tar` snapshot of `/var/lib/docker/volumes/ai-qadam-test_ai_qadam_test_pgdata/_data` as a precaution (`/` has 142 GB free); optional, not gating.
- **T-0027 (kernel-upgrade check, hetzner-prod)**: confirmed scoped to `landscape/hosts/hetzner-prod.md` only — different host. Not a duplicate.
- **No off-site / external storage**: task explicitly avoids any Hetzner snapshot / provider snapshot per project hard rule. All precautions stay on local disk (`/var/backups/`). Compliant.
- **No unattended-upgrades race**: landscape confirms `unattended-upgrades` is restricted to `security` + `ESMApps` + `ESM` origins, so it will not re-touch the `-updates`-pocket packages after the manual upgrade. The `apt-daily.timer` / `apt-daily-upgrade.timer` may be running concurrently (apt's own lock prevents a true race); executor may `systemctl stop` both for the duration as belt-and-braces, then re-enable.

## Preconditions
**PASS** — every precondition listed in step 01 is met by the current landscape:

| Precondition | Source task | Status |
|---|---|---|
| SSH root + operator-user access works; `sudo -n true` clean | T-0097 | done (3 operators with NOPASSWD sudo) |
| `tvolodi` is the preferred everyday operator (alias `pro-data-tech-qa` already maps to it) | T-0097 | done |
| `root@95.46.211.230` provider key still works as break-glass | (provider-set) | confirmed by audit probe C |
| sshd hardening survives reboot | T-0093 | done (audit probe C: 21/21 checks still pass) |
| UFW active | T-0094 | done |
| fail2ban active + ignoreip fresh | T-0095 | done; landscape notes current `ignoreip` is `178.89.57.135` — matches workstation, executor must sanity-check if more than ~2 days have passed |
| Docker / containerd starts cleanly on boot | T-0090 | done |
| Postgres compose `restart: unless-stopped` | (pre-existing) | confirmed |
| `/boot` has room for new kernel image | (landscape) | 989 MB total, 17% used — ample for one new kernel image (~80–100 MB) |
| No `-security` regression: 0 unpatched CVEs skipped by waiting | (landscape) | confirmed by audit probe B (`--- security-only pending --- 0`) |

**One executor-side check worth surfacing** (step 02 flagged it): `df -h /boot` should be re-checked immediately before upgrade; if the host has accumulated more than 4–5 stale kernels since the last `autoremove`, `/boot` could fill. Standard `apt full-upgrade` triggers `autoremove` post-install; `landscape` does not confirm `Remove-Unused-Kernel-Packages: true` is set in `50unattended-upgrades`. Executor should manually `apt autoremove --purge` if `/boot` is tight.

## Sequencing
**PASS** — T-0099-before-T-0096 is correct and captured:
- The audit-finding chain (T-0099 → T-0096) installs auditd against a stable, current kernel. Doing the reverse (auditd first, then kernel upgrade) would risk auditd losing or re-emitting events during the kernel transition and would not benefit anyone.
- T-0099 has no `blocked_by` entries, and the in-progress status indicates it is unblocked and ready.
- Step 02's landscape snapshot is fresh (`last_verified: 2026-07-10`, audit reconfirmation same day).
- The orchestrator should be aware that promoting T-0099 from `in-progress` → `done` will free the queue for T-0096 to be picked up (no explicit `blocks` link needed — the user's verbal sequencing instruction is the contract).

## Specific risks
- **Kernel boot failure on `7.0.0-27-generic`**: low probability (this is an Ubuntu LTS `-updates` pocket kernel, not a custom build), but a hard recovery would require pro-data.tech's KVM/rescue console. No provider API automation exists for this host (no Hetzner Cloud, no pro-data.tech API documented in landscape). Mitigated by: brief outage window, the prior kernel remains in GRUB as fallback (`/boot` shows 17% used → previous kernels not yet purged → can boot old kernel from GRUB menu).
- **No data backup**: `ai-qadam-test_ai_qadam_test_pgdata` volume has no automated backup. Executor should propose a local `tar` snapshot to `/var/backups/` as a precaution (142 GB free on `/`); not gating but strongly advised.
- **Postgres container restart ordering**: `unless-stopped` + Docker's normal systemd dependency on `containerd.service` should bring it back automatically; if a custom `docker-compose up -d` service unit were ever introduced without `Requires=docker.service`, the container could fail to come back. Landscape shows standard Compose behaviour, so no custom unit expected. Acceptance criterion explicitly verifies this.
- **fail2ban `ignoreip` drift**: if the workstation's outbound IP has changed since 2026-07-08, post-reboot SSH retries could trigger a ban during the executor's reconnect. Executor should `sudo fail2ban-client status sshd` and confirm `178.89.57.135` is in the ignore list before initiating the reboot.
- **Minor citation error in T-0099**: the "Why" section attributes the ">14 days → P1" rule to `tasks/README.md`; the actual source is `workflows/audit-host.md:323`. Cosmetic; landscape-updater may fix while editing the task to `done`.

## Verdict
**PASS** — T-0099 is well-formed, feasible, in-scope, conflict-free, has all preconditions met, and is correctly sequenced before T-0096. Solution-designer may proceed to step 04.