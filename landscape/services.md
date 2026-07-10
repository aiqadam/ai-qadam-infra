---
name: services
last_verified: 2026-07-10
status: populated
last_verified_note: Migrated from ai-dala-infra 2026-07-10 (T-0101). Contains ubuntu-16gb-nbg1-1 and pro-data-tech-qa service entries only.
---

# Services

What runs on each managed host in the ai-qadam infrastructure. Migrated from `ai-dala-infra` 2026-07-10 (T-0101). Updated by every workflow that changes service state.
## ubuntu-16gb-nbg1-1

Populated by `2026-06-27-discovery-host-001`. See [`hosts/ubuntu-16gb-nbg1-1.md`](hosts/ubuntu-16gb-nbg1-1.md) for the canonical host facts (hardware, access, network, backups). High-level: **freshly provisioned Ubuntu 26.04 cloud image; no project services, no Docker, no nginx**.

### Docker

- **Status (2026-06-27):** Docker **not installed**. No compose projects on disk. No docker-proxy ports bound.

### nginx

- **Status (2026-06-27):** nginx **not installed**. No vhosts.

### Native systemd services of note

| Unit | Path | User | What it does |
|---|---|---|---|
| `ssh.service` | (package default) | root | sshd |
| `chrony.service` | (package default) | root | NTP client (Ubuntu 26.04 default; replaces legacy systemd-timesyncd) |
| `unattended-upgrades.service` | (package default) | root | Automatic security upgrades (security + ESM channels only) |
| `qemu-guest-agent.service` | (package default) | root | Hetzner KVM guest agent |
| `cloud-init.{local,network,main,config,final}.service` | (package default) | root | Cloud-init bootstrap stages |
| `snapd.service` | (snap default) | root | Snap daemon |
| `apparmor.service` | (package default) | root | AppArmor MAC (180 profiles loaded, 104 in enforce) |
| `systemd-resolved.service` | (package default) | root | Local DNS stub on 127.0.0.53 / 127.0.0.54 |
| `ufw.service` | (package default) | root | **Enabled and active** — deny-by-default + allow 22/80/443 (v4+v6), DEFAULT_FORWARD_POLICY="ACCEPT" preserved for Docker parity; configured 2026-06-27 via run `2026-06-27-configure-ufw-001` / T-0083 |
| `fail2ban.service` | (apt package, `/usr/lib/systemd/system/fail2ban.service`) | root | Brute-force protection — sshd jail enabled (maxretry=3, bantime=600s, findtime=600s, ignoreip includes 178.89.57.135, banaction=iptables-multiport); config at `/etc/fail2ban/jail.d/sshd.local`. Installed 2026-06-27 via run `2026-06-27-install-fail2ban-001` / T-0084 |
| `rsyslog.service`, `cron.service`, `atd.service`, `polkit.service`, `dbus.service`, `multipathd.service`, `systemd-{journald,logind,networkd,udevd}.service`, `user@{0,1000}.service`, `getty@tty1.service`, `serial-getty@ttyS0.service` | (package defaults) | root | Standard Ubuntu cloud-image base |

### Scheduled tasks

- Per-user crontabs: `root` and `tvolodi` have **no crontabs**.
- `/etc/cron.d/`: `.placeholder`, `e2scrub_all` (stock).
- `/etc/cron.daily/`: `apport`, `apt-compat`, `dpkg`, `logrotate`, `man-db` (stock).
- `/etc/cron.hourly/`: empty.
- `/etc/cron.weekly/`: `man-db` (stock).
- `/etc/cron.monthly/`: empty.
- Systemd timers (18 stock cloud-image timers): `apt-daily-upgrade`, `apt-daily`, `dpkg-db-backup`, `motd-news`, `sysstat-collect`, `sysstat-rotate`, `sysstat-summary`, `logrotate`, `xfs_scrub_all`, `e2scrub_all`, `update-notifier-download`, `systemd-tmpfiles-clean`, `man-db`, `fstrim`, `update-notifier-motd`, `apport-autoreport`, `snapd.snap-repair`, `ua-timer`. **No `app-backup.timer`** (no apps to back up). **No certbot timer** (certbot not installed).

## pro-data-tech-qa

Populated by `2026-07-08-discovery-pro-data-tech-qa-001`. See [`hosts/pro-data-tech-qa.md`](hosts/pro-data-tech-qa.md) for the canonical host facts (hardware, OS, access, network, security). High-level: **Docker-installed host running the ai-qadam QA postgres container (T-0090 Phases A–E done 2026-07-08)**; nginx and any internet-facing services still pending (Phases F–I deferred to T-0090a). `role: ai-qadam-qa`. Parent task T-0090 done.

- **sshd hardening status:** hardened 2026-07-08 — PasswordAuthentication/KbdInteractiveAuthentication disabled; PermitRootLogin prohibit-password; AllowGroups sshusers; KEX/Ciphers/MACs tightened (no SHA-1, no CBC/3DES/RC4); drop-ins at /etc/ssh/sshd_config.d/40-disable-password.conf and 40-ai-dala-infra.conf; sshusers group created 2026-07-08 with root as sole member; operators `tvolodi`/`viktor_d`/`binali_r` added to sshusers by T-0097 the same day.
- **UFW firewall:** active 2026-07-08 (T-0094). Defaults: deny-incoming / allow-outgoing / forward-`ACCEPT` (flipped DROP→ACCEPT by T-0090 Phase A2, 2026-07-08; now matches sibling hosts `/etc/default/ufw` convention)/ IPv6 enabled. Inbound rules: 22/tcp (v4+v6) from any source. Backups: /tmp/ufw.pre-T0094.20260708T173602Z.bak/ + /etc/default/ufw.bak + /etc/default/ufw.pre-T0090.20260708T184046Z.bak (post-T-0094 pre-T-0090).
- **fail2ban sshd jail:** active 2026-07-08 (T-0095). Bans via iptables-multiport (chain f2b-sshd) for 600s after 3 failed attempts in 600s. UFW coexist (T-0094) unaffected.
- **Operator users:** tvolodi (uid 1001, workstation), viktor_d (uid 1002), binali_r (uid 1003) — all in `sshusers` group with NOPASSWD sudo via `/etc/sudoers.d/90-<user>`; password-locked, key-only auth; live SSH for tvolodi verified end-to-end 2026-07-08; all three members of the `docker` group (gid 986) added by T-0090 Phase B6 — live SSH as tvolodi from a fresh shell will then run `docker ps` without `sudo`.
- **Multi-PC SSH:** enabled for tvolodi (workstation-validated via `ssh -i ai-dala-infra tvolodi@95.46.211.230`); ready for viktor_d / binali_r from their own workstations (server-side `ssh-keygen -lf` already confirms their pubkeys parse).
- **Root SSH:** key-only (`prohibit-password`), provider key `rsa-key-20260707` (fingerprint `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0`) preserved as break-glass anchor.

### Apt posture

Verified by audit run `2026-07-10-audit-host-pro-data-tech-qa-001` and T-0099 executor (`2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001`).

- **Pending upgrades (2026-07-10, post-T-0099):** 4 packages remain (`fwupd` 2.1.1-1ubuntu3→2.1.1-1ubuntu3.1, `libfwupd3` matching, `python3-software-properties` 0.120→0.120.1, `software-properties-common` matching) — ALL flagged **"Not upgrading yet due to phasing"** by Ubuntu's phased-update mechanism. This is design-intent (Ubuntu's rollout model), not a regression or action item. The packages will land when the rollout window reaches this host — typically on the next unattended-upgrades cycle.
- **Why the queue wasn't fully consumed by T-0099:** `apt full-upgrade -y` was run (executor Phase 2.3) and a one-shot retry was performed (executor Phase 8 contingency for V01); both returned the phasing message. The kernel itself + the 8 other packages (curl/libcurl 8.18.0-1ubuntu2.3, ubuntu-kernel-accessories 1.570.1, ubuntu-minimal 1.570.1, ubuntu-server 1.570.1, ubuntu-standard 1.570.1, tzdata 2026b) all upgraded cleanly. Only the 4 phased packages remain.
- **unattended-upgrades:** active and enabled (daily cycle, security + ESM origins only). The next unattended-upgrades run will pick up the phased packages as their rollout windows open.
- **Active kernel:** `7.0.0-27-generic` (post-T-0099 reboot at 2026-07-10T06:14:28Z → sshd back 06:21:12Z; previous `7.0.0-14-generic` retained as GRUB fallback).
- **Pre-reboot backup:** `/var/backups/pre-T0099.20260710T061200Z/` — `pg_dump` (405 B) + `etc-snapshot.tar.gz` (148 453 B) + `pre-reboot-state.txt` (5924 B), root:root mode 0750/0640.
- **Kernel audit subsystem:** `CONFIG_AUDIT=y` built-in to kernel 7.0.0-27-generic (post-T-0099 reboot). `kauditd` kthread running (pid 68 at auditd start). The audit subsystem is not a loadable module here (Ubuntu cloud image convention); subsystem presence is verified by the `kauditd` kthread + `/usr/sbin/auditd` running + `auditctl -s` reporting `enabled 1`. T-0096 (2026-07-10) brought the project CIS-derived ruleset online against this subsystem.

### Docker

- **Status (2026-07-08):** Docker **installed** (T-0090 Phases A–E). Engine 29.6.1 (build `8900f1d`); Compose plugin v5.3.1; containerd as the runtime. systemd `docker.service` enabled + active. Operator users `tvolodi`/`viktor_d`/`binali_r` added to the `docker` group (gid 986).

#### Running Compose projects

| Project | Compose file | Containers |
|---|---|---|
| `ai-qadam-test` | `/var/www/ai-qadam-test/docker-compose.yml` | 1 (`ai-qadam-test-db-1` only — app container deferred to T-0090a) |

#### Running containers (2026-07-08, post-T-0090)

| Container | Image:tag | Compose project | Host ports | Bind | Restart / health | Purpose |
|---|---|---|---|---|---|---|
| `ai-qadam-test-db-1` | `pgvector/pgvector:pg16` | ai-qadam-test | `3112` → `5432` | `127.0.0.1` (loopback only) | `unless-stopped` / `(healthy)` (healthcheck `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}`, 5s interval, 3s timeout, 10 retries) | ai-qadam QA postgres — db `aiqadam_test`, user `aiqadam` (credentials from `/var/www/ai-qadam-test/.env`, mode 600 tvolodi:tvolodi); volume `ai-qadam-test_ai_qadam_test_pgdata` (Docker-canonical full name of named volume `ai_qadam_test_pgdata`) |

- **AI Qadam QA stack:** postgres container (pgvector/pgvector:pg16) at `127.0.0.1:3112` → `5432`; db `aiqadam_test`, user `aiqadam`. Stack name `ai-qadam-test`. Volume `ai_qadam_test_pgdata`. Status: deployed 2026-07-08, healthy.

### nginx

- **Status (2026-07-08):** nginx **not installed**. No vhosts. (Will be installed as part of T-0090a's application baseline + public-internet exposure.)

- **sshd hardening status:** hardened 2026-07-08 — PasswordAuthentication/KbdInteractiveAuthentication disabled; PermitRootLogin prohibit-password; AllowGroups sshusers; KEX/Ciphers/MACs tightened (no SHA-1, no CBC/3DES/RC4); drop-ins at /etc/ssh/sshd_config.d/40-disable-password.conf and 40-ai-dala-infra.conf; sshusers group created 2026-07-08 with root as sole member; operators `tvolodi`/`viktor_d`/`binali_r` added to sshusers by T-0097 the same day.
- **UFW firewall:** active 2026-07-08 (T-0094). Defaults: deny-incoming / allow-outgoing / forward-DROP / IPv6 enabled. Inbound rules: 22/tcp (v4+v6) from any source. Backups: /tmp/ufw.pre-T0094.20260708T173602Z.bak/ + /etc/default/ufw.bak.
- **fail2ban sshd jail:** active 2026-07-08 (T-0095). Bans via iptables-multiport (chain f2b-sshd) for 600s after 3 failed attempts in 600s. UFW coexist (T-0094) unaffected.
- **Operator users:** tvolodi (uid 1001, workstation), viktor_d (uid 1002), binali_r (uid 1003) — all in `sshusers` group with NOPASSWD sudo via `/etc/sudoers.d/90-<user>`; password-locked, key-only auth; live SSH for tvolodi verified end-to-end 2026-07-08.
- **Multi-PC SSH:** enabled for tvolodi (workstation-validated via `ssh -i ai-dala-infra tvolodi@95.46.211.230`); ready for viktor_d / binali_r from their own workstations (server-side `ssh-keygen -lf` already confirms their pubkeys parse).
- **Root SSH:** key-only (`prohibit-password`), provider key `rsa-key-20260707` (fingerprint `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0`) preserved as break-glass anchor.

### Docker

- **Status (2026-07-08):** Docker **not installed**. No compose projects on disk. No docker-proxy ports bound. (Will be installed as part of T-0090; T-0093 sshd hardening and T-0097 operator user creation both done 2026-07-08 — no gating blocks remain on T-0090.)

### nginx

- **Status (2026-07-08):** nginx **not installed**. No vhosts. (Will be installed as part of T-0090's application baseline.)

### Native systemd services of note

| Unit | Path | User | What it does |
|---|---|---|---|
| `ssh.service` | (package default) | root | sshd — hardened 2026-07-08 (T-0093): `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin prohibit-password`, `AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`; KEX/Ciphers/MACs tightened (no SHA-1, no CBC/3DES/RC4); provider key preserved as break-glass in `/root/.ssh/authorized_keys` |
| `chrony.service` | (package default) | root | NTP client (Ubuntu 26.04 default; replaces legacy systemd-timesyncd) |
| `unattended-upgrades.service` | (package default) | root | Automatic security upgrades (security + ESM channels only; 0 pending) |
| `qemu-guest-agent.service` | (package default) | root | pro-data.tech KVM guest agent (KVM/QEMU-based virtualization) |
| `cloud-init.{local,network,main,config,final}.service` | (package default) | root | Cloud-init bootstrap stages (last apt activity 2026-07-07 11:20 UTC) |
| `snapd.service` | (snap default) | root | Snap daemon |
| `apparmor.service` | (package default) | root | AppArmor MAC (179 profiles loaded, 103 enforce) |
| `systemd-resolved.service` | (package default) | root | Local DNS stub on 127.0.0.53 / 127.0.0.54 |
| `ufw.service` | (package default) | root | **Enabled and active** — deny-by-default + allow 22/tcp (v4+v6) from any source, DEFAULT_FORWARD_POLICY="ACCEPT" (T-0090 Phases A–E 2026-07-08 flipped DROP→ACCEPT to allow Docker bridge traffic; now matches sibling-host convention); configured 2026-07-08 via run `2026-07-08-install-ufw-pro-data-tech-qa-001` / T-0094, FORWARD reconciled via run `2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001` / T-0090 |
| `docker.service` | `/lib/systemd/system/docker.service` | root | Active, enabled. Hosts the `ai-qadam-test` QA stack (T-0090 Phases A–E, 2026-07-08). |
| `fail2ban.service` | (apt package, `/usr/lib/systemd/system/fail2ban.service`) | root | Brute-force protection — sshd jail enabled (`maxretry=3`, `bantime=600s`, `findtime=600s`, `ignoreip=127.0.0.1/8 ::1 178.89.57.135`, `banaction=iptables-multiport`); config at `/etc/fail2ban/jail.d/sshd.local`. Installed 2026-07-08 via run `2026-07-08-install-fail2ban-pro-data-tech-qa-001` / T-0095 |
| `auditd.service` | `/lib/systemd/system/auditd.service` | root | Kernel audit daemon — `active`+`enabled`, hosting project CIS-derived ruleset (15 keys, 67 kernel rules) loaded from `/etc/audit/rules.d/audit.rules`; audit log at `/var/log/audit/audit.log` (mode 0640, group `adm`); `kauditd` kthread running (kernel audit subsystem loaded via `CONFIG_AUDIT=y` built-in to kernel 7.0.0-27-generic). Installed 2026-07-10 via run `2026-07-10-enable-auditd-on-pro-data-tech-qa-001` / T-0096 (T-0096, 2026-07-10). Hosts 67 kernel rules, 15 keys (logins, time-change, identity, sudoers, privileged-priv_change, perm_mod, modules, cron, sshd_config, fail2ban_config, ufw_config, docker_config, ai_qadam_data, exec).
| `rsyslog.service`, `cron.service`, `polkit.service`, `dbus.service`, `multipathd.service`, `systemd-{journald,logind,networkd,udevd}.service`, `user@0.service`, `getty@tty1.service`, `serial-getty@ttyS0.service`, `fwupd.service`, `udisks2.service`, `ModemManager.service`, `networkd-dispatcher.service` | (package defaults) | root | Standard Ubuntu cloud-image base (22 running services) |

### Scheduled tasks

- Per-user crontabs: `root` and any `>=1000` user have **no crontabs**. (`tvolodi`, `viktor_d`, `binali_r` exist as of 2026-07-08 — T-0097 done — but all three have empty crontabs.)
- `/etc/cron.d/`: `.placeholder`, `e2scrub_all` (stock).
- `/etc/cron.daily/`: `apport`, `apt-compat`, `dpkg`, `logrotate`, `man-db` (stock).
- `/etc/cron.hourly/`: empty.
- `/etc/cron.weekly/`: `man-db` (stock).
- `/etc/cron.monthly/`: empty.
- `/etc/cron.yearly/`: empty.
- Systemd timers (19 stock cloud-image timers; 16 active, 3 inactive templates): `apt-daily-upgrade`, `apt-daily`, `dpkg-db-backup`, `motd-news`, `sysstat-collect`, `sysstat-rotate`, `sysstat-summary`, `logrotate`, `xfs_scrub_all`, `e2scrub_all`, `update-notifier-download`, `systemd-tmpfiles-clean`, `man-db`, `fstrim`, `update-notifier-motd` (inactive templates: `apport-autoreport`, `snapd.snap-repair`, `ua-timer`). **No `app-backup.timer`** (no apps to back up — T-0098 deferred). **No `fail2ban.service`** (T-0095 pending). **No certbot timer** (certbot not installed).

## Change log

| Date | Run ID | Change |
|---|---|---|
| 2026-05-12 | `2026-05-12-discovery-host-001` | Initial population: Docker engine, 3 running compose projects + orphan, 5 nginx vhosts, notion-bridge service, scheduled tasks. |
| 2026-05-12 | `2026-05-12-remove-n8n-001` | Removed n8n compose project (containers n8n_n8n_1, n8n_postgres_1; volumes n8n_n8n_storage, n8n_db_storage, n8n_data; network n8n_default; compose dir /home/tvolodi/apps/n8n/). Removed n8n.ai-dala.com nginx vhost (server blocks stripped from ai-dala.conf). 3 workflows exported to /home/tvolodi/backups/n8n-workflows-export-20260512.json. |
| 2026-05-12 | `2026-05-12-stop-exposing-postgres-001` | Rebound wms-postgres from `0.0.0.0:5412` to `127.0.0.1:5412` in `/opt/wms/docker/docker-compose.yml`. Container recreated. Port 5412 no longer reachable from public internet. |
| 2026-05-12 | `2026-05-12-stop-exposing-redis-001` | Rebound wms-redis from `0.0.0.0:6359` to `127.0.0.1:6359` in `/opt/wms/docker/docker-compose.yml`. Container recreated. Port 6359 no longer reachable from public internet. Redis has no `requirepass` set — tracked as T-0023. |
| 2026-05-13 | `2026-05-13-app-backup-strategy-001` | Added app-backup.service (oneshot) and app-backup.timer (daily 02:00 UTC) to systemd. Documented wms-postgres actual credentials (db: qoimaDB, user: qoimawmsUser from /opt/wms/.env, overriding Compose defaults). |
| 2026-05-13 | `2026-05-13-cleanup-stale-containers-001` | Removed 4 stale exited containers (wms-bot, zealous_rosalind, nervous_bassi, affectionate_hypatia). Container count: 10 → 6 (all running, 0 exited). wms-bot exit-1 cause: missing TELEGRAM_BOT_TOKEN; Compose `bot` service preserved behind `profiles: [bot]` — see T-0028. Compose backup at /opt/wms/docker/docker-compose.yml.bak-20260513012725. |
| 2026-05-13 | `2026-05-13-install-rustdesk-server-001` | Deployed RustDesk self-hosted server (rustdesk-hbbs, rustdesk-hbbr) at `/app/rustdesk-server/` as Docker Compose project. Ports 21115–21119 bound to 0.0.0.0. Ed25519 public key: `Q5mteJr3tfde9tWPrWyrzyRLHDdyhCkkV0K0mv3S6SA=`. Container count: 6 → 8. |
| 2026-05-13 | `2026-05-13-setup-productfactory-deploy-infra-001` | Installed nginx vhosts `pf-test.conf` and `pf.conf` (sites-available + sites-enabled symlinks). Recorded infrastructure-ready ProductFactory compose projects (not yet deployed; containers start when T-0031 runs). |
| 2026-05-13 | `2026-05-13-deploy-productfactory-to-test-001` | Deployed ProductFactory to test environment. Image `productfactory-test:latest` (id a5ca37cdafb2) built from git ref 7b06f44. Container `pf-test` running at `127.0.0.1:3110→3001`, volume `pf_test_data` created. Health check and external HTTPS (pf-test.ai-dala.com) confirmed passing. |
| 2026-05-14 | `2026-05-14-setup-bilimbaga-deploy-infra-001` | Installed nginx vhost `bilimbaga-test.conf` (sites-available + sites-enabled symlink); cloned BilimBaga repo to `/opt/apps/bilimbaga-test/` (HEAD 9c63b50); wrote `.env` (mode 600, root:root); nginx reloaded. BilimBaga test infrastructure ready; containers not yet deployed (T-0065). Added Cloudflare A record bilimbaga-test.ai-dala.com (id e0ab20b87a1a1504a00587f8550ef9d2). |
| 2026-05-14 | `2026-05-14-deploy-bilimbaga-to-test-001` | Deployed BilimBaga test stack: built images `bilimbaga-test:latest` and `bilimbaga-api-test:latest` from git ref `2b1b2cc` (3 in-flight commits: e7b9dc2, 4a4d130, 2b1b2cc). Started containers `bilimbaga-test-nginx-1`, `bilimbaga-test-api-1`, `bilimbaga-test-db-1`. Volume `bilimbaga-test_bilimbaga_test_pgdata` created; migrations applied. Port 127.0.0.1:3111 now bound. Health check passing. |
| 2026-05-15 | `2026-05-15-remove-notion-bridge-001` | T-0025: notion-bridge.service stopped, disabled, unit file `/etc/systemd/system/notion-bridge.service` removed, `/root/chatgpt_bridge/` deleted. Port 8000 / uvicorn no longer listening. Backup at `/home/tvolodi/backups/notion-bridge-20260515.tar.gz` (600 root:root). `ai-dala.com` / `www.ai-dala.com` root location continues to serve static HTML from `/var/www/ai-dala/`; `/ai-bridge/` location block remains in nginx config but returns 502 (upstream gone). |
| 2026-05-18 | `2026-05-18-redeploy-bilimbaga-test-001` | T-0067: Re-deployed BilimBaga test from git ref `2b1b2cc` to `b7f8bee`. Rebuilt images `bilimbaga-test:latest` (sha256:8fd3f0f4) and `bilimbaga-api-test:latest` (sha256:057366cb). All three containers (`bilimbaga-test-nginx-1`, `bilimbaga-test-api-1`, `bilimbaga-test-db-1`) recreated; health check passing (HTTP 200). Corrected stale "pending first deploy" note in vhosts table. |
| 2026-05-18 | `2026-05-18-redeploy-bilimbaga-test-002` | T-0068: Re-deployed BilimBaga test from git ref `b7f8bee` to `10019ab`. Rebuilt images `bilimbaga-test:latest` (sha256:da418d16) and `bilimbaga-api-test:latest` (sha256:057366cb — backend unchanged). All three containers recreated; health check passing (HTTP 200, latency 1.9ms). Fix includes missing `apiFetch.ts` module and implicit-any TS error in `TagsPage.tsx`. |
| 2026-05-18 | `2026-05-18-redeploy-bilimbaga-test-003` | T-0069: Re-deployed BilimBaga test from git ref `10019ab` to `4acb8eb`. Rebuilt `bilimbaga-test:latest` (sha256:3167bdc7 — auth show/hide password toggle + docs commits). `bilimbaga-api-test:latest` rebuilt as full cache hit (sha256:057366cb — backend unchanged). All three containers recreated; health check passing (HTTP 200, latency 1.882ms). |
| 2026-05-19 | `2026-05-19-redeploy-bilimbaga-test-001` | T-0072: Re-deployed BilimBaga test from git ref `4acb8eb` to `58e613e` (61 files changed; includes rate-limit middleware, autojob fix, and new `deploy/redeploy-test.sh`). Rebuilt `bilimbaga-test:latest` (sha256:21a550e3) and `bilimbaga-api-test:latest` (sha256:6dfa4b66). All three containers recreated; health check passing (HTTP 200). `deploy/redeploy-test.sh` now present on host at `/opt/apps/bilimbaga-test/deploy/redeploy-test.sh`. |
| 2026-05-19 | `2026-05-19-redeploy-bilimbaga-test-002` | T-0073: Re-deployed BilimBaga test from git ref `58e613e` to `3dbd4de` (10 files changed: exam service fix, new locale keys, ISS-010 issue report). Rebuilt `bilimbaga-test:latest` (sha256:341ba1be) and `bilimbaga-api-test:latest` (sha256:490760d6). Rollback tags `bilimbaga-test:rollback-20260519` and `bilimbaga-api-test:rollback-20260519` created. All three containers recreated; health check passing (HTTP 200). Cloudflare HTTPS health check also confirmed passing. |
| 2026-05-21 | `2026-05-21-install-immich-001` | T-0075: Deployed Immich Docker Compose stack under `/opt/immich/` (4 containers: immich_server, immich_machine_learning, immich_postgres, immich_redis). Added nginx vhost `photos.conf` for `photos.ai-dala.com` → `http://127.0.0.1:2283`. Container count 12 → 16. Added immich_postgres to `app-backup.sh`. All containers healthy; HTTPS endpoint confirmed passing. |
| 2026-05-25 | `2026-05-25-deploy-bilimbaga-test-001` | T-0076: BilimBaga test final state verified at git ref `fc02903`; latest images now `bilimbaga-test:latest` (sha256:9ff0f724...) and `bilimbaga-api-test:latest` (sha256:db806a95...). Recorded normalized predeploy rollback marker `20260525T024645Z` and confirmed health checks passing. |
| 2026-06-08 | `2026-06-08-redeploy-bilimbaga-test-001` | T-0079: Force-recreated all three bilimbaga-test containers via `redeploy-test.sh`; git pull was a no-op (main still at fc02903); both images rebuilt from cache; rollback tags `bilimbaga-test:rollback-20260608` and `bilimbaga-api-test:rollback-20260608` created; health check HTTP 200 confirmed on-host and via Cloudflare. |
| 2026-06-08 | `2026-06-08-redeploy-bilimbaga-test-002` | T-0080: Deployed BilimBaga test from git ref `fc02903` to `b349bb2` (17 files, ISS-027 fix: blank page for employees with expired exams); rebuilt `bilimbaga-test:latest` (sha256:c99e48f6) and `bilimbaga-api-test:latest` (sha256:d73b74e2); all three containers force-recreated; health check HTTP 200 on-host and via Cloudflare. |
| 2026-06-10 | `2026-06-10-redeploy-bilimbaga-test-001` | T-0081: Deployed BilimBaga test from git ref `b349bb2` to `a9879ad` (27 commits, 293 files changed); rebuilt `bilimbaga-test:latest` (sha256:430db406ae6f) and `bilimbaga-api-test:latest` (sha256:3d1b53a16a04); rollback tags `bilimbaga-test:rollback-20260610` and `bilimbaga-api-test:rollback-20260610` created; all three containers force-recreated; health check HTTP 200 on-host and via Cloudflare. |
| 2026-06-27 | `2026-06-27-discovery-host-001` | Added new top-level `## ubuntu-16gb-nbg1-1` section: freshly provisioned Ubuntu 26.04 cloud image; Docker not installed; nginx not installed; only stock cloud-image systemd units (ssh, chrony, qemu-guest-agent, unattended-upgrades, cloud-init, snapd, apparmor, systemd-resolved) plus the `ufw` binary (inactive). No cron jobs, no app-backup timer, no certbot timer. Host stub → populated. |
| 2026-06-27 | `2026-06-27-install-fail2ban-001` | Added `fail2ban.service` row to the `## ubuntu-16gb-nbg1-1` Native systemd services table. Updated `ufw.service` row description from "Enabled but inactive" to "Enabled and active" with the T-0083 rule set. fail2ban 1.1.0-9 installed and active on the host; sshd jail enabled per host landscape file; iptables `f2b-sshd` chain present. Task T-0084 closed done/succeeded. |
| 2026-07-08 | `2026-07-08-discovery-pro-data-tech-qa-001` | Added new top-level `## pro-data-tech-qa` section: freshly provisioned Ubuntu 26.04 cloud image on pro-data.tech provider (95.46.211.230); Docker not installed; nginx not installed; sshd at cloud-init defaults; UFW inactive; no fail2ban; no operator users; only stock cloud-image systemd units (ssh, chrony, qemu-guest-agent, unattended-upgrades, cloud-init, snapd, apparmor, systemd-resolved) + 14 stock units. Host stub → populated. Re-created 7 task files (T-0090, T-0093, T-0094, T-0095, T-0096, T-0097, T-0098) lost in the 2026-07-07 secrets-inventory scrub. |
| 2026-07-08 | `2026-07-08-harden-sshd-pro-data-tech-qa-001` | pro-data-tech-qa | sshd hardening complete (T-0093) |
| 2026-07-08 | `2026-07-08-install-ufw-pro-data-tech-qa-001` | pro-data-tech-qa | UFW firewall installed and active (T-0094); deny-in/allow-out/forward-DROP/IPv6-on; 22/tcp allowed from any source; DEFAULT_FORWARD_POLICY=DROP divergence documented for T-0090 Docker install |
| 2026-07-08 | `2026-07-08-create-operator-users-pro-data-tech-qa-001` | pro-data-tech-qa | operator users created (tvolodi, viktor_d, binali_r) — T-0097 done |
| 2026-07-08 | `2026-07-08-install-fail2ban-pro-data-tech-qa-001` | pro-data-tech-qa | fail2ban installed (T-0095) |
| 2026-07-08 | `2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001` | pro-data-tech-qa | Docker 29.6.1 + Compose v5.3.1 installed; UFW FORWARD policy reconciled DROP→ACCEPT; ai-qadam-test QA postgres container `ai-qadam-test-db-1` running healthy on `127.0.0.1:3112` → `5432`; 10/10 V-checks PASSED (T-0090 Phases A–E). app container + nginx + public HTTPS deferred to T-0090a. |
| 2026-07-10 | `2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001` | pro-data-tech-qa | T-0099 done — 9 apt upgrades applied (incl. linux-image-7.0.0-27-generic + tzdata 2026b + curl/libcurl 8.18.0-1ubuntu2.3 + ubuntu-kernel-accessories/minimal/server/standard 1.570.1); host rebooted into 7.0.0-27-generic (downtime 6m 44s); pre-reboot pg_dump + etc-snapshot preserved at `/var/backups/pre-T0099.20260710T061200Z/`; 4 phased-rollout packages (fwupd/libfwupd3/python3-software-properties/software-properties-common) remain in upgradable queue — Ubuntu's phased-update design, will land on next unattended-upgrades cycle. |
| 2026-07-10 | `2026-07-10-enable-auditd-on-pro-data-tech-qa-001` | pro-data-tech-qa | T-0096 done — auditd 1:4.1.2-1build1 + audispd-plugins installed; project CIS-derived ruleset (15 keys, 67 kernel rules) loaded via `augenrules --load` from `/etc/audit/rules.d/audit.rules`; daemon `active`+`enabled`; kernel audit subsystem loaded (`CONFIG_AUDIT=y` built-in to kernel 7.0.0-27-generic, `kauditd` kthread running); 8/9 V-checks PASS, 1 PARTIAL (V07 — USER_AUTH + EXECVE event-classes absent due to NOPASSWD sudo + key-only SSH; operator-launched commands ARE recorded as `type=SYSCALL` records with `auid=1001` and `key="exec"`); pre-install snapshot at `/var/backups/pre-T0096.20260710T123137Z/`; in-place `stime` syscall fix applied (kernel 7.x retired `-S stime`; `adjtimex`/`settimeofday`/`clock_settime` cover time-change); immutable flag (`-e 2`) deferred to follow-up T-0096a after 24h soak. |
