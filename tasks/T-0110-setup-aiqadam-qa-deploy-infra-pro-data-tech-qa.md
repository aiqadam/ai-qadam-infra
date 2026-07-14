---
id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
title: Set up AiQadam QA deploy infra on pro-data-tech-qa (app container, nginx, Cloudflare DNS for qa.aiqadam.org)
kind: task
status: done
priority: P1
created: 2026-07-12
updated: 2026-07-13
closed: 2026-07-13
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-13-setup-aiqadam-qa-infra-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - shared/app-registry.md
workflow: infrastructure
blocks: [T-0112, T-0114]
blocked_by: []
related: [T-0090a]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Set up AiQadam QA deploy infra on pro-data-tech-qa

## Why
The user wants a pipeline: local code change → push to `https://github.com/aiqadam/ai-qadam-platform.git` → GitHub Actions CI build → auto-deploy to `pro-data-tech-qa` as the QA instance → manual promotion to `pro-data-tech-prod`. Before GitHub Actions can deploy anything, the QA host needs the app checkout, a deployable container, an nginx vhost, and a public HTTPS endpoint. This supersedes the app-container portion of [T-0090a](../../tasks/T-0090a-prepare-qadam-test-public-https-endpoint.md) (that task targeted `qadam-test.ai-dala.com` in the `ai-dala-infra`-owned zone; this task targets `qa.aiqadam.org` in the `aiqadam.org` zone this repo already owns, avoiding cross-repo Cloudflare coordination).

Per [workflows/deploy-app.md](../../workflows/deploy-app.md), a `deploy-app` workflow run cannot execute until this setup task is `status: done`.

## What done looks like
- [x] App repo cloned on `pro-data-tech-qa` at a project-standard path (e.g. `/opt/apps/aiqadam-qa/`) from `https://github.com/aiqadam/ai-qadam-platform.git` — done, git HEAD `dfd2a7c`
- [x] Production-shape `docker-compose.yml` (NOT `infrastructure/docker-compose.yml`, which is explicitly local-dev-only per its own header comment) exists for QA — either committed to the app repo under `deploy/` or written by this task, containing the app's actual deployable services (API, web, etc.) pointed at the existing `ai-qadam-test-db-1` postgres (`127.0.0.1:3112`) or a new QA-scoped postgres, per the executor's judgment call — see Open questions — done: `deploy/docker-compose.qa.yml`, 2 services (oidc-stub + api), reuses `ai-qadam-test-db-1` via a new `aiqadam_qa` database
- [x] `.env` file on host (mode 600) with QA secrets — values never committed to any repo — done, `/opt/apps/aiqadam-qa/deploy/.env`
- [x] Free host port chosen from the `127.0.0.1:3110-3119` test-app range reserved in `shared/app-registry.md` (3112 is taken by postgres; next free is 3113) — done, `3113`
- [x] App container(s) built and running, healthy — done, `aiqadam-qa-oidc-stub-1` + `aiqadam-qa-api-1`, both healthy
- [x] nginx installed on `pro-data-tech-qa`, vhost for `qa.aiqadam.org` proxying to the app's host port — done, but the public hostname was renamed mid-run to `qa-uz.aiqadam.org` (see Result section below) — vhost proxies to `127.0.0.1:3113`
- [x] UFW: `80/tcp` and `443/tcp` allowed (currently only `22/tcp` is open on this host) — done
- [x] Cloudflare DNS: A record `qa.aiqadam.org` → `95.46.211.230` in the `aiqadam.org` zone (Zone ID in `landscape/secrets-inventory.md`) — superseded: the record actually created and kept is `qa-uz.aiqadam.org` → `95.46.211.230` (record ID `53aa89ca061e343291f33bb7b8b3a12e`); `qa.aiqadam.org` was created then deleted within this same run — see Result section
- [x] Let's Encrypt TLS cert obtained via certbot (matches the `penpot.aiqadam.org` pattern on prod) — OR Cloudflare-proxied + origin cert, per executor's judgment; document the choice — done, certbot direct (HTTP-01), matches the prod pattern, for `qa-uz.aiqadam.org` (ECDSA, expires 2026-10-11)
- [x] `curl -I https://qa.aiqadam.org` returns 200 from an external workstation — **caveat, accepted as satisfied via substitute criterion:** literal bare-root `curl -I https://qa-uz.aiqadam.org` returns `404` (pre-existing app behavior, no route handler for `GET /`, confirmed unrelated to infra by both the executor and the independent validator). The operative health check, `curl -s https://qa-uz.aiqadam.org/health`, returns `200` with `{"status":"ok",...}` both on-host and externally, and was accepted as the substitute acceptance criterion — see Result section for full reasoning.
- [x] `shared/app-registry.md` updated: QA environment section filled in (host port, container names, compose path, health endpoint) — done
- [x] `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`, `landscape/cloudflare.md`, `landscape/domains.md` updated — done

## Notes
- The app's local dev compose file (`c:\Users\tvolo\dev\ai-dala\aiqadam\infrastructure\docker-compose.yml`) explicitly states "Production runs on Coolify on the platform host; this file does not apply there" and runs apps on the host, not in containers (`apps/web`, `apps/api`, `apps/bot`, `apps/workers`). The user has decided to proceed with a direct SSH + Docker Compose deploy model instead of Coolify for this pipeline — the solution-designer (step 04) must design a QA-appropriate compose file/Dockerfile from the app's actual source layout, not reuse the local-dev file verbatim.
- The GitHub repo `https://github.com/aiqadam/ai-qadam-platform.git` is the remote this task's checkout should track — confirm this matches `c:\Users\tvolo\dev\ai-dala\aiqadam`'s current `origin` remote during step 02/04 (landscape-reader / solution-designer); if it doesn't match, halt and ask the user before proceeding (do not assume).
- This task does NOT create the GitHub Actions workflow file — that's [T-0113](../../tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md). This task only makes the QA host ready to receive a deploy (manually or via CI).

## Open questions
- **Which app services actually need containers for QA?** The registry (`shared/app-registry.md`) lists "Next.js (legacy prod) + Astro web-next + NestJS api (new monorepo)". Solution-designer must read the actual app repo structure (`apps/api`, `apps/web`, etc.) to determine what needs to run in QA, and should ask the user if ambiguous rather than guessing. **Resolved:** `apps/api` only (user-approved minimal-viable-slice scope).
- **Database:** reuse existing `ai-qadam-test-db-1` (127.0.0.1:3112, db `aiqadam_test`) or provision a fresh one? Recommend reuse unless the app's schema/migration state is incompatible. **Resolved:** reused, via a new `aiqadam_qa` database inside the same container; `aiqadam_test` untouched.
- **TLS approach:** certbot direct (matches prod's Penpot pattern, T-0109) vs Cloudflare-proxied with origin cert. Recommend certbot direct for consistency with T-0109 unless the user wants Cloudflare proxying (e.g. for DDoS protection / caching). **Resolved:** certbot direct, matching T-0109.

## Result

Done 2026-07-13 via run [2026-07-13-setup-aiqadam-qa-infra-001](../runs/2026-07-13-setup-aiqadam-qa-infra-001/). Executor handoff: [step-06-executor-infra.md](../runs/2026-07-13-setup-aiqadam-qa-infra-001/step-06-executor-infra.md). Validator handoff: [step-07-execution-validator.md](../runs/2026-07-13-setup-aiqadam-qa-infra-001/step-07-execution-validator.md) (verdict PASS).

**What was done:** Cloned `https://github.com/aiqadam/ai-qadam-platform.git` (HEAD `dfd2a7c`) to `/opt/apps/aiqadam-qa/`. Deployed Compose project `aiqadam-qa` (`deploy/docker-compose.qa.yml`, host-networked): `aiqadam-qa-oidc-stub-1` (static OIDC discovery stub, permanent fixture) and `aiqadam-qa-api-1` (built from `apps/api/Dockerfile`, listening `127.0.0.1:3113`). Reused `ai-qadam-test-db-1` via a new `aiqadam_qa` database. Generated two new secrets (`aiqadam-qa-jwt-signing-secret`, `aiqadam-qa-internal-api-token`). Installed nginx 1.28.3 + certbot 4.0.0; opened UFW `80/tcp`+`443/tcp`.

**Deviations from the original plan, in the order they happened:**
1. **First attempt (Phase 10 of an earlier sub-run) FAILED**: the originally-planned hostname `qa.aiqadam.org` produced an HTTP 400 from the app's tenant-resolution middleware, because the app treats any 2-character leftmost hostname label as a literal tenant code and `qa` is not a registered tenant.
2. **Root-cause diagnosis** (solution-designer, second revision): read the app's actual tenant-parsing source (`tenant.middleware.ts`) rather than guessing; determined that a hostname whose leftmost label is *not* exactly 2 characters falls through to the app's `DEFAULT_TENANT_CODE='uz'`, and that `qa-uz` (5 chars) satisfies this.
3. **Hostname rename executed**: created `qa-uz.aiqadam.org` (Cloudflare A record, nginx vhost, Let's Encrypt cert, `.env` WEB_BASE_URL/OIDC_REDIRECT_URI), then deleted the orphaned `qa.aiqadam.org` DNS record and cert (both backed up first). This is a documented, working fix via default-tenant fallback, not genuine subdomain-to-tenant matching — flagged for future awareness in `shared/app-registry.md` and `landscape/domains.md`.
4. **Acceptance-criterion caveat**: the task's literal `curl -I` root-path check returns 404 (pre-existing app behavior, no handler for `GET /`), not the originally-worded 200. Both the executor and the independent validator confirmed this is unrelated to infra and accepted `/health` returning `200` as the operative substitute — recorded plainly above rather than silently checked off.

No other deviations. All other "What done looks like" items were met exactly as originally specified.

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain (user request: GitHub push → CI build → QA auto-deploy → manual prod promotion)
- 2026-07-13: status → in-progress, run 2026-07-13-setup-aiqadam-qa-infra-001
- 2026-07-13: status -> done, outcome succeeded, run 2026-07-13-setup-aiqadam-qa-infra-001, commit <pending>
