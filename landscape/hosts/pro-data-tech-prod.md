---
host_id: pro-data-tech-prod
provider: pro-data.tech
role: penpot-prod
last_verified: 2026-07-11
status: hardened
last_verified_note: T-0109 done 2026-07-11 — Penpot fully operational at https://penpot.aiqadam.org with MCP. nginx 1.28.3 + Let's Encrypt TLS active. Run 2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001, step-07 PASS.
ssh_user: tvolodi
ssh_port: 22
os: ubuntu-26.04
kernel: 7.0.0-14-generic
---

# pro-data-tech-prod

A pro-data.tech cloud VM (IPv4 `95.46.211.224`, hostname `drkkrgm-prod-instance`) added to the inventory on 2026-07-11. Provider is **pro-data.tech** (NOT Hetzner) — no Hetzner Cloud Firewall, no Hetzner API, no Hetzner Backups option; the host stands on its own with cloud-init defaults. Sister host `pro-data-tech-qa` (`95.46.211.230`) is on the same `/25` subnet and has been fully hardened (T-0093 through T-0099). Role: **penpot-prod** — hosts the Penpot 2.16 design tool (T-0108, 2026-07-11).

> **Security baseline complete + Penpot fully deployed (2026-07-11):** sshd hardened (T-0102), UFW active (T-0103), fail2ban active (T-0104), operator users provisioned (T-0105), Docker CE 29.6.1 (T-0106). **Penpot 2.16 deployed (T-0108, 2026-07-11) — 7 containers running, MCP enabled. nginx 1.28.3 + Let's Encrypt TLS active (T-0109, 2026-07-11) — https://penpot.aiqadam.org live.** Remaining items: auditd not installed (gap #4), pending package upgrades (gap #5).

Populated by discovery run [`2026-07-11-discovery-pro-data-tech-prod-001`](../../runs/2026-07-11-discovery-pro-data-tech-prod-001/).

## Hardware & OS

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes B, C).

- **Public IPv4:** `95.46.211.224` (provider: pro-data.tech, subnet `95.46.211.128/25`)
- **IPv6:** link-local only (`fe80::649a:e1ff:fe4e:baeb/64` on eth0); no global IPv6 assignment.
- **Hostname:** `drkkrgm-prod-instance` (provider-assigned; not project-controlled)
- **Server type:** **unknown**. pro-data.tech does not expose plan tier via in-host metadata; the canonical plan labels would need to be confirmed in the provider's control panel. From in-host enumeration: 16 vCPU, ~31 GiB RAM, 339 GB root disk — notably larger than the QA host (8 vCPU / 15 GiB / 145 GB).
- **vCPU / RAM:** 16 vCPU (`nproc=16`); ~31 GiB RAM total (972 MiB used, 28 GiB free); **no swap**.
- **Disk:** 339 GB `/dev/sda1` mounted on `/` (3.1 GB used, 1%, 336 GB available); 989 MB `/dev/sda13` for `/boot` (17%); 105 MB `/dev/sda15` for `/boot/efi` (7%).
- **CPU model:** Intel Xeon Platinum 8164 @ 2.00GHz.
- **Location:** **unknown**. pro-data.tech does not expose a datacenter label via in-host metadata. Verify in the provider console.
- **OS:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`, `ID=ubuntu`).
- **Kernel:** `7.0.0-14-generic` (cloud-image default; **two minor versions behind the QA host's `7.0.0-27-generic`**; 12 pending package upgrades outstanding — see apt posture below).
- **Virtualization:** KVM (`systemd-detect-virt: kvm`; `qemu-guest-agent.service` running).
- **Cost:** **unknown**; verify in the provider control panel.

## Access

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes A, D, E).

- **Primary SSH user:** `tvolodi` (uid 1000). Key comment: `ai-dala-infra-mgmt@tvolodi-2026-05-12` (ED25519), at `/home/tvolodi/.ssh/authorized_keys`. Management key: `C:\Users\tvolo\.ssh\ai-dala-infra`.
- **Break-glass SSH user:** `root` (uid 0). Key: `rsa-key-20260707` (RSA, provider-provisioned), at `/root/.ssh/authorized_keys`. Management key: `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk`. `PermitRootLogin prohibit-password` — key-only. Root remains in `sshusers` permanently.
- **SSH host (primary):** `tvolodi@95.46.211.224`
- **SSH host (break-glass):** `root@95.46.211.224`
- **SSH key (management workstation):** `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (OpenSSH-format RSA despite the misleading `.ppk` extension; file starts with `-----BEGIN RSA PRIVATE KEY-----`).
- **Sudo:** passwordless for `root` via `/etc/sudoers.d/90-cloud-init-users` (`root ALL=(ALL) NOPASSWD:ALL`; cloud-init default). Project-managed drop-ins: `/etc/sudoers.d/90-tvolodi`, `/etc/sudoers.d/90-viktor_d`, `/etc/sudoers.d/90-binali_r` (each: `<user> ALL=(ALL) NOPASSWD: ALL`, mode 0440, owner root). Full `visudo -c` parse: clean.
- **Local users:** `root` (uid 0), `tvolodi` (uid 1000), `viktor_d` (uid 1001), `binali_r` (uid 1002) — all login-capable with key-only auth. `nobody` (uid 65534, nologin).
- **Currently logged in (at discovery time):** no active sessions other than the probe session (`who` returned empty).
- **SSH daemon config (sshd -T effective, 2026-07-11 — HARDENED per T-0102):**

  | Parameter | Effective value |
  |---|---|
  | `permitrootlogin` | `prohibit-password` — key-only root; password login blocked |
  | `passwordauthentication` | `no` |
  | `kbdinteractiveauthentication` | `no` |
  | `pubkeyauthentication` | `yes` |
  | `permitemptypasswords` | `no` |
  | `allowgroups` | `sshusers` — members: root, tvolodi, viktor_d, binali_r |
  | `maxauthtries` | `3` |
  | `logingracetime` | `30` |
  | `x11forwarding` | `no` |
  | `clientaliveinterval` | `300` |
  | `clientalivecountmax` | `2` |
  | `usedns` | `no` |
  | `kexalgorithms` | `curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256` |
  | `ciphers` | `chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr` |
  | `macs` | `hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com` |

- **sshd drop-in files (`/etc/ssh/sshd_config.d/`):** three files present (first-wins alphabetical sort):
  - `40-disable-password.conf` — `PasswordAuthentication no`, `KbdInteractiveAuthentication no`. Mode 644, owner root. (project-managed, T-0102)
  - `40-ai-dala-infra.conf` — `PermitRootLogin`, `MaxAuthTries`, `LoginGraceTime`, `X11Forwarding`, `ClientAliveInterval`, `ClientAliveCountMax`, `AllowGroups`, hardened KexAlgorithms/Ciphers/MACs. Mode 644, owner root. (project-managed, T-0102)
  - `60-cloudimg-settings.conf` — `PasswordAuthentication yes` (cloud-init default; overridden by the 40- files above). Mode 644, unchanged.
- **sshusers group:** gid 1000, created by T-0102. Current members: `root`, `tvolodi`, `viktor_d`, `binali_r` (`sshusers:x:1000:root,tvolodi,viktor_d,binali_r`). Root is a permanent member for break-glass SSH access — not removed. `PermitRootLogin prohibit-password` remains in effect regardless of group membership.
- **Note on socket activation:** `ssh.service` is socket-activated (`TriggeredBy: ssh.socket`, `Loaded: ... disabled; preset: enabled`). This is normal for Ubuntu 26.04. `systemctl is-active sshd` returns `active`.

## What runs here

See [`../services.md`](../services.md) for the canonical per-host table. High-level: **Penpot 2.16 deployed (T-0108, 2026-07-11) — 7 Docker Compose containers running under project `penpot`; MCP enabled (`penpot-mcp` running); nginx 1.28.3 + Let's Encrypt TLS active (T-0109, 2026-07-11) — https://penpot.aiqadam.org live.** Docker CE 29.6.1 (T-0106).

## Penpot

Deployed by run `2026-07-11-deploy-penpot-pro-data-tech-prod-001` (T-0108, 2026-07-11). Penpot 2.16 design tool running as a 7-container Docker Compose stack under project name `penpot` at `/opt/penpot/`.

- **Compose directory:** `/opt/penpot/`
- **Compose file:** `/opt/penpot/docker-compose.yaml` (7891 bytes; 3 patches applied: mailcatch loopback-only, env var interpolation for PENPOT_FLAGS/PENPOT_PUBLIC_URI/PENPOT_SECRET_KEY)
- **Env file:** `/opt/penpot/.env` (mode 600, owner root; 3 keys: `PENPOT_SECRET_KEY`, `PENPOT_PUBLIC_URI`, `PENPOT_FLAGS`)
- **PENPOT_PUBLIC_URI:** `https://penpot.aiqadam.org`
- **PENPOT_FLAGS:** `enable-prepl-server enable-mcp`
- **Frontend port:** `0.0.0.0:9001 → 8080/tcp` — HTTP 200 confirmed on `localhost:9001`
- **Mailcatch:** `127.0.0.1:1080 → 1080/tcp` (loopback-only; internet exposure blocked)
- **MCP:** enabled — `penpot-penpot-mcp-1` container (`penpotapp/mcp:2.16`) running
- **nginx / HTTPS:** **ACTIVE** (T-0109, 2026-07-11). nginx 1.28.3 reverse proxy; vhost `/etc/nginx/sites-available/penpot.aiqadam.org` (symlinked to `sites-enabled`); TLS via Let's Encrypt (cert `/etc/letsencrypt/live/penpot.aiqadam.org/fullchain.pem`, expires 2026-10-09, intermediate CA `YE1`/Let's Encrypt, auto-renewal via `certbot.timer`). `https://penpot.aiqadam.org` — HTTP 200 confirmed from external workstation.
- **First admin user:** not yet created — run `docker exec -ti penpot-penpot-backend-1 python3 manage.py create-profile` (one-time step)
- **Docker volumes:** `penpot_penpot_postgres_v15`, `penpot_penpot_assets`

### Containers (2026-07-11, post-T-0108)

| Container | Image:tag | Port binding | Health | Purpose |
|---|---|---|---|---|
| `penpot-penpot-frontend-1` | `penpotapp/frontend:2.16` | `0.0.0.0:9001→8080/tcp` | Up | Web frontend |
| `penpot-penpot-backend-1` | `penpotapp/backend:2.16` | (internal) | Up | Application backend |
| `penpot-penpot-exporter-1` | `penpotapp/exporter:2.16` | (internal) | Up | Export service |
| `penpot-penpot-mcp-1` | `penpotapp/mcp:2.16` | (internal) | Up | MCP server (Model Context Protocol) |
| `penpot-penpot-postgres-1` | `postgres:15` | (internal) | Up (healthy) | PostgreSQL 15 database |
| `penpot-penpot-valkey-1` | `valkey/valkey:8.1` | (internal) | Up (healthy) | Valkey (Redis-compatible) cache |
| `penpot-penpot-mailcatch-1` | `sj26/mailcatcher:latest` | `127.0.0.1:1080→1080/tcp` | Up | Mail catcher (loopback-only) |

## nginx

**Installed and active** (T-0109, 2026-07-11). nginx 1.28.3.

- **Package:** `nginx 1.28.3-2ubuntu1.6` (Ubuntu apt)
- **Service:** `nginx.service` — `active` and `enabled`
- **Vhost:** `/etc/nginx/sites-available/penpot.aiqadam.org` (symlinked to `/etc/nginx/sites-enabled/penpot.aiqadam.org`)
- **Config:** HTTP→HTTPS redirect on port 80; HTTPS on port 443 with `client_max_body_size 367001600`; WebSocket proxy for `/ws/notifications` and `/mcp/ws`; SSE proxy for `/mcp/stream`; general proxy for `/` → `http://localhost:9001/`
- **TLS:** Let's Encrypt via certbot 4.0.0; cert at `/etc/letsencrypt/live/penpot.aiqadam.org/` (ECDSA, expires 2026-10-09, intermediate CA `YE1`); auto-renewal via `certbot.timer` (active)
- **Access URL:** `https://penpot.aiqadam.org` — HTTP 200 confirmed from external workstation (step-07 PASS)

## Network

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes F, G, supplemental network probe).

- **Cloudflare proxied:** no — this host is not behind any Cloudflare-fronted domain. `landscape/cloudflare.md` and `landscape/domains.md` cover only the Hetzner-backed `ai-dala.com` and `bizdala.com` zones; pro-data.tech is a separate provider with no DNS presence in this project.
- **Provider-level firewall:** **unknown**. pro-data.tech may or may not provide a control-plane firewall. Per project policy the host should rely on a **host-level firewall** (T-0103) for defense-in-depth.
- **Host firewall (UFW):** **ACTIVE** (T-0103, 2026-07-11). `ufw default deny incoming`, `ufw default allow outgoing`, `DEFAULT_FORWARD_POLICY="DROP"`. Rules: 22/tcp ALLOW IN Anywhere (v4+v6), 80/tcp ALLOW IN Anywhere (v4+v6), 443/tcp ALLOW IN Anywhere (v4+v6). Backup of pre-run defaults at `/var/backups/ufw-defaults-pre-T0103.bak`. **Docker UFW coexistence block appended to `/etc/ufw/after.rules` (T-0106, 2026-07-11):** DOCKER-USER filter chain (`-A DOCKER-USER -i eth0 -j RETURN`) + MASQUERADE nat rule (`-A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE`); backup at `/var/backups/ufw-after.rules-pre-T0106.bak`.
- **nftables:** empty ruleset.
- **ip6tables:** fully open (all chains `policy ACCEPT`, no rules).
- **Network interfaces:**

  | Interface | Address | Notes |
  |---|---|---|
  | `lo` | 127.0.0.1/8, ::1/128 | loopback |
  | `eth0` | 95.46.211.224/25 brd 95.46.211.255 | public internet; gateway 95.46.211.129 |
  | `eth1` | 192.168.0.3/24 brd 192.168.0.255 | **private LAN** — not present on the QA host; likely a provider-managed private network between prod and other servers in the same account. QA host's expected LAN address would be `192.168.0.x` on the same `/24`. |

- **Default route:** `default via 95.46.211.129 dev eth0`.
- **IPv6:** link-local only on eth0 (`fe80::649a:e1ff:fe4e:baeb/64`) and eth1 (`fe80::e82f:86ff:fef3:bb89/64`). No global IPv6 assignment.
- **TCP listeners on 0.0.0.0:**

  | Port | Process | UFW rule | Notes |
  |---|---|---|---|
  | 22 | sshd | **ALLOW IN** (T-0103) | sshd hardened (T-0102): key-only, `PermitRootLogin prohibit-password`, `PasswordAuthentication no` |
  | 80 | nginx | **ALLOW IN** (T-0103) | HTTP → HTTPS redirect for penpot.aiqadam.org (T-0109, 2026-07-11) |
  | 443 | nginx | **ALLOW IN** (T-0103) | HTTPS; TLS via Let's Encrypt; proxies to penpot `localhost:9001` (T-0109, 2026-07-11) |
  | 9001 | penpot-frontend (Docker) | No explicit UFW rule; Docker manages own iptables chains | Penpot frontend (T-0108). Port bound to 0.0.0.0 via Docker iptables bypass; nginx is the recommended entry point. |

- **TCP listeners on loopback only:** `127.0.0.53:53`, `127.0.0.54:53` (systemd-resolved); `127.0.0.1:1080` (penpot-mailcatch, T-0108).
- **UDP:** `127.0.0.54:53` and `127.0.0.53:53` (systemd-resolved), `127.0.0.1:323` and `[::1]:323` (chronyd).
- **Effective exposure today:** SSH port 22 (UFW ALLOW IN). nginx ports 80/443 (UFW ALLOW IN; nginx handles HTTP→HTTPS redirect and TLS for `penpot.aiqadam.org`). Penpot port 9001 bound to 0.0.0.0 via Docker iptables bypass (remains externally accessible; nginx is the recommended entry point). UFW: deny-incoming default; 22/tcp, 80/tcp, 443/tcp explicitly ALLOW IN.

## Security posture

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes E, F, M).

> **Host is hardened (2026-07-11).** T-0102 sshd, T-0103 UFW, T-0104 fail2ban, T-0105 operator users — all P1 tasks complete. Remaining gaps: auditd (gap #4) and pending package upgrades (gap #5).

### Security gaps (vs QA baseline)

| # | Severity | Gap | Target state (per QA baseline) | Current state | Tracked by |
|---|---|---|---|---|---|
| 4 | HIGH | auditd not installed | active, CIS ruleset | not present | (pending task) |
| 5 | HIGH | 12 pending package upgrades | 0 | 12 outstanding | (pending task) |

### AppArmor

Module loaded. 179 profiles loaded, 103 in enforce mode (stock Ubuntu 26.04 default — same count as QA host).

### fail2ban

**Installed and active** (T-0104, 2026-07-11). fail2ban 1.1.0-9. systemd service `fail2ban.service`: `active` and `enabled`. Jail: `[sshd]` — `bantime = 1h`, `findtime = 10m`, `maxretry = 5`, `ignoreip = 127.0.0.1/8 ::1`. Config: `/etc/fail2ban/jail.local`. Currently banned: 0 (at install time). Journal-based log matching: `_SYSTEMD_UNIT=ssh.service + _COMM=sshd`. Note: management workstation IP (`178.89.57.135`) not in `ignoreip` — localhost-only list per execution parameters; run `fail2ban-client unban 178.89.57.135` if needed.

### auditd

**Not installed.** `auditctl` not found.

### Operator users

Three operator accounts provisioned (T-0105, 2026-07-11). All have locked passwords (key-only auth), membership in `sudo` and `sshusers`, and NOPASSWD sudo via individual drop-ins. Verified: 16/16 checks passed (run `2026-07-11-create-operator-users-pro-data-tech-prod-001`, step-07 PASS).

| User | UID | GID | Home | Groups | Sudoers drop-in | Key comment |
|---|---|---|---|---|---|---|
| `tvolodi` | 1000 | 1001 | `/home/tvolodi` | `sudo`, `sshusers`, `docker` (gid 986) | `/etc/sudoers.d/90-tvolodi` (0440) | `ai-dala-infra-mgmt@tvolodi-2026-05-12` (ED25519) |
| `viktor_d` | 1001 | 1002 | `/home/viktor_d` | `sudo`, `sshusers` | `/etc/sudoers.d/90-viktor_d` (0440) | `viktor_d@ai-dala-infra-2026-06-27` (ED25519) |
| `binali_r` | 1002 | 1003 | `/home/binali_r` | `sudo`, `sshusers` | `/etc/sudoers.d/90-binali_r` (0440) | `binali_r@ai-dala-infra-2026-06-27` (ED25519) |

## Backups

- **Provider-level snapshots:** **unknown and intentionally not used** (per project policy — consistent with the Hetzner precedent; cf. `wontfix` [T-0001](../../tasks/T-0001-enable-hetzner-snapshots.md)).
- **Application-level backups:** **none configured**. No backup tools (restic, borg, duplicity) installed. No project backup directories.
- **Application data (T-0108, 2026-07-11):** Penpot Docker volumes: `penpot_penpot_postgres_v15` (PostgreSQL 15 database), `penpot_penpot_assets` (uploaded files). No automated backup strategy configured yet (follow-on task to be scheduled after T-0109).

## apt posture

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probe L).

- **Pending upgrades:** **12** (unattended-upgrades has not yet applied them; last apt activity `2026-07-07 11:23` UTC — cloud-init bootstrap).
- **unattended-upgrades:** active and enabled (daily cycle).
- **Allowed-Origins:** stock Ubuntu (`security`, `ESM apps`, `ESM infra`).
- **Sources:** deb822 format at `/etc/apt/sources.list.d/ubuntu.sources` (Ubuntu 26.04 stock). No third-party repositories.
- **Kernel:** `7.0.0-14-generic` — the same kernel version the QA host ran before T-0099 upgraded it to `7.0.0-27-generic`.

## Native systemd services (running)

21 services running at discovery time — all standard Ubuntu cloud-image base. No application services.

| Unit | User | What it does |
|---|---|---|
| `ssh.service` | root | sshd (HARDENED — T-0102; socket-activated via `ssh.socket`) |
| `ufw.service` | root | **Enabled and active** — deny-incoming default, allow outgoing, 22/tcp 80/tcp 443/tcp ALLOW IN (v4+v6), DEFAULT_FORWARD_POLICY="DROP". Configured 2026-07-11 via T-0103. |
| `fail2ban.service` | root | Brute-force protection — sshd jail enabled (`bantime=1h`, `findtime=10m`, `maxretry=5`, `ignoreip=127.0.0.1/8 ::1`); config at `/etc/fail2ban/jail.local`. Installed 2026-07-11 via T-0104. || `docker.service` | root | Docker Engine — active, enabled. CE 29.6.1, Compose plugin v5.3.1, containerd.io 2.2.6 as runtime. UFW after.rules DOCKER-USER coexistence block in place (T-0106, 2026-07-11). || `chrony.service` | root | NTP client (Ubuntu 26.04 default) |
| `unattended-upgrades.service` | root | Automatic security upgrades (daily) |
| `qemu-guest-agent.service` | root | pro-data.tech KVM guest agent |
| `cloud-init.{local,network,main,config,final}.service` | root | Cloud-init bootstrap stages |
| `snapd.service` | root | Snap daemon |
| `apparmor.service` | root | AppArmor MAC (179 profiles, 103 enforce) |
| `systemd-resolved.service` | root | Local DNS stub on 127.0.0.53 / 127.0.0.54 |
| `nginx.service` | root | nginx 1.28.3 reverse proxy — **active** and **enabled** (T-0109, 2026-07-11). HTTP→HTTPS redirect on port 80; HTTPS TLS termination on port 443 for `penpot.aiqadam.org`; proxies to `localhost:9001`. |
| `certbot.timer` | root | Let's Encrypt auto-renewal timer — **active** and **enabled** (T-0109, 2026-07-11). Renews cert for `penpot.aiqadam.org` before expiry (cert expires 2026-10-09). |
| `rsyslog.service`, `cron.service`, `dbus.service`, `fwupd.service`, `getty@tty1.service`, `ModemManager.service`, `multipathd.service`, `networkd-dispatcher.service`, `polkit.service`, `serial-getty@ttyS0.service`, `systemd-journald.service`, `systemd-logind.service`, `systemd-networkd.service`, `systemd-udevd.service`, `udisks2.service`, `user@0.service` | root | Standard Ubuntu cloud-image base |

Also present in the image but noted: `open-vm-tools.service` (enabled but not running — unusual for a KVM host; likely baked into the provider image alongside `qemu-guest-agent`).

## Open tasks affecting this host

Pending work that affects this host is tracked in [`tasks/`](../../tasks/). See [`tasks/_index.md`](../../tasks/_index.md) for the current open set.

No open P1 tasks for this host. Remaining maintenance gaps (auditd, pending package upgrades) are tracked in the security posture section above; tasks will be created when scheduled.

## Change log

| Date | Run ID | Change |
|---|---|---|
| 2026-07-11 | `2026-07-11-discovery-pro-data-tech-prod-001` | T-0101: Initial discovery run. Host populated with hardware, OS, access, network, firewall, sshd, security, and backup findings. State: fresh Ubuntu 26.04 cloud image, no project services, no Docker, no nginx, no host firewall, no fail2ban, no auditd. 5 CRITICAL/HIGH security gaps identified; tracked as T-0102 through T-0105. Notable: eth1 192.168.0.3/24 private LAN (absent on QA host). |
| 2026-07-11 | `2026-07-11-harden-sshd-pro-data-tech-prod-001` | T-0102: sshd hardened — PermitRootLogin prohibit-password, PasswordAuthentication no, KbdInteractiveAuthentication no, AllowGroups sshusers (root in sshusers; transitional until T-0105), MaxAuthTries 3, LoginGraceTime 30, X11Forwarding no, hardened KexAlgorithms/Ciphers/MACs. Drop-in files 40-disable-password.conf and 40-ai-dala-infra.conf created (mode 644). sshd reloaded; 25/25 checks passed. |
| 2026-07-11 | `2026-07-11-install-ufw-pro-data-tech-prod-001` | T-0103: UFW installed and activated — deny-incoming default, allow outgoing, 22/tcp 80/tcp 443/tcp ALLOW IN (v4+v6), DEFAULT_FORWARD_POLICY="DROP". Backup at /var/backups/ufw-defaults-pre-T0103.bak. Security gap #1 (UFW inactive/CRITICAL) resolved. |
| 2026-07-11 | `2026-07-11-install-fail2ban-pro-data-tech-prod-001` | T-0104: fail2ban 1.1.0-9 installed and activated — sshd jail enabled, bantime=1h, findtime=10m, maxretry=5, ignoreip=127.0.0.1/8 ::1, journal backend. Config at /etc/fail2ban/jail.local. Security gap #2 (fail2ban not installed/HIGH) resolved. |
| 2026-07-11 | `2026-07-11-create-operator-users-pro-data-tech-prod-001` | T-0105: Operator users tvolodi (uid 1000), viktor_d (uid 1001), binali_r (uid 1002) created — sshusers+sudo group membership, NOPASSWD sudoers drop-ins (mode 0440), ed25519 keys installed. Root remains in sshusers (break-glass, permanent). Security gap #3 (no operator users/HIGH) resolved. 16/16 checks passed. All P1 security tasks complete; security baseline established. |
| 2026-07-11 | `2026-07-11-install-docker-pro-data-tech-prod-001` | T-0106: Docker CE 29.6.1 + Compose plugin v5.3.1 installed from official Docker apt repo (keyring method, resolute stable channel). docker.service enabled+active. containerd.io 2.2.6 as runtime. UFW after.rules appended with DOCKER-USER coexistence block (eth0-scoped MASQUERADE 172.16.0.0/12); backup at /var/backups/ufw-after.rules-pre-T0106.bak. tvolodi added to docker group (gid 986). `docker run hello-world` verified. |
| 2026-07-11 | `2026-07-11-deploy-penpot-pro-data-tech-prod-001` | T-0108: Penpot 2.16 deployed via Docker Compose at /opt/penpot/ (7 containers: penpot-frontend, penpot-backend, penpot-exporter, penpot-mcp, penpot-postgres, penpot-valkey, penpot-mailcatch). MCP enabled. PENPOT_PUBLIC_URI=https://penpot.aiqadam.org. Frontend HTTP 200 on localhost:9001. Mailcatch bound to 127.0.0.1:1080. .env mode 600 (owner root). nginx+HTTPS pending (T-0109). |
| 2026-07-11 | `2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001` | T-0109: nginx 1.28.3 installed and active; vhost `/etc/nginx/sites-available/penpot.aiqadam.org` created (HTTP→HTTPS redirect, HTTPS TLS termination, WebSocket/SSE/general proxy to localhost:9001). Let's Encrypt cert obtained (ECDSA, expires 2026-10-09, CA YE1); certbot.timer active for auto-renewal. `https://penpot.aiqadam.org` confirmed HTTP 200 from external workstation. Penpot fully operational. |
