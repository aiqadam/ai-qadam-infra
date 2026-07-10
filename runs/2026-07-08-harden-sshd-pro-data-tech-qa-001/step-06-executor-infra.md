---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-08T17:00:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-03-task-validator.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-04-solution-designer.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-05-user-approval.md
artifacts_changed:
  - /etc/ssh/sshd_config.d/40-disable-password.conf (created; 462 bytes; mode 644 root:root; PasswordAuthentication no + KbdInteractiveAuthentication no)
  - /etc/ssh/sshd_config.d/40-ai-dala-infra.conf (created; 1335 bytes; mode 644 root:root; PermitRootLogin prohibit-password, MaxAuthTries 3, LoginGraceTime 30, X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2, AllowGroups sshusers, KexAlgorithms/Ciphers/MACs dropping SHA-1)
  - /etc/group (modified by `groupadd -f sshusers`; new line `sshusers:x:1000:`; only `root` added via `usermod -aG`)
  - /tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/ (pre-change backup directory; contains original 60-cloudimg-settings.conf, 27 bytes)
  - /etc/ssh/sshd_config.d/60-cloudimg-settings.conf (untouched; still has redundant `PasswordAuthentication yes` which is silently overridden by the new 40- drop-in)
  - /root/.ssh/authorized_keys (untouched; provider key `rsa-key-20260707` preserved as break-glass anchor)
  - ssh.service (one full restart; listeners cycled through new KEX/Ciphers/MACs; ~2 seconds downtime)
next_step_hint: Pass to execution-validator (step 07).
---

## Summary

All 12 plan steps executed in order on `pro-data-tech-qa` (95.46.211.230). Two managed drop-ins installed under `/etc/ssh/sshd_config.d/` (`40-disable-password.conf`, `40-ai-dala-infra.conf`), `sshusers` group pre-created with `root` as sole member, `sshd -t` validates the new config cleanly (exit 0), `systemctl restart ssh` succeeded (`active` on 0.0.0.0:22 and [::]:22), `sshd -T` confirms every hardened directive is effective at the daemon level (passwordauth no, permitrootlogin prohibit-password, maxauthtries 3, logingracetime 30, x11forwarding no, clientaliveinterval 300, clientalivecountmax 2, allowgroups sshusers, plus the explicit KexAlgorithms/Ciphers/MACs with SHA-1 dropped), live SSH probe from the management workstation succeeds as `root` (groups include `1000(sshusers)`) with passwordless sudo OK, defense-in-depth probe confirms `PasswordAuthentication no` is effective at the network layer (server returns `Permission denied (publickey)` with no password method offered), backup is intact at the recorded timestamp, and the provider key remains as the break-glass anchor.

## Details

### Pre-execution checks

- Approval handoff verified: yes (`step-05-user-approval.md`, `verdict: APPROVED`, `inputs_read` lists `step-04-solution-designer.md`).
- Approval verdict: APPROVED (delegation `just go` recorded verbatim).
- Design references match: yes (step-05's `inputs_read` lists step-04; step-04's plan matches task T-0093 acceptance criteria verbatim).

### Execution log

#### Step 1: Pre-flight idempotency check (drop-ins, sshusers, Include directive, current effective config)

- Command: `id; getent group sshusers; grep -E '^Include' /etc/ssh/sshd_config; sudo -n sshd -T | grep -i ^passwordauthentication; sudo -n sshd -T | grep -i ^permitrootlogin`
- Exit code: 0
- Output (key facts): `uid=0(root) gid=0(root) groups=0(root)` (no `sshusers` yet), `sshusers` group not present, `Include /etc/ssh/sshd_config.d/*.conf` directive present, `passwordauthentication yes`, `permitrootlogin yes` (cloud-init defaults, expected).
- Result: success — preconditions normal.
- Backup taken: n/a (this step is read-only).
- Evidence: [step-06-pre-01-idempotency.txt](step-06-pre-01-idempotency.txt)

#### Step 2: Pre-flight connectivity + drop-in inventory

- Command: `ls -la /etc/ssh/sshd_config.d/; wc -l /root/.ssh/authorized_keys; grep '^.*rsa-key-20260707' /root/.ssh/authorized_keys`
- Exit code: 0
- Output: only `60-cloudimg-settings.conf` (27 B, mode 644, root:root, dated May 5) is present in `/etc/ssh/sshd_config.d/` — no file with prefix < 40, no pre-existing `40-disable-password.conf` or `40-ai-dala-infra.conf`. `/root/.ssh/authorized_keys` has exactly 1 line ending in `rsa-key-20260707`.
- Result: success.
- Backup taken: n/a.
- Evidence: [step-06-pre-02-connectivity.txt](step-06-pre-02-connectivity.txt)

#### Step 3: Snapshot backup of `/etc/ssh/sshd_config.d/`

- Command: `BACKUP_DIR=/tmp/sshd_config.d.pre-T0093.$(date -u +%Y%m%dT%H%M%SZ).bak; sudo -n mkdir -p $BACKUP_DIR && sudo -n cp -r /etc/ssh/sshd_config.d/. $BACKUP_DIR/ && sudo -n chmod -R u+rwX,go+r $BACKUP_DIR`
- Exit code: 0
- Output: `BACKUP_DIR=/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak`; backup contains `60-cloudimg-settings.conf` (27 bytes, content `PasswordAuthentication yes`). Non-empty: verified.
- Result: success.
- Backup taken: `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/` (one directory; `60-cloudimg-settings.conf`, 27 bytes).
- Evidence: [step-06-pre-03-backup.txt](step-06-pre-03-backup.txt)

#### Step 4: Create `sshusers` group; add `root` to it

- Command: `sudo -n groupadd -f sshusers; sudo -n usermod -aG sshusers root; getent group sshusers; id root`
- Exit code: 0
- Output: `sshusers:x:1000:root` (gid 1000); `uid=0(root) gid=0(root) groups=0(root),1000(sshusers)`.
- Result: success — `root` is now a member of `sshusers`, satisfying the pre-work for `AllowGroups sshusers` in step 6's drop-in.
- Backup taken: n/a.
- Evidence: [step-06-step-04-sshusers-group.txt](step-06-step-04-sshusers-group.txt)

#### Step 5: Drop-in file 1: `/etc/ssh/sshd_config.d/40-disable-password.conf`

- Command: `sudo -n tee /etc/ssh/sshd_config.d/40-disable-password.conf > /dev/null << 'SSHD_EOF' ... PasswordAuthentication no / KbdInteractiveAuthentication no / SSHD_EOF; sudo -n chmod 0644 ...; sudo -n chown root:root ...; cat /etc/ssh/sshd_config.d/40-disable-password.conf`
- Exit code: 0
- Output: file contents echo matches plan verbatim (5-line header comment + 2 directives, 462 bytes). Mode 644, owner root:root.
- Result: success.
- Backup taken: n/a (the file is itself a fresh change; backup from step 3 covers the original state).
- Evidence: [step-06-step-05-disable-password-dropin.txt](step-06-step-05-disable-password-dropin.txt)

#### Step 6: Drop-in file 2: `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf`

- Command: `sudo -n tee /etc/ssh/sshd_config.d/40-ai-dala-infra.conf > /dev/null << 'SSHD_EOF' ... PermitRootLogin prohibit-password / MaxAuthTries 3 / LoginGraceTime 30 / X11Forwarding no / ClientAliveInterval 300 / ClientAliveCountMax 2 / AllowGroups sshusers / KexAlgorithms ... / Ciphers ... / MACs ... / SSHD_EOF; sudo -n chmod 0644 ...; sudo -n chown root:root ...; cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf`
- Exit code: 0
- Output: file contents echo matches plan verbatim (6-line header comment + 10 directives, 1335 bytes). Mode 644, owner root:root.
- Result: success.
- Backup taken: n/a.
- Evidence: [step-06-step-06-ai-dala-infra-dropin.txt](step-06-step-06-ai-dala-infra-dropin.txt)

#### Step 7: Config syntax validation: `sudo -n sshd -t`

- Command: `sudo -n sshd -t; rc=$?; echo RC=$rc`
- Exit code: 0 (sshd -t)
- Output: `RC=0`. No stderr output.
- Result: success — both new drop-ins parse cleanly; sshd's compiled-in syntax checker accepts the new configuration.
- Backup taken: n/a.
- Evidence: [step-06-step-07-sshd-test.txt](step-06-step-07-sshd-test.txt)

#### Step 8: `sudo -n systemctl restart ssh` + listener check

- Command: `sudo -n systemctl restart ssh; sleep 2; sudo -n systemctl is-active ssh; ss -ltnp | grep :22`
- Exit code: 0
- Output: `active`. Listeners: `LISTEN 0 4096 0.0.0.0:22` with `users:(("sshd",pid=55364,fd=3),("systemd",pid=1,fd=205))` and `LISTEN 0 4096 [::]:22` with `users:(("sshd",pid=55364,fd=4),("systemd",pid=1,fd=206))`. New sshd pid 55364 confirms a fresh daemon (was 28491 in the discovery run).
- Result: success — sshd is active on both IPv4 and IPv6 listeners within 2 seconds of restart.
- Backup taken: n/a.
- Evidence: [step-06-step-08-sshd-restart.txt](step-06-step-08-sshd-restart.txt)

#### Step 9: `sshd -T` after restart — effective-config check

- Command: `sudo -n sshd -T 2>/dev/null | grep -Ei '^(passwordauthentication|permitrootlogin|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowgroups|kexalgorithms|ciphers|macs|pubkeyauthentication|kbdinteractiveauthentication) ' | sort` (script uploaded to `/tmp/sshd-T-script.sh` because remote grep regex with parentheses needed binary-safe transfer).
- Exit code: 0
- Output (13 lines, alphabetical):
  ```
  allowgroups sshusers
  ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
  clientalivecountmax 2
  clientaliveinterval 300
  kbdinteractiveauthentication no
  kexalgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
  logingracetime 30
  macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  maxauthtries 3
  passwordauthentication no
  permitrootlogin prohibit-password
  pubkeyauthentication yes
  x11forwarding no
  ```
- Result: success — every directive matches the drop-in verbatim. KEX excludes `diffie-hellman-group1-sha1`, `diffie-hellman-group14-sha1`, and any other SHA-1 KEX. Ciphers exclude 3DES, RC4, and unauthenticated CBCs. MACs exclude `hmac-sha1`, `hmac-sha1-etm`, `hmac-sha1-96`.
- Backup taken: n/a.
- Evidence: [step-06-step-09-sshd-T-after.txt](step-06-step-09-sshd-T-after.txt)

#### Step 10: Live SSH probe (fresh session, the critical sanity check)

- Command (NEW connection, not the connection used for steps 1–9):
  `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 root@95.46.211.230 "whoami && id && sudo -n true && echo SUDO_OK"`
- Exit code: 0
- Output (4 lines, separated):
  ```
  root
  uid=0(root) gid=0(root) groups=0(root),1000(sshusers)
  SUDO_OK
  ```
- Result: success — `root` login still works via key auth; `sshusers` is in root's supplementary groups (proves `usermod -aG sshusers root` took effect under the new `AllowGroups sshusers` directive); `SUDO_OK` proves passwordless sudo for root is intact. The provider-key break-glass path remains functional.
- Backup taken: n/a.
- Evidence: [step-06-step-10-live-ssh.txt](step-06-step-10-live-ssh.txt)

#### Step 11: Defense-in-depth probe — password-auth rejection

- Command: `ssh -i "..." -o PubkeyAuthentication=no -o PreferredAuthentications=password -o NumberOfPasswordPrompts=0 root@95.46.211.230 "whoami"`
- Exit code: non-zero (command denied — expected)
- Output: `root@95.46.211.230: Permission denied (publickey).`
- Result: success — the server's advertised auth-method list contains only `publickey` (no `password`); the connection is refused outright. `PasswordAuthentication no` and `KbdInteractiveAuthentication no` are both effective at the network layer. Note: PowerShell's "Command exited with code 1" warning on the SSH native cmd-let is the documented stderr-as-error misclassification, not an actual sshd-level failure.
- Backup taken: n/a.
- Evidence: [step-06-step-11-pwd-auth-rejection.txt](step-06-step-11-pwd-auth-rejection.txt)

#### Step 12: Verify backup is intact + final host state

- Command (script uploaded to `/tmp/backup-verify-script.sh` because of semicolon-quoting complexity on Windows PowerShell):
  - `ls -la $BACKUP_DIR; cat $BACKUP_DIR/60-cloudimg-settings.conf; wc -c ...; wc -l /root/.ssh/authorized_keys; grep -c '^ssh-rsa' ...; grep '^rsa-key-20260707' ...; ls -la /etc/ssh/sshd_config.d/; cat /etc/ssh/sshd_config.d/40-disable-password.conf; cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf; id root; getent group sshusers; stat -c '%n %a %U:%G %s' ...`
- Exit code: 0 (ssh); the inner PowerShell "Command exited with code 1" is stderr-as-error misclassification.
- Output:
  - Backup dir `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/` is intact: `60-cloudimg-settings.conf`, 27 bytes, content `PasswordAuthentication yes` (the original cloud-init value).
  - `/root/.ssh/authorized_keys`: 1 line, 1 RSA key (the provider key, comment `rsa-key-20260707`).
  - Drop-ins on host: lex-ordered 40-ai-dala-infra.conf (1335 B), 40-disable-password.conf (462 B), 60-cloudimg-settings.conf (27 B).
  - Both new drop-ins content match plan verbatim.
  - `uid=0(root) gid=0(root) groups=0(root),1000(sshusers)`.
  - `sshusers:x:1000:root` (gid 1000, root only).
  - Mode/owner on all three drop-ins: 644 root:root.
- Result: success — backup is intact and non-empty; break-glass key is preserved; new drop-ins match plan.
- Backup taken: n/a (verification only).
- Evidence: [step-06-step-12-backup-verify.txt](step-06-step-12-backup-verify.txt), [step-06-step-12-authorized-keys.txt](step-06-step-12-authorized-keys.txt) (provider-key line, separately re-verified with `grep '^.*rsa-key-20260707'`).

### Rollback executed

- not needed — every step of the plan succeeded; the backup at `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/` and the provider key in `/root/.ssh/authorized_keys` are preserved as documented rollback anchors for any future re-run.

### Resources changed

- **Files on host `pro-data-tech-qa` (95.46.211.230):**
  - `/etc/ssh/sshd_config.d/40-disable-password.conf` — created (462 B, mode 0644, root:root)
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` — created (1335 B, mode 0644, root:root)
  - `/etc/group` — one new line: `sshusers:x:1000:` (gid 1000; root added via `usermod -aG`)
  - `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/60-cloudimg-settings.conf` — preserved snapshot of the pre-change drop-in (27 B, content `PasswordAuthentication yes`)
  - `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` — **NOT modified** (still 27 B, unchanged; the redundant `PasswordAuthentication yes` line is silently overridden by the new 40- drop-in under first-wins semantics)
  - `/etc/ssh/sshd_config` — **NOT modified**
  - `/root/.ssh/authorized_keys` — **NOT modified** (provider key `rsa-key-20260707` preserved as break-glass anchor)
  - Temporary scp uploads: `/tmp/sshd-T-script.sh`, `/tmp/backup-verify-script.sh` (binary-safe transfers to host, ephemeral)
- **Services restarted:** `ssh.service` (one full restart; sshd pid 28491 → 55364; ~2 seconds downtime while the new listeners came up)
- **External resources changed:** none (no Hetzner / Cloudflare / GitHub / pro-data.tech API calls)

## Issues / risks

- **PowerShell syntax hazard (no functional impact):** the bash `grep -E '^(...|...) '` extended regex with parentheses was persistently mis-parsed when passed through `ssh ... "..."` from PowerShell (parentheses inside the double-quoted PowerShell string and inside the SSH argument are interpreted by PowerShell as subexpression contexts, and the unescaped `(` produced `bash: -c: line 1: syntax error near unexpected token '('`). Workaround used: write the script to a local file, `scp` it to the host (preserves bytes intact, no BOM/CR injection), then invoke via `bash /tmp/<script>.sh`. Same workaround applied for step 12's multi-command verification, which suffered a separate PowerShell semicolon-vs-quoting issue. Recommend the **landscape-updater** at step 08 record this pattern in `landscape/hosts/pro-data-tech-qa.md`'s `## Access` ("executor invocation pattern" subsection) so future runs on this host can use scp+bash directly instead of fighting the PowerShell quoting.

- **SSH-client-side "Command exited with code 1" stderr noise** for steps 11 and 12 is documented in [`/memories/powershell-native-command-stderr.md`](../../memories/powershell-native-command-stderr.md): PowerShell classifies any native-command stderr as an error even when the underlying exit code is 0. The actual sshd-level output is the authoritative result, and in both cases the sshd-level outcome was correct (auth denied / verification grep matched).

- **Drop-in order under `sshd_config.d/` first-wins semantics (working as designed, no risk):** the cloud-init drop-in `60-cloudimg-settings.conf` still says `PasswordAuthentication yes`, but under first-wins the new `40-disable-password.conf` wins, so `sshd -T` reports `passwordauthentication no`. If cloud-init ever regenerates `60-cloudimg-settings.conf` the behavior is unchanged (the file was already present and already losing). The landscape's `## Open questions` already records the long-term follow-up of disabling cloud-init's `ssh_pwauth` to remove the redundant directive at the source.

- **`sshusers` group created with a single member (`root`) at this point in time.** T-0097 (operator-user creation) will add `tvolodi`, `viktor_d`, `binali_r` later. Until then the `AllowGroups sshusers` directive has no observable effect on those users (their accounts don't exist yet). Per the solution-designer's decision roll, the `sshusers` group is left in place regardless of any future T-0093 rollback (harmless; required by T-0097).

- **No high-severity risks observed.** The host is in the target hardened state.

## Open questions

None for step 06. All 12 steps produced the exact expected output. Step 07 (execution-validator) should re-run V1–V21 from the solution-designer's verification table and confirm against the evidence files captured here.
