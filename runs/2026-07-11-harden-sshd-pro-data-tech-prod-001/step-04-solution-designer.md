---
run_id: 2026-07-11-harden-sshd-pro-data-tech-prod-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-11T00:00:00Z
task_id: T-0102-harden-sshd-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-02-landscape-reader.md
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — present this plan to the user and await APPROVE/REJECT before the executor proceeds
---

## Summary

Apply the same sshd hardening profile used on `pro-data-tech-qa` (T-0093, 21/21 checks passed) to `pro-data-tech-prod` (`95.46.211.224`), taking the host from a fully unhardened cloud-init state (`PermitRootLogin yes`, `PasswordAuthentication yes`) to a hardened, key-only, `AllowGroups sshusers`-restricted state — with `root` pre-added to `sshusers` (since no operator users exist yet) and both a backup and `sshd -t` validation gate protecting against lockout.

## Details

### Approval rationale

`NEEDS_APPROVAL` is required. This is the **first-time SSH hardening change on a production host**. Per `shared/approval-protocol.md` (§ "Always requires NEEDS_APPROVAL"), first-time changes to prod SSH always require explicit user sign-off. Additionally: blast radius is MEDIUM (an ordering error or invalid config would lock out the only access path to the host, with no confirmed out-of-band console recovery available from the pro-data.tech provider).

---

### Pre-execution requirements

All plan steps are executed over a single live SSH session opened before any changes:
- **Connection command (from management workstation):** `ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224`
- The session MUST remain open throughout execution. A lockout requires the same session to still be alive for rollback.
- The `sshd -t` gate (step 8) and `id root | grep sshusers` gate (step 9) are **hard stops** — if either fails, execution halts and rollback is performed immediately. The executor MUST NOT call `systemctl reload sshd` if either gate fails.

---

### Plan

**Step 1 — Advisory pre-flight: check for pending openssh-server upgrade**

Rationale: landscape notes 12 pending upgrades; if `openssh-server` is in the list, the hardened drop-ins may be overwritten or config may change on the next unattended-upgrades run. Flag it; take no action in this run.

Command:
```
apt list --upgradable 2>/dev/null | grep openssh
```
Verification: output printed and captured in execution log. If `openssh-server` appears, the execution-validator must note it as a risk item for a follow-up upgrade task. No action required in this run; do not abort.

---

**Step 2 — Backup existing sshd config (idempotent)**

Command:
```
cp -r /etc/ssh /var/backups/pre-T0102.$(date +%Y%m%dT%H%M%SZ)
```
Verification: `ls /var/backups/ | grep pre-T0102` returns a timestamped directory; `ls /var/backups/pre-T0102.*/` contains `sshd_config`, `sshd_config.d/`, and `60-cloudimg-settings.conf`.

Rollback note: this backup enables full restoration of the pre-change state regardless of what follows.

---

**Step 3 — Create `sshusers` group (idempotent)**

Command:
```
groupadd -f sshusers
```
`-f` means "succeed silently if group already exists" — safe to re-run.

Verification: `getent group sshusers` returns a line of the form `sshusers:x:<gid>:`.

---

**Step 4 — Add root to `sshusers` (idempotent)**

Command:
```
usermod -aG sshusers root
```
`-aG` appends without removing existing group memberships — safe to re-run.

Verification: `id root | grep sshusers` must succeed (exit 0, prints `sshusers` in the groups list).

Ordering note: this step MUST complete successfully before the drop-in files are written and before sshd is reloaded. If root is not in `sshusers` when `AllowGroups sshusers` is active, root will be denied SSH access on any new connection (including reconnection attempts). The active session stays alive — but any new session would be blocked.

---

**Step 5 — Write `/etc/ssh/sshd_config.d/40-disable-password.conf`**

Command:
```
cat > /etc/ssh/sshd_config.d/40-disable-password.conf << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
```
Idempotency: overwriting an existing file with identical content is safe. If the file already exists with correct content, no change occurs.

First-wins semantics: `40-` sorts before the cloud-init `60-cloudimg-settings.conf` (which sets `PasswordAuthentication yes`); the `40-` file wins and disables password auth, overriding the cloud-init default.

---

**Step 6 — Write `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf`**

This file name matches the QA reference (`40-ai-dala-infra.conf`) exactly, for fleet consistency. (The orchestrator's prompt suggested `40-harden-sshd.conf`; `40-ai-dala-infra.conf` is used here to match the T-0093 / QA implementation — see Issues / risks for the naming note.)

Command:
```
cat > /etc/ssh/sshd_config.d/40-ai-dala-infra.conf << 'EOF'
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
EOF
```
Idempotency: overwriting an existing file with identical content is safe.

Directive coverage: `PermitRootLogin prohibit-password` (key-only root, no password), `AllowGroups sshusers` (login restricted to group members), `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, hardened KEX/Ciphers/MACs (no SHA-1, no CBC, no 3DES, no RC4). `UseDNS no` and `PubkeyAuthentication yes` are already the default on this host and are not set explicitly (consistent with the QA drop-in content).

---

**Step 7 — Set permissions on both drop-in files**

Command:
```
chmod 644 /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf
```
Verification: `ls -la /etc/ssh/sshd_config.d/` shows both files with `-rw-r--r--` (644), owner `root root`.

---

**Step 8 — HARD GATE: validate sshd config with `sshd -t`**

Command:
```
sshd -t
```
Expected: exit code 0, no output (or only informational output — no errors or warnings).

**If exit code is non-zero or any error is printed: ABORT. Do NOT proceed to step 9 or step 10. Execute rollback immediately (see Rollback section below).**

This gate is the primary defence against deploying an invalid config that would prevent sshd from starting on the next reload.

---

**Step 9 — HARD GATE: confirm root is in `sshusers` before reload**

Command:
```
id root | grep sshusers
```
Expected: exit code 0, output contains the string `sshusers`.

**If exit code is non-zero (root not in sshusers): ABORT. Do NOT reload sshd. Execute rollback immediately.**

This gate confirms that `AllowGroups sshusers` will not lock out root when the reload happens.

---

**Step 10 — Reload sshd (preserves active session)**

Command:
```
systemctl reload sshd
```
`reload` sends SIGHUP to the master sshd process — it re-reads config without terminating active sessions. The executor's session remains live throughout.

Verification: `systemctl is-active sshd` → `active`. `systemctl status sshd` shows `Active: active (running)`.

---

**Step 11 — Verify sshd service is still running**

Command:
```
systemctl is-active sshd
```
Expected: output is `active` (exit code 0). If output is `failed` or `inactive`, sshd is down — open a new SSH connection immediately (active session is still alive) to diagnose; do not close the current session.

---

**Step 12 — Verify effective config (sshd -T, 22 checks)**

Command (run as a block; capture full output):
```
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowgroups|kexalgorithms|ciphers|macs|usedns) '
```

Expected values (case-insensitive; sshd -T lowercases all output):

| Parameter | Expected value |
|---|---|
| `permitrootlogin` | `prohibit-password` |
| `passwordauthentication` | `no` |
| `kbdinteractiveauthentication` | `no` |
| `pubkeyauthentication` | `yes` |
| `permitemptypasswords` | `no` |
| `maxauthtries` | `3` |
| `logingracetime` | `30` |
| `x11forwarding` | `no` |
| `clientaliveinterval` | `300` |
| `clientalivecountmax` | `2` |
| `allowgroups` | `sshusers` |
| `kexalgorithms` | contains `curve25519-sha256` AND does NOT contain `sha1` |
| `ciphers` | contains `chacha20-poly1305` AND does NOT contain `3des` or `cbc` |
| `macs` | contains `etm@openssh.com` AND does NOT contain `hmac-sha1` |
| `usedns` | `no` |

---

**Step 13 — Verify group and membership**

Commands:
```
getent group sshusers
id root
```
Verification: `getent group sshusers` returns `sshusers:x:<gid>:root` (root is listed). `id root` output contains `sshusers`.

---

**Step 14 — Verify drop-in files**

Commands:
```
ls -la /etc/ssh/sshd_config.d/
cat /etc/ssh/sshd_config.d/40-disable-password.conf
cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf
```
Verification: both project-managed files exist with mode `644` and correct content. Cloud-init `60-cloudimg-settings.conf` still present and unchanged (27 B, `PasswordAuthentication yes` — will lose the directive battle due to first-wins ordering).

---

**Step 15 — Verify backup exists**

Command:
```
ls -la /var/backups/ | grep pre-T0102
ls /var/backups/pre-T0102.*/
```
Verification: backup directory exists and contains `sshd_config` and `sshd_config.d/`.

---

### Rollback

Rollback is applicable if: `sshd -t` (step 8) fails, the `id root | grep sshusers` gate (step 9) fails, or any post-reload verification fails unexpectedly.

**Rollback scenario A: before reload (most common — sshd -t or group-check gate fired)**

1. Remove both project drop-ins — command: `rm -f /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf`
2. Confirm the only remaining drop-in is the cloud-init file — command: `ls /etc/ssh/sshd_config.d/`
3. Re-validate config is clean — command: `sshd -t` (must exit 0)
4. Host is back to pre-change state (cloud-init defaults). No reload needed; sshd was never reloaded. The active session was never disrupted.

**Rollback scenario B: after reload, sshd behaves unexpectedly**

1. Remove both project drop-ins — command: `rm -f /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf`
2. Validate — command: `sshd -t`
3. Reload to restore cloud-init defaults — command: `systemctl reload sshd`
4. Verify — command: `systemctl is-active sshd`

**Rollback scenario C: complete restore from backup (catastrophic only)**

1. Restore full `/etc/ssh` from backup — command: `cp -r /var/backups/pre-T0102.<timestamp>/ssh/* /etc/ssh/`
2. Validate — command: `sshd -t`
3. Reload — command: `systemctl reload sshd`

**No rollback possible note:** if root is locked out AND the active session terminates before rollback is applied, out-of-band access is required. The pro-data.tech provider's console recovery path is **not confirmed** in the landscape. This is the primary lockout risk driving the NEEDS_APPROVAL verdict.

---

### Verification (for step 07)

**On-host checks (execute over SSH as root after the run):**

1. `ls /var/backups/ | grep pre-T0102` → timestamped directory exists
2. `ls -la /etc/ssh/sshd_config.d/40-disable-password.conf` → mode `644`, owner `root root`
3. `ls -la /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` → mode `644`, owner `root root`
4. `cat /etc/ssh/sshd_config.d/40-disable-password.conf` → exact content: `PasswordAuthentication no` and `KbdInteractiveAuthentication no`
5. `cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` → all 10 directives present with correct values (see Step 6 file content above)
6. `ls /etc/ssh/sshd_config.d/60-cloudimg-settings.conf` → still exists and is unchanged
7. `getent group sshusers` → group exists; `root` in member list
8. `id root | grep sshusers` → exit 0
9. `sshd -t` → exit 0, no errors
10. `systemctl is-active sshd` → `active`
11. `sshd -T | grep permitrootlogin` → `prohibit-password`
12. `sshd -T | grep passwordauthentication` → `no`
13. `sshd -T | grep kbdinteractiveauthentication` → `no`
14. `sshd -T | grep pubkeyauthentication` → `yes`
15. `sshd -T | grep maxauthtries` → `3`
16. `sshd -T | grep logingracetime` → `30`
17. `sshd -T | grep x11forwarding` → `no`
18. `sshd -T | grep clientaliveinterval` → `300`
19. `sshd -T | grep clientalivecountmax` → `2`
20. `sshd -T | grep allowgroups` → `sshusers`
21. `sshd -T | grep kexalgorithms` → contains `curve25519-sha256`, does NOT contain `sha1`
22. `sshd -T | grep ciphers` → contains `chacha20-poly1305`, does NOT contain `3des` or `cbc`
23. `sshd -T | grep macs` → contains `etm@openssh.com`, does NOT contain `hmac-sha1`

**External checks (execute from management workstation, while the executor's in-session connection is ALSO live — session preservation test):**

24. Open a second SSH connection from the management workstation (separate terminal) — command: `ssh -i C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk root@95.46.211.224 "whoami; id | grep sshusers"` → connection succeeds, output contains `root` and `sshusers`
25. Password rejection test — command: `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes root@95.46.211.224 exit` → rejected with `Permission denied (publickey).` (server advertises only `publickey` in auth-methods list; password auth is fully disabled)

---

### Resources used

- **Secrets (by name):** none. The SSH private key (`pro-data.tech-prod-instance_rsa.ppk`) is referenced by path only; its value is never logged.
- **Files modified on host:**
  - `/etc/ssh/sshd_config.d/40-disable-password.conf` (created)
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (created)
  - `/var/backups/pre-T0102.<timestamp>/` (created — backup, read-only after creation)
  - `/etc/group` (modified by `usermod -aG sshusers root`)
- **Files modified in this repo (landscape/) — to be applied at step 08:**
  - `landscape/hosts/pro-data-tech-prod.md` — update sshd state, sshusers group, security posture, drop-in file list, post-T-0102 done status. Note transitional state: root is in sshusers temporarily until T-0105 provisions operator users.
  - `tasks/T-0102-harden-sshd-on-pro-data-tech-prod.md` — update `status: done`, add completion date.
- **External APIs called:** none

---

### Estimated impact

- **Downtime:** none — `systemctl reload` (SIGHUP) preserves all active SSH sessions. No new connections are blocked during reload (the process is sub-second).
- **Affected services:** sshd only. No other services on this host are impacted (no Docker, no nginx, no application services present).
- **Reversibility:** fully reversible — backup at `/var/backups/pre-T0102.<timestamp>/`, `sshd -t` gate prevents reload of invalid config, active session is preserved throughout. Rollback deletes the two drop-in files and reloads sshd.

## Issues / risks

- **Lockout risk (HIGH, mitigated):** `AllowGroups sshusers` will deny ALL SSH logins if root is not in the `sshusers` group at reload time. Since no operator users exist on prod yet, root is the only member. The plan mitigates this with two hard gates (step 8: `sshd -t`, step 9: `id root | grep sshusers`) that abort execution if either fails. The active session is preserved throughout; rollback is possible via the live session if reload is not yet called.
- **No confirmed out-of-band recovery:** `landscape/hosts/pro-data-tech-prod.md` does not document any provider console / recovery-mode access for pro-data.tech (unlike Hetzner where the Rescue System is known). If root is locked out despite both gates passing — i.e., a bug in the plan's ordering — the only recovery path is provider console, which is unconfirmed. This is the primary reason for `NEEDS_APPROVAL`.
- **12 pending package upgrades (advisory):** if `openssh-server` is in the pending list (checked in step 1), an unattended-upgrades run after this run could modify the sshd package and potentially affect the drop-in files or reset config. The executor should flag this if observed; no action required in this run.
- **Transitional root-in-sshusers state:** root is added to `sshusers` as a temporary measure until T-0105 provisions operator users. On QA, root is NOT in `sshusers` (root login is governed solely by `PermitRootLogin prohibit-password`, not by `AllowGroups`). The landscape update (step 08) must document this transitional state clearly so T-0105 knows to add operator users to `sshusers` and then optionally remove root from the group.
- **Drop-in filename naming:** the second drop-in is named `40-ai-dala-infra.conf` (matching the QA T-0093 reference) rather than `40-harden-sshd.conf` (as hinted by the orchestrator prompt). This choice is deliberate — fleet naming consistency takes precedence over the prompt's naming suggestion. The executor should not deviate from `40-ai-dala-infra.conf`.
- **No `PubkeyAuthentication yes` in drop-in:** `PubkeyAuthentication yes` is the compiled-in default for OpenSSH. It is NOT set in the drop-in (consistent with QA's `40-ai-dala-infra.conf`). Setting it explicitly is redundant; the verification step confirms the effective value via `sshd -T` regardless.
