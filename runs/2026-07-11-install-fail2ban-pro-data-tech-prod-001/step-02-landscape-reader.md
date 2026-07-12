---
run_id: 2026-07-11-install-fail2ban-pro-data-tech-prod-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0104-install-fail2ban-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — all facts present, no blockers
---

## Summary

`pro-data-tech-prod` (95.46.211.224, Ubuntu 26.04) has no fail2ban installed and no iptables-level brute-force protection. The host is partially hardened: sshd is hardened (T-0102, key-only on port 22) and UFW is active with deny-incoming default + allow 22/tcp (T-0103); both prerequisites for safe fail2ban iptables chain insertion are satisfied. The QA reference implementation (T-0095 on `pro-data-tech-qa`) used fail2ban 1.1.0-9 with `banaction=iptables-multiport`, but its jail.local values differ from T-0104's acceptance criteria — the executor must follow T-0104's specified values (`bantime=1h`, `findtime=10m`, `maxretry=5`), not the QA values (`bantime=600s`, `findtime=600s`, `maxretry=3`). Both landscape files are current (verified ≤1 day ago); no stale or stub files encountered.

## Details

### Relevant facts (sourced from landscape)

- **fail2ban status on prod:** NOT installed — explicitly recorded as HIGH severity gap. — _source: `landscape/hosts/pro-data-tech-prod.md` (Security gaps table, row #2)_
- **SSH port on prod:** `22` (confirmed from sshd -T effective config and `ssh_port: 22` frontmatter). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **UFW status on prod:** ACTIVE (T-0103, 2026-07-11). Default: deny incoming, allow outgoing, FORWARD DROP. Rules: 22/tcp, 80/tcp, 443/tcp ALLOW IN (v4+v6). Pre-run defaults backed up at `/var/backups/ufw-defaults-pre-T0103.bak`. — _source: `landscape/hosts/pro-data-tech-prod.md` (Network section)_
- **sshd hardening on prod:** T-0102 done 2026-07-11. `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `MaxAuthTries 3`, `AllowGroups sshusers`. Port 22 confirmed. — _source: `landscape/hosts/pro-data-tech-prod.md` (Access section — sshd drop-in files, sshd -T table)_
- **Pending apt upgrades on prod:** 12 packages outstanding; kernel is `7.0.0-14-generic` (two minor versions behind QA). No blocking impact on fail2ban install, but executor should be aware. — _source: `landscape/hosts/pro-data-tech-prod.md` (Hardware & OS section)_
- **SSH access credentials for prod:** `root@95.46.211.224`, key at `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (OpenSSH RSA despite .ppk extension). — _source: `landscape/hosts/pro-data-tech-prod.md` (Access section)_
- **QA reference implementation (T-0095):** fail2ban 1.1.0-9 installed 2026-07-08. `banaction=iptables-multiport`, `maxretry=3`, `findtime=600s`, `bantime=600s`. logpath: `/var/log/auth.log` (with journalmatch fallback). `ignoreip` included `127.0.0.1/8 ::1` plus the management workstation public IP at install time. Service active+enabled. Pre-change backup at `/etc/fail2ban.pre-T0095.20260708T182109Z.bak/`. — _source: `landscape/hosts/pro-data-tech-qa.md` (Security posture — fail2ban bullet; change log row 2026-07-08)_
- **T-0104 acceptance criteria (from step-01 handoff):** `bantime=1h`, `findtime=10m`, `maxretry=5`. These are intentionally different from the QA actual values — the executor must use T-0104's values, not the QA landscape values. — _source: `runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-01-task-reader.md`_
- **No nginx on prod:** the only public-internet-exposed listener is SSH (port 22); sshd jail is the only jail to configure. — _source: `landscape/hosts/pro-data-tech-prod.md` (What runs here section)_

### Stale or stub files encountered

None. Both files are current:
- `landscape/hosts/pro-data-tech-prod.md` — `last_verified: 2026-07-11`, `status: populated`
- `landscape/hosts/pro-data-tech-qa.md` — `last_verified: 2026-07-10`, `status: populated`

### Gaps requiring live discovery

- **Live confirmation that fail2ban is absent:** `dpkg -l fail2ban` — the landscape records it as not installed, but a live check before install is cheap and rules out any out-of-band change. Low-stakes gap; executor can handle inline.
- **Management workstation outbound IP at execution time:** the `ignoreip` entry for the mgmt workstation IP should be captured live during the executor run (same pattern as QA T-0095). The QA run used `178.89.57.135`; this may or may not match at T-0104 execution time.

## Issues / risks

- **jail.local values differ from QA:** T-0104's acceptance criteria (`bantime=1h`, `findtime=10m`, `maxretry=5`) are stricter than the actual QA config (`bantime=600s`, `findtime=600s`, `maxretry=3`). The executor must follow T-0104, not QA. The solution designer should document this delta explicitly so there is no confusion during execution.
- **12 pending apt upgrades on prod:** no blocking impact on this task but worth noting. The kernel is two minor versions behind QA — not a fail2ban concern.
- **`sshusers` group in transitional state:** T-0102 placed root in `sshusers`; T-0105 (operator users) has not run yet. fail2ban install does not interact with this, but the group state is noted for completeness.
