---
run_id: 2026-07-11-install-ufw-pro-data-tech-prod-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-11T06:10:00Z
task_id: T-0103-install-ufw-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: proceed to landscape-updater (step 08)
---

## Summary

All 5 verification checks passed independently — UFW is active on `pro-data-tech-prod` (95.46.211.224) with deny-incoming defaults, explicit ALLOW rules for 22/tcp, 80/tcp, and 443/tcp, `DEFAULT_FORWARD_POLICY="DROP"`, and the pre-run backup confirmed present; executor's resources-changed list fully reconciles with observed state.

## Details

### On-host checks

| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| UFW status active | `ufw status verbose` | `Status: active` | yes |
| Default deny incoming | `ufw status verbose` | `Default: deny (incoming), allow (outgoing), disabled (routed)` | yes |
| 22/tcp ALLOW IN (v4+v6) | `ufw status verbose` | `22/tcp ALLOW IN Anywhere` + `22/tcp (v6) ALLOW IN Anywhere (v6)` | yes |
| 80/tcp ALLOW IN (v4+v6) | `ufw status verbose` | `80/tcp ALLOW IN Anywhere` + `80/tcp (v6) ALLOW IN Anywhere (v6)` | yes |
| 443/tcp ALLOW IN (v4+v6) | `ufw status verbose` | `443/tcp ALLOW IN Anywhere` + `443/tcp (v6) ALLOW IN Anywhere (v6)` | yes |
| DEFAULT_FORWARD_POLICY="DROP" | `grep DEFAULT_FORWARD_POLICY /etc/default/ufw` | `DEFAULT_FORWARD_POLICY="DROP"` | yes |
| systemctl is-active ufw | `systemctl is-active ufw` | `active` | yes |
| Backup file present | `ls -la /var/backups/ufw-defaults-pre-T0103.bak` | `-rw-r--r-- 1 root root 1897 Jul 11 05:45 /var/backups/ufw-defaults-pre-T0103.bak` | yes |
| SSH session live | `echo SSH-LIVE-OK` via new TCP connection | `SSH-LIVE-OK` | yes |

### External checks

| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| SSH port reachable from validator | `ssh root@95.46.211.224 "echo SSH-LIVE-OK"` (new connection, exit 0) | `SSH-LIVE-OK` exit 0 | `SSH-LIVE-OK` exit 0 | yes |

*Note: HTTP/HTTPS external probes are out of scope for T-0103 (UFW install only — no web service is yet deployed on this host). Port 22 is the only service in use at this stage.*

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| `host:95.46.211.224:/var/backups/ufw-defaults-pre-T0103.bak` | Present: `-rw-r--r-- 1 root root 1897 Jul 11 05:45` | yes |
| `host:95.46.211.224:/etc/default/ufw` | `DEFAULT_FORWARD_POLICY="DROP"` confirmed | yes |
| `host:95.46.211.224:ufw-rules (22/tcp, 80/tcp, 443/tcp ALLOW IN)` | All three rules present v4+v6 in `ufw status verbose` | yes |
| `host:95.46.211.224:ufw-status (inactive → active)` | `Status: active` | yes |

## Issues / risks

- none

## Open questions

none
