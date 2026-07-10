---
run_id: 2026-07-08-create-operator-users-pro-data-tech-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/hosts/hetzner-prod.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/README.md
  - tasks/T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md
  - tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md
  - tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md
artifacts_read:
  - landscape/hosts/pro-data-tech-qa.md (last_verified 2026-07-08; populated)
  - landscape/services.md (last_verified 2026-07-08; populated)
  - landscape/hosts/hetzner-prod.md (last_verified 2026-07-08; populated)
  - landscape/hosts/ubuntu-16gb-nbg1-1.md (last_verified 2026-06-27; populated — fresh enough; key user pattern captured)
  - landscape/README.md
  - C:\Users\tvolo\.ssh\ai-dala-infra.pub (host)
  - C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub (host)
  - C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub (host)
artifacts_changed: []
next_step_hint: Pass to task-validator (step 03).
---

## Summary

Pro-data-tech-qa (95.46.211.230) is reachable, sshd-hardened, and ready for operator-user provisioning. The host currently has ONLY root (uid 0) and nobody (uid 65534) as login-capable users — no operator conflict exists. UIDs 1001, 1002, and 1003 are entirely free (no human users, no application users with shell). The `sshusers` group exists (gid 1000) with `root` as its sole member; T-0093's `AllowGroups sshusers` directive is in effect. All three operator pubkeys are present on the management workstation with the expected fingerprints. The sibling-host pattern from `hetzner-prod` / `ubuntu-16gb-nbg1-1` (uid 1001 → `tvolodi`, sudoers drop-in `90-tvolodi`, NOPASSWD ALL) is well-established and can be reused. No risks block the workflow; all flagged items are operational hints for the executor.

## Details

### Current host state — verified live (pro-data-tech-qa)

- **Reachable:** yes — SSH root login via `pro-data.tech-qa-instance_rsa.ppk` succeeded for all probes (provider key preserved as break-glass anchor in `/root/.ssh/authorized_keys`, comment `rsa-key-20260707`).
- **UID/GID state (probed 2026-07-08):** the only human-account uids present are root (uid 0, gid 0) and nobody (uid 65534, gid 65534 / nogroup). The highest human uid on the system is root's at 0; the gap 1000–65533 is **entirely vacant** for new users.
- **No operator conflict:** grep on `/etc/passwd` and `/etc/shadow` confirms no `tvolodi`, no `viktor_d`, no `binali_r`, and no application users in the uid 1000+ range. `tvolodi`/`viktor_d`/`binali_r` accounts can be created with uids 1001, 1002, 1003 cleanly.
- **`sshusers` group:** exists, gid 1000, sole member today is `root` (matches T-0093's run output). All three operator users will be added to this group so the `AllowGroups sshusers` sshd directive admits them.
- **`sudo` group:** exists, gid 27, **empty** on this host today. All three operator users will be added so the NOPASSWD sudo drop-in actually works (NOPASSWD rule + group membership is the convention used on `hetzner-prod` / `ubuntu-16gb-nbg1-1`).
- **`users` group:** exists, gid 100, empty on this host. All three operator users will be added for parity with the sibling hosts.
- **`admin` group:** exists, gid 107, empty on this host. Not needed by the task (sibling hosts do not use it).
- **`/etc/sudoers.d/` state:** today contains only `90-cloud-init-users` (root NOPASSWD ALL, mode 0440, root:root, untouched from cloud-init) and the standard `README`. The executor will need to write three new drop-ins: `90-tvolodi`, `90-viktor-d`, `90-binali-r`.
- **Break-glass anchor:** `/root/.ssh/authorized_keys` retains the provider's RSA-2048 key as the sole entry (mode 600 root, comment `rsa-key-20260707`). Confirmed unchanged from the discovery run; must not be removed or overwritten.
- **sshd config:** post-T-0093 drop-ins in place. `AllowGroups sshusers` is the gate. `PermitRootLogin prohibit-password` means the new operator users will be the only key-auth path for everyday work; root remains reachable only via the provider key (break-glass).

### Patterns from sibling hosts (hetzner-prod, ubuntu-16gb-nbg1-1)

- **hetzner-prod:** `tvolodi` (uid 1001, primary group `tvolodi`, secondary `sudo`+`users`). `/etc/sudoers.d/90-tvolodi` content `tvolodi ALL=(ALL) NOPASSWD:ALL`, mode 0440. `/home/tvolodi/.ssh/authorized_keys` contains the `ai-dala-infra` ed25519 pubkey (finger-print `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`). Pattern was bootstrapped manually 2026-05-12.
- **ubuntu-16gb-nbg1-1:** identical pattern. `tvolodi` (uid 1000 here, because `aitala` was already removed and no `tvolodi` existed when this host was provisioned). `/etc/sudoers.d/90-tvolodi` mode 0440 root:root, mtime 2026-06-27 04:46.
- **Convention to reuse for pro-data-tech-qa:**
  - `home` = `/home/<username>` mode 0755 (cloud-image default), `.ssh/` = 0700 root:<user> (mode 0700 root:<user>), `authorized_keys` = 0600 root:<user>.
  - Primary group = `<username>` (created by `useradd -U` / `-N`); secondary groups = `sudo, users, sshusers` (all present on this host).
  - Shell = `/bin/bash`.
  - Sudoers drop-in = `/etc/sudoers.d/90-<username>`, mode 0440, owner `root:root`, single line `<username> ALL=(ALL) NOPASSWD:ALL`.
  - **Uniqueness convention for UID on this host (homogeneous with sibling convention):** the existing `tvolodi` on `hetzner-prod` and `ubuntu-16gb-nbg1-1` both occupy the lowest free uid in the human range. On pro-data-tech-qa that means `tvolodi=1001`, `viktor_d=1002`, `binali_r=1003` (matches the task's What done looks like spec).

### Operator pubkeys present on the management workstation (verified 2026-07-08)

| Operator | File | Algorithm | SHA-256 fingerprint | Comment | Length |
|---|---|---|---|---|---|
| `tvolodi` (workstation user) | `C:\Users\tvolo\.ssh\ai-dala-infra.pub` | ed25519 | `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8` | `ai-dala-infra-mgmt@tvolodi-2026-05-12` | 119 B |
| `viktor_d` | `C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub` | ed25519 | `SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw` | `viktor_d@ai-dala-infra-2026-06-27` | 116 B |
| `binali_r` | `C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub` | ed25519 | `SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8` | `binali_r@ai-dala-infra-2026-06-27` | 116 B |

**Matching private keys present on this workstation:** confirmed for tvolodi (`ai-dala-infra`, 432 B). **Private keys NOT present on this workstation** for viktor_d / binali_r (their keys exist as `.pub` only on this box). Multi-PC acceptance for those two operators must rely on server-side authorized_keys parsing (`ssh-keygen -lf /home/<user>/.ssh/authorized_keys -E sha256` per user), not a live SSH handshake from this management workstation. This is consistent with the task's "Multi-PC acceptance criterion" caveat already captured by step-01.

### Gaps requiring live discovery

- **None blocking.** All required host facts gathered in this step. The executor at step-06 will still need to do its own `id` + `getent group` + `ls -la /etc/sudoers.d/` probes as part of its change-detection, but that is normal pre-/post-state capture inside the executor, not a landscape gap.

### Coordination with queued/sibling tasks

- **T-0094 (UFW on pro-data-tech-qa)** — `status: pending`, `priority: P2`, `blocked_by: T-0093` (now `done`). Eligible to run independently after T-0097. NOT currently executing in parallel with this run — confirmed by reading [`runs/`] (only `2026-07-08-discovery-pro-data-tech-qa-001`, `2026-07-08-harden-sshd-pro-data-tech-qa-001`, and this run exist on 2026-07-08). **No coordination conflict.** Recommended ordering: T-0097 → T-0094 → T-0095 → T-0090 (UFW before fail2ban because fail2ban's iptables chain should land on a host that already has a deny-by-default baseline; T-0090 afterwards because Docker install / app baseline is the largest blast radius).
- **T-0095 (fail2ban on pro-data-tech-qa)** — `status: pending`, `priority: P2`, `blocked_by: T-0093`. Same status as T-0094: eligible, not running in parallel.
- **T-0090 (prepare pro-data-tech-qa as ai-qadam QA instance)** — `status: observation`, parent task of T-0097, still effectively blocked on T-0097 for the multi-PC SSH acceptance criterion per the discovery findings.
- **No active live run** against this host other than this one. Safe to execute.

### Stale or stub files encountered

- `landscape/hosts/pro-data-tech-qa.md` — `last_verified: 2026-07-08`, fully populated by discovery + T-0093 sshd-hardening runs. **Fresh; no staleness.** Step-08 of this run will need to bump `last_verified` again.
- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `last_verified: 2026-06-27` (12 days old). Content quality on user-creation pattern is fine; not blocking. Stale enough that the landscape-updater should bump it during step-08 housekeeping if it touches that file (it shouldn't on this run).
- `landscape/hosts/hetzner-prod.md` — `last_verified: 2026-07-08`, fresh.
- `landscape/services.md` — `last_verified: 2026-07-08`, fresh.
- `landscape/secrets-inventory.md` — does **not exist on disk** (this was the 2026-07-07 scrub outcome; the file's previous contents were redacted from git history). Pubkey values for the operator keys are now stored externally per operator workstation; references in this run's landscape entries should name the pubkey files by path on the management workstation, not by fingerprint value.

## Issues / risks

- **`uid` 1001/1002/1003 collision risk: NONE.** Verified live — no other uid exists between 0 and 65533 except the standard system accounts (root, daemon, bin, sys, etc., all uid < 100) and nobody (uid 65534). The first human uid allocated on this host will be `tvolodi=1001`.
- **`sshusers` group readiness: OK.** Group exists (gid 1000) with `root` as the sole member. The executor's `usermod -aG sshusers <user>` will simply extend its member list.
- **`AllowGroups sshusers` directive ordering:** T-0093's drop-in `40-ai-dala-infra.conf` already declares `AllowGroups sshusers`. The first operator-SSH-able user (`tvolodi` via the workstation private key) will only be able to log in AFTER step-06 finishes writing that user's pubkey AND the `sshusers` membership update. If step-06 errors out mid-way, the operator could be temporarily locked out — but break-glass via `root` with the provider key remains intact (`PermitRootLogin prohibit-password` governs root, not `AllowGroups`).
- **Multi-PC acceptance scope (operator A/B):** server-side authorized_keys parsing will be the strongest validation available from this management workstation (no `viktor_d`/`binali_r` private keys here). The validator (step-07) must clearly distinguish "server-side authorized_keys parses + sudoers validates" from "operator A's workstation handshake succeeds". A live operator-A → server handshake is deferred to operator A's future presence; this is acceptable for T-0097 because the discovery-acknowledged multi-PC criterion is met by the on-server pubkey installation, which is what enables operator A's future handshake.
- **`/home/<user>/.ssh` directory permissions:** the executor must `chmod 0700 /home/<user>/.ssh` and `chmod 0600 /home/<user>/.ssh/authorized_keys` (and ownership `root:<user>`, NOT `<user>:<user>`, to match the sibling-host pattern). Sibling hosts use `root:<user>` ownership for the `~/.ssh/` and `authorized_keys` files; OpenSSH accepts both schemes as long as the file is not group- or world-writable. This is a small detail; the executor should consult `hetzner-prod.md` row at line documenting `tvolodi@91.98.28.126` access for the exact pattern.
- **No additional approval gate:** step-01 confirmed the user delegated with "just go" — proceed through the normal 8-step run; step-04's verdict PASS is expected (blast radius = medium, reversibility = full, break-glass anchor in place).
- **Sudoers drop-in file naming on a read-only filesystem / immutable flag:** not a concern — the host is a freshly-leased cloud VM with the standard Ubuntu rootfs and no immutable flags.
- **acct lockout window:** T-0094 (UFW) and T-0095 (fail2ban) are not running in parallel, and T-0097 itself does not modify firewall rules or fail2ban configuration. No lockout risk during execution; only the standard "if AllowGroups sshusers is missing a member" concern applies.

## Recommendation

Pass to step 03 (task-validator). The landscape, the live host state, the operator pubkeys on the workstation, and the sibling-host pattern are all clean and consistent. The task is well-scoped, has a sibling-host precedent, and has no blockers. No discovery sub-run is needed.
