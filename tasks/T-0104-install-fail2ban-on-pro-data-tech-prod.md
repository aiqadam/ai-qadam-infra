---
id: T-0104-install-fail2ban-on-pro-data-tech-prod
title: Install fail2ban with sshd jail on pro-data-tech-prod
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-install-fail2ban-pro-data-tech-prod-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: [T-0101]
related: [T-0095]
estimated_blast_radius: low
estimated_reversibility: full
---

# Install fail2ban with sshd jail on pro-data-tech-prod

## Why
SSH brute-force protection. fail2ban monitors auth logs and bans IPs that exceed failed-auth thresholds. The QA instance was configured identically via T-0095. This task applies the same configuration to the production host.

## What done looks like
- [ ] fail2ban installed (`apt-get install fail2ban`)
- [ ] `/etc/fail2ban/jail.local` created with `[sshd]` jail enabled, `bantime = 1h`, `findtime = 10m`, `maxretry = 5`
- [ ] fail2ban service enabled and started
- [ ] `fail2ban-client status sshd` shows jail is active
- [ ] `fail2ban-client status` shows 1 jail loaded

## Result

All acceptance criteria met per step-07 PASS (run `2026-07-11-install-fail2ban-pro-data-tech-prod-001`):

- [x] fail2ban 1.1.0-9 installed via `apt-get install fail2ban`
- [x] `/etc/fail2ban/jail.local` created with `[sshd]` jail enabled, `bantime = 1h`, `findtime = 10m`, `maxretry = 5`, `ignoreip = 127.0.0.1/8 ::1`
- [x] fail2ban service enabled (`systemctl is-enabled` → `enabled`) and started (`systemctl is-active` → `active`)
- [x] `fail2ban-client status sshd` confirms jail active; `Currently banned: 0`; journal backend `_SYSTEMD_UNIT=ssh.service + _COMM=sshd`
- [x] `fail2ban-client status` shows 1 jail loaded (`Jail list: sshd`)

Deviation: management workstation IP (`178.89.57.135`) not added to `ignoreip` (localhost-only list per execution parameters). Pre-documented in step-04 and step-06; impact low. See step-07 Issues / risks.

Executor handoff: [runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-06-executor-infra.md](../runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-06-executor-infra.md)
Validator handoff: [runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-07-execution-validator.md](../runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-07-execution-validator.md)
- Model after T-0095 / run `2026-07-08-install-fail2ban-pro-data-tech-qa-001`
- Must be installed AFTER UFW (T-0103) so fail2ban's iptables rules interact correctly with the UFW chain
- Consider whether to also add an nginx jail if nginx is confirmed running on this host (T-0101 discovery will determine)

## History
- 2026-07-11: created manually by orchestrator
- 2026-07-11: status → in-progress — run 2026-07-11-install-fail2ban-pro-data-tech-prod-001 started
- 2026-07-11: status → done, outcome succeeded, run 2026-07-11-install-fail2ban-pro-data-tech-prod-001, commit <pending>
