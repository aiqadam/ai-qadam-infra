---
id: T-0106-install-docker-on-pro-data-tech-prod
title: Install Docker Engine + Docker Compose plugin on pro-data-tech-prod
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-install-docker-pro-data-tech-prod-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
workflow: infrastructure
blocks: [T-0108]
blocked_by: []
related: [T-0090]
estimated_blast_radius: low
estimated_reversibility: full
---

# Install Docker Engine + Docker Compose plugin on pro-data-tech-prod

## Why
Penpot (T-0108) requires Docker and Docker Compose. The production host currently has neither (confirmed T-0101 discovery). The QA host received Docker during T-0090 (Phase B). This task replicates that step on prod.

## What done looks like
- [ ] Docker Engine installed from the official Docker apt repository (not snap; not distro package)
- [ ] docker compose (v2 plugin, not standalone compose v1) available as `docker compose`
- [ ] Docker service enabled and started
- [ ] `docker run hello-world` succeeds
- [ ] UFW / Docker iptables interaction handled: `/etc/docker/daemon.json` created with `"iptables": true` (default) and UFW after.rules updated to allow DOCKER-USER chain forward — OR use the standard workaround for Ubuntu 26.04 + UFW coexistence
- [ ] `tvolodi` user added to `docker` group

## Result

Docker CE 29.6.1 and Compose plugin v5.3.1 installed on `pro-data-tech-prod` (95.46.211.224) from the official Docker apt repository (keyring method, `resolute` stable channel). `docker.service` enabled and active; containerd.io 2.2.6 as runtime. UFW after.rules updated with DOCKER-USER coexistence block (`-A DOCKER-USER -i eth0 -j RETURN` + `-A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE`); pre-install backup at `/var/backups/ufw-after.rules-pre-T0106.bak`. Operator user `tvolodi` added to the `docker` group (gid 986). `docker run hello-world` confirmed (step-07 PASS). All six "What done looks like" items satisfied.

- Executor handoff: [runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-06-executor-infra.md](../runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-06-executor-infra.md)
- Validator handoff: [runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-07-execution-validator.md](../runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-07-execution-validator.md)

Deviations from "What done looks like":
- No `/etc/docker/daemon.json` created — the after.rules DOCKER-USER approach was used instead (explicitly listed in Notes as the recommended option). UFW coexistence is achieved correctly.
- `tvolodi` docker group membership requires a new SSH session to take effect (expected; `docker run hello-world` was run as root in step-07 as the documented workaround).

## Notes
- Reference: T-0090 Phase B for QA host
- Ubuntu 26.04 uses `apt` for Docker CE; use the official docker.com apt repo (keyring method), not the Ubuntu universe package
- UFW interaction: with DEFAULT_FORWARD_POLICY=DROP (set in T-0103), Docker containers cannot reach the internet without a fix. Add rules to /etc/ufw/after.rules to ACCEPT via DOCKER-USER chain, or create /etc/docker/daemon.json with `{"iptables": false}` and manage manually. Recommended: use the after.rules approach to keep UFW's FORWARD default intact while letting Docker networking work.
- The mailcatch port 1080 exposed in the default docker-compose should NOT be exposed via UFW to the internet

## History
- 2026-07-11: created manually by orchestrator
- 2026-07-11: status → in-progress — run 2026-07-11-install-docker-pro-data-tech-prod-001 started
- 2026-07-11: status → done, outcome succeeded, run 2026-07-11-install-docker-pro-data-tech-prod-001, commit <pending>
