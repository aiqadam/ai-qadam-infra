---
step: 01
agent: task-reader
run_id: 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001
task_id: T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa
verdict: PASS
inputs_read:
  - tasks/T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa.md
  - tasks/_index.md
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-06-executor-discovery.md
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-07-execution-validator.md
---

# Step 01 — task-reader

## Task summary
T-0099 is a state-changing host remediation on `pro-data-tech-qa` (95.46.211.230, hostname `drkkrgm-qa-instance`): apply the 9 pending apt upgrades currently sitting in the `-updates` pocket (including `linux-image-7.0.0-27-generic`, `linux-base`, `fwupd`, `libfwupd3`, `python3-software-properties`, `software-properties-common`, `tzdata`, `ubuntu-kernel-accessories`, `ubuntu-minimal`, `ubuntu-server`, `ubuntu-standard`), then reboot into the new kernel to clear the `/var/run/reboot-required` marker. This task was created as an `observation` by run `2026-07-10-audit-host-pro-data-tech-qa-001` (probe B — kernel/reboot-required drift), promoted to `pending`, then to `in-progress` for this run after the user chose to sequence it BEFORE T-0096 (auditd install) so that auditd is installed onto a stable, current kernel rather than one mid-upgrade. Severity is P2 (medium drift — not a violated security control; reboot-required outstanding only ~3 days, well under the P1 ">14 days" threshold), distinct from T-0027 (which is scoped to `landscape/hosts/hetzner-prod.md` only and does not already cover `pro-data-tech-qa`).

## Acceptance criteria (extracted from task file)
- [ ] All 9 pending package upgrades are applied (`linux-image-7.0.0-27-generic`, `linux-base`, `fwupd`, `libfwupd3`, `python3-software-properties`, `software-properties-common`, `tzdata`, `ubuntu-kernel-accessories`, `ubuntu-minimal`, `ubuntu-server`, `ubuntu-standard`).
- [ ] Host rebooted into the new kernel.
- [ ] `uname -r` reflects `7.0.0-27-generic` (or newer, if a further update has landed by execution time).
- [ ] `/var/run/reboot-required` marker is cleared (i.e. file absent).
- [ ] `ai-qadam-test-db-1` Postgres container comes back healthy post-reboot (`docker ps` shows `Up ... (healthy)`; loopback `SELECT 1` succeeds).
- [ ] sshd, UFW, and fail2ban remain active and unaffected by the reboot.

## Preconditions
- SSH root access via `pro-data.tech-qa-instance_rsa.ppk` (or the new operator user `tvolodi` + NOPASSWD sudo from T-0097) works; `sudo -n true` is clean.
- The 3 operator accounts (`tvolodi`, `viktor_d`, `binali_r`) created under T-0097 already exist — reboot will not regress them.
- sshd hardening from T-0093, UFW from T-0094, and fail2ban from T-0095 will be re-confirmed after reboot (not assumed to survive cleanly on a fresh boot — must be verified).
- Containerd/Docker installed under T-0090 starts cleanly on boot so the `ai-qadam-test-db-1` container comes back automatically.
- unattended-upgrades is enabled (security + ESM origins only); a manual `apt upgrade` here will coexist with unattended-upgrades without conflict — unattended-upgrades will not re-touch these `-updates`-pocket packages after we reboot.

## Out of scope
- **T-0096 (auditd install on pro-data-tech-qa) — explicitly NOT in this run.** This run only does kernel upgrade + reboot; auditd install is a separate, scheduled follow-up run after T-0099 completes successfully (intentional sequencing per user instruction on 2026-07-10).
- **T-0100 (harden ai-qadam-test-db-1 container — User/CapDrop/SecurityOpt/ReadonlyRootfs)** — observation only, not in scope here.
- **T-0098 (host-level backup strategy)** — remains open; the task notes explicitly flag that there is no automated rollback path if the reboot causes an unexpected issue. A manual filesystem-level dump of the Postgres volume (`/var/lib/docker/volumes/ai-qadam-test_ai_qadam_test_pgdata/`) before reboot is a reasonable precaution the executor may propose, but is not a hard acceptance criterion.
- **T-0027 (kernel-upgrade check)** — scoped to `landscape/hosts/hetzner-prod.md` only; this is a parallel observation for a different host, not a duplicate.
- **Probe D/J SUID `sudo-rs` cargo binaries** — confirmed informational-only by step 07 (`dpkg -S` shows `sudo-rs 0.2.13-0ubuntu1`; `/usr/bin/sudo` is the alternatives symlink to it). No action needed; do not raise here.
- Any cloud-provider snapshot/backup — per the project's hard rule "no off-site/external storage", all precautions stay on local disk only.

## Risks
- **Blast radius (medium, as task estimates):** the only public listener on this host today is SSH on port 22, so the host itself stays manageable throughout. The `ai-qadam-test-db-1` Postgres container will be briefly unavailable during reboot (Docker restart on boot); it is published only on loopback `127.0.0.1:3112`, so no external users are affected. No other internet-facing services run on this host.
- **Reversibility: partial.** The upgrade itself is recoverable (apt can downgrade if needed), but the reboot is a one-way transition into the new kernel: a kernel boot failure on `7.0.0-27-generic` would require break-glass recovery via the provider's rescue/KVM console, which is feasible but not graceful. The task explicitly notes no host-level or application-level backup mechanism exists yet (T-0098 still open) — a manual filesystem dump of the Postgres volume before reboot is a reasonable precaution.
- **No `-security` regression risk:** the 9 packages are tagged `-updates` (kernel/meta-package drift), not `-security`. Rebooting now does not skip any known CVE patch — unattended-upgrades has already pulled and applied the security pocket separately.
- **No unattended-upgrades conflict:** unattended-upgrades is restricted to `security` + ESM origins; it will not attempt to re-apply these `-updates`-pocket packages after the manual upgrade, and the post-reboot state should be stable.
- **No `lock-apt-on-reboot` setting to undo:** the project has not (yet) pinned apt during kernel upgrades (no such convention in `landscape/`), so a concurrent unattended-upgrades run during the manual upgrade is the only theoretical race. The executor should briefly `systemctl stop apt-daily.timer apt-daily-upgrade.timer` (or use `apt -y full-upgrade` while unattended-upgrades is idle — usually fine since the run is at 02:30 UTC outside the normal unattended-upgrades window of ~06:00–15:00 UTC observed in probe B's log).
- **Postgres container health dependency:** `ai-qadam-test-db-1` is the only container; if its restart ordering or systemd unit is misconfigured, it could fail to come back automatically. Acceptance criterion explicitly checks this; the executor should verify via `docker ps` + loopback `SELECT 1` before declaring done.

## Open questions
none