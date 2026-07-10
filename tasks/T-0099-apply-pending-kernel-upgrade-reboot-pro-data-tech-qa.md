---
id: T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa
title: Apply pending kernel upgrade and reboot pro-data-tech-qa (reboot-required drift)
kind: task
status: done
priority: P2
created: 2026-07-10
updated: 2026-07-10
closed: 2026-07-10
outcome: T-0099 done 2026-07-10 via run 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001. Kernel upgraded to 7.0.0-27-generic, host rebooted (downtime 6m 44s), all 9 V-checks PASSED. Pre-reboot pg_dump + etc-snapshot preserved at /var/backups/pre-T0099.20260710T061200Z/. 4 phased-rollout packages remain (Ubuntu phased-update; not a failure).
created_by: 2026-07-10-audit-host-pro-data-tech-qa-001
source_runs:
  - 2026-07-10-audit-host-pro-data-tech-qa-001
executed_by_runs:
  - 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0027-check-kernel-upgrade
estimated_blast_radius: medium
estimated_reversibility: partial
---

# Apply pending kernel upgrade and reboot pro-data-tech-qa

## Why
Audit run [2026-07-10-audit-host-pro-data-tech-qa-001](../runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-06-executor-discovery.md) (probe B) found the host running kernel `7.0.0-14-generic` while `linux-image-7.0.0-27-generic` is installed/available and `/var/run/reboot-required` is set (`*** System restart required ***`, pending pkgs `linux-image-7.0.0-27-generic`, `linux-base`). 9 packages total are pending upgrade (0 tagged `-security` by the naive grep heuristic — this is a kernel/meta-package drift, not necessarily an unpatched CVE). `landscape/hosts/pro-data-tech-qa.md` had recorded "0 pending upgrades as of 2026-07-07 11:20 UTC" — that snapshot is now stale.

Per [runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-07-execution-validator.md](../runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-07-execution-validator.md) Findings table (probe B row): severity medium (drift, not a violated security control), reboot-required outstanding only ~3 days (well under the P1 ">14 days" threshold per `tasks/README.md` / workflow Findings policy) — assigned **P2**. The validator also confirmed this is a distinct, new finding: [T-0027](T-0027-check-kernel-upgrade.md) (`check whether a kernel upgrade is available`) is scoped to `landscape/hosts/hetzner-prod.md` only and does NOT already cover `pro-data-tech-qa` — this is not a duplicate.

## What done looks like
- [x] Apply the 9 pending package upgrades (including `linux-image-7.0.0-27-generic`, `linux-base`, `fwupd`, `libfwupd3`, `python3-software-properties`, `software-properties-common`, `tzdata`, `ubuntu-kernel-accessories`, `ubuntu-minimal`, `ubuntu-server`, `ubuntu-standard`) via a state-changing infrastructure run.
- [x] Reboot the host into the new kernel.
- [x] Confirm `uname -r` reflects `7.0.0-27-generic` (or newer, if a further update has landed by execution time).
- [x] Confirm `/var/run/reboot-required` marker is cleared.
- [x] Confirm the `ai-qadam-test-db-1` Postgres container comes back healthy post-reboot (`docker ps` shows `Up ... (healthy)`; loopback `SELECT 1` succeeds).
- [x] Confirm sshd/UFW/fail2ban remain active and unaffected by the reboot.

## Result

Executed 2026-07-10 via run [`2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001`](../runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/) (executor step-06: [step-06-executor-infra.md](../runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-06-executor-infra.md); validator step-07: [step-07-execution-validator.md](../runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-07-execution-validator.md)). The plan's 7 phases ran cleanly: pre-flight idempotent state capture (Phase 0) → Postgres `pg_dump` snapshot via the live `POSTGRES_PASSWORD` (Phase 1, dump 405 B / 4 TOC entries) → `apt full-upgrade -y` upgraded 12 packages including `linux-image-7.0.0-27-generic` (already pre-installed, but meta-packages `ubuntu-kernel-accessories/minimal/server/standard` bumped 1.570→1.570.1, `tzdata` 2026a→2026b, `curl`/`libcurl*` 8.18.0-1ubuntu2.2→8.18.0-1ubuntu2.3) (Phase 2) → pre-reboot `etc-snapshot.tar.gz` + `pre-reboot-state.txt` captured (Phase 4) → `setsid systemctl reboot` at 2026-07-10T06:14:28Z (Phase 5) → SSH returned at 2026-07-10T06:21:12Z, downtime **6m 44s** (Phase 6 polling) → all 9 V-checks (V01–V09) PASSED on the new kernel 7.0.0-27-generic (Phase 7), with V01 carrying the documented phased-update caveat for 4 residual packages.

End state: host running `7.0.0-27-generic`; `ai-qadam-test-db-1` back `Up 6 minutes (healthy)`; `pg_isready` `accepting connections`; all of ssh/ufw/fail2ban/docker/apparmor `active`; `/var/run/reboot-required` cleared by the clean boot; `journalctl --boot=-1 --priority=err` returned 0 matches for `auditd|dhclient|networkd|snapd` (clean boot). Pre-reboot `pg_dump` (405 B) + `etc-snapshot.tar.gz` (148 453 B, 418 tar entries) + `pre-reboot-state.txt` (5924 B, 92 lines) preserved at `/var/backups/pre-T0099.20260710T061200Z/`. The previous kernel `7.0.0-14-generic` remains installed as the GRUB fallback per design (rollback path A still available).

**Deviations from the plan / acceptance criteria:** none of consequence. The new kernel `linux-image-7.0.0-27-generic` was already present in `dpkg -l` before this run (Ubuntu's `-updates` pocket had been delivering without reboots); the run's `apt full-upgrade` therefore upgraded the meta-packages rather than installing a fresh kernel image, but the `setsid` reboot was still required to actually boot into it. V01 (`apt list --upgradable` empty) returned 4 phased-update packages (`fwupd`, `libfwupd3`, `python3-software-properties`, `software-properties-common`) — all flagged "Not upgrading yet due to phasing" by Ubuntu's phased-update mechanism; this is design-intent and not a regression. The pg_dump is small (DB has only the pgvector extension + schema, no user tables) but is a valid `pg_dump` custom-format archive (verified via `pg_restore -l`). Landscape updated: [`landscape/hosts/pro-data-tech-qa.md`](../landscape/hosts/pro-data-tech-qa.md) frontmatter `kernel:` field → `7.0.0-27-generic`; [`landscape/services.md`](../landscape/services.md) gained a `### Apt posture` subsection under the pro-data-tech-qa block. This closes the conceptual blocker for T-0096 (auditd install — now sequenced to land on a stable, current kernel).

## Notes
- Kernel upgrade + reboot implies brief downtime for the `ai-qadam-test-db-1` container (Docker/containerd restart on boot). No other services are internet-facing on this host today (SSH is the only public listener), so blast radius is limited to this host's own workloads.
- No host-level or application-level backup exists yet for this host ([T-0098](T-0098-host-level-backup-strategy-for-pro-data-tech-qa.md), still open) — consider taking a manual precaution (e.g. a filesystem-level dump of the Postgres volume) before rebooting, since there is no automated rollback path if the reboot causes an unexpected issue.
- unattended-upgrades is active (security + ESM origins only) but does not auto-apply `-updates`-pocket kernel/meta-packages or trigger reboots — this drift will persist until a manual/scheduled apt upgrade + reboot occurs.

## History
- 2026-07-10: created as kind: observation by 2026-07-10-audit-host-pro-data-tech-qa-001 (probe B — kernel/reboot-required drift)
- 2026-07-10: promoted observation → pending by user request (sequenced before T-0096 auditd install; ensures auditd is installed on a stable, current kernel rather than one mid-upgrade)
- 2026-07-10: status → in-progress, run 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001
- 2026-07-10: status → done, outcome succeeded (run 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001, 9/9 V-checks PASSED)
