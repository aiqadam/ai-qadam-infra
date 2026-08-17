---
id: T-0125-fix-authentik-admin-url-on-qa
title: Set AUTHENTIK_ADMIN_URL to QA's own Authentik instance on pro-data-tech-qa
kind: task
status: done
priority: P0
created: 2026-07-24
updated: 2026-07-29
closed: 2026-07-29
outcome: succeeded
created_by: manual
source_runs: [2026-07-24-fix-deploy-qa-permission-001]
executed_by_runs: [2026-07-24-fix-authentik-admin-url-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0124-fix-deploy-qa-permission-denied]
estimated_blast_radius: low
estimated_reversibility: full
---

# Set AUTHENTIK_ADMIN_URL to QA's own Authentik instance on pro-data-tech-qa

## Why

Discovered while verifying T-0124's fix (permission-denied deploy blocker,
resolved) and `aiqadam/ai-qadam-platform`'s ISS-USR-REG-002 (registration
500 error, code fix merged as PR #51) live on `pro-data-tech-qa`.

After rebuilding and redeploying the `api` container with the fixed code,
`POST https://qa.aiqadam.org/api/v1/auth/register` now returns a clean
`400 registration_failed` instead of a bare `500` — confirming
ISS-USR-REG-002's fix works correctly. However, registration still cannot
fully succeed. The container's own logs show why:

```
[AuthentikClient] Authentik GET /api/v3/core/users/?email=... -> 523:
  {"title":"Error 523: Origin is unreachable", ...}
[RegistrationService] { event: 'registration.duplicate_check_failed', ... }
```

`apps/api/src/config/env.ts:151` defaults `AUTHENTIK_ADMIN_URL` to
`https://auth.aiqadam.org` (production's Authentik) when unset. QA's
`docker-compose.qa.yml` `api` service environment block overrides 4 other
vars (`PORT`, `REDIS_URL`, `DIRECTUS_URL`, `OIDC_ISSUER_URL`) for exactly
this class of "placeholder in .env, real value needed here" reason, but
does **not** override `AUTHENTIK_ADMIN_URL` — so the API falls back to
production's hostname, which QA's network/DNS obviously cannot reach for
admin-API calls (Cloudflare returns 523 "Origin is unreachable" — QA has
no route to production's origin for this purpose).

QA's own Authentik instance is reachable at `https://auth.qa.aiqadam.org`
(confirmed live: `/if/flow/default-authentication-flow/` → 200,
`/api/v3/root/config/` → 200) — this is the same hostname already
correctly used in `OIDC_ISSUER_URL`'s value
(`https://auth.qa.aiqadam.org/application/o/aiqadam-qa/`), just not
propagated to `AUTHENTIK_ADMIN_URL` as well.

## What done looks like

- [ ] `deploy/docker-compose.qa.yml`'s `api` service environment block
      (on `pro-data-tech-qa`, `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml`)
      gains `AUTHENTIK_ADMIN_URL: "https://auth.qa.aiqadam.org"`, following
      the exact same pattern/comment style as the existing 4 overrides in
      that block.
- [ ] `docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d api`
      picks up the new env var (recreate, not just restart, needed since
      it's an environment change).
- [ ] Live verification: `POST https://qa.aiqadam.org/api/v1/auth/register`
      with a well-formed, previously-never-used email returns `302`
      (`Location: /v1/auth/login`) — full registration success, not just
      "no longer 500."
- [ ] Confirm no other admin-API-calling code path on this host still
      silently defaults to the wrong Authentik URL (grep
      `AUTHENTIK_ADMIN_URL` usage in `apps/api/src` if needed, to confirm
      this one env var is the only thing that needed setting).

## Result

The `AUTHENTIK_ADMIN_URL: "https://auth.qa.aiqadam.org"` line was already
present in `deploy/docker-compose.qa.yml` on the host (added by run
`2026-07-24-fix-authentik-admin-url-001`) but became a git-uncommitted
local modification, never merged upstream into
`aiqadam/ai-qadam-platform`'s tracked copy of that file. Discovered
2026-07-29 while diagnosing an unrelated live 500 on
`https://qa.aiqadam.org/workspace/admin/users` (reported by
vladimir.titenko) — the QA deploy was 16 commits stale
(`d53b1973`, 2026-07-28) and needed a redeploy to current `main`
(`b5250071`) to pick up an SSR crash fix. `git checkout` for that
redeploy would have discarded this uncommitted line. Handled safely:
`git stash` the line → deploy → `git stash pop` (clean auto-merge) →
`docker compose up -d api` (recreate, not just restart, to pick up the
env change).

Live-verified post-recreate (2026-07-29): `api` container env now carries
`AUTHENTIK_ADMIN_URL=https://auth.qa.aiqadam.org` (confirmed via
`docker exec aiqadam-qa-api-1 env`); no more `523 Origin is unreachable`
errors calling out to production Authentik in fresh container logs.
Full registration-flow verification (the original `POST
.../v1/auth/register` → `302` acceptance criterion) was not re-run this
session — out of scope for the unrelated task that surfaced this — but
the root symptom (wrong Authentik host) is confirmed gone.

**Remaining gap this closure does NOT fix:** the fix still lives only as
an uncommitted local diff on the host — see new task
[T-0132](T-0132-upstream-qa-authentik-admin-url-into-repo.md), which
tracks committing this line into
`aiqadam/ai-qadam-platform`'s tracked `deploy/docker-compose.qa.yml` so
future deploys stop needing a stash/pop dance to avoid losing it.

## Notes

- This is a narrow, single-line `docker-compose.qa.yml` env var addition
  on a host file this repo already has a documented, precedented pattern
  for (the existing 4 overrides in the same block, with the same style of
  explanatory comment). Low blast radius, fully reversible (remove the
  line, recreate the container to roll back to the old — broken —
  default).
- Do NOT confuse this with T-0124: that task's scope (fixing the
  permission-denied deploy blocker) is fully complete and verified
  independently of this one. This is a distinct, newly-discovered
  environment-configuration gap, not a continuation of the same root
  cause.
- Source: discovered live during
  `2026-07-24-fix-deploy-qa-permission-001` (T-0124's own run), while
  performing the live functional verification T-0124's own acceptance
  criteria required.

## History
- 2026-07-24: created as `kind: task`, `status: pending`, `priority: P0` (manual, discovered during T-0124's live verification)
- 2026-07-24: status → `in-progress`, run `2026-07-24-fix-authentik-admin-url-001`
- 2026-07-29: status → `done`, outcome succeeded. Env var confirmed live on the `api` container after a QA redeploy to `b5250071` (unrelated task); preserved across the redeploy via git stash/pop. Follow-up filed as T-0132 to upstream the fix into the tracked repo file. Commit: n/a (host-local config change, not a repo commit in `ai-qadam-infra` or `ai-qadam-platform` yet).
