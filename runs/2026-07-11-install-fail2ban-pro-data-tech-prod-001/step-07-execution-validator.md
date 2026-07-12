---
run_id: 2026-07-11-install-fail2ban-pro-data-tech-prod-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0104-install-fail2ban-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: proceed to landscape-updater (step 08)
---

## Summary

End state verified: fail2ban 1.1.0-9 is installed, active, and enabled on `pro-data-tech-prod` (95.46.211.224) with one jail (`sshd`) running with `bantime=1h`, `findtime=10m`, `maxretry=5` — all primary acceptance criteria satisfied.

## Details

### On-host checks

| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| dpkg shows fail2ban installed (`ii`) | `dpkg -l fail2ban 2>/dev/null` | `ii  fail2ban  1.1.0-9  all  ban hosts that cause multiple authentication errors` | yes |
| `systemctl is-active fail2ban` returns `active` | `systemctl is-active fail2ban` | `active` | yes |
| `systemctl is-enabled fail2ban` returns `enabled` | `systemctl is-enabled fail2ban` | `enabled` | yes |
| `fail2ban-client status` shows 1 jail named `sshd` | `fail2ban-client status` | `Number of jail: 1`, `Jail list: sshd` | yes |
| `fail2ban-client status sshd` shows jail active, `Currently banned: 0` | `fail2ban-client status sshd` | Filter active, `Currently banned: 0`, `Total banned: 0`, `Journal matches: _SYSTEMD_UNIT=ssh.service + _COMM=sshd` | yes |
| `jail.local` contains `bantime = 1h`, `findtime = 10m`, `maxretry = 5`, `enabled = true` | `cat /etc/fail2ban/jail.local` | All four values present under `[sshd]` — exact match | yes |
| `grep "ignoreip" /etc/fail2ban/jail.local` includes `127.0.0.1/8` | `cat /etc/fail2ban/jail.local` | `ignoreip = 127.0.0.1/8 ::1` — `127.0.0.1/8` present | yes |
| `ignoreip` also includes management workstation IP (`178.89.57.135`) | `cat /etc/fail2ban/jail.local` | Management IP **not** present — pre-acknowledged deviation; task execution parameters specified localhost-only | noted (see Issues / risks) |

**Full observed `jail.local` content:**
```
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
backend = %(sshd_backend)s
bantime = 1h
findtime = 10m
maxretry = 5
```

### External checks

N/A — fail2ban is a host-side daemon with no externally observable HTTP/DNS surface. This was pre-declared in the designer's plan: the "two places" requirement is satisfied by (1) service status and (2) `fail2ban-client` jail status.

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| `root@95.46.211.224:/etc/fail2ban/jail.local` (created new) | File exists with expected content | yes |
| `fail2ban.service` restarted | Service is `active` and `enabled` | yes |

## Issues / risks

- **Management workstation IP (`178.89.57.135`) absent from `ignoreip`:** The task execution parameters overrode the designer's `ignoreip` template and specified `127.0.0.1/8 ::1` only. This is a pre-documented deviation (noted in both step-04 and step-06 handoffs). Impact: low — the management workstation could be banned after 5 failed SSH attempts, but existing sessions are unaffected and `fail2ban-client unban 178.89.57.135` resolves it instantly. Core brute-force protection functionality is unimpaired. No remediation required unless the operator prefers to add their IP.
- **12 pending apt upgrades on prod (including kernel):** pre-existing, not introduced by this run, not a blocker. Carried forward from executor's issues.
