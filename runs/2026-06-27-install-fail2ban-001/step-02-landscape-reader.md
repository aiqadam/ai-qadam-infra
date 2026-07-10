---
run_id: 2026-06-27-install-fail2ban-001
step: "02"
agent: landscape-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-install-fail2ban-001/step-01-task-reader.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - landscape/hosts/hetzner-prod.md
  - landscape/README.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-06-27-discovery-host-001/step-02-landscape-reader.md
  - runs/2026-06-27-configure-ufw-001/step-02-landscape-reader.md
  - runs/2026-05-12-install-fail2ban-001/step-06-executor-infra.md
  - tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — confirm blast radius/reversibility claims in T-0084; surface the Ubuntu 26.04 apt-availability + iptables-backend gap as a known executor-side verification item; surface the management-workstation-IP gap as a known executor-side live-discovery item.
---

## Summary

Landscape is sufficient to design fail2ban-with-sshd-jail on `ubuntu-16gb-nbg1-1`. The host is a freshly provisioned Ubuntu 26.04 cloud image with UFW active (T-0083 done 2026-06-27, run `2026-06-27-configure-ufw-001`), no Docker, no fail2ban, and only port 22 exposed to the internet. The reference pattern (T-0005 on `hetzner-prod`, Ubuntu 24.04) is well documented and the only delta is the Ubuntu 26.04 apt-package + iptables-backend question, which is a live executor-side verification item, not a landscape-level blocker. The management workstation outbound IP is NOT yet recorded for this new host and the task explicitly forbids hardcoding the prod value (`5.250.151.158`) — this is a known gap to be filled by `curl https://ifconfig.me` from the management workstation before the executor writes `ignoreip`.

## Details

### Relevant facts (sourced from landscape)

#### Target host — current state (`landscape/hosts/ubuntu-16gb-nbg1-1.md`, status: populated, last_verified: 2026-06-27)

- **Identity:** `ubuntu-16gb-nbg1-1`, Hetzner server id `145542849`, project id `15130993` ("ai-qadam"), CX43 (8 vCPU / 16 GiB / 150 GiB disk), Nuremberg (`nbg1`).
- **Network:** IPv4 `46.225.239.60`, IPv6 `2a01:4f8:1c1c:5959::/64` — both stacks available.
- **OS:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`). **This is NOT 24.04 like prod.**
- **Kernel:** `7.0.0-22-generic` (`#22-Ubuntu SMP PREEMPT_DYNAMIC Mon May 25 15:54:34 UTC 2026 x86_64`).
- **Role:** `unassigned` — no Docker, no nginx, no application data. Fresh cloud image.
- **Sudo user:** `tvolodi` (uid 1000, groups `sudo` `users`), passwordless via `/etc/sudoers.d/90-tvolodi` (mode 0440, owner root:root, mtime 2026-06-27 04:46). Sudo is verified working.
- **SSH daemon posture (2026-06-27, sshd -T effective):** cloud-image defaults — `Port 22`, `PermitRootLogin yes`, **`PasswordAuthentication yes`** ⚠, `PubkeyAuthentication yes`, `MaxAuthTries 6`, `LoginGraceTime 120`, `UseDNS no`. No project hardening yet (no `40-disable-password.conf`, no `AllowUsers`/`AllowGroups`). **fail2ban not installed.** AppArmor loaded (180 profiles, 104 enforce). auditd not installed.
- **sshd drop-ins:** only `50-cloud-init.conf` (sets `PasswordAuthentication yes`). No project-managed drop-ins.
- **UFW:** active and enabled at boot (as of 2026-06-27, run `2026-06-27-configure-ufw-001` / T-0083). Defaults: deny incoming, allow outgoing, `DEFAULT_FORWARD_POLICY="ACCEPT"` (Docker parity; no IP forwarding currently enabled, so FORWARD policy renders as `disabled (routed)` in `ufw status verbose` — correct UFW behavior).
- **UFW ruleset:** allow 22/tcp (v4+v6), allow 80/tcp (v4+v6), allow 443/tcp (v4+v6). Six rules total.
- **TCP listeners on 0.0.0.0:** only port 22 (`sshd`). No 80/443/nginx listener exists on the host (UFW allows, host stack RSTs — confirmed by external probe). Port 21 returns timeout-dropped (UFW drops). Confirms UFW is actively filtering.
- **Docker:** **not installed.** No compose projects on disk. No `iptables -L` Docker chains.
- **TCP listeners on 127.0.0.1 only:** `127.0.0.53:53` and `127.0.0.54:54` (systemd-resolved stub). Not affected by fail2ban.
- **iptables backend / nftables:** **NOT explicitly captured during discovery.** The landscape notes `iptables` / `ip6tables` chains at default ACCEPT (pre-UFW state) and `nft` binary present but empty ruleset — but does not record which iptables backend (`iptables-nft` vs `iptables-legacy`) is active. This is a gap; see "Gaps requiring live discovery" below.
- **SSH access from management workstation:** SSH config alias `Host ubuntu-16gb-nbg1-1` in `C:\Users\tvolo\.ssh\config`. Project key `C:\Users\tvolo\.ssh\ai-dala-infra` (ed25519, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`, last rotated 2026-05-12, recorded in `landscape/secrets-inventory.md`). Key is already deployed to `/home/tvolodi/.ssh/authorized_keys`.
- **Management workstation outbound IP for the new host:** **NOT RECORDED** anywhere in the landscape. The only IP recorded in landscape files is `5.250.151.158`, which appears in `landscape/hosts/hetzner-prod.md` (`landscape/hosts/hetzner-prod.md`'s "SSH hardening tooling on host" line: `fail2ban ... ignoreip includes 5.250.151.158`). This is the **prod workstation IP**, not necessarily the new host's. **T-0084 explicitly forbids hardcoding `5.250.151.158`** without verifying the current outbound IP from the workstation that will SSH into the new host. Gap; see below.
- **Project tag:** Hetzner project name frontmatter is `ai-qadam` (canonical), project id `15130993`. Server type CX43. Token for Hetzner API access to this project: `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` at `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` (out of scope for fail2ban install — fail2ban is purely on-host).

#### T-0005 reference pattern — exact values to mirror (`runs/2026-05-12-install-fail2ban-001/step-06-executor-infra.md`, sourced from `landscape/hosts/hetzner-prod.md` and the T-0005 design)

- **Apt package name on Ubuntu 24.04:** `fail2ban` (1.0.2-3ubuntu0.1). Installs with `python3-pyasyncore`, `python3-pyinotify`, `whois` as automatic dependencies. **Ubuntu 26.04 package availability was NOT captured during discovery** — executor must verify.
- **iptables backend on Ubuntu 24.04:** `iptables v1.8.10 (nf_tables)` with both `/usr/sbin/iptables-legacy` and `/usr/sbin/iptables-nft` present via `update-alternatives`. Proceeded with `banaction = iptables-multiport`. **Ubuntu 26.04 backend was NOT captured** — executor must re-verify (and the prod result is not a safe prediction).
- **Jail config (`/etc/fail2ban/jail.d/sshd.local` on hetzner-prod):**
  ```ini
  [sshd]
  enabled  = true
  port     = ssh
  filter   = sshd
  maxretry = 3
  bantime  = 600
  findtime = 600
  ignoreip = 127.0.0.1/8 ::1 5.250.151.158
  banaction = iptables-multiport
  ```
- **Service enable:** `systemctl enable fail2ban` (creates symlink `/etc/systemd/system/multi-user.target.wants/fail2ban.service → /usr/lib/systemd/system/fail2ban.service`) + `systemctl restart fail2ban`.
- **Verification commands (proven on prod):**
  - `sudo systemctl is-active fail2ban` → `active`
  - `sudo fail2ban-client status sshd` → shows `Currently failed`, `Total failed`, `Currently banned`, `Total banned`, `Banned IP list`.
- **Live behavior on prod immediately post-install:** 4 IPs already banned at T+0 (journal-history import). Expected on the new host as well — internet-facing port 22 attracts scanners within minutes.
- **Quirk noted on prod install:** apt install produced several `SyntaxWarning: invalid escape sequence` from fail2ban's own test files. Benign upstream packaging issue, not runtime error.

#### Cross-reference for landscape-update (step 08)

- **Per-task `affects:`** list: `landscape/hosts/ubuntu-16gb-nbg1-1.md` (security tools section) + `landscape/services.md`. The exec of `landscape/hosts/hetzner-prod.md` 2026-05-12 change-log row reads: `2026-05-12 | 2026-05-12-install-fail2ban-001 | Installed fail2ban 1.0.2-3ubuntu0.1; sshd jail enabled with maxretry=3, bantime=600s, findtime=600s, ignoreip includes management IP 5.250.151.158, banaction=iptables-multiport, config at /etc/fail2ban/jail.d/sshd.local. Service active and enabled at boot.` — same template applies to the new host's file with the IP substituted.
- **Security tools section in `landscape/hosts/ubuntu-16gb-nbg1-1.md`** currently reads: `**SSH hardening tooling on host:** **fail2ban not installed**. AppArmor loaded with 180 profiles (104 in enforce mode — Ubuntu default). **auditd not installed**.` — this sentence gets a fail2ban clause appended at step 08.

#### What the landscape does NOT capture (precise gaps)

- **The exact `apt-cache policy fail2ban` output for Ubuntu 26.04 repos** — apt repository availability, candidate version, and `apt update` freshness on the new host.
- **The active iptables backend** (`iptables-nft` vs `iptables-legacy`) on the new host. Prod confirmed `nf_tables` shim; not a safe assumption for 26.04.
- **The management workstation outbound IP** for use in `ignoreip`. NOT in any landscape file. Task T-0084 says "verified at run time" via `curl https://ifconfig.me` — this is a **user-side verification**, NOT an executor-side command. Executor should prompt the user (or read the value from a user-provided source) before writing the jail file.

### Stale or stub files encountered

- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `last_verified: 2026-06-27`, `status: populated`. **Fresh (today).** Authoritative for this run.
- `landscape/services.md` — `last_verified: 2026-06-27`, `status: populated`. **Fresh (today).** Per-host section for `ubuntu-16gb-nbg1-1` exists with the expected "no Docker / no nginx / stock cloud-image systemd units" content. Step 08 will add a fail2ban row to the systemd-units table.
- `landscape/secrets-inventory.md` — `last_verified: 2026-05-26`, `status: in-progress`. **32 days old — STALE** (over the 30-day threshold). Read-only for this run. The SSH key entry's current state (`last_rotated: 2026-05-12`, fingerprint unchanged) is corroborated by the target host's landscape file which references the same fingerprint. No design risk. Flagged for a future secrets-inventory refresh run.
- `landscape/hosts/hetzner-prod.md` — `last_verified: 2026-05-26`, `status: populated`. **32 days old — STALE.** Read-only reference for the T-0005 pattern (immutable history, including the fail2ban install line). No design risk. Flagged for a future landscape-updater audit.
- `landscape/README.md` — no `last_verified` field; meta-file, not applicable.

### Gaps requiring live discovery (downstream: executor must fill)

1. **Ubuntu 26.04 apt repository availability of `fail2ban` package.** Step 04 solution-designer cannot answer this from landscape alone. Executor (step 06) must run `apt-get update` and `apt-cache policy fail2ban` first; if no candidate is found, fail safely and report — the task is then BLOCKED by package availability, not landscape.
2. **Active iptables backend on the new host.** Executor (step 06) must run `iptables -V` and `update-alternatives --list iptables` (and the same for `ip6tables`) before selecting `banaction`. The prod record shows `nf_tables` (1.8.10) but Ubuntu 26.04 may default to a different backend or version.
3. **Management workstation outbound IP for the new host.** **NOT in any landscape file.** This is a **user-supplied value**, not a host-side discovery. The task explicitly states "run `curl https://ifconfig.me` from workstation and verify". Executor (step 06) MUST either:
   - (a) prompt the user at run start to provide the value, OR
   - (b) instruct the user to run `curl https://ifconfig.me` themselves and confirm before the executor writes the jail file.
   Hardcoding `5.250.151.158` without confirmation is explicitly forbidden by the task.
4. **fail2ban post-install side effects on the active UFW.** fail2ban inserts iptables rules via its banaction chain. UFW is currently active with allow-22 rules. The executor should sanity-check `iptables -L -n` (or `nft list ruleset`) after enabling the service to confirm both layers coexist without conflict. (Same risk was flagged for step 02 of `2026-06-27-configure-ufw-001` — currently unverified.)

### Issues / risks

- **Ubuntu 26.04 is newer than prod's 24.04.** fail2ban package name, default backend (iptables vs nftables), and shipped jail defaults may differ. Risk: low (Ubuntu major-version apt behavior is generally stable), but the task Notes explicitly flag this and require the executor to verify before installing.
- **Hardcoded prod workstation IP risk.** T-0084 explicitly forbids copying `5.250.151.158` blindly. Step 02 surfaces this as Gap #3 above.
- **Layering with T-0083.** UFW is already active (deny-incoming + allow 22/80/443). fail2ban in `jail.local` adds its own iptables/nftables rules via `banaction`. On prod this worked cleanly because fail2ban inserts rules above UFW's chains by convention. The executor should verify post-install that UFW's allow-22 rules and fail2ban's ban rules coexist (UFW must still allow legitimate SSH from `ignoreip`; fail2ban bans IPs that exceed `maxretry` within `findtime`).
- **`PasswordAuthentication yes` is still on.** Unlike prod (which had T-0007 disable password auth before T-0005 fail2ban), the new host has `PasswordAuthentication yes` (cloud-image default). fail2ban is therefore **more valuable here than it was on prod**. Step 04 should NOT touch sshd config in this run (out of scope for T-0084); a separate "disable ssh password auth" task is the natural follow-on (mirrors T-0007 for prod).
- **`landscape/secrets-inventory.md` is 32 days old** (just over the 30-day stale threshold). Not a blocker for this run (file is read-only reference); flag for future refresh.
- **`gitea:admin-password` row in `landscape/secrets-inventory.md` still contains the literal password value** (`eT96ulleryIpd38VJeQNRGm3lQ3qcUO3`). Pre-existing drift; out of scope; surface as low-priority cleanup item.

### Open questions

- (For step 04 solution-designer) Which `banaction` should the design commit to? Recommendation: `iptables-multiport` (same as prod) IF the executor's backend probe returns `iptables-nft` or `nf_tables`. If 26.04 ships `iptables-legacy` only, the design should adjust. Either way, the design should NOT hardcode the banaction without a step-06 verification step.
- (For step 06 executor-infra) Workstation IP for `ignoreip` must be confirmed **before** writing `/etc/fail2ban/jail.d/sshd.local`. Suggested approach: include a step-0 "confirm workstation IP" gate that explicitly asks the user for the value or instructs them to run `curl https://ifconfig.me` and paste the result. If the user is unreachable / non-interactive, BLOCKED.
- (For step 08 landscape-updater) The change-log entry for `landscape/hosts/ubuntu-16gb-nbg1-1.md` should mirror the prod format exactly, with the workstation IP substituted and the package version from `dpkg -l fail2ban | grep ^ii` substituted. The systemd-units-of-note table in `landscape/services.md` should add a `fail2ban.service` row under the `ubuntu-16gb-nbg1-1` section. The "Security tools" sentence in the host file gets a fail2ban clause appended.

## Verdict rationale

**PASS.** Landscape is sufficient. The host is well-documented (populated today), the reference pattern (T-0005 on prod) is reproducible from landscape + closed-run handoffs, and all known unknowns are precisely characterized as live-discovery or user-supply items that step 06 owns. None of the gaps make safe design impossible — they are gating verifications the executor must perform (apt availability, iptables backend, workstation IP). No `BLOCKED` condition.