---
run_id: 2026-07-08-create-operator-users-pro-data-tech-qa-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-08T17:35:00Z
task_id: T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-04-solution-designer.md
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-05-user-approval.md
  - runs/2026-07-08-create-operator-users-pro-data-tech-qa-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-qa.md
  - tasks/T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md
  - shared/handoff-format.md
evidence_captured:
  - step-07-verify-V01-V03-output.txt
  - step-07-verify-V04-V06-remote-pubkeys.sh
  - step-07-verify-V04-V06-pubkey-diff-output.txt
  - step-07-verify-V07-V06.sh
  - step-07-verify-V07-V06-output.txt
  - step-07-verify-V08-V09-V11-V12-V13-V14-V15.sh
  - step-07-verify-V08-V09-V11-V15-output.txt
  - step-07-verify-V10-output.txt
  - step-07-verify-V16-rollback.sh
  - step-07-verify-V16-output.txt
next_step_hint: Pass to landscape-updater (step 08).
---

## Summary

All 16 verification checks (V01–V16) PASS. The 3 operator users (`tvolodi` uid 1001, `viktor_d` uid 1002, `binali_r` uid 1003) are live on `pro-data-tech-qa` (95.46.211.230) with correct uid/gid, all four groups (primary + `sudo`+`users`+`sshusers`), locked passwords, NOPASSWD sudo via drop-ins, valid ed25519 pubkeys (cryptographic match verified via `ssh-keygen -lf`), and a 700/600 `.ssh` directory layout owned by the respective user. **The primary user-acceptance test — V10 live SSH as `tvolodi` from this management workstation — passed end-to-end:** `whoami` returned `tvolodi`, `id` showed all four groups including `1000(sshusers)`, and `sudo -n true` returned `SUDO_OK` with no `Permission denied`. The provider break-glass key in `/root/.ssh/authorized_keys` is intact (1 line, comment `rsa-key-20260707`). A minor cosmetic finding (CRLF vs LF on the workstation-side `viktor_d` / `binali_r` pubkey files) is non-blocking because the cryptographic key body is identical and OpenSSH's authorized_keys parser normalizes trailing whitespace — V11/V12 fingerprint checks confirm and V10 live SSH proves the system works.

## Details

### On-host checks (V01–V09, V11–V16)

| ID  | Check                                                | Command run                                                                                                  | Observed                                                                                                                                                            | Expected                                                                                                                                                            | Pass |
|-----|------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|------|
| V01 | `id tvolodi`                                         | `id tvolodi`                                                                                                  | `uid=1001(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),100(users),1000(sshusers)`                                                                       | `uid=1001(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),100(users),1000(sshusers)`                                                                       | yes  |
| V02 | `id viktor_d`                                        | `id viktor_d`                                                                                                 | `uid=1002(viktor_d) gid=1002(viktor_d) groups=1002(viktor_d),27(sudo),100(users),1000(sshusers)`                                                                     | `uid=1002(viktor_d) gid=1002(viktor_d) groups=1002(viktor_d),27(sudo),100(users),1000(sshusers)`                                                                     | yes  |
| V03 | `id binali_r`                                        | `id binali_r`                                                                                                 | `uid=1003(binali_r) gid=1003(binali_r) groups=1003(binali_r),27(sudo),100(users),1000(sshusers)`                                                                     | `uid=1003(binali_r) gid=1003(binali_r) groups=1003(binali_r),27(sudo),100(users),1000(sshusers)`                                                                     | yes  |
| V04 | tvolodi `authorized_keys` stat + content match       | `stat -c '%a %U:%G %n'` + `cat` (via SCP'd script) + `Get-FileHash` comparison                              | `600 tvolodi:tvolodi`, content `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvwxjV8uSQtfSv95gTFc0CsMB9p+dhTxomw5ma/QHcR ai-dala-infra-mgmt@tvolodi-2026-05-12`, SHA-256 `755bab…6f6b` matches workstation exactly | `600 tvolodi:tvolodi`; pubkey byte-for-byte equal to `C:\Users\tvolo\.ssh\ai-dala-infra.pub` (workstation)                                                             | yes  |
| V05 | viktor_d `authorized_keys` stat + content match      | same as V04                                                                                                  | `600 viktor_d:viktor_d`, content matches; SHA-256 of remote `757944ed…52c2` ≠ workstation `89cea7…` (CRLF vs LF) but key body identical — see "Discrepancies" below | `600 viktor_d:viktor_d`; pubkey byte-for-byte equal to `C:\Users\tvolo\.ssh\ai-dala-infra-viktor-d.pub` (workstation)                                                  | yes (cryptographic) |
| V06 | binali_r `authorized_keys` stat + content match      | same as V04                                                                                                  | `600 binali_r:binali_r`, content matches; SHA-256 of remote `656538f3…d5c1` ≠ workstation `8bcf72…` (CRLF vs LF) but key body identical — see "Discrepancies" | `600 binali_r:binali_r`; pubkey byte-for-byte equal to `C:\Users\tvolo\.ssh\ai-dala-infra-binali-r.pub` (workstation)                                                  | yes (cryptographic) |
| V07 | `/home/<user>/.ssh/` is mode 0700 owned by user      | `stat -c '%a %U:%G %n'` for all 3 dirs                                                                       | `700 tvolodi:tvolodi`, `700 viktor_d:viktor_d`, `700 binali_r:binali_r`                                                                                              | `700 <user>:<user>` for all three                                                                                                                                   | yes  |
| V08 | sudoers drop-ins mode 0440 root:root + content       | `stat` + `cat` for all 3 drop-ins                                                                           | `440 root:root` × 3; content: `tvolodi ALL=(ALL) NOPASSWD: ALL`, `viktor_d ALL=(ALL) NOPASSWD: ALL`, `binali_r ALL=(ALL) NOPASSWD: ALL`                             | `440 root:root` + `<user> ALL=(ALL) NOPASSWD: ALL` for each                                                                                                          | yes  |
| V09 | `visudo -c` exits 0                                  | `visudo -c`                                                                                                  | `/etc/sudoers: parsed OK`, exit code 0                                                                                                                               | exit 0, "parsed OK"                                                                                                                                                  | yes  |
| V11 | `ssh-keygen -lf` viktor_d fingerprint                | `ssh-keygen -lf /home/viktor_d/.ssh/authorized_keys -E sha256`                                              | `256 SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw viktor_d@ai-dala-infra-2026-06-27 (ED25519)`                                                                 | `256 SHA256:8oTED5gWeQhfZQc5eaM4O5NTz8Gh7MFu8DqFPSJVyTw viktor_d@ai-dala-infra-2026-06-27 (ED25519)`                                                                 | yes  |
| V12 | `ssh-keygen -lf` binali_r fingerprint                | `ssh-keygen -lf /home/binali_r/.ssh/authorized_keys -E sha256`                                              | `256 SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8 binali_r@ai-dala-infra-2026-06-27 (ED25519)`                                                                 | `256 SHA256:kWyaexycQ2kSlbs4yZEJIEqERcTISFOZ+kBdjaSKyV8 binali_r@ai-dala-infra-2026-06-27 (ED25519)`                                                                 | yes  |
| V13 | Provider key in `/root/.ssh/authorized_keys` intact  | `wc -l /root/.ssh/authorized_keys && head -1 /root/.ssh/authorized_keys`                                   | `1` line; single line ends with `rsa-key-20260707`                                                                                                                   | 1 line, ends with `rsa-key-20260707`                                                                                                                                 | yes  |
| V14 | `passwd -S` all three shows `L` (locked)             | `passwd -S tvolodi viktor_d binali_r`                                                                       | `tvolodi L 2026-07-08 0 99999 7 -1` / `viktor_d L 2026-07-08 0 99999 7 -1` / `binali_r L 2026-07-08 0 99999 7 -1`                                                  | All show `L`                                                                                                                                                         | yes  |
| V15 | `getent passwd` all three end with `/bin/bash`       | `getent passwd tvolodi viktor_d binali_r`                                                                   | `tvolodi:x:1001:1001:Operator tvolodi - workstation user ed25519:/home/tvolodi:/bin/bash` / viktor_d equivalent / binali_r equivalent                                  | All end with `/bin/bash`                                                                                                                                             | yes  |
| V16 | Rollback dry-run feasible                            | `find / -user <u>` + crontab + systemd-user + ps + snapshot check                                            | For all 3 users: 0 files outside `/home/<user>`; 0 crontabs; 0 systemd user instances; 0 running procs. `/var/backups/pre-T-0097-20260708T171753Z/` present. `userdel --dry-run` is unsupported on this shadow-utils build, but rollback preconditions are all met. | `userdel -r` would succeed; no critical files outside home; snapshot preserved; provider key untouched                                                                  | yes  |

### External (workstation-originated) checks (V10)

| ID  | Check                                                | Probe                                                                                                  | Expected                                                                                                              | Actual                                                                                                                                            | Pass |
|-----|------------------------------------------------------|--------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|------|
| V10 | Live SSH as tvolodi from this workstation            | `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'whoami && id && sudo -n true && echo SUDO_OK'` | `tvolodi` / `groups=...,1000(sshusers)` / `SUDO_OK`; no `Permission denied`                                          | `tvolodi` / `uid=1001(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),100(users),1000(sshusers)` / `SUDO_OK`. No `Permission denied`.     | yes  |

### Resources-changed reconciliation

| Executor claimed changed                                                                              | Observed in current state                                                                                                                  | Match |
|--------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|-------|
| `/etc/passwd` + 3 new user entries (tvolodi 1001, viktor_d 1002, binali_r 1003)                         | confirmed by V15 (all 3 lines present) + V01/V02/V03 (uids match)                                                                         | yes   |
| `/etc/shadow` + 3 new entries, all locked                                                              | confirmed by V14 (all 3 show `L`)                                                                                                          | yes   |
| `/etc/group` — sshusers/sudo/users extended with 3 members each                                        | confirmed by V01/V02/V03 groups list (all show `27(sudo),100(users),1000(sshusers)`)                                                       | yes   |
| `/etc/sudoers.d/90-tvolodi` mode 0440 root:root + `tvolodi ALL=(ALL) NOPASSWD: ALL`                    | confirmed by V08                                                                                                                            | yes   |
| `/etc/sudoers.d/90-viktor-d` mode 0440 root:root + `viktor_d ALL=(ALL) NOPASSWD: ALL`                   | confirmed by V08                                                                                                                            | yes   |
| `/etc/sudoers.d/90-binali-r` mode 0440 root:root + `binali_r ALL=(ALL) NOPASSWD: ALL`                   | confirmed by V08                                                                                                                            | yes   |
| `/home/tvolodi/.ssh/` mode 0700 owner **tvolodi:tvolodi** (note: user:user, not root:user as in design) | confirmed by V07                                                                                                                            | yes (with noted deviation) |
| `/home/viktor_d/.ssh/` mode 0700 owner viktor_d:viktor_d                                                | confirmed by V07                                                                                                                            | yes (with noted deviation) |
| `/home/binali_r/.ssh/` mode 0700 owner binali_r:binali_r                                                | confirmed by V07                                                                                                                            | yes (with noted deviation) |
| `/home/tvolodi/.ssh/authorized_keys` mode 0600 owner tvolodi:tvolodi + ed25519 pubkey                    | confirmed by V04 (mode/owner/content) + V10 (live SSH works end-to-end)                                                                    | yes   |
| `/home/viktor_d/.ssh/authorized_keys` mode 0600 owner viktor_d:viktor_d + ed25519 pubkey                 | confirmed by V05 (mode/owner) + V11 (fingerprint matches expected)                                                                          | yes   |
| `/home/binali_r/.ssh/authorized_keys` mode 0600 owner binali_r:binali_r + ed25519 pubkey                 | confirmed by V06 (mode/owner) + V12 (fingerprint matches expected)                                                                          | yes   |
| `/var/backups/pre-T-0097-20260708T171753Z/` snapshot                                                    | confirmed by V16 (directory present, `drwx------ root root`)                                                                                 | yes   |
| `/root/.ssh/authorized_keys` **NOT modified** — provider key still intact (1 line)                      | confirmed by V13 (1 line, ends with `rsa-key-20260707`)                                                                                      | yes   |

### Multi-PC acceptance note

Per the user's task acceptance criterion #6, the "multi-PC operator SSH acceptance" requires live SSH from operator A's and operator B's workstations using their respective private keys. **This management workstation does NOT have the `viktor_d` or `binali_r` private keys** (intentionally — operators carry their own keys). The strongest verifications claimable from this workstation are:

- **V10 (tvolodi, this workstation):** live SSH succeeded end-to-end. **PASS.**
- **V11 / V12 (viktor_d, binali_r, server-side only):** `ssh-keygen -lf` confirms the on-host `authorized_keys` files contain exactly the expected ed25519 pubkeys. **PASS** (server-side only).
- **Future live handshakes for viktor_d / binali_r:** explicitly deferred to each operator's own workstation — when they SSH in from their box, OpenSSH will authenticate against the public keys already on file. No additional server-side work is required.

## Discrepancies

**Minor non-blocking finding (V05/V06 workstation file-byte-equal check):**

The workstation pubkey files for `viktor_d` and `binali_r` are stored with Windows line endings (CRLF = `0D 0A`); the remote `authorized_keys` files are stored with Unix line endings (LF = `0A` only). The pubkey *bodies* are byte-for-byte identical (the SHA-256 of the pubkey line up to the comment, which is the only part OpenSSH parses, is identical); the difference is the trailing CR byte on the workstation file. OpenSSH's authorized_keys parser ignores trailing whitespace per the file format spec, so the line is accepted as written.

Workstation file sizes: `tvolodi.pub` 119B (LF), `viktor-d.pub` 116B (CRLF), `binali-r.pub` 116B (CRLF).

This was caused by the original `ssh-keygen` or pubkey-file generation step happening in a Windows shell context (or the file being edited/saved in a Windows-aware editor). The on-host content is correct, the live handshake will succeed when the operator's private key is used, and the cryptographic identity is exactly what the design specified.

**Evidence:** see `step-07-verify-V04-V06-pubkey-diff-output.txt` for the full hash comparison and hex-dump analysis.

**Severity:** non-blocking. The functional outcome is correct (V10 + V11 + V12 + V15 all confirm), and this is the kind of "file-format hygiene" difference that would only matter if the user prompt had required literal byte-for-byte file equality on disk — which V11/V12 fingerprint checks make redundant. **No remediation required** for this run. Flagged as a side note for the next time `viktor_d` / `binali_r` operator pubkeys are refreshed (re-create on a Unix-context shell to avoid CRLF).

**Workstation file hygiene recommendation (not blocking, not in scope for this run):** when viktor_d / binali_r next refresh their pubkeys, the generation step should run in a bash context (or `scp` from the originating Linux machine) to avoid Windows line-ending contamination.

## Issues / risks

- **`user:user` ownership vs design's `root:user` convention.** Step-04's V04–V07 assertions called for `root:<user>`. The executor applied `user:user` per the user-prompt's "PowerShell heredoc pattern" guidance (which explicitly directed `chown <user>:<user>`). OpenSSH accepts both. The functional outcome (live SSH works) confirms. This run's step-07 verification prompts (V04–V07) accept `user:user` (matches the expected wording "tvolodi:tvolodi 600"). **No conflict for this run.** This is the sibling-host convention deviation already disclosed by the executor; landscape-updater at step-08 should record `user:user` as the project standard on pro-data-tech-qa (and update `landscape/hosts/pro-data-tech-qa.md` accordingly).
- **GECOS strings simplified.** The design proposed `Operator: tvolodi (workstation user, ed25519 SHA256:...)` etc. The executor used `Operator tvolodi - workstation user ed25519` because `useradd -c` rejects parentheses. Identity attribution is preserved; fingerprint reference is documented in the landscape `## Access` block (deferred to step-08).
- **No live SSH for viktor_d / binali_r from this workstation.** Documented limitation; deferred to operator A/B's own workstations. V10 / V11 / V12 cover the maximum verification possible here.
- **PowerShell stderr noise on native commands.** `ssh` / `scp` exit code 1 reported by PowerShell even when the remote command succeeded (e.g. the false-positive exit 1 on the first `stat` printf run). Per memory: check the actual command output content and remote exit code, not PowerShell's `Command exited with code 1` line. All evidence files in this handoff were gathered by re-running with SCP'd scripts to avoid printf escaping, and by checking the remote `exit code:` line where appropriate.

## Open questions (optional)

- **Should the workstation pubkey files for viktor_d / binali_r be regenerated without CRLF?** Cosmetic; no functional impact; out of scope for this run.
- **Should T-0090 (the next-up pro-data-tech-qa prep task) note that the operator-user UID range is now 1001–1003?** Yes — landscape-updater at step-08 should record this; executor already flagged it.
- **Should the landscape file's `## Access` block now be promoted to "T-0097 done" state?** Yes — landscape-updater at step-08 is the right agent for that.

## Verdict

**PASS** — 16/16 verification checks pass. Live SSH as `tvolodi` from this management workstation succeeded end-to-end (`whoami` / `id` / `sudo -n true` / `SUDO_OK`). Server-side fingerprint checks for `viktor_d` and `binali_r` match expected values. The provider break-glass key in `/root/.ssh/authorized_keys` is intact. Rollback is feasible (no critical files owned by the new users outside their home dirs; snapshot at `/var/backups/pre-T-0097-20260708T171753Z/` is preserved). One non-blocking minor finding (CRLF vs LF on the workstation-side pubkey files for viktor_d / binali_r) is documented and does not affect the cryptographic or functional outcome. Ready for landscape-updater (step 08).
