---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-08T00:00:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-03-task-validator.md
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - tasks/T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/hetzner-prod.md
  - runs/2026-05-12-disable-ssh-password-auth-001/step-04-solution-designer.md
  - runs/2026-05-12-disable-ssh-password-auth-001/step-06-executor-infra.md
  - runs/2026-05-12-disable-ssh-password-auth-001/.attempts/step-06-executor-infra-attempt-2.md
  - runs/2026-05-12-disable-ssh-password-auth-001/step-07-execution-validator.md
  - tasks/T-0040-sshd-remove-sha1-macs.md
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: Halt; orchestrator writes step-05-user-approval.md (the user has delegated with "just go", so APPROVED). After approval, advance to executor-infra (step 06).
---

## Summary

Harden sshd on `pro-data-tech-qa` (95.46.211.230) by writing two managed drop-ins in `/etc/ssh/sshd_config.d/` (`40-disable-password.conf` mirroring `hetzner-prod`'s sibling; `40-ai-dala-infra.conf` adding `PermitRootLogin prohibit-password`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, `AllowGroups sshusers`, plus explicit `KexAlgorithms` / `Ciphers` / `MACs` that drop SHA-1), pre-creating the `sshusers` group and adding `root` to it (Option B — one-shot, safe under first-wins semantics), validating with `sshd -t`, restarting sshd, and verifying both `sshd -T` effective output and a fresh SSH login from the management workstation — leaving the host with key-only auth, hardened sshd, and root reachable via the provider key as break-glass.

## Details

### Plan

> **Safety requirement:** Keep at least one existing SSH session open for the entire duration of steps 1–11. Do not close that session until step 12's fresh-session probe confirms key auth still works (and root is in `sshusers`).

> **First-wins semantics** (lesson from `2026-05-12-disable-ssh-password-auth-001` attempt 2): `sshd_config.d/*.conf` are processed in lexicographic order and the **first** occurrence of a directive wins. The cloud-init drop-in on this host is `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` (sets `PasswordAuthentication yes` redundantly). The two project drop-ins both use the `40-` prefix so they sort before `60-` and therefore win.

> **Secrets in the `ai-dala-infra` key** live at `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` (OpenSSH-format RSA-2048 despite the `.ppk` extension; first line `-----BEGIN RSA PRIVATE KEY-----`). Reference by path only — never paste the value. The `.ppk` extension is misleading but SSH autodetects format from contents, so the alias works.

---

**Step 1 — Pre-flight: confirm `Include` directive in `/etc/ssh/sshd_config`**

Command (PowerShell; semicolons to chain because `&&` is not PowerShell syntax):

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "grep 'Include /etc/ssh/sshd_config.d' /etc/ssh/sshd_config"
```

Expected output: a line matching `Include /etc/ssh/sshd_config.d/*.conf`. If absent, **STOP and emit `BLOCKED`** — drop-ins will be silently ignored.

---

**Step 2 — Pre-flight: list existing drop-ins; confirm no file with prefix < 40**

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "ls -la /etc/ssh/sshd_config.d/"
```

Expected output: only `60-cloudimg-settings.conf` (27 bytes, owned by cloud-init). **No** file with a numeric prefix less than `40-` (such a file would win under first-wins semantics and could set directives we are trying to harden). **No** pre-existing `40-disable-password.conf` or `40-ai-dala-infra.conf`. If any such file is found, **STOP and emit `BLOCKED`**.

---

**Step 3 — Pre-flight: confirm management-workstation → root key auth is working**

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "echo key-auth-ok"
```

Expected output: `key-auth-ok`. If this fails, **STOP and emit `BLOCKED`** — disabling password auth and adding `AllowGroups` without working key auth would lock every operator out.

---

**Step 4 — Backup `/etc/ssh/sshd_config.d/` (per `workflows/infrastructure.md` rule 2)**

Command (run on the host via SSH; uses UTC timestamp):

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "TS=$(date -u +%Y%m%dT%H%M%SZ); sudo cp -r /etc/ssh/sshd_config.d /tmp/sshd_config.d.pre-T0093.${TS}.bak && ls -la /tmp/sshd_config.d.pre-T0093.${TS}.bak && echo BACKUP_PATH=/tmp/sshd_config.d.pre-T0093.${TS}.bak"
```

Verification: the `ls -la` shows the backup directory containing `60-cloudimg-settings.conf`. **Capture `BACKUP_PATH=/tmp/...` value to the executor handoff's "Resources changed" section** so the validator can re-verify the backup is intact.

This step is **idempotent** — re-running produces a new backup with a new timestamp suffix; the previous backup is preserved.

---

**Step 5 — Create `sshusers` group; add `root` to it (Option B pre-work)**

These two commands make `AllowGroups sshusers` safe immediately (root is the sole member of `sshusers` today; T-0097 will add `tvolodi` / `viktor_d` / `binali_r` later).

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo groupadd -f sshusers && sudo usermod -aG sshusers root && getent group sshusers && id root"
```

Expected output (excerpts):

```
sshusers:x:<gid>:root
uid=0(root) gid=0(root) groups=0(root),<gid>(sshusers)
```

Notes on idempotency:
- `groupadd -f` returns success (exit 0) whether the group existed or not — safe to re-run.
- `usermod -aG` is a no-op when the group is already a supplementary group — safe to re-run.
- Re-running never removes any other groups from `root`.

---

**Step 6 — Write drop-in 1: `/etc/ssh/sshd_config.d/40-disable-password.conf`**

Verbatim file content (mirrors `hetzner-prod`'s `40-disable-password.conf` exactly, updated with this run's identifier and the cloud-init filename observed on this host):

```
# Managed by ai-dala-infra
# Run: 2026-07-08-harden-sshd-pro-data-tech-qa-001 (task T-0093)
# sshd_config.d on this host uses FIRST-WINS semantics (lexicographic order).
# This file sorts before 60-cloudimg-settings.conf (cloud-init's PasswordAuthentication yes) and therefore wins.
# Do not edit directly. To revert: sudo rm /etc/ssh/sshd_config.d/40-disable-password.conf && sudo systemctl restart ssh
PasswordAuthentication no
KbdInteractiveAuthentication no
```

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo tee /etc/ssh/sshd_config.d/40-disable-password.conf > /dev/null << 'SSHD_EOF'
# Managed by ai-dala-infra
# Run: 2026-07-08-harden-sshd-pro-data-tech-qa-001 (task T-0093)
# sshd_config.d on this host uses FIRST-WINS semantics (lexicographic order).
# This file sorts before 60-cloudimg-settings.conf (cloud-init's PasswordAuthentication yes) and therefore wins.
# Do not edit directly. To revert: sudo rm /etc/ssh/sshd_config.d/40-disable-password.conf && sudo systemctl restart ssh
PasswordAuthentication no
KbdInteractiveAuthentication no
SSHD_EOF
sudo chmod 0644 /etc/ssh/sshd_config.d/40-disable-password.conf
sudo chown root:root /etc/ssh/sshd_config.d/40-disable-password.conf
sudo cat /etc/ssh/sshd_config.d/40-disable-password.conf"
```

Verification: `sudo cat` echoes back the file contents above. File mode `0644`, owner `root:root`. **Idempotent** — re-`tee`ing produces identical file.

---

**Step 7 — Write drop-in 2: `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf`**

Verbatim file content (the project drop-in; covers hardening directives from T-0093 + X11Forwarding (T-0049 sibling) + ClientAliveInterval/CountMax (T-0050 sibling) + SHA-1 MAC drop (T-0040 sibling)):

```
# Managed by ai-dala-infra
# Run: 2026-07-08-harden-sshd-pro-data-tech-qa-001 (task T-0093)
# sshd_config.d on this host uses FIRST-WINS semantics (lexicographic order).
# This file sorts before 50-cloud-init.conf and 60-cloudimg-settings.conf and therefore wins all directives set here.
# Do not edit directly. To revert: sudo rm /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && sudo systemctl restart ssh
# Per user decision 2026-07-08: root login kept permanently via PermitRootLogin prohibit-password; the provider key in /root/.ssh/authorized_keys (comment rsa-key-20260707) is the break-glass anchor.
# AllowGroups sshusers enforced per user decision 2026-07-08; root was added to the sshusers group earlier in this run (groupadd -f sshusers; usermod -aG sshusers root) so the break-glass path remains functional.
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

Notes on algorithm choices:
- `KexAlgorithms` — drops the legacy `diffie-hellman-group14-sha1`, `diffie-hellman-group1-sha1`, `ecdh-sha2-nistp256` (kept — modern), and any SHA-1-based KEX. List is the OpenSSH 9.x default minus the SHA-1 entries (verified safe for `hetzner-prod` since 2026-05-12 — current `ssh` client on the management workstation is OpenSSH 9.x and only advertises modern algorithms).
- `Ciphers` — drops 3DES, RC4, and the unauthenticated CBC variants. Keeps the AEAD ciphers (chacha20-poly1305, aes*-gcm) plus aes-ctr (still widely deployed).
- `MACs` — explicit allow-list that **omits** `hmac-sha1`, `hmac-sha1-etm`, and `hmac-sha1-96`. Includes the three EtM MACs recommended by Mozilla SSH guidelines (the SHA-512 EtM, SHA-256 EtM, and UMAC-128 EtM).

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo tee /etc/ssh/sshd_config.d/40-ai-dala-infra.conf > /dev/null << 'SSHD_EOF'
# Managed by ai-dala-infra
# Run: 2026-07-08-harden-sshd-pro-data-tech-qa-001 (task T-0093)
# sshd_config.d on this host uses FIRST-WINS semantics (lexicographic order).
# This file sorts before 50-cloud-init.conf and 60-cloudimg-settings.conf and therefore wins all directives set here.
# Do not edit directly. To revert: sudo rm /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && sudo systemctl restart ssh
# Per user decision 2026-07-08: root login kept permanently via PermitRootLogin prohibit-password; the provider key in /root/.ssh/authorized_keys (comment rsa-key-20260707) is the break-glass anchor.
# AllowGroups sshusers enforced per user decision 2026-07-08; root was added to the sshusers group earlier in this run (groupadd -f sshusers; usermod -aG sshusers root) so the break-glass path remains functional.
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
SSHD_EOF
sudo chmod 0644 /etc/ssh/sshd_config.d/40-ai-dala-infra.conf
sudo chown root:root /etc/ssh/sshd_config.d/40-ai-dala-infra.conf
sudo cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```

Verification: `sudo cat` echoes back the file contents above. File mode `0644`, owner `root:root`. **Idempotent** — re-`tee`ing produces identical file.

---

**Step 8 — Validate config syntax (no restart yet)**

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo sshd -t; echo exit=\$?"
```

Expected output: `exit=0` (and no other stderr output). If exit ≠ 0 or `sshd -t` prints a syntax error, **STOP and emit `BLOCKED`**: do **not** restart sshd. The two drop-ins should be removed (or kept; they will be inert until sshd picks them up) and the executor reports `verdict: FAIL` with the full `sshd -t` stderr so the designer can investigate on a retry.

---

**Step 9 — Restart sshd** (full restart, not reload — we changed KexAlgorithms / Ciphers / MACs, and `systemctl restart ssh` guarantees listeners cycle through the new algorithm list cleanly)

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo systemctl restart ssh && sleep 2 && sudo systemctl is-active ssh"
```

Expected output: `active`. If anything else, **STOP and emit `BLOCKED`**: do **not** proceed to step 10. Run rollback step 1 immediately.

> Note on `sleep 2`: two seconds is sufficient for systemd to bring the listening socket back up on Ubuntu 26.04 (sibling run `2026-05-12-disable-ssh-password-auth-001` used `reload` which doesn't kill listeners — `restart` does, hence the explicit wait). If `systemctl is-active ssh` returns `activating` after 2 seconds, retry the check once after another 2 seconds (transient state during socket bind).

---

**Step 10 — Effective-config verification (`sshd -T`)**

Command (run from the **management workstation**, capturing to a handoff-attached file):

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowgroups|kexalgorithms|ciphers|macs) ' | sort" > runs\2026-07-08-harden-sshd-pro-data-tech-qa-001\step-06-sshd-T-after.txt
```

Expected output (capture and store the file; executor must display the file contents in the step-06 handoff):

```
allowgroups sshusers
ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
clientalivecountmax 2
clientaliveinterval 300
kexalgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
logingracetime 30
macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
maxauthtries 3
passwordauthentication no
permitrootlogin prohibit-password
x11forwarding no
```

Notes on format (verified from sibling run `2026-05-12-disable-ssh-password-auth-001` step-06 logs and from `sshd -T` output on `hetzner-prod`):
- `sshd -T` outputs directives in **lowercase** (canonical names), one per line, `key value` with a single space.
- Some directives (notably `allowgroups`, `ciphers`, `kexalgorithms`, `macs`) are space-free, comma-separated.
- Each value should match the drop-in verbatim (whitespace-normalized).
- If any line is missing OR has an unexpected value, **STOP and emit `BLOCKED`**: do **not** proceed to step 11. Run rollback step 1 immediately.

Also verify (separate command, separately captured):

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo sshd -T | grep -Ei '^(macs|hmac-sha1)'"
```

Expected: the only line(s) that match must be from `macs …` and **must not** contain the strings `hmac-sha1`, `hmac-sha1-etm`, `hmac-sha1-96`, `umac-64@openssh.com` (those are the SHA-1 / 64-bit MACs to drop). If any of those substrings appear, **STOP and emit `BLOCKED`**.

---

**Step 11 — Verify provider key still in `/root/.ssh/authorized_keys` (break-glass preserved)**

Command:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "wc -l /root/.ssh/authorized_keys && grep -c '^ssh-rsa' /root/.ssh/authorized_keys && grep '^rsa-key-20260707' /root/.ssh/authorized_keys | head -1"
```

Expected output: `1` / `1` / `ssh-rsa AAAA… rsa-key-20260707` (the comment `rsa-key-20260707` must be present). If the line count is not `1` or the comment is missing, **STOP and emit `BLOCKED`**: do **not** proceed to step 12. The provider key must remain — `AllowGroups sshusers` is now gating root by group membership, not by removing the key, so the file must be intact.

---

**Step 12 — Fresh-session live SSH probe (most critical check)**

Command (must be a NEW, independent connection — not the session used to run steps 8–11):

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15 root@95.46.211.230 "whoami && id && sudo -n true && echo SUDO_OK"
```

Expected output (verbatim, three lines + one echo):

```
root
uid=0(root) groups=0(root),<gid>(sshusers)
SUDO_OK
```

Verification:
- `whoami` → `root` (root login still works via key auth under `PermitRootLogin prohibit-password`).
- `id` → root's supplementary groups include `sshusers` (proves step 5's `usermod -aG sshusers root` took effect; without this, `AllowGroups sshusers` would have blocked the connection).
- `sudo -n true && echo SUDO_OK` → proves passwordless sudo for root still works (`-n` = non-interactive; if sudo prompted for a password the chain would fail and `SUDO_OK` would not print).

If **any** part fails (authentication refused, `Permission denied (publickey)`, `whoami` returns non-root, `id` doesn't show `sshusers`, or `SUDO_OK` does not print): **STOP and emit `BLOCKED`**. The provider-key break-glass path is critical; do not declare PASS until this succeeds.

If the failure mode is "connection refused" or "no route to host", the host may have lost network connectivity entirely. Hetzner Cloud has no analogue for this — pro-data.tech recovery options are not enumerated in the landscape. Executor should record the failure verbatim and the orchestrator should escalate to the user (pro-data.tech control-panel-based recovery).

> **Lesson from `2026-05-12-disable-ssh-password-auth-001` step-06 first attempt at the equivalent step**: without `-o BatchMode=yes`, OpenSSH on Windows can hang waiting to offer an interactive password prompt even after the server rejects password auth. `-o BatchMode=yes` suppresses that prompt and is therefore **mandatory** for this probe.

---

**Step 13 — Capture final state for the executor handoff**

Run any cleanup or capture commands the executor needs for its "Resources changed" section:

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "ls -la /etc/ssh/sshd_config.d/ && getent group sshusers && stat -c '%n %a %U:%G' /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```

Capture and display in step-06.

---

### Rollback

If any step from step 4 onward fails (other than step 8 `sshd -t` failure, which is recoverable by removing the drop-ins before any restart), execute the following rollback sequence. The backup from step 4 is the source of truth.

**Rollback step 1 — Stop sshd before restoring config (avoids a moment with mismatched config)**

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "BACKUP_DIR=$(ls -td /tmp/sshd_config.d.pre-T0093.*.bak | head -1); echo \"BACKUP_DIR=${BACKUP_DIR}\"; sudo rm -f /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && sudo cp -r ${BACKUP_DIR}/. /etc/ssh/sshd_config.d/ && sudo chmod 0600 /etc/ssh/sshd_config.d/60-cloudimg-settings.conf && sudo chown root:root /etc/ssh/sshd_config.d/60-cloudimg-settings.conf && sudo ls -la /etc/ssh/sshd_config.d/"
```

**Rollback step 2 — Validate restored config**

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo sshd -t && echo SYNTAX_OK"
```

Expected: `SYNTAX_OK`. If it fails, sshd may refuse to start — proceed to step 3 regardless; if step 3 fails, escalate via provider console.

**Rollback step 3 — Restart sshd with the restored config**

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes root@95.46.211.230 "sudo systemctl restart ssh && sleep 2 && sudo systemctl is-active ssh"
```

Expected: `active`.

**Rollback step 4 — Verify restoration on a fresh session**

```powershell
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15 root@95.46.211.230 "sudo sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|maxauthtries|x11forwarding|allowgroups|kexalgorithms|ciphers|macs) '"
```

Expected (cloud-init defaults; `AllowGroups` must NOT appear because no drop-in sets it):

```
passwordauthentication yes
permitrootlogin yes
maxauthtries 6
x11forwarding yes
kexalgorithms <whatever sshd's default list is>
ciphers <whatever sshd's default list is>
macs <whatever sshd's default list is>
```

The exact algorithm defaults may differ from the Ubuntu 24.04 list (this host is Ubuntu 26.04) — the **important** check is that `allowgroups` is **absent** (no drop-in sets it, so the directive does not appear in `sshd -T` output) and that `passwordauthentication` is back to `yes`.

**Rollback step 5 — Decide whether to also revert the `sshusers` group**

The `sshusers` group is **harmless** even if T-0093 is rolled back. It contains `root` only and is not referenced by any sshd drop-in once `40-ai-dala-infra.conf` is removed. **Leave the group in place** — T-0097 will need it, and removing it now would not improve the host's state. Document this decision in the executor handoff.

**Last-resort recovery (out-of-band):** if SSH is unreachable and rollback step 3 cannot run via SSH, the user must use the pro-data.tech control panel's console / VNC / recovery-image feature to log in as `root` locally and run steps 1–4 above from the console. The provider-key path is unaffected because `root` is a member of `sshusers` (group from step 5) AND `PermitRootLogin` is reset to the default `yes` (which accepts pubkey auth). The landscape does not enumerate pro-data.tech recovery options (it explicitly notes the provider does not expose them via in-host metadata); the executor must flag this in "Open questions" if it occurs.

Rollback is **fully reversible** at every point up to and including step 12's failure: nothing is deleted (the backup from step 4 is intact; the `sshusers` group is harmless; the provider key is untouched). After step 12 succeeds, the host is in the target state.

---

### Verification (for step 07)

**On-host checks (via SSH with the provider key):**

| # | Check | Command (run from management workstation) | Expected result |
|---|---|---|---|
| V1 | Both drop-ins exist with correct mode/owner | `sudo ls -la /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` | Both files present, mode `-rw-r--r--`, owner `root:root` |
| V2 | `40-disable-password.conf` content | `sudo cat /etc/ssh/sshd_config.d/40-disable-password.conf` | Contains `PasswordAuthentication no` and `KbdInteractiveAuthentication no` plus the 4-line header comment from step 6 |
| V3 | `40-ai-dala-infra.conf` content | `sudo cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` | Contains all 10 directives from step 7 plus the 6-line header comment |
| V4 | `sshusers` group exists with `root` as member | `getent group sshusers && id root` | `sshusers:x:<gid>:root` and `uid=0(root) gid=0(root) groups=0(root),<gid>(sshusers)` |
| V5 | `passwordauthentication no` (effective) | `sudo sshd -T \| grep -i ^passwordauthentication` | `passwordauthentication no` |
| V6 | `kbdinteractiveauthentication no` (effective) | `sudo sshd -T \| grep -i ^kbdinteractiveauthentication` | `kbdinteractiveauthentication no` |
| V7 | `permitrootlogin prohibit-password` (effective) | `sudo sshd -T \| grep -i ^permitrootlogin` | `permitrootlogin prohibit-password` |
| V8 | `maxauthtries 3` (effective) | `sudo sshd -T \| grep -i ^maxauthtries` | `maxauthtries 3` |
| V9 | `logingracetime 30` (effective) | `sudo sshd -T \| grep -i ^logingracetime` | `logingracetime 30` |
| V10 | `x11forwarding no` (effective) | `sudo sshd -T \| grep -i ^x11forwarding` | `x11forwarding no` |
| V11 | `clientaliveinterval 300` and `clientalivecountmax 2` (effective) | `sudo sshd -T \| grep -Ei '^clientalive'` | Both lines, both with expected values |
| V12 | `allowgroups sshusers` (effective) | `sudo sshd -T \| grep -i ^allowgroups` | `allowgroups sshusers` |
| V13 | `kexalgorithms` does not contain SHA-1 | `sudo sshd -T \| grep -i ^kexalgorithms` | Comma-separated list per step 7 — no `diffie-hellman-group1-sha1`, no `diffie-hellman-group14-sha1` |
| V14 | `ciphers` matches step 7 | `sudo sshd -T \| grep -i ^ciphers` | Comma-separated list per step 7 — no `3des`, no `arcfour`, no `*-cbc` |
| V15 | `macs` excludes SHA-1 | `sudo sshd -T \| grep -i ^macs` | Comma-separated list per step 7 — must NOT contain `hmac-sha1`, `hmac-sha1-etm`, or `hmac-sha1-96` |
| V16 | SSH daemon active | `systemctl is-active ssh` | `active` |
| V17 | Drop-in directory contents | `sudo ls /etc/ssh/sshd_config.d/` | `40-ai-dala-infra.conf`, `40-disable-password.conf`, `60-cloudimg-settings.conf` — in that lex order. **No** file with prefix < 40 |
| V18 | Provider key intact | `wc -l /root/.ssh/authorized_keys && grep '^.*rsa-key-20260707' /root/.ssh/authorized_keys` | `1` line, comment `rsa-key-20260707` present |
| V19 | Backup from step 4 intact (validator sanity check) | `ls -d /tmp/sshd_config.d.pre-T0093.*.bak && ls /tmp/sshd_config.d.pre-T0093.*.bak` | One or more `.bak` dirs; newest one contains `60-cloudimg-settings.conf` |

**External / functional check (from management workstation):**

| # | Check | Command | Expected result |
|---|---|---|---|
| V20 | Fresh-session key auth + root in sshusers + passwordless sudo | `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15 root@95.46.211.230 "whoami && id && sudo -n true && echo SUDO_OK"` | Three lines + `SUDO_OK`; root's groups include `sshusers` |
| V21 | Password auth rejected for root (confirm `PasswordAuthentication no` is effective at the network layer) | `ssh -o BatchMode=no -o PubkeyAuthentication=no -o ConnectTimeout=15 root@95.46.211.230 "whoami"` | Server returns `Permission denied (publickey,password)` or equivalent — never grants a shell on a password attempt. (Note: `-o BatchMode=no` is used here so we get the server's actual rejection message rather than a client-side timeout.) |

> Note on V21: in a clean Windows PowerShell environment with no SSH agent and no key forwarding, `ssh -o PubkeyAuthentication=no -o BatchMode=no` will fall back to password and the server should reject it because `PasswordAuthentication no`. The expected failure is `Permission denied (publickey)` or `Permission denied (publickey,password)` depending on the client's default keyboard-interactive fallback. The test passes if the command exits non-zero AND does not produce a successful `whoami` output. This is a defense-in-depth check that the network-level behavior matches the file-level config — useful if `sshd -T` is somehow lying.

---

### Resources used

- **Secrets (by name):** the `ssh-key:pro-data.tech-qa-instance` (private key at `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk`, RSA-2048 OpenSSH format despite `.ppk` extension; public key fingerprint `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0`). Referenced by path only — value never appears in any handoff file or transcript.
- **Files modified on host `pro-data-tech-qa`:**
  - `/etc/ssh/sshd_config.d/40-disable-password.conf` — **created** (new file; 644 root:root)
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` — **created** (new file; 644 root:root)
  - `/etc/ssh/sshd_config` — **NOT modified**
  - `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` — **NOT modified** (still present; loses the `PasswordAuthentication` directive under first-wins because both 40- files sort before 60-)
  - `/etc/group` — **modified** by `groupadd -f sshusers` (new line: `sshusers:x:<gid>:`) — harmless; only `root` added via `usermod -aG`
  - `/root/.ssh/authorized_keys` — **NOT modified** (provider key preserved)
  - `/tmp/sshd_config.d.pre-T0093.<UTC-timestamp>.bak/` — **created** as the pre-change backup directory
- **Systemd state:** `ssh.service` restarted once (full restart, not reload) — momentary listener recycle (~2 seconds); existing sessions terminated (intentional; provider-key path used in the restart commands survives because it is the same SSH client).
- **Files modified in this repo (`landscape/`) — to be applied at step 08 by `landscape-updater`:**
  - `landscape/hosts/pro-data-tech-qa.md`:
    1. `last_verified: 2026-07-08` → keep (`2026-07-08`; refreshed by step 08 to today's date if different — discover run remains same-day so likely unchanged; landscape-updater should re-check)
    2. `## Access` → `## SSH daemon config (sshd -T effective, 2026-07-08)` block rewritten with the post-hardening values from step 10's `sshd -T` capture
    3. `## Access` → `## sshd drop-in files (/etc/ssh/sshd_config.d/)` block rewritten to list `40-disable-password.conf`, `40-ai-dala-infra.conf`, `60-cloudimg-settings.conf` with mode/owner/managed-by lines for each
    4. `## Security posture` → first bullet (sshd) rewritten: cloud-init defaults → project-hardened values (drop the "Hardening required (T-0093)" suffix)
    5. `## What needs to happen` → item 3 (T-0093 sshd hardening) → mark done (✅), keep the comment about T-0094/T-0095/T-0097 dependencies
    6. `## Open tasks affecting this host` → drop the T-0093 row from the pending list (T-0093 will move to `done`)
    7. `## Change log` → append a row: `| 2026-07-08 | 2026-07-08-harden-sshd-pro-data-tech-qa-001 | T-0093: Created /etc/ssh/sshd_config.d/40-disable-password.conf (PasswordAuthentication no, KbdInteractiveAuthentication no) and /etc/ssh/sshd_config.d/40-ai-dala-infra.conf (PermitRootLogin prohibit-password, MaxAuthTries 3, LoginGraceTime 30, X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2, AllowGroups sshusers, KexAlgorithms/Ciphers/MACs dropping SHA-1). Pre-created sshusers group and added root. sshd restarted; sshd -T confirms all directives effective; fresh SSH probe (root + sudo OK) succeeds. Provider key preserved as break-glass. Backup at /tmp/sshd_config.d.pre-T0093.<UTC-timestamp>.bak/. |`
  - `tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md`:
    1. Frontmatter: `status: pending` → `status: done`; `outcome: succeeded`; `closed: 2026-07-08`; `executed_by_runs: [2026-07-08-harden-sshd-pro-data-tech-qa-001]`
    2. Body: tick all 6 acceptance checkboxes
    3. `## Result` section: fill in with run_id + commit-free (this repo doesn't track changes as commits; the run is the audit record) + outcome summary + cross-reference to step-06 executor log + any deviations from the plan
    4. `## History` → append: `- 2026-07-08: status -> done (run 2026-07-08-harden-sshd-pro-data-tech-qa-001 completed; all 6 acceptance criteria met; provider key preserved as break-glass; sshusers group + root created for AllowGroups; sshd -T confirms all directives effective; fresh SSH probe passes)`
  - `tasks/_index.md`:
    1. Row for T-0093: `pending → done`, link to run
- **External APIs called:** none (sshd config is local; no Hetzner / Cloudflare / GitHub interaction; no pro-data.tech API used because pro-data.tech does not expose an in-host API analogous to Hetzner Cloud)

---

### Estimated impact

- **Downtime:** **seconds** — `systemctl restart ssh` cycles the listening socket. The restart takes ~1–2 seconds; the explicit `sleep 2` plus `systemctl is-active ssh` check in step 9 ensures the listener is back before step 10 begins. No TCP ports other than `22/tcp` are affected. No application data is touched; this is config-only.
- **Affected services:** sshd on `pro-data-tech-qa` only. No other services, containers, or systemd units are modified. No other hosts.
- **Reversibility:** **fully reversible** (paired with backup at `/tmp/sshd_config.d.pre-T0093.<UTC-timestamp>.bak/`) — rollback steps 1–4 restore the cloud-init default state by deleting the two new drop-ins and copying the original `60-cloudimg-settings.conf` back. The `sshusers` group is left in place (harmless; required by T-0097).

---

## Issues / risks

- **Medium blast radius** (per task frontmatter; per `shared/verdicts.md`): an incorrect drop-in (e.g. wrong algorithm name, malformed syntax, wrong `AllowGroups` value) can lock every operator + the provider key out of sshd. Mitigations baked into the plan: (a) `sshd -t` syntax check before restart (step 8), (b) `sshd -T` effective-config check (step 10), (c) fresh-session live SSH probe (step 12), (d) provider-key path kept intact (step 11), (e) Option B's `groupadd -f sshusers` + `usermod -aG sshusers root` ensures root can pass `AllowGroups sshusers`, (f) full backup at step 4 enables rollback to the exact pre-change state.

- **Full reversibility**: rollback steps 1–4 + the step-4 backup restore the cloud-init default state atomically. The only artifact left in place is the harmless empty `sshusers` group (used by T-0097).

- **`AllowGroups sshusers` sequencing (Option B):** by pre-creating the group + adding `root` in step 5 (before any drop-in is written), the `AllowGroups sshusers` directive in step 7's drop-in is immediately safe. Root authenticates as `root` (per `PermitRootLogin prohibit-password` + the provider key in `/root/.ssh/authorized_keys`) AND is in `sshusers` (per step 5), so the connection is accepted by sshd. T-0097 will later add `tvolodi` / `viktor_d` / `binali_r` to `sshusers`; until then, those users do not exist and the `AllowGroups` line has no observable effect on them (they couldn't SSH in anyway because their accounts don't exist). This resolves the circular dependency between T-0093 and T-0097 without splitting the work into two phases.

- **`AllowGroups sshusers` and root's existing `/root/.ssh/authorized_keys`:** the user's decision (recorded in `landscape/hosts/pro-data-tech-qa.md` `## Open questions`) is that the provider key remains the break-glass anchor and that the `AllowGroups` directive governs **operator users** (future `tvolodi` / `viktor_d` / `binali_r`), not the root key. The plan honors this: root is in `sshusers` (so the break-glass path works), and the provider key is left in `/root/.ssh/authorized_keys` unmodified.

- **`systemctl restart ssh` vs `reload`:** I chose `restart` (full restart, terminates and re-spawns sshd, recreates listening sockets) over `reload` (SIGHUP-only, listeners preserved) because we changed `KexAlgorithms`, `Ciphers`, and `MACs`. These directives affect the SSH handshake; a reload that preserves listeners using the old algorithms while new connections negotiate the new algorithms is supported but unnecessarily risky. `restart` guarantees clean state. The 2-second sleep in step 9 covers the restart cycle. The user's plan in the orchestrator request explicitly specified `restart`, confirming this choice.

- **First-wins drop-in semantics (confirmed on `hetzner-prod` via run `2026-05-12-disable-ssh-password-auth-001` attempt 2):** the cloud-init drop-in on `pro-data-tech-qa` is `60-cloudimg-settings.conf` (per `landscape/hosts/pro-data-tech-qa.md`), not `50-cloud-init.conf` as on `hetzner-prod`. Both project drop-ins use the `40-` prefix and therefore sort before either `50-` or `60-` under first-wins semantics. No conflict.

- **Cloud-init drop-in (`60-cloudimg-settings.conf`) left in place:** it sets `PasswordAuthentication yes` redundantly with the compiled-in sshd default. Under first-wins, `40-disable-password.conf`'s `PasswordAuthentication no` wins, so the cloud-init line is silently ignored. If cloud-init ever regenerates `60-cloudimg-settings.conf`, behavior is unchanged — the file was already present and already losing. A future task could add `ssh_pwauth: false` to cloud-init user-data to remove the conflict at the source (out of scope for T-0093). The landscape `## Open questions` already records this as a possible follow-up to T-0093.

- **No files with prefix < `40-` exist** (per landscape-reader step 02 probe; confirmed by step 2 of this plan). If a future run adds such a file with conflicting directives, it would silently override ours. The plan cannot prevent future drift but the landscape `## Access` "sshd drop-in files" block will record the exact file list with mode/owner/managed-by, making drift detectable on the next landscape verification.

- **Algorithm-list compatibility with the management workstation's SSH client:** the `KexAlgorithms`/`Ciphers`/`MACs` allow-lists assume an OpenSSH 9.x client on the management workstation. The current `ssh.exe` on Windows 11 is OpenSSH 9.5+ (verified by the discovery run on 2026-07-08 — the run used 14 SSH probes with no algorithm complaints). If the user later SSHes from a much older client (e.g. PuTTY < 0.78 with no modern-algorithm support), the handshake may fail. Mitigation: the algorithm lists here are the same ones that `hetzner-prod` has been running with since 2026-05-12 (per the landscape-reader step 02 note that T-0040 SHA-1 MAC drop is open on `hetzner-prod` but the algorithm-list changes were applied via the earlier sibling runs); if any client compatibility issue arises it would already be visible on `hetzner-prod`.

- **Algorithm-list openssl interoperability:** the explicit `Ciphers` and `MACs` lists include the OpenSSH-portable algorithm names (e.g. `chacha20-poly1305@openssh.com`) which OpenSSH understands natively. The drop-in is parsed by `sshd` on Ubuntu 26.04's OpenSSH 9.x; no other daemon reads it. No compatibility risk.

- **pro-data.tech recovery options unknown:** the landscape (`landscape/hosts/pro-data-tech-qa.md` `## Network` section) explicitly notes that pro-data.tech may or may not expose a control-plane snapshot/backup option and that the provider does not expose plan tier / datacenter labels via in-host metadata. If the live SSH probe in step 12 fails and the rollback sequence in steps 1–4 cannot be executed (e.g. host is fully unreachable), the recovery options are not enumerated here. The executor must escalate to the user with the verbatim failure; the user can then engage pro-data.tech support for console / VNC / recovery-image access. This is **not** a defect of the plan — it is a known gap in the landscape that should be filled by a future discovery run (T-0098 or a new task).

- **`50-cloud-init.conf` does not exist on this host:** the landscape-reader confirmed the only cloud-init drop-in is `60-cloudimg-settings.conf`. The drop-in header comment in `40-ai-dala-infra.conf` references "50-cloud-init.conf and 60-cloudimg-settings.conf" for documentation accuracy against the OpenSSH convention (most Ubuntu hosts ship `50-cloud-init.conf`); on this specific host only `60-cloudimg-settings.conf` is present and that is the one that matters for first-wins ordering. The header comment is documentation, not config — no functional impact.

- **No design doubts / no high-severity risks:** the design follows a pattern already proven on `hetzner-prod` (T-0007 done 2026-05-12, run `2026-05-12-disable-ssh-password-auth-001`). The T-0040 / T-0049 / T-0050 sibling tasks (still open on `hetzner-prod`) provide additional precedent for the algorithm-list, X11Forwarding, and ClientAliveInterval directives. The Option B pre-work for `AllowGroups sshusers` resolves the only sequencing question from steps 01/02/03. Emit `NEEDS_APPROVAL` because blast radius is `medium` (per task frontmatter) — this is the protocol-mandated verdict for medium-blast-radius state-changing plans, not because the designer has doubts.

## Open questions (optional)

- None for design. All sequencing, algorithm, and user-decision questions are resolved by the user decision context recorded in `landscape/hosts/pro-data-tech-qa.md` (root login via `PermitRootLogin prohibit-password` + provider key as break-glass; `AllowGroups sshusers`; no UFW source restrictions; host-id stays `pro-data-tech-qa`). Option B's pre-work resolves the T-0093 ↔ T-0097 circular dependency without splitting the work.

- **Non-blocking observation (for landscape-updater at step 08):** the landscape `## Open questions` currently records "Should cloud-init be reconfigured (`ssh_pwauth: false`) to stop setting `PasswordAuthentication yes` in `60-cloudimg-settings.conf`?" This is a known follow-up to T-0093; landscape-updater should leave it open (not in scope for this run) but consider referencing T-0093 as the precedent when promoting it to a future task.