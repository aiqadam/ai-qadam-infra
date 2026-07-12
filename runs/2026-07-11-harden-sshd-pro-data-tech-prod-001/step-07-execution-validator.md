---
run_id: 2026-07-11-harden-sshd-pro-data-tech-prod-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-11T06:15:00Z
task_id: T-0102-harden-sshd-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: proceed to landscape-updater (step 08)
---

## Summary

All 25/25 acceptance criteria from step-04 independently verified against `root@95.46.211.224` via live SSH probes; effective sshd config matches the hardened target state exactly; password authentication is confirmed rejected from the external surface; resources-changed list reconciles fully with observed host state.

## Details

### On-host checks

| # | Check (from designer) | Command run | Result | Pass |
|---|---|---|---|---|
| 1 | Backup directory exists | `ls /var/backups/ \| grep pre-T0102` | `pre-T0102.` present, exit 0 | yes |
| 2 | 40-disable-password.conf: mode 644, owner root | `ls -la /etc/ssh/sshd_config.d/` | `-rw-r--r-- 1 root root 58 Jul 11 05:17` | yes |
| 3 | 40-ai-dala-infra.conf: mode 644, owner root | `ls -la /etc/ssh/sshd_config.d/` | `-rw-r--r-- 1 root root 516 Jul 11 05:17` | yes |
| 4 | 40-disable-password.conf content | `cat /etc/ssh/sshd_config.d/40-disable-password.conf` | `PasswordAuthentication no` + `KbdInteractiveAuthentication no` | yes |
| 5 | 40-ai-dala-infra.conf content (all 11 directives) | `cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` | All 11 directives present with correct values (see raw output below) | yes |
| 6 | 60-cloudimg-settings.conf still present, unchanged | `ls -la /etc/ssh/sshd_config.d/60-cloudimg-settings.conf` | `-rw-r--r-- 1 root root 27 May 5 05:21` — unmodified | yes |
| 7 | sshusers group exists, root in member list | `getent group sshusers` | `sshusers:x:1000:root` — exit 0 | yes |
| 8 | id root shows sshusers | `id root \| grep sshusers` | `uid=0(root) gid=0(root) groups=0(root),1000(sshusers)` — exit 0 | yes |
| 9 | sshd -t exits 0 | `sshd -t` | exit 0, no output (no errors) | yes |
| 10 | sshd service active | `systemctl is-active sshd` | `active` — exit 0 | yes |
| 11 | permitrootlogin = prohibit-password | `sshd -T \| grep permitrootlogin` | `permitrootlogin prohibit-password` | yes |
| 12 | passwordauthentication = no | `sshd -T \| grep passwordauthentication` | `passwordauthentication no` | yes |
| 13 | kbdinteractiveauthentication = no | `sshd -T \| grep kbdinteractiveauthentication` | `kbdinteractiveauthentication no` | yes |
| 14 | pubkeyauthentication = yes | `sshd -T \| grep pubkeyauthentication` | `pubkeyauthentication yes` | yes |
| 15 | maxauthtries = 3 | `sshd -T \| grep maxauthtries` | `maxauthtries 3` | yes |
| 16 | logingracetime = 30 | `sshd -T \| grep logingracetime` | `logingracetime 30` | yes |
| 17 | x11forwarding = no | `sshd -T \| grep x11forwarding` | `x11forwarding no` | yes |
| 18 | clientaliveinterval = 300 | `sshd -T \| grep clientaliveinterval` | `clientaliveinterval 300` | yes |
| 19 | clientalivecountmax = 2 | `sshd -T \| grep clientalivecountmax` | `clientalivecountmax 2` | yes |
| 20 | allowgroups = sshusers | `sshd -T \| grep allowgroups` | `allowgroups sshusers` | yes |
| 21 | kexalgorithms: has curve25519-sha256, no sha1 | `sshd -T \| grep kexalgorithms` | `curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256` — no sha1 | yes |
| 22 | ciphers: has chacha20-poly1305, no 3des/cbc | `sshd -T \| grep ciphers` | `chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr` — no 3des, no cbc | yes |
| 23 | macs: has etm@openssh.com, no hmac-sha1 | `sshd -T \| grep macs` | `hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com` — no hmac-sha1 | yes |

**sshd -T full output (checks 11-23, raw):**
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

### External checks

| # | Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|---|
| 24 | Fresh key-auth connection succeeds; root in sshusers | `ssh -i .../pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 "whoami; id \| grep sshusers"` | `root` + `sshusers` in output, exit 0 | `root` / `uid=0(root) gid=0(root) groups=0(root),1000(sshusers)` / `sshusers_confirmed` — exit 0 | yes |
| 25 | Password auth rejected | `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes root@95.46.211.224 exit` | `Permission denied (publickey).` | `Permission denied (publickey).` — exit 255 | yes |

Note on check 25: PowerShell surfaced the SSH stderr as a `NativeCommandError` with "Command exited with code 1" — this is a known false positive in PowerShell's native-command stderr handling (see user memory). The actual SSH server response was the expected `Permission denied (publickey).`, confirming password auth is disabled.

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| `/etc/ssh/sshd_config.d/40-disable-password.conf` (created, 58 B, mode 644) | Present — `-rw-r--r-- 1 root root 58 Jul 11 05:17` — correct content | yes |
| `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (created, 516 B, mode 644) | Present — `-rw-r--r-- 1 root root 516 Jul 11 05:17` — correct content | yes |
| `/var/backups/pre-T0102.` (created — backup, no timestamp due to PowerShell expansion) | Present — `pre-T0102.` directory in `/var/backups/`, contains `sshd_config` and `sshd_config.d/` | yes |
| `/etc/group` (modified — root added to sshusers gid 1000) | `id root` → `groups=0(root),1000(sshusers)`; `getent group sshusers` → `sshusers:x:1000:root` | yes |

## Issues / risks

- **Backup directory has no timestamp** (`pre-T0102.` instead of `pre-T0102.20260711T051604Z`): independently confirmed — `$(date +%Y%m%dT%H%M%SZ)` was expanded by PowerShell before reaching the remote shell, yielding an empty string. The backup directory itself is valid and non-empty (contains all `/etc/ssh` files including `sshd_config` and `sshd_config.d/`). It is fully usable for rollback. Recommend wrapping remote `date` expansions in single-quoted heredocs in future executor runs.
- **Transitional root-in-sshusers state** (pre-existing risk, noted by both designer and executor): root is the sole member of `sshusers`. If T-0105 (operator user provisioning) does not add operator accounts to `sshusers` before removing root from the group, root will be locked out. Step-08 landscape update must document this constraint clearly.
- **ssh.service is socket-activated** (`TriggeredBy: ssh.socket`, `Loaded: ... disabled; preset: enabled`): observed independently. This is normal for Ubuntu 26.04. `systemctl is-active sshd` returns `active`; the reload applied correctly. No action needed; landscape update should note socket activation.

## Open questions

- none
