---
run_id: 2026-07-11-create-operator-users-pro-data-tech-prod-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-11T12:00:00Z
task_id: T-0105-create-operator-users-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - /home/tvolodi/.ssh/authorized_keys (created on host)
  - /home/viktor_d/.ssh/authorized_keys (created on host)
  - /home/binali_r/.ssh/authorized_keys (created on host)
  - /etc/sudoers.d/90-tvolodi (created on host)
  - /etc/sudoers.d/90-viktor_d (created on host)
  - /etc/sudoers.d/90-binali_r (created on host)
  - /etc/passwd, /etc/shadow, /etc/group (modified by useradd/usermod on host)
next_step_hint: advance to execution-validator (step 07)
---

## Summary

Executed all 8 plan steps on `pro-data-tech-prod` (95.46.211.224) successfully: created operator accounts `tvolodi`, `viktor_d`, and `binali_r` with ed25519 SSH keys, `sshusers`+`sudo` group membership, locked passwords, and validated NOPASSWD sudoers drop-ins; root remains in `sshusers`; live SSH test as `tvolodi` (login + `sudo true`) passed.

## Details

### Pre-execution checks
- Approval handoff verified: yes (`runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-05-user-approval.md`)
- Approval verdict: APPROVED
- step-04 verdict: NEEDS_APPROVAL — confirmed approval file present and matches
- Design references match: yes

### Execution log

#### Step 1: Verify prerequisites
- Command: `ssh ... 'getent group sshusers; echo ---; getent group sudo; echo ---; id root'`
- Exit code: 0
- Output:
  ```
  sshusers:x:1000:root
  ---
  sudo:x:27:
  ---
  uid=0(root) gid=0(root) groups=0(root),1000(sshusers)
  ```
- Result: success — sshusers exists with root, sudo group exists, root in sshusers

#### Step 2: Backup /etc/sudoers.d
- Command: `ssh ... 'cp -a /etc/sudoers.d /etc/sudoers.d.bak.pre-T0105 && ls -la /etc/sudoers.d.bak.pre-T0105/'`
- Exit code: 0
- Output:
  ```
  total 16
  drwxr-x---   2 root root 4096 May  5 05:20 .
  drwxr-xr-x 112 root root 4096 Jul 11 06:16 ..
  -r--r-----   1 root root  127 May  5 05:20 90-cloud-init-users
  -r--r-----   1 root root  863 Jan 14 18:11 README
  ```
- Result: success
- Backup taken: `/etc/sudoers.d.bak.pre-T0105/`

#### Step 3: Create user tvolodi

- **3a. Idempotency check**
  - Command: `ssh ... 'id tvolodi 2>/dev/null && echo EXISTS || echo NEW'`
  - Exit code: 0
  - Output: `NEW`

- **3b. Create account**
  - Command: `ssh ... 'useradd -m -s /bin/bash -G sudo,sshusers tvolodi && echo "useradd OK"'`
  - Exit code: 0
  - Output: `useradd OK`

- **3b-c. Ensure groups + lock password**
  - Command: `ssh ... 'usermod -aG sudo,sshusers tvolodi && passwd -l tvolodi && echo "groups+lock OK"'`
  - Exit code: 0
  - Output: `passwd: password changed.\ngroups+lock OK`

- **3d-e. .ssh dir + authorized_keys**
  - Command: `ssh ... 'mkdir -p /home/tvolodi/.ssh && grep -qxF "<key>" ... || echo "<key>" >> ...'`
  - Exit code: 0
  - Output: `key installed`

- **3f. Permissions**
  - Command: `ssh ... 'chmod 700 /home/tvolodi/.ssh && chmod 600 .../authorized_keys && chown -R tvolodi:tvolodi ...'`
  - Exit code: 0
  - Output: `perms OK`

- **3g-h. Sudoers drop-in + validate** (all three users done via SCP'd script)
  - Command: script `/tmp/sudoers-setup.sh` executed via `bash /tmp/sudoers-setup.sh`
  - Exit code: 0
  - Output:
    ```
    /etc/sudoers.d/90-tvolodi: parsed OK
    tvolodi sudoers OK
    /etc/sudoers.d/90-viktor_d: parsed OK
    viktor_d sudoers OK
    /etc/sudoers.d/90-binali_r: parsed OK
    binali_r sudoers OK
    ALL SUDOERS DONE
    ```
  - Result: success — all three drop-ins written and validated by visudo before proceeding

#### Step 4: Create user viktor_d

- **4a. Idempotency check** — Output: `NEW`
- **4b. Create account** — `useradd OK`
- **4b-c. Groups + lock** — `passwd: password changed. / groups+lock OK`
- **4d-e. .ssh + key** — `key installed`
- **4f. Permissions** — `perms OK`
- Sudoers: validated in combined script above

#### Step 5: Create user binali_r

- **5a. Idempotency check** — Output: `NEW`
- **5b. Create account** — `useradd OK`
- **5b-c. Groups + lock** — `passwd: password changed. / groups+lock OK`
- **5d-e. .ssh + key** — `key installed`
- **5f. Permissions** — `perms OK`
- Sudoers: validated in combined script above

#### Step 6+7: Final global verification
- Command: `ssh ... 'id tvolodi; id viktor_d; id binali_r; getent group sshusers; getent group sudo; ... visudo -c'`
- Exit code: 0
- Output:
  ```
  === id checks ===
  uid=1000(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),1000(sshusers)
  uid=1001(viktor_d) gid=1002(viktor_d) groups=1002(viktor_d),27(sudo),1000(sshusers)
  uid=1002(binali_r) gid=1003(binali_r) groups=1003(binali_r),27(sudo),1000(sshusers)
  === sshusers group ===
  sshusers:x:1000:root,tvolodi,viktor_d,binali_r
  === sudo group ===
  sudo:x:27:tvolodi,viktor_d,binali_r
  === root in sshusers ===
  sshusers:x:1000:root,tvolodi,viktor_d,binali_r
  root present
  === visudo full parse ===
  /etc/sudoers: parsed OK
  visudo PASS
  ```
- Result: success — all 16 verification checks pass; root is preserved in sshusers

#### Step 8: SSH login test as tvolodi
- Command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 tvolodi@95.46.211.224 "whoami && id && sudo true && echo SUDO_OK"`
- Exit code: 0
- Output:
  ```
  tvolodi
  uid=1000(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),1000(sshusers)
  SUDO_OK
  ```
- Result: success — SSH key authentication accepted, AllowGroups sshusers allows tvolodi, passwordless sudo works

### Rollback executed
Not needed — all steps succeeded.

### Resources changed
- Files on host:
  - `/etc/sudoers.d.bak.pre-T0105/` (backup directory — not a change, safety artifact)
  - `/home/tvolodi/.ssh/authorized_keys` (created)
  - `/home/viktor_d/.ssh/authorized_keys` (created)
  - `/home/binali_r/.ssh/authorized_keys` (created)
  - `/etc/sudoers.d/90-tvolodi` (created, 0440)
  - `/etc/sudoers.d/90-viktor_d` (created, 0440)
  - `/etc/sudoers.d/90-binali_r` (created, 0440)
  - `/etc/passwd`, `/etc/shadow`, `/etc/group` (modified by useradd/usermod)
- Services restarted: none
- External resources changed: none

## Issues / risks

- **Note for step-08 landscape-updater:** `landscape/hosts/pro-data-tech-prod.md` contains an erroneous note that root "will be removed from sshusers once T-0105 provisions operator accounts." Root was NOT removed and must NOT be removed — root must remain in sshusers for break-glass SSH access. The landscape-updater must delete this note and update the operator users section to reflect tvolodi (uid 1000), viktor_d (uid 1001), binali_r (uid 1002).

## Open questions

none
