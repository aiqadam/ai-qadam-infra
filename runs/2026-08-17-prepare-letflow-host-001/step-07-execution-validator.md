---
run_id: 2026-08-17-prepare-letflow-host-001
step: "07"
agent: execution-validator
verdict: PASS
created: 2026-08-17T06:10:00Z
task_id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
inputs_read:
  - runs/2026-08-17-prepare-letflow-host-001/step-04-solution-designer.md
  - runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md
  - runs/2026-08-17-prepare-letflow-host-001/step-0-3-accounts-baseline.txt
  - runs/2026-08-17-prepare-letflow-host-001/executor-06-helpers.ps1
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: >
  All designer-specified verification checks independently reconfirmed against
  live host state and the live Hetzner API. End state matches the plan and the
  executor's report. Both informational items the executor flagged (2.6/2.7
  local-hang, 4.4 timing signature) independently corroborated as non-issues.
  Advance to landscape-updater (step 08) to apply the documented landscape/
  updates and create observation task T-0135.
---

## Summary
Independently re-verified against live host state (`ubuntu-16gb-nbg1-1`) and the live Hetzner Cloud API: end state matches the designer's plan and the executor's PASS report on every check — accounts locked-not-deleted, sshd hardened to the fleet-standard pattern with working key auth and rejected password auth, Docker installed/active/functional with working egress, and the Hetzner Cloud Firewall carrying exactly the 3 specified rules. Both items the executor flagged as informational are independently corroborated as non-functional deviations, not defects.

## Details

### On-host checks
| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| SSH alias reachability | `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; whoami"` | `===OK===` / `tvolodi` | yes |
| `viktor_d`/`binali_r` expired, locked, not deleted | `ssh ubuntu-16gb-nbg1-1 "id viktor_d; id binali_r; sudo chage -l ...; sudo passwd -S ..."` | Both resolve via `id` (uid 1001/1002, groups unchanged); both `Account expires: Jan 02, 1970`; both `passwd -S` show `L 2026-06-27` | yes |
| Home directories intact | `sudo ls -la /home/viktor_d /home/binali_r` | Both present, mode `750`, owned by respective users, contents (`.bashrc`, `.ssh/`, `.cache/`, `.bash_history` for viktor_d) untouched | yes |
| sshd effective config matches fleet-standard | `sudo sshd -T \| grep -E '^(permitrootlogin\|passwordauthentication\|...\|allowusers\|allowgroups\|kexalgorithms\|...) '` | `allowgroups sshusers`, no `allowusers` line, `maxauthtries 3`, `logingracetime 30`, `permitrootlogin prohibit-password`, `passwordauthentication no`, kexalgorithms = curve25519/DH-group only (no PQ/hybrid entries), ciphers/macs match fleet pattern, `usedns no` | yes |
| `sshusers` group membership exact | `getent group sshusers` | `sshusers:x:1003:tvolodi,root` — exactly these two, no `viktor_d`/`binali_r` | yes |
| `viktor_d`/`binali_r` excluded from `sshusers` (negative check) | `getent group sshusers \| grep -qE 'viktor_d\|binali_r' && echo UNEXPECTED_MEMBER \|\| echo EXCLUSION_OK` | `EXCLUSION_OK` | yes |
| `sshd_config.d/` contains exactly the 3 expected files | `ls -la /etc/ssh/sshd_config.d/` | `40-ai-dala-infra.conf`, `40-disable-password.conf`, `50-cloud-init.conf` only — no `40-ssh-hardening.conf*` leftover (confirmed separately with an explicit `grep -c` returning `0`) | yes |
| Backup + removed-file recoverability | `ls /var/backups/ \| grep -E 'pre-T0134\|40-ssh-hardening'`; `ls -la /var/backups/pre-T0134.20260817T051919Z/`; `test -s .../40-ssh-hardening.conf.removed` | Backup dir present with full `/etc/ssh` contents (sshd_config, host keys, moduli, sshd_config.d/); `40-ssh-hardening.conf.removed` present, 249 bytes, non-empty | yes |
| Docker installed, active, enabled | `dpkg -l docker-ce docker-compose-plugin \| grep '^ii'; systemctl is-active docker; systemctl is-enabled docker` | Both packages `ii` (docker-ce 5:29.7.2-1, docker-compose-plugin 5.4.0-1); `active`; `enabled` | yes |
| `tvolodi` in `docker` group | `id tvolodi` | `groups=1000(tvolodi),27(sudo),100(users),1003(sshusers),983(docker)` | yes |
| `docker run hello-world` | `sudo docker run hello-world` | `Hello from Docker!` full message | yes |
| Container egress works | `sudo docker run --rm alpine:3.20 sh -c 'wget ... https://api.ipify.org'` | Returned `46.225.239.60` (host's own public IP) | yes |
| UFW/`after.rules` unaffected (3.13 fallback correctly not triggered) | `sudo ufw status verbose`; `grep -c 'T-0134' /etc/ufw/after.rules` | 22/80/443 `ALLOW IN Anywhere` (v4+v6), unchanged from baseline; `NO_T0134_MARKER` — confirms `after.rules` was not touched, consistent with egress test having passed | yes |
| fail2ban + ufw active | `sudo systemctl is-active fail2ban; sudo systemctl is-active ufw` | `active`, `active` | yes |
| Apt/GPG artifacts present | `cat /etc/apt/sources.list.d/docker.list`; `test -f /etc/apt/keyrings/docker.gpg` | `resolute stable` source line correct; `GPG_PRESENT` | yes |

### External checks
| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| Fresh SSH session, key auth | `ssh ubuntu-16gb-nbg1-1 "whoami; id \| grep sshusers"` (new session) | Connects, `tvolodi`, `sshusers` present | `tvolodi` / `groups=...,983(docker),1003(sshusers)` | yes |
| Password auth rejected | `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes ubuntu-16gb-nbg1-1 exit` | `Permission denied (publickey)` | `tvolodi@46.225.239.60: Permission denied (publickey).` exit 255 | yes |
| Hetzner Cloud Firewall live state (real HTTPS GET, independent PowerShell call, not reading the saved JSON) | `GET https://api.hetzner.cloud/v1/firewalls/11204449` with fresh token load | HTTP 200; exactly 3 rules — 22/80/443, all `0.0.0.0/0`+`::/0`; `applied_to` server `145542849` | HTTP 200; 3 rules exactly as expected, descriptions match executor's reported values; `applied_to.server.id = 145542849` | yes |
| External TCP reachability, port 80 | `Test-NetConnection 46.225.239.60 -Port 80` (fresh workstation probe) | `TcpTestSucceeded: False` (no listener) | `False`, ~13.8s completion | yes |
| External TCP reachability, port 443 | `Test-NetConnection 46.225.239.60 -Port 443` | `TcpTestSucceeded: False` | `False`, ~11.9s completion | yes |
| External TCP reachability, port 22 | `Test-NetConnection 46.225.239.60 -Port 22` | `TcpTestSucceeded: True` | `True` | yes |

### Resources-changed reconciliation
| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| `/etc/shadow`/`/etc/gshadow` — viktor_d/binali_r expired+locked | Confirmed via `chage -l` and `passwd -S` | yes |
| `/etc/group` — `sshusers` created (gid 1003, tvolodi+root); `docker` gained tvolodi | `getent group sshusers` = `1003:tvolodi,root`; `id tvolodi` shows both groups | yes |
| `40-disable-password.conf` rewritten idempotently | Content matches plan exactly, mtime Aug 17 05:20 (fresh) | yes |
| `40-ai-dala-infra.conf` created | Content matches fleet-standard body verbatim, mtime Aug 17 05:22 (fresh) | yes |
| `40-ssh-hardening.conf` + `.bak` sibling removed, backed up | Absent from `sshd_config.d/`; `40-ssh-hardening.conf.removed` present in backup dir, 249 bytes | yes |
| `/var/backups/pre-T0134.20260817T051919Z/` full backup created | Present, contains sshd_config, host keys, moduli, sshd_config.d/ | yes |
| `/etc/apt/keyrings/docker.gpg`, `/etc/apt/sources.list.d/docker.list` created | Both present, correct content | yes |
| Docker packages installed (docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin) | `docker-ce` and `docker-compose-plugin` confirmed `ii`; `docker --version`/`docker compose version` implicitly confirmed via hello-world + compose functioning | yes |
| `/etc/ufw/after.rules` NOT modified (3.12 egress passed) | `grep -c 'T-0134'` → 0; ufw status shows only pre-existing 22/80/443 Anywhere rules | yes |
| Hetzner Cloud Firewall: 1 rule -> 3 rules (22/80/443, all world-open) | Confirmed via independent live GET | yes |
| `ssh.service` reloaded; `docker.service`+socket+containerd started/enabled | `systemctl is-active docker` = active, `is-enabled` = enabled; fresh SSH session succeeds post-reload (proves reload didn't break the service) | yes |

### Independent assessment of the two flagged informational items

1. **2.6/2.7 heredoc/SSH local-hang, "independently re-verified" claim.** I independently re-read both drop-in files fresh in this validation pass (not reusing the executor's captured output): `40-disable-password.conf` contains exactly `PasswordAuthentication no` / `KbdInteractiveAuthentication no`; `40-ai-dala-infra.conf` contains the full fleet-standard directive block verbatim, matching the plan's 2.7 body exactly, including the KexAlgorithms/Ciphers/MACs lines. `stat` mtimes for both files (Aug 17 05:20 and 05:22 UTC) are consistent with the executor's claimed execution window and are within the same run, not stale leftovers from a different attempt. This independently corroborates the executor's claim that the underlying SSH/tee commands completed successfully on the host despite the local Bash-tool-side hang — I did not merely trust the executor's report, I re-read the files myself in this pass. Assessment: informational item stands as reported, not a functional problem.

2. **4.4 TCP-reachability timing signature (~13s instead of "immediate").** My own independent probe (run fresh, minutes after the executor's) reproduced the same pattern: ports 80/443 both `TcpTestSucceeded: False` with completion times of ~13.8s and ~11.9s respectively — close to the executor's reported ~13.4s/~13.1s, and consistent with a stable, real phenomenon rather than a transient blip. This is markedly faster than the plan's 0.7 pre-change baseline (~31-35s) but not the "immediate TCP RST" the plan predicted. Port 22 reachability (`TcpTestSucceeded: True`) and the API-level rule state (independently confirmed via live GET, 3 rules exactly as designed) are both correct, which are the two facts the plan's actual Phase 4 rollback trigger depends on ("SSH no longer reachable, or set_rules returns an error" — neither occurred). Assessment: informational item stands as reported; the residual ~12s is plausibly explained by `Test-NetConnection`'s bundled ICMP-ping attempt (also visible as a warning in my own raw probe output) and/or normal TCP connect/RTT variance, not evidence of an incomplete firewall change.

## Issues / risks

- None found that would change the verdict. All designer-specified "must pass" checks passed under independent re-observation, not merely by trusting the executor's report.
- Carried forward from the executor's own report (factual, not new): port 22 remains open to `0.0.0.0/0`+`::/0` on the Hetzner Cloud Firewall by explicit user instruction; `viktor_d`/`binali_r` no longer have working SSH access (locked, not deleted) by explicit user instruction. Both independently reconfirmed as designed, not defects.
- No external probe is possible for `viktor_d`/`binali_r` login denial (no key on the management workstation for either identity) — same documented limitation the designer and executor both noted; on-host state (expiry + lock) is the authoritative check and was independently reconfirmed here.

## Open questions (optional)

None. All checks in the designer's Verification (for step 07) block were independently re-run against live state (host + Hetzner API) and passed. The 4.4 timing discrepancy and the 2.6/2.7 local-tool hang are both reproducible/corroborable rather than one-off transient observations, so neither is marked inconclusive.
