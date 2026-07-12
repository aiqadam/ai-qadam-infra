---
run_id: 2026-07-11-deploy-penpot-pro-data-tech-prod-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0108-deploy-penpot-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-02-landscape-reader.md
  - tasks/T-0108-deploy-penpot-on-pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: solution-designer (step 04) — design the Docker Compose deployment plan; confirm canonical docker-compose.yaml URL, patch mailcatch port binding to 127.0.0.1:1080, generate PENPOT_SECRET_KEY on remote host
---

## Summary

Task T-0108 is valid and ready for design. All six validation checks pass: the task is concrete and verifiable, the infrastructure workflow is the correct vehicle, the host is a clean slate with no Penpot deployment present, there are no landscape conflicts, all required facts are either known or safely deferrable to live discovery, and the workflow-specific rules (idempotency, backup, dual-layer verification) are satisfiable for this operation.

## Details

### Validation results

1. **Well-formed: PASS** — The task names seven discrete, binary acceptance criteria (directory created, compose file present, `.env` with specific key/value pairs, `docker compose up -d` exits 0, all seven named containers healthy, `curl localhost:9001` returns 2xx/3xx, `penpot-mcp` container running). Each criterion is independently verifiable by the execution-validator.

2. **In-scope: PASS** — The infrastructure workflow explicitly covers "Docker / Compose changes on the server." This is exactly a Docker Compose deployment on `pro-data-tech-prod`. No mismatch.

3. **Not already done: PASS** — Landscape (step 02, sourced from `landscape/hosts/pro-data-tech-prod.md` and `landscape/services.md`, both dated 2026-07-11) confirms: no application containers running, no nginx installed, no listener on port 9001, `/opt/penpot/` not mentioned. The host is a clean slate.

4. **No conflict with current state: PASS** — Docker CE 29.6.1 + Compose plugin v5.3.1 are installed and active (T-0106 done). UFW allows ports 80 and 443 (needed by T-0109 later, not by this task). Docker/UFW coexistence (DOCKER-USER chain, eth0-scoped MASQUERADE) is already configured. Three operator users with NOPASSWD sudo and `docker` group membership are provisioned. Nothing in the landscape contradicts any element of the plan.

5. **Discoverable scope: PASS** — The three open items flagged in steps 01 and 02 are all safely deferrable to live discovery or solution design:
   - Canonical Penpot `docker-compose.yaml` URL: well-known public GitHub raw URL; solution-designer can confirm and quote it.
   - Port 9001 occupancy: landscape already shows only port 22 active; a live `ss -tlnp` check by the executor adds assurance without blocking design.
   - Mailcatch `0.0.0.0:1080` default binding: a known, documented issue; solution-designer will include an explicit sed/patch step in the plan. No unknown unknowns remain.

6. **Workflow-specific rules respected: PASS** — (a) Idempotency: `docker compose up -d` is natively idempotent; creating `/opt/penpot/` with `mkdir -p` and writing `.env` with `tee` are both idempotent. (b) Backup before destructive changes: this is a fresh deploy — no pre-existing config files will be overwritten. No backup obligation is triggered. (c) Dual-layer verification: the acceptance criteria supply both a host-side probe (`curl localhost:9001`) and container-level health checks, satisfying step 07's requirement to verify at two layers.

### Production-flag confirmation

- `PENPOT_FLAGS`: `enable-prepl-server enable-mcp` — both required flags present, both dev-mode overrides (`disable-secure-session-cookies`, `disable-email-verification`) explicitly absent. Confirmed in task file and step-01 handoff.
- `PENPOT_SECRET_KEY`: must be generated on the remote host via `python3 -c "import secrets; print(secrets.token_urlsafe(64))"` and written only to the server-side `.env`; must not appear in run logs or any file in this repo. This constraint is enforceable in the executor plan.
- `PENPOT_PUBLIC_URI`: `https://penpot.aiqadam.org` — DNS confirmed live (T-0107 done). HTTPS not yet active (T-0109 pending); this is intentional and accepted.
- Mailcatch port: must be patched from default `0.0.0.0:1080:1080` to `127.0.0.1:1080:1080` before first `up`. Solution-designer must include this patch step explicitly.

## Issues / risks

- `PENPOT_SECRET_KEY` must never be echoed into the run transcript or stored in this repo; executor plan must treat it as a secret-generation-only operation (write directly to `.env` without echo).
- Containers (especially `penpot-postgres` and `penpot-backend`) may take 30–60 s to reach `healthy`; execution-validator must poll rather than assert immediately.
- Kernel `7.0.0-14-generic` is behind QA host (`7.0.0-27-generic`); 12 pending package upgrades outstanding. Non-blocking for this task.

## Open questions

none
