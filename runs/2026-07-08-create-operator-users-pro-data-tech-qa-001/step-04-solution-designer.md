---
run_id: 2026-07-08-create-operator-users-pro-data-tech-qa-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-08T00:00:00Z
task_id: T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-03-task-validator.md
  - tasks/T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/hetzner-prod.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
  - shared/verdicts.md
next_step_hint: User-approval gate (step 05). Per orchestrator's "just go" delegation, the run will auto-approve at step 05; emitting NEEDS_APPROVAL here to be explicit about the gate as the prompt requested.
---

## Summary

Create three non-root operator users (`tvolodi`, `viktor_d`, `binali_r`) on `pro-data-tech-qa` (95.46.211.230), each with NOPASSWD sudo, key-only auth via project-specific ed25519 pubkeys, and membership in the `sshusers` group (gid 1000) so the post-T-0093 `AllowGroups sshusers` sshd directive admits them. Plan reuses the sibling-host precedent from `hetzner-prod` (uid 1001, primary group = username, secondary groups `sudo`+`users`+`sshusers`, drop-in `/etc/sudoers.d/90-<user>` mode 0440 root:root). UIDs 1001/1002/1003 are reserved for human operators; the executor's `# What does NOT change` note will flag UID 1100+ for future application/service users (so T-0090 doesn't collide). The run is fully reversible via `userdel -r` + `gpasswd -d sshusers` + `rm /etc/sudoers.d/90-<user>` and the provider key in `/root/.ssh/authorized_keys` remains as break-glass anchor throughout.

## Pre-flight checks (run by executor first)

| ID | Check | Pass criterion |
|---|---|---|
| P01 | All three workstation pubkey files exist on the management host | `Test-Path C:\Users\tvolo\.ssh\ai-dala-infra.pub` and the two `-viktor-d` / `-binali-r` siblings all return `True`. Verified 2026-07-08 by step-04 designer. |
| P02 | Workstation has the `tvolodi` private key (`ai-dala-infra`) for live SSH test | `Test-Path C:\Users\tvolo\.ssh\ai-dala-infra` returns `True`. The other two operators' private keys are intentionally absent from this workstation — live SSH handshake for `viktor_d` / `binali_r` is deferred to each operator's own workstation. |
| P03 | `/root/.ssh/authorized_keys` on host contains the provider key (break-glass anchor) and is unchanged from baseline | `wc -l /root/.ssh/authorized_keys` returns `1`; the single line matches the `rsa-key-20260707` comment. |
| P04 | No `tvolodi` / `viktor_d` / `binali_r` user already exists (idempotency) | `id tvolodi` / `id viktor_d` / `id binali_r` each return `id: '<user>': no such user`. **Idempotent rerun:** if any user already exists, the executor must skip that user's `useradd` and treat the run as partial-success (capture which users were created fresh vs already present). |
| P05 | UIDs 1001/1002/1003 are not in use on the host | `getent passwd 1001` / `1002` / `1003` all return empty. (Verified 2026-07-08 by step-02: only `root` and `nobody` exist in the 0–65533 range.) |
| P06 | `sshusers` group exists with gid 1000 | `getent group sshusers` returns `sshusers:x:1000:root` (root is sole current member, per T-0093). If the group is missing, executor runs `groupadd -g 1000 sshusers` first. |
| P07 | `sudo` and `users` groups exist | `getent group sudo` → `sudo:x:27:` (empty here). `getent group users` → `users:x:100:` (empty here). Both present per step-02. |
| P08 | `/etc/sudoers.d/` directory exists and `visudo` is available | `test -d /etc/sudoers.d && command -v visudo` both succeed. Standard Ubuntu 26.04 — assumed present. |

## Plan

The plan is 12 ordered steps. Every step is **idempotent** unless flagged. State-changing commands are followed by their immediate verification check (the V-NN tags match the Verification matrix below). All commands run on `pro-data-tech-qa` (95.46.211.230) via the existing root provider key — no parallel sshd reconfiguration is involved; `AllowGroups sshusers` is already in effect from T-0093.

### Step 0 — Snapshot rollback state (pre-condition for full reversibility)

```bash
# Run as root over SSH
mkdir -p /var/backups/pre-T-0097-$(date -u +%Y%m%dT%H%M%SZ)
cp -a /etc/sudoers /var/backups/pre-T-0097-*/sudoers
cp -a /etc/sudoers.d /var/backups/pre-T-0097-*/sudoers.d
cp -a /etc/passwd /var/backups/pre-T-0097-*/passwd
cp -a /etc/shadow /var/backups/pre-T-0097-*/shadow
cp -a /etc/group  /var/backups/pre-T-0097-*/group
cp -a /etc/gshadow /var/backups/pre-T-0097-*/gshadow
chmod -R 0700 /var/backups/pre-T-0097-*
ls -la /var/backups/pre-T-0097-*
```
Verification: directory exists and contains 5 system-file copies; mode 0700 root:root.

### Step 1 — Create `tvolodi` user (uid 1001)

```bash
# Run as root
getent passwd tvolodi >/dev/null && echo "tvolodi: already exists (idempotent skip)" || \
  useradd -m -u 1001 -s /bin/bash -c "Operator: tvolodi (workstation user)" -U tvolodi
passwd -l tvolodi
```
- `-U` creates a user-private primary group `tvolodi` with same gid (1001).
- `passwd -l` locks the password (no password login; key-only via `AllowGroups sshusers` + `PasswordAuthentication no`).
Verification: `getent passwd tvolodi` shows `tvolodi:x:1001:1001:Operator: tvolodi (workstation user):/home/tvolodi:/bin/bash`. `passwd -S tvolodi` shows `L` (locked). Maps to V01, V14, V15.

### Step 2 — Create `viktor_d` user (uid 1002)

```bash
# Run as root
getent passwd viktor_d >/dev/null && echo "viktor_d: already exists (idempotent skip)" || \
  useradd -m -u 1002 -s /bin/bash -c "Operator: viktor_d (multi-PC)" -U viktor_d
passwd -l viktor_d
```
Verification: same shape as Step 1 with uid 1002. Maps to V02, V14, V15.

### Step 3 — Create `binali_r` user (uid 1003)

```bash
# Run as root
getent passwd binali_r >/dev/null && echo "binali_r: already exists (idempotent skip)" || \
  useradd -m -u 1003 -s /bin/bash -c "Operator: binali_r (multi-PC)" -U binali_r
passwd -l binali_r
```
Verification: same shape as Step 1 with uid 1003. Maps to V03, V14, V15.

### Step 4 — Add all three users to secondary groups (`sudo`, `users`, `sshusers`)

```bash
# Run as root — `gpasswd -a` is idempotent; safe to re-run
for u in tvolodi viktor_d binali_r; do
  gpasswd -a "$u" sudo
  gpasswd -a "$u" users
  gpasswd -a "$u" sshusers
done
```

**Ordering note (per validator's risk call-out):** the `sshusers` group add is done here, BEFORE the `authorized_keys` writes in Steps 5–7. This minimizes the lockout window for `tvolodi` (the operator with a private key on this workstation): once `tvolodi` is in `sshusers`, `AllowGroups sshusers` would admit them — but they can only authenticate if a pubkey is on file, so the practical lockout window is the `gpasswd -a tvolodi sshusers` → `authorized_keys` write gap (a few hundred milliseconds). For `viktor_d` and `binali_r`, no lockout is possible yet because no pubkey is on file and their private keys aren't on this box.

Verification: `id <user>` for each shows all four groups (primary + sudo + users + sshusers). Maps to V01, V02, V03.

### Step 5 — Create `~/.ssh/` directories with correct ownership + mode

Per the sibling-host precedent (hetzner-prod.md, ubuntu-16gb-nbg1-1.md), the project's audit baseline is **`root:<user>` ownership on `/home/<user>/.ssh/` and `authorized_keys`**, not `<user>:<user>`. OpenSSH accepts either scheme; the sibling pattern is the project convention.

> **Note vs. user prompt:** the prompt's section "Critical design points to resolve" suggests `chown -R <user>:<user>` and `chmod 700` / `chmod 600`. This design uses the sibling-host pattern (`root:<user>`, mode 0700 for `.ssh/`, 0600 for `authorized_keys`) for audit-log parity with `hetzner-prod` and `ubuntu-16gb-nbg1-1`. The functional outcome (key auth works) is identical; the only difference is which account owns the file. See "Open questions" for explicit acknowledgment.

```bash
# Run as root
for u in tvolodi viktor_d binali_r; do
  install -d -m 0700 -o root -g "$u" /home/"$u"/.ssh
  chmod 0700 /home/"$u"/.ssh
  chown root:"$u" /home/"$u"/.ssh
done
```
Verification: `ls -ld /home/<user>/.ssh` for each shows `drwx------ root <user>`. Maps to V07.

### Step 6 — Install operator pubkeys into each `authorized_keys`

```bash
# Run as root, with pubkey contents streamed from the management workstation
# via `ssh ... cat <pubkey> | sudo tee ...` (or scp + install — executor picks)

# tvolodi
install -m 0600 -o root -g tvolodi \
  /dev/stdin /home/tvolodi/.ssh/authorized_keys <<'KEY'
$(cat C:\Users\tvolo\.ssh\ai-dala-infra.pub on workstation, streamed via stdin)
KEY

# viktor_d
install -m 0600 -o root -g viktor_d \
  /dev/stdin /home/viktor_d/.ssh/authorized_keys <<'KEY'
$(cat C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub on workstation, streamed via stdin)
KEY

# binali_r
install -m 0600 -o root -g binali_r \
  /dev/stdin /home/binali_r/.ssh/authorized_keys <<'KEY'
$(cat C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub on workstation, streamed via stdin)
KEY
```

Executor's preferred transfer mechanism: `ssh root@95.46.211.230 'cat > /tmp/<filename>.pub' < C:\Users\tvolo\.ssh\<filename>.pub`, then `install -m 0600 -o root -g <user> /tmp/<filename>.pub /home/<user>/.ssh/authorized_keys`. This avoids PowerShell heredoc quirks. After install, `rm -f /tmp/<filename>.pub` on the host (no persistent secrets on tmpfs).

**Pubkey values (one-line ed25519 strings, executor reads these from the workstation files at run time):**
- `tvolodi` → `C:\Users\tvolo\.ssh\ai-dala-infra.pub` (ed25519, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`, comment `ai-dala-infra-mgmt@tvolodi-2026-05-12`)
- `viktor_d` → `C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub` (ed25519, fingerprint `SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw`, comment `viktor_d@ai-dala-infra-2026-06-27`)
- `binali_r` → `C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub` (ed25519, fingerprint `SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8`, comment `binali_r@ai-dala-infra-2026-06-27`)

These fingerprints are referenced by the **name** of the file (e.g., `ai-dala-infra.pub`) and not by inline value; executor must read the pubkey content from the workstation files at execution time.

Verification: `ssh-keygen -lf /home/<user>/.ssh/authorized_keys -E sha256` returns the expected fingerprint (per file). `ls -l /home/<user>/.ssh/authorized_keys` shows `-rw------- root <user>`. Maps to V04, V05, V06, V07.

### Step 7 — Write NOPASSWD sudo drop-ins

```bash
# Run as root
cat > /tmp/90-tvolodi   <<'EOF'
tvolodi ALL=(ALL) NOPASSWD: ALL
EOF
cat > /tmp/90-viktor-d  <<'EOF'
viktor_d ALL=(ALL) NOPASSWD: ALL
EOF
cat > /tmp/90-binali-r  <<'EOF'
binali_r ALL=(ALL) NOPASSWD: ALL
EOF

# Validate BEFORE installing (catch syntax errors before committing to /etc/sudoers.d/)
visudo -c -f /tmp/90-tvolodi
visudo -c -f /tmp/90-viktor-d
visudo -c -f /tmp/90-binali-r

# Move into place atomically (mode 0440, owner root:root)
install -m 0440 -o root -g root /tmp/90-tvolodi  /etc/sudoers.d/90-tvolodi
install -m 0440 -o root -g root /tmp/90-viktor-d /etc/sudoers.d/90-viktor-d
install -m 0440 -o root -g root /tmp/90-binali-r /etc/sudoers.d/90-binali-r
rm -f /tmp/90-tvolodi /tmp/90-viktor-d /tmp/90-binali-r

# Final whole-file sudoers validation
visudo -c
```

**Naming:** The user's prompt suggested `90-<user>` (using the literal username, including the underscore). I follow this. Filenames are `90-tvolodi`, `90-viktor-d`, `90-binali-r` (preserving the underscore in the content but using `-` in the filename for filesystem hygiene; sudo drop-in filenames have no semantic meaning — only the content matters).

Verification: `visudo -c` exits 0. `ls -l /etc/sudoers.d/90-*` shows `-r--r----- root root`. `cat /etc/sudoers.d/90-<user>` matches the expected single line. Maps to V08, V09.

### Step 8 — Live SSH test for `tvolodi` from the management workstation

```bash
# Run from the management workstation (PowerShell or bash)
ssh -i $HOME/.ssh/ai-dala-infra -o IdentitiesOnly=yes \
  tvolodi@95.46.211.230 \
  'whoami && id && sudo -n true && echo SUDO_OK && exit'
```
**Expected output:** `tvolodi\nuid=1001(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),100(users),1000(sshusers)\nSUDO_OK`.

If this fails with `Permission denied (publickey)`, the most likely cause is the `authorized_keys` write in Step 6 didn't land (file mode/ownership wrong). Recovery: re-run Step 5 + 6 for `tvolodi`, then re-test.

**Note:** `viktor_d` and `binali_r` are NOT live-tested here because their private keys are not on this management workstation. Live SSH for those operators is correctly deferred to operator A's / operator B's own workstations. Maps to V10 (partial — only `tvolodi`).

### Step 9 — Server-side authorized_keys parse check for `viktor_d` and `binali_r`

```bash
# Run as root on the host (since ssh-keygen can read any mode 0600 file as root)
ssh-keygen -lf /home/viktor_d/.ssh/authorized_keys  -E sha256
ssh-keygen -lf /home/binali_r/.ssh/authorized_keys  -E sha256
# Expected output:
#   256 SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw  viktor_d@ai-dala-infra-2026-06-27 (ED25519)
#   256 SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8  binali_r@ai-dala-infra-2026-06-27 (ED25519)
```
Maps to V11, V12. **Strongest server-side guarantee available from this workstation** — but it is *not* a live handshake. The validator must clearly distinguish this from operator A/B's future live handshakes (the multi-PC caveat from T-0097's acceptance criterion #6).

### Step 10 — Confirm provider key break-glass anchor still intact

```bash
# Run as root
wc -l /root/.ssh/authorized_keys
grep -c '^ssh-rsa' /root/.ssh/authorized_keys  # or ssh-ed25519 / ecdsa; depends on provider key algorithm
head -1 /root/.ssh/authorized_keys             # must end with `rsa-key-20260707`
```
Expected: `1` line, comment `rsa-key-20260707`. Maps to V13.

### Step 11 — Document the user-creation pattern in landscape (deferred to step 08)

The executor does NOT modify landscape files. The landscape-updater at step 08 will:
- Rewrite `## Access` in `landscape/hosts/pro-data-tech-qa.md` to list the three operator users with uid, groups, sudoers drop-in path, pubkey-filename reference (no pubkey values in repo).
- Update `## What needs to happen` item #2 (was "T-0097 — operator user creation") to ✅ done.
- Remove T-0097 from `## Open tasks affecting this host`.
- Bump `last_verified:` to `2026-07-08` (already current; may not need bump — landscape-updater's call).

Maps to V16 (documentation).

### Step 12 — Rollback dry-run documentation

The executor produces a comment block in the run log containing the rollback script for that run (filled in below). This is dry-run only — not executed unless a rollback is actually needed.

## Rollback

**Per-user rollback** (reverses the work done for a single user):

```bash
# Run as root
USERNAME=$1  # pass tvolodi / viktor_d / binali_r
test -n "$USERNAME" || { echo "Usage: $0 <username>"; exit 2; }

# 1. Remove sudoers drop-in (if it exists; -f suppresses the error on first-run re-runs)
rm -f "/etc/sudoers.d/90-${USERNAME//_/-}"
visudo -c

# 2. Remove user from sshusers / sudo / users groups
gpasswd -d "$USERNAME" sshusers 2>/dev/null
gpasswd -d "$USERNAME" sudo     2>/dev/null
gpasswd -d "$USERNAME" users    2>/dev/null

# 3. Remove user + home dir + primary group
userdel -r "$USERNAME"

# 4. Sanity check: user no longer present
id "$USERNAME" 2>&1 | grep -q 'no such user' && echo "rollback: $USERNAME removed"
```

**Full-run rollback** (reverses everything, in case all three users were created and none should have been):

```bash
for u in tvolodi viktor_d binali_r; do
  rm -f /etc/sudoers.d/90-${u//_/-}
  gpasswd -d "$u" sshusers 2>/dev/null
  gpasswd -d "$u" sudo     2>/dev/null
  gpasswd -d "$u" users    2>/dev/null
  userdel -r "$u"
done
visudo -c
id tvolodi 2>&1 | grep -q 'no such user' && echo "rollback: tvolodi removed"
id viktor_d 2>&1 | grep -q 'no such user' && echo "rollback: viktor_d removed"
id binali_r 2>&1 | grep -q 'no such user' && echo "rollback: binali_r removed"
```

**Files modified on host (reversible via per-file recovery from `/var/backups/pre-T-0097-*/`):**
- `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow` — recover from Step 0 snapshot.
- `/etc/sudoers.d/90-tvolodi`, `/etc/sudoers.d/90-viktor-d`, `/etc/sudoers.d/90-binali-r` — recover from Step 0 snapshot.
- `/home/<user>/.ssh/`, `/home/<user>/.ssh/authorized_keys` — recover via `userdel -r` re-run (full cleanup) or per-file from snapshot.

**Files NOT touched (provider key break-glass anchor preserved):**
- `/root/.ssh/authorized_keys` — provider key line is never modified by this run.

## Verification matrix (V01–V16)

Each row is a single, deterministic check the execution-validator (step 07) re-runs. All on-host checks run as root via the provider key. The "External" row (V10) runs from the management workstation.

| ID | Layer | Command (run as root on host, unless External) | Pass criterion |
|---|---|---|---|
| V01 | On-host | `id tvolodi` | `uid=1001(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),100(users),1000(sshusers)` |
| V02 | On-host | `id viktor_d` | `uid=1002(viktor_d) gid=1002(viktor_d) groups=1002(viktor_d),27(sudo),100(users),1000(sshusers)` |
| V03 | On-host | `id binali_r` | `uid=1003(binali_r) gid=1003(binali_r) groups=1003(binali_r),27(sudo),100(users),1000(sshusers)` |
| V04 | On-host | `stat -c '%a %U:%G' /home/tvolodi/.ssh/authorized_keys && ssh-keygen -lf /home/tvolodi/.ssh/authorized_keys -E sha256` | `600 root:tvolodi` AND `256 SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8 ai-dala-infra-mgmt@tvolodi-2026-05-12 (ED25519)` |
| V05 | On-host | same for `viktor_d` | `600 root:viktor_d` AND `256 SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw viktor_d@ai-dala-infra-2026-06-27 (ED25519)` |
| V06 | On-host | same for `binali_r` | `600 root:binali_r` AND `256 SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8 binali_r@ai-dala-infra-2026-06-27 (ED25519)` |
| V07 | On-host | `stat -c '%a %U:%G' /home/<user>/.ssh` for each user | `700 root:<user>` for all three |
| V08 | On-host | `stat -c '%a %U:%G %n' /etc/sudoers.d/90-tvolodi /etc/sudoers.d/90-viktor-d /etc/sudoers.d/90-binali-r && cat /etc/sudoers.d/90-tvolodi /etc/sudoers.d/90-viktor-d /etc/sudoers.d/90-binali-r` | `440 root:root` AND content `<user> ALL=(ALL) NOPASSWD: ALL` for each |
| V09 | On-host | `visudo -c` | `parsed OK` (exit 0) |
| V10 | External (workstation) | `ssh -i $HOME/.ssh/ai-dala-infra -o IdentitiesOnly=yes tvolodi@95.46.211.230 'whoami && id && sudo -n true && echo SUDO_OK'` | Returns `tvolodi`, full `id` output with `sshusers` group, `SUDO_OK`. No `Permission denied`. **This is the only live SSH handshake claimable from this workstation.** |
| V11 | On-host | `ssh-keygen -lf /home/viktor_d/.ssh/authorized_keys -E sha256` | `256 SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw viktor_d@ai-dala-infra-2026-06-27 (ED25519)`. **Server-side parse only — does NOT exercise a live handshake (operator A's private key is not on this workstation).** |
| V12 | On-host | `ssh-keygen -lf /home/binali_r/.ssh/authorized_keys -E sha256` | `256 SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8 binali_r@ai-dala-infra-2026-06-27 (ED25519)`. Same caveat as V11. |
| V13 | On-host | `wc -l /root/.ssh/authorized_keys && head -1 /root/.ssh/authorized_keys` | `1` line, ends with `rsa-key-20260707` (provider key, break-glass anchor). |
| V14 | On-host | `passwd -S tvolodi; passwd -S viktor_d; passwd -S binali_r` | Each line shows `L` in the second field (password locked). No `NP` (no password) since we used `passwd -l` (lock), not `passwd -d` (delete). `L` is what we want: the account has a disabled-password entry in `/etc/shadow`, preventing any password-based login. |
| V15 | On-host | `getent passwd tvolodi; getent passwd viktor_d; getent passwd binali_r` | Each line ends with `/bin/bash`. The 5th field (GECOS) is `Operator: <user> <annotation>`. |
| V16 | Documentation | `landscape/hosts/pro-data-tech-qa.md` `## Access` block after step-08 update | Lists `tvolodi` (uid 1001), `viktor_d` (uid 1002), `binali_r` (uid 1003); references pubkey-filenames (no inline values); `## What needs to happen` item #2 marked ✅ done; T-0097 removed from `## Open tasks affecting this host`; `last_verified` field is current. |

**Verification done by this workstation** (V10 covers `tvolodi`'s live SSH + `sudo -n true` returning `SUDO_OK`). **Verification deferred to operator workstations** (live SSH for `viktor_d` from operator A's box, live SSH for `binali_r` from operator B's box). The validator must clearly distinguish these two layers in its report.

## Resources used

- **Secrets (by name, no values):**
  - `C:\Users\tvolo\.ssh\ai-dala-infra.pub` (workstation pubkey for `tvolodi`).
  - `C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub` (workstation pubkey for `viktor_d`).
  - `C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub` (workstation pubkey for `binali_r`).
  - Private keys for `viktor_d` and `binali_r` are NOT on this workstation; live handshakes deferred.
  - The provider's `rsa-key-20260707` (in `/root/.ssh/authorized_keys`) is the run's break-glass anchor; not used for the operator users themselves.
- **Files modified on host:**
  - `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow` (3 new users + 3 new group memberships).
  - `/home/tvolodi/.ssh/` (dir, mode 0700, root:tvolodi).
  - `/home/viktor_d/.ssh/` (dir, mode 0700, root:viktor_d).
  - `/home/binali_r/.ssh/` (dir, mode 0700, root:binali_r).
  - `/home/tvolodi/.ssh/authorized_keys` (file, mode 0600, root:tvolodi, 1 ed25519 pubkey line).
  - `/home/viktor_d/.ssh/authorized_keys` (same, root:viktor_d).
  - `/home/binali_r/.ssh/authorized_keys` (same, root:binali_r).
  - `/etc/sudoers.d/90-tvolodi` (file, mode 0440, root:root, single line).
  - `/etc/sudoers.d/90-viktor-d` (same).
  - `/etc/sudoers.d/90-binali-r` (same).
  - `/var/backups/pre-T-0097-*/` (5 system-file snapshots from Step 0).
  - **NOT modified:** `/root/.ssh/authorized_keys` (provider key preserved).
- **Files modified in this repo (deferred to landscape-updater at step 08):**
  - `landscape/hosts/pro-data-tech-qa.md` — `## Access` block rewritten; `## What needs to happen` item #2 marked ✅ done; T-0097 removed from `## Open tasks affecting this host`; `last_verified` field possibly bumped.
- **External APIs called:** none (this run is entirely host-local; no Hetzner API, no Cloudflare API, no GitHub API).

## Estimated impact

- **Downtime:** none (no service interruption; sshd is not reloaded; only `/etc/passwd`, `/etc/group`, and `/etc/sudoers.d/` are touched, none of which require a daemon restart for sshd).
- **Affected services:**
  - `sshd` — config unchanged; `AllowGroups sshusers` already in effect; new operators become admissible as each `sshusers` membership lands.
  - `sudo` — three new drop-ins loaded at next `sudo` invocation (sudo re-reads `/etc/sudoers.d/` per invocation, no daemon restart needed).
- **Affected users / groups:**
  - 3 new OS users (`tvolodi`, `viktor_d`, `binali_r`); uids 1001, 1002, 1003.
  - 3 new group memberships on the existing `sudo` (gid 27), `users` (gid 100), `sshusers` (gid 1000) groups.
- **Reversibility:** **fully reversible** via the per-user rollback script above. Snapshots in `/var/backups/pre-T-0097-*/` provide defense-in-depth recovery. Provider key in `/root/.ssh/authorized_keys` is never modified, preserving the break-glass path. No irreversible operation (no `dd`, no `mkfs`, no destructive fs op, no `rm -rf /`).

## Issues / risks

- **`~/.ssh/` ownership convention.** The user prompt's "Critical design points to resolve" section suggests `chown -R <user>:<user>`. This plan uses the sibling-host precedent of `root:<user>`. OpenSSH accepts either scheme as long as files are not group- or world-writable; the functional outcome is identical. The sibling-host pattern is the project's audit baseline (per hetzner-prod.md and ubuntu-16gb-nbg1-1.md). **Risk severity:** low — operational convention; OpenSSH validates both. **Mitigation:** if the user explicitly wants `<user>:<user>`, the plan can be amended in 30 seconds by changing Steps 5–6 to use `-o <user> -g <user>` instead of `-o root -g <user>`. The validator at step 07 should accept either as long as file modes are 0700/0600 and the pubkey parses.
- **Multi-PC acceptance scope.** `viktor_d` and `binali_r` private keys are NOT on this management workstation. Step 07's validator must clearly distinguish (a) `tvolodi` live SSH + sudo from this workstation, (b) server-side `ssh-keygen -lf` parse for the other two, from (c) operator A/B's future live SSH from their own workstations (deferred until they are present). **Risk severity:** low — explicitly called out in T-0097's "Multi-PC acceptance criterion"; not over-claiming is the goal.
- **Lockout window for `tvolodi`.** Adding `tvolodi` to `sshusers` happens BEFORE writing `authorized_keys` (Step 4 → Step 6). This minimizes but does not eliminate the window where `tvolodi` is in `sshusers` but cannot authenticate (because the pubkey isn't on file yet). The window is hundreds of milliseconds in practice. The provider key remains valid throughout; recovery is always available. **Risk severity:** low.
- **`AllowGroups sshusers` ordering vs. cloud-init fallback.** The post-T-0093 `AllowGroups sshusers` directive is in effect. The provider key in `/root/.ssh/authorized_keys` is governed by `PermitRootLogin prohibit-password`, NOT by `AllowGroups`, so root login via the provider key is always available regardless of `sshusers` membership. **Risk severity:** none — break-glass path is fully independent of the operator-user provisioning.
- **Heredoc / PowerShell quirks in pubkey transfer.** PowerShell's handling of native stdin / ssh heredocs is quirky. The executor should use `ssh root@... 'cat > /tmp/x.pub' < C:\Users\tvolo\.ssh\...pub` to stream the pubkey over the SSH connection (clean stdin transfer), then `install -m 0600 -o root -g <user> /tmp/x.pub /home/<user>/.ssh/authorized_keys`, then `rm /tmp/x.pub`. **Risk severity:** low — operational; well-precedented.
- **`passwd -l` vs. `passwd -d`.** Plan uses `-l` (lock the password entry in `/etc/shadow`). Some sibling hosts used `-d` (delete the password). Both block password-based login. `-l` is preferred because it preserves the entry (auditable later), whereas `-d` leaves an empty password field. **Risk severity:** none — purely an audit-log choice.
- **UID-range reservation for T-0090.** The executor's "What does NOT change" note must flag that UIDs 1001/1002/1003 are now reserved for human operators, and that T-0090 (Docker, application baseline) should pick application/service users at UID 1100+ to avoid collision. **Risk severity:** low — coordination note for a future task.
- **No off-site storage / no external secrets.** This run introduces no external storage targets and no secret values in the repo. Pubkeys are referenced by file path (e.g., `C:\Users\tvolo\.ssh\ai-dala-infra.pub`), not by inline value or fingerprint. **Risk severity:** none — fully compliant with project policy.
- **No concurrent runs against this host.** Step-02 confirmed no other active run touches `pro-data-tech-qa`. T-0094 (UFW) and T-0095 (fail2ban) are eligible but not yet executing. **Risk severity:** none.

## Open questions

- **Ownership of `~/.ssh/` and `authorized_keys` (root:user vs. user:user).** Plan uses `root:<user>` for sibling-host parity. If the user explicitly prefers `<user>:<user>` (as the prompt's bullet suggests), amend Steps 5–6 to use `-o <user> -g <user>`. The validation matrix (V04–V07) currently asserts `root:<user>`; if amended, change V04–V07 expectations to `<user>:<user>`. **This is a 30-second design amendment, not a blocker.**
- **Default shell `bash` vs. something else.** Sibling hosts use `/bin/bash`; plan uses `/bin/bash`. No operator has requested an alternative. **No change expected.**
- **Lockout risk for `tvolodi` if Step 6 fails mid-write.** If `install -m 0600 ... /home/tvolodi/.ssh/authorized_keys` is interrupted (network blip), the file may be partial. Recovery: re-run Step 6 (it's idempotent — `install` overwrites). Provider key remains valid throughout. **No design change needed; flagged for executor's awareness.**
- **Concatenation with existing `authorized_keys` if user already exists (partial rerun).** If a previous partial run left a `authorized_keys` with no matching pubkey, `install` will overwrite it. The plan does not check for or preserve pre-existing pubkeys. **Risk severity:** very low — pre-flight P04 catches this case; if the user already exists and has a valid pubkey, Step 1/2/3 are skipped but Step 6 still overwrites — which is the safe choice (re-establish authoritative state).

## Why `NEEDS_APPROVAL` (despite "just go" delegation)

Per the prompt's explicit instruction, I emit `NEEDS_APPROVAL` even though:

1. `estimated_blast_radius: medium` (per T-0097 frontmatter) and the design's reversibility is `full` — together with the sibling-host precedent this would normally qualify for auto-`PASS`.
2. The orchestrator's "just go" delegation (recorded in step-01) explicitly waives the human-approval gate at step 05.
3. The plan has no high-severity risks; the deviation from the prompt's "user:user" ownership convention is low-severity and reversible.
4. The `~/.ssh/` ownership convention (`root:<user>` vs. `<user>:<user>`) is a real design decision the user may want to override.

The user-prompt explicitly asks for `NEEDS_APPROVAL` "to be explicit about the gate". Honored. The step-05 file will be auto-approved and the executor will run.

## Plan summary

12 ordered steps (Snapshot → 3× useradd + passwd-l → group add → ssh dir → authorized_keys → sudoers drop-ins → live SSH test for `tvolodi` → server-side parse for `viktor_d` / `binali_r` → provider-key preservation check → landscape documentation at step-08 → rollback dry-run). 16 verification checks. 3 operator users. Fully reversible. Break-glass preserved. No off-site storage. Multi-PC acceptance caveat explicitly captured.