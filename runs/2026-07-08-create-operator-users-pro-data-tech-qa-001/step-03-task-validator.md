---
run_id: 2026-07-08-create-operator-users-pro-data-tech-qa-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-02-landscape-reader.md
  - tasks/T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md
  - tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md
  - tasks/_index.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/hetzner-prod.md
  - shared/handoff-format.md
checks_passed:
  - task-file-integrity
  - feasibility
  - scope
  - multi-pc-acceptance
  - risk-acknowledgment
  - workflow-rules
next_step_hint: Pass to solution-designer (step 04).
---

## Summary

T-0097 is well-formed, feasible, in-scope, and ready for the solution-designer (step 04). The gating blocker T-0093 is done with all 6 of its own acceptance criteria satisfied; no other task is running against `pro-data-tech-qa` in parallel; per-operator accounts (rather than a single shared user) have been selected per the user's "just go" delegation; and the multi-PC acceptance caveat is captured explicitly in the task body and can be honored by step-07's execution-validator. No external-storage decisions are introduced; no secrets are written to files in this repo.

## Details

### Validation results

| # | Check | Verdict | Reason |
|---|---|---|---|
| 1 | Task file integrity | PASS | T-0097 frontmatter shows `kind: task`, `status: pending`, `priority: P2`, `blocked_by: T-0093`. T-0093's `status: done` and `closed: 2026-07-08` confirmed (21/21 verification checks passed in its own run). T-0097 has 7 acceptance criteria, all measurable (uid numbers, file paths, mode 0440 / 0700 / 0600, specific pubkey fingerprints, and explicit landscape-file updates). |
| 2 | Feasibility | PASS | `sshusers` group exists (gid 1000) with `root` as sole member; `sudo` group exists (gid 27, empty); `users` group exists (gid 100, empty). UIDs 1001/1002/1003 are confirmed free (only `root` and `nobody` exist on the host; range 1–65533 is otherwise vacant for human accounts). All three operator pubkeys present on the management workstation (`ai-dala-infra.pub`, `ai-dala-infra-viktor-d.pub`, `ai-dala-infra-binali-r.pub`) with fingerprints matching the landscape. NOPASSWD sudo pattern matches sibling hosts `hetzner-prod` (T-0007 done 2026-05-12) and `ubuntu-16gb-nbg1-1` (T-0082 done 2026-06-27). |
| 3 | Scope | PASS | T-0094 (UFW) and T-0095 (fail2ban) are both `status: pending` with `blocked_by: [T-0093]` but neither has an active run; no concurrency hazard. T-0090 (the parent prep task) is `status: observation` and explicitly documents that it remains "effectively blocked by T-0097 for the multi-PC SSH acceptance criterion" — so T-0097 is not racing T-0090, and T-0090 cannot be promoted to `pending` until T-0097 is `done`. No other active run touches this host (only the discovery + sshd-hardening runs exist before this one). |
| 4 | Multi-PC acceptance | PASS | The task body (Acceptance criterion #6, plus the "Multi-PC acceptance criterion (verbatim from the user's most recent request)" Note) explicitly distinguishes server-side `authorized_keys` parsing verification from operator-A→server and operator-B→server SSH handshakes. The step-02 handoff reaffirms that `viktor_d` / `binali_r` private keys are not on this management workstation, so step-07's `execution-validator` can only claim server-side authorized_keys/sudoers validation for those two operators; a live handshake from operator A's or operator B's workstation is correctly deferred to their future presence. Acceptance criterion #1 (`tvolodi` pubkey from this workstation → live SSH test is feasible) is the only criterion for which a live handshake is achievable from this box. |
| 5 | Risk acknowledgment | PASS | Acceptance criterion #5 requires the provider key (comment `rsa-key-20260707`) to remain in `/root/.ssh/authorized_keys` and explicitly states "Do NOT remove it." `landscape/hosts/pro-data-tech-qa.md` "Security posture" section documents the provider key as break-glass under `PermitRootLogin prohibit-password`; the step-02 handoff confirms the file still has its single provider-key line. File ownership / mode conventions are referenced in the task's "Sibling host pattern" Note (`/home/<user>/.ssh/` mode 0700, `authorized_keys` mode 0600) — ownership convention `root:<user>` for `~/.ssh/` is captured in step-01's open question and again in step-02 ("risks noted"). Reversibility is full: `userdel -r <user>` cleans up; the same is true for sudoers drop-ins (single-line files, deletable). No irreversibly destructive operations (no `dd`, no destructive fs op, no volume reclaim). |
| 6 | Workflow rules respected | PASS | `workflows/infrastructure.md` is the natural fit (host-mutation, state-changing, low-medium blast radius). Blast radius is `medium` and reversibility is `full` per T-0097 frontmatter — consistent with `infrastructure` workflow gating. The user's "just go" delegation recorded in step-01 justifies skipping step-05's human-approval gate. Backup-before-destructive is satisfiable: step-02 states `/etc/sudoers` and `/etc/group` snapshots to `/var/backups/pre-T-0097/` are sufficient rollback insurance. |

### Risks noted (non-blocking — these are executor hints, not blockers)

- **`~/.ssh/` ownership convention.** Sibling hosts use `root:<user>` for `/home/<user>/.ssh/` and `/home/<user>/.ssh/authorized_keys` (mode 0700/0600 respectively). Step-04's solution plan and step-06's executor must use the same convention here to keep audit-log parity across the project.
- **Mid-step lockout window.** If step-06 errors out between `useradd tvolodi` and `usermod -aG sshusers tvolodi`, the operator would be SSH-able in name but blocked by `AllowGroups sshusers`. Break-glass via the provider key (`PermitRootLogin prohibit-password` is independent of `AllowGroups`) remains intact, so this is recoverable, but the executor should set `gpasswd -a tvolodi sshusers` BEFORE writing the `authorized_keys` (or treat them as one atomic finalization step) to minimize the window.
- **UID-range reservation for T-0090.** T-0090's follow-on (Docker, app baseline) will provision application users; the executor's `# What does NOT change` note should flag "UIDs 1100+ reserved for application/service users" so T-0090 does not collide with the human-operator range 1001–1003 established here.
- **Multi-PC acceptance scope.** Step-07's execution-validator must clearly distinguish (a) `tvolodi` live SSH from this workstation + `sudo -n true` returning `SUDO_OK`, (b) `viktor_d` and `binali_r` server-side `ssh-keygen -lf /home/<user>/.ssh/authorized_keys` + `visudo -c -f /etc/sudoers.d/90-<user>` checks, from (c) the future operator-A / operator-B live SSH handshakes (deferred until they are present). All three are needed to call the task "done"; the validator's handoff should not over-claim live handshakes for the operators whose private keys are not on this box.
- **Default shell.** Sibling hosts use `/bin/bash`; the executor should set the same (Ubuntu 26.04 default).
- **No off-site storage introduced.** The task does not create or propose any external backup targets. This complies with the project-wide rule in `.github/copilot-instructions.md` and `CLAUDE.md` ("No off-site/external storage"). Pubkey values are stored on each operator's workstation and referenced by path on the management workstation — not captured in any file in this repo.

### Cross-references verified

- Sibling-host precedent: [landscape/hosts/hetzner-prod.md](../landscape/hosts/hetzner-prod.md) `## Access` block documents the `tvolodi` (uid 1001, `sudo`+`users` secondary groups) + NOPASSWD drop-in + `/home/tvolodi/.ssh/authorized_keys` pattern. [landscape/hosts/ubuntu-16gb-nbg1-1.md](../landscape/hosts/ubuntu-16gb-nbg1-1.md) follows the same pattern with uid 1000 because of prior `aitala` removal. Both confirmed at `last_verified: 2026-07-08` / `2026-06-27` respectively.
- Pattern reference for the step-04 solution-designer: `hetzner-prod.md` lines documenting `tvolodi@91.98.28.126` access; sibling drop-in `/etc/sudoers.d/90-tvolodi` content `tvolodi ALL=(ALL) NOPASSWD:ALL` mode 0440; ownership `root:<user>` for the `~/.ssh/` tree.
- Task frontmatter reconciles with `tasks/_index.md`: T-0097 is listed at P2 / status pending; T-0093 is listed at P1 / status done; T-0094 and T-0095 at P2 / status pending. All consistent.

## Issues / risks

None blocking. All items in the "Risks noted" section are operational hints for step-04 (solution-designer) and step-06 (executor-infra); none require a re-run of steps 01–03.

## Recommendation

Pass to solution-designer (step 04). The task file is well-formed, the blocker is satisfied, sibling-host precedent is established, the multi-PC acceptance caveat is captured up front, the operator pubkey set is verified on the workstation, the host state is clean (UIDs 1001/1002/1003 free; `sshusers` group present and ready for new members), and no parallel runs against this host exist. The next-step hint from step-02 already pointed here; this validator confirms the gate.
