---
run_id: 2026-07-11-deploy-penpot-pro-data-tech-prod-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-11T13:30:00Z
task_id: T-0108-deploy-penpot-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-prod.md
artifacts_changed:
  - /opt/penpot/ (directory created)
  - /opt/penpot/docker-compose.yaml (downloaded + 3 patches applied)
  - /opt/penpot/.env (created, mode 600, 3 PENPOT_ keys)
  - Docker volumes: penpot_penpot_postgres_v15, penpot_penpot_assets
  - 7 Docker containers started under project name "penpot"
---

## Summary

All deployment steps executed successfully on pro-data-tech-prod (95.46.211.224). Penpot 2.16 is running as 7 containers with MCP enabled. Note: executor subagent stalled during Docker image pull phase; orchestrator completed the `docker compose up -d` step directly via SSH and wrote this handoff after verifying all containers running.

## Details

### Preparation steps (executed by executor subagent before stall)
- `/opt/penpot/` created, `docker-compose.yaml` downloaded (7891 bytes)
- `/opt/penpot/.env` created (mode 600): 3 keys — PENPOT_SECRET_KEY (urlsafe 64-byte, generated on-host via python3), PENPOT_PUBLIC_URI=https://penpot.aiqadam.org, PENPOT_FLAGS=enable-prepl-server enable-mcp
- Patches applied to docker-compose.yaml:
  - `"1080:1080"` → `"127.0.0.1:1080:1080"` (mailcatch localhost-only)
  - `PENPOT_FLAGS: disable-email-verification ...` → `PENPOT_FLAGS: ${PENPOT_FLAGS}` (uses .env)
  - `PENPOT_PUBLIC_URI: http://localhost:9001` → `PENPOT_PUBLIC_URI: ${PENPOT_PUBLIC_URI}` (uses .env)
  - `PENPOT_SECRET_KEY: change-this-insecure-key` → `PENPOT_SECRET_KEY: ${PENPOT_SECRET_KEY}` (uses .env)

### Launch (completed by orchestrator directly)
Command: `cd /opt/penpot && docker compose -p penpot -f docker-compose.yaml --env-file .env up -d`

All 7 containers started successfully from penpotapp/frontend:2.16, penpotapp/backend:2.16, penpotapp/exporter:2.16, penpotapp/mcp:2.16, postgres:15, valkey/valkey:8.1, sj26/mailcatcher:latest.

### Verification
| Check | Result |
|---|---|
| docker compose ps (7 containers) | All Up |
| penpot-postgres healthy | ✓ |
| penpot-valkey healthy | ✓ |
| penpot-frontend port 9001 | 0.0.0.0:9001→8080/tcp |
| curl localhost:9001 | HTTP 200 |
| penpot-mcp-1 running | ✓ Up 22 seconds |
| mailcatch binding | 127.0.0.1:1080→1080/tcp (localhost only) |

## Issues / risks
- Executor subagent stalled during Docker image pull (Docker Hub download latency). Orchestrator completed launch step directly. All planned operations completed correctly.

## Open questions
- First admin user must be created via: `docker exec -ti penpot-penpot-backend-1 python3 manage.py create-profile`
- nginx + HTTPS (T-0109) must be completed before the application is usable from the internet
