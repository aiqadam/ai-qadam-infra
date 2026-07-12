---
id: T-0102-harden-sshd-on-pro-data-tech-prod
title: Harden sshd on pro-data-tech-prod (PermitRootLogin prohibit-password, PasswordAuthentication no, AllowGroups sshusers, MaxAuthTries 3, LoginGraceTime 30)
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-harden-sshd-pro-data-tech-prod-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
workflow: infrastructure
blocks: []
blocked_by: [T-0101]
related: [T-0093]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Harden sshd on pro-data-tech-prod

## Why
Fresh cloud VMs typically ship with permissive SSH defaults (PasswordAuthentication yes, PermitRootLogin yes, weak KEX algorithms). The QA counterpart was hardened identically via T-0093. This task applies the same hardening profile to the new production host.

## What done looks like
- [ ] `PermitRootLogin prohibit-password` (key-only root login; password login blocked)
- [ ] `PasswordAuthentication no` and `KbdInteractiveAuthentication no`
- [ ] `PubkeyAuthentication yes`
- [ ] `AllowGroups sshusers` (operator users added to group before this is applied)
- [ ] `MaxAuthTries 3`
- [ ] `LoginGraceTime 30`
- [ ] `X11Forwarding no`
- [ ] `UseDNS no`
- [ ] Weak KEX / ciphers / MACs removed
- [ ] sshd config validated with `sshd -t` before reload
- [ ] sshd reloaded, active SSH session preserved throughout
- [ ] 20+ verification checks passed

## Result

sshd hardened on `pro-data-tech-prod` (`95.46.211.224`) via run `2026-07-11-harden-sshd-pro-data-tech-prod-001`. All 25/25 executor checks passed; independently verified by execution-validator (25/25).

**What was done:**
- `sshusers` group (gid 1000) created; `root` added as sole member (transitional — root must remain in `sshusers` until T-0105 provisions operator users).
- Drop-in `40-disable-password.conf` written: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`.
- Drop-in `40-ai-dala-infra.conf` written: `PermitRootLogin prohibit-password`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, `AllowGroups sshusers`, hardened KexAlgorithms/Ciphers/MACs.
- Both drop-ins: mode 644, owner root.
- `sshd -t` hard gate: PASSED. Root-in-sshusers hard gate: PASSED.
- `systemctl reload sshd` applied. Session preserved throughout.
- Password auth rejection confirmed from external probe.
- Pre-change backup: `/var/backups/pre-T0102.` (no timestamp due to PowerShell `date` expansion bug; backup is valid and complete).

**Checklist against "What done looks like":**
- [x] `PermitRootLogin prohibit-password`
- [x] `PasswordAuthentication no` and `KbdInteractiveAuthentication no`
- [x] `PubkeyAuthentication yes`
- [x] `AllowGroups sshusers`
- [x] `MaxAuthTries 3`
- [x] `LoginGraceTime 30`
- [x] `X11Forwarding no`
- [x] `UseDNS no` (default; confirmed via `sshd -T`)
- [x] Weak KEX / ciphers / MACs removed
- [x] sshd config validated with `sshd -t` before reload
- [x] sshd reloaded, active SSH session preserved throughout
- [x] 25/25 verification checks passed (exceeded 20+ target)

**Deviations:** none material. Drop-in named `40-ai-dala-infra.conf` (QA fleet convention per T-0093) rather than `40-harden-sshd.conf`. Backup directory has no timestamp (PowerShell expansion bug; backup is valid).

**Executor handoff:** [runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-06-executor-infra.md](../runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-06-executor-infra.md)
**Validator handoff:** [runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-07-execution-validator.md](../runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-07-execution-validator.md)

## Notes
- Model after T-0093 / run `2026-07-08-harden-sshd-pro-data-tech-qa-001` (21/21 checks passed)
- Must create `sshusers` group and add root to it BEFORE setting `AllowGroups sshusers`, or root will be locked out
- Drop-in file pattern: `/etc/ssh/sshd_config.d/` — do not overwrite the main config file

## History
- 2026-07-11: created manually by orchestrator
- 2026-07-11: status → in-progress — run 2026-07-11-harden-sshd-pro-data-tech-prod-001 started
- 2026-07-11: status → done, outcome succeeded, run 2026-07-11-harden-sshd-pro-data-tech-prod-001, commit <pending>
