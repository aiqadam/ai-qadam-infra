---
run_id: 2026-07-11-create-operator-users-pro-data-tech-prod-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-11T00:00:00Z
task_id: T-0105-create-operator-users-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-02-landscape-reader.md
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — present plan to user; on APPROVED advance to executor-infra (step 06)
---

## Summary

Create three non-root operator accounts (`tvolodi`, `viktor_d`, `binali_r`) on `pro-data-tech-prod` (`95.46.211.224`), each added to the `sshusers` and `sudo` groups, with their confirmed ed25519 public keys in `authorized_keys` and a validated NOPASSWD sudoers drop-in — leaving `root` in `sshusers` throughout for break-glass access.

## Details

### SSH transport for all remote steps

All commands below are run on the remote host. The executor connects as:

```
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" root@95.46.211.224
```

The executor may open a single interactive session and run the commands sequentially, or pass each as a quoted remote argument. Either is acceptable; an interactive session is preferred to avoid quoting complexity with public key strings.

---

### Plan

**Step 1 — Verify prerequisites** — verification: confirms `sshusers` group exists, `sudo` group exists, root is currently in `sshusers`

```bash
getent group sshusers
getent group sudo
id root
```

Expected: `sshusers:x:1000:root` on the first line; `sudo:x:27:...` on the second; root's `groups=` output includes `sshusers`. If any of these fail, **stop and report BLOCKED** — do not proceed.

---

**Step 2 — Backup `/etc/sudoers.d` before modifications** — verification: timestamped backup dir exists

```bash
cp -a /etc/sudoers.d "/etc/sudoers.d.bak.$(date +%Y%m%dT%H%M%S)"
ls /etc/sudoers.d.bak.*
```

Record the exact backup directory name in the run notes — needed for rollback.

---

**Step 3 — Create user `tvolodi`**

```bash
# 3a. Create account (idempotent)
id tvolodi 2>/dev/null || useradd -m -s /bin/bash -G sudo,sshusers tvolodi

# 3b. Ensure group membership even if user pre-existed
usermod -aG sudo,sshusers tvolodi

# 3c. Lock password
passwd -l tvolodi

# 3d. Create .ssh directory
mkdir -p /home/tvolodi/.ssh

# 3e. Add public key (idempotent)
grep -qxF 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvwxjV8uSQtfSv95gTFc0CsMB9p+dhTxomw5ma/QHcR ai-dala-infra-mgmt@tvolodi-2026-05-12' /home/tvolodi/.ssh/authorized_keys 2>/dev/null \
  || echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvwxjV8uSQtfSv95gTFc0CsMB9p+dhTxomw5ma/QHcR ai-dala-infra-mgmt@tvolodi-2026-05-12' >> /home/tvolodi/.ssh/authorized_keys

# 3f. Fix permissions
chmod 700 /home/tvolodi/.ssh
chmod 600 /home/tvolodi/.ssh/authorized_keys
chown -R tvolodi:tvolodi /home/tvolodi/.ssh

# 3g. Write sudoers drop-in (overwrite = idempotent)
printf 'tvolodi ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/90-tvolodi
chmod 0440 /etc/sudoers.d/90-tvolodi

# 3h. Validate drop-in — MUST exit 0 before proceeding
visudo -c -f /etc/sudoers.d/90-tvolodi
```

Verification: exit code of `visudo -c -f` must be 0. If non-zero, **stop immediately** — restore the backup and report FAIL.

---

**Step 4 — Create user `viktor_d`**

```bash
# 4a. Create account (idempotent)
id viktor_d 2>/dev/null || useradd -m -s /bin/bash -G sudo,sshusers viktor_d

# 4b. Ensure group membership
usermod -aG sudo,sshusers viktor_d

# 4c. Lock password
passwd -l viktor_d

# 4d. Create .ssh directory
mkdir -p /home/viktor_d/.ssh

# 4e. Add public key (idempotent)
grep -qxF 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc2DSP1u7/HygLWJwqHdEAZqCLdGrYqloHxDNt+bkla viktor_d@ai-dala-infra-2026-06-27' /home/viktor_d/.ssh/authorized_keys 2>/dev/null \
  || echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc2DSP1u7/HygLWJwqHdEAZqCLdGrYqloHxDNt+bkla viktor_d@ai-dala-infra-2026-06-27' >> /home/viktor_d/.ssh/authorized_keys

# 4f. Fix permissions
chmod 700 /home/viktor_d/.ssh
chmod 600 /home/viktor_d/.ssh/authorized_keys
chown -R viktor_d:viktor_d /home/viktor_d/.ssh

# 4g. Write sudoers drop-in
printf 'viktor_d ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/90-viktor_d
chmod 0440 /etc/sudoers.d/90-viktor_d

# 4h. Validate drop-in — MUST exit 0 before proceeding
visudo -c -f /etc/sudoers.d/90-viktor_d
```

---

**Step 5 — Create user `binali_r`**

```bash
# 5a. Create account (idempotent)
id binali_r 2>/dev/null || useradd -m -s /bin/bash -G sudo,sshusers binali_r

# 5b. Ensure group membership
usermod -aG sudo,sshusers binali_r

# 5c. Lock password
passwd -l binali_r

# 5d. Create .ssh directory
mkdir -p /home/binali_r/.ssh

# 5e. Add public key (idempotent)
grep -qxF 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBC2MHyCVKbG3R22SkHxZh27wa5vlGmKE0LteeG4+ZHS binali_r@ai-dala-infra-2026-06-27' /home/binali_r/.ssh/authorized_keys 2>/dev/null \
  || echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBC2MHyCVKbG3R22SkHxZh27wa5vlGmKE0LteeG4+ZHS binali_r@ai-dala-infra-2026-06-27' >> /home/binali_r/.ssh/authorized_keys

# 5f. Fix permissions
chmod 700 /home/binali_r/.ssh
chmod 600 /home/binali_r/.ssh/authorized_keys
chown -R binali_r:binali_r /home/binali_r/.ssh

# 5g. Write sudoers drop-in
printf 'binali_r ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/90-binali_r
chmod 0440 /etc/sudoers.d/90-binali_r

# 5h. Validate drop-in — MUST exit 0 before proceeding
visudo -c -f /etc/sudoers.d/90-binali_r
```

---

**Step 6 — Confirm root remains in `sshusers`** — verification: root must still be a member; do NOT remove it

```bash
getent group sshusers | grep -w root
```

Expected: output contains `root`. If root is absent, run `usermod -aG sshusers root` to restore it.

---

**Step 7 — Final global verification** — verification: all 3 users present, all group memberships correct, full sudoers parse clean

```bash
# 7a. User existence
id tvolodi; id viktor_d; id binali_r

# 7b. Group membership
getent group sshusers
getent group sudo

# 7c. Full sudoers parse (includes all drop-ins)
visudo -c
```

Expected from 7a: each `id` shows `uid=<N>(<user>)`, `groups=` includes `sudo` and `sshusers`.
Expected from 7b: both group lines include `tvolodi,viktor_d,binali_r`; `sshusers` line also includes `root`.
Expected from 7c: exit code 0.

---

**Step 8 — SSH login verification as `tvolodi` (from management workstation — run locally, not via root SSH)**

```powershell
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o StrictHostKeyChecking=yes -o ConnectTimeout=10 tvolodi@95.46.211.224 "id; groups"
```

Expected: command exits 0; output includes `tvolodi`, `sudo`, `sshusers`. This confirms `AllowGroups sshusers` allows the new user and the public key is accepted.

---

### Rollback

Rollback applies if any step fails mid-execution. All commands run as root on the remote host.

```bash
# R1. Delete users created this run (userdel -r removes home dir and mail spool)
userdel -r tvolodi 2>/dev/null; true
userdel -r viktor_d 2>/dev/null; true
userdel -r binali_r 2>/dev/null; true

# R2. Remove sudoers drop-ins created this run
rm -f /etc/sudoers.d/90-tvolodi /etc/sudoers.d/90-viktor_d /etc/sudoers.d/90-binali_r

# R3. Restore sudoers.d from backup (replace <timestamp> with value noted in Step 2)
# Only needed if the backup exists and the current state is inconsistent
cp -a /etc/sudoers.d.bak.<timestamp>/* /etc/sudoers.d/
visudo -c

# R4. Confirm root is still in sshusers (must remain for break-glass access)
getent group sshusers | grep -w root
```

Rollback is **fully reversible** — `userdel -r` removes the home directory (no data was in it at time of creation) and sudo drop-ins were created fresh this run.

**Note:** do NOT remove `root` from `sshusers` as part of any rollback step. Root must remain in `sshusers` regardless of outcome.

---

### Verification (for step 07)

16 checks, mirroring T-0097:

**Per user (3 users × 5 checks = 15):**
1. `id tvolodi` exits 0 (user exists) — repeat for `viktor_d`, `binali_r`
2. `id tvolodi` output includes `sshusers` in groups — repeat for `viktor_d`, `binali_r`
3. `id tvolodi` output includes `sudo` in groups — repeat for `viktor_d`, `binali_r`
4. `grep -c 'ssh-ed25519' /home/tvolodi/.ssh/authorized_keys` returns 1 and key fingerprint matches — repeat for each user
5. `stat -c '%a %U %G' /etc/sudoers.d/90-tvolodi` returns `440 root root` — repeat for `viktor_d`, `binali_r`

**Global (1 check):**
16. `getent group sshusers` output contains `root` — break-glass preserved

**External behavior (recorded separately, not part of the 16-count):**
- On-host: `visudo -c` exits 0 (full sudoers parse)
- External: SSH login `tvolodi@95.46.211.224` with `C:\Users\tvolo\.ssh\ai-dala-infra` exits 0 and `id` output is correct

---

### Resources used

- Secrets (by name): none
- Files modified on host:
  - `/home/tvolodi/.ssh/authorized_keys` (created)
  - `/home/viktor_d/.ssh/authorized_keys` (created)
  - `/home/binali_r/.ssh/authorized_keys` (created)
  - `/etc/sudoers.d/90-tvolodi` (created)
  - `/etc/sudoers.d/90-viktor_d` (created)
  - `/etc/sudoers.d/90-binali_r` (created)
  - `/etc/passwd`, `/etc/shadow`, `/etc/group` (modified by `useradd` / `usermod`)
- Files modified in this repo (landscape/): `landscape/hosts/pro-data-tech-prod.md` — to be updated by step-08 landscape-updater (add operator accounts; correct erroneous "root will be removed from sshusers" note)
- External APIs called: none

---

### Estimated impact

- Downtime: **none** — no services running on this host; SSH daemon remains running throughout; no sshd reload required
- Affected services: SSH access (additive change only — new accounts gain access, no existing access removed)
- Reversibility: **fully reversible** — `userdel -r` removes home dir (empty at time of creation); sudoers drop-ins can be deleted; `/etc/group` changes can be undone with `gpasswd -d`

## Issues / risks

- **MUST NOT remove root from `sshusers`:** `landscape/hosts/pro-data-tech-prod.md` contains an erroneous note stating root "will be removed from `sshusers` once T-0105 provisions operator accounts." This note is **incorrect and dangerous** — removing root from `sshusers` with `AllowGroups sshusers` active would permanently block root break-glass SSH access. The executor must explicitly skip any root removal. The landscape-updater (step-08) must delete this note.
- **fail2ban is active:** a failed SSH login attempt from the management workstation IP could trigger the sshd jail. The executor must ensure each user is fully added to `sshusers` before the SSH login test in Step 8. If a ban is triggered: `fail2ban-client set sshd unbanip <mgmt-workstation-ip>` from the root session.
- **`visudo -c -f` failure is a hard stop:** a syntax error in a sudoers drop-in breaks `sudo` for all users on the host. After each `visudo -c -f` call, the executor must check the exit code before proceeding to the next user. If it returns non-zero, delete the offending drop-in, restore from backup, and emit FAIL.
- **`estimated_blast_radius: medium`:** this is a production host; approval is required per the approval protocol regardless of reversibility.

## Approval required

`NEEDS_APPROVAL` because `estimated_blast_radius` is `medium` (production host, first-time operator user provisioning). Per `shared/approval-protocol.md`: "Always requires NEEDS_APPROVAL: first-time deploys to prod … any operation the designer is uncertain about."
