---
run_id: 2026-07-11-harden-sshd-pro-data-tech-prod-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0102-harden-sshd-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — validate T-0102 is well-formed and execution is safe to proceed
---

## Summary

The prod host (`pro-data-tech-prod`, `95.46.211.224`) was discovered on 2026-07-11 and its landscape file is current (not stale). It is a fresh Ubuntu 26.04 cloud image with no project-managed hardening applied: `PermitRootLogin yes`, `PasswordAuthentication yes`, no `AllowGroups` restriction, and no sshd drop-in files beyond the cloud-init default. The QA sister host (`pro-data-tech-qa`) completed identical sshd hardening under T-0093 on 2026-07-08 (21/21 checks passed) and serves as the exact reference implementation. The single critical difference for this run is that **no operator users exist yet on prod** — the `sshusers` group must be created and root added to it before `AllowGroups sshusers` is applied, or root will be permanently locked out. The landscape is sufficient for safe design; no live discovery is required before proceeding.

## Details

### Relevant facts (sourced from landscape)

**Host identity and access**
- Host ID `pro-data-tech-prod`, public IPv4 `95.46.211.224`, hostname `drkkrgm-prod-instance` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- SSH access path: `root@95.46.211.224`, key `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (OpenSSH RSA despite `.ppk` extension) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Root is the **only** login-capable account (uid 0). No uid≥1000 operator users exist. `/root/.ssh/authorized_keys` contains exactly 1 line (provider key, `rsa-key-20260707`) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- OS: Ubuntu 26.04 LTS, kernel `7.0.0-14-generic` (two minor versions behind QA's `7.0.0-27-generic`; 12 pending package upgrades outstanding, tracked separately) — _source: `landscape/hosts/pro-data-tech-prod.md`_

**Current sshd state — UNHARDENED**

| Parameter | Current value | Risk |
|---|---|---|
| `permitrootlogin` | **yes** | CRITICAL |
| `passwordauthentication` | **yes** | CRITICAL |
| `maxauthtries` | 6 | HIGH |
| `logingracetime` | 120 | MEDIUM |
| `x11forwarding` | yes | MEDIUM |
| `allowgroups` / `allowusers` | (none set) | MEDIUM |
| `pubkeyauthentication` | yes | OK |
| `permitemptypasswords` | no | OK |
| `usedns` | no | OK |

- Only sshd drop-in present: `60-cloudimg-settings.conf` (`PasswordAuthentication yes`, cloud-init default). No project-managed drop-ins — _source: `landscape/hosts/pro-data-tech-prod.md`_

**Target hardened state (from QA post-T-0093)**

Effective `sshd -T` output on QA after T-0093 hardening (21/21 checks passed):

| Parameter | Target value |
|---|---|
| `PermitRootLogin` | `prohibit-password` |
| `PasswordAuthentication` | `no` |
| `KbdInteractiveAuthentication` | `no` |
| `PubkeyAuthentication` | `yes` |
| `MaxAuthTries` | `3` |
| `LoginGraceTime` | `30` |
| `X11Forwarding` | `no` |
| `ClientAliveInterval` | `300` |
| `ClientAliveCountMax` | `2` |
| `AllowGroups` | `sshusers` |
| `KexAlgorithms` | `curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256` |
| `Ciphers` | `chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr` |
| `MACs` | `hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com` |

Implementation pattern: two project-managed drop-in files under `/etc/ssh/sshd_config.d/`, sorting before the cloud-init `60-cloudimg-settings.conf`:
- `40-disable-password.conf` — `PasswordAuthentication no`, `KbdInteractiveAuthentication no`
- `40-ai-dala-infra.conf` — `PermitRootLogin`, `MaxAuthTries`, `LoginGraceTime`, `X11Forwarding`, `ClientAliveInterval`, `ClientAliveCountMax`, `AllowGroups`, hardened KEX/Ciphers/MACs

_source: `landscape/hosts/pro-data-tech-qa.md`_

**Critical difference: no operator users on prod**
- On QA (post-T-0093): operator users `tvolodi` (uid 1001), `viktor_d` (uid 1002), `binali_r` (uid 1003) all belong to the `sshusers` group. Root is NOT in `sshusers` on QA (root login is governed by `PermitRootLogin prohibit-password`). This works on QA because the sshusers group has members — _source: `landscape/hosts/pro-data-tech-qa.md`_
- On prod: **no operator users exist yet** (T-0105 is pending). Root is the sole account. Therefore, the `sshusers` group must be created and **root must be added to it** before `AllowGroups sshusers` is applied, or root will be locked out of the host entirely. Root can be removed from `sshusers` once T-0105 lands and operator users are provisioned — _source: `landscape/hosts/pro-data-tech-prod.md`_

**Network notes**
- `eth1 192.168.0.3/24` (private LAN, provider-managed, brd `192.168.0.255`) — no impact on sshd hardening; sshd binds to `0.0.0.0` by default and the AllowGroups directive applies equally on both NICs. Documented for completeness — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Host firewall (UFW): **INACTIVE** — no current packet-level inbound restrictions. All ports on all interfaces are `policy ACCEPT`. UFW hardening is tracked by T-0103 (pending, after this run) — _source: `landscape/hosts/pro-data-tech-prod.md`_

### Stale or stub files encountered

- None. `landscape/hosts/pro-data-tech-prod.md` — `last_verified: 2026-07-11`, `status: populated`. Fresh discovery from today.

### Gaps requiring live discovery

- **None blocking.** All facts needed for design and execution are present in the landscape:
  - Current sshd parameter values are known (from `sshd -T` probe in discovery run T-0101)
  - Target state is fully specified (QA post-T-0093 drop-in file contents)
  - The only structural difference (no operator users) is documented and the mitigation is clear (root in sshusers)
- Advisory gap: the executor should confirm during execution that no non-root user has been added to the host since the 2026-07-11 discovery run (i.e., still `root`-only). A `getent passwd` check during the execution session is sufficient; this is not a blocker for design.

## Issues / risks

- **Lockout risk (CRITICAL, mitigated by design):** `AllowGroups sshusers` will deny ALL logins if no member of `sshusers` has SSH access. Since prod has no operator users, root must be added to the `sshusers` group before the drop-in files are reloaded. The executor must verify this ordering before every sshd reload. The solution design must make the `usermod -aG sshusers root` step non-optional and pre-validated.
- **No fallback console access confirmed:** pro-data.tech provider console access is not documented in the landscape (unlike Hetzner where the Rescue System is known). If root is locked out, out-of-band recovery path is unknown. This amplifies the lockout risk: the `sshd -t` validation gate and `sshusers` group check are the primary safeguards; the executor must not skip them.
- **12 pending package upgrades outstanding** (tracked separately, not in scope for T-0102) — one of which may include an OpenSSH package update. The executor should run `apt list --upgradable` at the start of the session and flag if `openssh-server` is in the list; if it is, the landscape-updater should note it for the pending upgrade task. No action in this run.
- **Kernel version lag** (`7.0.0-14-generic` vs QA's `7.0.0-27-generic`) — no impact on sshd hardening. Noted for completeness.
