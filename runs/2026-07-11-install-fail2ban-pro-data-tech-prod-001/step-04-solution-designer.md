---
run_id: 2026-07-11-install-fail2ban-pro-data-tech-prod-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-11T00:00:00Z
task_id: T-0104-install-fail2ban-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-02-landscape-reader.md
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — NEEDS_APPROVAL; present plan to user before executor proceeds
---

## Summary

Install fail2ban on `pro-data-tech-prod` (95.46.211.224) via apt, write `/etc/fail2ban/jail.local` with a single `[sshd]` jail (`bantime=1h`, `findtime=10m`, `maxretry=5`), enable and start the service, leaving the host with SSH brute-force protection active.

## Details

### Why NEEDS_APPROVAL

`approval-protocol.md` v3 explicitly lists **"package installs"** under "Always requires `NEEDS_APPROVAL`", regardless of blast radius or reversibility. This is a first-time package install on a production host. The five-condition auto-approve check is therefore not applicable.

### Plan

**Pre-step A — Capture management workstation public IP (local, no SSH)**

Command (PowerShell on management workstation):
```powershell
(Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
```
Verification: prints the current outbound IPv4 address. Store this value as `<MGMT_IP>` for use in step 3. (QA precedent used `178.89.57.135`; this may differ at execution time.)

---

**Step 1 — Idempotency check: confirm fail2ban is absent**

Command:
```bash
ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 \
  'dpkg -l fail2ban 2>/dev/null | grep -q "^ii" && echo "ALREADY_INSTALLED" || echo "NOT_INSTALLED"'
```
Verification: output is `NOT_INSTALLED`. If `ALREADY_INSTALLED`, executor must inspect existing config before proceeding and emit a note in the execution handoff.

---

**Step 2 — Install fail2ban**

Command:
```bash
ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 \
  'DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban'
```
Verification: command exits 0; `dpkg -l fail2ban` shows `ii  fail2ban`.

---

**Step 3 — Write /etc/fail2ban/jail.local**

Note: `/etc/fail2ban/jail.local` does not exist pre-install (fail2ban was absent). After apt installs the package, `jail.conf` is present but `jail.local` is not — writing it is a new-file creation, not an overwrite. No backup is required; there is nothing to back up.

Substitute `<MGMT_IP>` with the value captured in Pre-step A.

Command:
```bash
ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 'cat > /etc/fail2ban/jail.local <<'"'"'EOF'"'"'
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 <MGMT_IP>

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
backend = %(sshd_backend)s
bantime = 1h
findtime = 10m
maxretry = 5
EOF'
```
Verification: `cat /etc/fail2ban/jail.local` on host shows the expected content with the correct `ignoreip` line and `[sshd]` values.

**IMPORTANT — jail.local values differ from QA reference:** T-0095 on `pro-data-tech-qa` used `bantime=600s`, `findtime=600s`, `maxretry=3`. T-0104's acceptance criteria mandate `bantime=1h`, `findtime=10m`, `maxretry=5`. The executor must use T-0104's values, not the QA landscape values.

---

**Step 4 — Enable fail2ban service**

Command:
```bash
ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 \
  'systemctl enable fail2ban'
```
Verification: `systemctl is-enabled fail2ban` returns `enabled`.

---

**Step 5 — Start fail2ban service**

Command:
```bash
ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 \
  'systemctl start fail2ban'
```
Verification: `systemctl is-active fail2ban` returns `active`.

---

**Step 6 — Verify jail status**

Command:
```bash
ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 \
  'fail2ban-client status'
```
Verification: output shows `Number of jail: 1` and lists `sshd`.

---

**Step 7 — Verify sshd jail is active**

Command:
```bash
ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 \
  'fail2ban-client status sshd'
```
Verification: output includes `Status for the jail: sshd`, `File list:` containing auth.log or journal, `Currently banned: 0` (clean start).

### Rollback

The plan is fully reversible. Execute in order if rollback is needed:

1. Stop the service — command: `ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 'systemctl stop fail2ban'`
2. Disable the service — command: `ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 'systemctl disable fail2ban'`
3. Remove jail.local — command: `ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 'rm -f /etc/fail2ban/jail.local'`
4. Uninstall package — command: `ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 'DEBIAN_FRONTEND=noninteractive apt-get remove -y fail2ban && apt-get autoremove -y'`

Post-rollback verification: `dpkg -l fail2ban 2>/dev/null | grep -q "^ii" && echo "STILL_PRESENT" || echo "REMOVED"` — expected `REMOVED`.

### Verification (for step 07)

- **On-host:**
  - `dpkg -l fail2ban | grep "^ii"` — package present
  - `systemctl is-active fail2ban` returns `active`
  - `systemctl is-enabled fail2ban` returns `enabled`
  - `fail2ban-client status` shows `Number of jail: 1` and lists `sshd`
  - `fail2ban-client status sshd` shows jail active, `Currently banned: 0`
  - `cat /etc/fail2ban/jail.local` — file contains `bantime = 1h`, `findtime = 10m`, `maxretry = 5`, `enabled = true` under `[sshd]`
  - `grep "ignoreip" /etc/fail2ban/jail.local` — includes `127.0.0.1/8` and the management workstation IP captured in Pre-step A
- **External:** N/A — fail2ban is a host-side daemon with no externally observable HTTP/DNS state. The "verify in two places" requirement is satisfied by (1) service status and (2) `fail2ban-client` jail status, both confirming the daemon is operational.

### Resources used

- Secrets (by name): none
- Files modified on host: `/etc/fail2ban/jail.local` (created new)
- Files modified in this repo (landscape/): `landscape/hosts/pro-data-tech-prod.md` — to be updated at step 08 to record fail2ban installed, version, jail.local values, and clearing the HIGH-severity security gap
- External APIs called: `https://api.ipify.org` (read-only; used to resolve management workstation public IP for `ignoreip`)

### Estimated impact

- Downtime: none — fail2ban bans new failed-auth IPs only; existing authenticated SSH sessions are unaffected. Service restart is not required.
- Affected services: SSH brute-force protection only. No application services on this host.
- Reversibility: fully reversible — package can be removed, jail.local deleted, and iptables rules cleared via rollback steps above.

## Issues / risks

- **jail.local values intentionally differ from QA:** `bantime=1h`, `findtime=10m`, `maxretry=5` (T-0104) vs `bantime=600s`, `findtime=600s`, `maxretry=3` (QA T-0095 actual). The executor must follow T-0104's values. Low severity — documented here and in the plan.
- **Management workstation IP must be captured live:** the `ignoreip` entry is time-of-execution-dependent. If the executor skips Pre-step A and uses a stale IP, the management workstation could be banned on repeated failed auth attempts. Severity: low (only affects new connections; existing session is unaffected; can be unbanned instantly with `fail2ban-client unban <ip>`).
- **12 pending apt upgrades on prod (including kernel):** not a blocker for this task; no interaction with fail2ban install. Noted for situational awareness.
- **`sshusers` group in transitional state:** T-0105 (operator users) has not run yet; root is the sole SSH account. No interaction with fail2ban. Noted for completeness.
