---
run_id: 2026-07-11-discovery-pro-data-tech-prod-001
step: 06
agent: executor-discovery
verdict: PASS
created: 2026-07-11T04:47:00Z
task_id: T-0101-add-pro-data-tech-prod-to-inventory
inputs_read:
  - runs/2026-07-11-discovery-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-discovery-pro-data-tech-prod-001/step-02-landscape-reader.md
  - runs/2026-07-11-discovery-pro-data-tech-prod-001/step-03-task-validator.md
  - workflows/discovery-host.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Proceed to step 07 (execution-validator). Validator should flag the 5 critical/high security gaps (password auth, permitrootlogin yes, inactive UFW, no fail2ban, no auditd) and the notable private eth1 LAN interface vs the QA baseline. Step 08 (landscape-updater) should create landscape/hosts/pro-data-tech-prod.md and add a pro-data-tech-prod entry to landscape/services.md.
---

## Summary

All 14 probes ran cleanly against `root@95.46.211.224` (`drkkrgm-prod-instance`). The host is a fresh Ubuntu 26.04 LTS KVM instance (kernel `7.0.0-14-generic`, 16 vCPU, 32 GiB RAM, 339 GB root disk) with **no hardening applied**: UFW inactive (fully open iptables), `PasswordAuthentication yes`, `PermitRootLogin yes`, no fail2ban, no auditd, no Docker, no nginx, and no operator users. Key structural surprise vs. the QA baseline: a second NIC (eth1 `192.168.0.3/24`) indicates a private provider LAN between the two hosts. Twelve pending package upgrades are outstanding. The kernel is two minor versions behind the QA host (`7.0.0-14` vs `7.0.0-27`).

## Details

### Pre-execution checks

- **Workflow `state_changing` flag:** `false` (verified in `workflows/discovery-host.md` frontmatter)
- **SSH key format:** `-----BEGIN RSA PRIVATE KEY-----` — OpenSSH RSA (PEM) format; confirmed valid before first connection
- **Pre-execution probe (Probe A):**
  - Command: `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" -o StrictHostKeyChecking=accept-new -o BatchMode=yes root@95.46.211.224 'whoami && id && hostname && sudo -n true && echo SUDO_OK'`
  - Output:
    ```
    root
    uid=0(root) gid=0(root) groups=0(root)
    drkkrgm-prod-instance
    SUDO_OK
    ```
  - Result: **SUDO_OK confirmed**. Proceeding.

### Probe log

All probes used the exact SSH command: `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" -o StrictHostKeyChecking=accept-new -o BatchMode=yes root@95.46.211.224 '<command>'`

---

#### Probe A: Identity & access (pre-execution self-check)
- Command: `whoami && id && hostname && sudo -n true && echo SUDO_OK`
- Exit code: 0
- Output:
  ```
  root
  uid=0(root) gid=0(root) groups=0(root)
  drkkrgm-prod-instance
  SUDO_OK
  ```
- Side effects observed: none (SSH host key added to known_hosts — expected first-connect behaviour)

---

#### Probe B: OS & kernel
- Command: `cat /etc/os-release && uname -a && lsb_release -a 2>/dev/null`
- Exit code: 0
- Output:
  ```
  PRETTY_NAME="Ubuntu 26.04 LTS"
  NAME="Ubuntu"
  VERSION_ID="26.04"
  VERSION="26.04 LTS (Resolute Raccoon)"
  VERSION_CODENAME=resolute
  ID=ubuntu
  ID_LIKE=debian
  UBUNTU_CODENAME=resolute
  ---UNAME---
  Linux drkkrgm-prod-instance 7.0.0-14-generic #14-Ubuntu SMP PREEMPT_DYNAMIC Mon Apr 13 11:09:53 UTC 2026 x86_64 GNU/Linux
  ---LSB---
  Distributor ID: Ubuntu
  Description:    Ubuntu 26.04 LTS
  Release:        26.04
  Codename:       resolute
  ```
- Side effects observed: none

---

#### Probe C: Hardware
- Command: `nproc && free -h && df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs`
- Exit code: 0
- Output:
  ```
  16
  ---FREE---
                 total        used        free      shared  buff/cache   available
  Mem:            31Gi       972Mi        28Gi       5.0Mi       2.2Gi        30Gi
  Swap:             0B          0B          0B
  ---DF---
  Filesystem      Size  Used Avail Use% Mounted on
  /dev/sda1       339G  3.1G  336G   1% /
  /dev/sda13      989M  150M  772M  17% /boot
  /dev/sda15      105M  6.3M   99M   7% /boot/efi
  ```
- Additional hardware detail (CPU model, virt type):
  ```
  model name      : Intel(R) Xeon(R) Platinum 8164 CPU @ 2.00GHz
  MemTotal:       32858084 kB
  SwapTotal:             0 kB
  systemd-detect-virt: kvm
  ```
- Side effects observed: none

---

#### Probe D: Users & groups
- **getent passwd (uid≥1000 and root only):**
  ```
  root:x:0:0:root:/root:/bin/bash
  ```
  — No uid≥1000 accounts exist. Fresh host, no operator users.

- **`/etc/sudoers.d/` contents:**
  ```
  total 16
  drwxr-x---  2 root root 4096 May  5 05:20 .
  -r--r-----  1 root root  127 May  5 05:20 90-cloud-init-users
  -r--r-----  1 root root  863 Jan 14 18:11 README
  90-cloud-init-users: root ALL=(ALL) NOPASSWD:ALL
  ```
  Only stock cloud-init drop-in; no project-managed drop-ins.

- **Currently logged in:** no active sessions other than the probe session itself (`who` returned empty).

- **`last` command:** not installed (`bash: line 1: last: command not found`) — same as QA host.

- **`/root/.ssh/authorized_keys`:**
  - 1 line total
  - Key type: `ssh-rsa`
  - Comment: `rsa-key-20260707`
  - (Key value not recorded; same naming convention as QA host provider key)

- Side effects observed: none

---

#### Probe E: SSH daemon config (effective)
- Command: `sudo sshd -T 2>/dev/null | grep -Ei '^(port |permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|usedns|x11forwarding|allowusers|allowgroups|maxauthtries|clientaliveinterval|logingracetime)' | sort`
- Exit code: 0
- Output:
  ```
  clientaliveinterval 0
  logingracetime 120
  maxauthtries 6
  passwordauthentication yes
  permitemptypasswords no
  permitrootlogin yes
  port 22
  pubkeyauthentication yes
  usedns no
  x11forwarding yes
  ```
- **sshd drop-in files (`/etc/ssh/sshd_config.d/`):**
  ```
  60-cloudimg-settings.conf
  PasswordAuthentication yes
  ```
  Only one drop-in — cloud-init default. No project-managed drop-ins.
- Side effects observed: none

---

#### Probe F: Firewall
- Command: `ufw status verbose`, `nft list ruleset`, `iptables -L -n -v`, `ip6tables -L -n -v`
- Exit code: 0 for all
- Output:
  ```
  --- ufw ---
  Status: inactive
  --- nftables ---
  (empty ruleset)
  --- iptables ---
  Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
   pkts bytes target  prot  opt  in  out  source  destination
  Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
   pkts bytes target  prot  opt  in  out  source  destination
  Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
   pkts bytes target  prot  opt  in  out  source  destination
  --- ip6tables ---
  Chain INPUT  (policy ACCEPT)  — no rules
  Chain FORWARD (policy ACCEPT) — no rules
  Chain OUTPUT (policy ACCEPT)  — no rules
  ```
- Side effects observed: none

---

#### Probe G: Network listeners
- Command: `sudo ss -tlnp && sudo ss -ulnp`
- Exit code: 0
- Output:
  ```
  TCP LISTEN:
  LISTEN 0 4096  127.0.0.53%lo:53   0.0.0.0:*  users:(("systemd-resolve",pid=28524,fd=18))
  LISTEN 0 4096       0.0.0.0:22   0.0.0.0:*  users:(("sshd",pid=18442,fd=3),("systemd",pid=1,fd=150))
  LISTEN 0 4096     127.0.0.54:53   0.0.0.0:*  users:(("systemd-resolve",pid=28524,fd=20))
  LISTEN 0 4096          [::]:22      [::]:*  users:(("sshd",pid=18442,fd=4),("systemd",pid=1,fd=151))

  UDP UNCONN:
  UNCONN 0 0  127.0.0.54:53    0.0.0.0:*   systemd-resolve
  UNCONN 0 0  127.0.0.53%lo:53 0.0.0.0:*   systemd-resolve
  UNCONN 0 0  127.0.0.1:323    0.0.0.0:*   chronyd
  UNCONN 0 0      [::1]:323      [::]:*   chronyd
  ```
- Side effects observed: none

---

#### Network interface probe (supplemental)
- Command: `ip addr show && ip route && ip -6 addr show`
- Exit code: 0
- Output:
  ```
  1: lo — 127.0.0.1/8, ::1/128
  2: eth0 (UP) — 95.46.211.224/25 brd 95.46.211.255; inet6 fe80::649a:e1ff:fe4e:baeb/64 link-local
  3: eth1 (UP) — 192.168.0.3/24 brd 192.168.0.255; inet6 fe80::e82f:86ff:fef3:bb89/64 link-local

  Routes:
  default via 95.46.211.129 dev eth0 proto static
  95.46.211.128/25 dev eth0 proto kernel scope link src 95.46.211.224
  192.168.0.0/24 dev eth1 proto kernel scope link src 192.168.0.3
  ```
- IPv6: no global address on either interface (link-local only)
- **Notable:** `eth1 192.168.0.3/24` is a second NIC on a private LAN — not present on QA host (`pro-data-tech-qa` has only eth0 `95.46.211.230/25`). Likely a provider-managed private network between prod and other servers in the same account.
- Side effects observed: none

---

#### Probe H: Docker
- Command: `which docker && docker --version`
- Exit code: non-zero
- Output: `docker not installed`
- Side effects observed: none

---

#### Probe I: nginx
- Command: `which nginx && nginx -v 2>&1`
- Exit code: non-zero
- Output: `nginx not installed`
- Side effects observed: none

---

#### Probe J: Systemd units of interest
- Command: `systemctl list-units --type=service --state=running --no-pager --no-legend | head -40`
- Exit code: 0
- Running services (21 total):
  ```
  chrony.service
  cron.service
  dbus.service
  fwupd.service
  getty@tty1.service
  ModemManager.service
  multipathd.service
  networkd-dispatcher.service
  polkit.service
  qemu-guest-agent.service
  rsyslog.service
  serial-getty@ttyS0.service
  ssh.service
  systemd-journald.service
  systemd-logind.service
  systemd-networkd.service
  systemd-resolved.service
  systemd-udevd.service
  udisks2.service
  unattended-upgrades.service
  user@0.service
  ```
- Notable in enabled (non-running): `apparmor.service`, `cloud-init-*.service` (5 stages), `snapd.service`, `open-vm-tools.service` (unusual for a KVM host — may be baked into the provider image).
- Side effects observed: none

---

#### Probe K: Scheduled tasks
- Root crontab: empty (no entries)
- `/etc/cron.d/`: `e2scrub_all` only (standard Ubuntu)
- Systemd timers: all standard Ubuntu timers (`apt-daily`, `apt-daily-upgrade`, `fwupd-refresh`, `logrotate`, `man-db`, `dpkg-db-backup`, `sysstat-*`, `e2scrub_all`, `xfs_scrub_all`, `fstrim`, `motd-news`, `systemd-tmpfiles-clean`, `update-notifier-*`). No project-custom timers.
- Side effects observed: none

---

#### Probe L: Package & update posture
- Pending upgrades: **12** (unattended-upgrades has not yet applied them)
- APT sources: `/etc/apt/sources.list.d/ubuntu.sources` (deb822, standard Ubuntu 26.04 only; no third-party repos)
- `20auto-upgrades`: `APT::Periodic::Update-Package-Lists "1"` and `APT::Periodic::Unattended-Upgrade "1"` — enabled
- Last apt activity: `2026-07-07 11:23:06.080212247 +0000` (cloud-init bootstrap)
- Side effects observed: none

---

#### Probe M: Security tools
- **fail2ban:** `fail2ban not present` — not installed
- **auditd:** `auditd not present` — not installed; `auditctl` not found
- **AppArmor:**
  ```
  apparmor module is loaded.
  179 profiles are loaded.
  103 profiles are in enforce mode.
  ```
  Stock Ubuntu 26.04 default. Same profile count as QA host.
- Side effects observed: none

---

#### Probe N: Backup posture
- Backup-related systemd units: `dpkg-db-backup.timer` (standard Ubuntu DB backup) + `lvm2-monitor.service` (LVM snapshot monitoring, not related to data backups)
- Backup tools: none (`restic`, `borg`, `duplicity` — none present)
- No project backup directories
- Side effects observed: none

---

### Findings summary (for step 07 validator + step 08 updater)

**Identity / access:**
- Hostname: `drkkrgm-prod-instance` — source: Probe A
- SSH user: `root` (uid 0, gid 0) — source: Probe A
- `/root/.ssh/authorized_keys`: 1 line, type `ssh-rsa`, comment `rsa-key-20260707` — source: Probe D
- No uid≥1000 users — source: Probe D
- sudoers: only `/etc/sudoers.d/90-cloud-init-users` (cloud-init default, root NOPASSWD:ALL) — source: Probe D

**OS / kernel:**
- OS: Ubuntu 26.04 LTS "Resolute Raccoon" — source: Probe B
- Kernel: `7.0.0-14-generic` (older than QA's `7.0.0-27-generic`) — source: Probe B
- Architecture: x86_64 — source: Probe B

**Hardware:**
- vCPU: 16 (`nproc=16`) — source: Probe C
- RAM: ~31 GiB total, 972 MiB used, no swap — source: Probe C
- Disk: 339 GB `/dev/sda1` at `/` (3.1 GB used, 1%), 989 MB `/boot`, 105 MB `/boot/efi` — source: Probe C
- CPU model: Intel Xeon Platinum 8164 @ 2.00GHz — source: supplemental
- Virtualization: KVM — source: supplemental (`systemd-detect-virt`)

**Network:**
- Public IP: `95.46.211.224/25`, gateway `95.46.211.129` (eth0) — source: network probe
- Private LAN: `192.168.0.3/24` (eth1) — **not present on QA host** — source: network probe
- IPv6: link-local only (no global assignment) — source: network probe
- Public TCP listeners: port 22 (`sshd`, `0.0.0.0` and `[::]`) — source: Probe G
- Loopback listeners only: 53 (systemd-resolved), 323 (chronyd) — source: Probe G

**sshd (UNHARDENED — multiple security gaps):**
- `permitrootlogin yes` — allows password+key root login — source: Probe E
- `passwordauthentication yes` — password auth enabled — source: Probe E
- `maxauthtries 6` — not hardened — source: Probe E
- `logingracetime 120` — not hardened — source: Probe E
- `x11forwarding yes` — not hardened — source: Probe E
- `clientaliveinterval 0` — not set — source: Probe E
- No `allowgroups` or `allowusers` restriction — source: Probe E
- Drop-in: only `60-cloudimg-settings.conf` (`PasswordAuthentication yes`) — source: Probe E

**Firewall (NONE ACTIVE):**
- UFW: installed but **inactive** — source: Probe F
- nftables: empty ruleset — source: Probe F
- iptables: no rules, policy ACCEPT on all chains (INPUT/FORWARD/OUTPUT) — source: Probe F
- ip6tables: same, fully open — source: Probe F

**Running services:**
- 21 services running; all standard Ubuntu cloud-image base services — source: Probe J
- No Docker, no nginx, no fail2ban, no auditd — sources: Probes H, I, M

**Security tools:**
- AppArmor: loaded, 179 profiles, 103 enforce (stock Ubuntu default) — source: Probe M
- fail2ban: not installed — source: Probe M
- auditd: not installed — source: Probe M

**Packages / updates:**
- 12 pending upgrades — source: Probe L
- unattended-upgrades: enabled (daily) — source: Probe L
- Last apt activity: 2026-07-07 — source: Probe L

**Backups:**
- No backup tooling; no application data to back up yet — source: Probe N

### Security gaps vs QA baseline (priority order)

| # | Severity | Gap | QA state | Prod state |
|---|---|---|---|---|
| 1 | CRITICAL | `PermitRootLogin yes` (any auth method) | `prohibit-password` (key-only) | `yes` |
| 2 | CRITICAL | `PasswordAuthentication yes` | `no` | `yes` |
| 3 | CRITICAL | UFW inactive (no firewall at all) | active, default-deny, 22/tcp only | inactive; ACCEPT all |
| 4 | HIGH | fail2ban not installed | active sshd jail | not present |
| 5 | HIGH | auditd not installed | active, CIS ruleset | not present |
| 6 | HIGH | 12 pending package upgrades | 0 at initial discovery | 12 outstanding |
| 7 | HIGH | Kernel `7.0.0-14-generic` (old) | `7.0.0-27-generic` (post T-0099) | `7.0.0-14-generic` |
| 8 | MEDIUM | `MaxAuthTries 6` | 3 | 6 |
| 9 | MEDIUM | `LoginGraceTime 120` | 30 | 120 |
| 10 | MEDIUM | `X11Forwarding yes` | no | yes |
| 11 | MEDIUM | No operator users (uid≥1000) | tvolodi, viktor_d, binali_r | none |
| 12 | LOW | `ClientAliveInterval 0` | 300 | 0 |

### Structural observations vs QA baseline

- **eth1 private LAN `192.168.0.3/24`:** The prod host has a second NIC on `192.168.0.0/24`. QA host (`95.46.211.230`) has only eth0. This private LAN is unknown in the current landscape; the QA host's IP on this network (if any) is not known. This should be investigated and documented — it may indicate that the two hosts share a provider-managed private network for inter-host communication.
- **Larger hardware:** 16 vCPU / 32 GiB RAM vs QA's 8 vCPU / 15 GiB. This is the production-grade tier.
- **`open-vm-tools.service` enabled:** Unusual for a KVM host (open-vm-tools is VMware tooling). `systemd-detect-virt` confirms KVM. May be a provider image quirk; not functionally harmful.
- **No Docker, no nginx:** Host is truly fresh — no application workload yet. Contrast with QA which had Docker + postgres installed via T-0090.
- **`last` not installed:** Same as QA host — `util-linux` partial install on this provider image. `who` works.
- **`snapd` installed and enabled:** 6 snap-related units enabled (same as QA). No snaps actually installed beyond the seeded set.

### Files this run will propose for landscape update

- `landscape/hosts/pro-data-tech-prod.md` — new file: full host profile (all sections)
- `landscape/services.md` — new entry for `pro-data-tech-prod` (initially minimal: SSH only, no Docker/nginx)

## Issues / risks

- **No active firewall is the highest-urgency risk.** Port 22 is exposed to the internet with password auth enabled and no fail2ban. The host is actively brute-forceable right now. The hardening task chain (T-0102 through T-0105) should be executed immediately after the landscape is updated.
- **`PasswordAuthentication yes` + `PermitRootLogin yes`** means any attacker who discovers or guesses the root password has full root access. Even if the password is strong, this is not acceptable for a production host.
- **12 pending packages + kernel `7.0.0-14`:** Security patches are outstanding. An `apt upgrade` + kernel upgrade (cf. T-0099 pattern) should be part of the hardening sequence.
- **eth1 private LAN `192.168.0.3/24` is undocumented.** If the QA host is also on `192.168.0.x`, then any compromise of either host gives lateral movement access to the other via the private LAN (bypassing UFW/iptables on eth0). UFW rules should explicitly address eth1 traffic as part of T-0102.

## Open questions

- **What is the QA host's IP on the `192.168.0.0/24` private network?** Probe this on the QA host to confirm topology. If QA is `192.168.0.2` and prod is `192.168.0.3`, the two hosts are on a shared private LAN. This should be reflected in both landscape files and factored into UFW rules.
- **Is `open-vm-tools.service` installed by the provider image intentionally, or is it a leftover?** Harmless in practice on KVM; worth documenting in the landscape file.
- **What is the prod host's role?** The task file implies production (vs QA), but no role is assigned yet. The landscape-updater should set `role: unassigned` and leave a note that role will be determined by the task chain.
