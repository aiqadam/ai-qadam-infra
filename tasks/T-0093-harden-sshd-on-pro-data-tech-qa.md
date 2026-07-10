---
id: T-0093-harden-sshd-on-pro-data-tech-qa
title: Harden sshd on pro-data-tech-qa (PermitRootLogin prohibit-password, PasswordAuthentication no, AllowGroups sshusers, MaxAuthTries 3, LoginGraceTime 30) — must precede other SSH-using work
kind: task
status: done
priority: P1
created: 2026-07-08
updated: 2026-07-08
closed: 2026-07-08
outcome: Hardening applied successfully on 2026-07-08 via run 2026-07-08-harden-sshd-pro-data-tech-qa-001. 21/21 verification checks passed. Provider key preserved as break-glass.
created_by: 2026-07-08-discovery-pro-data-tech-qa-001
source_runs:
  - 2026-07-08-discovery-pro-data-tech-qa-001
executed_by_runs:
  - 2026-07-08-harden-sshd-pro-data-tech-qa-001
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
blocked_by: []
related:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
  - T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
  - T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
  - T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
estimated_blast_radius: medium
estimated_reversibility: full
---

# Harden sshd on pro-data-tech-qa (PermitRootLogin prohibit-password, PasswordAuthentication no, AllowGroups sshusers, MaxAuthTries 3, LoginGraceTime 30) — must precede other SSH-using work

## Why
Discovery run [`2026-07-08-discovery-pro-data-tech-qa-001`](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/) (probe E) shows sshd is at cloud-init defaults on `pro-data-tech-qa`: `PermitRootLogin yes`, `PasswordAuthentication yes` (explicit via the drop-in `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`), `MaxAuthTries 6`, `LoginGraceTime 120`, `X11Forwarding yes`, `ClientAliveInterval 0`. There is no `AllowUsers` / `AllowGroups` filter. The drop-in sets `PasswordAuthentication yes` explicitly, which is a cloud-init policy — disabling it requires a project drop-in that sorts first (`40-disable-password.conf` or `40-ai-dala-infra.conf`) under first-wins semantics. This host accepts password authentication over the public Internet; the only thing standing between sshd and the world is the pro-data.tech provider's network (if any). For a managed host, this is unacceptable. The sibling hardening is captured by [T-0094](./T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md) (UFW), [T-0095](./T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md) (fail2ban), and [T-0097](./T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md) (operator users) — but all of them require sshd to be in a stable, hardened state first, so this task is the gate.

## What done looks like
- [x] `/etc/ssh/sshd_config.d/40-disable-password.conf` created with `PasswordAuthentication no`, `KbdInteractiveAuthentication no` (sibling of `hetzner-prod`'s drop-in, lexicographically before `60-cloudimg-settings.conf`).
- [x] `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` created with `PermitRootLogin prohibit-password` (interim; allows pubkey root until T-0097 creates the operator users), `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, `AllowGroups sshusers`, drop SHA-1 MACs (`hmac-sha1`, `hmac-sha1-etm`).
- [x] `sshd -T` (effective output) re-verified post-change: all hardening directives set to the intended values; `passwordauthentication no`, `permitrootlogin prohibit-password`, `maxauthtries 3`, `x11forwarding no`, etc.
- [x] SSH login from the management workstation verified post-restart (key auth, no password prompt).
- [x] Provider key (comment `rsa-key-20260707`) still in `/root/.ssh/authorized_keys` (1 line) as break-glass anchor.
- [x] `landscape/hosts/pro-data-tech-qa.md` updated: `last_verified` refreshed; `## Access` sshd-config block rewritten with the post-hardening values; `## Security posture` note about sshd removed; `## What needs to happen` item #3 marked done.

## Result

T-0093 closed `done` on 2026-07-08. Executing run: [`2026-07-08-harden-sshd-pro-data-tech-qa-001`](../../runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/). Outcome: **succeeded** (21/21 verification checks PASSED, including all V01–V21 sub-checks across `sshusers` group, drop-in files, `sshd -T` effective output, live SSH login, password-rejection at network layer, provider-key preservation, sshd syntax/runtime status, cloud-init drop-in preservation, lex order, backup integrity). No deviations from the plan defined in `step-04-solution-designer.md`. Validator handoff: [`step-07-execution-validator.md`](../../runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-execution-validator.md) (verdict `PASS`). Executor handoff: [`step-06-executor-infra.md`](../../runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-executor-infra.md). Commit: pending (will be added when the orchestrator finalizes the run commit / when the user commits landscape + task files together — placeholder `<pending>` will be updated).

### Diff summary vs. "What done looks like"

- All 6 "what done looks like" criteria met (see checked boxes above).
- **Extra hardening applied** beyond the plan: hardened `KexAlgorithms` and `Ciphers` allow-lists in the same `40-ai-dala-infra.conf` drop-in (drops SHA-1 KEX, 3DES, RC4, CBC — mirroring `hetzner-prod`'s sibling drop-in). The plan listed these in the file content but did not enumerate them as a separate acceptance criterion; the executor and validator verified them under the broader "all directives set to intended values" check. Worth noting because the task title only mentions 3 directives; the actual drop-in contains 10 (matching `hetzner-prod`'s full set).
- **`sshusers` group** created (gid 1000) with `root` as sole member. This was pre-work in the plan (not a separate acceptance criterion) but is now a load-bearing fact for T-0097 — operators added to the group automatically get ssh access under the `AllowGroups` allow-list.

### Other notes

- **V19 `passwd -S root` shows `P` (password set) not `L` (locked).** Documented in `step-07` as "PASS with note" — this is the pre-existing cloud-init root account state, not changed by T-0093. SSH-level auth is governed by `PermitRootLogin prohibit-password`, not by OS-level account status. If the user wants to ALSO lock the root account at the OS level (`passwd -l root`), that is a separate decision (T-0098 candidate or a follow-up to T-0097).
- **V11 `Permission denied (publickey).`** is the rigorous form of the password-rejection check: the server's auth-method advertisement contains ONLY `publickey`, confirming both `PasswordAuthentication no` AND `KbdInteractiveAuthentication no` are effective, not just one.
- **Backup preserved at `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/`.** The original `60-cloudimg-settings.conf` (27 B, `PasswordAuthentication yes`) is in the backup directory verbatim. Future housekeeping task can `rm -rf` it.
- **Sibling-host parity achieved:** `pro-data-tech-qa` now matches the `hetzner-prod` and `ubuntu-16gb-nbg1-1` hardening baseline, modulo the open task list.

### Unblocking effect

With T-0093 `done`:
- [T-0094](./T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md) (UFW) — was `blocked_by: T-0093`, now unblocked.
- [T-0095](./T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md) (fail2ban) — was `blocked_by: T-0093`, now unblocked.
- [T-0097](./T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md) (operator users) — was `blocked_by: T-0093`, now unblocked (and is the **next-up** task — the multi-PC SSH acceptance criterion).
- [T-0090](./T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md) (full prep) — was `blocked_by: T-0093`; unblock satisfied, still effectively blocked by T-0097 for multi-PC acceptance.

## Notes
- **First-wins drop-in semantics:** sshd reads `/etc/ssh/sshd_config.d/*.conf` in lexicographic order; the first occurrence of a directive wins. The project drop-in must sort before `60-cloudimg-settings.conf` (cloud-init). Use `40-` prefix for project-managed drop-ins.
- **`PermitRootLogin` policy (user decision 2026-07-08):** keep `prohibit-password` permanently. Root login via the provider key remains a break-glass anchor; operator users (`tvolodi`, `viktor_d`, `binali_r` in the `sshusers` group) handle everyday work. **No** future staged transition to `no` — root stays reachable for recovery. If the user ever changes their mind, a separate task can flip this; for now the break-glass path stays open.
- **Provider key as break-glass:** the single line in `/root/.ssh/authorized_keys` (provider key, comment `rsa-key-20260707`) is the recovery vector. Do NOT remove it before operator pubkeys are installed. After T-0097 confirms operator pubkeys work, the provider key can stay as a break-glass anchor or be moved to a separate `/root/.ssh/breakglass/` subdirectory per the project's pattern (decision deferred to the user).
- **Sibling host pattern:** `hetzner-prod` and `ubuntu-16gb-nbg1-1` already have the same hardening applied (T-0007 done 2026-05-12, T-0049 done 2026-05-14, T-0040 done 2026-05-14, T-0050 done 2026-05-14). The drop-in contents and the `sshd -T` verification pattern can be reused verbatim.
- **Deferrable sub-tasks:** SHA-1 MAC drop (T-0040 sibling on `hetzner-prod`), `X11Forwarding no` (T-0049 sibling), `ClientAliveInterval` (T-0050 sibling). All small, can be in the same drop-in.
- **Predecessor T-0093 was a `pending` task on the pre-scrub snapshot at `a41ec73`; lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md).** This re-created file restores the observation. Promotion to `kind: task` is a manual user action; the user does it once they decide to begin the T-0093 → T-0097 → T-0090 unblocking sequence.

## History
- 2026-07-08: status -> done — run 2026-07-08-harden-sshd-pro-data-tech-qa-001 completed; 21/21 verification checks passed; sshd hardened, password auth disabled, root key-only login enforced, sshusers group created with root only, drop-ins 40-*.conf installed, backup at /tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak
- 2026-07-08: status pending -> in-progress, run 2026-07-08-harden-sshd-pro-data-tech-qa-001 (step-05 APPROVED via user delegation "just go")
- 2026-07-08: status observation -> pending (promoted by user delegation; depth-1 in T-0093 blocking tree, ready for 8-step infrastructure workflow run)
- 2026-07-08: created from discovery run 2026-07-08-discovery-pro-data-tech-qa-001 (status observation; promoted to task when blockers T-0097 satisfied)
