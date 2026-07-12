---
run_id: 2026-07-11-install-docker-pro-data-tech-prod-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0106-install-docker-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - root@95.46.211.224:/var/backups/ufw-after.rules-pre-T0106.bak
  - root@95.46.211.224:/etc/apt/keyrings/docker.gpg
  - root@95.46.211.224:/etc/apt/sources.list.d/docker.list
  - root@95.46.211.224:/etc/ufw/after.rules
  - root@95.46.211.224:packages:docker-ce=5:29.6.1,docker-ce-cli,containerd.io=2.2.6,docker-buildx-plugin=0.35.0,docker-compose-plugin=5.3.1
  - root@95.46.211.224:systemd:docker.service=enabled/active
  - root@95.46.211.224:group:docker+=tvolodi
next_step_hint: proceed to execution-validator (step 07)
---

## Summary

Executed all 15 plan steps in order against `root@95.46.211.224`. Docker Engine 29.6.1 and Compose plugin v5.3.1 are installed from the official Docker apt repo, UFW after.rules updated with DOCKER-USER/MASQUERADE coexistence rules (T-0106), Docker daemon enabled and running, `tvolodi` added to the `docker` group, and `docker run hello-world` confirmed "Hello from Docker!".

## Details

### Pre-execution checks
- step-04 verdict: `NEEDS_APPROVAL` ✓
- step-05 file present: yes ✓
- step-05 verdict: `APPROVED` ✓
- step-05 `inputs_read` references step-04: yes ✓
- All approval gate checks passed; proceeding with execution.

### Execution log

#### Step 1: Backup /etc/ufw/after.rules
- Command: `cp /etc/ufw/after.rules /var/backups/ufw-after.rules-pre-T0106.bak && test -f /var/backups/ufw-after.rules-pre-T0106.bak && echo BACKUP_OK`
- Exit code: 0
- Output:
  ```
  BACKUP_OK
  ```
- Result: success
- Backup taken: `/var/backups/ufw-after.rules-pre-T0106.bak`

#### Step 2: Probe outbound HTTPS to Docker CDN
- Command: `curl -s --max-time 10 https://download.docker.com/linux/ubuntu/gpg > /dev/null && echo OUTBOUND_OK`
- Exit code: 0
- Output:
  ```
  OUTBOUND_OK
  ```
- Result: success

#### Step 3: apt-get install ca-certificates curl gnupg lsb-release
- Command: `DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release`
- Exit code: 0
- Output (trimmed):
  ```
  ca-certificates is already the newest version (20260601~26.04.1).
  curl is already the newest version (8.18.0-1ubuntu2.3).
  gnupg is already the newest version (2.4.8-4ubuntu3).
  lsb-release is already the newest version (12.1-2build1).
  0 upgraded, 0 newly installed, 0 to remove and 9 not upgraded.
  ```
- Result: success (all prerequisites already present)

#### Step 4: Create /etc/apt/keyrings directory
- Command: `install -m 0755 -d /etc/apt/keyrings && echo KEYRINGS_DIR_OK`
- Exit code: 0
- Output:
  ```
  KEYRINGS_DIR_OK
  ```
- Result: success

#### Step 5: Install Docker GPG key into apt keyring
- Command: `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && chmod a+r /etc/apt/keyrings/docker.gpg && test -f /etc/apt/keyrings/docker.gpg && echo GPG_OK`
- Exit code: 0
- Output:
  ```
  GPG_OK
  ```
- Result: success

#### Step 6: Add Docker stable apt repository
- Command: `echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && cat /etc/apt/sources.list.d/docker.list`
- Exit code: 0
- Output:
  ```
  deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu resolute stable
  ```
- Result: success — contains `download.docker.com` and `resolute`

#### Step 7: apt-get update
- Command: `apt-get update`
- Exit code: 0
- Output (trimmed):
  ```
  Get:1 https://download.docker.com/linux/ubuntu resolute InRelease [32.5 kB]
  Get:4 https://download.docker.com/linux/ubuntu resolute/stable amd64 Packages [20.0 kB]
  Fetched 52.5 kB in 1s (59.9 kB/s)
  Reading package lists...
  ```
- Result: success — no `E:` errors; Docker repo fetched successfully

#### Step 8: Install Docker Engine and Compose plugin
- Command: `DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
- Exit code: 0
- Output (trimmed):
  ```
  The following NEW packages will be installed:
    containerd.io docker-buildx-plugin docker-ce docker-ce-cli
    docker-ce-rootless-extras docker-compose-plugin pigz
  0 upgraded, 7 newly installed, 0 to remove and 9 not upgraded.
  Get:2 containerd.io 2.2.6-1~ubuntu.26.04~resolute [23.6 MB]
  Get:3 docker-ce-cli 5:29.6.1-1~ubuntu.26.04~resolute [16.9 MB]
  Get:4 docker-ce 5:29.6.1-1~ubuntu.26.04~resolute [23.3 MB]
  Get:5 docker-buildx-plugin 0.35.0-1~ubuntu.26.04~resolute [17.2 MB]
  Get:6 docker-ce-rootless-extras 5:29.6.1-1~ubuntu.26.04~resolute [10.2 MB]
  Get:7 docker-compose-plugin 5.3.1-1~ubuntu.26.04~resolute [8100 kB]
  Fetched 99.4 MB in 9s (11.3 MB/s)
  Setting up docker-ce (5:29.6.1-1~ubuntu.26.04~resolute) ...
  Created symlink '/etc/systemd/system/multi-user.target.wants/docker.service' → '/usr/lib/systemd/system/docker.service'.
  Created symlink '/etc/systemd/system/sockets.target.wants/docker.socket' → '/usr/lib/systemd/system/docker.socket'.
  ```
- Result: success — all 7 packages installed; Docker postinst auto-started daemon briefly

#### Step 9: Stop Docker before writing after.rules
- Command: `systemctl stop docker.service docker.socket containerd.service; systemctl is-active docker.service; echo STOP_DONE`
- Exit code: 0
- Output:
  ```
  inactive
  STOP_DONE
  ```
- Result: success — docker.service is inactive

#### Step 10: Append Docker UFW coexistence rules to /etc/ufw/after.rules
- Idempotency guard: `grep -c 'T-0106' /etc/ufw/after.rules` → `0` (block not present; safe to append)
- Command: `printf '\n# BEGIN Docker UFW coexistence rules (T-0106)\n*filter\n:DOCKER-USER - [0:0]\n-A DOCKER-USER -i eth0 -j RETURN\nCOMMIT\n*nat\n:POSTROUTING - [0:0]\n-A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE\nCOMMIT\n# END Docker UFW coexistence rules (T-0106)\n' >> /etc/ufw/after.rules && grep -c 'T-0106' /etc/ufw/after.rules`
- Exit code: 0
- Output:
  ```
  2
  ```
- Result: success — `grep -c 'T-0106'` returns 2 (BEGIN and END comment lines)
- Backup taken: n/a (backup taken in step 1 before any modification)

#### Step 11: ufw reload
- Command: `ufw reload && ufw status && iptables -t nat -L POSTROUTING -n`
- Exit code: 0
- Output:
  ```
  Firewall reloaded
  Status: active

  To                         Action      From
  --                         ------      ----
  22/tcp                     ALLOW       Anywhere
  80/tcp                     ALLOW       Anywhere
  443/tcp                    ALLOW       Anywhere
  22/tcp (v6)                ALLOW       Anywhere (v6)
  80/tcp (v6)                ALLOW       Anywhere (v6)
  443/tcp (v6)               ALLOW       Anywhere (v6)

  Chain POSTROUTING (policy ACCEPT)
  target     prot opt source               destination
  MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0
  MASQUERADE  all  --  172.16.0.0/12        0.0.0.0/0
  ```
- Result: success — UFW reloaded; MASQUERADE and `172.16.0.0/12` present in POSTROUTING. The first MASQUERADE rule (`172.17.0.0/16`) was inserted by Docker's own iptables management during its brief auto-start after step 8; it is expected and Docker will manage its own rules on start/stop. The `-o eth0` output-interface constraint on the T-0106 rule is present in the actual rule (it was written to after.rules); `iptables -L` in non-verbose mode does not display the output interface column.

#### Step 12: Enable and start Docker
- Command: `systemctl enable docker && systemctl start docker && systemctl is-active docker && systemctl is-enabled docker`
- Exit code: 0
- Output:
  ```
  Synchronizing state of docker.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
  Executing: /usr/lib/systemd/systemd-sysv-install enable docker
  active
  enabled
  ```
- Result: success — docker.service is active and enabled

#### Step 13: Add tvolodi to docker group
- Command: `usermod -aG docker tvolodi && id tvolodi`
- Exit code: 0
- Output:
  ```
  uid=1000(tvolodi) gid=1001(tvolodi) groups=1001(tvolodi),27(sudo),1000(sshusers),986(docker)
  ```
- Result: success — tvolodi is in docker group (gid 986)

#### Step 14: docker run hello-world
- Command: `docker run hello-world`
- Exit code: 0
- Output (trimmed):
  ```
  Unable to find image 'hello-world:latest' locally
  latest: Pulling from library/hello-world
  4f55086f7dd0: Pull complete
  Digest: sha256:96498ffd522e70807ab6384a5c0485a79b9c7c08ca79ba08623edcad1054e62d
  Status: Downloaded newer image for hello-world:latest

  Hello from Docker!
  This message shows that your installation appears to be working correctly.
  ```
- Result: success — "Hello from Docker!" confirmed; image pulled from Docker Hub; daemon is functional

#### Step 15: docker compose version
- Command: `docker compose version`
- Exit code: 0
- Output:
  ```
  Docker Compose version v5.3.1
  ```
- Result: success — Compose plugin v5.3.1 installed and accessible

### Rollback executed
Not needed — all 15 steps succeeded.

### Resources changed
- Files on host:
  - `/var/backups/ufw-after.rules-pre-T0106.bak` — backup of pre-install after.rules
  - `/etc/apt/keyrings/docker.gpg` — Docker APT signing key
  - `/etc/apt/sources.list.d/docker.list` — Docker stable apt repository entry
  - `/etc/ufw/after.rules` — appended DOCKER-USER filter chain + MASQUERADE nat rule (T-0106 block)
- Packages installed: `docker-ce` (5:29.6.1), `docker-ce-cli`, `containerd.io` (2.2.6), `docker-buildx-plugin` (0.35.0), `docker-compose-plugin` (5.3.1), `docker-ce-rootless-extras`, `pigz`
- Services changed: `docker.service` → enabled/active; `containerd.service` → active
- User group change: `tvolodi` added to group `docker` (gid 986)
- External resources changed: none

## Issues / risks
- The `172.17.0.0/16 MASQUERADE` rule visible in `iptables -t nat -L POSTROUTING -n` was inserted by Docker's postinst auto-start (between step 8 install and step 9 stop). Docker manages these rules itself; they will be cleaned up and re-added normally as Docker starts and stops. Not a risk.
- `tvolodi` will not be able to run `docker` without `sudo` until opening a new SSH session (group membership applies on next login). `docker run hello-world` in step 14 was run as root; this is the correct workaround per the plan.
- 9 pending package upgrades remain on the host (pre-existing from discovery; not introduced by this run). Including kernel `7.0.0-14-generic` being two minor versions behind the QA host. Non-blocking but warrants a separate upgrade run.
- `auditd` is not installed (gap noted in landscape file). Non-blocking; warrants a separate task.

## Open questions
- none
