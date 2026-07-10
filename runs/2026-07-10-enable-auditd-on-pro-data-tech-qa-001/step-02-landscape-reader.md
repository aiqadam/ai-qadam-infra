---
step: 02
agent: landscape-reader
run_id: 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
task_id: T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
verdict: PASS
inputs_read:
  - runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md
  - landscape/README.md
  - landscape/hosts/hetzner-prod.md (cross-check: auditd status on sibling)
  - landscape/hosts/ubuntu-16gb-nbg1-1.md (cross-check: auditd status on sibling)
  - /memories/repo/ (no auditd-specific notes; only UFW/sshd/gitea items)
---

# Step 02 — landscape-reader

## Current state (relevant to T-0096)

### OS + kernel

- **OS:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`, `ID=ubuntu`).
- **Kernel:** `7.0.0-27-generic` — advanced from `7.0.0-14-generic` by T-0099 reboot 2026-07-10T06:14:28Z → 06:21:12Z (downtime 6m 44s, all 9 V-checks PASSED). The previous kernel is retained as GRUB fallback. The T-0088 deferral rationale (kernel 7.x + Ubuntu 26.04 auditd compat) is no longer applicable per the user's 2026-07-10 promotion.
- **Virtualization:** KVM / QEMU (qemu-guest-agent.service active).
- **Architecture:** x86_64 (assumed from kernel string — Ubuntu 26.04 stock).
- **Reboot state:** `/var/run/reboot-required` is **absent** post-reboot — clean boot, no pending reboot.
- _source: `landscape/hosts/pro-data-tech-qa.md` (`## Hardware & OS`)_

### Existing security tooling

All active + enabled as of 2026-07-08 hardening chain; not to be perturbed by this run.

- **sshd (T-0093):** hardened — `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin prohibit-password`, `AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`; hardened KEX/Ciphers/MACs (no SHA-1, no CBC/3DES/RC4). Drop-ins at `/etc/ssh/sshd_config.d/40-disable-password.conf` + `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf`. Cloud-init `60-cloudimg-settings.conf` preserved (silently overridden by first-wins semantics).
- **UFW (T-0094 + T-0090 reconciliation):** active + enabled. `Default: deny (incoming), allow (outgoing), allow (routed)`; `DEFAULT_FORWARD_POLICY="ACCEPT"` (flipped DROP→ACCEPT 2026-07-08 by T-0090 Phase A2); `IPV6=yes`. Inbound rules: 22/tcp (v4+v6) from any source per user decision 2026-07-08 (no source-IP allowlist). Backups: `/etc/default/ufw.bak`, `/tmp/ufw.pre-T0094.20260708T173602Z.bak/`, `/etc/default/ufw.pre-T0090.20260708T184046Z.bak`.
- **fail2ban (T-0095):** 1.1.0-9 installed; sshd jail enabled (`banaction=iptables-multiport`, `maxretry=3`, `bantime=600s`, `findtime=600s`, `ignoreip=127.0.0.1/8 ::1 178.89.57.135`, `logpath=/var/log/auth.log` with journalmatch fallback). Backup at `/etc/fail2ban.pre-T0095.20260708T182109Z.bak/`. systemd `fail2ban.service` is active + enabled.
- **AppArmor:** loaded; **179 profiles loaded, 103 in enforce mode** (stock Ubuntu 26.04 default; first two enforced: `/usr/bin/man`, `/usr/lib/snapd/snap-confine`). Orthogonal to auditd — not in scope, not modified by this run.
- **Operator users (T-0097):** `tvolodi` (uid 1001), `viktor_d` (uid 1002), `binali_r` (uid 1003) — members of `sshusers`+`sudo`+`users`+`docker` groups; NOPASSWD sudo via `/etc/sudoers.d/90-<user>` (0440, root:root). Root key-only via provider break-glass key `rsa-key-20260707`.
- _source: `landscape/hosts/pro-data-tech-qa.md` (`## Security posture`, `## Access`, `## What runs here`)_

### auditd precedent

- **None in this repo.** No managed host has auditd installed today.
  - `pro-data-tech-qa` (this host): **NOT installed.** T-0096 is the first auditd install for this host; originally deferred per T-0088 (dangling reference), deferral rationale overridden by user on 2026-07-10.
  - `hetzner-prod`: **NOT installed.** T-0047 (`auditd on hetzner-prod`) is itself an `observation` / deferred, has never been promoted to execution. Sibling landscape confirms: "auditd NOT installed" in `## Security posture`.
  - `ubuntu-16gb-nbg1-1`: **NOT installed** (T-0082 host; out of scope for the 2026-06-27 discovery run, no auditd task tracked).
- **AppArmor is the project's current MAC baseline** (not auditd). The 103 enforced AppArmor profiles cover most of the use-cases auditd is normally used for here.
- **Repository memory `/memories/repo/`:** no auditd-specific notes (only UFW, sshd, gitea, ssh-quoting hazards).
- **No precedent for a "sane ruleset" file** in this repo, in `/etc/audit/rules.d/audit.rules` on any host, or in any prior run handoff. The solution-designer must design the ruleset from scratch.
- _sources: `landscape/hosts/hetzner-prod.md` (line 58: "auditd NOT installed"); `landscape/hosts/pro-data-tech-qa.md` (`## Security posture` auditd entry); `landscape/hosts/ubuntu-16gb-nbg1-1.md` (no auditd mention at all); `tasks/T-0047` (observation, deferred)_

### Backups convention

Per-task snapshot directories under `/var/backups/`, named `<thing>.pre-T<NNNN>.<YYYYMMDDTHHMMSSZ>.bak[/]` (timestamped UTC, atomic directory or single-file). Existing examples on this host:

- **Most recent precedent (still on disk):** `/var/backups/pre-T0099.20260710T061200Z/` — contains:
  - `pg_dump` (405 B)
  - `etc-snapshot.tar.gz` (148 453 B)
  - `pre-reboot-state.txt` (5924 B)
  - root:root, mode 0750/0640.
- **fail2ban pre-change:** `/etc/fail2ban.pre-T0095.20260708T182109Z.bak/`
- **sshd pre-change:** `/tmp/sshd_config_d.pre-T0093.20260708T165653Z.bak/` (under `/tmp`, not `/var/backups/` — legacy convention drift; the fail2ban/T-0099 examples moved to `/var/backups/`)
- **UFW pre-change:** `/etc/default/ufw.bak` (mode 0644, root:root, mtime `Dec 6 2025`, the cloud-init default), `/tmp/ufw.pre-T0094.20260708T173602Z.bak/`, `/etc/default/ufw.pre-T0090.20260708T184046Z.bak`

**Convention for this run:** snapshot of `/etc/audit/` (which is **non-existent** today — `auditd` not installed) plus a placeholder for future diffs. Path: `/var/backups/pre-T0096.<TIMESTAMP>/`. The solution-designer should follow the `/var/backups/` + UTC timestamp pattern used by T-0099.

The project's "do not auto-clean operational artifacts" rule applies — these backups stay until housekeeping (T-0098) lands.

_ sources: `landscape/hosts/pro-data-tech-qa.md` (`## Backups`, T-0099 entry); `landscape/README.md` (Backups & storage policy)_

### Docker / containers

- **Docker engine:** 29.6.1 (build `8900f1d`); **Docker Compose plugin:** v5.3.1; **runtime:** containerd (default for Docker 29.x on Ubuntu 26.04).
- **systemd:** `docker.service` enabled + active.
- **Compose project `ai-qadam-test`** (only one running):
  - Compose file: `/var/www/ai-qadam-test/docker-compose.yml` (mode 644, owner `tvolodi:tvolodi`).
  - Env file: `/var/www/ai-qadam-test/.env` (mode 600, owner `tvolodi:tvolodi`) — contains `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB`.
- **Container `ai-qadam-test-db-1`** (the only running container on this host):
  - Image: `pgvector/pgvector:pg16`
  - Host port: `127.0.0.1:3112` → `5432` (TCP, loopback only — NOT exposed publicly).
  - Healthcheck: `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}`, 5s interval / 3s timeout / 10 retries. Status `(healthy)` (post-T-0099 reboot).
  - Volume: `ai-qadam-test_ai_qadam_test_pgdata` (named, mounted at `/var/lib/postgresql/data` inside container).
  - Network: `ai-qadam-test_default` (Compose-default bridge).
- **No app container yet** (`ai-qadam-test-app-*` deferred to T-0090a). No nginx yet (T-0090a). No other Compose projects.
- **Auditd implication:** auditd's namespace-isolation awareness is kernel-level (netlink / kernel logs), not Docker-aware by default. The executor may want to add a `-w /var/www/ai-qadam-test/docker-compose.yml` watch (or skip — out of project scope for "sane ruleset"). **Docker itself does not need auditd; only the operator actions on the host do.**
- _source: `landscape/hosts/pro-data-tech-qa.md` (`## AI Qadam QA stack`); `landscape/services.md` (`## pro-data-tech-qa`)_

### Logs

- **rsyslog:** `rsyslog.service` active + enabled (stock Ubuntu). Standard log directory `/var/log/` is in use — `/var/log/auth.log` is the fail2ban logpath, so it's reliably populated with sshd auth events.
- **systemd-journald:** `systemd-journald.service` active + enabled (stock). `journalctl` works for any unit, including `auditd.service` post-install.
- **No custom log aggregation / no remote shipping.** Auditd's stock `log_file = /var/log/audit/audit.log` (Ubuntu 26.04 default) will be the audit trail's home. The fail2ban journalmatch fallback demonstrates systemd journal is the canonical event source for security tools on this host.
- **Per project hard rule (README § Backups & storage policy):** no off-site storage, no audit log shipping, no SIEM — audit logs stay on local disk. Stock Ubuntu `auditd` package's `logrotate` integration (default `/etc/logrotate.d/auditd`) is sufficient; no custom rotation policy in scope.
- _source: `landscape/hosts/pro-data-tech-qa.md` (fail2ban logpath row + rsyslog.service row); `landscape/README.md` (Backups & storage policy)_

### APT posture

- **`unattended-upgrades`** active + enabled, daily cycle. `Allowed-Origins`: `security`, `ESM apps`, `ESM infra` only.
- **APT::Periodic::Update-Package-Lists=1**, **APT::Periodic::Unattended-Upgrade=1** in `/etc/apt/apt.conf.d/20auto-upgrades`.
- **Pending upgrades (post-T-0099):** **4 phased-rollout packages** (`fwupd` 2.1.1-1ubuntu3→2.1.1-1ubuntu3.1, `libfwupd3` matching, `python3-software-properties` 0.120→0.120.1, `software-properties-common` matching). Flagged "Not upgrading yet due to phasing" by Ubuntu's phased-update mechanism — **not actionable today, not blocking** T-0096.
- **`apt install auditd` will pull in** `auditd` + default Depends (`audispd-plugins` likely; possibly `libauparse0` etc.). The task body says `audispd-plugins` may be installed but must NOT be configured (no remote dispatchers / ausearch-to-siem out of scope).
- **Sources:** deb822 at `/etc/apt/sources.list.d/ubuntu.sources` (Ubuntu 26.04 stock). No third-party PPAs in play — the install will be from the official Ubuntu archive (canonical "resolute" pocket).
- _source: `landscape/hosts/pro-data-tech-qa.md` (`## apt posture`); `landscape/services.md` (`## pro-data-tech-qa` → `### Apt posture`)_

## Gaps for the solution-designer

The landscape does **not** document the following facts; they must either be discovered live by the executor or designed from first principles by the solution-designer:

1. **No in-repo "sane ruleset" precedent.** Step 04 must design `/etc/audit/rules.d/audit.rules` from scratch. Suggested minimum bar (carried from step 01):
   - Defaults: `-b 8192` (buffer), `-f 1` (failure mode: printk), `-e 2` (immutable at end-of-ruleset).
   - At least one rule per event class needed by ausearch acceptance criterion 4: `USER_LOGIN`, `USER_AUTH`, `EXECVE`.
   - Optional project-relevant additions: auth file watches on `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/sudoers.d/`; privileged execve on `/usr/bin/sudo`, `/usr/bin/su`.
   - Keep the file simple and project-readable (file header comment with rationale + date + run_id).
2. **No audit log path documented for this host.** Once installed, `/var/log/audit/audit.log` is the stock Ubuntu default; `/etc/audit/auditd.conf` `log_file` and `log_format` defaults are stock (`log_format=ENRICHED`, `log_group=adm`, `mode 0640`). Step 08 (landscape-updater) should record the actual log path after install lands.
3. **No auditd ↔ Docker interaction analysis in the landscape.** Stock `auditd` records host-kernel audit events; Docker container events are not in audit by default unless you add `-w` watches on `/var/lib/docker/` (out of scope for "sane ruleset"). The executor should not add Docker-specific rules unless the user asks.
4. **No information about whether `audispd-plugins` is needed in the ruleset.** Default Ubuntu install leaves `audisp-remote.conf` and `au-remote.conf` untouched (no remote dispatch). Solution-designer should explicitly state "no dispatcher configuration" and validator should confirm `/etc/audisp/` and `/etc/audisp/plugins.d/` are stock post-install.
5. **First-time auditd install risk (T-0088 class).** The landscape does not contain data on whether the audit subsystem on this exact `7.0.0-27-generic` kernel patch level has known issues. Mitigation: executor must verify `systemctl status auditd` + `journalctl -u auditd -n 50` immediately after first start; the step-01 risk analysis already calls this out. No live discovery needed up front — verification during install is sufficient.
6. **No logrotate policy documented for audit logs.** Stock Ubuntu ships `/etc/logrotate.d/auditd` (rotates weekly, retains 4). Acceptable for "sane ruleset"; no custom rotation in scope. Solution-designer should note this in the ruleset header so a future T-0098 housekeeping run knows it was intentional.
7. **No remote time / clock-drift audit signal.** `chrony.service` is active (per landscape), so event timestamps should be reliable. Worth mentioning in the ruleset header but not requiring action.

## Issues / risks

- **T-0088 reference is dangling.** The task body cites a T-0088 precedent that no longer exists as a file (lost in the 2026-07-07 secrets-inventory scrub per T-0091). The deferral rationale is unsupported by a current document. The user has explicitly authorized execution on 2026-07-10, so this is **not** a blocker for step 02 — flagged for context only.
- **Landscape `last_verified: 2026-07-10` for `pro-data-tech-qa.md`** is 0 days old — fully fresh, no staleness flag. The file's `## Security posture` confirms "auditd NOT installed" as of last verification.
- **Landscape `last_verified: 2026-07-10` for `services.md`** is also 0 days old — fresh.
- **4 phased-rollout packages** remain in the upgradable queue. They will NOT block `apt install auditd` (auditd is a different package entirely), but if the unattended-upgrades cycle runs mid-install it could trigger a transient apt lock — solution-designer should instruct the executor to use `apt install -y auditd` directly and tolerate the standard "waiting for lock" wait (or use `apt-get install -y --no-install-recommends auditd audispd-plugins` for explicit control).
- **Audit log file ownership** (root:root mode 0640, group `adm`) — stock behavior; ausearch via `sudo` sidesteps any permission issue. If any non-root operator wants to read `/var/log/audit/audit.log` later, that user must be in `adm` group. Out of scope for this run.
- **Reboot not required.** The task body does not require a reboot. `systemctl enable --now auditd` should bring it active + enabled without a reboot.

## Open questions (optional)

None — the task is unambiguous. The solution-designer will be able to write a ruleset using the suggested minimum bar from step 01; the executor will handle the install + reload + ausearch verification per the step-01 acceptance criteria; the landscape-updater (step 08) will close out the documentation diff.

`verdict: PASS` — landscape is loaded, summary is written, gaps are documented. No `BLOCKED` warranted.