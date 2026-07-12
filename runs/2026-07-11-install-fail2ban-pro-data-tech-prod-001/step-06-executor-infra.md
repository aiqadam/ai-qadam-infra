---
run_id: 2026-07-11-install-fail2ban-pro-data-tech-prod-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-11T12:00:00Z
task_id: T-0104-install-fail2ban-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - root@95.46.211.224:/etc/fail2ban/jail.local
next_step_hint: proceed to execution-validator (step 07)
---

## Summary

Executed all 7 plan steps successfully. fail2ban 1.1.0-9 is installed, enabled, and active on `pro-data-tech-prod` (95.46.211.224) with one jail (`sshd`) loaded, `Currently banned: 0`, and journal-based log matching via `_SYSTEMD_UNIT=ssh.service + _COMM=sshd`.

## Details

### Pre-execution checks

- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes — `step-05-user-approval.md` `inputs_read` lists `runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-04-solution-designer.md`

### Execution log

#### Pre-step A: Capture management workstation public IP

- Command: `(Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()`
- Exit code: 0
- Output: `178.89.57.135`
- Result: success
- Note: task execution parameters specified `ignoreip = 127.0.0.1/8 ::1` (localhost-only) rather than including `178.89.57.135`. The IP is recorded here for audit; see Issues / risks.

#### Step 1: Idempotency check — confirm fail2ban absent

- Command: `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" -o StrictHostKeyChecking=accept-new root@95.46.211.224 'dpkg -l fail2ban 2>/dev/null | grep -E "^ii"'`
- Exit code: 1
- Output: (empty — no matching line)
- Result: success — NOT_INSTALLED confirmed, safe to proceed

#### Step 2: Install fail2ban

- Command: `ssh ... 'DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban'`
- Exit code: 0
- Output (trimmed):
  ```
  The following NEW packages will be installed:
    fail2ban python3-pyasyncore python3-pyinotify whois
  0 upgraded, 4 newly installed, 0 to remove and 12 not upgraded.
  Get:1 http://archive.ubuntu.com/ubuntu resolute/universe amd64 fail2ban all 1.1.0-9 [421 kB]
  Setting up fail2ban (1.1.0-9) ...
  Created symlink '/etc/systemd/system/multi-user.target.wants/fail2ban.service' → '/usr/lib/systemd/system/fail2ban.service'.
  ```
- Result: success — fail2ban 1.1.0-9 installed; service symlink auto-created by dpkg
- Backup taken: n/a (new install, no pre-existing state)

#### Step 3: Write /etc/fail2ban/jail.local

- Command: `ssh ... 'cat > /etc/fail2ban/jail.local <<'"'"'EOF'"'"' ... EOF'` (PowerShell here-string)
- Exit code: 0
- Verification (`cat /etc/fail2ban/jail.local`):
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
- Result: success — file content matches specification exactly

#### Step 4: Enable fail2ban service

- Command: `ssh ... 'systemctl enable fail2ban && systemctl is-enabled fail2ban'`
- Exit code: 0
- Output:
  ```
  Synchronizing state of fail2ban.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
  Executing: /usr/lib/systemd/systemd-sysv-install enable fail2ban
  enabled
  ```
- Result: success — `systemctl is-enabled` returns `enabled`

#### Step 5: Restart fail2ban service

- Command: `ssh ... 'systemctl restart fail2ban && systemctl is-active fail2ban'`
- Exit code: 0
- Output: `active`
- Result: success — service active after restart with jail.local loaded

#### Step 6: Verify jail status

- Command: `ssh ... 'fail2ban-client status'`
- Exit code: 0
- Output:
  ```
  Status
  |- Number of jail:      1
  `- Jail list:   sshd
  ```
- Result: success — 1 jail loaded, jail name `sshd`

#### Step 7: Verify sshd jail is active

- Command: `ssh ... 'fail2ban-client status sshd'`
- Exit code: 0
- Output:
  ```
  Status for the jail: sshd
  |- Filter
  |  |- Currently failed: 0
  |  |- Total failed:     0
  |  `- Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
  `- Actions
     |- Currently banned: 0
     |- Total banned:     0
     `- Banned IP list:
  ```
- Result: success — jail active, 0 banned, journal backend matched to `ssh.service + sshd` (expected for Ubuntu 26.04)

### Rollback executed

Not needed — all steps succeeded.

### Resources changed

- Files on host: `/etc/fail2ban/jail.local` (created new at Step 3)
- Services restarted: `fail2ban.service` (restarted at Step 5)
- External resources changed: none

## Issues / risks

- **Management workstation IP not in ignoreip:** The execution task parameters specified `ignoreip = 127.0.0.1/8 ::1` (localhost-only), omitting the management workstation IP `178.89.57.135` that step-04 included. As the step-04 plan notes, this is low-severity (only affects new connections; the active SSH session is unaffected; `fail2ban-client unban <ip>` resolves any accidental ban instantly). If the operator prefers to add their IP, update `ignoreip` in `/etc/fail2ban/jail.local` and `systemctl restart fail2ban`.
- **12 pending apt upgrades on prod (including kernel):** pre-existing, not a blocker. Noted for awareness.
- **Journal backend — no /var/log/auth.log file:** Ubuntu 26.04 uses systemd journal by default; fail2ban's `%(sshd_backend)s` resolved to `systemd`. This is correct and expected; `Journal matches: _SYSTEMD_UNIT=ssh.service + _COMM=sshd` confirms the filter is reading the right source.

## Open questions

none
