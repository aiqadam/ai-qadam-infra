---
run_id: 2026-07-11-create-operator-users-pro-data-tech-prod-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0105-create-operator-users-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: advance to landscape-updater (step 08)
---

## Summary

All 16 designer verification checks independently confirmed on `pro-data-tech-prod` (95.46.211.224): operator accounts `tvolodi` (uid=1000), `viktor_d` (uid=1001), and `binali_r` (uid=1002) exist with correct group memberships, ed25519 keys installed at 0600, sudoers drop-ins at 0440 with a clean full parse, root remains in `sshusers`, and an external SSH login as `tvolodi` with passwordless sudo succeeded.

## Details

### On-host checks

| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| `id tvolodi` exits 0; uid=1000; groups include `sudo` and `sshusers` | `id tvolodi` | `uid=1000(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),1000(sshusers)` | yes |
| `id viktor_d` exits 0; uid=1001; groups include `sudo` and `sshusers` | `id viktor_d` | `uid=1001(viktor_d) gid=1002(viktor_d) groups=1002(viktor_d),27(sudo),1000(sshusers)` | yes |
| `id binali_r` exits 0; uid=1002; groups include `sudo` and `sshusers` | `id binali_r` | `uid=1002(binali_r) gid=1003(binali_r) groups=1003(binali_r),27(sudo),1000(sshusers)` | yes |
| `getent group sshusers` includes root + all three operators | `getent group sshusers` | `sshusers:x:1000:root,tvolodi,viktor_d,binali_r` | yes |
| `getent group sudo` includes all three operators | `getent group sudo` | `sudo:x:27:tvolodi,viktor_d,binali_r` | yes |
| `.ssh` dirs are mode 700, owned by respective user | `ls -la /home/tvolodi/.ssh/ /home/viktor_d/.ssh/ /home/binali_r/.ssh/` | All dirs `drwx------ … <user> <user>` | yes |
| `authorized_keys` files are mode 600, owned by respective user | (same `ls -la` output) | All files `-rw------- … <user> <user>` | yes |
| `wc -l authorized_keys` returns 1 for each user | `wc -l /home/tvolodi/.ssh/authorized_keys /home/viktor_d/.ssh/authorized_keys /home/binali_r/.ssh/authorized_keys` | `1 … 1 … 1 … 3 total` | yes |
| Key type is ED25519 with correct comment per user | `ssh-keygen -l -f /home/<user>/.ssh/authorized_keys` | `ai-dala-infra-mgmt@tvolodi-2026-05-12 (ED25519)` / `viktor_d@ai-dala-infra-2026-06-27 (ED25519)` / `binali_r@ai-dala-infra-2026-06-27 (ED25519)` | yes |
| `visudo -c` exits 0 (full sudoers parse clean) | `visudo -c` | `/etc/sudoers: parsed OK` | yes |
| `/etc/sudoers.d/` contains exactly 3 project drop-ins | `ls -la /etc/sudoers.d/` | `90-tvolodi`, `90-viktor_d`, `90-binali_r` present (plus pre-existing `90-cloud-init-users` and `README`) | yes |
| `stat` on each drop-in returns `440 root root` | `stat -c '%a %U %G %n' /etc/sudoers.d/90-tvolodi /etc/sudoers.d/90-viktor_d /etc/sudoers.d/90-binali_r` | `440 root root` for all three | yes |
| root remains in `sshusers` (break-glass preserved) | `getent group sshusers \| grep -w root` | `sshusers:x:1000:root,tvolodi,viktor_d,binali_r` — `ROOT_PRESENT` | yes |

### External checks

| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| SSH login as `tvolodi` using `ai-dala-infra` key exits 0 | `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "whoami && id && sudo true && echo SUDO_OK"` | exit 0; `whoami=tvolodi`; id shows `sudo` and `sshusers`; `SUDO_OK` | `tvolodi` / `uid=1000(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),1000(sshusers)` / `SUDO_OK` — exit 0 | yes |

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| `/home/tvolodi/.ssh/authorized_keys` (created) | Present, 1 ed25519 key, mode 0600, owned tvolodi | yes |
| `/home/viktor_d/.ssh/authorized_keys` (created) | Present, 1 ed25519 key, mode 0600, owned viktor_d | yes |
| `/home/binali_r/.ssh/authorized_keys` (created) | Present, 1 ed25519 key, mode 0600, owned binali_r | yes |
| `/etc/sudoers.d/90-tvolodi` (created, 0440) | Present, mode 0440, owned root root | yes |
| `/etc/sudoers.d/90-viktor_d` (created, 0440) | Present, mode 0440, owned root root | yes |
| `/etc/sudoers.d/90-binali_r` (created, 0440) | Present, mode 0440, owned root root | yes |
| `/etc/passwd`, `/etc/shadow`, `/etc/group` (modified by useradd/usermod) | All three users exist in `/etc/group` via `getent group` and `id`; consistent with useradd/usermod writes | yes |
| `/etc/sudoers.d.bak.pre-T0105/` (safety backup, not a change) | Not checked (backup directory — not part of artifacts_changed list; presence is benign) | n/a |

## Issues / risks

- **Erroneous landscape note not yet corrected:** `landscape/hosts/pro-data-tech-prod.md` still contains the note "root will be removed from `sshusers` once T-0105 provisions operator accounts." Root was NOT removed and must NOT be removed. Step-08 landscape-updater must delete this note and update the operator users section with confirmed UIDs.

## Open questions

none
