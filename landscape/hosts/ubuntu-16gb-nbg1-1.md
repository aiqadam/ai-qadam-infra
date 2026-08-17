---
host_id: ubuntu-16gb-nbg1-1
provider: hetzner
role: letflow-app
last_verified: 2026-08-17
status: populated
hetzner_server_name: ubuntu-16gb-nbg1-1
hetzner_server_id: 145542849
hetzner_project_id: 15130993
hetzner_server_type: CX43
hetzner_project_name: ai-qadam
ssh_user: tvolodi
ssh_port: 22
os: ubuntu-26.04
kernel: 7.0.0-22-generic
---

# ubuntu-16gb-nbg1-1

The second Hetzner Cloud server, leased by the user on 2026-06-27 in Hetzner project "ai-qadam" (project id `15130993`). `role: letflow-app` (assigned 2026-08-17 via task [T-0134](../../tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md) — host readiness for the `letflow` project; app-level deploy is a follow-on task not yet created). Docker Engine + Compose plugin are installed; sshd is hardened to the fleet-standard `AllowGroups sshusers` pattern; UFW is active (deny-by-default + allow 22/80/443); no application containers deployed yet. The host is protected by Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`) carrying 3 rules as of 2026-08-17: TCP 22 open to `0.0.0.0/0`+`::/0` (intentionally left world-open per explicit user decision — see "Hetzner Cloud Firewall" section below), TCP 80 and TCP 443 newly open to `0.0.0.0/0`+`::/0`. Parent inventory task [T-0082](../../tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md) closed 2026-06-27.

## Hardware & OS

Verified by discovery run `2026-06-27-discovery-host-001` (probes B, C).

- **Public IPv4:** `46.225.239.60`
- **Public IPv6:** `2a01:4f8:1c1c:5959::/64`
- **Hostname:** `ubuntu-16gb-nbg1-1`
- **Server type:** CX43 (Hetzner Cloud)
- **vCPU / RAM:** 8 vCPU / ~15 GiB RAM visible inside (16 GiB allocated; no swap)
- **Disk:** 150 GiB `/dev/sda1` mounted on `/` (1.7 GiB used, 2%, 143 GiB free); 253 MiB `/dev/sda15` on `/boot/efi`
- **Location:** Nuremberg, Germany (`nbg1-dc3`, Hetzner datacenter DC3 in the `nbg1` location)
- **OS:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`, `ID=ubuntu`)
- **Kernel:** `7.0.0-22-generic` (`#22-Ubuntu SMP PREEMPT_DYNAMIC Mon May 25 15:54:34 UTC 2026 x86_64`)
- **Virtualization:** KVM / QEMU (confirmed via `qemu-guest-agent.service` running)
- **Hetzner Backups option:** **NOT enabled** (`backup_window=""` per `GET /v1/servers/145542849` 2026-06-27 — Hetzner daily snapshots are off; confirmed incidentally by run `2026-06-27-audit-hetzner-firewall-001`, out of scope for that run).
- **Hetzner Cloud Firewall:** **APPLIED, 3 rules as of 2026-08-17.** Project `15130993` contains firewall `ai-qadam-mgmt-ssh` (id `11204449`), scoped to server `145542849` (`ubuntu-16gb-nbg1-1`). Inbound rules: TCP 22 from `0.0.0.0/0`+`::/0` (world-open — see below), TCP 80 from `0.0.0.0/0`+`::/0`, TCP 443 from `0.0.0.0/0`+`::/0`. Hetzner default outbound (allow all) — no customization. Ports 80/443 opened and port 22 reconfirmed world-open 2026-08-17 via run [`2026-08-17-prepare-letflow-host-001`](../../runs/2026-08-17-prepare-letflow-host-001/) (task [T-0134](../../tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md), now done). See "Hetzner Cloud Firewall" section below for full details.
- **Server protection flags:** `protection.delete=True`, `protection.rebuild=True` (Hetzner defaults were `false`/`false`; enabled 2026-06-27 by the same run as defense-in-depth against accidental destruction).
- **Cost:** €15.99 / month (from Hetzner console at bootstrap)

## Access

Verified by discovery run `2026-06-27-discovery-host-001` (probes A, D, E, A.1) unless otherwise noted; superseding facts as of run `2026-08-17-prepare-letflow-host-001` (task T-0134) are noted inline.

- **SSH user:** `tvolodi` (uid 1000, primary group `tvolodi`, secondary groups `sudo`, `users`)
- **SSH host (this project's key targets):** `tvolodi@46.225.239.60`
- **SSH config alias on management workstation:** `Host ubuntu-16gb-nbg1-1` in `C:\Users\tvolo\.ssh\config` — invoke as `ssh ubuntu-16gb-nbg1-1`. Uses the same project key (`~/.ssh/ai-dala-infra`) and `IdentitiesOnly yes`.
- **SSH key (management workstation):** `C:\Users\tvolo\.ssh\ai-dala-infra` (ed25519, no passphrase). Public key fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`. Full public key in [`../secrets-inventory.md`](../secrets-inventory.md).
- **SSH key installed on server:** yes — present in `/home/tvolodi/.ssh/authorized_keys`. Note: contains **two duplicate lines** for the same ed25519 key (likely from bootstrap re-runs); harmless but worth deduplicating in a future cleanup.
- **Sudo:** passwordless via `/etc/sudoers.d/90-tvolodi` (content: `tvolodi ALL=(ALL) NOPASSWD:ALL`, mode `0440`, owner `root:root`, mtime `2026-06-27 04:46`). Cloud-init default `/etc/sudoers.d/90-cloud-init-users` (`root ALL=(ALL) NOPASSWD:ALL`) also present — harmless duplication for root.
- **Root login:** Cloud-init default `/etc/sudoers.d/90-cloud-init-users` grants root passwordless sudo locally. SSH daemon has `PermitRootLogin yes` (default), but `/root/.ssh/` is empty — root cannot SSH in. Root access is via local console (Hetzner web console) or `sudo` from `tvolodi`.
- **Other local users (uid >= 1000 or login shell):** `root`, `nobody`, `tvolodi`, `viktor_d` (uid 1001), `binali_r` (uid 1002). `viktor_d`/`binali_r` were provisioned out-of-band on 2026-06-27 (undocumented in this repo until discovered 2026-08-17 by run `2026-08-17-prepare-letflow-host-001` — see [T-0135](../../tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md)); both accounts are now **expired + password-locked (not deleted)** as of 2026-08-17 (task T-0134): `usermod -e 1` (expiry in the past) + `usermod -L` applied to both; home directories `/home/viktor_d`, `/home/binali_r`, uids/gids/group memberships (`sudo`, `users`) all preserved untouched. Neither account is a member of `sshusers` (see sshd hardening below) — SSH login is not possible for either. Reversal path (re-enable expiry + unlock password) is documented in `runs/2026-08-17-prepare-letflow-host-001/step-04-solution-designer.md` Rollback section but was not executed.
- **Host fingerprints (known_hosts entries on management workstation):**
  - RSA `SHA256:pNGyU7GiFCZ0QNqi9myVa8TB7dN0mrLzQqWCDuMdtls`
  - ECDSA `SHA256:0OuNLbfFiqFCJd54IGcPTWlBNKw3KpoRMGqQBN353fs`
  - ED25519 `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`
- **SSH daemon config (sshd -T effective, 2026-08-17, post T-0134):** `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PubkeyAuthentication yes`, `PermitEmptyPasswords no`, `UseDNS no`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, `AllowGroups sshusers` (no `AllowUsers` line). KexAlgorithms/Ciphers/MACs match the fleet-standard pattern (T-0093/T-0102 on `pro-data-tech-qa`/`pro-data-tech-prod`) — no SHA-1, no CBC/3DES, no post-quantum KEX entries. This fleet-standard hardening (applied 2026-08-17 via task T-0134) **replaces** an out-of-band hardening pass discovered live during T-0134's execution: a drop-in labeled `T-0087` (`# Managed by ai-dala-infra. T-0087.`) had already applied `PermitRootLogin no`, `AllowUsers tvolodi viktor_d binali_r`, `MaxAuthTries 6`, `LoginGraceTime 120`, and post-quantum KEX algorithms (`mlkem768x25519-sha256`, `sntrup761x25519-sha512`) on 2026-06-27 — no task or run for `T-0087` exists anywhere in this repo. See [T-0135](../../tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md) for the open investigation into its origin.
- **sshd drop-in files (`/etc/ssh/sshd_config.d/`, as of 2026-08-17):** first-wins semantics (lexicographic order; first occurrence of a directive wins)
  - `40-ai-dala-infra.conf` — fleet-standard hardening directives (`PermitRootLogin prohibit-password`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, `AllowGroups sshusers`, tightened KexAlgorithms/Ciphers/MACs). Created 2026-08-17 (T-0134).
  - `40-disable-password.conf` — sets `PasswordAuthentication no` / `KbdInteractiveAuthentication no`. Rewritten idempotently 2026-08-17 (T-0134) — content unchanged from the pre-existing `T-0087`-authored file of the same name.
  - `50-cloud-init.conf` — sets `PasswordAuthentication yes` (cloud-init managed; overridden by the two drop-ins above, which sort first).
  - `40-ssh-hardening.conf` (the `T-0087`-labeled `AllowUsers tvolodi viktor_d binali_r` file) and its `.bak.20260627T145652Z` sibling — **removed 2026-08-17 (T-0134)**, backed up on-host at `/var/backups/pre-T0134.20260817T051919Z/` (full `/etc/ssh` copy) and `/var/backups/pre-T0134.20260817T051919Z/40-ssh-hardening.conf.removed` (explicit copy), not merely deleted.
- **`sshusers` group (created 2026-08-17, T-0134):** gid 1003, members `tvolodi`+`root` only. `viktor_d`/`binali_r` explicitly excluded (see Access section account note above).
- **SSH hardening tooling on host:** fail2ban 1.1.0-9 installed and active; sshd jail enabled (maxretry=3, bantime=600s, findtime=600s, ignoreip includes 178.89.57.135 (management workstation for this host), banaction=iptables-multiport); config: `/etc/fail2ban/jail.d/sshd.local` (169 bytes, 0644 root:root, mtime 2026-06-27 06:13). 2 IPs already banned at install (2026-06-27): `14.103.127.232`, `45.148.10.240` (journal-history import from SSH brute-force scanners on port 22). iptables `f2b-sshd` chain present (`tcp, multiport dports 22`). Service active + enabled at boot; reconfirmed active 2026-08-17 (T-0134) — its role as the operative brute-force defense is heightened now that port 22 is confirmed world-open at the Hetzner Cloud Firewall layer (see "Hetzner Cloud Firewall" section). **auditd not installed**. AppArmor loaded with 180 profiles (104 in enforce mode — Ubuntu default).

## What runs here

See [`../services.md`](../services.md) for the canonical per-host tables. High-level: **Docker Engine + Compose plugin installed and active (2026-08-17, T-0134); no application containers deployed yet; no nginx**. No Compose projects on disk.

### Native systemd services of note (this host)

| Unit | Path | User | What it does |
|---|---|---|---|
| `ssh.service` | (package default) | root | sshd — hardened 2026-08-17 (T-0134), see "Access" section |
| `docker.service` | (apt package) | root | Docker Engine 29.7.2 — active, enabled. Installed 2026-08-17 (T-0134) |
| `chrony.service` | (package default) | root | NTP client (Ubuntu 26.04 default, replacing legacy systemd-timesyncd) |
| `unattended-upgrades.service` | (package default) | root | Automatic security upgrades (security + ESM channels only — see "apt posture" below) |
| `qemu-guest-agent.service` | (package default) | root | Hetzner KVM guest agent |
| `cloud-init.{local,network,main,config,final}.service` | (package default) | root | Cloud-init bootstrap stages |
| `snapd.service` | (snap default) | root | Snap daemon |
| `apparmor.service` | (package default) | root | AppArmor MAC (180 profiles loaded, 104 enforce) |
| `systemd-resolved.service` | (package default) | root | Local DNS stub on 127.0.0.53 / 127.0.0.54 |
| `rsyslog.service`, `cron.service`, `atd.service`, `polkit.service`, `dbus.service`, `multipathd.service`, `systemd-{journald,logind,networkd,udevd}.service`, `user@{0,1000}.service`, `getty@tty1.service`, `serial-getty@ttyS0.service` | (package defaults) | root | Standard Ubuntu cloud-image base |

## Network

Verified by discovery run `2026-06-27-discovery-host-001` (probes F, G).

- **Cloudflare proxied:** no — this host has no DNS or proxied zones yet.
- **Host firewall (UFW):** active and enabled at boot as of 2026-06-27 (run `2026-06-27-configure-ufw-001` / T-0083). `IPV6=yes` in `/etc/default/ufw` so v4 + v6 rules apply. Backed up pre-change state at `/etc/default/ufw.bak` (mode 0644, owner root:root, 1897 bytes; mtime preserved from the original Dec 6 2025 file).
- **UFW defaults:** deny (incoming), allow (outgoing). `DEFAULT_FORWARD_POLICY="ACCEPT"` preserved in `/etc/default/ufw` for Docker parity with `hetzner-prod`. Because IP forwarding is currently disabled on this host (`/proc/sys/net/ipv4/ip_forward=0`, `/proc/sys/net/ipv6/conf/all/forwarding=0`), UFW renders the FORWARD policy as `disabled (routed)` in `ufw status verbose` — this is correct UFW behavior; the `ACCEPT` value will activate the moment IP forwarding is enabled (e.g., when Docker is installed).
- **UFW ruleset (as of 2026-06-27, reconfirmed unchanged 2026-08-17 by T-0134):** allow 22/tcp (v4+v6), allow 80/tcp (v4+v6), allow 443/tcp (v4+v6). Six rules total. systemd: `ufw.service` `UnitFileState=enabled`, `ActiveState=active` (the `exited` sub-state is normal for `ufw.service` — the service starts and exits after handing off to the iptables backend). Persistence across `sudo reboot` verified live by step 13 of run `2026-06-27-configure-ufw-001`. The Hetzner Cloud Firewall sits in front of UFW in the network path (public internet → Hetzner Cloud Firewall → UFW → fail2ban → sshd). As of 2026-08-17 (T-0134), the Hetzner Cloud Firewall allows TCP 22/80/443 all from `0.0.0.0/0`+`::/0` (see "Hetzner Cloud Firewall" section) — UFW is the same allow set at the host layer (defense-in-depth for 22, primary filter for 80/443 pending nothing yet listening on those ports).
- **Docker UFW bypass:** Docker installed 2026-08-17 (T-0134); no `after.rules` DOCKER-USER/MASQUERADE block was needed — live container-egress test passed without it (`docker run --rm alpine:3.20 ... wget https://api.ipify.org` returned the host's own public IP). `/etc/ufw/after.rules` unmodified.
- **External probe (2026-06-27, from management workstation):** `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True`. Ports 80 and 443 returned `TcpTestSucceeded: False` with immediate RST (no listener bound — UFW allows, host stack responds; at that time the Hetzner Cloud Firewall also blocked 80/443 at the cloud edge). Port 21 returns `False` with timeout (UFW drops). Re-probed 2026-08-17 post-T-0134: ports 80/443 still `TcpTestSucceeded: False` (no listener — expected, no app deployed yet) but now clear the Hetzner Cloud Firewall (which now allows them), so completion is a faster host-stack RST rather than a cloud-edge drop; port 22 remains `True` throughout.
- **TCP listeners on 0.0.0.0 (reachable from internet, filtered by UFW allow rules):**

  | Port | Process | Purpose | Status |
  |---|---|---|---|
  | 22 | sshd | management | expected; UFW ALLOW IN (v4+v6); hardened 2026-08-17 (T-0134) — key-only auth, `AllowGroups sshusers` |

- **TCP listeners on 127.0.0.1 only:** `127.0.0.53:53` and `127.0.0.54:53` (systemd-resolved stub).
- **UDP:** `127.0.0.53:53` and `127.0.0.54:53` (systemd-resolved), `46.225.239.60%eth0:68` (DHCP client), `127.0.0.1:323` and `[::1]:323` (chronyd).

## Hetzner Cloud Firewall

- **Status:** APPLIED, 3 rules as of 2026-08-17 (T-0134). Project 15130993 contains firewall `ai-qadam-mgmt-ssh` (id `11204449`), scoped to server `145542849` (`ubuntu-16gb-nbg1-1`).
- **Inbound rules (as of 2026-08-17):**
  - TCP 22 from `0.0.0.0/0` + `::/0` — **intentionally world-open**, per explicit user decision ("Leave it open to anywhere") given during run `2026-08-17-prepare-letflow-host-001`. This rule was found already widened from its original `178.89.57.135/32` scope when the run's Phase 0 live-state check queried the API — the widening is dated 2026-06-27 per the rule's own `description` field and has no corresponding task or run record anywhere in this repo (see [T-0135](../../tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md)). T-0134 reconfirmed/preserved this state rather than narrowing it back, and updated the rule's `description` to record the reconfirmation. Mitigating layers: UFW does not restrict port 22 by source IP either; `fail2ban` is active; `PasswordAuthentication no` is enforced host-wide (key-only auth).
  - TCP 80 from `0.0.0.0/0` + `::/0` — newly opened 2026-08-17 (T-0134), for the planned Letflow application deployment.
  - TCP 443 from `0.0.0.0/0` + `::/0` — newly opened 2026-08-17 (T-0134), for the planned Letflow application deployment.
- **Outbound rules:** Hetzner default (allow all outbound).
- **Labels:** `managed-by=ai-dala-infra`, `purpose=ssh-management-only`, `host=ubuntu-16gb-nbg1-1` (label unchanged by T-0134; now stale given the firewall's expanded scope beyond SSH-only — not corrected as part of this run).
- **Created:** 2026-06-27T07:14:31Z (originally created during run `2026-06-27-apply-hetzner-firewall-001` attempt 1; applied during attempt 3 of the same run). Rule set updated 2026-08-17 via run [`2026-08-17-prepare-letflow-host-001`](../../runs/2026-08-17-prepare-letflow-host-001/) (task T-0134).
- **Hetzner API verified:** `GET /v1/firewalls/11204449` confirms the firewall carries exactly the 3 rules above and remains applied to server `145542849`, independently reconfirmed 2026-08-17 by both the executor and the execution-validator.
- **Server protection flags enabled:** `protection.delete=true`, `protection.rebuild=true`. Defense-in-depth against accidental destruction.
- **Lockout mitigation:** SSH allow-rule is world-open at the cloud-firewall layer as of 2026-08-17 (see above); UFW similarly does not restrict by source IP. Hetzner Cloud Console direct console access (KVM-over-IP) remains available as a fallback regardless of the Cloud Firewall's port-22 CIDR.

## Backups

Verified by discovery run `2026-06-27-discovery-host-001` (probe N). Hetzner Backups option status updated 2026-06-27 by run [`2026-06-27-audit-hetzner-firewall-001`](../../runs/2026-06-27-audit-hetzner-firewall-001/) probe C (incidental capture): `backup_window=""` per `GET /v1/servers/145542849` — option is NOT enabled.

- **Hetzner snapshot backups:** **NOT enabled** (`backup_window=""` — confirmed 2026-06-27 by Hetzner Cloud API). **Policy: paid Hetzner Backups + any other paid Hetzner add-ons are out of scope** (declared 2026-06-27); backups stay on local disk only. See [README § Backups & storage policy](../README.md#backups--storage-policy). Cf. [hetzner-prod](../hosts/hetzner-prod.md) for the same finding on the prod host (tracked as `wontfix` [T-0001](../../tasks/T-0001-enable-hetzner-snapshots.md)).
- **Application-level backups:** **none configured**. No `/usr/local/bin/app-backup.sh`, no `/var/backups/app/` staging, no `app-backup.timer`. No restic / borg / duplicity installed. `/var/backups/` empty. Only stock `dpkg-db-backup.timer` runs daily.
- **No data to back up yet:** this host has no databases, no Compose volumes, no application state (Docker is installed as of 2026-08-17, T-0134, but no application containers are deployed). Backup strategy will be defined once the Letflow application is deployed. Local-disk application-level backups will be the strategy (consistent with the project-wide [Backups & storage policy](../README.md#backups--storage-policy)).

## apt posture

Verified by discovery run `2026-06-27-discovery-host-001` (probe L).

- **Pending upgrades:** 13 (as of 2026-06-27 04:48; one `apt upgrade` already ran during cloud-init bootstrap at 04:48:19; the 13 remaining are normal for a fresh 26.04 image and will mostly resolve after the first unattended-upgrade cycle).
- **unattended-upgrades:** active and enabled.
- **Allowed-Origins:** `${distro_id}:${distro_codename}`, `${distro_id}:${distro_codename}-security`, `${distro_id}ESMApps:${distro_codename}-apps-security`, `${distro_id}ESM:${distro_codename}-infra-security`. **`-updates` channel NOT included** (matches `hetzner-prod`'s pre-2026-05-12 state).
- **`Unattended-Upgrade::DevRelease "auto"`** — Ubuntu default; on Ubuntu 26.04 (codename `resolute`) this may pull in pre-release updates. Informational; user decision required if stable-only is desired.
- **Sources:** deb822 format at `/etc/apt/sources.list.d/ubuntu.sources`; `/etc/apt/sources.list` is comment-only.

## Open questions

- **Canonical short `host_id`:** T-0082's "Notes" raises whether to rename `ubuntu-16gb-nbg1-1` → `hetzner-2` for consistency with `hetzner-prod`. Decision is the user's; not changed unilaterally.
- **ED25519 fingerprint on management workstation's `known_hosts`:** already recorded via `StrictHostKeyChecking=accept-new`; should be reconciled against `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`. RSA and ECDSA fingerprints above are now added to the local `known_hosts` by a follow-up step (out of scope for this landscape-update step).

## What needs to happen

1. ✅ **SSH access from management workstation.** Done — `tvolodi` user + project key installed, SSH config alias added.
2. ✅ **Hetzner Cloud Firewall.** Audit complete 2026-06-27 via run [`2026-06-27-audit-hetzner-firewall-001`](../../runs/2026-06-27-audit-hetzner-firewall-001/); firewall `ai-qadam-mgmt-ssh` (id `11204449`) **applied** 2026-06-27 via run [`2026-06-27-apply-hetzner-firewall-001`](../../runs/2026-06-27-apply-hetzner-firewall-001/). Single inbound rule: TCP 22 from management workstation outbound IP `178.89.57.135/32`. Server protection flags `protection.delete=true` + `protection.rebuild=true` enabled in the same run as defense-in-depth. Tasks [T-0085](../../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) and [T-0086](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) **done**.
3. ✅ **OS-level firewall (UFW).** Configured 2026-06-27 via run `2026-06-27-configure-ufw-001` — deny-by-default + allow 22/80/443 (v4+v6), `DEFAULT_FORWARD_POLICY="ACCEPT"` for Docker parity, persistence across reboot verified. Task [T-0083](../../tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md) **done**.
4. ✅ **sshd hardening** for parity with `hetzner-prod`. Done — fleet-standard pattern applied 2026-08-17 via run [`2026-08-17-prepare-letflow-host-001`](../../runs/2026-08-17-prepare-letflow-host-001/): `PasswordAuthentication no`, `PermitRootLogin prohibit-password`, `AllowGroups sshusers`, no SHA-1 MACs, explicit KexAlgorithms/Ciphers, project-managed `40-disable-password.conf` + `40-ai-dala-infra.conf` drop-ins. This also reconciled an out-of-band `T-0087`-labeled hardening pass discovered live during this run — see "Access" section and [T-0135](../../tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md). Task [T-0134](../../tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md) **done**.
5. ✅ **fail2ban** install for parity with `hetzner-prod`. Done — fail2ban 1.1.0-9 installed 2026-06-27 via run `2026-06-27-install-fail2ban-001`; sshd jail active with maxretry=3 / bantime=600s / findtime=600s; ignoreip includes management workstation outbound IP `178.89.57.135` (NOT the prod value `5.250.151.158` — distinct network). Task [T-0084](../../tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md) **done**.
6. ✅ **Role assignment.** Done — `role: letflow-app` set 2026-08-17 via task [T-0134](../../tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md). Docker Engine + Compose plugin installed; Hetzner Cloud Firewall opened for 80/443. Application-level deploy (Cloudflare DNS, nginx vhost, `shared/app-registry.md` registration, first Letflow deploy) is a follow-on task, not yet created.
7. ✅ **Hetzner snapshot backups policy.** User decision 2026-06-27: **paid Hetzner Backups option is intentionally NOT enabled** — all backups stay on local disk only; no paid Hetzner add-ons. Policy canonically stated in [README § Backups & storage policy](../README.md#backups--storage-policy). This host aligns with [hetzner-prod](../hosts/hetzner-prod.md) and the existing `wontfix` [T-0001](../../tasks/T-0001-enable-hetzner-snapshots.md); not promoted to a separate task.

## Open tasks affecting this host

Pending work that affects this host is tracked in [`tasks/`](../../tasks/). For the current open set with priorities and statuses see [`tasks/_index.md`](../../tasks/_index.md). The following tasks reference this host's landscape file:

- [T-0082](../../tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md) — Add new Hetzner server ubuntu-16gb-nbg1-1 to inventory and run discovery — **done** (closed 2026-06-27; inventory populated, Hetzner Cloud Firewall audited + applied, UFW + fail2ban configured. Role assignment was out of scope at the time; role has since been set — see T-0134.)
- [T-0083](../../tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md) — Configure UFW on ubuntu-16gb-nbg1-1 (deny-by-default, allow 22/80/443) — observation
- [T-0084](../../tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md) — Install fail2ban with SSH default jail on ubuntu-16gb-nbg1-1 — done (run 2026-06-27-install-fail2ban-001)
- [T-0085](../../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) — Audit Hetzner Cloud Firewall state for ubuntu-16gb-nbg1-1 (project ai-qadam) — done (run 2026-06-27-audit-hetzner-firewall-001)
- [T-0086](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) — Apply Hetzner Cloud Firewall to ubuntu-16gb-nbg1-1 (project 15130993) — done (run 2026-06-27-apply-hetzner-firewall-001; firewall `ai-qadam-mgmt-ssh` id `11204449` applied; server protection flags enabled)
- [T-0134](../../tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md) — Prepare ubuntu-16gb-nbg1-1 as an application host for Letflow (Docker, firewall, sshd hardening) — done (run 2026-08-17-prepare-letflow-host-001; `role: letflow-app` set, Docker installed, sshd hardened, Hetzner Cloud Firewall opened for 80/443)
- [T-0135](../../tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md) — Investigate undocumented 2026-06-27 changes on ubuntu-16gb-nbg1-1 (T-0087 sshd/account provisioning; Hetzner firewall port-22 widening) — observation

## Change log

| Date | Run ID | Change |
|---|---|---|
| 2026-06-27 | (manual bootstrap by orchestrator) | Stub created at user request, task T-0082 opened. Hetzner server name + IPv4 + IPv6 only — no SSH access verified, no firewall ID. |
| 2026-06-27 | (manual correction) | Hetzner IDs added from console screenshot: server_id=145542849, project_id=15130993 (project "ai-qadam"). Server type confirmed CX43 (8 vCPU / 16 GiB / 160 GB disk). Hetzner server_id, project_id, server_type, project_name populated in frontmatter. |
| 2026-06-27 | (manual correction) | Project name casing corrected from "Al-Qadam" (Hetzner Cloud Console display) to "ai-qadam" (canonical name used by this project's token naming and inventory references). Hetzner project name frontmatter value updated. Hetzner Cloud Firewall note updated to reference the new per-project token `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` (`C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`). |
| 2026-06-27 | (manual verification) | SSH access from management workstation verified (`tvolodi@46.225.239.60`, passwordless sudo OK). SSH config alias `ubuntu-16gb-nbg1-1` added. OS + kernel + uptime + sudoers.d state captured. Sudoers drop-in `/etc/sudoers.d/90-tvolodi` not yet present — cloud-init default in use. |
| 2026-06-27 | `2026-06-27-discovery-host-001` | Initial discovery run. Populated Hardware & OS, Access (incl. all three SSH host key fingerprints: RSA `SHA256:pNGyU7GiFCZ0QNqi9myVa8TB7dN0mrLzQqWCDuMdtls`, ECDSA `SHA256:0OuNLbfFiqFCJd54IGcPTWlBNKw3KpoRMGqQBN353fs`, ED25519 `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`), What runs here, Network, Backups, apt posture, Open questions, What needs to happen (item #4 retired — `/etc/sudoers.d/90-tvolodi` already created at bootstrap 2026-06-27 04:46; mtime confirmed by probe D). Status `stub` → `populated`. Per-host section added to [`../services.md`](../services.md). Observation task T-0083 (Configure UFW) created. |
| 2026-06-27 | `2026-06-27-configure-ufw-001` | Configured UFW: default-deny inbound, allow outbound, allow 22/80/443 (v4+v6); DEFAULT_FORWARD_POLICY="ACCEPT" for Docker parity; backup at /etc/default/ufw.bak (1897 bytes, 0644 root:root); verified post-reboot persistence; external probe (22=True, 80/443 RST-no-listener, 21 timeout-dropped) confirms active filtering. Task T-0083 closed done/succeeded. Network section rewritten; TCP listener table status updated; "What needs to happen" item #3 marked done. |
| 2026-06-27 | `2026-06-27-install-fail2ban-001` | Installed fail2ban 1.1.0-9 (Ubuntu 26.04 package; major-version bump from prod's 1.0.2-3ubuntu0.1); sshd jail enabled with maxretry=3, bantime=600s, findtime=600s, ignoreip includes management workstation outbound IP 178.89.57.135 (live-verified via api.ipify.org; distinct from prod's 5.250.151.158), banaction=iptables-multiport (backend: iptables 1.8.11 / nf_tables), config at /etc/fail2ban/jail.d/sshd.local. Service active and enabled at boot. 2 IPs banned at install (journal-history import from SSH brute-force scanners on port 22): 14.103.127.232, 45.148.10.240. iptables f2b-sshd chain present. Task T-0084 closed done/succeeded. SSH hardening tooling line updated; "What needs to happen" item #5 marked done. |
| 2026-06-27 | `2026-06-27-audit-hetzner-firewall-001` | Hetzner Cloud Firewall audit: project `ai-qadam` (id 15130993) has ZERO Cloud Firewalls (verified via `GET /v1/firewalls?project_id=15130993` → empty enumeration; all three URL variants checked). Server `ubuntu-16gb-nbg1-1` is exposed at the cloud layer with only UFW + fail2ban protection. Location updated `nbg1` → `nbg1-dc3` (Nuremberg DC3). `Hetzner Backups option` confirmed NOT enabled (`backup_window=""` per probe C, incidental). Server-side fields captured: `protection.delete=False`, `protection.rebuild=False`, `private_net=[]`, `created=2026-06-27T04:26:39Z`. New "Hetzner Cloud Firewall" section added above "Backups". Open questions items #1 (Cloud Firewall ID) and #2 (snapshot backups) resolved. "What needs to happen" items #2 and #7 updated to reflect audit results. Task T-0085 closed done/succeeded; new observation task T-0086 created. `landscape/secrets-inventory.md` updated with SHA-256 fingerprint of the per-project ai-qadam Hetzner token. |
| 2026-06-27 | `2026-06-27-apply-hetzner-firewall-001` | Applied Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`) — single inbound rule TCP 22 from `178.89.57.135/32`. Server protection flags enabled (`protection.delete=true`, `protection.rebuild=true`). Run `2026-06-27-apply-hetzner-firewall-001` succeeded after 3 attempts (two body-shape bugs in the design corrected mid-run). |
| 2026-06-27 (retroactive entry, discovered 2026-08-17) | none (no task/run record found anywhere in this repo) | **Undocumented out-of-band changes**, discovered live during Phase 0 of run `2026-08-17-prepare-letflow-host-001`: (1) an sshd hardening pass labeled `T-0087` in its own file comments applied `PermitRootLogin no`, `AllowUsers tvolodi viktor_d binali_r`, `MaxAuthTries 6`, `LoginGraceTime 120`, and post-quantum KexAlgorithms via `/etc/ssh/sshd_config.d/40-ssh-hardening.conf`, alongside provisioning of two new sudo-capable accounts `viktor_d` (uid 1001) and `binali_r` (uid 1002); (2) the Hetzner Cloud Firewall's port-22 rule was widened from `178.89.57.135/32` to `0.0.0.0/0`+`::/0`, self-described by its own `description` field as "widened 2026-06-27". Neither change has any corresponding task or run record in this repo. Both are tracked for investigation under new observation task [T-0135](../../tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md). |
| 2026-08-17 | `2026-08-17-prepare-letflow-host-001` | Task [T-0134](../../tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md) done. `role:` set to `letflow-app`. Locked (expired + password-locked, not deleted) the `viktor_d`/`binali_r` accounts discovered above. Reconciled the undocumented `T-0087` sshd hardening: removed `40-ssh-hardening.conf` (backed up), replaced with fleet-standard drop-ins `40-ai-dala-infra.conf` (`AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`, no PQ KEX) + idempotently-rewritten `40-disable-password.conf`; `sshusers` group created with `tvolodi`+`root` only. Installed Docker Engine 29.7.2 + Compose plugin v5.4.0 (active, enabled); live egress test passed, no `after.rules` change needed. Updated Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`) from 1 rule to 3: port 22 reconfirmed world-open (`0.0.0.0/0`+`::/0`, per explicit user decision — the widening discovered above is preserved, not reverted) plus newly-opened 80/443, both world-open. All changes independently verified by execution-validator (step 07 PASS). |