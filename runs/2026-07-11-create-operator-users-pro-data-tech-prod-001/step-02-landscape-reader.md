---
run_id: 2026-07-11-create-operator-users-pro-data-tech-prod-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0105-create-operator-users-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — verify task completeness and confirm executor has all inputs needed
---

## Summary

`pro-data-tech-prod` (`95.46.211.224`) is fully hardened at the network/sshd/firewall layer (T-0102 sshd, T-0103 UFW, T-0104 fail2ban — all `done` as of 2026-07-11) but has **no operator accounts**: `root` (uid 0) is the sole login-capable user, `nobody` (uid 65534, nologin) is the only other passwd entry. The `sshusers` group (gid 1000) was created by T-0102 and currently has `root` as its sole member; `AllowGroups sshusers` is active in the effective sshd config, meaning any new user must be added to `sshusers` before SSH login is possible. All three operator ed25519 public keys are confirmed available in the step-01 handoff. The QA reference run (T-0097, `2026-07-08-create-operator-users-pro-data-tech-qa-001`, 16/16 checks PASSED) is the proven pattern to replicate identically.

## Details

### Relevant facts (sourced from landscape)

- **Host identity:** `pro-data-tech-prod`, IPv4 `95.46.211.224`, hostname `drkkrgm-prod-instance`, Ubuntu 26.04, kernel `7.0.0-14-generic` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Current local users:** `root` (uid 0, login-capable via key) and `nobody` (uid 65534, nologin) only; **no uid≥1000 accounts exist** — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **`sshusers` group:** gid 1000, created by T-0102; current sole member is `root` (uid 0); transitional state pending T-0105 — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **`AllowGroups sshusers` in effect:** set in `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (project-managed, T-0102); any new user not in this group cannot log in via SSH — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **`PermitRootLogin prohibit-password`:** key-only root access; provider RSA key (`rsa-key-20260707`) in `/root/.ssh/authorized_keys` is the break-glass anchor — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **`PasswordAuthentication no`, `PubkeyAuthentication yes`:** confirmed in effective sshd config (T-0102) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **UFW active (T-0103):** deny-incoming default; 22/tcp, 80/tcp, 443/tcp allowed in; no other ports open — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **fail2ban active (T-0104):** sshd jail running — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Management SSH key:** `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (OpenSSH RSA, not PuTTY format) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Operator public keys (confirmed by orchestrator in step-01):**
  - `tvolodi`: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvwxjV8uSQtfSv95gTFc0CsMB9p+dhTxomw5ma/QHcR ai-dala-infra-mgmt@tvolodi-2026-05-12`
  - `viktor_d`: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc2DSP1u7/HygLWJwqHdEAZqCLdGrYqloHxDNt+bkla viktor_d@ai-dala-infra-2026-06-27`
  - `binali_r`: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBC2MHyCVKbG3R22SkHxZh27wa5vlGmKE0LteeG4+ZHS binali_r@ai-dala-infra-2026-06-27`
  - _source: `runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-01-task-reader.md`_
- **QA reference pattern (T-0097, 16/16 checks PASSED):** `tvolodi` uid 1001, `viktor_d` uid 1002, `binali_r` uid 1003; each in groups `<user>, sudo, users, sshusers`; password locked; `/etc/sudoers.d/90-<user>` with `<user> ALL=(ALL) NOPASSWD: ALL`, mode 0440, root:root, `visudo -c` validated; operator `.ssh/` directories owned `<user>:<user>`; `authorized_keys` mode 0600 — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **Landscape `last_verified`:** 2026-07-11 — current; not stale — _source: `landscape/hosts/pro-data-tech-prod.md`_

### Stale or stub files encountered

None. `landscape/hosts/pro-data-tech-prod.md` — `last_verified: 2026-07-11`, `status: populated`. Within 30-day threshold.

### Gaps requiring live discovery

- **Actual UID assignments on prod after account creation:** landscape records no uid≥1000 accounts; executor must confirm starting UID (`useradd` defaults on a fresh Ubuntu 26.04 system with no prior uid≥1000 accounts should assign 1000, 1001, 1002 — but prod may differ from QA if any system accounts are in the 1000 range). Executor should verify with `id <user>` post-creation.
- **`sudo` and `adduser` package presence:** likely installed as Ubuntu 26.04 defaults, but not explicitly enumerated in the discovery run. Executor should confirm before issuing `usermod -aG sudo`.
- **Current membership of `sudo` group:** not enumerated in the landscape; executor should confirm group exists (`getent group sudo`) before adding users to it.

## Issues / risks

- **Landscape note conflicts with task requirement on root group membership:** `landscape/hosts/pro-data-tech-prod.md` states root "will be removed from `sshusers` once T-0105 provisions operator accounts." However, step-01 explicitly requires root to remain in `sshusers` for break-glass access. Given that `AllowGroups sshusers` gates ALL users including root (removing root from `sshusers` would block root SSH access entirely), the step-01 requirement must take precedence. The solution designer and executor must **not** remove root from `sshusers`; the landscape note is erroneous and should be corrected by step-08 landscape-updater.
- **`AllowGroups` timing risk:** if executor creates a user and tests SSH before adding that user to `sshusers`, the login will be denied and may trigger fail2ban. Each user must be added to `sshusers` in the same operation as account creation (i.e., via `usermod -aG sshusers <user>` immediately after `useradd`, before any SSH test).
- **sudoers.d mode:** drop-in files must be mode 0440 exactly; a bad mode or syntax error breaks `sudo` for all users on the host. `visudo -c` must be run after each drop-in creation.
