---
run_id: 2026-07-11-harden-sshd-pro-data-tech-prod-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0102-harden-sshd-on-pro-data-tech-prod
inputs_read:
  - tasks/T-0102-harden-sshd-on-pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader (step 02) — read landscape/hosts/pro-data-tech-prod.md to confirm host details and current sshd state
---

## Summary

Task T-0102 is well-formed, status `in-progress`, and maps cleanly to the `infrastructure` workflow. It instructs the executor to apply the same sshd hardening profile used on the QA sister host (T-0093) to the new production host at 95.46.211.224. The task is parseable; all acceptance criteria are explicit and machine-verifiable. Verdict: PASS.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - landscape/hosts/pro-data-tech-prod.md
- **Host:** pro-data-tech-prod — 95.46.211.224 (pro-data.tech prod instance); root access via `pro-data.tech-prod-instance_rsa.ppk`
- **Hardening directives (from task "What done looks like"):**
  - `PermitRootLogin prohibit-password` — key-only root; password login blocked
  - `PasswordAuthentication no` and `KbdInteractiveAuthentication no`
  - `PubkeyAuthentication yes`
  - `AllowGroups sshusers` — operator users and root must be members before this directive is active
  - `MaxAuthTries 3`
  - `LoginGraceTime 30`
  - `X11Forwarding no`
  - `UseDNS no`
  - Weak KEX algorithms, ciphers, and MACs removed
  - Config validated with `sshd -t` before reload
  - sshd reloaded while preserving the active session
  - 20+ post-execution verification checks must pass
- **Implementation pattern:** drop-in file under `/etc/ssh/sshd_config.d/` — do NOT overwrite the main config
- **Critical ordering constraint:** `sshusers` group must be created and root added to it BEFORE `AllowGroups sshusers` is applied, or root will be locked out
- **Reference run:** `2026-07-08-harden-sshd-pro-data-tech-qa-001` (T-0093; 21/21 checks passed) — the executor must model this run exactly
- **Blast radius:** medium — misconfiguration or wrong group membership before `AllowGroups` could permanently lock out SSH access to the host
- **Reversibility:** full — original sshd_config backed up before any changes; `sshd -t` validation gate prevents reload of invalid config; drop-in file can be deleted and sshd reloaded to restore defaults
- **Constraints stated by user:** none beyond "apply the same profile as T-0093"
- **Information gaps for downstream steps:**
  - Confirm that non-root operator users (e.g. `tvolodi`) already exist on this host and will be added to `sshusers` (landscape-reader / executor must verify)
  - Confirm the exact private key name/path used for the executor's SSH session so the active-session-preservation check can be validated

## Issues / risks

- If no non-root operator user exists yet on pro-data-tech-prod, `AllowGroups sshusers` with only `root` in the group is safe for now but should be noted in the landscape update
- Task status is already `in-progress` (set when this run started) — status check passes; execution is not blocked
