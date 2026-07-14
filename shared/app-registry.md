---
name: app-registry
last_updated: 2026-07-13
---
<!-- last_updated bumped by T-0111 (2026-07-13, run 2026-07-13-setup-aiqadam-prod-infra-001): added the Production environment section and the Redis/Valkey gap note to the QA section. -->

# App registry

Authoritative list of application projects managed by this infra repo. Migrated from `ai-dala-infra` 2026-07-10 (T-0101).

---

## AiQadam

| Property | Value |
|---|---|
| **App ID** | `aiqadam` |
| **Local source** | `c:\Users\tvolo\dev\ai-dala\aiqadam` (lowercase monorepo; pnpm + turbo) |
| **Stack** | Next.js (legacy prod) + Astro `web-next` + NestJS `api` (new monorepo), PostgreSQL 16 + pgvector |
| **Health endpoint** | `GET /` → 200 (Next.js or Astro depending on build) |

### Test environment (QA instance on pro-data-tech-qa)

| Property | Value |
|---|---|
| **Server** | `pro-data-tech-qa` (95.46.211.230) |
| **Server checkout (postgres-only, legacy)** | `/var/www/ai-qadam-test/` |
| **Compose project name (postgres-only, legacy)** | `ai-qadam-test` |
| **Database container** | `ai-qadam-test-db-1` (pgvector/pgvector:pg16) on `127.0.0.1:3112` → `5432` |
| **Databases** | `aiqadam_test` (original, user: `aiqadam`) and `aiqadam_qa` (new, added 2026-07-13 by T-0110, same container/user) |
| **Volume** | `ai_qadam_test_pgdata` (canonical Docker name: `ai-qadam-test_ai_qadam_test_pgdata`) |
| **Env file (postgres-only, legacy)** | `/var/www/ai-qadam-test/.env` (mode 600, `tvolodi:tvolodi`) |
| **App checkout** | `/opt/apps/aiqadam-qa/` — git HEAD `dfd2a7c`, from `https://github.com/aiqadam/ai-qadam-platform.git` |
| **App Compose project name** | `aiqadam-qa` |
| **App Compose file** | `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` (2 services: `oidc-stub`, `api`; `network_mode: host`) |
| **App env file** | `/opt/apps/aiqadam-qa/deploy/.env` (mode 600) — includes 2 new secrets, names only: `aiqadam-qa-jwt-signing-secret`, `aiqadam-qa-internal-api-token` (see [`secrets-inventory.md`](../landscape/secrets-inventory.md)) |
| **Containers** | `aiqadam-qa-oidc-stub-1` (`nginx:alpine`, `127.0.0.1:9999`, static OIDC discovery stub) and `aiqadam-qa-api-1` (built from `apps/api/Dockerfile`, `127.0.0.1:3113`) |
| **Host port** | `3113` (api; next free port in the `127.0.0.1:3110-3119` reserved test-app range — `3112` is postgres) |
| **nginx vhost** | `/etc/nginx/sites-available/qa-uz.aiqadam.org` → proxies to `127.0.0.1:3113` |
| **Health endpoint** | `GET https://qa-uz.aiqadam.org/health` → `200`, `{"status":"ok","service":"api","tenant":{"code":"uz",...}}` |
| **Scope decision** | Only `apps/api` is containerized for QA — `apps/web` and `apps/web-next` are NOT deployed here. OIDC login and Directus-CMS-backed routes are therefore non-functional in this environment by design; schema-valid placeholder OIDC/Directus env vars satisfy boot-time validation only. This is the user-approved minimal-viable-slice scope for T-0110. |
| **Tenant-resolution nuance** | The health endpoint resolves via the app's `DEFAULT_TENANT_CODE='uz'` fallback, not genuine subdomain-to-tenant matching: the hostname `qa-uz.aiqadam.org`'s leftmost label (`qa-uz`, 5 chars) fails the app's exactly-2-char tenant-code check in `tenant.middleware.ts` and falls through to the default. It is not recognized as "the uz tenant" by name — it is recognized as "not a 2-character code, so use the default." A genuine subdomain-tenant match would require a hostname whose leftmost label is exactly a registered 2-char code (e.g. `uz.aiqadam.org`), which was not chosen here. This is sufficient and correct for this environment's actual purpose (a QA health-check smoke test), but fragile in principle: any future change to `NON_TENANT_LABELS`, the length-based branch, or `DEFAULT_TENANT_CODE` in the app's source could silently change this hostname's behavior. |
| **oidc-stub dependency** | Permanent fixture of this environment, not a temporary placeholder — the `api` container's boot-time `Issuer.discover()` call requires a reachable OIDC discovery endpoint, and `aiqadam-qa-oidc-stub-1` (a static `nginx:alpine` stub on loopback `9999`) satisfies that requirement indefinitely. Real OIDC login is out of scope; the stub is not slated for replacement as part of any currently-known future task. |
| **Known deviation** | Bare `GET https://qa-uz.aiqadam.org/` (root path) returns 404 — pre-existing Nest/Express app behavior (no route handler for `GET /`), confirmed unrelated to infra, not a regression. |
| **Known gap** | No Redis/Valkey service is included in this stack (only `oidc-stub` + `api`). The `api` container logs continuous `ioredis ECONNREFUSED` from `JtiRevocationService`/`OutboxRelayService`/internal-cron/Telegram module — the app boots and `/health` passes (zod default `REDIS_URL=redis://localhost:6379`), but token-revocation-on-signout and background cron/Telegram features are silently non-functional. Noted retroactively (T-0111, 2026-07-13) — the same underlying gap was present here but not recorded at T-0110 close-out. Same gap exists in prod (see below); tracked as a pending follow-on task (see `tasks/`). |
| **Deploy status** | Done 2026-07-13 ([T-0110](../tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md)) — both containers healthy, nginx + Let's Encrypt TLS live, UFW 80/443 open. |
| **Next milestone** | [T-0112](../tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md) (deploy keys) and [T-0113](../tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md) (CI/CD workflow), then [T-0114](../tasks/T-0114-first-deploy-aiqadam-to-qa.md) (first CI-driven deploy to this QA host). |

### Production environment (pro-data-tech-prod)

| Property | Value |
|---|---|
| **Server** | `pro-data-tech-prod` (95.46.211.224) |
| **App checkout** | `/opt/apps/aiqadam-prod/` — git HEAD `dfd2a7c` (pinned, detached HEAD — same commit already validated on QA via T-0110), from `https://github.com/aiqadam/ai-qadam-platform.git` |
| **App Compose project name** | `aiqadam-prod` |
| **App Compose file** | `/opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml` (3 services: `postgres`, `oidc-stub`, `api`; `network_mode: host`) |
| **App env file** | `/opt/apps/aiqadam-prod/deploy/.env` (mode 600) — includes 3 new secrets, names only: `aiqadam-prod-jwt-signing-secret`, `aiqadam-prod-internal-api-token`, `aiqadam-prod-postgres-password` (see [`../landscape/secrets-inventory.md`](../landscape/secrets-inventory.md)) |
| **Database** | Dedicated `aiqadam_prod` database inside the new `aiqadam-prod-postgres-1` container (`postgres:16`) — NOT shared with QA's `aiqadam_qa`/`aiqadam_test`. Host port `3114` → `5432`. Volume `aiqadam-prod_aiqadam_prod_pgdata`. |
| **Containers** | `aiqadam-prod-postgres-1` (`postgres:16`, `3114`, binds `0.0.0.0`/`[::]` under `network_mode: host`, UFW-shielded rather than app-layer-restricted), `aiqadam-prod-oidc-stub-1` (`nginx:alpine`, `127.0.0.1:9998`, static OIDC discovery stub), `aiqadam-prod-api-1` (built from `apps/api/Dockerfile`, `127.0.0.1:3115`) |
| **Host ports** | `3114` (postgres), `9998` (oidc-stub, loopback), `3115` (api, loopback) |
| **nginx vhost** | `/etc/nginx/sites-available/aiqadam.org` → proxies to `127.0.0.1:3115`. Bare apex only (`server_name aiqadam.org;`, no `www`). Additive — coexists with the pre-existing `penpot.aiqadam.org` vhost on the same host. |
| **Health endpoint** | `GET https://aiqadam.org/health` → `200`, `{"status":"ok","service":"api","tenant":{"code":"uz",...}}` |
| **Tenant-resolution nuance** | Unlike QA's length-based fallback, the bare apex `aiqadam.org` resolves to the `uz` tenant because `aiqadam` (and `www`) are hardcoded into the app's own `NON_TENANT_LABELS` set — confirmed by reading `tenant.middleware.ts` source during T-0111 execution. This is an intentional, source-confirmed exemption, not an accidental length-check fallthrough. |
| **Scope decision** | Only `apps/api` is containerized for prod — `apps/web` and `apps/web-next` are NOT deployed here. OIDC login and Directus-CMS-backed routes are therefore non-functional in this environment by design; schema-valid placeholder OIDC/Directus env vars satisfy boot-time validation only. Matches the QA precedent (T-0110). |
| **oidc-stub dependency** | Permanent fixture of this environment, not a temporary placeholder — mirrors the QA `oidc-stub` pattern exactly. Real OIDC login is out of scope; not slated for replacement as part of any currently-known future task. |
| **Known deviation** | Bare `GET https://aiqadam.org/` (root path) returns 404 (JSON, from Express — no route handler for `GET /`) — pre-existing app behavior, same as QA, confirmed unrelated to infra. |
| **Known gap** | No Redis/Valkey service is included in this stack. The `api` container logs continuous `ioredis ECONNREFUSED` from `JtiRevocationService`/`OutboxRelayService`/internal-cron/Telegram module — the app boots and `/health` passes (zod default `REDIS_URL=redis://localhost:6379`), but token-revocation-on-signout and background cron/Telegram features are silently non-functional. Same underlying gap as QA (see above). Recommended follow-on: add a dedicated Redis/Valkey container for `aiqadam-prod`, mirroring Penpot's own `penpot-penpot-valkey-1` pattern already proven on this same host. Tracked as a pending follow-on task (see `tasks/`). |
| **Postgres bind-address posture** | Binds `0.0.0.0:3114`/`[::]:3114` under `network_mode: host` (not app-layer loopback-restricted) — protected solely by UFW's default-deny-incoming policy, matching the existing Penpot `postgres:15` precedent on this host rather than introducing a new per-service hardening posture. |
| **DNS / Cloudflare** | Apex `aiqadam.org` A record (zone `bec8854d698d56ff17cf917367634100`, record ID `bf1113199732117bd147ebd87d6e356d`) repointed from a pre-existing third-party record (`212.20.151.29`) to `95.46.211.224`, `proxied` flipped `true`→`false`. See [`../landscape/cloudflare.md`](../landscape/cloudflare.md) for full zone detail and blast-radius reasoning. |
| **TLS** | Separate Let's Encrypt cert for `aiqadam.org` (ECDSA, issued 2026-07-13, expires 2026-10-11), auto-renewing via the same `certbot.timer` already active on the host. Penpot's own cert (`penpot.aiqadam.org`, expires 2026-10-09) is fully independent and unaffected. |
| **Deploy status** | Done 2026-07-13 ([T-0111](../tasks/T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod.md)) — all 3 containers healthy (`RestartCount=0`), nginx + Let's Encrypt TLS live, Penpot confirmed unregressed (7/7 containers, external 200) at every checkpoint throughout execution. |
| **Next milestone** | [T-0112](../tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md) (deploy keys) and [T-0113](../tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md) (CI/CD workflow), then [T-0115](../tasks/T-0115-first-promote-aiqadam-to-prod.md) (first CI-driven promotion to this prod host). |

---

## Adding a new app

1. Create deploy artifacts in the project repo under `deploy/`.
2. Add a new section here with all table properties filled in.
3. Create an infra setup task and a deploy task (linked via `blocked_by`).
