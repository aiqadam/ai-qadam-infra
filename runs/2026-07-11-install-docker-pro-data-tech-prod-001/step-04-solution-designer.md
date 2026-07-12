---
run_id: 2026-07-11-install-docker-pro-data-tech-prod-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-11T00:00:00Z
task_id: T-0106-install-docker-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-02-landscape-reader.md
  - runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — NEEDS_APPROVAL: package install + iptables modification on prod
---

## Summary

Install Docker Engine 29.x (official Docker apt repo, keyring method) and the Docker Compose v2 plugin on `pro-data-tech-prod` (95.46.211.224, Ubuntu 26.04 "resolute"), with UFW/Docker iptables coexistence handled via `/etc/ufw/after.rules` DOCKER-USER chain — keeping `DEFAULT_FORWARD_POLICY=DROP` intact — and `tvolodi` added to the `docker` group.

## Details

### Why NEEDS_APPROVAL

This plan touches prod with package installs, iptables rule modifications via after.rules, a service enablement, and a user group change. Per `shared/approval-protocol.md`, any of these individually mandates `NEEDS_APPROVAL`; all four together make this unambiguous.

### Plan

All commands run on-host as `tvolodi` via `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.224`. Commands requiring root are prefixed with `sudo`.

**Step 1 — Connectivity probe**
Confirm outbound HTTPS to the Docker CDN is reachable before committing to an install.
- Command: `curl -s --max-time 10 https://download.docker.com/linux/ubuntu/gpg > /dev/null && echo CONNECTIVITY_OK`
- Verification: output contains `CONNECTIVITY_OK`; non-zero exit or timeout → abort, escalate to user.

**Step 2 — Backup current after.rules**
Capture a snapshot of the current `/etc/ufw/after.rules` before any modification, consistent with T-0103 backup convention.
- Command: `sudo cp /etc/ufw/after.rules /var/backups/ufw-after.rules-pre-T0106.bak`
- Verification: `test -f /var/backups/ufw-after.rules-pre-T0106.bak && echo BACKUP_OK`

**Step 3 — Read current after.rules content (idempotency guard)**
Confirm no DOCKER-USER or MASQUERADE rules already exist before appending, to prevent duplicate rules if this plan is re-run.
- Command: `sudo cat /etc/ufw/after.rules`
- Verification: output does NOT contain `DOCKER-USER` or the string `T-0106`. If either is present, STOP and alert — the rule block was already appended on a previous attempt; skip steps 9–10 (after.rules write and ufw reload) and continue from step 11.

**Step 4 — Install apt prerequisites**
- Command: `sudo apt-get install -y ca-certificates curl gnupg lsb-release`
- Verification: `dpkg -l ca-certificates curl gnupg lsb-release | grep -c '^ii'` returns `4`

**Step 5 — Install Docker GPG key into apt keyring**
- Command: `sudo install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && sudo chmod a+r /etc/apt/keyrings/docker.gpg`
- Verification: `test -f /etc/apt/keyrings/docker.gpg && echo GPG_OK`

**Step 6 — Add Docker stable apt repository**
Uses `lsb_release -cs` which returns `resolute` on Ubuntu 26.04 (confirmed working on QA host pro-data-tech-qa, same OS, Docker 29.6.1 installed via identical method).
- Command: `echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null`
- Verification: `cat /etc/apt/sources.list.d/docker.list` — output contains `download.docker.com` and `resolute`

**Step 7 — Update apt package index**
- Command: `sudo apt-get update`
- Verification: command exits 0; no `E:` error lines for the Docker repo; output contains `download.docker.com`

**Step 8 — Install Docker Engine and Compose plugin**
Installs docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin. **Note:** Docker's postinst script will auto-start the daemon immediately on install. Step 9 stops it before any container workload, to ensure after.rules is in place first.
- Command: `sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
- Verification: `docker --version` prints a version string starting with `Docker version`; command exits 0

**Step 9 — Stop Docker immediately (before after.rules is written)**
Docker's postinst starts the daemon, but containers must not run until UFW after.rules is in place. Stop the service and socket units now.
- Command: `sudo systemctl stop docker.service docker.socket containerd.service`
- Verification: `systemctl is-active docker.service` returns `inactive`

**Step 10 — Append Docker UFW coexistence rules to `/etc/ufw/after.rules`**
Uses the DOCKER-USER chain approach with the MASQUERADE rule scoped to `-o eth0` (public interface only), explicitly excluding `eth1` (192.168.0.3/24 private LAN) to prevent masquerading private LAN traffic through the public interface. This deviates from the naive `! -o docker0` pattern; see Issues / risks for rationale.

- Command:
  ```
  sudo tee -a /etc/ufw/after.rules > /dev/null << 'DOCKERRULES'

  # BEGIN Docker UFW coexistence rules (T-0106)
  *filter
  :DOCKER-USER - [0:0]
  -A DOCKER-USER -i eth0 -j RETURN
  COMMIT
  *nat
  :POSTROUTING - [0:0]
  -A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE
  COMMIT
  # END Docker UFW coexistence rules (T-0106)
  DOCKERRULES
  ```
- Verification: `grep -c 'T-0106' /etc/ufw/after.rules` returns `2`

**Step 11 — Reload UFW**
Applies the new iptables rules without interrupting active connections.
- Command: `sudo ufw reload`
- Verification: `sudo ufw status` exits 0; `sudo iptables -t nat -L POSTROUTING -n` output contains `MASQUERADE` and `172.16.0.0/12`

**Step 12 — Enable and start Docker**
- Command: `sudo systemctl enable docker && sudo systemctl start docker`
- Verification: `systemctl is-active docker` returns `active`; `systemctl is-enabled docker` returns `enabled`

**Step 13 — Add tvolodi to the docker group**
The `docker` group is created by the Docker package install. After adding, `tvolodi` can run docker commands without sudo in a new login session.
- Command: `sudo usermod -aG docker tvolodi`
- Verification: `id tvolodi | grep docker` contains `docker`

**Step 14 — Verify: docker run hello-world**
Runs as sudo since the current SSH session's group membership for `tvolodi` won't reflect the new docker group until re-login.
- Command: `sudo docker run hello-world`
- Verification: output contains `Hello from Docker!`; command exits 0

**Step 15 — Verify: docker compose version**
- Command: `docker compose version`
- Verification: output starts with `Docker Compose version v`; command exits 0

---

### Rollback

If any step fails after step 8, apply the following in order:

1. Stop Docker: `sudo systemctl stop docker.service docker.socket containerd.service`
2. Remove tvolodi from docker group (if added): `sudo deluser tvolodi docker`
3. Restore after.rules from backup and reload UFW: `sudo cp /var/backups/ufw-after.rules-pre-T0106.bak /etc/ufw/after.rules && sudo ufw reload`
4. Remove Docker packages: `sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && sudo apt-get autoremove -y`
5. Remove Docker keyring file: `sudo rm -f /etc/apt/keyrings/docker.gpg`
6. Remove Docker apt list: `sudo rm -f /etc/apt/sources.list.d/docker.list`
7. Verify UFW is still active and unmodified: `sudo ufw status` and `sudo cat /etc/ufw/after.rules`

Rollback is **fully reversible**: Docker leaves no persistent data on a fresh install where no containers were started in production. The backup at `/var/backups/ufw-after.rules-pre-T0106.bak` (step 2) makes the after.rules change reversible.

If rollback is required before step 8: no rollback needed — no state has been changed (steps 1–7 are read-only or idempotent prerequisites).

---

### Verification (for step 07)

**On-host checks:**
- `dpkg -l docker-ce | grep '^ii'` — Docker CE installed
- `dpkg -l docker-compose-plugin | grep '^ii'` — Compose plugin installed
- `systemctl is-active docker` = `active`
- `systemctl is-enabled docker` = `enabled`
- `docker --version` exits 0, output begins `Docker version`
- `docker compose version` exits 0, output begins `Docker Compose version v`
- `sudo docker run hello-world` exits 0, output contains `Hello from Docker!`
- `id tvolodi | grep docker` — tvolodi is in docker group
- `grep 'T-0106' /etc/ufw/after.rules` — marker lines present (idempotency proof)
- `sudo iptables -t nat -L POSTROUTING -n` — contains `MASQUERADE` with source `172.16.0.0/12` targeting `eth0`
- `sudo ufw status` — shows `Status: active`; FORWARD policy still `DROP` (verify with `grep DEFAULT_FORWARD_POLICY /etc/default/ufw`)
- `test -f /var/backups/ufw-after.rules-pre-T0106.bak` — backup exists

**External checks:**
- No external check required. The Docker install does not expose any new public-internet listener. No UFW ALLOW rules are added for Docker-managed ports (none needed for a baseline install with no containers running).

---

### Resources used

- **Secrets (by name):** none
- **Files modified on host:**
  - `/etc/apt/keyrings/docker.gpg` (created)
  - `/etc/apt/sources.list.d/docker.list` (created)
  - `/etc/ufw/after.rules` (appended)
  - `/var/backups/ufw-after.rules-pre-T0106.bak` (created — backup)
  - System package database (`dpkg`, `/var/lib/apt/`) — modified by apt-get
  - systemd unit state: `docker.service` and `containerd.service` enabled and active
  - `/etc/group` — `docker` group created; `tvolodi` added
- **Files modified in this repo (landscape/):** `landscape/hosts/pro-data-tech-prod.md` — to be updated at step 08 (Docker installed, after.rules state, tvolodi in docker group, run reference)
- **External APIs called:** `download.docker.com` (GPG key fetch, apt index, package download), `registry-1.docker.io` (hello-world image pull)

### Estimated impact

- **Downtime:** none for existing services. The only active listener is sshd; Docker installation and UFW reload do not interrupt it. `ufw reload` performs a non-disruptive ruleset reload.
- **Affected services:** none currently running on this host (baseline only; no application services deployed).
- **Reversibility:** fully reversible (see Rollback section above).

## Issues / risks

- **MASQUERADE rule scoped to `-o eth0`, not `! -o docker0`:** The task instructions specify `! -o docker0` for the POSTROUTING MASQUERADE rule. Steps 02 and 03 both flag that prod has a second interface `eth1` (192.168.0.3/24, private LAN) absent on QA. Using `! -o docker0` would masquerade container traffic exiting through `eth1` as well as `eth0`, potentially routing Docker-originating traffic onto the private LAN with the wrong source IP. This design uses `-o eth0` instead, which masquerades only container traffic leaving through the public interface. **This is a deliberate, safe deviation from the task instructions.** If containers need to reach `eth1`-local hosts (e.g., the QA server on 192.168.0.x) the routing will still function, but those packets will carry the container source IP (172.x.x.x), which is correct for a private LAN peer that has the route back. Flag for human reviewer.

- **Docker postinst auto-starts the daemon:** Ubuntu's Docker packages start `docker.service` via systemd postinst hooks. Step 9 explicitly stops the daemon before after.rules is written; this is the critical ordering. Executor must not skip or reorder step 9.

- **`lsb_release -cs` returns `resolute` on Ubuntu 26.04:** The Docker apt repo at `download.docker.com/linux/ubuntu/dists/resolute/` must exist. This was confirmed working on the QA host (same OS, Docker 29.6.1 installed). If the apt-get update step (step 7) returns `404 Not Found` for the resolute channel, the executor must STOP and escalate — this would require a workaround (e.g., using the `noble` codename), which would need a new design.

- **12 pending package upgrades on prod:** `apt-get install docker-ce` does not run a full `apt-get upgrade`, so the 12 outstanding upgrades are NOT pulled in by this plan. This is intentional — a full `apt-get upgrade` may pull a newer kernel requiring a reboot, which is out of scope. The 12 pending upgrades remain outstanding after this run. A separate task should address them.

- **`docker run hello-world` requires outbound 443 to Docker Hub (registry-1.docker.io):** UFW allows outgoing by default; this should pass. However, the pro-data.tech provider-level firewall (if any) is unknown. The connectivity probe in step 1 only checks `download.docker.com` (the package CDN), not `registry-1.docker.io` (the image registry). If the hello-world pull fails due to a provider-level egress block on registry-1.docker.io, that is an execution-time blocker and not a design flaw.

- **tvolodi docker group membership not effective until new SSH session:** After `usermod -aG docker tvolodi`, the group membership takes effect only in new login sessions. The hello-world verification in step 14 therefore uses `sudo docker run hello-world` to avoid a false negative. The execution-validator (step 07) confirms group membership via `id tvolodi | grep docker`, not by testing passwordless docker access in the same session.
