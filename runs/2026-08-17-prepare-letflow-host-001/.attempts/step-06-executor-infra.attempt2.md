---
run_id: 2026-08-17-prepare-letflow-host-001
step: "06"
agent: executor-infra
verdict: FAIL
created: 2026-08-17T03:42:00Z
task_id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
retry_of: step-06
inputs_read:
  - runs/2026-08-17-prepare-letflow-host-001/step-04-solution-designer.md
  - runs/2026-08-17-prepare-letflow-host-001/step-05-user-approval.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/secrets-inventory.md
  - runs/2026-06-27-apply-hetzner-firewall-001/executor-02-helpers.ps1
artifacts_changed: []
next_step_hint: Do NOT re-run executor-infra as a retry a third time. This requires a fresh solution-designer pass (step 04) that incorporates the newly-discovered live state (T-0087 sshd hardening already applied, AllowUsers tvolodi/viktor_d/binali_r, and the two undocumented operator accounts), likely preceded by a landscape-updater correction of ubuntu-16gb-nbg1-1.md and a search for whatever task/run produced T-0087 (not present in this repo's tasks/ or runs/ trees as of this attempt). The user must decide how viktor_d and binali_r should be treated (added to sshusers? left on a co-existing AllowUsers mechanism? something else?) before any new plan reaches approval.
---

## Summary

Attempt 2 (retry of the archived attempt 1 at [step-06-executor-infra.attempt1.md](./.attempts/step-06-executor-infra.attempt1.md)) halted during Phase 0 live-state reconfirmation, before any state-changing command was run: sub-step 0.2 revealed the host's sshd is already hardened (task `T-0087`, applied 2026-06-27) with an `AllowUsers tvolodi viktor_d binali_r` drop-in that the approved plan never accounted for, and two real, provisioned, sudo-capable local accounts (`viktor_d`, `binali_r`) exist on the host that are absent from `landscape/hosts/ubuntu-16gb-nbg1-1.md` and from the plan's own Phase 3. Proceeding with the approved plan's Phase 3 as written would silently replace `AllowUsers tvolodi viktor_d binali_r` with `AllowGroups sshusers` (containing only `tvolodi` and `root`), which would revoke SSH access for `viktor_d` and `binali_r` — an undesigned, unapproved, and potentially harmful side effect. Execution stopped per the plan's own instruction ("Any deviation from this expectation must be reconciled before Phase 3 proceeds") and this agent's rule against improvising past a wrong/invalid step. No rollback was necessary; host state is unchanged from before this attempt.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes (step-05's `inputs_read` lists `runs/2026-08-17-prepare-letflow-host-001/step-04-solution-designer.md`, matching the plan executed)
- Retry context: this is attempt 2. Attempt 1 failed at Phase 0.1 (missing SSH config alias, no host state touched); its handoff is archived at [step-06-executor-infra.attempt1.md](./.attempts/step-06-executor-infra.attempt1.md) and was not re-read in detail beyond confirming it exists and reported a clean pre-execution failure (per instruction, prior handoff content is not pasted here).

### Execution log

#### Step 0.1: SSH baseline reconfirmation
- Command: `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; whoami; hostname; date -u"`
- Exit code: 0
- Output (trimmed):
  ```
  ===OK===
  tvolodi
  ubuntu-16gb-nbg1-1
  Mon Aug 17 03:35:31 AM UTC 2026
  ```
- Result: success
- Backup taken: n/a (read-only)

#### Step 0.2: Current sshd effective config
- Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(passwordauthentication|permitrootlogin|allowgroups) '"`
- Exit code: 0
- Output (trimmed):
  ```
  permitrootlogin no
  passwordauthentication no
  ```
  (no `allowgroups` line)
- Result: **deviation from plan expectation**. Plan expected `passwordauthentication yes`, `permitrootlogin yes`, no `allowgroups` line (per the landscape file's "hardening not yet applied" status, last verified 2026-06-27). Live state shows `passwordauthentication no` and `permitrootlogin no` already in effect — sshd hardening has already happened, contrary to the landscape snapshot and the plan built on it.
- Backup taken: n/a (read-only)

#### Step 0.2b (diagnostic, not in plan — read-only follow-up to reconcile the 0.2 deviation per the plan's own instruction)
- Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowgroups|kexalgorithms|ciphers|macs|usedns) '"`
- Exit code: 0
- Output (trimmed):
  ```
  logingracetime 120
  maxauthtries 6
  clientaliveinterval 300
  clientalivecountmax 2
  permitrootlogin no
  pubkeyauthentication yes
  passwordauthentication no
  kbdinteractiveauthentication no
  x11forwarding no
  permitemptypasswords no
  usedns no
  ciphers chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
  macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  kexalgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521
  ```
  No `allowgroups` line present at all (access control is via `AllowUsers`, not `AllowGroups` — see next step).
- Result: informational — confirms partial hardening is live but does not match the T-0093/T-0102/T-0134 fleet pattern (different `MaxAuthTries`, `LoginGraceTime`, `KexAlgorithms`, `Ciphers` values; no `AllowGroups`).

#### Step 0.2c (diagnostic, not in plan): sshd_config.d contents
- Command: `ssh ubuntu-16gb-nbg1-1 "ls -la /etc/ssh/sshd_config.d/"` followed by `cat` of each `.conf` file
- Exit code: 0
- Output (trimmed):
  ```
  -rw-r--r-- 1 root root  116 Jun 27 10:01 40-disable-password.conf
  -rw-r--r-- 1 root root  249 Jun 27 14:57 40-ssh-hardening.conf
  -rw-r--r-- 1 root root  232 Jun 27 10:01 40-ssh-hardening.conf.bak.20260627T145652Z
  -rw------- 1 root root   27 Jun 27 04:27 50-cloud-init.conf

  == 40-disable-password.conf ==
  # Managed by ai-dala-infra. T-0087. Mirrors prod T-0007.
  PasswordAuthentication no
  KbdInteractiveAuthentication no

  == 40-ssh-hardening.conf ==
  # Managed by ai-dala-infra. T-0087.
  PermitRootLogin no
  AllowUsers tvolodi viktor_d binali_r
  X11Forwarding no
  ClientAliveInterval 300
  ClientAliveCountMax 2
  Macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

  == 40-ssh-hardening.conf.bak.20260627T145652Z ==
  # Managed by ai-dala-infra. T-0087.
  PermitRootLogin no
  AllowUsers tvolodi
  X11Forwarding no
  ClientAliveInterval 300
  ClientAliveCountMax 2
  Macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  ```
- Result: **root cause identified.** A prior task, `T-0087`, already applied sshd hardening to this host on 2026-06-27 (same day as the Hetzner firewall/UFW/fail2ban work, but never folded into `landscape/hosts/ubuntu-16gb-nbg1-1.md`, which still lists item 4 "sshd hardening" as `⏳` not yet done, and lists no `T-0087` anywhere). The `.bak` filename timestamp (`14:57`) shows `AllowUsers` was edited at least once in place, growing from `tvolodi` alone to `tvolodi viktor_d binali_r`. Access control today is via `AllowUsers`, not `AllowGroups`. `40-disable-password.conf`'s content happens to be byte-identical to what the plan's step 3.5 would write (harmless, idempotent), but `40-ssh-hardening.conf` bears no relation to the plan's step 3.6 `40-ai-dala-infra.conf` content or filename.

#### Step 0.2d (diagnostic, not in plan): sshusers group and undocumented accounts
- Command: `ssh ubuntu-16gb-nbg1-1 "getent group sshusers; id tvolodi; id root"`
- Exit code: non-zero for `getent group sshusers` (group does not exist); 0 for the `id` calls
- Output (trimmed):
  ```
  uid=1000(tvolodi) gid=1000(tvolodi) groups=1000(tvolodi),27(sudo),100(users)
  uid=0(root) gid=0(root) groups=0(root)
  ```
- Command: `ssh ubuntu-16gb-nbg1-1 "id viktor_d; id binali_r; getent passwd | grep -E 'viktor_d|binali_r'; sudo ls -la /home/"`
- Exit code: 0
- Output (trimmed):
  ```
  uid=1001(viktor_d) gid=1001(viktor_d) groups=1001(viktor_d),27(sudo),100(users)
  uid=1002(binali_r) gid=1002(binali_r) groups=1002(binali_r),27(sudo),100(users)
  viktor_d:x:1001:1001:Viktor D operator:/home/viktor_d:/bin/bash
  binali_r:x:1002:1002:Binali R operator:/home/binali_r:/bin/bash
  drwxr-x---  4 binali_r binali_r 4096 Jun 27 15:00 binali_r
  drwxr-x---  4 tvolodi  tvolodi  4096 Jun 27 14:28 tvolodi
  drwxr-x---  6 viktor_d viktor_d 4096 Jun 28 05:58 viktor_d
  ```
- Result: **confirmed real, provisioned, sudo-capable accounts**, active as recently as 2026-06-28 (viktor_d home directory mtime), not transient/spurious. Directly contradicts `landscape/hosts/ubuntu-16gb-nbg1-1.md`'s Access section ("Other local users (uid >= 1000 or login shell): root, nobody, tvolodi. No aitala, no deploy. Clean slate.").

### Rollback executed
Not needed. No state-changing command was issued at any point in this attempt — all commands run were read-only (`whoami`/`hostname`/`date`, `sshd -T`, `ufw status`, `cat`/`ls`/`getent`/`id`, `dpkg -l`). Host state at the end of this attempt is identical to its state at the start.

### Resources changed
- Files on host: none
- Services restarted: none
- External resources changed: none (Hetzner Cloud Firewall API was never called; Phase 2 was not reached)

## Issues / risks

- **HIGH — approved plan's Phase 3 would have silently revoked SSH access for two real, active, undocumented users.** `viktor_d` and `binali_r` are provisioned, sudo-capable accounts currently permitted to SSH in via `AllowUsers tvolodi viktor_d binali_r` (drop-in `40-ssh-hardening.conf`, task T-0087, 2026-06-27). The approved plan's step 3.6 would write `40-ai-dala-infra.conf` containing `AllowGroups sshusers`, and step 3.2-3.4 would populate `sshusers` with only `tvolodi` and `root`. Because `40-ai-dala-infra.conf` sorts before `40-ssh-hardening.conf` lexicographically, the new `AllowGroups` restriction would become the effective access-control directive (first-wins semantics per the plan's own step 3.5 note), locking out `viktor_d` and `binali_r` without their knowledge or the user's explicit consent — this consequence was never surfaced during the step-04/step-05 approval cycle because the plan (and the landscape file it was built from) had no knowledge these accounts existed.
- **HIGH — `landscape/hosts/ubuntu-16gb-nbg1-1.md` is materially wrong, not just "51 days stale" as the plan characterized it.** The file states sshd hardening is `⏳` not yet done and that the account list is a "clean slate" of `root`, `nobody`, `tvolodi` only. Both statements are false as of live inspection. Task `T-0087` (which performed the hardening and created the two accounts, or at least the hardening — account provisioning may be a separate action) does not appear in this repo's `tasks/` or `runs/` directories as of this attempt, meaning either T-0087 was executed by tooling/a process outside this repo's workflow entirely, or its task/run records are missing from the repo. This needs investigation before any new plan for this host is designed.
- **MEDIUM — `40-disable-password.conf` already exists with content identical to the plan's step 3.5.** Harmless if the plan is re-run as-is (idempotent overwrite), but confirms parts of this plan's target state already exist under different provenance (T-0087) than assumed (a fresh T-0134-only change).
- **INFORMATIONAL — Phase 1 (Docker) and Phase 2 (Hetzner Firewall) were never reached.** Their preconditions (0.4 Docker-absence check: confirmed `NOT_INSTALLED`, matching plan expectation) were checked and were clean/as-expected; only the sshd-hardening deviation (0.2) caused the halt. A future re-run does not need to re-litigate Docker or firewall assumptions, only the sshd hardening design.

## Open questions (optional)

- Who or what applied T-0087, and why is it not recorded in this repo's `tasks/`/`runs/` trees? This is off-plan discovery, noted for the user per the "no off-plan changes, note it" rule — not something this executor investigated further (e.g., no attempt was made to inspect shell history, cron, or other hosts' provisioning tooling for the source of T-0087).
- Should `viktor_d` and `binali_r` be added to `sshusers` in a revised plan, or is their access intended to be phased out as part of moving this host to the `letflow-app` role? This is a user decision, not inferable from any input file.
- Does the pre-existing hardening's divergent `MaxAuthTries` (6 vs. the fleet's 3), `LoginGraceTime` (120 vs. 30), and `KexAlgorithms`/`Ciphers` lists (including post-quantum KEX algorithms not present in the T-0093/T-0102 pattern) reflect a deliberate, newer security posture that the fleet pattern should adopt, or should this host simply be brought in line with the older fleet pattern? Worth resolving before a revised plan is designed, since it affects whether `40-ssh-hardening.conf` should be edited in place, merged, or fully replaced.
