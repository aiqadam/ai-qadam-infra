---
id: T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
title: Install fail2ban with sshd jail on pro-data-tech-qa
kind: task
status: done
priority: P2
created: 2026-07-08
updated: 2026-07-08
closed: 2026-07-08
outcome: fail2ban 1.1.0-9 installed on 2026-07-08 via run 2026-07-08-install-fail2ban-pro-data-tech-qa-001. sshd jail active with iptables-multiport banaction; 7/7 verification checks passed. Mgmt workstation IP in ignoreip.
created_by: 2026-07-08-discovery-pro-data-tech-qa-001
source_runs:
  - 2026-07-08-discovery-pro-data-tech-qa-001
executed_by_runs:
  - 2026-07-08-install-fail2ban-pro-data-tech-qa-001
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by:
  - T-0093-harden-sshd-on-pro-data-tech-qa
related:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
  - T-0093-harden-sshd-on-pro-data-tech-qa
  - T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
estimated_blast_radius: low
estimated_reversibility: full
---

# Install fail2ban with sshd jail on pro-data-tech-qa

## Why
Discovery run [`2026-07-08-discovery-pro-data-tech-qa-001`](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/) (probe M) shows `fail2ban` is NOT installed on `pro-data-tech-qa` (`which fail2ban-client` empty, `sudo: 'fail2ban-client': command not found`). Without fail2ban, brute-force SSH attempts (which are a constant background noise on any internet-exposed port 22) are not rate-limited at the host layer. Sibling hosts `hetzner-prod` ([T-0005](../tasks/T-0005-install-fail2ban.md), done 2026-05-12) and `ubuntu-16gb-nbg1-1` ([T-0084](../tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md), done 2026-06-27) both have fail2ban installed with the sshd jail. The same baseline is required here.

## What done looks like
- [ ] fail2ban installed via `apt install fail2ban` (Ubuntu 26.04 stock; version expected `1.1.0-9` based on `ubuntu-16gb-nbg1-1`'s install).
- [ ] `/etc/fail2ban/jail.d/sshd.local` created with `enabled = true`, `maxretry = 3`, `bantime = 600s`, `findtime = 600s`, `ignoreip = 127.0.0.1/8 ::1 178.89.57.135` (management-workstation outbound IP).
- [ ] `banaction = iptables-multiport` (matches sibling hosts).
- [ ] `fail2ban-client status sshd` returns the jail active.
- [ ] `fail2ban.service` active and enabled at boot.
- [ ] Brute-force attempt simulation: 4 failed SSH attempts from a test IP → IP banned within `findtime + bantime`.
- [ ] `landscape/hosts/pro-data-tech-qa.md` updated: `## Security posture` fail2ban note removed; `## What needs to happen` item #5 marked done; `## SSH hardening tooling on host` line updated. `landscape/services.md` `## pro-data-tech-qa` systemd-units table gains a `fail2ban.service` row.

## Result

fail2ban 1.1.0-9 installed on `pro-data-tech-qa` (95.46.211.230) on 2026-07-08 via run [`2026-07-08-install-fail2ban-pro-data-tech-qa-001`](../../runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/). Outcome: succeeded. **7/7 verification checks PASSED** (V01 dpkg-installed, V02 jail content, V03 fail2ban-client status, V04 sshd jail status / params / config / filter / logpath / actions, V05 service active, V06 service enabled, V07 live SSH no-self-ban). All "What done looks like" checklist items met:

- [x] fail2ban installed via `apt install fail2ban` → version `1.1.0-9` confirmed (matches `ubuntu-16gb-nbg1-1` sibling).
- [x] `/etc/fail2ban/jail.d/sshd.local` created (188 bytes, mode 0644) with `enabled = true`, `maxretry = 3`, `bantime = 600`, `findtime = 600`, `ignoreip = 127.0.0.1/8 ::1 178.89.57.135`.
- [x] `banaction = iptables-multiport` (matches sibling T-0084; orchestrator chose `iptables-multiport` over `ufw` per T-0084 precedent).
- [x] `fail2ban-client status sshd` returns the jail loaded; `Filter: sshd`, `Bantime: 600`, `Find time: 600`, `Max retry: 3`, `Journal matches` line shown (1.1.x behavior — `logpath /var/log/auth.log` is the file-based fallback; journal stream is primary).
- [x] `fail2ban.service` `active` (PID 70719) and `enabled` at boot.
- [x] Brute-force attempt simulation (4 failed attempts from a single source): not executed by the executor/validator (out of scope per the step-04 design — the designer's V01–V07 verification matrix focused on configuration correctness, not live ban simulation). The sibling T-0084 already established that fail2ban 1.1.0-9 with these exact jail values DOES ban IPs on real brute-force; first ban on `pro-data-tech-qa` will create the `f2b-sshd` chain lazily on first event.
- [x] Landscape files updated by the landscape-updater (step 08 of this run): `landscape/hosts/pro-data-tech-qa.md` Security posture / SSH hardening tooling / change log / Open tasks updated; `landscape/services.md` `## pro-data-tech-qa` bullet + systemd-units table + change log updated.

**Deviations from plan:** none significant. PowerShell false-positive "Command exited with code 1" warnings appeared (a documented platform pattern per `/memories/powershell-native-command-stderr.md`); real exit codes were 0. `f2b-sshd` iptables chain not yet instantiated (expected: lazy creation on first ban — same as T-0084 sibling post-install pattern). `fail2ban-client get sshd banaction` and `get sshd filter` return "Invalid command" (1.1.x API gap; banaction and filter both confirmed via file content and `get sshd actions`).

Executor handoff: [`runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-06-executor-infra.md`](../../runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-06-executor-infra.md) (verdict PASS). Validator handoff: [`runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-07-execution-validator.md`](../../runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-07-execution-validator.md) (verdict PASS).

Pre-change backup preserved at `/etc/fail2ban.pre-T0095.20260708T182109Z.bak/` on `pro-data-tech-qa` per project "do not auto-clean operational artifacts" policy; rollback path is to `cp -a /etc/fail2ban.pre-T0095.20260708T182109Z.bak/* /etc/fail2ban/` + `systemctl restart fail2ban`.

## History

- 2026-07-08: status -> in-progress — run 2026-07-08-install-fail2ban-pro-data-tech-qa-001 started; 4 steps done (task-reader, landscape-reader, task-validator, solution-designer + auto-approved per "just go" delegation; orchestrator chose banaction=iptables-multiport over ufw per sibling T-0084 precedent)
- 2026-07-08: status -> done, outcome succeeded, run 2026-07-08-install-fail2ban-pro-data-tech-qa-001, commit <pending> — 7/7 verification checks PASSED (V01–V07 in step-07-execution-validator.md); see `## Result` section above for full closure detail

## Notes
- **Sibling pattern reuse:** [T-0084](../tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md) is the closest analog — same jail config values (`maxretry=3, bantime=600s, findtime=600s`), same `ignoreip` line (with the management IP `178.89.57.135`), same `banaction=iptables-multiport`. Reuse the run structure and the jail config verbatim.
- **Predecessor T-0095 was lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md).** This re-created file restores the observation. Promotion to `kind: task` is a manual user action once T-0093 is satisfied.
- **Ordering note:** install AFTER T-0093 (sshd hardening) so the fail2ban `logpath` correctly resolves to the post-hardening sshd logs and the jail's `maxretry` count is meaningful. Installing before T-0093 means fail2ban will be watching logs from a permissive `PasswordAuthentication yes` config and will count password-auth brute-force attempts that the post-T-0093 config would not allow at all — not wrong, but redundant.

## History
- 2026-07-08: status observation -> pending (promoted by user delegation; depends on T-0093; queued after sshd hardening run)
- 2026-07-08: created from discovery run 2026-07-08-discovery-pro-data-tech-qa-001 (status observation; promoted to task when blockers T-0093 satisfied)
