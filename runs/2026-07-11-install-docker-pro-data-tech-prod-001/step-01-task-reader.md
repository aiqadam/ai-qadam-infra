---
run_id: 2026-07-11-install-docker-pro-data-tech-prod-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0106-install-docker-on-pro-data-tech-prod
inputs_read:
  - tasks/T-0106-install-docker-on-pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader (step 02) — read pro-data-tech-prod host file and UFW/firewall state
---

## Summary

Task T-0106 is in-progress status and clearly scoped: install Docker Engine (from the official Docker apt repository) and the Docker Compose v2 plugin on `pro-data-tech-prod` (95.46.211.224), then resolve the UFW + Docker iptables coexistence problem using the `/etc/ufw/after.rules` DOCKER-USER approach so the UFW FORWARD default (DROP) does not silently break container internet access.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md`
  - `landscape/services.md`
- **Why (verbatim from task):**
  > Penpot (T-0108) requires Docker and Docker Compose. The production host currently has neither (confirmed T-0101 discovery). The QA host received Docker during T-0090 (Phase B). This task replicates that step on prod.
- **Acceptance criteria (from "What done looks like"):**
  1. Docker Engine installed from the official Docker apt repository (not snap; not distro package).
  2. `docker compose` (v2 plugin, not standalone compose v1) available.
  3. Docker service enabled and started (`systemctl enable --now docker`).
  4. `docker run hello-world` exits 0.
  5. UFW / Docker iptables interaction handled: `/etc/ufw/after.rules` updated to ACCEPT forward traffic via the DOCKER-USER chain (not via `"iptables": false` in daemon.json).
  6. `tvolodi` user added to the `docker` group.
- **Constraints stated by user / task:**
  - Use official docker.com apt repo (keyring method); not Ubuntu universe package, not snap.
  - Ubuntu 26.04 (apt-based).
  - UFW is active with `DEFAULT_FORWARD_POLICY=DROP` (set in T-0103) — must not disable UFW's iptables management; fix via after.rules.
  - Port 1080 (mailcatch) must NOT be opened via UFW to the internet.
  - Reference: T-0090 Phase B (QA host) for procedure precedent.
- **Information gaps for downstream steps:**
  - Exact current UFW ruleset and `/etc/ufw/after.rules` content on prod (step 02 will read landscape).
  - Whether any prior `/etc/docker/daemon.json` exists (unlikely — no Docker installed, but worth confirming).
  - Network interface name used by Docker's default bridge (`docker0`) — needed for the after.rules MASQUERADE rule; typically `docker0` but should be verified post-install.

## Issues / risks

- UFW + Docker iptables interaction is the primary risk: if after.rules is not written before containers are started, they silently have no internet access. Execution order matters: install Docker → write after.rules → reload UFW → start/restart Docker.
- Adding `tvolodi` to the `docker` group grants root-equivalent container escape capability; this is intentional and accepted per task scope.
- `docker run hello-world` requires outbound internet from the host on port 443 (Docker Hub); confirm host egress is not blocked by the Hetzner-level firewall.
