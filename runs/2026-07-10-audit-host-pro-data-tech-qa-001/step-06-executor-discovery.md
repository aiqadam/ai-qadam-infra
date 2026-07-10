---
run_id: 2026-07-10-audit-host-pro-data-tech-qa-001
step: 06
agent: executor-discovery
verdict: PASS
created: 2026-07-10T02:30:00Z
inputs_read:
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-03-task-validator.md
  - workflows/audit-host.md
artifacts_changed: []
next_step_hint: execution-validator (step 07) should pay particular attention to (1) probe B — kernel 7.0.0-14 running vs 7.0.0-27 available with reboot-required marker set, a drift from landscape's "0 pending upgrades" snapshot; (2) probe D/J — SUID sudo/su binaries present under /usr/lib/cargo/bin/ in addition to standard /usr/bin locations, unusual and worth judging; (3) probe H — container runs without User/CapDrop/SecurityOpt hardening (defaults only); (4) probe E — auth.log shows continuous internet background-scan brute-force noise (all rejected, fail2ban handling it, 52 total bans) — informational only, not a new risk given existing fail2ban control. Findings matching T-0096 (auditd absent) and T-0090a (nginx absent) are reconfirmed, not new.
---

## Summary
All 15 read-only probes (A through O) from workflows/audit-host.md were executed via `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" root@95.46.211.230` against `pro-data-tech-qa` (95.46.211.230); every probe ran to completion with no side effects, confirming the landscape's hardened baseline (sshd, UFW, fail2ban, sudoers) while surfacing three items for step 07 to judge: a pending kernel upgrade with reboot-required (drift from "0 pending upgrades" snapshot), unusual SUID `su`/`sudo` binary locations under `/usr/lib/cargo/bin/`, and the Postgres container running without explicit hardening flags (User/CapDrop/SecurityOpt all default/empty).

## Details

### Pre-execution checks
- Workflow `state_changing` flag: false (verified in `workflows/audit-host.md` frontmatter).
- Cloudflare check: not applicable — pro-data.tech is not fronted by Cloudflare (confirmed by step 02 landscape-reader); no Cloudflare probes are in this workflow's checklist for this host.
- Pre-execution probe result:
  ```
  $ ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" root@95.46.211.230 'whoami && id && hostname && sudo -n true && echo SUDO_OK'
  root
  uid=0(root) gid=0(root) groups=0(root),1000(sshusers)
  drkkrgm-qa-instance
  SUDO_OK
  ```
  Confirms root access, passwordless sudo, and hostname `drkkrgm-qa-instance` (internal hostname; consistent with pro-data.tech provider naming, distinct from the `pro-data-tech-qa` landscape ID which is our internal alias).

### Probe log

#### Probe A: Pre-flight (sanity)
- Command: `whoami && id && hostname && sudo -n true && echo SUDO_OK && uptime && date -u`
- Exit code: 0
- Output:
  ```
  root
  uid=0(root) gid=0(root) groups=0(root),1000(sshusers)
  drkkrgm-qa-instance
  SUDO_OK
   02:13:45 up 2 days, 14:59,  1 user,  load average: 0.01, 0.03, 0.00
  Fri Jul 10 02:13:45 UTC 2026
  ```
- Side effects observed: none.

#### Probe B: Kernel & OS patch posture
- Command: as specified (kernel/proc-version, reboot-required marker, pending upgrades, security-only count, unattended-upgrades log tail, effective config, debsecan check)
- Exit code: 0
- Output (relevant excerpt):
  ```
  --- kernel running ---
  7.0.0-14-generic
  Linux version 7.0.0-14-generic ... #14-Ubuntu SMP PREEMPT_DYNAMIC Mon Apr 13 11:09:53 UTC 2026
  --- reboot-required marker ---
  *** System restart required ***
  linux-image-7.0.0-27-generic
  linux-base
  --- pending upgrades ---
  fwupd/resolute-updates 2.1.1-1ubuntu3.1 amd64 [upgradable from: 2.1.1-1ubuntu3]
  libfwupd3/resolute-updates 2.1.1-1ubuntu3.1 amd64 [upgradable from: 2.1.1-1ubuntu3]
  python3-software-properties/resolute-updates 0.120.1 all [upgradable from: 0.120]
  software-properties-common/resolute-updates 0.120.1 all [upgradable from: 0.120]
  tzdata/resolute-updates 2026b-0ubuntu0.26.04.1 all [upgradable from: 2026a-3ubuntu1]
  ubuntu-kernel-accessories/resolute-updates 1.570.1 amd64 [upgradable from: 1.570]
  ubuntu-minimal/resolute-updates 1.570.1 amd64 [upgradable from: 1.570]
  ubuntu-server/resolute-updates 1.570.1 amd64 [upgradable from: 1.570]
  ubuntu-standard/resolute-updates 1.570.1 amd64 [upgradable from: 1.570]
  --- security-only pending ---
  0
  --- last unattended-upgrades run ---
  2026-07-09 06:26:53,943 INFO Starting unattended upgrades script
  2026-07-09 06:26:55,677 INFO No packages found that can be upgraded unattended and no pending auto-removals
  2026-07-09 15:09:09,494 INFO Starting unattended upgrades script
  (only whitelist/blacklist init lines after — no packages applied)
  --- unattended-upgrades effective config ---
  APT::Periodic::Unattended-Upgrade "1";
  Unattended-Upgrade::Allowed-Origins:: "${distro_id}:${distro_codename}";
  Unattended-Upgrade::Allowed-Origins:: "${distro_id}:${distro_codename}-security";
  Unattended-Upgrade::Allowed-Origins:: "${distro_id}ESMApps:${distro_codename}-apps-security";
  Unattended-Upgrade::Allowed-Origins:: "${distro_id}ESM:${distro_codename}-infra-security";
  --- debsecan if available ---
  debsecan not installed (acceptable; would require apt install)
  ```
- Side effects observed: none.
- Note: 9 packages pending upgrade, 0 flagged `-security` by the grep heuristic, but `linux-image-7.0.0-27-generic` (a newer kernel) is available and `/var/run/reboot-required` is set — the running kernel (7.0.0-14) has NOT been rebooted into the newer image. Landscape's "0 pending upgrades as of 2026-07-07" is now 3 days stale and no longer accurate — this is a real drift, not a probe artifact (unattended-upgrades only auto-applies packages matching the security/ESM origins above; kernel/meta-package updates here are appearing as regular `-updates` pocket items awaiting either unattended-upgrades' next eligible pass or a manual/scheduled reboot).

#### Probe C: SSH daemon hardening
- Command: `sudo sshd -T`, cipher/KEX/MAC grep, host key listing, drop-in listing + contents, per-user authorized_keys audit
- Exit code: 0
- Output (relevant excerpt):
  ```
  permitrootlogin prohibit-password
  passwordauthentication no
  kbdinteractiveauthentication no
  pubkeyauthentication yes
  maxauthtries 3
  logingracetime 30
  x11forwarding no
  clientaliveinterval 300
  clientalivecountmax 2
  allowgroups sshusers
  usedns no
  ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
  kexalgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
  macs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  requiredrsasize 1024

  --- host keys present ---
  -rw-r--r-- 1 root root 186 Jul  7 11:14 /etc/ssh/ssh_host_ecdsa_key.pub
  -rw-r--r-- 1 root root 106 Jul  7 11:14 /etc/ssh/ssh_host_ed25519_key.pub
  -rw-r--r-- 1 root root 578 Jul  7 11:14 /etc/ssh/ssh_host_rsa_key.pub

  --- sshd config drop-ins ---
  40-ai-dala-infra.conf (T-0093, first-wins, wins all directives set)
  40-disable-password.conf (T-0093, PasswordAuthentication no / KbdInteractiveAuthentication no)
  60-cloudimg-settings.conf (stock cloud-init, stale "PasswordAuthentication yes" — overridden by first-wins)

  --- authorized_keys posture ---
  === root ===       mode=600 owner=root:root  1 ssh-rsa key
  === nobody ===      no authorized_keys
  === tvolodi ===    mode=600 owner=tvolodi:tvolodi   1 ssh-ed25519 key
  === viktor_d ===   mode=600 owner=viktor_d:viktor_d  1 ssh-ed25519 key
  === binali_r ===   mode=600 owner=binali_r:binali_r  1 ssh-ed25519 key
  ```
- Side effects observed: none.
- Note: matches landscape exactly (T-0093 hardening intact, no config drift). Root's sole authorized key is `ssh-rsa` type (the break-glass provider key) — `requiredrsasize 1024` is the sshd-enforced minimum, but the actual key's bit length was not measured by this probe (out of scope for probe C as specified) — flagged for informational awareness only.

#### Probe D: sudoers review
- Command: `/etc/sudoers` dump, `/etc/sudoers.d/` listing+contents, `visudo -c`, sudo/admin/wheel/docker group membership
- Exit code: 0
- Output:
  ```
  --- /etc/sudoers main ---
  Defaults env_reset, mail_badpass, secure_path=...
  root ALL=(ALL:ALL) ALL
  %admin ALL=(ALL) ALL
  %sudo ALL=(ALL:ALL) ALL
  @includedir /etc/sudoers.d

  --- /etc/sudoers.d/ contents ---
  -r--r----- 90-binali-r    (binali_r ALL=(ALL) NOPASSWD: ALL)
  -r--r----- 90-cloud-init-users  (root ALL=(ALL) NOPASSWD:ALL)
  -r--r----- 90-tvolodi     (tvolodi ALL=(ALL) NOPASSWD: ALL)
  -r--r----- 90-viktor-d    (viktor_d ALL=(ALL) NOPASSWD: ALL)
  -r--r----- README (stock)

  --- syntactically valid? ---
  /etc/sudoers: parsed OK
  VISUDO_OK

  --- members of sudo + admin + wheel ---
  [sudo] sudo:x:27:tvolodi,viktor_d,binali_r
  [admin] admin:x:107: (empty)
  [wheel] (group does not exist)

  --- members of docker (effectively root) ---
  docker:x:986:tvolodi,viktor_d,binali_r
  ```
- Side effects observed: none.
- Note: matches landscape exactly. All 4 privileged identities (root + 3 operators) have passwordless full sudo via mode-0440 drop-ins; all 3 operators are also in `docker` group (root-equivalent). This is already-known, intentional design (T-0097), not new.

#### Probe E: Failed authentication & ban activity
- Command: auth.log grep for Failed/Invalid user/authentication failure, `last -n 30`, fail2ban-client status (+sshd jail +banned)
- Exit code: 0 (see note on re-check below)
- Output:
  ```
  --- recent failed sshd auths (auth.log) ---
  (initial grep returned no visible output — auth.log contains non-UTF8 bytes that made `grep -E` treat it as a binary file under this shell's locale; re-run with `grep -aE` below)
  --- last 30 successful logins ---
  bash: line 1: last: command not found
  --- fail2ban status ---
  /usr/bin/fail2ban-client
  Status
  |- Number of jail: 1
  `- Jail list: sshd
  --- fail2ban sshd jail ---
  Status for the jail: sshd
  |- Filter
  |  |- Currently failed: 0
  |  |- Total failed: 260
  |  `- Journal matches: _SYSTEMD_UNIT=ssh.service + _COMM=sshd
  `- Actions
     |- Currently banned: 0
     |- Total banned: 52
     `- Banned IP list: (empty)
  --- currently banned ---
  [{'sshd': []}]
  ```
  Re-check (read-only, `grep -a` to force text mode — same probe intent, no state change) confirmed the log is populated:
  ```
  $ sudo grep -aE 'Failed|Invalid user|authentication failure' /var/log/auth.log | tail -50
  ...continuous stream of "Invalid user <name> from <IP> port <port>" entries from ~15 distinct source IPs
  (2.57.122.209, 2.57.121.25, 45.118.144.36, 193.46.255.86, 2.57.121.112, 139.99.74.35,
   176.53.159.197, 82.165.175.206, etc.), usernames: admin, user, administrator, ansible,
   milan, apache, debian, ubuntu, odoo, support, orangepi, test, myla, tomcat, mirian
  Last few lines are our own probe commands being logged by syslog (sudo:root: COMMAND=/usr/bin/grep ...) — expected auditability, not a side effect.
  ```
- Side effects observed: none. (`last` binary is simply not installed on this minimal Ubuntu image — informational, not an error requiring remediation; command exited harmlessly.)
- Note: this is background internet-wide SSH scanning noise (never any valid username attempted, all rejected pre-auth), fully consistent with fail2ban's 260-total-failed / 52-total-banned counters and 0 currently banned/currently failed (attackers get banned and move on, or give up after a few tries below fail2ban's maxretry=3 threshold before triggering a ban in a given window). No successful/anomalous login indicators found.

#### Probe F: Listening services and exposure
- Command: `sudo ss -tlnp`, `sudo ss -ulnp`, summary awk for 0.0.0.0/:: binds
- Exit code: 0
- Output:
  ```
  --- TCP listeners ---
  127.0.0.1:3112       docker-proxy (pid=77537)   [Postgres, loopback only]
  127.0.0.54:53        systemd-resolve
  127.0.0.53%lo:53     systemd-resolve
  0.0.0.0:22           sshd
  [::]:22              sshd

  --- UDP listeners ---
  127.0.0.54:53        systemd-resolve
  127.0.0.53%lo:53     systemd-resolve
  127.0.0.1:323        chronyd
  [::1]:323            chronyd

  --- summary: bound to 0.0.0.0 or :: ---
  0.0.0.0:22  sshd
  [::]:22     sshd
  ```
- Side effects observed: none.
- Note: exactly matches landscape — only port 22 is publicly bindable; everything else is loopback-only. No drift.

#### Probe G: Firewall ruleset (UFW + iptables + nftables)
- Command: `ufw status verbose`, `iptables -L -n -v --line-numbers`, `ip6tables` same, `iptables -t nat -L DOCKER`, `nft list ruleset`
- Exit code: 0
- Output (relevant excerpt):
  ```
  Status: active
  Logging: on (low)
  Default: deny (incoming), allow (outgoing), allow (routed)
  22/tcp    ALLOW IN  Anywhere      # sshd - operator access T-0094 baseline
  22/tcp(v6) ALLOW IN Anywhere (v6) # sshd - operator access T-0094 baseline

  Chain INPUT (policy DROP) — f2b-sshd jump first, then ufw-before/after-input chains, ends DROP
  Chain FORWARD (policy DROP) — DOCKER-USER / DOCKER-FORWARD / ufw-*-forward chains
  Chain OUTPUT (policy ACCEPT)
  Chain DOCKER (nat) — 1 DNAT rule: tcp dpt:3112 to 172.18.0.2:5432 restricted to 127.0.0.1 dst (loopback-only publish)
  Chain f2b-sshd — 1 RETURN rule (no active bans at scan time; matches probe E's "0 currently banned")

  IPv6: Chain INPUT (policy DROP), FORWARD (policy ACCEPT after chain jumps — same DOCKER-* + ufw6-* structure as v4)

  nftables (ip filter table): mirrors the iptables ruleset (UFW backend uses legacy iptables that nft displays via the compat layer) — INPUT policy drop, FORWARD policy drop, OUTPUT policy accept; counters non-zero on before/after-input chains confirming active traffic filtering.
  ```
- Side effects observed: none.
- Note: matches landscape (UFW active, only 22/tcp allowed inbound, no source-IP allowlist — deliberate). FORWARD default-policy shows DROP at the table level but the Docker-injected jump chains (DOCKER-USER → DOCKER-FORWARD → ACCEPT for docker0/br-* interfaces) create an effective allow path for container traffic — this matches the documented T-0090 Phase A2 change and is intentional, not drift.

#### Probe H: Docker daemon and container security
- Command: `docker --version`, `docker info`, daemon.json check, per-container inspect (User/Privileged/CapAdd/CapDrop/SecurityOpt/ReadonlyRoot/PidMode/NetworkMode/PortBindings/Mounts/EnvKeys), image ages, healthcheck status
- Exit code: 0
- Output:
  ```
  Docker version 29.6.1, build 8900f1d
  Server=29.6.1 Containers=1 Images=1 StorageDriver=overlayfs CgroupDriver=systemd
  SecurityOpt=[name=apparmor name=seccomp,profile=builtin name=cgroupns]
  --- daemon config ---
  no daemon.json (defaults in effect)

  === container 223138e7d5d4 (ai-qadam-test-db-1) ===
  Image:         pgvector/pgvector:pg16
  User:          (empty — runs as image default, root inside container)
  Privileged:    false
  CapAdd:        []
  CapDrop:       []
  SecurityOpt:   []          (relies on daemon-level default apparmor+seccomp only; no container-level override)
  ReadonlyRoot:  false
  NetworkMode:   ai-qadam-test_default
  PortBindings:  5432/tcp -> 127.0.0.1:3112
  Mounts:        volume ai-qadam-test_ai_qadam_test_pgdata -> /var/lib/postgresql/data (rw=true)
  EnvKeys (names only): GOSU_VERSION, LANG, PATH, PGDATA, PG_MAJOR, PG_VERSION, POSTGRES_DB, POSTGRES_PASSWORD, POSTGRES_USER

  --- image ages ---
  pgvector/pgvector:pg16   9 days ago   621MB

  --- containers with no healthcheck ---
  /ai-qadam-test-db-1: health=healthy
  ```
- Side effects observed: none.
- Note: daemon-level apparmor+seccomp defaults are in effect (Docker's stock `docker-default` profile), but the container itself sets no additional hardening (no explicit non-root `User:`, no `CapDrop`, no `SecurityOpt` override, `ReadonlyRootfs: false`). This is standard for an off-the-shelf `pgvector/pgvector` image and consistent with a loopback-only, non-internet-facing database — worth a P2/P3 judgment call by step 07, not an emergency. `POSTGRES_PASSWORD` env key confirmed present (name only; per rules, value never read/echoed).

#### Probe I: nginx TLS posture
- Command: `nginx -V`, `nginx -T` grep, per-vhost TLS handshake loop, cert-file find
- Exit code: 0 (nginx binary absent; expected commands returned empty rather than erroring destructively)
- Output:
  ```
  --- nginx version + modules ---
  (empty — nginx not installed)
  --- effective config (trimmed) ---
  (empty)
  --- TLS handshake test ---
  (empty — no server_name entries to iterate)
  --- cert files on disk ---
  (30 stock CA bundle .pem files under /etc/ssl/certs/ — standard distro trust store, no application/service TLS certs found)
  ```
- Side effects observed: none.
- Note: **expected, not a failure.** Per step 01/02/03, nginx is deliberately not yet installed on this host (deferred to T-0090a). This probe correctly reconfirms that already-tracked state.

#### Probe J: Filesystem hygiene
- Command: world-writable file find (excluding tmp/proc/sys/dev/run/docker/log), SUID binary find, broken-ownership find, home dir permissions, `/etc/shadow`+`/etc/sudoers` permission check
- Exit code: 0
- Output:
  ```
  --- world-writable files ---
  (empty — none found outside excluded paths)

  --- SUID binaries ---
  /usr/bin/chfn, /usr/bin/chsh, /usr/bin/mount, /usr/bin/gpasswd, /usr/bin/newgrp,
  /usr/bin/passwd, /usr/bin/umount, /usr/bin/su, /usr/bin/fusermount3, /usr/bin/ntfs-3g,
  /usr/bin/sudo.ws, /usr/lib/openssh/ssh-keysign, /usr/lib/dbus-1.0/dbus-daemon-launch-helper
  (all standard distro SUID binaries)
  PLUS, non-standard location:
  /usr/lib/cargo/bin/su
  /usr/lib/cargo/bin/sudo
  (also duplicate listings under /var/lib/containerd/.../snapshots/1/fs/usr/bin/* — these are container image filesystem layers, not live host paths, since -xdev should exclude overlay mounts but containerd snapshot dirs live on the same root filesystem/device as /var/lib; informational, not independently exploitable)

  --- broken ownership (no user/no group) ---
  All findings are under /var/lib/containerd/.../snapshots/*/fs/{run,etc,var/lib}/postgresql* —
  i.e. uid/gid mappings internal to the Postgres container image layer (postgres user doesn't
  exist in the host's /etc/passwd), not live host files. No broken ownership on real host paths.

  --- home directory permissions ---
  /home: drwxr-xr-x root:root; binali_r/tvolodi/viktor_d homes all drwxr-x--- (750), owned correctly, no group/other access beyond own user
  /root: drwx------ (700), correctly locked down

  --- /etc/shadow + /etc/sudoers permissions ---
  -rw-r----- root:shadow  /etc/gshadow
  -rw-r--r-- root:root    /etc/passwd   (normal, world-readable is expected for passwd)
  -rw-r----- root:shadow  /etc/shadow
  -r--r----- root:root    /etc/sudoers
  ```
- Side effects observed: none.
- Note: `/usr/lib/cargo/bin/su` and `/usr/lib/cargo/bin/sudo` are unusual — not a standard Ubuntu package location for these binary names. This warrants step 07's judgment (could be a snap/cargo-installed Rust tool shipping oddly-named binaries, or something worth a closer look) — flagged as a finding, not confirmed as malicious.

#### Probe K: Secrets-on-disk scan
- Command: `.env` file find, world-readable env-file find, key-file find (id_rsa/id_ed25519/*.key/*.pem/*.pfx/known_hosts outside /etc/ssl), bash/zsh history secret-pattern count (count only, no content printed)
- Exit code: 0
- Output:
  ```
  --- compose .env files ---
  /var/www/ai-qadam-test/.env

  --- world-readable env files (BAD) ---
  (empty — the above .env is NOT world-readable)

  --- key files ---
  /var/lib/fwupd/pki/client.pem, /var/lib/fwupd/pki/secret.key (stock fwupd PKI, not application secrets)
  /etc/pki/fwupd*/LVFS-CA*.pem (stock fwupd CA trust anchors)
  Assorted container-layer / python package test fixtures (twisted test/fake_CAs/*.pem, botocore cacert.pem) — not live secrets
  No id_rsa/id_ed25519/user-generated *.key or *.pem found outside standard system locations.

  --- bash/zsh histories with secret-ish patterns ---
  (empty output — no history files matched any of /root/.bash_history, /root/.zsh_history,
   or per-operator .bash_history/.zsh_history; none exist on this host)
  ```
- Side effects observed: none.
- Note: matches landscape (`.env` at `/var/www/ai-qadam-test/.env`, mode 600 confirmed not-world-readable). No secrets-inventory.md cross-reference was possible per step 02's known gap (file scrubbed/gitignored per T-0091) — this finding is assessed standalone: the one `.env` file found is properly permissioned, no other credential material discovered on disk.

#### Probe L: Cron and scheduled task review
- Command: per-user crontab dump, `/etc/cron.*` listing, `/etc/crontab`, `systemctl list-timers --all`
- Exit code: 0
- Output:
  ```
  --- per-user crontabs ---
  (empty — root + all 3 operators have no crontab entries)

  --- /etc/cron.d/ etc. ---
  /etc/cron.d/: only .placeholder + stock e2scrub_all
  /etc/cron.daily/: stock apport, apt-compat, dpkg, logrotate, man-db
  /etc/cron.hourly/, /etc/cron.monthly/: only .placeholder
  /etc/cron.weekly/: only .placeholder + stock man-db

  --- /etc/crontab ---
  stock run-parts entries only (hourly/daily/weekly/monthly via anacron fallback)

  --- systemd timers (19 total) ---
  sysstat-collect/rotate/summary, fwupd-refresh, apt-daily(-upgrade), motd-news, man-db,
  update-notifier-download/motd, systemd-tmpfiles-clean, dpkg-db-backup, logrotate,
  e2scrub_all, xfs_scrub_all, fstrim, apport-autoreport, snapd.snap-repair, ua-timer
  — all stock Ubuntu timers, no custom/application timers present.
  ```
- Side effects observed: none.
- Note: matches landscape exactly — no custom cron/timer jobs, confirms no app-level backup timer exists (reconfirms T-0098's open observation, not new).

#### Probe M: Running services and binaries
- Command: listener-to-binary-to-package mapping, enabled-service listing, failed-unit check
- Exit code: 0
- Output:
  ```
  --- services listening + binary path ---
  pid=28263 proc=systemd-resolve bin=/usr/lib/systemd/systemd-resolved pkg=systemd-resolved
  pid=55364 proc=sshd            bin=/usr/sbin/sshd                    pkg=openssh-server
  pid=77537 proc=docker-proxy    bin=/usr/bin/docker-proxy              pkg=docker-ce

  --- enabled but not running services (first 40) ---
  apparmor, apport, blk-availability, chrony, cloud-config/final/local/main/network,
  console-setup, containerd, cron, dmesg, docker, e2scrub_reap, fail2ban, finalrd,
  getty@, grub-initrd-fallback, grub2-common, keyboard-setup, lvm2-monitor, ModemManager,
  multipathd, netplan-configure, networkd-dispatcher, open-iscsi, open-vm-tools, pollinate,
  rsyslog, secureboot-db, setvtrgb, snapd.*, sshd-keygen — all stock/expected units
  (this list command shows "enabled" services regardless of current active state; several
  of these, e.g. docker/fail2ban/cron, ARE actively running — this list is not itself a
  "stale install" signal on its own, just the full enabled-units inventory truncated to 40)

  --- failed units ---
  0 loaded units listed. (no failed units)
  ```
- Side effects observed: none.
- Note: every listening process maps to an expected, package-managed binary — no unmanaged/unexpected listener. No failed systemd units. Clean result.

#### Probe N: Audit logs and security tooling presence
- Command: auditd presence/active check, `aa-status`, SELinux check, auth.log retention listing, journal disk usage
- Exit code: 0
- Output:
  ```
  --- auditd ---
  auditd not present

  --- AppArmor profiles in enforce mode ---
  apparmor module is loaded.
  180 profiles are loaded.
  104 profiles are in enforce mode.
  (docker-default among enforced profiles, confirming probe H's SecurityOpt=apparmor finding)

  --- SELinux ---
  SELinux not present

  --- /var/log/auth.log retention ---
  -rw-r----- 1 syslog adm 8129239 Jul 10 02:15 /var/log/auth.log   (single file, 8.1MB, no rotated .1/.gz siblings currently present)

  --- journal disk usage ---
  Archived and active journals take up 132.5M in the file system.
  ```
- Side effects observed: none.
- Note: auditd absence reconfirms T-0096 (already an open observation task — no new task should be created). AppArmor 180 loaded / 104 enforce is a small increment over landscape's recorded 179/103 (both recorded 2 days apart) — not material drift, informational only. No auth.log rotation files present alongside the current 8.1MB file; worth noting as informational (logrotate.timer is active per probe L and should rotate it on schedule — no evidence of a rotation failure, just no historical rotated file yet at this point in the log's lifecycle).

#### Probe O: Cloudflare-edge-vs-host sanity (cross-reference, not state change)
- Command: `ufw status numbered` filtered to ALLOW/DENY, `ss -tlnp` filtered to ports 22/80/443
- Exit code: 0
- Output:
  ```
  [ 1] 22/tcp      ALLOW IN Anywhere     # sshd - operator access T-0094 baseline
  [ 2] 22/tcp (v6) ALLOW IN Anywhere (v6) # sshd - operator access T-0094 baseline

  --- ports 22/80/443 listener check ---
  0.0.0.0:22  sshd
  [::]:22     sshd
  expected exposed ports OK
  ```
- Side effects observed: none.
- Note: Cloudflare-fronting half of this probe is N/A for this host (pro-data.tech has no Cloudflare presence, confirmed by step 02) — the host-only half executed cleanly: only port 22 is both listening and UFW-allowed; ports 80/443 are neither open in UFW nor listened on. No drift from expected exposed-port set.

### Findings summary (for step 07 validator + step 08 updater)
- Kernel 7.0.0-14 running while 7.0.0-27 is installed/available and `/var/run/reboot-required` is set (host has not been rebooted in 2+ days despite a newer kernel package being available) — source: probe B. This is a drift from landscape's "0 pending upgrades as of 2026-07-07" snapshot; 9 packages (incl. kernel meta-packages) are now pending, 0 of which are tagged `-security` by the naive grep heuristic (kernel updates typically land in `-updates`, not `-security`, so this doesn't necessarily indicate an unpatched CVE, but the reboot-required state itself is worth judging).
- sshd hardening (ciphers/KEX/MACs/AllowGroups/PermitRootLogin/etc.) exactly matches landscape and T-0093 — no drift — source: probe C.
- sudoers configuration (4 NOPASSWD identities: root + 3 operators, all mode-0440 drop-ins, visudo-valid) exactly matches landscape and T-0097 — no drift — source: probe D.
- fail2ban active, sshd jail enforcing (260 total failed, 52 total banned historically, 0 currently banned/failed at scan time) — no drift — source: probe E.
- Continuous internet-background SSH brute-force scanning observed in auth.log (multiple source IPs, common default usernames: admin/user/ubuntu/debian/etc.) — all pre-auth rejections, no successful or anomalous logins — informational only, already mitigated by fail2ban — source: probe E (re-checked with `grep -a` after initial binary-file false negative).
- Only port 22/tcp is publicly listening and UFW-allowed; all other listeners (Postgres 3112, DNS 53, chrony 323) are loopback-only — matches landscape exactly — source: probes F, G, O.
- UFW default-deny-incoming policy active and logging; iptables/nftables rulesets consistent with UFW + Docker's injected chains (DOCKER-USER/DOCKER-FORWARD) — no drift — source: probe G.
- Docker container `ai-qadam-test-db-1` runs with daemon-default apparmor+seccomp only; no container-level `User`, `CapDrop`, `SecurityOpt`, or `ReadonlyRootfs` hardening applied; not privileged; loopback-only port publish — source: probe H.
- nginx not installed — reconfirms already-tracked [T-0090a](../../tasks/T-0090a-prepare-qadam-test-public-https-endpoint.md), not a new finding — source: probe I.
- No world-writable files found on live host paths (only within containerd image-layer snapshot dirs, not independently exploitable) — source: probe J.
- SUID binaries include two non-standard-location copies (`/usr/lib/cargo/bin/su`, `/usr/lib/cargo/bin/sudo`) in addition to the expected `/usr/bin/*` standard set — source: probe J. Warrants step 07 judgment (likely a Rust/cargo-installed tool, not necessarily malicious, but non-standard).
- `/etc/shadow`, `/etc/gshadow`, `/etc/sudoers` all correctly permissioned (root-owned, group-restricted or root-only) — no drift — source: probe J.
- One `.env` file found (`/var/www/ai-qadam-test/.env`), confirmed NOT world-readable — matches landscape's documented mode 600 — source: probe K.
- No stray private keys, no world-readable env files, no secret-pattern hits in shell histories (no shell history files exist on this host) — source: probe K.
- No custom cron jobs or systemd timers beyond stock Ubuntu ones — reconfirms no app-level backup mechanism exists, which is already tracked as [T-0098](../../tasks/T-0098-host-level-backup-strategy-for-pro-data-tech-qa.md), not a new finding — source: probe L.
- All listening processes map to expected, package-managed binaries (systemd-resolved, sshd/openssh-server, docker-proxy/docker-ce); no failed systemd units — source: probe M.
- auditd not installed — reconfirms already-tracked [T-0096](../../tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md), not a new finding — source: probe N.
- AppArmor active, 180 profiles loaded / 104 enforce (landscape recorded 179/103 two days prior — negligible increment, not material drift) — source: probe N.
- No auth.log rotation siblings present yet alongside the current 8.1MB file; logrotate.timer is active and scheduled — informational, not a fault — source: probes L, N.
- Cloudflare cross-reference (probe O) is N/A for this host (no Cloudflare fronting); host-only port-exposure check confirms exactly the expected set (22 only) — source: probe O.

### Files this run will propose for landscape update
- `landscape/hosts/pro-data-tech-qa.md` — sections: frontmatter `last_verified:` date, Change log row (per workflow's step 08 guidance — audit findings live in new task files, not landscape body rewrites).
- New observation task file(s) as judged by step 07 for: (a) kernel/reboot-required drift (probe B), and (b) non-standard SUID binary locations (probe J) — pending step 07's severity assignment. Container-hardening gap (probe H) may also warrant a new observation task at step 07's discretion (P2-ish per the workflow's Findings policy table: "container without healthcheck" is explicitly P2 in the policy table, but this container DOES have a healthcheck — the missing item here is capability/user hardening, a related but distinct gap step 07 should classify).

## Issues / risks
- Probe E's auth.log grep initially returned no visible output due to the file being treated as a binary match by `grep -E` under the SSH session's locale (embedded non-UTF8 bytes from attempted usernames/encodings in the log stream). This was caught and re-verified read-only with `grep -a` (force-text) before finalizing this handoff — same probe intent, no state change, just a display/encoding correction. Flagging so step 07 does not mistake the corrected re-run for an additional, unplanned probe.
- No side effects were observed from any probe. The only writes visible in probes' own output are auth.log/journal entries generated by syslog logging our own `sudo` invocations — this is normal system auditability of command execution, not a file/state modification caused by probe content itself.

## Open questions (optional)
- Should the kernel/reboot-required drift (probe B) and the reboot itself be scoped as a new observation task now, or folded into a broader "apply pending host updates + reboot" state-changing follow-up task? Recommend step 07 assign severity and step 08 create the task; the actual reboot action itself is out of scope for this read-only audit run.
- The `/usr/lib/cargo/bin/su` and `/usr/lib/cargo/bin/sudo` SUID binaries were not further inspected (e.g., `dpkg -S`, file provenance, hash comparison) since doing so was outside the literal probe J command as specified in the workflow. Step 07 may want a follow-up read-only inspection to determine if these are a legitimate Rust toolchain artifact (e.g., a `sudo`-like wrapper crate) or something requiring escalation.
