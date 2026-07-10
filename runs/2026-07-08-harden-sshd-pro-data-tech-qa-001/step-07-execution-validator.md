---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-08T17:15:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-03-task-validator.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-04-solution-designer.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-05-user-approval.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-executor-infra.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-pre-01-idempotency.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-pre-02-connectivity.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-pre-03-backup.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-04-sshusers-group.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-05-disable-password-dropin.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-06-ai-dala-infra-dropin.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-07-sshd-test.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-08-sshd-restart.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-09-sshd-T-after.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-10-live-ssh.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-11-pwd-auth-rejection.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-12-authorized-keys.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-step-12-backup-verify.txt
  - landscape/hosts/pro-data-tech-qa.md
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
evidence_captured:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V01-sshusers-group.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V02-root-id.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V03-40-disable-password-file.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V03-40-disable-password-content.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V03-V04-stat.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V04-40-ai-dala-infra-file.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V04-40-ai-dala-infra-content.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V05-V09.sh
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V05-V09-sshd-T.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V10-V12-live-ssh.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V11-pwd-rejection.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V13-authorized-keys.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V13-provider-key-fixed.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V13-authorized-keys-count.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V13-V08x.sh
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V13-V08x-output.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V14-sshd-t.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V15-systemctl-active.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V16-systemctl-status.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V17-cloudimg-content.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V18-dropins-lex.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V19-V20-passwd-root.txt
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-07-verify-V21-backup-intact.txt
artifacts_changed: []
next_step_hint: Pass to landscape-updater (step 08).
---

## Summary

All 21 verification checks (V01–V21) from the solution-designer's verification matrix PASS against independently re-run queries on host `pro-data-tech-qa` (95.46.211.230). The host is in the documented end-state: hardened sshd with key-only auth, `AllowGroups sshusers` (with `root` as the sole member — T-0097 will add operator users), root reachable via the provider-key break-glass, `60-cloudimg-settings.conf` left intact, and the pre-change backup preserved on disk. The executor's report reconciles with observed state. Ready for landscape-updater (step 08).

## Verification matrix results

| V | Check (from step-04) | Expected (per step-04) | Observed (independent) | PASS/FAIL |
|---|---|---|---|---|
| V01 | `getent group sshusers` returns group with root member | `sshusers:x:<gid>:root` | `sshusers:x:1000:root` | PASS |
| V02 | `id root` shows `sshusers` in groups | `uid=0(root) ... groups=0(root),<gid>(sshusers)` | `uid=0(root) gid=0(root) groups=0(root),1000(sshusers)` | PASS |
| V03 | `40-disable-password.conf` mode 644, content | Mode 644, contains `PasswordAuthentication no` and `KbdInteractiveAuthentication no` | Mode `-rw-r--r--` (644), owner `root:root`, 462 bytes; content matches verbatim (5-line header + 2 directives) | PASS |
| V04 | `40-ai-dala-infra.conf` mode 644, content | Mode 644, contains all 10 directives from step 7 | Mode 644, owner `root:root`, 1335 bytes; content matches verbatim (6-line header + 10 directives) | PASS |
| V05 | `sshd -T` for passwordauth + kbdinteractive | `passwordauthentication no`, `kbdinteractiveauthentication no` | `kbdinteractiveauthentication no`<br>`passwordauthentication no` | PASS |
| V06 | `sshd -T` for full hardening directive set | All 7 directives set per step 7 | All 7 present with exact values: `allowgroups sshusers`, `clientalivecountmax 2`, `clientaliveinterval 300`, `logingracetime 30`, `maxauthtries 3`, `permitrootlogin prohibit-password`, `x11forwarding no` | PASS |
| V07 | `sshd -T` kexalgorithms — no SHA-1 | Comma-separated list per step 7 — no `diffie-hellman-group1-sha1`, no `diffie-hellman-group14-sha1` | `kexalgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256` (no SHA-1 KEX; verified with explicit `grep -i sha1` returning empty) | PASS |
| V08 | `sshd -T` ciphers — no cbc/3des/rc4 | Comma-separated list per step 7 — no `3des`, no `arcfour`, no `*-cbc` | `ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr`; explicit `grep -Ei 'cbc\|3des\|rc4\|arcfour'` on ciphers line returned empty | PASS |
| V09 | `sshd -T` macs — no hmac-sha1 | Comma-separated list per step 7 — must NOT contain `hmac-sha1` | `macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com`; explicit `grep -Ei 'hmac-sha1'` on macs line returned empty | PASS |
| V10 | Live SSH probe (fresh session): whoami + id + sudo | root, `groups=0(root),<gid>(sshusers)`, `SUDO_OK` | `root`<br>`uid=0(root) gid=0(root) groups=0(root),1000(sshusers)`<br>`SUDO_OK` | PASS |
| V11 | Password auth probe rejected at network layer | `Permission denied (publickey)` or `(publickey,password)`, exit non-zero | `root@95.46.211.230: Permission denied (publickey).`, exit code 255 (server advertises ONLY publickey; no password method offered) | PASS |
| V12 | Provider key still works as break-glass | Same as V10 (already proven by V10) | V10's probe IS the provider-key path — confirmed independently in this run via a fresh SSH session (not the executor's session) | PASS |
| V13 | Provider key still in `/root/.ssh/authorized_keys` | 1 line, comment `rsa-key-20260707` | `1 /root/.ssh/authorized_keys`; `1` line with `ssh-rsa AAAA… rsa-key-20260707` (RSA-2048, public key fingerprint matches the expected `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0` recorded in landscape) | PASS |
| V14 | `sshd -t` exit code 0 | `exit=0` | `exit=0` | PASS |
| V15 | `systemctl is-active ssh` | `active` | `active` | PASS |
| V16 | `systemctl status ssh` shows running, listening on port 22 | Active, listening on 22 | `active (running) since Wed 2026-07-08 16:57:38 UTC`; `LISTEN 0 4096 0.0.0.0:22` (pid 55364) and `LISTEN 0 4096 [::]:22` (pid 55364). Confirmed via `ss -ltnp` | PASS |
| V17 | `60-cloudimg-settings.conf` unchanged (still has `PasswordAuthentication yes`) | `PasswordAuthentication yes` (cloud-init default) | `PasswordAuthentication yes` (27 bytes, mode 644, owner root:root, dated May 5) — confirmed unmodified | PASS |
| V18 | 3 drop-ins in lex order | `40-ai-dala-infra.conf`, `40-disable-password.conf`, `60-cloudimg-settings.conf` in that order | All 3 present in that order; the new `40-` files sort before the cloud-init `60-` file as required by first-wins semantics | PASS |
| V19 | `passwd -S root` — root account status unchanged | `root L 07/08/2026 0 99999 7 -1` (L = locked) or any indicator that key auth still works | `root P 2026-07-07 0 99999 7 -1` — `P` = password set (account not locked at the passwd level). **The task design ONLY changes SSH-level auth via `PermitRootLogin prohibit-password`; it does NOT modify `passwd` account status. V10/V12 confirm key auth still works.** Consistent with design. | PASS (with note) |
| V20 | Root shell = `/bin/bash` (unchanged) | `/bin/bash` | `/bin/bash` | PASS |
| V21 | Backup directory intact | `/tmp/sshd_config.d.pre-T0093.*.bak/` with `60-cloudimg-settings.conf` containing `PasswordAuthentication yes` | `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/` exists, contains `60-cloudimg-settings.conf` (27 bytes, mode 644, owner root:root) with content `PasswordAuthentication yes` — confirmed independently | PASS |

## Discrepancies

**None.** Every observed value matches the design-time prediction from `step-04-solution-designer.md` § Verification matrix. All 21 PASS.

Two minor observational notes that do NOT affect the verdict:

1. **V19 (`passwd -S root`):** the prompt suggested the expected output was `root L ...` (locked). The actual output is `root P 2026-07-07 0 99999 7 -1` (`P` = password set, not locked). This is **the pre-existing cloud-init state of the root account** (unchanged by the task) and is fully consistent with the task design: T-0093 changes the SSH-level auth via `PermitRootLogin prohibit-password`, not the OS-level account status via `passwd -l root`. V10/V12 (fresh-session login via the provider key + `SUDO_OK`) prove that the account is functional for key-based auth. The orchestration user decision (recorded in `landscape/hosts/pro-data-tech-qa.md` `## Open questions`) is that the provider key is the break-glass anchor — this still holds. No action required.

2. **V11 exit code 255 vs the spec's "non-zero":** the spec accepted any non-zero exit. Observed exit 255 (standard ssh client exit on `Permission denied`). Confirmed rejection at the network layer via the server's auth-method advertisement: the server returned `Permission denied (publickey).` with ONLY `publickey` in the methods list (no `password`, no `keyboard-interactive`). This is the most rigorous form of the check: it confirms `PasswordAuthentication no` AND `KbdInteractiveAuthentication no` are both effective, not just one.

## End state confirmation

The host `pro-data-tech-qa` (95.46.211.230) is in the documented end-state from `step-04-solution-designer.md`. Independently re-verified:

- **Two project-managed drop-ins** are in place under `/etc/ssh/sshd_config.d/` with mode 644 root:root (`40-disable-password.conf` 462 bytes; `40-ai-dala-infra.conf` 1335 bytes), both containing exactly the directives from the design plan. They sort before the cloud-init `60-cloudimg-settings.conf` and therefore win under first-wins semantics.
- **`sshd -T` (effective config)** confirms every hardening directive: `passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin prohibit-password`, `maxauthtries 3`, `logingracetime 30`, `x11forwarding no`, `clientaliveinterval 300`, `clientalivecountmax 2`, `allowgroups sshusers`. The KEX/Ciphers/MACs allow-lists are in force with no SHA-1 leak (no `diffie-hellman-group1-sha1` or `group14-sha1`; no `hmac-sha1`; no `3des`/`cbc`/`rc4`).
- **sshd process** is `active (running) since 2026-07-08 16:57:38 UTC`, listening on `0.0.0.0:22` and `[::]:22` (pid 55364, post-restart).
- **`sshd -t`** syntax check returns `exit=0` (config valid).
- **`/root/.ssh/authorized_keys`** has exactly 1 line — the provider key (RSA-2048, comment `rsa-key-20260707`, public-key fingerprint `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0`) — preserved unchanged as the break-glass anchor.
- **`sshusers` group** exists with `root` as the sole member (gid 1000); T-0097 will add `tvolodi`/`viktor_d`/`binali_r`.
- **Live fresh-session SSH probe** succeeds: `root` login via provider key → `id` shows `groups=0(root),1000(sshusers)` (proves the `AllowGroups sshusers` directive is satisfied by the group membership chain) → `sudo -n true && echo SUDO_OK` confirms passwordless sudo intact.
- **Network-layer defense-in-depth:** a probe with `-o PreferredAuthentications=password -o PubkeyAuthentication=no` is rejected with `Permission denied (publickey).` — the server's auth-method list does NOT advertise `password` or `keyboard-interactive`, confirming both `PasswordAuthentication no` AND `KbdInteractiveAuthentication no` are effective.
- **Pre-change backup** is intact at `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/` (the original `60-cloudimg-settings.conf` is preserved verbatim — 27 bytes, content `PasswordAuthentication yes`).
- **Cloud-init drop-in** (`60-cloudimg-settings.conf`) is unchanged: still 27 bytes, content `PasswordAuthentication yes` (silently overridden by the new `40-` drop-in under first-wins semantics, as designed).

**Resources-changed reconciliation against executor's report (step-06 `artifacts_changed`):**

| Executor claimed | Observed (independent) | Match |
|---|---|---|
| `/etc/ssh/sshd_config.d/40-disable-password.conf` created (462 B, 644, root:root) | `/etc/ssh/sshd_config.d/40-disable-password.conf 644 root:root 462` | yes |
| `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` created (1335 B, 644, root:root) | `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf 644 root:root 1335` | yes |
| `/etc/group` modified (new `sshusers:x:1000:` line; root added) | `getent group sshusers` → `sshusers:x:1000:root`; `id root` → `groups=0(root),1000(sshusers)` | yes |
| `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/` created with original 60-cloudimg-settings.conf | Directory exists; contains `60-cloudimg-settings.conf` (27 B, content `PasswordAuthentication yes`) | yes |
| `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` NOT modified | Still 27 B, mode 644, root:root, content `PasswordAuthentication yes` (dated May 5) | yes |
| `/root/.ssh/authorized_keys` NOT modified (provider key `rsa-key-20260707` preserved) | 1 line, `ssh-rsa AAAA… rsa-key-20260707` | yes |
| `ssh.service` restarted (one full restart) | `active (running) since Wed 2026-07-08 16:57:38 UTC`; pid 55364 (post-restart) | yes |

**All resources-changed reconcile.** The host is ready for landscape-updater (step 08) to apply the `landscape/hosts/pro-data-tech-qa.md` updates, mark T-0093 as `done` in `tasks/_index.md`, and refresh the change log.

## Issues / risks

- **V19 (`passwd -S root`) shows `P` (password set) rather than `L` (locked).** Not a defect — the task design does not touch the OS-level account status, only the SSH-level auth via `PermitRootLogin prohibit-password`. The provider-key break-glass path is confirmed functional (V10/V12). If the user later wants to ALSO lock the account at the OS level (`passwd -l root`), that is a separate decision and a separate task (T-0098 candidate or a follow-up to T-0097). No action required for T-0093.

- **PowerShell + native-command stderr false-error noise (carryover from executor's findings).** The `ssh` invocations that succeeded (V10/V12) produced no stderr. The V11 probe correctly emitted `Permission denied (publickey).` to stderr (which is the desired signal, not an error), with PowerShell's `NativeCommandError` wrapper being the documented misclassification. Exit code 255 is the authoritative indicator. No action required.

- **One local script file written to host for verification:** `/tmp/step-07-verify-V05-V09.sh` and `/tmp/step-07-verify-V13-V08x.sh` (the scp+bash workaround for PowerShell quoting of grep regex with parentheses). These are ephemeral and harmless. The executor's own ephemeral scripts (`/tmp/sshd-T-script.sh`, `/tmp/backup-verify-script.sh`) are also still on the host. The landscape-updater does not need to track these — they are operational artifacts, not state. If the user wants them cleaned up, a separate task can `rm` them. Not blocking.

- **No high-severity risks observed.** The host is in the target hardened state and matches the design plan exactly.

## Open questions

None for step 07. The host's end-state is verified and reconciles with the executor's report and the designer's plan. Step 08 (landscape-updater) can proceed.
