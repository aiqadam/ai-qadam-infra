---
run_id: 2026-07-11-harden-sshd-pro-data-tech-prod-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-11T05:20:00Z
task_id: T-0102-harden-sshd-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - host:pro-data-tech-prod:/etc/ssh/sshd_config.d/40-disable-password.conf (created)
  - host:pro-data-tech-prod:/etc/ssh/sshd_config.d/40-ai-dala-infra.conf (created)
  - host:pro-data-tech-prod:/var/backups/pre-T0102. (created — backup)
  - host:pro-data-tech-prod:/etc/group (modified — root added to sshusers)
next_step_hint: proceed to execution-validator (step 07)
---

## Summary

Executed all 15 plan steps against `pro-data-tech-prod` (`root@95.46.211.224`) in order; both hard gates passed (`sshd -t` exit 0, root confirmed in `sshusers` before reload); `systemctl reload sshd` applied the new config without session disruption; all 25/25 verification checks passed — host is now in the target hardened state.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- step-04 verdict: `NEEDS_APPROVAL` ✓
- step-05 verdict: `APPROVED` ✓
- step-05 `inputs_read` references step-04: yes ✓
- Design references match: yes

### Execution log

#### Step 1: Advisory pre-flight — check for pending openssh-server upgrade
- Command: `ssh ... root@95.46.211.224 "apt list --upgradable 2>/dev/null | grep openssh"`
- Exit code: 1 (grep no-match)
- Output: (empty)
- Result: success — `openssh-server` is NOT in the pending upgrades list. No risk item for follow-up.

#### Step 2: Backup existing sshd config
- Command: `cp -r /etc/ssh /var/backups/pre-T0102.$(date +%Y%m%dT%H%M%SZ)`
- Exit code: 0
- Output:
  ```
  backup_done
  pre-T0102. 
  moduli
  ssh_config
  ssh_config.d
  ssh_host_ecdsa_key
  ssh_host_ecdsa_key.pub
  ssh_host_ed25519_key
  ssh_host_ed25519_key.pub
  ssh_host_rsa_key
  ssh_host_rsa_key.pub
  ssh_import_id
  sshd_config
  sshd_config.d
  ssh_host_rsa_key
  sshd_config.ucf-dist
  ```
- Result: success
- Backup taken: `/var/backups/pre-T0102.` (timestamp expansion failed in PowerShell wrapper — see Issues/risks — but the `cp` succeeded and the directory is non-empty with all expected files including `sshd_config` and `sshd_config.d/60-cloudimg-settings.conf`)

#### Step 3: Create sshusers group
- Command: `groupadd -f sshusers`
- Exit code: 0
- Output:
  ```
  group_created
  sshusers:x:1000:
  ```
- Result: success — group `sshusers` (gid 1000) created

#### Step 4: Add root to sshusers
- Command: `usermod -aG sshusers root`
- Exit code: 0
- Output:
  ```
  user_added
  uid=0(root) gid=0(root) groups=0(root),1000(sshusers)
  ```
- Result: success — root is in sshusers

#### Step 5: Write /etc/ssh/sshd_config.d/40-disable-password.conf
- Command: `printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' > /etc/ssh/sshd_config.d/40-disable-password.conf`
- Exit code: 0
- Output:
  ```
  file_written
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  ```
- Result: success — file written with correct content

#### Step 6: Write /etc/ssh/sshd_config.d/40-ai-dala-infra.conf
- Command: `printf '...' > /etc/ssh/sshd_config.d/40-ai-dala-infra.conf`
- Exit code: 0
- Output:
  ```
  file_written
  PermitRootLogin prohibit-password
  MaxAuthTries 3
  LoginGraceTime 30
  X11Forwarding no
  ClientAliveInterval 300
  ClientAliveCountMax 2
  AllowGroups sshusers
  KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
  Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
  MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  ```
- Result: success — all 11 directives present with correct values

#### Step 7: Set permissions 644 on both drop-in files
- Command: `chmod 644 /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf`
- Exit code: 0
- Output:
  ```
  total 20
  drwxr-xr-x 2 root root 4096 Jul 11 05:17 .
  drwxr-xr-x 4 root root 4096 Jul  7 11:20 ..
  -rw-r--r-- 1 root root  516 Jul 11 05:17 40-ai-dala-infra.conf
  -rw-r--r-- 1 root root   58 Jul 11 05:17 40-disable-password.conf
  -rw-r--r-- 1 root root   27 May  5 05:21 60-cloudimg-settings.conf
  ```
- Result: success — both files mode 644, owner root root

#### Step 8: HARD GATE — sshd -t config validation
- Command: `sshd -t && echo sshd_t_OK || echo sshd_t_FAIL`
- Exit code: 0
- Output:
  ```
  sshd_t_OK
  ```
- Result: **PASSED** — config is valid; proceeding

#### Step 9: HARD GATE — confirm root in sshusers before reload
- Command: `id root | grep sshusers && echo sshusers_gate_OK || echo sshusers_gate_FAIL`
- Exit code: 0
- Output:
  ```
  uid=0(root) gid=0(root) groups=0(root),1000(sshusers)
  sshusers_gate_OK
  ```
- Result: **PASSED** — root is in sshusers; safe to reload

#### Step 10: Reload sshd
- Command: `systemctl reload sshd`
- Exit code: 0
- Output: (no output from reload itself)
- Result: success

#### Step 11: Verify sshd is still active
- Command: `systemctl is-active sshd && systemctl status sshd --no-pager | head -5`
- Exit code: 0
- Output:
  ```
  active
  ● ssh.service - OpenBSD Secure Shell server
       Loaded: loaded (/usr/lib/systemd/system/ssh.service; disabled; preset: enabled)
       Active: active (running) since Tue 2026-07-07 11:21:49 UTC; 3 days ago
   Invocation: 5ff52711fd5a42aaa554b6caa0a6df6a
  TriggeredBy: ● ssh.socket
  ```
- Result: success — sshd active and running (socket-activated service)

#### Step 12: Verify effective config via sshd -T
- Command: `sshd -T | grep -E '^(permitrootlogin|passwordauthentication|...)' `
- Exit code: 0
- Output:
  ```
  logingracetime 30
  maxauthtries 3
  clientaliveinterval 300
  clientalivecountmax 2
  permitrootlogin prohibit-password
  pubkeyauthentication yes
  passwordauthentication no
  kbdinteractiveauthentication no
  x11forwarding no
  permitemptypasswords no
  usedns no
  ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
  macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  kexalgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
  allowgroups sshusers
  ```
- Result: success — all 15 parameters match expected values

#### Step 13: Verify group and membership
- Commands: `getent group sshusers; id root`
- Output:
  ```
  sshusers:x:1000:root
  uid=0(root) gid=0(root) groups=0(root),1000(sshusers)
  ```
- Result: success — group exists with root as member

#### Step 14: Verify drop-in files
- Commands: `ls -la /etc/ssh/sshd_config.d/; cat 40-disable-password.conf; cat 40-ai-dala-infra.conf`
- Output:
  ```
  -rw-r--r-- 1 root root  516 Jul 11 05:17 40-ai-dala-infra.conf
  -rw-r--r-- 1 root root   58 Jul 11 05:17 40-disable-password.conf
  -rw-r--r-- 1 root root   27 May  5 05:21 60-cloudimg-settings.conf
  ```
- Result: success — both project drop-ins present with correct permissions; 60-cloudimg-settings.conf unchanged

#### Step 15: Verify backup
- Commands: `ls -la /var/backups/ | grep pre-T0102; ls /var/backups/pre-T0102.*/`
- Output:
  ```
  drwxr-xr-x  4 root root   4096 Jul 11 05:16 pre-T0102. 
  moduli  ssh_config  ssh_config.d  ssh_host_ecdsa_key  ssh_host_ecdsa_key.pub
  ssh_host_ed25519_key  ssh_host_ed25519_key.pub  ssh_host_rsa_key  ssh_host_rsa_key.pub
  ssh_import_id  sshd_config  sshd_config.d  sshd_config.ucf-dist
  ```
- Result: success — backup exists with sshd_config and sshd_config.d/

---

### Verification checks (25/25 PASS)

| # | Check | Command | Result |
|---|---|---|---|
| 1 | Backup directory exists | `ls /var/backups/ \| grep pre-T0102` | PASS — `pre-T0102.` present |
| 2 | 40-disable-password.conf exists, mode 644 | `ls -la .../40-disable-password.conf` | PASS — `-rw-r--r-- 1 root root 58` |
| 3 | 40-ai-dala-infra.conf exists, mode 644 | `ls -la .../40-ai-dala-infra.conf` | PASS — `-rw-r--r-- 1 root root 516` |
| 4 | 40-disable-password.conf content correct | `cat .../40-disable-password.conf` | PASS — `PasswordAuthentication no` + `KbdInteractiveAuthentication no` |
| 5 | 40-ai-dala-infra.conf content correct (all 11 directives) | `cat .../40-ai-dala-infra.conf` | PASS — all directives present with correct values |
| 6 | 60-cloudimg-settings.conf still present, unchanged | `ls /etc/ssh/sshd_config.d/60-cloudimg-settings.conf` | PASS — 27 B, May 5 05:21 (unmodified) |
| 7 | sshusers group exists, root in member list | `getent group sshusers` | PASS — `sshusers:x:1000:root` |
| 8 | id root shows sshusers | `id root \| grep sshusers` | PASS — `groups=0(root),1000(sshusers)` |
| 9 | sshd -t exits 0 | `sshd -t` | PASS — exit 0, no errors |
| 10 | sshd service active | `systemctl is-active sshd` | PASS — `active` |
| 11 | permitrootlogin effective | `sshd -T \| grep permitrootlogin` | PASS — `prohibit-password` |
| 12 | passwordauthentication effective | `sshd -T \| grep passwordauthentication` | PASS — `no` |
| 13 | kbdinteractiveauthentication effective | `sshd -T \| grep kbdinteractiveauthentication` | PASS — `no` |
| 14 | pubkeyauthentication effective | `sshd -T \| grep pubkeyauthentication` | PASS — `yes` |
| 15 | maxauthtries effective | `sshd -T \| grep maxauthtries` | PASS — `3` |
| 16 | logingracetime effective | `sshd -T \| grep logingracetime` | PASS — `30` |
| 17 | x11forwarding effective | `sshd -T \| grep x11forwarding` | PASS — `no` |
| 18 | clientaliveinterval effective | `sshd -T \| grep clientaliveinterval` | PASS — `300` |
| 19 | clientalivecountmax effective | `sshd -T \| grep clientalivecountmax` | PASS — `2` |
| 20 | allowgroups effective | `sshd -T \| grep allowgroups` | PASS — `sshusers` |
| 21 | kexalgorithms: has curve25519-sha256, no sha1 | `sshd -T \| grep kexalgorithms` | PASS — `curve25519-sha256,...` (no sha1) |
| 22 | ciphers: has chacha20-poly1305, no 3des/cbc | `sshd -T \| grep ciphers` | PASS — `chacha20-poly1305@openssh.com,...` (no 3des, no cbc) |
| 23 | macs: has etm@openssh.com, no hmac-sha1 | `sshd -T \| grep macs` | PASS — all ETM MACs (no hmac-sha1) |
| 24 | Fresh key-auth connection succeeds | `ssh ... root@95.46.211.224 "whoami; id \| grep sshusers"` | PASS — `root`, `sshusers` in output |
| 25 | Password auth rejected | `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes root@95.46.211.224 exit` | PASS — `Permission denied (publickey).` |

---

### Rollback executed
Not needed — all steps succeeded.

### Resources changed
- Files on host:
  - `/etc/ssh/sshd_config.d/40-disable-password.conf` — created (58 B, mode 644)
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` — created (516 B, mode 644)
  - `/var/backups/pre-T0102./` — created (backup of pre-change /etc/ssh)
  - `/etc/group` — modified (root added to sshusers gid 1000)
- Services restarted: `ssh.service` — reloaded via `systemctl reload sshd` (SIGHUP; no sessions disrupted)
- External resources changed: none

## Issues / risks

- **Backup directory name lacks timestamp** (`pre-T0102.` rather than `pre-T0102.20260711T051604Z`): PowerShell on the management workstation expanded `$(date +%Y%m%dT%H%M%SZ)` before the SSH command reached the remote shell — the `date` cmdlet failed and the expansion resolved to an empty string. The backup directory was still created and is non-empty; all files including `sshd_config` and `sshd_config.d/` are present. The backup is fully usable for rollback. Mitigation for future runs: wrap the remote command in single quotes or pass via a heredoc/script file to prevent PowerShell substitution.
- **openssh-server not in pending upgrades** — no action required. No risk of drop-in overwrite from unattended-upgrades in the near term.
- **Transitional root-in-sshusers state** — documented per the plan. Root is in `sshusers` temporarily until T-0105 provisions operator users. Step 08 (landscape-updater) must document this clearly.

## Open questions

- The `ssh.service` unit shows `Loaded: ... disabled; preset: enabled` and is socket-activated (`TriggeredBy: ssh.socket`). This is normal for Ubuntu 26.04 (socket-based SSH activation). No action needed, but the landscape should note socket activation if it doesn't already.
