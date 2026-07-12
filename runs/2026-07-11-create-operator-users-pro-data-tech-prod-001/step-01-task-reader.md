---
run_id: 2026-07-11-create-operator-users-pro-data-tech-prod-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0105-create-operator-users-on-pro-data-tech-prod
inputs_read:
  - tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader (step 02) — read pro-data-tech-prod host landscape and confirm sshusers group presence from T-0102 run
---

## Summary

Task T-0105 requests creation of non-root operator users (`tvolodi`, `viktor_d`, `binali_r`) on the production host `pro-data-tech-prod` (95.46.211.224), mirroring the pattern proven on QA via T-0097 (16/16 checks passed). All security prerequisites are complete (T-0102 sshd hardened with `AllowGroups sshusers`, T-0103 UFW, T-0104 fail2ban). The workflow selected is `infrastructure`.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md`
- **Operator public keys (confirmed by orchestrator):**
  - `tvolodi`: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvwxjV8uSQtfSv95gTFc0CsMB9p+dhTxomw5ma/QHcR ai-dala-infra-mgmt@tvolodi-2026-05-12`
  - `viktor_d`: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc2DSP1u7/HygLWJwqHdEAZqCLdGrYqloHxDNt+bkla viktor_d@ai-dala-infra-2026-06-27`
  - `binali_r`: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBC2MHyCVKbG3R22SkHxZh27wa5vlGmKE0LteeG4+ZHS binali_r@ai-dala-infra-2026-06-27`
- **Constraints stated by user:**
  - Must add every new user to the `sshusers` group before testing key auth — `AllowGroups sshusers` is active from T-0102; users not in this group cannot log in via SSH.
  - `root` must also be in `sshusers` to preserve break-glass access.
  - Model identically after T-0097 / run `2026-07-08-create-operator-users-pro-data-tech-qa-001`.
  - All three users must receive their confirmed ed25519 public keys; no placeholder keys.
- **Acceptance criteria (from "What done looks like"):**
  1. `sshusers` group exists (was created in T-0102; verify it is present).
  2. User `tvolodi` created with home dir, added to `sshusers` and `sudo` groups.
  3. `/etc/sudoers.d/90-tvolodi` with `tvolodi ALL=(ALL) NOPASSWD: ALL`, mode 0440; `visudo -c` passes.
  4. `tvolodi` `authorized_keys` populated with the confirmed ed25519 key above.
  5. Users `viktor_d` and `binali_r` created with the same pattern, keys populated.
  6. `root` added to `sshusers` group.
  7. SSH login verified as `tvolodi@95.46.211.224` from management workstation.
  8. All `visudo -c` checks pass for all drop-in files.
  9. 16/16 verification checks passed (matching T-0097 acceptance criteria).
- **Information gaps for downstream steps:**
  - Landscape-reader (step 02) must confirm whether `sshusers` group was recorded as created in the T-0102 run landscape update, or whether the executor needs to create it.
  - Landscape-reader should also confirm the current `root` SSH break-glass configuration and whether `root` was already added to `sshusers` in T-0102.

## Issues / risks

- **Critical:** `AllowGroups sshusers` is already active. If a new user is created but not added to `sshusers` before an SSH login attempt is made, the login will be denied. The executor must add each user to `sshusers` atomically with user creation (i.e., in the same `useradd` command or immediately after, before any SSH test).
- **Medium:** `sudoers.d` drop-in files must be mode 0440 and syntax-valid; a bad drop-in will break `sudo` for all users on the host.

## Open questions

none
