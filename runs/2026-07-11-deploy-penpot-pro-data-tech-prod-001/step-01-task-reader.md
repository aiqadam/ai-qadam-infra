---
run_id: 2026-07-11-deploy-penpot-pro-data-tech-prod-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0108-deploy-penpot-on-pro-data-tech-prod
inputs_read:
  - tasks/T-0108-deploy-penpot-on-pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader (step 02) — read pro-data-tech-prod host landscape and confirm Docker 29.6.1 present and port 9001 available
---

## Summary

Task T-0108 requests deploying Penpot via Docker Compose on `pro-data-tech-prod` (95.46.211.224), with MCP enabled, `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org`, production-hardened flags (no dev-mode overrides), a strong random `PENPOT_SECRET_KEY`, and the mailcatch port 1080 bound to `127.0.0.1` only. Status is `in-progress` (run already opened), so execution may proceed.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md`
  - `landscape/services.md`
- **Why (verbatim from task):** "The primary objective: deploy Penpot design tool with MCP server enabled at `penpot.aiqadam.org`."
- **Concrete operation:** Deploy the official Penpot Docker Compose stack on `pro-data-tech-prod`, apply production configuration, and confirm all containers are healthy with Penpot reachable on `localhost:9001`.
- **Acceptance criteria (from "What done looks like"):**
  1. Working directory `/opt/penpot/` created with correct ownership.
  2. `docker-compose.yaml` downloaded from the official Penpot repository.
  3. `.env` file created (gitignored on server) containing:
     - `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org`
     - `PENPOT_SECRET_KEY=<random 512-bit base64 string>` (generated via `python3 -c "import secrets; print(secrets.token_urlsafe(64))"`)
     - `PENPOT_FLAGS` set to production values: `enable-prepl-server enable-mcp` — `disable-secure-session-cookies` and `disable-email-verification` **must not** be present.
     - Mailcatch port 1080 bound to `127.0.0.1:1080` only (not `0.0.0.0`).
  4. `docker compose -p penpot -f docker-compose.yaml up -d` exits 0.
  5. All seven containers healthy: `penpot-frontend`, `penpot-backend`, `penpot-exporter`, `penpot-mcp`, `penpot-postgres`, `penpot-valkey`, `penpot-mailcatch`.
  6. `curl -s -o /dev/null -w "%{http_code}" http://localhost:9001` returns a 2xx/3xx response.
  7. `penpot-mcp` container is running.
- **Constraints stated by user:**
  - Production flags must NOT include `disable-secure-session-cookies`.
  - `PENPOT_SECRET_KEY` must be a strong random value (not a placeholder).
  - Mailcatch port 1080 must be bound to `127.0.0.1` only.
  - `PENPOT_PUBLIC_URI` must be set to `https://penpot.aiqadam.org` from the start even though HTTPS (T-0109) comes later.
  - MCP (`enable-mcp`) must be present in `PENPOT_FLAGS`.
  - Penpot listens on `localhost:9001` only; no direct internet exposure until nginx+HTTPS (T-0109).
- **Pre-conditions confirmed by user:**
  - Docker 29.6.1 installed (T-0106 done).
  - Domain `penpot.aiqadam.org` resolves to `95.46.211.224` (T-0107 done).
- **Information gaps for downstream steps:**
  - Exact URL of the official Penpot `docker-compose.yaml` to download (landscape-reader or solution-designer should confirm the canonical source, e.g., `https://raw.githubusercontent.com/penpotapp/penpot/main/docker/images/docker-compose.yaml`).
  - Whether any UFW rules need adjustment to allow Docker-internal traffic on `localhost:9001`.
  - Whether an operator user already exists on the host with `sudo` rights for running these commands.

## Issues / risks

- `PENPOT_SECRET_KEY` must be generated on the remote host (not stored in this repo); executor must confirm the value is written only to the server `.env` file and never echoed into the run logs.
- Mailcatch `1080` port: the official compose file defaults may bind to `0.0.0.0`; executor must explicitly patch the port binding to `127.0.0.1:1080:1080`.
- `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org` while TLS is not yet active means Penpot's internal links will use HTTPS; the app will be inaccessible via browser until T-0109 completes — this is expected and acceptable.
- Container health-check timing: some Penpot containers (postgres, backend) may take 30–60 s to reach `healthy`; executor should poll rather than assert immediately.
