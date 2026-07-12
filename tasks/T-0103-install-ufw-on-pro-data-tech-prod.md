---
id: T-0103-install-ufw-on-pro-data-tech-prod
title: Install local baseline firewall on pro-data-tech-prod (UFW deny-incoming, allow 22/tcp, allow 80/tcp, allow 443/tcp)
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-install-ufw-pro-data-tech-prod-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: [T-0101]
related: [T-0094]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Install local baseline firewall on pro-data-tech-prod

## Why
pro-data.tech has no Hetzner Cloud Firewall equivalent. The only host-level protection is UFW. The QA instance was similarly configured via T-0094. This task applies the same deny-incoming baseline with explicit allows for SSH/HTTP/HTTPS to the production host.

## What done looks like
- [ ] UFW installed (`apt-get install ufw`)
- [ ] `DEFAULT_FORWARD_POLICY="DROP"` set in `/etc/default/ufw` (Docker-safe: Docker manages its own iptables rules independently)
- [ ] `ufw default deny incoming`
- [ ] `ufw default allow outgoing`
- [ ] `ufw allow 22/tcp` (SSH — must be applied before enable to avoid lockout)
- [ ] `ufw allow 80/tcp`
- [ ] `ufw allow 443/tcp`
- [ ] `ufw --force enable`
- [ ] `ufw status verbose` shows expected rules
- [ ] SSH access verified after enable

## Result

UFW installed (already present) and activated on `pro-data-tech-prod` (95.46.211.224) via run `2026-07-11-install-ufw-pro-data-tech-prod-001`. All checklist items completed:

- [x] UFW installed (`apt-get install ufw` — already newest version, idempotent)
- [x] `DEFAULT_FORWARD_POLICY="DROP"` confirmed in `/etc/default/ufw` (Ubuntu 26.04 cloud image default; sed no-op, verified)
- [x] `ufw default deny incoming`
- [x] `ufw default allow outgoing`
- [x] `ufw allow 22/tcp` (applied before enable; no lockout)
- [x] `ufw allow 80/tcp`
- [x] `ufw allow 443/tcp`
- [x] `ufw --force enable`
- [x] `ufw status verbose` confirmed: Status: active, deny incoming, allow outgoing, 22/80/443 ALLOW IN (v4+v6)
- [x] SSH access verified via new TCP connection after enable (no lockout)

Executor handoff: [`runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-06-executor-infra.md`](../runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-06-executor-infra.md)
Validator handoff: [`runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-07-execution-validator.md`](../runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-07-execution-validator.md)

No deviations from the "What done looks like" checklist.

## Notes
- Model after T-0094 / run `2026-07-08-install-ufw-pro-data-tech-qa-001`
- Must allow 22/tcp BEFORE enabling UFW to avoid lockout
- If Docker is present on this host, note the DEFAULT_FORWARD_POLICY divergence (Docker uses its own iptables chain, not UFW FORWARD; setting DROP here does not break Docker networking)
- Discovery run (T-0101) will reveal whether Docker is installed on this host

## History
- 2026-07-11: created manually by orchestrator
- 2026-07-11: status → in-progress — run 2026-07-11-install-ufw-pro-data-tech-prod-001 started
- 2026-07-11: status → done, outcome succeeded, run 2026-07-11-install-ufw-pro-data-tech-prod-001, commit <pending>
