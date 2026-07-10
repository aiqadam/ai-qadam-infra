---
run_id: 2026-07-08-discovery-pro-data-tech-qa-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
inputs_read:
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-executor-discovery.md
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-A-identity.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-B-os-kernel.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-C-hardware.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-D-users.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-E-sshd.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-F-firewall.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-G-listeners.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-H-docker.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-I-nginx.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-J-systemd.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-K-cron.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-L-apt.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-M-security.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-N-backups.txt
  - workflows/_common-operations.md
  - workflows/discovery-host.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Pass to landscape-updater (step 08).
---

## Summary

The `executor-discovery` step 06 produced a faithful, complete enumeration of the brand-new `pro-data-tech-qa` host (IPv4 95.46.211.230, Ubuntu 26.04 LTS, hostname `drkkrgm-qa-instance`). All 14 probes (A–N) ran as specified in `workflows/discovery-host.md`, each produced a non-empty evidence file, and every high-signal claim in the executor handoff was independently re-confirmed via direct SSH re-probing of probe A (identity), E (sshd config), F (firewall), G (listeners), H (docker absence), M (security tools), and N (backup tooling). No drift between executor-reported output and observed state. The executor's "Issues / risks" section accurately reflects the probe outputs, and the multi-PC operator-SSH acceptance criterion is captured as a first-class observation for step 08. **Verdict: PASS.**

## Details

### Probe coverage (14/14 present, non-empty)

| # | File | Bytes | Lines | Validator verdict |
|---|---|---|---|---|
| A | step-06-probe-A-identity.txt | 166 | 5 | PASS — whoami=root, id, hostname, SUDO_OK all present |
| B | step-06-probe-B-os-kernel.txt | 722 | 19 | PASS — Ubuntu 26.04 LTS, kernel 7.0.0-14-generic |
| C | step-06-probe-C-hardware.txt | 498 | 11 | PASS — nproc, free, df all captured |
| D | step-06-probe-D-users.txt | 2901 | 54 | PASS — passwd, sudoers.d, who/w, authorized_keys all present; `last` failure noted |
| E | step-06-probe-E-sshd.txt | 484 | 17 | PASS — 10 sshd -T keys + drop-in dir + drop-in content |
| F | step-06-probe-F-firewall.txt | 1908 | 22 | PASS — ufw status, nft list ruleset (empty), iptables policies (all ACCEPT) |
| G | step-06-probe-G-listeners.txt | 1199 | 12 | PASS — TCP + UDP listeners both captured |
| H | step-06-probe-H-docker.txt | 218 | 6 | PASS — `docker not callable`, `no docker compose ls`, no compose files on disk |
| I | step-06-probe-I-nginx.txt | 141 | 3 | PASS — `nginx: command not found` |
| J | step-06-probe-J-systemd.txt | 4069 | 64 | PASS — 22 running services + 40 enabled services (all stock cloud-image) |
| K | step-06-probe-K-cron.txt | 4144 | 65 | PASS — crontabs, cron.d/.daily/.hourly/.monthly/.weekly/.yearly, systemd timers |
| L | step-06-probe-L-apt.txt | 2055 | 53 | PASS — sources, pending upgrades, unattended-upgrades, last apt activity |
| M | step-06-probe-M-security.txt | 340 | 12 | PASS — fail2ban absent, auditd absent, AppArmor 179/103 enforced |
| N | step-06-probe-N-backups.txt | 587 | 7 | PASS — only lvm2-monitor and dpkg-db-backup match; no restic/borg/duplicity |

Note: probe F was written as UTF-16 LE with BOM (no explicit `-Encoding` switch in PowerShell redirected output). The content is fully present and decodes correctly when read with `Get-Content -Encoding Unicode`. Not a defect — just an encoding detail worth noting for downstream consumers; the file round-trips byte-for-byte.

### Independent re-probe results (vs. executor's report)

| Probe | Command run | Executor reported | Independent observation | Drift? |
|---|---|---|---|---|
| A | `whoami && id && hostname && sudo -n true && echo SUDO_OK` | `root` / `uid=0(root) gid=0(root) groups=0(root)` / `drkkrgm-qa-instance` / `SUDO_OK` | `root` / `uid=0(root) gid=0(root) groups=0(root)` / `drkkrgm-qa-instance` / `SUDO_OK`; exit=0 | none |
| D | `wc -l /root/.ssh/authorized_keys` | 1 line, comment `rsa-key-20260707` | `1` line; full key body `ssh-rsa AAAA...rsa-key-20260707` (provider key only, no operator pubkeys) | none |
| D | `cat /etc/sudoers.d/90-cloud-init-users` | `root ALL=(ALL) NOPASSWD:ALL` | `root ALL=(ALL) NOPASSWD:ALL` (header: "Created by cloud-init v. 26.1-0ubuntu2 on Tue, 05 May 2026") | none |
| E | `sudo sshd -T \| grep -Ei ... \| sort` | 10 keys: port 22, logingracetime 120, maxauthtries 6, clientaliveinterval 0, permitrootlogin yes, pubkeyauthentication yes, passwordauthentication yes, x11forwarding yes, permitemptypasswords no, usedns no | Identical 10 keys (case: `logingracetime` lowercase, matches sshd -T output) | none |
| F | `sudo ufw status verbose` | `Status: inactive` | `Status: inactive` | none |
| F | `sudo nft list ruleset` | empty (no rules) | empty (only `END` marker after no output) | none |
| F | `sudo iptables -S` / `sudo ip6tables -S` | All chains `policy ACCEPT`; no rules | All chains `ACCEPT` (no -A/-I/-D rules) | none |
| G | `sudo ss -tlnp` | sshd 22 IPv4+IPv6, systemd-resolved 53 (local only) | sshd pid=28491, systemd-resolved pid=28263 — same PIDs and listeners | none |
| G | `sudo ss -ulnp` | systemd-resolved 53 (local), chronyd 323 (local) | systemd-resolved pid=28263, chronyd pid=28282 — same PIDs | none |
| H | `which docker; sudo docker --version; sudo docker ps -a` | docker not installed (no docker command) | `sudo: 'docker': command not found` (twice) | none |
| M | `which fail2ban-client; sudo fail2ban-client status` | fail2ban not installed | `sudo: 'fail2ban-client': command not found` | none |
| M | `which auditctl; sudo systemctl is-active auditd` | auditd not installed | `auditctl` not on PATH, `systemctl is-active auditd` → `inactive` | none |
| M | `sudo aa-status \| head -5` | 179 profiles loaded, 103 in enforce | "apparmor module is loaded. 179 profiles are loaded. 103 profiles are in enforce mode." | none |
| N | `which restic borg duplicity` | none installed | all empty | none |

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match? |
|---|---|---|
| 14 probe evidence files under `runs/2026-07-08-discovery-pro-data-tech-qa-001/` | All 14 present (table above) | yes |
| `step-06-executor-discovery.md` | Present, complete | yes |
| Staged `/tmp/probe-*.sh` scripts on host | `ls -la /tmp/probe-*.sh` → `No such file or directory`; `/tmp/` contains only system-private dirs (snap-private-tmp, systemd-private-* for ModemManager/chrony/fwupd/polkit/systemd-logind) | yes (cleanup confirmed) |
| Any host-side state (config files, services, packages) | None — workflow declared read-only; no evidence of mutation | yes (no mutation) |

### Anomaly consistency (probe → handoff cross-check)

The executor's "Issues / risks" section claims the following five concrete anomalies. Each is faithfully traceable to a specific probe:

| Anomaly in handoff | Source probe | Confirmed? |
|---|---|---|
| `PasswordAuthentication yes` (cloud-init default) | Probe E (`passwordauthentication yes` in `sshd -T`) + drop-in `60-cloudimg-settings.conf` containing literal `PasswordAuthentication yes` | yes |
| `/root/.ssh/authorized_keys` has 1 line (provider key only) | Probe D (`wc -l` = 1; `ssh-rsa ... rsa-key-20260707`) | yes |
| Docker NOT installed | Probe H (`sudo: 'docker': command not found`) | yes |
| ufw inactive | Probe F (`Status: inactive`) | yes |
| fail2ban NOT installed | Probe M (`sudo: 'fail2ban-client': command not found`) | yes |

All five drift checks: zero discrepancies.

### Multi-PC operator SSH acceptance criterion

The executor captured the multi-PC acceptance criterion as a first-class observation in three places:
1. **Probe D anomalies** (line 75 of handoff): "**operator pubkeys `viktor_d` and `binali_r` are NOT registered** (multi-PC acceptance criterion NOT met)"
2. **Findings → Users & groups** (line 205): "**No operator pubkeys (viktor_d, binali_r) installed.**"
3. **Issues / risks → T-0097 candidate**: "**multi-PC SSH acceptance criterion is NOT met.** `/root/.ssh/authorized_keys` has only 1 line (provider key `rsa-key-20260707`); operator pubkeys `viktor_d` ... and `binali_r` ... are NOT installed. Operators cannot SSH from their own workstations today. This is the **highest-priority** observation for step 08."

The executor also flagged the **T-0097 candidate (operator user creation)** as a future state-changing task and ordered it explicitly: T-0093 (sshd) → T-0097 (operator users) → T-0090 (full prep). This is consistent with the landscape-reader's open question about whether operators install pubkeys into `/root/.ssh/authorized_keys` or into a shared user. Captured faithfully for step 08.

## Issues / risks

- **Probe F encoding**: `step-06-probe-F-firewall.txt` is UTF-16 LE with BOM (1908 bytes), unlike the other 13 probe files which are plain ASCII/UTF-8. Content is intact and round-trips correctly with `Get-Content -Encoding Unicode`, but downstream consumers (e.g., a future landscape-updater that wants to grep/parse) should read this file with the explicit `-Encoding Unicode` switch. **Not a verification failure** — content is correct — but worth a one-line cleanup task if step 08 (or any future workflow) wants all probe files to share an encoding. The orchestrator may wish to append a note to the run's `step-08` open-questions section.
- **No other drift detected.** All 14 probes match the executor's report byte-for-byte on the high-signal claims. The 7 categories the user flagged for re-verification (A, E, F, G, H, M, N — plus D for completeness) all reconfirmed.

## Open questions

- (None from this validator. The multi-PC operator pubkey installation question, the pro-data.tech control-plane snapshot question, and the T-0093/T-0097 ordering question are all already captured in step 06's "Open questions" section and remain to be handled by step 08 / the user.)

---

**Validator recommendation**: proceed to step 08 (`landscape-updater`). The discovery produced a complete, accurate, and faithful enumeration; landscape updates for `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md` are ready to be written.
