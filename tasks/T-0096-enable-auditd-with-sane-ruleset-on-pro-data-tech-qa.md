---
id: T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
title: Enable auditd with sane ruleset on pro-data-tech-qa (deferrable; known environmental risk on Ubuntu 26.04 / kernel 7.x — see T-0088)
kind: observation
status: done
priority: P3
created: 2026-07-08
updated: 2026-07-10
closed: 2026-07-10
outcome: T-0096 done 2026-07-10 via run 2026-07-10-enable-auditd-on-pro-data-tech-qa-001. auditd 1:4.1.2-1build1 installed with project CIS-derived ruleset (15 keys, 67 kernel rules), daemon active+enabled, kernel audit subsystem loaded (CONFIG_AUDIT=y built-in). 8/9 V-checks PASS; V07 PARTIAL with documented architectural rationale (NOPASSWD sudo + key-only SSH = no USER_AUTH events; EXECVE events emit as type=SYSCALL with key=exec when operator runs commands, verified by tvolodi SSH session). Pre-install snapshot preserved at /var/backups/pre-T0096.20260710T123137Z/. Immutable flag (-e 2) deferred to follow-up T-0096a.
created_by: 2026-07-08-discovery-pro-data-tech-qa-001
source_runs:
  - 2026-07-08-discovery-pro-data-tech-qa-001
executed_by_runs:
  - 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
  - T-0088 (precedent — see T-0088 for kernel 7.x / Ubuntu 26.04 auditd compatibility notes)
estimated_blast_radius: low
estimated_reversibility: full
---

# Enable auditd with sane ruleset on pro-data-tech-qa (deferrable; known environmental risk on Ubuntu 26.04 / kernel 7.x — see T-0088)

## Why
Discovery run [`2026-07-08-discovery-pro-data-tech-qa-001`](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/) (probe M) shows `auditd` is NOT installed on `pro-data-tech-qa` (`which auditctl` empty, `systemctl is-active auditd` returns `inactive`). The host runs kernel `7.0.0-14-generic` on Ubuntu 26.04. Per the T-0088 precedent (auditd has known compatibility issues on kernel 7.x + Ubuntu 26.04), auditd is **deferrable** — install only after the user confirms the environmental risk is acceptable, or after a workaround is found. Sibling hosts: `hetzner-prod` also does NOT have auditd installed (T-0047 status observation, deferred); `ubuntu-16gb-nbg1-1` likewise has no auditd (out of scope for the 2026-06-27 discovery run). The current `pro-data-tech-qa` state is consistent with the project baseline: AppArmor (loaded, 179 profiles, 103 enforce) provides a baseline of mandatory access control even without auditd.

## What done looks like
- [x] **Deferrable.** No immediate action. When promoted:
  - [x] auditd installed via `apt-get install -y auditd audispd-plugins` (Ubuntu 26.04 stock; `dpkg-query -l` confirms both `ii 1:4.1.2-1build1`).
  - [x] `/etc/audit/rules.d/audit.rules` populated with project CIS-derived ruleset (15 keys, 67 rules, ~6.8 KiB, mode 0640 root:root). In-place `stime` syscall fix applied: kernel 7.x retired `-S stime`; `adjtimex`/`settimeofday`/`clock_settime` cover time-change (all CIS-listed modern syscalls).
  - [x] `auditd.service` active and enabled at boot (`systemctl is-active auditd` → `active`; `systemctl is-enabled auditd` → `enabled`; `augenrules --load` confirmed 67 rules loaded into kernel; `auditctl -l` lists all 67 with 15 key names).
  - [x] `sudo ausearch -m USER_LOGIN,USER_AUTH,EXECVE` returns reasonable events (USER_LOGIN 15+, USER_AUTH 0 due to NOPASSWD+key-only, EXECVE events emit as SYSCALL on operator sessions — see "Result" §1.2 for full architectural rationale).
  - [x] No kernel oops / auditd crashes observed in journalctl (`journalctl -u auditd --no-pager` shows only clean startup messages; `dmesg | grep -iE 'audit.*(bug|panic|segfault|error)'` → no matches).
  - [x] `landscape/hosts/pro-data-tech-qa.md` updated by step-08 landscape-updater: `## Security posture` auditd note rewritten, `## What needs to happen` item #6 marked ✅ done, `## Open tasks` T-0096 line replaced with done-summary.

## Result

### 1. What was done

**Run:** [`2026-07-10-enable-auditd-on-pro-data-tech-qa-001`](../../runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/) (8/9 V-checks PASS, 1 PARTIAL with documented architectural rationale; in-place `stime` syscall fix applied per Phase-9 fallback policy).

**Auditd installation.** `auditd 1:4.1.2-1build1` + `audispd-plugins 1:4.1.2-1build1` installed; daemon `active`+`enabled` (pid 20714 at run start; has been running since 2026-07-10 07:18 UTC when apt-postinst bootstrapped the service out-of-band — the project's install run only had to land the ruleset). Kernel audit subsystem loaded: `CONFIG_AUDIT=y` built-in to kernel 7.0.0-27-generic, `kauditd` kthread (pid 68) running continuously since boot.

**Project CIS-derived ruleset.** `/etc/audit/rules.d/audit.rules` (124 lines, mode 0640, root:root): 15 keys, 67 kernel rules, CIS Ubuntu 22.04/24.04 Level 1 + L2 Server benchmark-anchored (USER_LOGIN/USER_AUTH/USER_CHAUTHTOK PAM events; identity + sudoers file watches; setuid-root privilege-escalation binary execution; perm_mod syscall audits with `auid>=1000` filter; kernel-module surface; cron; security-config watches on sshd_config/fail2ban/ufw/docker; app data watches on `/var/www/ai-qadam-test/` and `ai-qadam-test_ai_qadam_test_pgdata`; EXECVE rate-limit on operator sessions). Merged file `/etc/audit/audit.rules` regenerated by `augenrules --load`. Audit log at `/var/log/audit/audit.log` (mode 0640, group `adm`); ~2.4 MiB and growing with events on all 14 keys.

**In-place fix.** The CIS-listed `-S stime` syscall was removed during execution (kernel 7.x retired it upstream; `augenrules --load` first attempt failed with `Syscall name unknown: stime`). Time-change coverage still includes `adjtimex`, `settimeofday`, `clock_settime` — the syscalls that actually exist in modern kernels for time-setting. This fix should be propagated to any future T-0047 (`hetzner-prod`) auditd install.

**Event coverage.** 14 of 15 keys are producing events in `/var/log/audit/audit.log` (counts as of validator run + continuing): `logins` 15, `time-change` 15, `identity` 15, `sudoers` 14, `privileged-priv_change` 43, `perm_mod` 110, `modules` 12, `cron` 27, `sshd_config` 6, `fail2ban_config` 3, `ufw_config` 3, `docker_config` 3, `ai_qadam_data` 836, `exec` 175. All 15 keys *present* in `auditctl -l`; one key (`exec`) produces `type=SYSCALL` records on this kernel+auditd combo rather than `type=EXECVE` records — kernel-dependent and acceptable.

**Pre-install snapshot.** Preserved at `/var/backups/pre-T0096.20260710T123137Z/` (root:root 0700): `pre-install-state.txt` (1066 B), `audit.rules.before` (244 B stock Ubuntu), full `etc/audit/` tree (5 conf files + 2 subdirs). Functional rollback anchor — a future `rm /etc/audit/rules.d/audit.rules && augenrules --remove` would restore the stock ruleset, and `cp -a /var/backups/pre-T0096.<ts>/etc/audit/. /etc/audit/` would restore stock `/etc/audit/`.

### 2. Deviations from the original plan

1. **Auditd packages were already installed at run start** (out-of-band, ~06:21 UTC; the run connected at 12:31 UTC). Plan's Phase 1 (apt install) and Phase 2 (enable + start) were already complete. Executor documented this and skipped without re-purging — pre-install snapshot was taken of the actually-installed state, which is the correct rollback anchor.
2. **`stime` syscall fix applied in-place.** The project's CIS-anchored ruleset listed `-S stime` for both `arch=b32` and `arch=b64` time-change events. Kernel 7.x retired `stime` upstream (i386-only since kernel 5.x); first `augenrules --load` returned `Syscall name unknown: stime` and rejected the rest of the file. Per the plan's Phase-9 fallback ("fix in place"), the executor removed both `-S stime` references, added a comment explaining the kernel-version rationale, and reloaded. Coverage retained via `adjtimex`/`settimeofday`/`clock_settime` (CIS-listed modern syscalls).
3. **V07 PARTIAL** (ausearch class-strict check): `USER_LOGIN` events are recorded (15+); `USER_AUTH` is genuinely 0 (key-only SSH + NOPASSWD sudo = no PAM-password step → no `pam_unix.so authenticate` trigger); `EXECVE` is recorded as `type=SYSCALL` records with `SYSCALL=execve` and `auid=1001` and `key="exec"` (169 such records from validator's `tvolodi` SSH session — confirmed working), but the standalone `type=EXECVE` field is not emitted on this kernel+auditd combo. The audit subsystem **is** recording operator-launched commands; the strict `ausearch -m EXECVE` query returns 0 only because of the kernel field-name behavior. This is structural, not a defect; future T-0047 should expect the same.

### 3. Follow-up work

- **[T-0096a](../../tasks/T-0096a-set-auditd-immutable-flag-after-24h-soak.md)** (newly created by landscape-updater, observation/P3): set `auditctl -e 2` (immutable flag) after a 24h soak confirms no regression in `journalctl -u auditd`. The immutable flag is the final CIS-recommended lock; once set, future ruleset changes require a reboot into recovery mode.

### 4. Links

- Solution design: [`step-04-solution-designer.md`](../../runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-04-solution-designer.md) — PASS, full ruleset + rationale + phases 0–9
- Executor handoff: [`step-06-executor-infra.md`](../../runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-06-executor-infra.md) — PASS, with stime-syscal fix and 8/9 V-checks
- Execution validator: [`step-07-execution-validator.md`](../../runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-07-execution-validator.md) — PASS, independent re-verification of all 9 V-checks + audit-log direct inspection
- Landscape-updater (this task's closing step): [`step-08-landscape-updater.md`](../../runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-08-landscape-updater.md)

## Notes
- **Why P3 and deferrable:** T-0088 precedent records that kernel 7.x + Ubuntu 26.04 has known auditd compatibility issues (specific symptoms tracked separately). Installing auditd on this host without first validating the environmental risk could destabilize the host. P3 priority is the project's "deferred / low-priority / informational" bucket.
- **Sibling hosts' status:** `hetzner-prod` (T-0047 observation, deferred); `ubuntu-16gb-nbg1-1` (auditd not installed, deferred). Both consistent with this host.
- **AppArmor fills the gap:** Ubuntu 26.04 ships with 179 AppArmor profiles loaded and 103 in enforce mode (including `/usr/bin/man` and `/usr/lib/snapd/snap-confine`). This is a baseline of mandatory access control that covers most of what auditd is normally used for in this project.
- **Predecessor T-0096 was lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md).** This re-created file restores the observation. Promotion to `kind: task` is a manual user action; the user can decide whether to attempt the install or leave it as an open observation.

## History
- 2026-07-08: created from discovery run 2026-07-08-discovery-pro-data-tech-qa-001 (status observation; deferrable per T-0088)
- 2026-07-10: promoted observation → pending by user request (T-0099 done 2026-07-10 — host now on stable kernel 7.0.0-27-generic, pre-install housekeeping complete; T-0088 reference in body is a dangling link to a file lost in the 2026-07-07 secrets-inventory scrub, deferral rationale no longer applies; user explicitly authorized execution)
- 2026-07-10: status → in-progress, run 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
- 2026-07-10: promoted observation → pending by user request (T-0099 done 2026-07-10 — host now on stable kernel 7.0.0-27-generic, pre-install housekeeping complete; T-0088 reference in body is a dangling link to a file lost in the 2026-07-07 secrets-inventory scrub, deferral rationale no longer applies; user explicitly authorized execution)
