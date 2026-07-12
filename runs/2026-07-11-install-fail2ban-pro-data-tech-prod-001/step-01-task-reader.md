---
run_id: 2026-07-11-install-fail2ban-pro-data-tech-prod-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0104-install-fail2ban-on-pro-data-tech-prod
inputs_read:
  - tasks/T-0104-install-fail2ban-on-pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader (step 02) — read landscape/hosts/pro-data-tech-prod.md and cross-check T-0095 run for reference config
---

## Summary

Task T-0104 is `in-progress` with a clear scope: install fail2ban on `pro-data-tech-prod` (95.46.211.224) with a single `[sshd]` jail, modelled exactly on the QA precedent (T-0095). Workflow is `infrastructure`. Blast radius is LOW and reversibility is FULL.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md`
  - `landscape/services.md`
- **Why (verbatim from task):** SSH brute-force protection. fail2ban monitors auth logs and bans IPs that exceed failed-auth thresholds. The QA instance was configured identically via T-0095. This task applies the same configuration to the production host.
- **Acceptance criteria (from "What done looks like"):**
  1. fail2ban installed via `apt-get install fail2ban`
  2. `/etc/fail2ban/jail.local` created with `[sshd]` jail enabled, `bantime = 1h`, `findtime = 10m`, `maxretry = 5`
  3. fail2ban service enabled and started
  4. `fail2ban-client status sshd` shows jail is active
  5. `fail2ban-client status` shows 1 jail loaded
- **Constraints stated by user:**
  - No nginx on this host — sshd jail only (do not add nginx jail)
  - Must run after UFW is active (T-0103 done) so fail2ban iptables rules interact correctly with the UFW chain
  - sshd is already hardened (T-0102 done)
  - Reference implementation: T-0095 / run `2026-07-08-install-fail2ban-pro-data-tech-qa-001`
- **Information gaps for downstream steps:**
  - Exact current state of the host (packages installed, existing fail2ban presence if any) — landscape-reader and executor should verify with `dpkg -l fail2ban` before installing
  - SSH port in use (T-0102 harden-sshd may have changed it from 22) — executor should confirm from landscape or sshd_config before writing jail.local

## Issues / risks

- Blast radius is LOW: fail2ban only bans IPs on new connection failures; existing SSH sessions are unaffected. Service can be stopped or IPs unbanned instantly with `fail2ban-client` if needed.
- Risk of inadvertent self-lockout is near-zero since operator is already authenticated; fail2ban does not kill existing connections.
