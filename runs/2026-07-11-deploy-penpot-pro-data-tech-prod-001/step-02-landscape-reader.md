---
run_id: 2026-07-11-deploy-penpot-pro-data-tech-prod-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0108-deploy-penpot-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — validate pre-conditions and task completeness against landscape facts
---

## Summary

`pro-data-tech-prod` (95.46.211.224) is fully hardened and Docker-ready as of 2026-07-11. Docker CE 29.6.1 with Compose plugin v5.3.1 is installed and active (T-0106). UFW is active with deny-incoming default; ports 22/tcp, 80/tcp, and 443/tcp are allowed (v4+v6). The Docker/UFW coexistence block (DOCKER-USER chain, eth0-scoped MASQUERADE) is in place. No application containers are running and no nginx is installed — the host is a clean slate for the Penpot deployment. The security baseline is complete (sshd T-0102, UFW T-0103, fail2ban T-0104, operator users T-0105). Three operator users are provisioned with NOPASSWD sudo and membership in the `docker` group: `tvolodi` (uid 1000), `viktor_d` (uid 1001), `binali_r` (uid 1002). Both landscape files are dated 2026-07-11 and are not stale.

## Details

### Relevant facts (sourced from landscape)

- **Host:** `pro-data-tech-prod`, `95.46.211.224`, Ubuntu 26.04 LTS, kernel `7.0.0-14-generic` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Docker CE:** 29.6.1, Compose plugin v5.3.1; `docker.service` enabled and active; `tvolodi` in `docker` group (gid 986) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **UFW status:** ACTIVE, `default deny incoming`, `default allow outgoing`. Rules: `22/tcp ALLOW IN Anywhere (v4+v6)`, `80/tcp ALLOW IN Anywhere (v4+v6)`, `443/tcp ALLOW IN Anywhere (v4+v6)` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Docker/UFW coexistence:** DOCKER-USER chain appended to `/etc/ufw/after.rules` (eth0-scoped `-j RETURN`; MASQUERADE nat rule for `172.16.0.0/12`); backup at `/var/backups/ufw-after.rules-pre-T0106.bak` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Application containers:** none. No nginx. Only active internet-facing listener is SSH on port 22 — _source: `landscape/hosts/pro-data-tech-prod.md`_, _source: `landscape/services.md`_
- **Operator users with sudo + docker group:** `tvolodi` (uid 1000), `viktor_d` (uid 1001), `binali_r` (uid 1002). SSH via `tvolodi@95.46.211.224`, key `C:\Users\tvolo\.ssh\ai-dala-infra` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Security posture:** hardened (T-0102 sshd, T-0103 UFW, T-0104 fail2ban, T-0105 operator users). Remaining gaps: auditd not installed (gap #4), 12 pending package upgrades (gap #5) — both non-blocking — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **PENPOT_FLAGS (production):** `enable-prepl-server enable-mcp`. Dev overrides `disable-secure-session-cookies` and `disable-email-verification` must NOT be present — _source: `runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-01-task-reader.md`_
- **PENPOT_PUBLIC_URI:** `https://penpot.aiqadam.org` (DNS T-0107 done; HTTPS/nginx arrives in T-0109) — _source: `runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-01-task-reader.md`_
- **Target port for Penpot frontend:** `localhost:9001` (loopback only; not exposed via UFW) — _source: `runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-01-task-reader.md`_

### Stale or stub files encountered

None. Both files are dated `last_verified: 2026-07-11` (today).

### Gaps requiring live discovery

- **Port 9001 occupancy:** landscape confirms no current listeners on 9001 (only port 22 in `ss`/`netstat` probe), but this should be verified live before binding to avoid a conflict with any future service.
- **`/opt/penpot/` directory existence:** not mentioned in the landscape; executor must create it (or verify it does not yet exist) at run time.
- **Official Penpot `docker-compose.yaml` URL:** not recorded in the landscape. Canonical source expected to be `https://raw.githubusercontent.com/penpotapp/penpot/main/docker/images/docker-compose.yaml`; solution-designer should confirm and quote in the plan.
- **Mailcatch port binding in the official compose file:** the compose file likely defaults to `0.0.0.0:1080`; executor must patch to `127.0.0.1:1080:1080` before first `up`.

## Issues / risks

- `PENPOT_SECRET_KEY` must be generated **on the remote host** and must never be echoed into run logs or committed to this repo.
- `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org` is set to HTTPS now, but TLS is not yet active (T-0109 pending). Penpot will be unreachable via browser until nginx + Certbot are configured; this is expected per the task.
- Kernel `7.0.0-14-generic` is two minor versions behind the QA host (`7.0.0-27-generic`); 12 pending upgrades outstanding. Non-blocking for Penpot deployment but noted.
- No swap on the host (31 GiB RAM total); unlikely to be an issue for Penpot's 7-container stack, but backend/postgres startup spikes should be monitored.
