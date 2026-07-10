---
id: T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
title: Install fail2ban with SSH default jail on ubuntu-16gb-nbg1-1
kind: task
status: done
priority: P1
created: 2026-06-27
updated: 2026-06-27
closed: 2026-06-27
outcome: succeeded
created_by: orchestrator
source_runs: []
executed_by_runs:
  - 2026-06-27-install-fail2ban-001
affects:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1
  - T-0005-install-fail2ban
estimated_blast_radius: low
estimated_reversibility: full
---

# Install fail2ban with SSH default jail on ubuntu-16gb-nbg1-1

## Why
The new host `ubuntu-16gb-nbg1-1` (46.225.239.60, project `ai-qadam`) was provisioned 2026-06-27 and now has UFW active with port 22 open to the public internet (T-0083). SSH PasswordAuthentication was not disabled on this host yet, and even if it is disabled in the future, internet-facing SSH without brute-force protection is constant noise and attack surface. This task mirrors T-0005 (fail2ban install on hetzner-prod) to apply the same SSH jail pattern on the new host.

## What done looks like
- [x] `fail2ban` package installed via apt.
- [x] `/etc/fail2ban/jail.d/sshd.local` exists with `[sshd] enabled = true`, maxretry=3, bantime=600s, findtime=600s, ignoreip including management workstation IP.
- [x] `systemctl status fail2ban` shows `Active: active (running)`.
- [x] `fail2ban-client status sshd` shows the jail loaded with `Currently failed:` / `Currently banned:` fields.
- [x] Management workstation IP confirmed before writing to `ignoreip` (run `curl https://ifconfig.me` from workstation and verify).
- [x] `landscape/hosts/ubuntu-16gb-nbg1-1.md` security tools section updated with fail2ban details.

## Result
fail2ban 1.1.0-9 installed via apt on ubuntu-16gb-nbg1-1 (46.225.239.60, project ai-qadam). sshd jail configured at `/etc/fail2ban/jail.d/sshd.local` with maxretry=3, bantime=600s, findtime=600s, banaction=iptables-multiport. Management workstation outbound IP `178.89.57.135` in `ignoreip` (live-verified via `https://api.ipify.org` from workstation — distinct from prod's `5.250.151.158`). Service enabled at boot and active. Jail confirmed loaded with `f2b-sshd` chain installed in iptables (`tcp, multiport dports 22`). 2 IPs already banned at install from journal-history import: `14.103.127.232`, `45.148.10.240`. External BatchMode SSH from management workstation succeeded (`echo ok`), proving the workstation is not self-banned. No deviations from "What done looks like". See [step-06 executor handoff](../../runs/2026-06-27-install-fail2ban-001/step-06-executor-infra.md) and [step-07 validator handoff](../../runs/2026-06-27-install-fail2ban-001/step-07-execution-validator.md). Landscape files updated: [`landscape/hosts/ubuntu-16gb-nbg1-1.md`](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) (SSH hardening tooling line + "What needs to happen" item #5 + change-log row), [`landscape/services.md`](../../landscape/services.md) (added `fail2ban.service` row; updated `ufw.service` row from "inactive" to "active").

## Notes
- New host runs Ubuntu 26.04 (not 24.04 like prod) — fail2ban package and iptables backend behavior may differ slightly. Executor must check apt repository availability and the active iptables backend before installing.
- Ignoreip must include the management workstation outbound IP, verified at run time (do not hardcode `5.250.151.158` without confirming).
- This task is infrastructure-blocker-level for SSH hardening on the new host. UFW is already in place (T-0083); fail2ban is the second layer.

## History
- 2026-06-27: created
- 2026-06-27: status → in-progress — run 2026-06-27-install-fail2ban-001 started
- 2026-06-27: status → done — run 2026-06-27-install-fail2ban-001 succeeded (commit pending)