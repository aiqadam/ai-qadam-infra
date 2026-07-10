---
run_id: 2026-07-08-create-operator-users-pro-data-tech-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
inputs_read:
  - tasks/T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md
  - tasks/_index.md
  - tasks/README.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - workflows/infrastructure.md
  - landscape/README.md
next_step_hint: Pass to landscape-reader (step 02) — target scope is landscape/hosts/pro-data-tech-qa.md, landscape/secrets-inventory.md, and the existing-pattern reference (hosts/hetzner-prod.md and hosts/ubuntu-16gb-nbg1-1.md).
---

## Summary

T-0097 is well-formed, status `pending` (eligible), and ready for execution as an `infrastructure` workflow run. It directs the creation of a `tvolodi` non-root user on `pro-data-tech-qa` with NOPASSWD sudo, the project's `ai-dala-infra` pubkey installed in its `authorized_keys`, and — by user delegation — the per-operator variant (separate `viktor_d`, `binali_r` users with their own pubkeys) rather than a single shared user. The provider key in `/root/.ssh/authorized_keys` remains as break-glass. Multi-PC SSH acceptance for `viktor_d`/`binali_r` will rely on server-side authorized_keys parsing verification, since operators A and B are not physically at this workstation.

## Task summary

T-0097 was promoted from observation to `kind: task` on 2026-07-08 after T-0093 (sshd hardening) closed successfully. Per its frontmatter:

- `id: T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa`
- `status: pending`, `priority: P2`
- `workflow: infrastructure`
- `affects: landscape/hosts/pro-data-tech-qa.md`
- `blocks: [T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance]`
- `blocked_by: [T-0093-harden-sshd-on-pro-data-tech-qa]` — T-0093 closed 2026-07-08, so the blocker is satisfied.
- `executed_by_runs: []` — this run will fill it.
- `estimated_blast_radius: medium`, `estimated_reversibility: full`.

## Acceptance criteria (from "What done looks like")

These map directly to the validator's checks at step 07:

1. `tvolodi` user created (uid 1001 if available; primary group `tvolodi`; secondary groups `sudo`, `users`, `sshusers`).
2. `/etc/sudoers.d/90-tvolodi` present (line: `tvolodi ALL=(ALL) NOPASSWD:ALL`), mode 0440, owner root:root.
3. `/home/tvolodi/.ssh/authorized_keys` populated with `C:\Users\tvolo\.ssh\ai-dala-infra.pub` (ed25519, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`).
4. **Per-operator variant** (selected per orchestrator's delegation note — see "User decisions already made"):
   - `viktor_d` (uid 1002) with `/etc/sudoers.d/90-viktor-d` and pubkey `C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub`.
   - `binali_r` (uid 1003) with `/etc/sudoers.d/90-binali-r` and pubkey `C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub`.
   - Both users added to `sshusers` group (so `AllowGroups sshusers` from T-0093 admits them).
   - All three (`tvolodi`, `viktor_d`, `binali_r`) added to `sudo`, `users`, `sshusers` secondary groups.
5. Provider key (comment `rsa-key-20260707`) preserved in `/root/.ssh/authorized_keys`. Break-glass anchor; do NOT remove.
6. **Multi-PC acceptance criterion:** viktor_d and binali_r pubkey lines parseable server-side (`ssh-keygen -lf <keyfile> -E sha256` succeeds for each `~/.ssh/authorized_keys`; `cat /etc/sudoers.d/90-<user>` validates with `visudo -c -f`). This workstation has no viktor_d or binali_r private keys, so a live SSH handshake from this box cannot exercise those credentials. The run's step-07 validator should clearly distinguish "server-side parse ok" from "operator-A SSH from operator-A's workstation" (the latter is deferred until operator A is present).
7. `landscape/hosts/pro-data-tech-qa.md` updated by step-08: `## Access` block rewritten with new users + sudoers + authorized_keys entries; T-0097 removed from `## Open tasks affecting this host`; `## What needs to happen` item #2 marked done. `last_verified:` frontmatter field bumped.

## User decisions already made (per orchestrator delegation)

- **Per-operator accounts (not single shared user).** The task body left this open ("Single-user vs multi-user — user decision required"), but the orchestrator's delegation note confirms the user's chosen path is per-operator accounts in the `sshusers` group. All three users get distinct accounts.
- **No additional approval gate.** User delegated with "just go" — proceed through the normal 8-step run; step-04's verdict may be `PASS` if blast radius + reversibility look clean (they do: reversible, recoverable, with break-glass).
- **Pubkey for `tvolodi` = `~/.ssh/ai-dala-infra.pub`.** Verified locally: no separate `ai-dala-infra-tvolodi.pub` exists (the management workstation user IS tvolodi). The orchestrator's note in the task context mentions this explicitly and is correct.

## Open questions or risks

- **Open question (decidable by step-04 designer):** should each `~/.ssh/` directory and `authorized_keys` be created with mode 0700 / 0600 respectively? Sibling hosts (`hetzner-prod`) follow this convention; recommend the executor do the same.
- **Open question (answerable by step-04 or step-06):** default shell for `tvolodi`, `viktor_d`, `binali_r`. Sibling hosts use `/bin/bash`. Default to `/bin/bash`.
- **Open question (probably answered by `last log` or `ls /home` first):** are uids 1001/1002/1003 actually free on `pro-data-tech-qa`? Discovery run's probe D says only `root` and `nobody` exist; 1001+ should be free, but the executor should still check before assuming.
- **Risk (multi-PC acceptance):** step-07 cannot independently exercise `viktor_d` or `binali_r` SSH handshakes from this workstation — their private keys are not on this Windows box. The validator's claim of multi-PC acceptance for those two operators is therefore limited to server-side authorized_keys parsing + sudoers validation. Document this limitation explicitly in step-07's handoff so it's not over-claimed.
- **Risk (sshusers group doesn't exist yet):** T-0093's `AllowGroups sshusers` directive is loaded, but the group itself may or may not have been created during T-0093's execution. Executor (`groupadd sshusers`) must handle the case where it already exists.
- **Risk (uid collisions on T-0090 follow-on):** if T-0090 later provisions application users, it should pick uids >= 1100 to avoid colliding with the human-operator range 1001–1003 established here. Flag this for the executor's `# What does NOT change` note so T-0090 is informed.

## Workflow recommendation

- **Workflow:** `infrastructure` (per task's `workflow:` frontmatter field).
- **Step bindings (per [`workflows/infrastructure.md`](../../workflows/infrastructure.md) § Step bindings):** 01 task-reader (this step) → 02 landscape-reader → 03 task-validator → 04 solution-designer → 05 user-approval (skipped per "just go" + low blast radius) → 06 executor-infra → 07 execution-validator → 08 landscape-updater.
- **Landscape files in scope for downstream steps:**
  - [`landscape/hosts/pro-data-tech-qa.md`](../../landscape/hosts/pro-data-tech-qa.md) — primary target.
  - [`landscape/secrets-inventory.md`](../../landscape/secrets-inventory.md) — read-only inventory; pubkey values stay external per `landscape/README.md` Editing rule #2.
  - [`landscape/hosts/hetzner-prod.md`](../../landscape/hosts/hetzner-prod.md) — pattern reference (sibling host already has the `tvolodi` baseline).
  - [`landscape/hosts/ubuntu-16gb-nbg1-1.md`](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) — secondary pattern reference.
- **Idempotency expectation:** `useradd`/`groupadd` are idempotent with `-U` and force-overwrite idioms; sudoers drop-ins are append-only via `[ -f ] && echo`. The solution-designer must spell this out for the executor.
- **Backup-before-destructive:** not strictly required here (no existing operator files to overwrite), but capture `/etc/sudoers` and `/etc/group` snapshots to `/var/backups/pre-T-0097/` for rollback confidence.

## Issues / risks

- See "Open questions or risks" above. None block the workflow; all are resolvable by step-04 or step-06.
