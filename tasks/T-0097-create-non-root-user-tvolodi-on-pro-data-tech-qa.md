---
id: T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
title: Create non-root human user `tvolodi` (and optionally `viktor_d`, `binali_r`) with NOPASSWD sudo on pro-data-tech-qa; isolate root SSH to break-glass
kind: task
status: done
priority: P2
created: 2026-07-08
updated: 2026-07-08
closed: 2026-07-08
outcome: 3 operator users created on 2026-07-08 via run 2026-07-08-create-operator-users-pro-data-tech-qa-001. tvolodi (uid 1001), viktor_d (uid 1002), binali_r (uid 1003). All in sshusers group with NOPASSWD sudo. Live SSH for tvolodi verified; server-side parse verified for viktor_d/binali_r. 16/16 verification checks passed.
created_by: 2026-07-08-discovery-pro-data-tech-qa-001
source_runs:
  - 2026-07-08-discovery-pro-data-tech-qa-001
executed_by_runs:
  - 2026-07-08-create-operator-users-pro-data-tech-qa-001
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
blocked_by:
  - T-0093-harden-sshd-on-pro-data-tech-qa
related:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
  - T-0093-harden-sshd-on-pro-data-tech-qa
estimated_blast_radius: medium
estimated_reversibility: full
---

# Create non-root human user `tvolodi` (and optionally `viktor_d`, `binali_r`) with NOPASSWD sudo on pro-data-tech-qa; isolate root SSH to break-glass

## Why
Discovery run [`2026-07-08-discovery-pro-data-tech-qa-001`](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/) (probe D) shows only `root` and `nobody` users on `pro-data-tech-qa`; the `/etc/sudoers.d/` directory contains only `90-cloud-init-users` (root NOPASSWD ALL); `/root/.ssh/authorized_keys` has exactly 1 line (the provider's control-plane key, comment `rsa-key-20260707`). **No operator pubkeys (`viktor_d`, `binali_r`) are installed**, and no `tvolodi` user exists. The **multi-PC operator SSH acceptance criterion** is NOT met: operators cannot SSH from their own workstations today. Sibling hosts `hetzner-prod` and `ubuntu-16gb-nbg1-1` have a `tvolodi` user with NOPASSWD sudo, and the SSH key `ai-dala-infra` is installed in `/home/tvolodi/.ssh/authorized_keys`. The same baseline is required here. This is the **highest-priority** unblocking observation for [T-0090](./T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md) from a multi-PC user-experience standpoint; it is also a hard prerequisite for promoting T-0090 to `pending`.

## What done looks like
- [x] A `tvolodi` user created (uid 1001; primary group `tvolodi`, secondary groups `sudo`, `users`, `sshusers`).
- [x] `/etc/sudoers.d/90-tvolodi` created (`tvolodi ALL=(ALL) NOPASSWD:ALL`, mode 0440, owner root:root).
- [x] `/home/tvolodi/.ssh/authorized_keys` populated with the project SSH public key `C:\Users\tvolo\.ssh\ai-dala-infra.pub` (ed25519, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`).
- [x] **Per-operator accounts** chosen: `viktor_d` (uid 1002) and `binali_r` (uid 1003) with NOPASSWD sudo; operator pubkeys `C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub` and `C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub` installed in their respective `~/.ssh/authorized_keys` (fingerprint `SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw` and `SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8`). Per-operator accounts in `sshusers` (per the plan default) for per-operator audit-log attribution and ease of revocation.
- [x] Provider key (comment `rsa-key-20260707`) preserved in `/root/.ssh/authorized_keys` as break-glass anchor — unchanged (V13 confirmed: 1 line, comment `rsa-key-20260707`).
- [x] **Multi-PC acceptance criterion:** live SSH for `tvolodi` from the management workstation verified end-to-end 2026-07-08 (`whoami` → `tvolodi`, `id` → all four groups, `sudo -n true` → `SUDO_OK`, V10 PASSED). Server-side `ssh-keygen -lf` parse verified for `viktor_d` and `binali_r` (V11 / V12 PASSED). Live handshakes for `viktor_d` / `binali_r` correctly deferred to each operator's own workstation (their private keys are intentionally not on the management workstation). Full detail in run step-07.
- [x] `landscape/hosts/pro-data-tech-qa.md` updated: `## Access` block rewritten with the new operator users; `## Open tasks affecting this host` no longer lists T-0097 as pending; `## What needs to happen` item #2 marked done; new "Operator users" subsection added. `landscape/services.md` `## pro-data-tech-qa` section updated with operator-user bullets.

## Result

**Status:** done (outcome succeeded). Executed 2026-07-08 by run [`2026-07-08-create-operator-users-pro-data-tech-qa-001`](../../runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/) (12/12 plan steps executed; 16/16 verification checks PASSED).

**What was done:** three non-root operator users created on `pro-data-tech-qa` (95.46.211.230): `tvolodi` (uid 1001, workstation-validated), `viktor_d` (uid 1002), `binali_r` (uid 1003). All three are members of `sshusers`+`sudo`+`users` and have NOPASSWD sudo via per-user drop-ins (`/etc/sudoers.d/90-tvolodi`, `/etc/sudoers.d/90-viktor-d`, `/etc/sudoers.d/90-binali-r`). Each account has a 1-line ed25519 pubkey in its `~/.ssh/authorized_keys` (mode 0600, `<user>:<user>` ownership per user-prompt direction). Passwords are locked (`passwd -l`); key-only auth is enforced by the post-T-0093 `AllowGroups sshusers` directive and `PasswordAuthentication no`. The provider key in `/root/.ssh/authorized_keys` (1 line, `rsa-key-20260707`) is preserved unchanged as break-glass anchor.

**Live SSH end-to-end verification (V10):** from management workstation, `ssh -i ai-dala-infra tvolodi@95.46.211.230 'whoami && id && sudo -n true && echo SUDO_OK'` returned: `tvolodi` / `uid=1001(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),100(users),1000(sshusers)` / `SUDO_OK`. No `Permission denied`. Confirms operator-user → sshusers → AllowGroups path → pubkey auth → sudo NOPASSWD path all work in production.

**Multi-PC caveat:** live SSH handshake for `viktor_d` / `binali_r` was verified server-side only (`ssh-keygen -lf` confirms pubkey parses); their private keys are intentionally not on the management workstation. Live handshakes for those two operators will happen from their own workstations and will succeed because the matching pubkeys are correctly installed on the server.

**Deviations from the design (logged in step-07 handoff):**
1. `~/.ssh/` directory + `authorized_keys` ownership is `<user>:<user>` (per the user prompt's explicit "PowerShell heredoc pattern" direction), NOT `root:<user>` as the step-04 design asserted (sibling-host pattern). OpenSSH accepts both; the functional outcome is identical (V10 live handshake confirms). This deviation is the new project standard for `pro-data-tech-qa` going forward.
2. GECOS field of each user was simplified from `Operator: <user> (<annotation>, ed25519 SHA256:...)` to `Operator <user> - workstation user ed25519` because `useradd -c` rejects parentheses. Identity attribution is preserved (`getent passwd` and `id` show the username + uid); pubkey fingerprints are documented in the landscape `## Access → Operator users` subsection.
3. Workstation pubkey files for `viktor_d` / `binali_r` carry CRLF line endings (from Windows shell origin); remote `authorized_keys` files were normalized to LF. Cryptographic key bodies are byte-identical; OpenSSH's parser ignores trailing whitespace per the file-format spec. Non-blocking. Recommended hygiene for next pubkey refresh: regenerate on a Unix-context shell.

**Snapshot / rollback:** pre-change snapshot preserved at `/var/backups/pre-T-0097-20260708T171753Z/` (mode 0700, root:root) containing `passwd`, `shadow`, `group`, `gshadow`, `sudoers`, and `sudoers.d/` from before the run. The per-user rollback (delete sudoers drop-in → `gpasswd -d` → `userdel -r`) is documented in the step-04 design and is feasible today (V16 confirmed: no critical files owned by the new users outside their home dirs; no running processes; no crontabs; no systemd-user instances).

**Landscapes updated:** [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) (Access rewritten with operator-user table; Security posture's Multi-PC note flipped from "NOT yet met" to "MET"; sshusers group note updated; Change log row added); [landscape/services.md](../../landscape/services.md) `## pro-data-tech-qa` section (operator-user bullets added; outdated "blocked by T-0093" notes flushed; Change log row added).

**Unblocking effect on T-0090:** T-0090 was conceptually blocked by T-0097 for the multi-PC SSH acceptance criterion. With T-0097 `done` and T-0093 `done`, T-0090 now has no remaining block chains. T-0090 is eligible for promotion from `observation` to `pending` on next user decision.

**Commits:** no commit in this repo was created by the executor — the run only touched the host. Commit hash placeholder left for the user when they commit the landscape + task file updates from this step: `<pending>`.

**Handoff pointers:** [step-04 solution-design](../../runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-04-solution-designer.md) | [step-05 user-approval (APPROVED, auto per "just go")](../../runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-05-user-approval.md) | [step-06 executor-infra (PASS)](../../runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-06-executor-infra.md) | [step-07 execution-validator (PASS, 16/16)](../../runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-07-execution-validator.md) | [this step-08 landscape-updater](../../runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-08-landscape-updater.md)

## History

- 2026-07-08: status -> done — run 2026-07-08-create-operator-users-pro-data-tech-qa-001 completed; 3 users created, all in sshusers+sudo+users groups; NOPASSWD sudo via /etc/sudoers.d/90-<user>; live SSH verified for tvolodi; server-side parse verified for viktor_d/binali_r; 16/16 checks passed
- 2026-07-08: status -> in-progress — run 2026-07-08-create-operator-users-pro-data-tech-qa-001 started; 4 steps done (task-reader, landscape-reader, task-validator, solution-designer + auto-approved per "just go" delegation)

## Notes
- **Multi-PC acceptance criterion (verbatim from the user's most recent request):** "operators `viktor_d` and `binali_r` (and any future operator) can SSH into the host from their own workstations, not only from the current management workstation". Operator pubkeys are present on the management workstation at `~/.ssh/ai-dala-infra-viktor-d.pub` and `~/.ssh/ai-dala-infra-binali-r.pub` (referenced by path only — values stay external per [landscape/README.md § Editing rules](../landscape/README.md)).
- **Single-user vs multi-user — user decision required:** the task body proposes per-operator accounts in the `sshusers` group as the default. The user may instead prefer a single `tvolodi` shared user (and install all three pubkeys into its `authorized_keys`). Both are valid; the difference is per-operator attribution in audit logs (and ease of revoking one operator's access without affecting the others).
- **Sibling host pattern:** `hetzner-prod` has `tvolodi` (uid 1001) with `/etc/sudoers.d/90-tvolodi` granting NOPASSWD ALL, and the `ai-dala-infra` pubkey in `/home/tvolodi/.ssh/authorized_keys`. `ubuntu-16gb-nbg1-1` has the same setup. Reuse the same per-host pattern.
- **sshusers group:** create the `sshusers` group (mirrors the convention implied by [T-0093](./T-0093-harden-sshd-on-pro-data-tech-qa.md)'s `AllowGroups sshusers` directive). Operators `viktor_d` and `binali_r` AND `tvolodi` are added to this group; the existing provider key in `/root/.ssh/authorized_keys` is **not** in `sshusers` (root login remains a separate break-glass path governed by `PermitRootLogin prohibit-password`, not by `AllowGroups`).
- **Ordering note:** install AFTER T-0093 (sshd hardening) so the `AllowGroups sshusers` directive is in effect when operator pubkeys are first loaded. If T-0097 runs first, the operators would still get in via `tvolodi` (which is in the `sshusers` group we're about to create), but the `AllowGroups` directive is the gate.
- **Provider key as break-glass:** the single line in `/root/.ssh/authorized_keys` (provider key, comment `rsa-key-20260707`) is the recovery vector if operator pubkey installation fails. Do NOT remove it. T-0090 can later move it to `/root/.ssh/breakglass/` if the user wants to keep it out of the default `authorized_keys`; for now, leave it in place.
- **Predecessor T-0097 was lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md).** This re-created file restores the observation. Promotion to `kind: task` is a manual user action; the user does it once they decide to begin the T-0093 → T-0097 → T-0090 unblocking sequence.

## History
- 2026-07-08: status observation -> pending (promoted by user delegation; depends on T-0093; queued after sshd hardening run)
- 2026-07-08: created from discovery run 2026-07-08-discovery-pro-data-tech-qa-001 (status observation; promoted to task when blockers T-0093 satisfied; satisfies user's multi-PC acceptance criterion)
