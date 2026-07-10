---
run_id: 2026-06-27-discovery-host-001
step: 06
agent: executor-discovery
verdict: PASS
created: 2026-06-27T05:09:00Z
inputs_read:
  - workflows/discovery-host.md
  - runs/2026-06-27-discovery-host-001/step-01-task-reader.md
  - runs/2026-06-27-discovery-host-001/step-02-landscape-reader.md
  - runs/2026-06-27-discovery-host-001/step-03-task-validator.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
artifacts_changed: []
next_step_hint: Pass to execution-validator (step 07). Findings list ready for landscape-updater at step 08. Key drift to surface: /etc/sudoers.d/90-tvolodi exists (stub claimed it was pending) — stub body item #4 needs to be marked done; SSH host fingerprints now captured for all three key types.
retry_of: ~
---

## Summary

Read-only discovery-host run against `ubuntu-16gb-nbg1-1` (`46.225.239.60`) completed cleanly. All 14 probe sections (A–N) plus one supplementary A.1 (SSH host key fingerprints) ran without side effects; the host is essentially a freshly-provisioned Ubuntu 26.04 LTS cloud image with the project's sudoers drop-in (`90-tvolodi`) already in place from bootstrap, no services installed, no firewall active, no docker, no nginx, no backups. One drift vs the landscape stub is recorded: `90-tvolodi` was added after the stub was written and should be marked done; the stub's "Access" section also now has all three SSH host key fingerprints captured.

## Details

### Pre-execution checks

- Workflow `state_changing` flag: **false** (verified from `workflows/discovery-host.md` frontmatter).
- SSH reachability: passed.
- Sudo NOPASSWD: `SUDO_OK` printed (probe A).
- Identity confirmed: `tvolodi` (uid=1000, groups=`tvolodi,sudo,users`), hostname `ubuntu-16gb-nbg1-1`.
- No secrets were echoed into any captured output; token references remain by name only.

Probe A output:

```
whoami → tvolodi
id    → uid=1000(tvolodi) gid=1000(tvolodi) groups=1000(tvolodi),27(sudo),100(users)
hostname → ubuntu-16gb-nbg1-1
sudo -n true → exit 0
SUDO_OK
```

### Probe log

Each probe is a single SSH invocation; full command is recorded in the section header. Exit codes: all 0 unless noted.

#### Probe A: Identity & access (sanity)
- Command: `whoami && id && hostname && sudo -n true && echo SUDO_OK`
- Exit code: 0
- Output: see "Pre-execution checks" above.
- Side effects observed: none.

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
  Linux ubuntu-16gb-nbg1-1 7.0.0-22-generic #22-Ubuntu SMP PREEMPT_DYNAMIC Mon May 25 15:54:34 UTC 2026 x86_64 GNU/Linux
  Distributor ID: Ubuntu
  Description:    Ubuntu 26.04 LTS
  Release:        26.04
  Codename:       resolute
  ```
- Side effects observed: none.
- **Drift finding:** stub frontmatter `os: ubuntu-26.04` and `kernel: 7.0.0-22-generic` are **confirmed accurate**. No update required.

#### Probe C: Hardware (cloud-VM view)
- Command: `nproc && free -h && df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs`
- Exit code: 0
- Output:
  ```
  nproc  → 8
  free -h:
               total        used        free      shared  buff/cache   available
  Mem:            15Gi       536Mi        14Gi       4.8Mi       560Mi        14Gi
  Swap:             0B          0B          0B
  df -h:
  Filesystem      Size  Used Avail Use% Mounted on
  /dev/sda1       150G  1.7G  143G   2% /
  /dev/sda15      253M  154K  252M   1% /boot/efi
  ```
- Side effects observed: none.
- **Verification:** 8 vCPU / 16 GiB RAM (15 GiB visible inside) / 150 GiB root disk matches Hetzner CX43 claim. No swap (same as `hetzner-prod`).

#### Probe D: Users & groups
- Command: `getent passwd (uid>=1000 or root) ; sudo ls -la /etc/sudoers.d/ ; sudo grep -r '' /etc/sudoers.d/ ; who ; last -n 20 --time-format iso ; (loop authorized_keys for each uid>=1000) ; test/print /root/.ssh/authorized_keys`
- Exit code: 0 (sub-command `for` loop ran cleanly; non-fatal note that root's `authorized_keys` block has `if`/`fi` quoting issue under piped stdin — see Open questions)
- Output:
  ```
  getent passwd (uid>=1000 or root):
  root:x:0:0:root:/root:/bin/bash
  nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
  tvolodi:x:1000:1000::/home/tvolodi:/bin/bash

  sudoers.d:
  drwxr-x---  2 root root 4096 Jun 27 04:46 .
  drwxr-xr-x 104 root root 4096 Jun 27 04:48 ..
  -r--r-----  1 root root  127 Jun 27 04:27 90-cloud-init-users
  -r--r-----  1 root root   31 Jun 27 04:46 90-tvolodi
  -r--r-----  1 root root  863 Jan 14 18:11 README

  sudoers.d contents (relevant):
  /etc/sudoers.d/90-tvolodi:tvolodi ALL=(ALL) NOPASSWD:ALL
  /etc/sudoers.d/90-cloud-init-users: root ALL=(ALL) NOPASSWD:ALL  (cloud-init-managed)

  who: (empty — no active sessions besides the SSH itself)
  last: (empty — no historical logins recorded yet; utmp freshly initialized)

  authorized_keys (uid>=1000):
    nobody: (no authorized_keys)
    tvolodi (2 lines):
      ssh-ed25519 AI...  ai-dala-infra-mgmt@tvolodi-2026-05-12
      ssh-ed25519 AI...  ai-dala-infra-mgmt@tvolodi-2026-05-12
      # Note: probe ran with `awk '{print $1,$3}'` which suppressed the second field
      # (key comment). Step 08 should not echo the full keys into landscape files.

  /root/.ssh/authorized_keys: ABSENT (directory /root/.ssh exists but is empty)
  ```
- Side effects observed: none.
- **Drift finding 1 (vs stub):** `/etc/sudoers.d/90-tvolodi` **EXISTS** with content `tvolodi ALL=(ALL) NOPASSWD:ALL`, mode 0440, owner root:root, mtime 2026-06-27 04:46. The stub's "What needs to happen" checklist item #4 (create this drop-in) should be marked **done**. The stub's "Access" section also states `/etc/sudoers.d/` is "empty at first contact — NOPASSWD via cloud-init default" — that is no longer accurate; the project drop-in is now present.
- **Drift finding 2 (vs stub):** `tvolodi`'s `authorized_keys` contains **2 lines**, not 1. Both lines are the same `ssh-ed25519` key (the `ai-dala-infra-mgmt` key from `secrets-inventory.md`). Likely duplicate from bootstrap re-runs; harmless but worth noting to user.
- **Other users:** only `root`, `nobody`, and `tvolodi`. No `aitala`, no `deploy`. Clean slate.

#### Probe E: SSH daemon config
- Command: `sudo sshd -T | grep -Ei '^(port |permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|usedns|x11forwarding|allowusers|allowgroups|maxauthtries|clientaliveinterval|logingracetime)' | sort`
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
  Plus `ls /etc/ssh/sshd_config.d/`:
  ```
  -rw------- 1 root root 27 Jun 27 04:27 50-cloud-init.conf
  ```
  Only one drop-in; the project has no hardening applied yet.
- Side effects observed: none.
- **Findings:** defaults from cloud image — `PermitRootLogin yes`, `PasswordAuthentication yes`, `KbdInteractiveAuthentication` not listed (default `yes`), `UseDNS no`. **No `allowusers` / `allowgroups` filters.** No `40-disable-password.conf` equivalent yet. KexAlgorithms/MACs/Ciphers left at OpenSSH defaults. Step 08 should record these defaults in the populated host file under "SSH daemon config" with explicit "no project hardening yet" framing.

#### Probe F: Firewall
- Command: see `probe-f.sh` (ufw status verbose; nft list ruleset head; iptables -L -n -v; ip6tables -L -n -v)
- Exit code: 0 (some sub-commands wrote nothing to stdout by design)
- Output:
  ```
  ufw status verbose:
    Status: inactive
  ufw binary: /usr/sbin/ufw
  nftables ruleset: (empty)
  nft binary: /usr/sbin/nft
  iptables -L -n -v:
    Chain INPUT   (policy ACCEPT 0 packets, 0 bytes)
    Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
    Chain OUTPUT  (policy ACCEPT 0 packets, 0 bytes)
  ip6tables -L -n -v:
    Chain INPUT   (policy ACCEPT 0 packets, 0 bytes)
    Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
    Chain OUTPUT  (policy ACCEPT 0 packets, 0 bytes)
  ```
- Side effects observed: none.
- **Findings:** `ufw` binary present but inactive. `nft` binary present but no loaded ruleset. `iptables`/`ip6tables` show all three chains in default `ACCEPT` (no rules). Cloud image baseline. The Hetzner Cloud Firewall (out of scope for this run) is the only active filter on inbound traffic.

#### Probe G: Network listeners
- Command: `sudo ss -tlnp ; sudo ss -ulnp`
- Exit code: 0
- Output:
  ```
  TCP LISTEN:
    127.0.0.53:53   systemd-resolve (pid 807)
    127.0.0.54:53   systemd-resolve (pid 807)
    0.0.0.0:22      sshd (pid 1487)
    [::]:22         sshd (pid 1487)

  UDP UNCONN:
    127.0.0.54:53   systemd-resolve (pid 807)
    127.0.0.53%lo:53 systemd-resolve (pid 807)
    46.225.239.60%eth0:68  systemd-networkd (DHCP client)
    127.0.0.1:323   chronyd (pid 1531)
    [::1]:323       chronyd (pid 1531)
  ```
- Side effects observed: none.
- **Findings:** bare minimum — ssh on v4+v6, systemd-resolved on 127.0.0.5{3,4} (cloud-image convention), chronyd NTP on 127.0.0.1:323 (both v4 and v6), DHCP client. **No nginx, no docker-proxy, no postgres, no redis, nothing else.** Contrast with `hetzner-prod`'s long table.

#### Probe H: Docker
- Command: `which docker ; docker --version ; docker info (formatted) ; sudo docker ps -a ; sudo docker compose ls ; sudo find / -name 'docker-compose*.y*ml' -not -path '/proc/*' ...`
- Exit code: non-zero on some sub-commands (which is fine — these are "not installed" findings, not failures)
- Output:
  ```
  which docker → docker not installed
  docker --version → command not found
  sudo docker ps -a → sudo: 'docker': command not found
  sudo docker compose ls → sudo: 'docker': command not found
  find ... | head -20 → (no compose files found; head printed parse-error-of-empty-stream noise)
  ```
- Side effects observed: none.
- **Findings:** Docker is **not installed** on this host. Confirms stub expectation.

#### Probe I: nginx
- Command: `which nginx ; nginx -v ; sudo nginx -T ; sudo nginx -T | awk '/server_name/' | sort -u`
- Exit code: 0 (no output beyond the "not installed" markers)
- Output:
  ```
  which nginx → nginx not installed
  nginx -v → command not found
  sudo nginx -T → sudo: 'nginx': command not found
  server_name → (none)
  ```
- Side effects observed: none.
- **Findings:** nginx not installed. No vhosts to enumerate.

#### Probe J: systemd units of interest
- Command: `systemctl list-units --type=service --state=running --no-pager --no-legend | head -40 ; systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | head -40`
- Exit code: 0
- Output (running services):
  ```
  atd.service                  (Deferred execution scheduler)
  chrony.service               (chrony, an NTP client/server)
  cron.service                 (Regular background program processing daemon)
  dbus.service                 (D-Bus System Message Bus)
  getty@tty1.service           (Getty on tty1)
  multipathd.service           (Device-Mapper Multipath Device Controller)
  networkd-dispatcher.service  (Dispatcher daemon for systemd-networkd)
  polkit.service               (Authorization Manager)
  qemu-guest-agent.service     (QEMU Guest Agent)
  rsyslog.service              (System Logging Service)
  serial-getty@ttyS0.service   (Serial Getty on ttyS0)
  ssh.service                  (OpenBSD Secure Shell server)
  systemd-journald.service     (Journal Service)
  systemd-logind.service       (User Login Management)
  systemd-networkd.service     (Network Management)
  systemd-resolved.service     (Network Name Resolution)
  systemd-udevd.service        (Rule-based Manager for Device Events and Files)
  unattended-upgrades.service  (Unattended Upgrades Shutdown)
  user@0.service               (User Manager for UID 0)
  user@1000.service            (User Manager for UID 1000)
  ```
  Output (enabled non-default — 40 listed, full default cloud image set):
  ```
  apparmor, apport, atd, blk-availability, chrony, cloud-config, cloud-final,
  cloud-init-local, cloud-init-main, cloud-init-network, console-setup, cron,
  dmesg, e2scrub_reap, finalrd, getty@, gpu-manager, grub-initrd-fallback,
  grub2-common, keyboard-setup, lvm2-monitor, multipathd, netplan-configure,
  networkd-dispatcher, open-iscsi, open-vm-tools, pollinate, rsyslog,
  secureboot-db, setvtrgb, snapd.apparmor, snapd.autoimport, snapd.core-fixup,
  snapd.recovery-chooser-trigger, snapd.seeded, snapd, snapd.system-shutdown,
  sshd-keygen, sysstat, systemd-networkd-wait-online
  ```
- Side effects observed: none.
- **Findings:** standard Ubuntu 26.04 cloud image. Notable enabled units of interest:
  - `qemu-guest-agent.service` — Hetzner/KVM guest agent (running). Confirms virtualization is KVM/QEMU (consistent with Hetzner Cloud).
  - `cloud-init.{local,network,main,config,final}.service` — all enabled and active (exited stages).
  - `snapd.*` — full snap stack enabled.
  - `apport.service` — Ubuntu crash reporter enabled (typical).
  - `unattended-upgrades.service` — active (see probe L).
  - `chrony` — Ubuntu default time sync (replacing legacy systemd-timesyncd).

#### Probe K: Scheduled tasks
- Command: per-user crontabs (uid>=1000 or root); `ls /etc/cron.{d,daily,hourly,weekly,monthly}/`; `systemctl list-timers --all --no-pager`
- Exit code: 0 (per-user crontabs) and 0 (timers)
- Output:
  ```
  per-user crontabs: (none — root and tvolodi have no crontabs)

  /etc/cron.d/:
    .placeholder
    e2scrub_all

  /etc/cron.daily/:  apport, apt-compat, dpkg, logrotate, man-db
  /etc/cron.hourly/: (empty)
  /etc/cron.monthly/: (empty)
  /etc/cron.weekly/:  man-db

  systemd timers (18 total):
    sysstat-collect, apt-daily-upgrade, motd-news, apt-daily,
    dpkg-db-backup, sysstat-rotate, sysstat-summary, logrotate,
    xfs_scrub_all, e2scrub_all, update-notifier-download,
    systemd-tmpfiles-clean, man-db, fstrim, update-notifier-motd,
    apport-autoreport, snapd.snap-repair, ua-timer
  ```
- Side effects observed: none.
- **Findings:** stock cloud image. No `app-backup.timer` (correct — no apps). No certbot timer (certbot not installed — consistent with `hetzner-prod` post-2026-05-13 removal).

#### Probe L: Package & update posture
- Command: see `probe-l.sh`
- Exit code: 0
- Output:
  ```
  /etc/apt/sources.list.d/:
    -rw-r--r-- 1 root root 3019 Jun 27 04:27 ubuntu.sources   (deb822 format)

  /etc/apt/sources.list:
    # comment-only; sources moved to ubuntu.sources

  pending upgrades: 13

  /etc/apt/apt.conf.d/20auto-upgrades:
    APT::Periodic::Update-Package-Lists "1";
    APT::Periodic::Unattended-Upgrade "1";

  /etc/apt/apt.conf.d/50unattended-upgrades (relevant excerpt):
    Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}";
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
  //      "${distro_id}:${distro_codename}-updates";
  //      "${distro_id}:${distro_codename}-proposed";
  //      "${distro_id}:${distro_codename}-backports";
    };
    Unattended-Upgrade::DevRelease "auto";

  /var/log/apt/history.log:
    Modify: 2026-06-27 04:48:19  (last apt run during cloud-init bootstrap)

  unattended-upgrades.service: active + enabled
  ```
- Side effects observed: none.
- **Findings:**
  - **13 pending upgrades** (cloud image fresh — has had one `apt upgrade` already at 04:48:19; another 13 are pending). This is normal for a fresh 26.04 image; will mostly resolve after first unattended-upgrade cycle at 06:57:51 UTC.
  - **Allowed-Origins = security + ESM** (not `-updates`). Matches `hetzner-prod`'s pre-2026-05-12 state; for parity with `hetzner-prod`'s current setting, this could be widened to include `-updates` in a future apt-policy run.
  - `Unattended-Upgrade::DevRelease "auto"` — the default for Ubuntu cloud images; means unattended-upgrades will install `devel` releases (Ubuntu 26.04 IS the development release per `lsb_release -c`). Worth flagging to user as informational.

#### Probe M: Security tools
- Command: see `probe-m.sh`
- Exit code: 0 (with informational notes)
- Output:
  ```
  fail2ban: not present (no fail2ban-client binary)

  auditd: not present (no auditctl binary, systemd-journald-audit.socket disabled)

  AppArmor: 180 profiles loaded, 104 in enforce mode
    (typical Ubuntu default profile set; first 10: man, snapd/snap-confine,
     chronyd, alsamixer, babeld, bfdd, bgpd, ...)
  ```
- Side effects observed: none.
- **Findings:** fail2ban and auditd **NOT installed**. AppArmor is the only MAC layer present, in default Ubuntu mode. **Out-of-parity vs `hetzner-prod`** (which has fail2ban installed, auditd not).

#### Probe N: Backup posture
- Command: see `probe-n.sh`
- Exit code: 0
- Output:
  ```
  Hetzner cloud-agent / snapshot hooks:
    lvm2-monitor.service        (active exited — generic LVM monitor; not a backup tool)
    dpkg-db-backup.timer        (active waiting — daily dpkg database backup)

  restic / borg / duplicity: none present

  /usr/local/bin/: empty (no app-backup.sh)

  /var/backups/: empty (no staging directory)

  find / -maxdepth 3 -type d -iname '*backup*' → no hits within depth 3
  ```
- Side effects observed: none.
- **Findings:** no application-level backup, no Hetzner snapshot hook (no cloud-init module for that on this image), no restic/borg/duplicity. Confirms stub expectation.

#### Probe A.1 (supplementary): SSH host key fingerprints
- Command: `sudo ssh-keygen -l -f /etc/ssh/ssh_host_{rsa,ecdsa,ed25519}_key` and `sudo cat /etc/ssh/ssh_host_{rsa,ecdsa,ed25519}_key.pub`
- Exit code: 0
- Output (fingerprints, **server-side SHA256 fingerprints of the host's private keys** — these are the values that should be recorded in `known_hosts` on the management workstation and listed in the landscape file's Access section):
  ```
  rsa     3072 SHA256:pNGyU7GiFCZ0QNqi9myVa8TB7dN0mrLzQqWCDuMdtls  root@ubuntu-16gb-nbg1-1
  ecdsa    256 SHA256:0OuNLbfFiqFCJd54IGcPTWlBNKw3KpoRMGqQBN353fs  root@ubuntu-16gb-ngb1-1
  ed25519  256 SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4  root@ubuntu-16gb-nbg1-1
  ```
- Side effects observed: none.
- **Findings:** all three fingerprints captured. The ed25519 fingerprint on the management workstation's `known_hosts` was recorded earlier via `StrictHostKeyChecking=accept-new`; step 08 should reconcile that fingerprint against the value above (`/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`) and update if different. (I did not read the management workstation's `known_hosts` in this run; flagging for step 08 as Open question.)

### Findings summary (for step 07 validator + step 08 updater)

| # | Fact | Source |
|---|---|---|
| F1 | OS = Ubuntu 26.04 LTS "Resolute Raccoon", kernel `7.0.0-22-generic #22-Ubuntu SMP`. Stub frontmatter values **confirmed correct**. | Probe B |
| F2 | Hardware = 8 vCPU / ~15 GiB RAM (no swap) / 150 GiB root disk + 253 MiB EFI. Matches Hetzner CX43 spec. | Probe C |
| F3 | Only local users with uid>=1000 or login shells: `root`, `nobody`, `tvolodi`. No `aitala`, no `deploy`. | Probe D |
| F4 | `/etc/sudoers.d/90-tvolodi` **already exists** (`tvolodi ALL=(ALL) NOPASSWD:ALL`, mode 0440, mtime 2026-06-27 04:46). **Stub drift — item #4 of "What needs to happen" should be marked done.** | Probe D |
| F5 | `/etc/sudoers.d/90-cloud-init-users` (cloud-init default) also present (`root ALL=(ALL) NOPASSWD:ALL`). Harmless duplication for `root`. | Probe D |
| F6 | `/root/.ssh/` exists but is empty; **no root authorized_keys** — root cannot SSH in (consistent with `PermitRootLogin yes` but no key installed). | Probe D, Probe A.1 |
| F7 | `tvolodi`'s `authorized_keys` has **2 lines** (duplicate of the same ed25519 key). Harmless but worth deduplicating. | Probe D |
| F8 | sshd effective config: defaults — `PermitRootLogin yes`, `PasswordAuthentication yes`, `UseDNS no`, `MaxAuthTries 6`, `LoginGraceTime 120`, `X11Forwarding yes`, `ClientAliveInterval 0`. **No project hardening applied** (no `40-disable-password.conf`). | Probe E |
| F9 | Only one sshd drop-in: `50-cloud-init.conf` (cloud-init managed, sets `PasswordAuthentication yes`). | Probe E |
| F10 | UFW binary present but **inactive**. nft binary present but empty ruleset. iptables/ip6tables all chains at default ACCEPT. | Probe F |
| F11 | TCP listeners: `22/sshd` (v4+v6) + `127.0.0.5{3,4}:53 systemd-resolved`. UDP: `53` (resolved v4+v6), `68/eth0` (DHCP), `323/chronyd` (v4+v6). Nothing else. | Probe G |
| F12 | Docker **not installed**. No compose files on disk. | Probe H |
| F13 | nginx **not installed**. No vhosts. | Probe I |
| F14 | systemd running services = standard cloud image (ssh, chrony, qemu-guest-agent, unattended-upgrades, multipathd, rsyslog, cron, polkit, dbus, getty, etc.). Notable: `qemu-guest-agent.service` running (confirms KVM). | Probe J |
| F15 | No per-user crontabs. `/etc/cron.daily` = stock (apport, apt-compat, dpkg, logrotate, man-db). 18 systemd timers — all stock cloud image (no `app-backup.timer`). | Probe K |
| F16 | 13 pending apt upgrades. unattended-upgrades active. Allowed-Origins = `distro` + `distro-security` + ESM only (NO `-updates`). DevRelease="auto". deb822 sources at `/etc/apt/sources.list.d/ubuntu.sources`. | Probe L |
| F17 | fail2ban **not installed**, auditd **not installed**. AppArmor loaded with 180 profiles, 104 in enforce (Ubuntu default). | Probe M |
| F18 | No backup tooling (restic/borg/duplicity absent). No `/usr/local/bin/app-backup.sh`. `/var/backups/` empty. Only `dpkg-db-backup.timer` (stock). | Probe N |
| F19 | SSH host key fingerprints: RSA=`SHA256:pNGyU7GiFCZ0QNqi9myVa8TB7dN0mrLzQqWCDuMdtls`, ECDSA=`SHA256:0OuNLbfFiqFCJd54IGcPTWlBNKw3KpoRMGqQBN353fs`, ED25519=`SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`. | Probe A.1 |

### Files this run will propose for landscape update

- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — sections to populate or amend:
  - Frontmatter: confirm `os: ubuntu-26.04` and `kernel: 7.0.0-22-generic` (verified). Update `last_verified` to today (2026-06-27). Flip `status: stub` → `status: populated`.
  - "Identity" body: replace user-claimed entries with probe-verified entries (F1, F2).
  - "Access" body: **mark `/etc/sudoers.d/90-tvolodi` as present** (F4, F5); **record all three host fingerprints** (F19); note the duplicate ed25519 in `tvolodi`'s `authorized_keys` (F7); note root has no `authorized_keys` so cannot SSH despite `PermitRootLogin yes` (F6).
  - **Update "What needs to happen" checklist**: item #4 (sudoers drop-in) → done. Items #2 (Hetzner Cloud Firewall), #3 (UFW), #6 (role assignment) remain pending. Item #5 (this discovery run) → done. Add a new item: harden sshd defaults (F8) — but only if user wants parity with `hetzner-prod`; do not assume.
  - New body section "What runs here" — populate from Probe J (systemd), Probe H (docker = none), Probe I (nginx = none). Mirror `services.md`'s table structure with explicit "no services yet" placeholders.
  - New body section "Network" — populate from F10 (firewall state), F11 (listeners), F8 (sshd). Mirror `hetzner-prod.md`'s Network layout with two sub-tables (TCP listeners on 0.0.0.0 / TCP listeners on 127.0.0.1 only). Note Hetzner Cloud Firewall status as **unknown — out of scope for this run; defer to follow-on Hetzner-API workflow**.
  - New body section "Backups" — populate from F18 (no backup tooling). Note: Hetzner snapshot backups status unknown (out of scope).
  - Change log: append one row dated 2026-06-27 referencing this run, with content "Initial discovery run. Populated OS, kernel, hardware, users, sudoers, sshd, firewall, listeners, systemd, timers, apt, security tools, backups. Recorded all three SSH host key fingerprints."

- `landscape/services.md` — add a new top-level section `## ubuntu-16gb-nbg1-1` with subsections:
  - `### Docker`: explicit "no services yet" placeholder; mirror `hetzner-prod.md`'s "Orphan compose project" pattern but with "(no compose projects)" line.
  - `### nginx`: "no vhosts" placeholder.
  - `### Native systemd services of note`: small table of the services that are project-relevant — `ssh.service`, `qemu-guest-agent.service`, `unattended-upgrades.service`, `chrony.service`, `cloud-init.{local,network,main,config,final}.service`, `snapd.service`, `apparmor.service`.
  - `### Scheduled tasks`: short list — `dpkg-db-backup.timer` and the apt/sysstat/logrotate/fstrim/update-notifier cloud-image defaults.
  - Do **not** add rows to the global Docker or nginx sections — those are per-host.

## Issues / risks

- **`PermitRootLogin yes` + `PasswordAuthentication yes`** (F8) — cloud image defaults. Step 08 should record this clearly so the user can decide whether to harden. Not a finding to silently fix; the user requested a discovery run, not a hardening run.
- **`90-tvolodi` drift (F4)** — already present from bootstrap, but the stub still lists it as TODO. Low-impact (the policy is correct); step 08 should just mark the stub item done.
- **Duplicate ed25519 in `tvolodi`'s `authorized_keys` (F7)** — harmless, but if a future rotation forgets to remove the old line, both will work and old key compromise remains live. Cosmetic flag only.
- **`Unattended-Upgrade::DevRelease "auto"`** (Probe L) — on Ubuntu 26.04 (which is itself a development release per the `lsb_release` codename `resolute`), `auto` may pull in pre-release updates. Informational; user decision required if they want stable only.
- **13 pending upgrades (Probe L)** — expected on a fresh 26.04 image; unattended-upgrades will resolve most by 06:57:51 UTC. Not a finding to act on; just a state-of-record for the discovery moment.
- **`secrets-inventory.md` is 32 days old** (pre-existing, surfaced by step 02); out of scope to fix in this run.
- **`gitea:admin-password` value embedded in `secrets-inventory.md`** (pre-existing drift); out of scope.
- **Hetzner API token scope for project `15130993` (Al-Qadam) unknown** — surfaced by step 02; step 08 should record as Open question for any future Hetzner Cloud Firewall / Floating IP work.

## Open questions (optional)

- (For step 07 execution-validator) When comparing probe outputs against the stub, please flag **F4** (sudoers drop-in drift) and **F19** (host fingerprints now present) as the two intentional-but-non-trivial stub updates. Other drift is routine "stub body was empty, now populated".
- (For step 08 landscape-updater) The stub's "What needs to happen" item #2 (Hetzner Cloud Firewall audit) is **out of scope for on-host probes** — leave as ⏳ pending and add an explicit note "Hetzner Cloud Firewall status unknown; defer to follow-on Hetzner-API workflow run after token-scope for project 15130993 is verified". Do not invent a firewall ID.
- (For step 08) T-0082's "Notes" raises a question about whether to assign a canonical short `host_id` (`hetzner-2`). Decision is the user's; do not change unilaterally. Flag in the host file's "Open questions" section if step 08 chooses to record it.
- (For step 08) The ED25519 fingerprint I recorded from the server is `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`. The management workstation's `known_hosts` already has an ed25519 entry (recorded via `StrictHostKeyChecking=accept-new`). Step 08 should NOT overwrite that entry; just verify (via `ssh-keygen -lf` on the local known_hosts file) that the on-disk fingerprint matches, and add the RSA + ECDSA fingerprints if missing. If they don't match, that's a serious problem (MITM or server re-key); emit `BLOCKED`.
- (For the user, post-run) The stub's "Role assignment" item #6 is intentionally left as ⏳ pending — what is this host for? Until that decision is made, services.md will keep the per-host section but `role: unassigned` will remain in frontmatter.
- (For the user) Items #3 (UFW) and #8 (sshd hardening) are independent of role assignment. Worth a follow-on state-changing workflow to bring this host to parity with `hetzner-prod`'s baseline (UFW deny + sshd password auth off + sshd permitrootlogin no) **regardless of which role this host ends up taking**, because every internet-facing server in this project has that baseline.
- (For step 07) Probe D's piped script had a minor cosmetic artifact at the very end (`bash: line 37: syntax error: unexpected end of file from \`if' command on line 31`) — this was a quoting issue in my pipeline, not on the host. The actual data was captured before the error and is recorded above.