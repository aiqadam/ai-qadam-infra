---
run_id: 2026-07-24-fix-authentik-admin-url-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-24T02:10:00Z
task_id: T-0125-fix-authentik-admin-url-on-qa
inputs_read:
  - tasks/T-0125-fix-authentik-admin-url-on-qa.md
artifacts_changed: []
next_step_hint: landscape-reader should read landscape/hosts/pro-data-tech-qa.md and landscape/services.md
---

## Summary

Execute T-0125: add the missing `AUTHENTIK_ADMIN_URL` override to QA's `docker-compose.qa.yml` `api` service so admin-API calls resolve to QA's own Authentik instance instead of production's, then recreate the container and live-verify registration succeeds end-to-end.

## Details

- **Workflow:** infrastructure

- **Target scope:**
  - `landscape/hosts/pro-data-tech-qa.md`
  - `landscape/services.md`
  - Host file: `pro-data-tech-qa:/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` (`api` service environment block)

- **Constraints stated by user:**
  - New env var line must follow the exact same pattern/comment style as the existing 4 overrides already in that block (`PORT`, `REDIS_URL`, `DIRECTUS_URL`, `OIDC_ISSUER_URL`).
  - Value to set: `AUTHENTIK_ADMIN_URL: "https://auth.qa.aiqadam.org"` — same hostname already correctly used in `OIDC_ISSUER_URL`.
  - Container must be recreated (`docker compose ... up -d api`), not merely restarted, since this is an environment-variable change.
  - Must not be conflated with T-0124 (related but distinct root cause — that task's scope is already complete and independently verified).

- **Information gaps for downstream steps:**
  - Exact current contents/formatting of the `api` service environment block in `docker-compose.qa.yml` on the host (needed to match comment style precisely) — not yet read; landscape-reader / executor must fetch this from the live host file.
  - Whether any other code path in `apps/api/src` reads `AUTHENTIK_ADMIN_URL` (or an equivalent config key) with its own separate fallback that would also need overriding — task asks to grep and confirm this env var is the only gap.
  - Confirmation that no other environment file (e.g., a `.env` on the host, distinct from the compose file) also needs the same fix, since defaults are read via `apps/api/src/config/env.ts:151`.

### Why (quoted verbatim from task file)

> Discovered while verifying T-0124's fix (permission-denied deploy blocker,
> resolved) and `aiqadam/ai-qadam-platform`'s ISS-USR-REG-002 (registration
> 500 error, code fix merged as PR #51) live on `pro-data-tech-qa`.
>
> After rebuilding and redeploying the `api` container with the fixed code,
> `POST https://qa.aiqadam.org/api/v1/auth/register` now returns a clean
> `400 registration_failed` instead of a bare `500` — confirming
> ISS-USR-REG-002's fix works correctly. However, registration still cannot
> fully succeed. The container's own logs show why:
>
> ```
> [AuthentikClient] Authentik GET /api/v3/core/users/?email=... -> 523:
>   {"title":"Error 523: Origin is unreachable", ...}
> [RegistrationService] { event: 'registration.duplicate_check_failed', ... }
> ```
>
> `apps/api/src/config/env.ts:151` defaults `AUTHENTIK_ADMIN_URL` to
> `https://auth.aiqadam.org` (production's Authentik) when unset. QA's
> `docker-compose.qa.yml` `api` service environment block overrides 4 other
> vars (`PORT`, `REDIS_URL`, `DIRECTUS_URL`, `OIDC_ISSUER_URL`) for exactly
> this class of "placeholder in .env, real value needed here" reason, but
> does **not** override `AUTHENTIK_ADMIN_URL` — so the API falls back to
> production's hostname, which QA's network/DNS obviously cannot reach for
> admin-API calls (Cloudflare returns 523 "Origin is unreachable" — QA has
> no route to production's origin for this purpose).
>
> QA's own Authentik instance is reachable at `https://auth.qa.aiqadam.org`
> (confirmed live: `/if/flow/default-authentication-flow/` → 200,
> `/api/v3/root/config/` → 200) — this is the same hostname already
> correctly used in `OIDC_ISSUER_URL`'s value
> (`https://auth.qa.aiqadam.org/application/o/aiqadam-qa/`), just not
> propagated to `AUTHENTIK_ADMIN_URL` as well.

### What done looks like → acceptance criteria for step 07 (execution-validator)

1. `deploy/docker-compose.qa.yml`'s `api` service environment block on `pro-data-tech-qa` (`/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml`) gains `AUTHENTIK_ADMIN_URL: "https://auth.qa.aiqadam.org"`, matching the existing 4 overrides' pattern/comment style exactly.
2. `docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d api` is run to recreate (not restart) the `api` container so it picks up the new env var.
3. Live verification: `POST https://qa.aiqadam.org/api/v1/auth/register` with a well-formed, never-before-used email returns `302` with `Location: /v1/auth/login` — full registration success end-to-end.
4. Confirmation (via grep of `AUTHENTIK_ADMIN_URL` usage in `apps/api/src`) that this single env var is the only place on this host still defaulting to the wrong Authentik URL — no other silent-default code path remains.

## Issues / risks

- none

## Open questions (optional)

- none — task is unambiguous, workflow is clearly `infrastructure`, and the file is already correctly in `in-progress` status per the orchestrator's run-init step.
