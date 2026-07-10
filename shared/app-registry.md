---
name: app-registry
last_updated: 2026-07-08
---

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
| **Server checkout** | `/var/www/ai-qadam-test/` |
| **Compose project name** | `ai-qadam-test` |
| **Database container** | `ai-qadam-test-db-1` (pgvector/pgvector:pg16) on `127.0.0.1:3112` → `5432` |
| **Database** | `aiqadam_test` (user: `aiqadam`) |
| **Volume** | `ai_qadam_test_pgdata` (canonical Docker name: `ai-qadam-test_ai_qadam_test_pgdata`) |
| **Env file** | `/var/www/ai-qadam-test/.env` (mode 600, `tvolodi:tvolodi`) |
| **Deploy status** | Phase A–E done 2026-07-08 ([T-0090](../tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md)) — postgres container running + healthy, app container deferred (no app source clone yet) |
| **Next milestone** | [T-0090a](../tasks/T-0090a-prepare-qadam-test-public-https-endpoint.md) — clone ai-qadam source, build app image, expose via nginx + Cloudflare (`qadam-test.ai-dala.com`). **⚠ Cloudflare DNS step requires coordination with `ai-dala-infra` repo owner.** |

---

## Adding a new app

1. Create deploy artifacts in the project repo under `deploy/`.
2. Add a new section here with all table properties filled in.
3. Create an infra setup task and a deploy task (linked via `blocked_by`).
