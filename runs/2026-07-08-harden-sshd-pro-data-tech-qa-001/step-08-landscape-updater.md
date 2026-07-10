---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-03-task-validator.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-04-solution-designer.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-05-user-approval.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-executor-infra.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-execution-validator.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - tasks/_index.md
  - tasks/README.md
  - shared/handoff-format.md
  - shared/verdicts.md
files_updated:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - tasks/_index.md
next_step_hint: Run complete. T-0093 closed. Orchestrator may proceed to next pending task (T-0097: create non-root operator users).
---

## Summary

Landscape files updated to reflect the new hardened sshd end-state on `pro-data-tech-qa` (95.46.211.230): `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin prohibit-password`, `AllowGroups sshusers`, `sshusers` group exists with `root` as sole member, provider key preserved as break-glass, hardened KEX/Ciphers/MACs allow-lists in force, backup intact at `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/`. Task T-0093 transitioned from `in-progress` to `done` with outcome `succeeded` (21/21 verification checks PASSED).

## File diffs

| File | Change |
|---|---|
| `landscape/hosts/pro-data-tech-qa.md` | Rewrote the "SSH daemon config" and "sshd drop-in files" bullets in `## Access` to list the post-hardening values and the three drop-ins (`40-disable-password.conf`, `40-ai-dala-infra.conf`, `60-cloudimg-settings.conf` unchanged). Rewrote `## Security posture` to document sshd hardening, `sshusers` group membership, provider-key break-glass preservation, and backup location. Marked `T-0093` done in `## What needs to happen` and updated `## Open tasks affecting this host` to reflect the unblocking effect (T-0094, T-0095, T-0097 `blocked_by: T-0093` is now obsolete; T-0097 is next-up). Marked the root-login-policy open question as "applied via T-0093". Appended a Change log row for `2026-07-08-harden-sshd-pro-data-tech-qa-001`. `last_verified` remains `2026-07-08` (already current — no bump needed). |
| `landscape/services.md` | Added `**sshd hardening status:**` bullet under `## pro-data-tech-qa`. Updated the `ssh.service` row in the Native systemd services table (both the pro-data-tech-qa and the implicit-shape) with the hardened directive set. Appended a Change log row for `2026-07-08-harden-sshd-pro-data-tech-qa-001`. |
| `tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md` | Frontmatter: `status: in-progress` → `status: done`; `closed: 2026-07-08`; `outcome: Hardening applied successfully on 2026-07-08 via run 2026-07-08-harden-sshd-pro-data-tech-qa-001. 21/21 verification checks passed. Provider key preserved as break-glass.`; `updated: 2026-07-08`. Body: all 6 "What done looks like" criteria checked off; "Result" section populated with what happened, links to step-04 / step-06 / step-07, hash placeholder, deviation notes (extra `KexAlgorithms`+`Ciphers` hardening beyond the explicit acceptance criteria; `sshusers` group creation as load-bearing pre-work), V19 / V11 subtleties, sibling-host parity achieved, and unblocking effect on T-0094 / T-0095 / T-0097 / T-0090. History entry appended (most-recent-first): `2026-07-08: status -> done — run ... completed; 21/21 verification checks passed; ...`. |
| `tasks/_index.md` | Removed T-0093 from the in-progress block. Inserted T-0093 in the P1 `done` block, immediately after T-0092 (sorted by priority then ID, per the index contract). Updated the `affects` column to include `landscape/services.md` (was just `landscape/hosts/pro-data-tech-qa.md`). |

## Task closure

T-0093 transitioned: `in-progress` → `done` (outcome `succeeded`). All acceptance criteria met: 6/6 checkboxes ticked, 21/21 verification checks PASSED per step-07. No FAIL, no partial rollback, no open issues. Closed at `2026-07-08`. The commit hash is a `<pending>` placeholder; the orchestrator (or user) will fill it in at run-finalization / commit time.

## Next

The next-up pending task per the unblocking analysis is **T-0097** (create non-root operator users `tvolodi`, `viktor_d`, `binali_r` on `pro-data-tech-qa`, with NOPASSWD sudo and `sshusers` group membership). It is the gating task for the user's **multi-PC SSH acceptance criterion**. After T-0097 lands, T-0090 (full ai-qadam QA prep) becomes truly unblocked. Parallel paths: T-0094 (UFW) and T-0095 (fail2ban) are also unblocked and may run concurrently with T-0097.

## Issues / risks

none
