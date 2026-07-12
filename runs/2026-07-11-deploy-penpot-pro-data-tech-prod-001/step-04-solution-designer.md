---
run_id: 2026-07-11-deploy-penpot-pro-data-tech-prod-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-11T00:00:00Z
task_id: T-0108-deploy-penpot-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-02-landscape-reader.md
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — present plan for NEEDS_APPROVAL gate; then executor-infra (step 06)
---

## Summary

Deploy the official Penpot Docker Compose stack (7 containers) on `pro-data-tech-prod` (95.46.211.224), configured with production flags (`enable-prepl-server enable-mcp`), a server-generated strong secret key written only to `/opt/penpot/.env`, mailcatch port bound to loopback only, and `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org`; end state is all 7 containers healthy and penpot-frontend answering HTTP on `localhost:9001`.

## Details

### Plan

All commands run on `pro-data-tech-prod` via `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.224`. Commands shown are the remote-side shell commands. Multi-line blocks should be delivered via a single SSH heredoc invocation or a temporary script uploaded to the host — the executor must NOT split them into separate SSH calls in a way that loses shell state (e.g., variables and `cd`).

---

**Pre-step — verify port 9001 is free**

- Command: `ss -tlnp | grep 9001`
- Expected: no output
- Purpose: confirms no existing process will conflict with the Penpot frontend binding

---

**Step 1 — Create working directory**

- Command:
  ```bash
  sudo mkdir -p /opt/penpot
  sudo chown tvolodi:tvolodi /opt/penpot
  ```
- Verification: `ls -ld /opt/penpot` returns a line with owner `tvolodi` and group `tvolodi`
- Rollback: `sudo rm -rf /opt/penpot`

---

**Step 2 — Download official docker-compose.yaml**

- Command:
  ```bash
  curl -fsSL -o /opt/penpot/docker-compose.yaml \
    https://raw.githubusercontent.com/penpot/penpot/main/docker/images/docker-compose.yaml
  ```
- Verification: `wc -l /opt/penpot/docker-compose.yaml` returns a value >50; `head -3 /opt/penpot/docker-compose.yaml` shows valid YAML content
- Note: canonical repo is `github.com/penpot/penpot` (not `penpotapp/penpot`); the step-01 and step-02 handoffs both referenced the same raw URL format
- Rollback: `rm -f /opt/penpot/docker-compose.yaml`

---

**Step 3 — Inspect compose file format before patching**

- Commands (read-only; inform how to write the sed patterns):
  ```bash
  grep -n "1080" /opt/penpot/docker-compose.yaml
  grep -n "PENPOT_FLAGS" /opt/penpot/docker-compose.yaml
  grep -n "PENPOT_PUBLIC_URI" /opt/penpot/docker-compose.yaml
  grep -n "PENPOT_SECRET_KEY" /opt/penpot/docker-compose.yaml
  ```
- Purpose: determine whether port 1080 is quoted (`"1080:1080"`) or bare (`- 1080:1080`) and whether env vars use YAML-map style (`KEY: "value"`) or list style (`- KEY=value`), so the correct sed patterns below can be selected
- No rollback required (read-only)

---

**Step 4 — Create .env file (secret key never echoed to terminal or logs)**

- Command (run as a single SSH block):
  ```bash
  cat > /opt/penpot/.env << 'ENVEOF'
  PENPOT_PUBLIC_URI=https://penpot.aiqadam.org
  PENPOT_FLAGS=enable-prepl-server enable-mcp
  ENVEOF
  python3 -c "import secrets; print('PENPOT_SECRET_KEY=' + secrets.token_urlsafe(64))" >> /opt/penpot/.env
  chmod 600 /opt/penpot/.env
  ```
- **CRITICAL:** The `python3` one-liner appends the key directly to the file. Do NOT capture the key in a shell variable first (e.g. `KEY=$(...)`) — that could expose it in process listings or shell history.
- Verification:
  - `ls -la /opt/penpot/.env` — mode must be `600`, owner `tvolodi`
  - `grep -c "PENPOT_" /opt/penpot/.env` — must return `3`
  - `grep "PENPOT_PUBLIC_URI" /opt/penpot/.env` — must return `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org`
  - `grep "PENPOT_FLAGS" /opt/penpot/.env` — must return `PENPOT_FLAGS=enable-prepl-server enable-mcp`
  - `grep -q "PENPOT_SECRET_KEY=" /opt/penpot/.env && echo present` — must return `present` (do NOT print the value itself)
  - `grep "disable-secure-session-cookies\|disable-email-verification" /opt/penpot/.env` — must return **no output**
- Rollback: `rm -f /opt/penpot/.env`

---

**Step 5 — Patch mailcatch port binding (0.0.0.0:1080 → 127.0.0.1:1080)**

- If port is quoted in the compose file (e.g. `"1080:1080"`):
  ```bash
  sed -i 's/"1080:1080"/"127.0.0.1:1080:1080"/' /opt/penpot/docker-compose.yaml
  ```
- If port is bare (e.g. `- 1080:1080`):
  ```bash
  sed -i 's/- 1080:1080/- 127.0.0.1:1080:1080/' /opt/penpot/docker-compose.yaml
  ```
- Executor selects the correct variant based on the grep output from Step 3.
- Verification: `grep "1080" /opt/penpot/docker-compose.yaml` — must contain `127.0.0.1:1080:1080` and must NOT contain `0.0.0.0:1080`
- Rollback: re-run Step 2 (re-download) then re-apply all patches from Step 5 onward

---

**Step 6 — Patch PENPOT_FLAGS to reference .env variable**

- If compose file uses YAML-map style (`PENPOT_FLAGS: "..."`):
  ```bash
  sed -i 's|PENPOT_FLAGS:.*|PENPOT_FLAGS: "${PENPOT_FLAGS}"|' /opt/penpot/docker-compose.yaml
  ```
- If compose file uses list style (`- PENPOT_FLAGS=...`):
  ```bash
  sed -i 's|- PENPOT_FLAGS=.*|- PENPOT_FLAGS=${PENPOT_FLAGS}|' /opt/penpot/docker-compose.yaml
  ```
- Executor selects the correct variant based on Step 3 inspection.
- Verification: `grep "PENPOT_FLAGS" /opt/penpot/docker-compose.yaml` — every matching line must contain `${PENPOT_FLAGS}`, not a hardcoded flag string

---

**Step 7 — Patch PENPOT_PUBLIC_URI and PENPOT_SECRET_KEY to reference .env variables**

- YAML-map style:
  ```bash
  sed -i 's|PENPOT_PUBLIC_URI:.*|PENPOT_PUBLIC_URI: "${PENPOT_PUBLIC_URI}"|' /opt/penpot/docker-compose.yaml
  sed -i 's|PENPOT_SECRET_KEY:.*|PENPOT_SECRET_KEY: "${PENPOT_SECRET_KEY}"|' /opt/penpot/docker-compose.yaml
  ```
- List style:
  ```bash
  sed -i 's|- PENPOT_PUBLIC_URI=.*|- PENPOT_PUBLIC_URI=${PENPOT_PUBLIC_URI}|' /opt/penpot/docker-compose.yaml
  sed -i 's|- PENPOT_SECRET_KEY=.*|- PENPOT_SECRET_KEY=${PENPOT_SECRET_KEY}|' /opt/penpot/docker-compose.yaml
  ```
- Verification: `grep "PENPOT_PUBLIC_URI\|PENPOT_SECRET_KEY" /opt/penpot/docker-compose.yaml` — all matching lines must contain `${PENPOT_PUBLIC_URI}` and `${PENPOT_SECRET_KEY}` respectively; none must contain `http://localhost:9001`, `my-insecure-key`, or any hardcoded value

---

**Step 8 — Final patch verification**

- Command:
  ```bash
  grep -E "1080|PENPOT_FLAGS|PENPOT_PUBLIC_URI|PENPOT_SECRET_KEY" /opt/penpot/docker-compose.yaml
  ```
- Expected output must satisfy ALL of:
  1. A line matching `1080` contains `127.0.0.1:1080:1080` — no `0.0.0.0`
  2. Every line matching `PENPOT_FLAGS` contains `${PENPOT_FLAGS}`
  3. Every line matching `PENPOT_PUBLIC_URI` contains `${PENPOT_PUBLIC_URI}`
  4. Every line matching `PENPOT_SECRET_KEY` contains `${PENPOT_SECRET_KEY}`
- If any condition is not met, re-download (Step 2) and re-apply patches (Steps 5–7) before proceeding to Step 9.

---

**Step 9 — Start containers**

- Command:
  ```bash
  cd /opt/penpot && docker compose -p penpot -f docker-compose.yaml --env-file .env up -d
  ```
- Expected: command exits 0; Docker pulls images (may take several minutes on first run) and starts 7 containers
- Verification: `docker compose -p penpot ps` shows 7 containers with status `Created` or `Up`
- Rollback: see Rollback section below

---

**Step 10 — Wait for containers to reach Up/healthy state (poll up to 120 s)**

- Command:
  ```bash
  for i in $(seq 1 12); do
    echo "=== Poll $i/12 ($(date +%H:%M:%S)) ==="
    docker compose -p penpot ps
    sleep 10
  done
  ```
- Expected: by poll 6–12, all 7 containers (`penpot-frontend`, `penpot-backend`, `penpot-exporter`, `penpot-mcp`, `penpot-postgres`, `penpot-valkey`, `penpot-mailcatch`) show `Up` or `healthy`. `penpot-postgres` and `penpot-backend` are the slowest (30–60 s is normal).
- Rollback trigger: if any container is in `Exit` or `Restarting` state after 120 s, capture `docker compose -p penpot logs --tail 50` for the failing container(s) before rolling back.

---

**Step 11 — HTTP probe on localhost:9001**

- Command:
  ```bash
  curl -s -o /dev/null -w "%{http_code}" http://localhost:9001
  ```
- Expected: any `2xx` or `3xx` status code
- Rollback trigger: `5xx` or connection refused after Step 10 polling confirms containers are `Up` → inspect `docker compose -p penpot logs penpot-frontend --tail 50`

---

**Step 12 — Verify penpot-mcp container is running**

- Command:
  ```bash
  docker ps --format "{{.Names}}\t{{.Status}}" | grep penpot-mcp
  ```
- Expected: a line containing `penpot-mcp` with status starting with `Up`

---

### Rollback

**For any failure in Steps 1–8 (pre-up):** no containers were started; rollback is `sudo rm -rf /opt/penpot`.

**For any failure in Steps 9–12 (post-up):**

1. Stop and remove containers (preserving volumes for post-mortem):
   ```bash
   cd /opt/penpot && docker compose -p penpot -f docker-compose.yaml down
   ```
2. Capture diagnostic information before further cleanup:
   ```bash
   docker compose -p penpot logs --tail 100 > /tmp/penpot-rollback-logs.txt
   ```
3. If full teardown is required (remove volumes — destroys all Postgres data):
   ```bash
   docker volume ls | grep penpot | awk '{print $2}' | xargs -r docker volume rm
   ```
4. Remove working directory:
   ```bash
   sudo rm -rf /opt/penpot
   ```

Note: Step 3 (volume removal) is **one-way** — no backup exists since this is a first-time deploy. Only proceed with volume removal if there is no need to inspect the database state post-failure.

### Verification (for step 07)

- **On-host:**
  1. `ls -ld /opt/penpot` — directory exists, owner `tvolodi tvolodi`
  2. `ls -la /opt/penpot/.env` — file present, mode `600`, owner `tvolodi`
  3. `grep -c "PENPOT_" /opt/penpot/.env` → `3`
  4. `grep "PENPOT_FLAGS" /opt/penpot/.env` → `PENPOT_FLAGS=enable-prepl-server enable-mcp`
  5. `grep "PENPOT_PUBLIC_URI" /opt/penpot/.env` → `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org`
  6. `grep "disable-secure-session-cookies\|disable-email-verification" /opt/penpot/.env` → **no output** (dev flags absent)
  7. `grep "1080" /opt/penpot/docker-compose.yaml` → contains `127.0.0.1:1080:1080`, does NOT contain `0.0.0.0:1080`
  8. `grep -q "PENPOT_SECRET_KEY=" /opt/penpot/.env && echo present` → `present` (value must NOT be printed)
  9. `docker compose -p penpot ps` — all 7 containers (`penpot-frontend`, `penpot-backend`, `penpot-exporter`, `penpot-mcp`, `penpot-postgres`, `penpot-valkey`, `penpot-mailcatch`) in `Up` or `healthy` state
  10. `curl -s -o /dev/null -w "%{http_code}" http://localhost:9001` → `2xx` or `3xx`
  11. `docker ps --format "{{.Names}}\t{{.Status}}" | grep penpot-mcp` → line present, status starts with `Up`

- **External:** none expected at this step. `https://penpot.aiqadam.org` will return connection refused on port 443 until nginx + TLS are configured in T-0109. This is intentional and is not a failure condition for this run.

### Resources used

- Secrets (by name): `PENPOT_SECRET_KEY` — generated on-host via `python3 secrets.token_urlsafe(64)`, written only to `/opt/penpot/.env` (mode 600); never stored in a shell variable, never echoed to terminal or run logs, never committed to this repo
- Files modified on host:
  - `/opt/penpot/` (directory, created)
  - `/opt/penpot/docker-compose.yaml` (downloaded + patched in-place)
  - `/opt/penpot/.env` (created, mode 600)
  - Docker volumes (created by `docker compose up`): `penpot_postgres_data`, `penpot_assets`, and any additional volumes defined in the official compose file
- Files modified in this repo (landscape/) — to be applied at step 08:
  - `landscape/hosts/pro-data-tech-prod.md` — update "What runs here" section with Penpot containers; add port 9001 loopback listener to network section
  - `landscape/services.md` — add Penpot service entry (host: `pro-data-tech-prod`, port: 9001 loopback, public URI pending T-0109)
- External APIs called: `raw.githubusercontent.com` (GET `penpot/penpot/main/docker/images/docker-compose.yaml`); Docker Hub (image pulls during `docker compose up -d`)

### Estimated impact

- **Downtime:** none — this is a first-time deploy; no prior service exists on this host
- **Affected services:** no currently running services affected; Penpot frontend will bind to `127.0.0.1:9001` only — not internet-exposed until T-0109 (nginx + TLS)
- **Reversibility:** fully reversible for infrastructure (containers, files, directory); Docker volume removal after a failed deploy is one-way but acceptable since no prior state exists

## Issues / risks

- **PENPOT_SECRET_KEY handling:** the key must be generated and written to `.env` in a single Python one-liner that appends directly to the file. The executor must NOT capture it in a shell variable (`KEY=$(...)`) before writing, as that exposes the value to shell history and process listings. The verification step checks for presence only (`grep -q ... && echo present`), never prints the value.
- **sed pattern format uncertainty:** the exact syntax of environment variable entries in the official Penpot `docker-compose.yaml` (YAML-map `KEY: "value"` vs. list `- KEY=value`) is not known until the file is downloaded. Step 3 (inspect) must be completed before any sed patches are applied. Two variant commands are provided for each patch step — executor selects the matching one.
- **Dev-mode flags must be absent:** `PENPOT_FLAGS` in `.env` must contain ONLY `enable-prepl-server enable-mcp`. The step-07 validator must explicitly confirm that `disable-secure-session-cookies` and `disable-email-verification` are not present anywhere in `.env`.
- **Container startup time:** `penpot-postgres` and `penpot-backend` can take 30–60 s to reach `healthy`. The execution-validator must poll rather than assert at a fixed point in time.
- **PENPOT_PUBLIC_URI set to HTTPS before TLS is active:** `https://penpot.aiqadam.org` is the correct final URI but TLS is not yet live. Penpot will generate internal links with that URI, but the app will not be browser-reachable until T-0109. This is expected, accepted, and documented. The `curl localhost:9001` check is the only HTTP validation in scope for this run.
- **`NEEDS_APPROVAL` required:** per `shared/approval-protocol.md`, first-time application deploys to a production host always require human approval regardless of reversibility or blast radius scores. This plan must not be auto-forwarded to the executor.
