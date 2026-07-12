---
id: T-0108-deploy-penpot-on-pro-data-tech-prod
title: Deploy Penpot via Docker Compose on pro-data-tech-prod (MCP enabled, PENPOT_PUBLIC_URI=https://penpot.aiqadam.org)
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-deploy-penpot-pro-data-tech-prod-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
workflow: infrastructure
blocks: [T-0109]
blocked_by: [T-0106]
related: []
estimated_blast_radius: medium
estimated_reversibility: full
---

# Deploy Penpot via Docker Compose on pro-data-tech-prod

## Why
The primary objective: deploy Penpot design tool with MCP server enabled at `penpot.aiqadam.org`.

## What done looks like
- [ ] Working directory `/opt/penpot/` created with correct ownership
- [ ] `docker-compose.yaml` downloaded from official Penpot repo
- [ ] `.env` file created (gitignored on server, not stored in this repo) with:
  - `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org`
  - `PENPOT_SECRET_KEY=<random 512-bit base64 string>`
  - `PENPOT_FLAGS` adjusted for production: remove `disable-secure-session-cookies`, keep `disable-email-verification` (no SMTP configured; self-hosted standard), keep `enable-mcp`, keep `enable-prepl-server`
  - Mailcatch port 1080 NOT exposed to host public interface (bind to 127.0.0.1:1080)
- [ ] `docker compose -p penpot -f docker-compose.yaml up -d` succeeds
- [ ] All containers healthy: penpot-frontend, penpot-backend, penpot-exporter, penpot-mcp, penpot-postgres, penpot-valkey, penpot-mailcatch
- [ ] Penpot reachable on localhost:9001 from the host
- [ ] MCP container (`penpot-mcp`) running

## Result

Penpot 2.16 deployed on pro-data-tech-prod (95.46.211.224) via Docker Compose under project `penpot` at `/opt/penpot/`. All 7 containers running: penpot-frontend, penpot-backend, penpot-exporter, penpot-mcp, penpot-postgres (healthy), penpot-valkey (healthy), penpot-mailcatch. MCP enabled (`penpot-penpot-mcp-1` running, image `penpotapp/mcp:2.16`). PENPOT_PUBLIC_URI set to `https://penpot.aiqadam.org`. Frontend confirmed HTTP 200 on `localhost:9001`. Mailcatch bound to `127.0.0.1:1080` (loopback-only). `.env` mode 600, owner root.

Deviation from plan: `.env` owner is `root` (plan said `tvolodi`). Equally restrictive and not a security regression — Docker reads the file as root. Confirmed acceptable by step-07 validator.

All "What done looks like" checklist items verified by step-07 PASS.

See [runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-06-executor-infra.md](../runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-06-executor-infra.md) (executor) and [runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-07-execution-validator.md](../runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-07-execution-validator.md) (validator).

Remaining: nginx + HTTPS (T-0109); first admin user (`docker exec -ti penpot-penpot-backend-1 python3 manage.py create-profile`).

## Notes
- MCP is included in default PENPOT_FLAGS as `enable-mcp`; a dedicated `penpot-mcp` service (image `penpotapp/mcp`) is in the official compose file — no extra work needed
- Production flags: `enable-prepl-server enable-mcp` (remove the dev-mode flags)
- PENPOT_SECRET_KEY: generate with `python3 -c "import secrets; print(secrets.token_urlsafe(64))"`
- The mailcatch service exposes port 1080 — bind to 127.0.0.1 to prevent internet exposure
- nginx + HTTPS is handled in T-0109; Penpot listens on localhost:9001 only until then
- Create first admin user via: `docker exec -ti penpot-penpot-backend-1 python3 manage.py create-profile`

## History
- 2026-07-11: created manually by orchestrator
- 2026-07-11: domain corrected to aiqadam.org (no hyphen) per T-0107 finding
- 2026-07-11: status → in-progress — run 2026-07-11-deploy-penpot-pro-data-tech-prod-001 started
- 2026-07-11: status → done, outcome succeeded, run 2026-07-11-deploy-penpot-pro-data-tech-prod-001, commit <pending>
