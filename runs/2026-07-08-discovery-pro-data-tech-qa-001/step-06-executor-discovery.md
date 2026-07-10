---
run_id: 2026-07-08-discovery-pro-data-tech-qa-001
step: 06
agent: executor-discovery
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
inputs_read:
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-03-task-validator.md
  - workflows/discovery-host.md
  - shared/handoff-format.md
artifacts_changed:
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-A-identity.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-B-os-kernel.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-C-hardware.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-D-users.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-E-sshd.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-F-firewall.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-G-listeners.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-H-docker.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-I-nginx.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-J-systemd.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-K-cron.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-L-apt.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-M-security.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-probe-N-backups.txt
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-06-executor-discovery.md
next_step_hint: Pass to execution-validator (step 07).
---

## Summary

Read-only `discovery-host` enumeration of the brand-new cloud host `pro-data-tech-qa` (IPv4 95.46.211.230, Ubuntu 26.04 LTS) completed successfully. All 14 probe sections (A–N) ran cleanly via `ssh -i ... root@95.46.211.230` (explicit root + identity, NOT the `pro-data-tech-qa` alias which sets `User tvolodi`). Pre-execution self-check (probe A) returned `whoami=root`, `sudo -n true` OK. The host is a clean cloud-init-provisioned cloud VM with no application/services running yet: sshd on port 22 (cloud-init defaults — `PermitRootLogin yes`, `PasswordAuthentication yes`), no Docker, no nginx, no ufw rules active, no operator users (only `root`), single key in `/root/.ssh/authorized_keys` (provider key only — no operator pubkeys), no backup tooling. Verdict: **PASS**.

## Details

### Pre-execution checks

- Workflow `state_changing` flag: **false** (verified in `workflows/discovery-host.md` frontmatter).
- Pre-execution self-check (probe A): `whoami=root`, `uid=0(root)`, `gid=0(root)`, `groups=0(root)`, `hostname=drkkrgm-qa-instance`, `sudo -n true` → `SUDO_OK`. PASS.
- SSH User trap averted: used `ssh ... root@95.46.211.230` (not the bare `pro-data-tech-qa` alias which configures `User tvolodi`). Only `root` has `NOPASSWD:ALL` via `/etc/sudoers.d/90-cloud-init-users`; landing as `tvolodi` would have failed probe A.
- Identity file: `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` (OpenSSH-format RSA-2048; `.ppk` extension is misleading — ssh/scp autodetect format from contents). Matches the fingerprint `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0` recorded by the task-reader.

### Probe log

#### Probe A: Identity & access — `step-06-probe-A-identity.txt`
- Command: `whoami && id && hostname && sudo -n true && echo SUDO_OK`
- Exit code: 0
- Result: `root` / `uid=0(root) gid=0(root) groups=0(root)` / `drkkrgm-qa-instance` / `SUDO_OK`
- Side effects observed: none

#### Probe B: OS & kernel — `step-06-probe-B-os-kernel.txt`
- Command: `cat /etc/os-release && uname -a && lsb_release -a 2>/dev/null`
- Exit code: 0
- Result: `Ubuntu 26.04 LTS` (Resolute Raccoon); kernel `Linux drkkrgm-qa-instance 7.0.0-14-generic #14-Ubuntu SMP PREEMPT_DYNAMIC Mon Apr 13 11:09:53 UTC 2026 x86_64 GNU/Linux`
- Side effects observed: none

#### Probe C: Hardware — `step-06-probe-C-hardware.txt`
- Command: `nproc; free -h; df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs`
- Exit code: 0
- Result: `nproc=8` vCPU; RAM 15Gi total / 647Mi used / 13Gi free; root disk `/dev/sda1` 145G / 2.9G used / 142G avail (2%); `/boot` 989M / 17%; `/boot/efi` 105M / 7%. No swap.
- Side effects observed: none

#### Probe D: Users & groups — `step-06-probe-D-users.txt`
- Command: as per `workflows/discovery-host.md` (script uploaded to /tmp, executed, removed)
- Exit code: 0
- Result:
  - `getent passwd >=1000 || ==root`: only `root` (uid 0) and `nobody` (uid 65534). **No operator users.**
  - `/etc/sudoers.d/`: only `90-cloud-init-users` (root NOPASSWD:ALL) + stock `README`.
  - `who`/`w` (supplementary, after `last` was found missing): 2 users logged in — `root` from `178.89.57.135` (current ssh session, 03:14) and `root` on `pts/0` from same source (16:43, idle 10:31m). Uptime 15h59m.
  - `last` command is not installed on this host (`/usr/bin/last` missing) — that's a finding, not a probe failure.
  - `/root/.ssh/authorized_keys`: **1 line** — `ssh-rsa rsa-key-20260707` (provider key only; the key comment doesn't carry the operator's name). No operator pubkeys installed.
- Anomalies: only 1 line in `authorized_keys`; **operator pubkeys `viktor_d` and `binali_r` are NOT registered** (multi-PC acceptance criterion NOT met). `last` missing (minor — can be installed by `util-linux` package, but `w` provides equivalent info).

#### Probe E: sshd config — `step-06-probe-E-sshd.txt`
- Command: `sudo sshd -T 2>/dev/null | grep -Ei '^(port|...etc)' | sort` + `sudo ls -la /etc/ssh/sshd_config.d/` + `sudo grep -rEh '' /etc/ssh/sshd_config.d/`
- Exit code: 0
- Result (relevant subset of `sshd -T` effective output):
  - `port 22`
  - `permitrootlogin yes` — **cloud-init default; should be `prohibit-password` after hardening**
  - `passwordauthentication yes` — **cloud-init default; should be `no` after hardening**
  - `pubkeyauthentication yes`
  - `permitemptypasswords no`
  - `usedns no`
  - `x11forwarding yes` — should be `no` for a server
  - `maxauthtries 6` — should be `3`
  - `clientaliveinterval 0`
  - `logingraceTime 120`
  - **No `allowusers` / `allowgroups` directives** — no operator group restriction
- Drop-ins: `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` (27 bytes, contains `PasswordAuthentication yes`). First-wins semantics: the drop-in sets `PasswordAuthentication yes` (which equals the compiled-in default; redundant but explicit). No `Match` blocks.
- Anomalies: All four sshd hardening flags are at their cloud-init defaults (insecure). The drop-in confirms `PasswordAuthentication yes` is INTENTIONAL cloud-init policy, not a misconfiguration.

#### Probe F: Firewall — `step-06-probe-F-firewall.txt`
- Command: `ufw status verbose; nft list ruleset; iptables -L -n -v; ip6tables -L -n -v`
- Exit code: 0
- Result:
  - **ufw**: present (`/usr/sbin/ufw`), installed, but **Status: inactive** (cloud-init default).
  - **nftables**: present, `nft list ruleset` returned **empty** (no rules loaded).
  - **iptables** (IPv4 + IPv6): all chains default `policy ACCEPT`; no rules.
- Anomalies: No host-level firewall active. The host is reachable on port 22 with no additional rules. The pro-data.tech provider's perimeter (if any) is outside the host's view. Capture for step 08 / T-0094.

#### Probe G: Network listeners — `step-06-probe-G-listeners.txt`
- Command: `sudo ss -tlnp; sudo ss -ulnp`
- Exit code: 0
- Result (TCP):
  - `127.0.0.54:53` (systemd-resolved, stub resolver) — local only
  - `127.0.0.53%lo:53` (systemd-resolved, stub resolver) — local only
  - `0.0.0.0:22` (sshd, pid 28491)
  - `[::]:22` (sshd, pid 28491, IPv6)
- Result (UDP):
  - `127.0.0.54:53` (systemd-resolved)
  - `127.0.0.53%lo:53` (systemd-resolved)
  - `127.0.0.1:323` (chronyd)
  - `[::1]:323` (chronyd)
- Anomalies: **No listeners on 80/443** — no nginx, no app server. Only ssh (22), systemd-resolved (53, local only), chronyd (323, local only).

#### Probe H: Docker — `step-06-probe-H-docker.txt`
- Command: `which docker && docker --version`; `docker info`; `sudo docker ps -a`; `sudo docker compose ls`; `sudo find / -name 'docker-compose*.y*ml' -not -path ...`
- Exit code: 0
- Result:
  - `which docker` — empty (not on PATH)
  - `docker --version` — not callable
  - `sudo docker ps -a` — "docker not callable"
  - `sudo docker compose ls` — "no docker compose ls"
  - `sudo find` — no compose files on disk
- Anomalies: **Docker is NOT installed.** Expected for a freshly-provisioned host; gate behind T-0093 (sshd hardening) + T-0097 (operator users) before T-0090 installs it. Capture for step 08.

#### Probe I: nginx — `step-06-probe-I-nginx.txt`
- Command: `which nginx && nginx -v`; `sudo nginx -T`
- Exit code: 0
- Result: `which nginx` empty; `sudo nginx -T` → `sudo: 'nginx': command not found`; no vhost summary.
- Anomalies: **nginx NOT installed.** Expected for a freshly-provisioned host; will be installed as part of T-0090's application baseline.

#### Probe J: systemd — `step-06-probe-J-systemd.txt`
- Command: `systemctl list-units --type=service --state=running | head -40`; `systemctl list-unit-files --type=service --state=enabled | head -40`
- Exit code: 0
- Result (running services, first 40 of 22 — all listed since 22 ≤ 40):
  - chrony, cron, dbus, fwupd, getty@tty1, ModemManager, multipathd, networkd-dispatcher, polkit, qemu-guest-agent, rsyslog, serial-getty@ttyS0, snapd, ssh, systemd-journald, systemd-logind, systemd-networkd, systemd-resolved, systemd-udevd, udisks2, unattended-upgrades, user@0
- Result (enabled services, first 40 of 40): stock cloud-image set — AppArmor, apport, blk-availability, chrony, cloud-config, cloud-final, cloud-init-{local,main,network}, console-setup, cron, dmesg, e2scrub_reap, finalrd, getty@, grub-initrd-fallback, grub2-common, keyboard-setup, lvm2-monitor, ModemManager, multipathd, netplan-configure, networkd-dispatcher, open-iscsi, open-vm-tools (template), pollinate, rsyslog, secureboot-db, setvtrgb, snapd.{apparmor,autoimport,core-fixup,recovery-chooser-trigger,seeded,service,system-shutdown}, sshd-keygen, sysstat, systemd-networkd-wait-online, systemd-networkd.
- Anomalies: All stock cloud-image units. `qemu-guest-agent` is enabled (cloud image is QEMU/KVM-based, consistent with pro-data.tech likely running KVM). `unattended-upgrades` is active and `ssh` is active (OpenBSD Secure Shell).

#### Probe K: Scheduled tasks — `step-06-probe-K-cron.txt`
- Command: per-user crontabs; `ls -la /etc/cron.*`; `systemctl list-timers --all`
- Exit code: 0
- Result:
  - **Per-user crontabs**: none for `root` or any `>=1000` user. Empty.
  - **System crontabs** (`/etc/cron.d`): only `.placeholder` + `e2scrub_all` (ext4 filesystem scrub).
  - **`/etc/cron.daily`**: apport, apt-compat, dpkg, logrotate, man-db.
  - **`/etc/cron.{hourly,monthly,yearly}`**: only `.placeholder`.
  - **`/etc/cron.weekly`**: man-db.
  - **systemd timers**: fwupd-refresh (2h), sysstat-collect (10m), apt-daily-upgrade (daily 06:00), apt-daily (daily 09:59), update-notifier-download (12h), systemd-tmpfiles-clean (12h), motd-news (12h), man-db (daily 12h), dpkg-db-backup (daily 00:00), sysstat-rotate (daily 00:00), sysstat-summary (daily 00:07), logrotate (daily 00:54), update-notifier-motd (weekly), xfs_scrub_all (weekly), e2scrub_all (weekly), fstrim (weekly), apport-autoreport (inactive), snapd.snap-repair (inactive), ua-timer (inactive).
- Anomalies: Stock cloud-image schedules only. No app-level cron jobs. No application-level backups. The `ua-timer` (unattended-upgrades timer) is in the inactive list — it appears to be a template that the actual `apt-daily.timer` and `apt-daily-upgrade.timer` replace. Note: `unattended-upgrades.service` is `active running` (per probe J), so unattended security updates are functional.

#### Probe L: apt posture — `step-06-probe-L-apt.txt`
- Command: `ls /etc/apt/sources.list.d/`; `apt list --upgradable`; `cat 20auto-upgrades`; `cat 50unattended-upgrades`; `stat /var/log/apt/history.log`
- Exit code: 0
- Result:
  - `/etc/apt/sources.list.d/`: only `ubuntu.sources` (Ubuntu 26.04 deb822-format sources file). No third-party repos.
  - **Pending upgrades: 0** (apt was run during initial cloud-init bootstrap; system is up to date).
  - `20auto-upgrades`: `APT::Periodic::Update-Package-Lists "1"; APT::Periodic::Unattended-Upgrade "1";` — daily updates and upgrades enabled.
  - `50unattended-upgrades` Allowed-Origins: stock Ubuntu (security, ESM apps, ESM infra). `updates`/`proposed`/`backports` are commented out (default).
  - Last apt activity: 2026-07-07 11:20:46 UTC (yesterday — the cloud-init bootstrap run).
- Anomalies: Clean stock apt posture. Unattended security updates enabled and configured per Ubuntu defaults.

#### Probe M: Security tools — `step-06-probe-M-security.txt`
- Command: `which fail2ban-client && sudo fail2ban-client status`; `which auditctl && sudo systemctl is-active auditd`; `which aa-status && sudo aa-status`
- Exit code: 0
- Result:
  - **fail2ban**: `which fail2ban-client` empty → "fail2ban not present". NOT installed.
  - **auditd**: `which auditctl` empty → "auditd not present". NOT installed.
  - **AppArmor**: `/usr/sbin/aa-status` present, "apparmor module is loaded. 179 profiles are loaded. 103 profiles are in enforce mode." First two enforced profiles: `/usr/bin/man`, `/usr/lib/snapd/snap-confine`.
- Anomalies: No SSH brute-force protection (fail2ban missing). No auditd (deferrable — known to have issues on 7.x kernels per T-0088; per landscape-reader, not a hard requirement). AppArmor stock.

#### Probe N: Backup posture — `step-06-probe-N-backups.txt`
- Command: `systemctl list-units | grep -Ei 'backup|snapshot'`; `which restic borg duplicity`; `find / -maxdepth 3 -type d -iname '*backup*'`
- Exit code: 0
- Result:
  - **Snapshot hooks / Hetzner cloud-agent**: not present (no `hetzner-cloud-agent` service). The only `backup|snapshot` matches are `lvm2-monitor.service` (LVM monitoring — not a backup tool) and `dpkg-db-backup.timer` (the systemd timer that backs up `/var/backups/dpkg.status` daily).
  - **restic / borg / duplicity**: none installed (all `which` empty).
  - **Common backup paths**: only `/var/backups` (stock directory, contains the standard `dpkg`, `apt`, `passwd`, `group`, `shadow`, `gshadow`, `alternatives` archive files; nothing app-specific).
- Anomalies: **No application-level backup tooling.** No restic, no borg, no duplicity. No `pro-data.tech`-specific snapshot agent (the provider may have a control-plane snapshot, but no in-host hook for it). Capture for T-0098.

## Findings (raw)

### Hardware & OS
- Cloud VM: 8 vCPU, 15 GiB RAM, 145 GB root disk (`/dev/sda1`, 2% used), 989 MB `/boot`, 105 MB `/boot/efi`. No swap.
- Hostname: `drkkrgm-qa-instance`. **OS: Ubuntu 26.04 LTS (Resolute Raccoon)**. Kernel: `7.0.0-14-generic` (x86_64, SMP, PREEMPT_DYNAMIC).
- Virtualization: cloud image with `qemu-guest-agent.service` active — KVM/QEMU-based guest.
- IPv4: 95.46.211.230 (provider: pro-data.tech, NOT Hetzner).
- No IPv6 captured by probes; no `ip -6 addr` was in scope per the workflow.

### Identity & access
- Current login: `root` via provider SSH key (the SSH alias `pro-data-tech-qa` configures `User tvolodi` but provider-key auth as `root` works directly with `ssh ... root@95.46.211.230`).
- `sudo`: passwordless for `root` only via `/etc/sudoers.d/90-cloud-init-users` (`root ALL=(ALL) NOPASSWD:ALL`).
- No other sudoers drop-ins.
- No `tvolodi` user. No operator users (`viktor_d`, `binali_r` not present).

### Users & groups
- `getent passwd >=1000 || ==root`: only `root` and `nobody`. **No operator users.**
- `/etc/sudoers.d/`: only `90-cloud-init-users` + stock `README`. No operator drop-ins.
- Currently logged in: 2 sessions — `root` from `178.89.57.135` (current SSH session, 03:14 UTC) and `root` on `pts/0` from same source (16:43 UTC, idle 10:31m). Uptime 15h59m.
- `last` command not installed (`util-linux` not fully provisioned; `w` provides equivalent info).
- `/root/.ssh/authorized_keys`: **1 line** — `ssh-rsa rsa-key-20260707` (provider key; comment field does not carry the operator's name — this is a pro-data.tech control-plane key, not operator-managed). **No operator pubkeys (viktor_d, binali_r) installed.**
- No `/home/<user>/.ssh/authorized_keys` files exist (no non-root users).

### sshd config
- Port 22; `PermitRootLogin yes`; `PasswordAuthentication yes`; `PubkeyAuthentication yes`; `PermitEmptyPasswords no`; `UseDNS no`; `X11Forwarding yes`; `MaxAuthTries 6`; `ClientAliveInterval 0`; `LoginGraceTime 120`.
- **No `AllowUsers` / `AllowGroups` directives.**
- Drop-in: `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` (27 bytes, single line: `PasswordAuthentication yes`). First-wins semantics: the drop-in sets `PasswordAuthentication yes` redundantly with the default — explicit cloud-init policy, not an oversight. **There is no `Match` block, so the drop-in applies globally.**
- `sshd -T` (effective) output captured verbatim in `step-06-probe-E-sshd.txt`.
- The compiled-in Ubuntu 26.04 defaults for the remaining keys (e.g. `MaxAuthTries 6`) are documented in the probe log; not a finding beyond noting that 6 retries × `LoginGraceTime 120` is generous.

### Network listeners
- **TCP**: `127.0.0.54:53` (systemd-resolved stub, local), `127.0.0.53%lo:53` (systemd-resolved stub, local), `0.0.0.0:22` (sshd), `[::]:22` (sshd IPv6).
- **UDP**: `127.0.0.54:53` (systemd-resolved), `127.0.0.53%lo:53` (systemd-resolved), `127.0.0.1:323` (chronyd), `[::1]:323` (chronyd IPv6).
- No app ports (80, 443, 3000-3999, 5432, 6379, etc.). No Docker, no nginx, no app server.

### Firewall
- **ufw**: installed but **inactive**. (`Status: inactive`.)
- **nftables**: present, `nft list ruleset` returned empty — no rules loaded.
- **iptables** (IPv4 + IPv6): all chains default `policy ACCEPT`; no rules.
- Effective state: no host-level firewall. Only the pro-data.tech provider's network (if any) protects the host.

### Docker
- Not installed. `which docker` empty, `docker --version` not callable, `sudo docker ps` "docker not callable", `sudo docker compose ls` "no docker compose ls", no `docker-compose*.yml` files on disk.
- Container runtime, compose projects, networks, volumes: not present.

### nginx
- Not installed. `which nginx` empty, `sudo nginx -T` "command not found". No vhost summary.

### systemd
- 22 running services (all stock cloud-image): chrony, cron, dbus, fwupd, getty, ModemManager, multipathd, networkd-dispatcher, polkit, qemu-guest-agent, rsyslog, serial-getty, snapd, ssh, systemd-{journald,logind,networkd,resolved,udevd}, udisks2, unattended-upgrades, user@0.
- 40 enabled services (stock cloud-image; full list in `step-06-probe-J-systemd.txt`).
- No application-level services. No third-party systemd units.

### Scheduled tasks
- No per-user crontabs.
- `/etc/cron.d`: only `e2scrub_all` (ext4 scrub) + `.placeholder`.
- `/etc/cron.daily`: apport, apt-compat, dpkg, logrotate, man-db.
- `/etc/cron.{hourly,monthly,yearly}`: only `.placeholder`.
- `/etc/cron.weekly`: man-db.
- systemd timers: 19 listed (3 inactive templates: apport-autoreport, snapd.snap-repair, ua-timer). 16 active, all stock cloud-image.

### apt posture
- Sources: only `/etc/apt/sources.list.d/ubuntu.sources` (Ubuntu 26.04 deb822-format). No third-party repos.
- Pending upgrades: **0** (system is up to date as of 2026-07-07 11:20 UTC bootstrap).
- Unattended-upgrades: enabled (daily), Allowed-Origins stock Ubuntu (security, ESM apps, ESM infra). `updates`/`proposed`/`backports` commented out.
- Last apt activity: 2026-07-07 11:20:46 UTC.

### Security tools
- **fail2ban**: not installed.
- **auditd**: not installed.
- **AppArmor**: module loaded, 179 profiles loaded, 103 in enforce mode. First two enforced: `/usr/bin/man`, `/usr/lib/snapd/snap-confine`.
- No other security tooling (no CrowdSec, no AIDE, no rkhunter, no chkrootkit — none in scope of probe M but worth noting for T-0096).

### Backup posture
- No Hetzner cloud-agent (not Hetzner). No pro-data.tech in-host snapshot agent visible.
- No restic, no borg, no duplicity. No tar-based nightly backup cron.
- `/var/backups` is the stock Ubuntu directory only (dpkg/apt/passwd/group/shadow/gshadow/alternatives archives).
- No app-level backups; the only system-level backup is the daily `dpkg-db-backup.timer`.

## Issues / risks

- **T-0093 candidate (sshd hardening)**: `PermitRootLogin yes`, `PasswordAuthentication yes` (intentional cloud-init default — see drop-in `60-cloudimg-settings.conf`). No `AllowGroups` directive. The host accepts password authentication over the public Internet; this is a security baseline gap.
- **T-0094 candidate (host firewall)**: ufw installed but inactive; nftables has no rules; iptables all-ACCEPT. No host-level firewall posture. The pro-data.tech provider's network protection is outside the host's view; defense-in-depth requires ufw/nft ruleset active on the host.
- **T-0095 candidate (fail2ban)**: SSH brute-force protection absent.
- **T-0096 candidate (auditd)**: kernel audit not installed. Deferrable (known issues on 7.x kernels per T-0088). AppArmor does provide a baseline of mandatory access control.
- **T-0097 candidate (operator user creation)**: **multi-PC SSH acceptance criterion is NOT met.** `/root/.ssh/authorized_keys` has only 1 line (provider key `rsa-key-20260707`); operator pubkeys `viktor_d` (`~/.ssh/ai-dala-infra-viktor-d.pub`) and `binali_r` (`~/.ssh/ai-dala-infra-binali-r.pub`) are NOT installed. Operators cannot SSH from their own workstations today. This is the **highest-priority** observation for step 08.
- **T-0090 candidate (Docker install)**: host cannot run Compose applications yet. Expected at this stage; gate behind T-0093 + T-0097.
- **T-0098 candidate (backup tooling)**: no restic/borg/duplicity, no app-level backup strategy. Per project policy, backups must stay on local host disk — `restic` to a local `btrfs`/`zfs` dataset is the recommended pattern. The pro-data.tech control-plane snapshot (if any) is **out of scope** for the project per the orchestrator's "no off-site/external storage" hard rule; not even the pro-data.tech control-plane snapshot is provisioned (verify via the pro-data.tech dashboard, not in scope for this run).
- **Hygiene: `.ppk` extension is misleading**: the file `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` is OpenSSH-format RSA-2048 (not PuTTY `.ppk`). ssh/scp autodetect format from contents, so the alias works. Recommended for a future cosmetic task (rename to `.pem` or `.key`). Deferrable.
- **Provider key `rsa-key-20260707` lacks operator attribution**: the single line in `/root/.ssh/authorized_keys` has the comment `rsa-key-20260707` — this is a pro-data.tech control-plane key (created 2026-07-07), NOT operator-managed. After T-0093 (which should set `PermitRootLogin prohibit-password` and add `AllowGroups sshusers`), the `tvolodi` and operator users will need to be created in the `sshusers` group, and the provider key's role is purely a bootstrap anchor.
- **No `tvolodi` user**: the SSH alias `pro-data-tech-qa` configures `User tvolodi`, but the host has no `tvolodi` user. The alias currently only works because (a) ssh falls back to the username in the URL when no `User` directive matches, and (b) the `root` user accepts the provider key. After T-0093 sets `PermitRootLogin prohibit-password` (still allows pubkey root) → T-0097 creates `tvolodi` + operator users → T-0090 sets `PermitRootLogin no`. Decision deferred to the user per the landscape-reader's "open question".

## Open questions (optional)

- **Operator key installation strategy**: should the operators install their pubkeys into `/root/.ssh/authorized_keys` directly (keeping root login with keys until T-0090 sets `PermitRootLogin no`), or into a new shared user (e.g., `ai-qadam`) in the `sshusers` group with NOPASSWD sudo? This is a future state-changing task (T-0097), NOT for this discovery. The user's `tvolodi` user on the management workstation is a separate question (the SSH alias `User tvolodi` doesn't mean a `tvolodi` user must exist on the host).
- **pro-data.tech control-plane snapshot**: does the pro-data.tech control plane offer snapshot/backup of the host's root disk? If so, is it enabled by default? This is not visible from inside the host. Worth asking the user to check the pro-data.tech dashboard, but per project policy ("no off-site/external storage") it should be **disabled** even if available.
- **Hetzner-style firewall template**: should `pro-data-tech-qa` follow the same hardening template as `hetzner-prod` and `ubuntu-16gb-nbg1-1` (UFW deny-by-default + fail2ban + sshd drop-in + `AllowGroups sshusers`), or a different baseline? The probes show cloud-init defaults; the user decides the path.
- **T-0093 vs T-0090 ordering for hardening**: T-0093 (sshd) should run first, then T-0097 (operator users), then T-0090 (full prep including Docker + app baseline). The `pro-data.tech-qa-instance_rsa.ppk` provider key provides a fallback escape route if T-0093 is misconfigured; the user should verify provider-key access is preserved across the T-0093 → T-0097 → T-0090 sequence.
