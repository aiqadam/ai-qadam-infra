---
step: 02
agent: landscape-reader
run_id: 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001
task_id: T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa
verdict: PASS
inputs_read:
  - runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-06-executor-discovery.md
---

# Step 02 — landscape-reader

## Current state (relevant to T-0099)

### Host

- **Public IPv4:** `95.46.211.230` (provider: pro-data.tech — NOT Hetzner; no Hetzner API, no Hetzner Cloud Firewall, no Hetzner Backups, no `firewall-1` analogue)
- **Hostname:** `drkkrgm-qa-instance` (provider-assigned)
- **OS:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`)
- **Kernel running:** `7.0.0-14-generic` (`#14-Ubuntu SMP PREEMPT_DYNAMIC Mon Apr 13 11:09:53 UTC 2026 x86_64`) — landscape frontmatter `kernel: 7.0.0-14-generic` reconfirmed by audit probe B (2026-07-10 02:13 UTC; `uptime 2 days, 14:59`).
- **Virtualization:** KVM / QEMU (pro-data.tech; `qemu-guest-agent.service` active). Reboot via `systemctl reboot` only — no provider control-plane recovery documented.
- **Disk:** 145 GB `/dev/sda1` mounted on `/` (2.9 GB used, 142 GB free, ample headroom for `apt full-upgrade`); 989 MB `/boot` (17% used — must remain under capacity; new kernel image lands here); 105 MB `/boot/efi` (7% used).
- **Memory:** 15 GiB total, no swap; 8 vCPU.
- **No on-site or off-site backup infrastructure** — this is a key constraint for the reboot's blast radius (see "Backups in place" below).

### Access

- **Workstation SSH alias:** `pro-data-tech-qa` in `C:\Users\tvolo\.ssh\config`. **The alias sets `User tvolodi`**, so `ssh pro-data-tech-qa` (or `ssh -i ai-dala-infra pro-data-tech-qa`) lands as `tvolodi`; with the operator provisioned under T-0097, this is now the preferred identity. For root operations, the executor should use the explicit form `ssh -i <key> root@95.46.211.230` (this was how prior runs accessed the host).
- **Operator users (post-T-0097):**
  - `tvolodi` (uid 1001) — workstation-validated live SSH; groups `tvolodi, sudo, users, sshusers, docker`; NOPASSWD sudo via `/etc/sudoers.d/90-tvolodi` (mode 0440 root:root, `visudo -c` clean). **Preferred everyday operator.**
  - `viktor_d` (uid 1002), `binali_r` (uid 1003) — same groups/permissions; server-side pubkey parse confirmed by audit probe C; live SSH deferred to each operator's own workstation.
- **Break-glass root access:** `root@95.46.211.230` via provider key (`C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` — OpenSSH-format RSA-2048 despite the misleading `.ppk` extension; fingerprint `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0`). Public key has comment `rsa-key-20260707` and is the **only** line in `/root/.ssh/authorized_keys` (mode 600 root:root; confirmed unchanged by audit probe C). `PermitRootLogin prohibit-password` keeps password auth off; root's only login path is the provider key as break-glass.
- **Sudo mode for operators:** NOPASSWD (drop-in files `/etc/sudoers.d/90-{tvolodi,viktor-d,binali-r}` each `<user> ALL=(ALL) NOPASSWD: ALL`). For root access, `sudo -n true` returns `SUDO_OK`.
- **sshd hardening (T-0093, intact):** `Port 22`, `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PubkeyAuthentication yes`, `AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`, `UseDNS no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`; KEX/Ciphers/MACs tightened (no SHA-1, no CBC/3DES/RC4). Drop-ins: `/etc/ssh/sshd_config.d/40-disable-password.conf` + `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (project) sort before `60-cloudimg-settings.conf` (cloud-init, stale `PasswordAuthentication yes` which is overridden by first-wins). Backups preserved at `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/`. Audit probe C verified all 21/21 checks still pass — **no drift**.
- **Current logged-in sessions at audit time:** 1 active session from `178.89.57.135` (management workstation outbound IP); audit probe U `uptime 2 days, 14:59` indicates host has been up since ~2026-07-07 11:20 UTC (cloud-init bootstrap).

### Container state (the only container running here)

| Container | Image | Host port → container | Health | Restart policy | Volume |
|---|---|---|---|---|---|
| `ai-qadam-test-db-1` | `pgvector/pgvector:pg16` | `127.0.0.1:3112` → `5432` (TCP, loopback only) | `(healthy)` (healthcheck `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}`, 5s interval / 3s timeout / 10 retries) | `unless-stopped` (Compose default) | `ai-qadam-test_ai_qadam_test_pgdata` named volume mounted at `/var/lib/postgresql/data` inside the container (rw) |

- **Compose project:** `ai-qadam-test` (`/var/www/ai-qadam-test/docker-compose.yml`, mode 644, `tvolodi:tvolodi`).
- **Env file:** `/var/www/ai-qadam-test/.env` (mode 600, `tvolodi:tvolodi`) — contains `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` (values not in landscape). DB: `aiqadam_test`, user: `aiqadam`.
- **Network:** `ai-qadam-test_default` (Compose-default bridge, internal-only; only the published loopback port 3112 is reachable from the host).
- **Container hardening gap (audit probe H, May inform post-reboot verification but NOT an acceptance criterion for T-0099):** no explicit `User` / `CapDrop` / `SecurityOpt` / `ReadonlyRootfs` (relies on Docker daemon defaults — `docker-default` apparmor+seccomp). **Tracked separately as T-0100** (observation only, out of scope for T-0099).
- **Status at last audit (2026-07-10 02:13 UTC):** `Up` and `healthy`. After reboot, Docker (29.6.1, containerd runtime) must come back clean and Compose must auto-restart this container (`unless-stopped`). **Acceptance criterion for T-0099: `docker ps` shows `Up ... (healthy)` post-reboot and loopback `SELECT 1` returns `1`.**

### apt posture

- **`unattended-upgrades` is active and enabled**, but restricted to **`security` + `ESMApps` + `ESM` origins only** (not `-updates`, not `-proposed`, not `-backports`). Source `/etc/apt/apt.conf.d/20auto-upgrades` has `APT::Periodic::Update-Package-Lists "1"` and `APT::Periodic::Unattended-Upgrade "1"` — daily pull + upgrade enabled. Last unattended-upgrades run timestamps: `2026-07-09 06:26:53` ("No packages found that can be upgraded unattended and no pending auto-removals") and `2026-07-09 15:09:09`. **No race concern**: unattended-upgrades will NOT re-touch the 9 `-updates` pocket packages after we apply them manually (out of its allowed-origins list).
- **Sources:** deb822-format `/etc/apt/sources.list.d/ubuntu.sources` (Ubuntu 26.04 stock); no third-party repositories.
- **Effective `apt` semantics here:** since `-updates` is **not** in unattended-upgrades' allow-list, the 9 pending packages (see Pre-reboot state below) have been sitting in `-updates` **unattended** for 3 days. A manual `apt -y full-upgrade` is the correct path; unattended-upgrades is not in the way.
- **Conflicting timer to be aware of:** `apt-daily.timer` and `apt-daily-upgrade.timer` (systemd) run unattended-upgrades on the daily cadence; the audit found the last run at `~06:26 UTC` and a re-trigger at `~15:09 UTC` (2026-07-09). Out-of-band `apt -y full-upgrade` is normally safe even if a timer fires mid-upgrade (apt holds a lock), but a belt-and-braces approach for the executor would be to `systemctl stop apt-daily.timer apt-daily-upgrade.timer` for the duration of the upgrade + reboot window, then re-enable.
- **`/etc/apt/apt.conf.d/50unattended-upgrades`** is the standard Ubuntu-shipped config, restricted to security/ESM as captured by audit probe B.

### Backups in place (config-only; no data backup)

The **only** backups on this host are **config-file rollback artifacts** from prior hardening runs. **There is NO application-level or data-level backup** of the Postgres volume.

| Path | Source task | What it covers |
|---|---|---|
| `/etc/default/ufw.bak` (1897 B) | (cloud-init defaults) | Pre-T-0094 UFW defaults — pure config snapshot |
| `/tmp/ufw.pre-T0094.20260708T173602Z.bak/` | T-0094 | Full `/etc/ufw/` directory snapshot (11 files + 1 subdir) |
| `/etc/default/ufw.pre-T0090.20260708T184046Z.bak` | T-0090 | Pre-FORWARD-flip state |
| `/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak/` | T-0093 | Pre-sshd-hardening sshd_config.d (contains the original `60-cloudimg-settings.conf`) |
| `/etc/fail2ban.pre-T0095.20260708T182109Z.bak/` | T-0095 | Pre-fail2ban config snapshot |

**None of these cover application data or container volumes.** T-0098 (host-level backup strategy for pro-data-tech-qa, P3 observation, deferred) is still open — **no automated rollback path exists for the Postgres data directory `/var/lib/docker/volumes/ai-qadam-test_ai_qadam_test_pgdata/_data/`**. The task file T-0099 (per step 01) explicitly flags this as a "manual filesystem-level dump of the Postgres volume before reboot is a reasonable precaution the executor may propose, but is not a hard acceptance criterion." **Provider snapshots are deliberately NOT used** (project rule: no paid provider add-ons, no off-site/external storage; see `landscape/hosts/pro-data-tech-qa.md` "Backups" section).

### Pre-reboot state

- **`uname -r` currently shows:** `7.0.0-14-generic` (landscape frontmatter; reconfirmed by audit probe B 2026-07-10 02:13 UTC).
- **`/var/run/reboot-required` is set** (audit probe B captured the literal marker file content: `*** System restart required ***\nlinux-image-7.0.0-27-generic\nlinux-base`). After the upgrade + reboot, this file should be absent.
- **9 packages pending upgrade** (audit probe B `apt list --upgradable` output, all from pocket `resolute-updates`, no `-security` tagged):

  | Package | From version | To version |
  |---|---|---|
  | `linux-image-7.0.0-27-generic` | (kernel meta-pkg, will pull newer kernel image into `/boot`) | (version not shown by probe — apt-upgrade will display) |
  | `linux-base` | (kernel base) | (newer) |
  | `fwupd` | `2.1.1-1ubuntu3` | `2.1.1-1ubuntu3.1` |
  | `libfwupd3` | `2.1.1-1ubuntu3` | `2.1.1-1ubuntu3.1` |
  | `python3-software-properties` | `0.120` | `0.120.1` |
  | `software-properties-common` | `0.120` | `0.120.1` |
  | `tzdata` | `2026a-3ubuntu1` | `2026b-0ubuntu0.26.04.1` |
  | `ubuntu-kernel-accessories` | `1.570` | `1.570.1` |
  | `ubuntu-minimal` | `1.570` | `1.570.1` |
  | `ubuntu-server` | `1.570` | `1.570.1` |
  | `ubuntu-standard` | `1.570` | `1.570.1` |

  Note: `linux-image-7.0.0-27-generic` was listed in the reboot-required marker but **NOT** enumerated by audit probe B's `apt list --upgradable` tail — likely because Linux kernel images are held by `apt-mark hold`/`unattended-upgrades` so they don't re-appear in the upgradable list once applied, OR the kernel meta-package is `linux-image-generic` and the listed `linux-image-7.0.0-27-generic` is itself the upgradable kernel slot. **The executor must re-run `apt list --upgradable`** at execution time to get a current snapshot — the landscape's list is from 2026-07-10 02:13 UTC and may have shifted by execution time.
- **No `-security` pending:** audit probe B explicitly confirmed `--- security-only pending ---\n0`. So no unpatched CVE will be skipped by waiting.
- **Unattended-upgrades log grep (audit probe B):** the only recurring message is `No packages found that can be upgraded unattended and no pending auto-removals` — proof that the unattended-upgrades channel is **not** touching `-updates`-pocket items.

### Cloud-init / snap state (reboot should preserve)

- **`cloud-init.{local,network,main,config,final}.service`** is stock package default. The cloud-init `init` stage ran once at provider install time (last apt activity captured as "cloud-init" — `2026-07-07 11:20 UTC`); subsequent runs are idempotent. Reboot does not re-trigger cloud-init (no new instance metadata, no new user-data); host's `machine-id`, `instance-id`, and `/var/lib/cloud/instance` should survive.
- **`snapd.service`** is active. No project-installed snaps recorded in landscape; the snap-cargo SUID binaries under `/usr/lib/cargo/bin/{su,sudo}` (audit probe J) are stock Ubuntu artifacts, not malicious (per step 01's preconditions).
- **`apparmor.service`** — 179 profiles loaded, 103 in enforce mode (landscape) / `180 / 104` (audit probe N, +1/+1 over 2 days, negligible). Will survive reboot cleanly.
- **`chrony.service`** — Ubuntu 26.04 default NTP client; sync on boot is fast (no long wait).
- **`qemu-guest-agent.service`** — pro-data.tech KVM guest agent; needed for clean provider-side state updates after `systemctl reboot`.

## Things NOT covered by landscape (gaps for the solution-designer)

The landscape + audit run cover nearly all of what T-0099 needs. The few gaps below will need live discovery by the executor at execution time:

- **Current exact `uname -r`** — landscape says 7.0.0-14 (last verified 2026-07-08), audit confirmed it again at 2026-07-10 02:13 UTC. No drift expected, but the executor should re-check immediately before reboot to confirm no surprise kernel switch happened between audit and T-0099 execution.
- **Current `apt list --upgradable` snapshot** — audit captured it ~hours ago. By execution time, unattended-upgrades may have run again (last run `2026-07-09 06:26 UTC`; next likely ~`2026-07-10 06:26 UTC`); security-pocket upgrades would have appeared and `apt list --upgradable` would now reflect a smaller set. **Executor must re-snapshot `apt list --upgradable` at execution time** to know exactly what's pending.
- **`/var/run/reboot-required`** contents at execution time — audit confirmed it's set with `linux-image-7.0.0-27-generic` listed. The contents may shift if unattended-upgrades applies a security update before T-0099 runs.
- **Free space on `/boot`** — landscape shows 989 MB total at 17% used (~168 MB free after kernel images). Each Ubuntu kernel image uses ~80–100 MB; running 2 or 3 stale kernels plus a new one can push `/boot` to capacity. **Executor must check `df -h /boot` pre-upgrade** and may need `apt autoremove --purge` of stale kernels to make room. The standard Ubuntu `unattended-upgrades` config does not auto-prune old kernels unless `/etc/apt/apt.conf.d/50unattended-upgrades` has `Unattended-Upgrade::Remove-Unused-Kernel-Packages` / `Remove-Unused-Dependencies` set to `"true"` (current landscape notes do not confirm this; apt post-install hook typically does `autoremove` after a manual `apt full-upgrade`).
- **Postgres volume integrity snapshot before reboot** — optional risk mitigation per step 01; not a hard acceptance criterion. The executor should propose the approach (e.g. `tar -czf /var/backups/ai-qadam-test-pgdata-preT0099-$(date -u +%Y%m%dT%H%M%SZ).tar.gz /var/lib/docker/volumes/ai-qadam-test_ai_qadam_test_pgdata/_data` — note: this requires space; `/` has 142 GB free, fine). Live discovery required to capture volume size and decide.
- **Whether `autoremove` will fire during the upgrade** — dependent on local apt config; landscape does not enumerate this. Executor should check `/etc/apt/apt.conf.d/50unattended-upgrades` `Remove-Unused-Dependencies` setting before pulling the trigger.
- **`fail2ban` ignoreip freshness** — currently `178.89.57.135` (mgmt workstation outbound IP, captured at 2026-07-08). If the workstation's outbound IP has changed in the last 2 days, the executor's SSH might briefly hit fail2ban after enough retries; landscape notes the management workstation IP as `178.89.57.135` and the audit run worked from there recently, so this is a check-the-current-IP task only.

---

**Stale checks performed:**
- `landscape/hosts/pro-data-tech-qa.md` frontmatter `last_verified: 2026-07-10` — fresh (today).
- `landscape/services.md` frontmatter `last_verified: 2026-07-08` — 2 days old but `last_verified_note` describes pro-data-tech-qa explicitly (T-0094 done, T-0095 done, FORWARD reconciled); the table section for pro-data-tech-qa is also consistent with the host landscape and audit probe H. **Acceptable for this task**; step 08 should bump `last_verified` to 2026-07-10 after T-0099 completes (and update the pro-data-tech-qa section to reflect post-kernel-reboot state).
- `services.md` table rows for pro-data-tech-qa include some stale text (e.g. duplicated "ufw.service" copy-pasted under the "pro-data-tech-qa" Docker section); harmless for T-0099 design, but it's a landscape hygiene fix for a future housekeeping pass.

**Stubs encountered:** none.
**Verdict: PASS.** All needed facts are populated; gaps are limited to live snapshots the executor can capture at execution time, none of which are blockers.
