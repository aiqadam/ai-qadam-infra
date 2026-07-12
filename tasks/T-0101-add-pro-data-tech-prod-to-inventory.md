---
id: T-0101-add-pro-data-tech-prod-to-inventory
title: Add new pro-data.tech server 95.46.211.224 (prod instance) to inventory via discovery
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-discovery-pro-data-tech-prod-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
workflow: discovery-host
blocks: [T-0102, T-0103, T-0104, T-0105]
blocked_by: []
related: [T-0090]
estimated_blast_radius: low
estimated_reversibility: full
---

# Add new pro-data.tech server 95.46.211.224 (prod instance) to inventory via discovery

## Why
A second pro-data.tech server at `95.46.211.224` (SSH key `pro-data.tech-prod-instance_rsa.*`) has been provisioned. Before any security hardening can be applied, the host must be enumerated and added to the landscape inventory. The QA counterpart (`pro-data-tech-qa`, `95.46.211.230`) was handled similarly via T-0090 and its sub-tasks. This task runs the read-only discovery probe to capture OS, hardware, users, services, network, and firewall state.

## What done looks like
- [ ] `landscape/hosts/pro-data-tech-prod.md` created and populated with current host state
- [ ] `landscape/services.md` updated with any running services discovered
- [ ] sshd config, OS version, kernel, users, and firewall state recorded
- [ ] Open security gaps identified and surfaced as observation tasks (T-0102 through T-0105 pre-created)

## Result

All four "What done looks like" checklist items met:
- `landscape/hosts/pro-data-tech-prod.md` created and fully populated (hostname `drkkrgm-prod-instance`, IP `95.46.211.224`, OS Ubuntu 26.04 LTS kernel `7.0.0-14-generic`, 16 vCPU / 32 GiB RAM / 339 GB disk, dual NIC eth0+eth1).
- `landscape/services.md` updated with `## pro-data-tech-prod` section (placeholder — no application services present on a fresh image).
- sshd config (`PermitRootLogin yes`, `PasswordAuthentication yes`), OS version, kernel, users (root only), and firewall state (UFW inactive, iptables all-ACCEPT) recorded in the host file.
- 5 CRITICAL/HIGH security gaps identified and surfaced; tracked as T-0102 through T-0105 (pre-created by orchestrator before this run).

See executor handoff: [runs/2026-07-11-discovery-pro-data-tech-prod-001/step-06-executor-discovery.md](../runs/2026-07-11-discovery-pro-data-tech-prod-001/step-06-executor-discovery.md)
See validator handoff: [runs/2026-07-11-discovery-pro-data-tech-prod-001/step-07-execution-validator.md](../runs/2026-07-11-discovery-pro-data-tech-prod-001/step-07-execution-validator.md)

Notable finding beyond the checklist: `eth1 192.168.0.3/24` private LAN NIC is present on the prod host but absent on the QA host — likely a provider-managed private network between the two servers. No QA deviation; documented in the host file Network section.

## Notes
- SSH access: `root@95.46.211.224` using key `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (same naming convention as QA key — likely OpenSSH RSA despite `.ppk` extension)
- This host is on the same pro-data.tech subnet as the QA instance (`95.46.211.224/25` subnet)
- No Hetzner Cloud Firewall equivalent; host will rely on UFW + fail2ban for security (same architecture as QA)

## History
- 2026-07-11: created manually by orchestrator in response to user request to prepare host from security POV
- 2026-07-11: status -> done, outcome succeeded, run 2026-07-11-discovery-pro-data-tech-prod-001, commit <pending>
