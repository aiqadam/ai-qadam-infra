---
id: T-0116-add-redis-valkey-to-aiqadam-qa-and-prod
title: Add a dedicated Redis/Valkey service to the AiQadam QA and prod app stacks
kind: observation
status: observation
priority: P2
created: 2026-07-13
updated: 2026-07-13
closed:
outcome:
created_by: 2026-07-13-setup-aiqadam-prod-infra-001
source_runs: [2026-07-13-setup-aiqadam-qa-infra-001, 2026-07-13-setup-aiqadam-prod-infra-001]
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - shared/app-registry.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0110, T-0111]
estimated_blast_radius: low
estimated_reversibility: full
---

# Add a dedicated Redis/Valkey service to the AiQadam QA and prod app stacks

## Why

Neither the QA (T-0110) nor the prod (T-0111) AiQadam app stacks include a Redis/Valkey service, but the `apps/api` NestJS application expects one. Quoted from the T-0111 executor's handoff (`runs/2026-07-13-setup-aiqadam-prod-infra-001/step-06-executor-infra.md`):

> "no Redis/Valkey service was ever included in this plan's Phase B/C, but the api app expects one. The `aiqadam-prod-api-1` container logs show continuous `ioredis Unhandled error event: AggregateError [ECONNREFUSED]` from `JtiRevocationService`, `OutboxRelayService`, and (per source inspection of `apps/api/src/config/env.ts`, `jti-revocation.service.ts`, `internal-cron.module.ts`, `telegram.module.ts`) also affects internal-cron and Telegram integrations — all default to `REDIS_URL=redis://localhost:6379` via a zod default, so the app boots and `/health` reports `ok`, but no Redis is actually running in this stack... Practical effect: JWT access-token revocation-on-signout likely does not take effect until natural token expiry ... and background cron/Telegram features are non-functional."

Confirmed independently by the T-0111 execution-validator (`runs/2026-07-13-setup-aiqadam-prod-infra-001/step-07-execution-validator.md`) as "a genuine scope gap, not a hidden crash risk" — non-blocking for T-0111's own closure, since T-0111's 13-item acceptance checklist made no mention of Redis.

The same gap exists in the QA environment (T-0110) — this was not explicitly recorded in `shared/app-registry.md`'s QA section at T-0110's close-out; the landscape-updater for T-0111 has retroactively added a note there.

## What done looks like

- [ ] A dedicated Redis/Valkey container added to both the `aiqadam-qa` and `aiqadam-prod` Compose projects — mirroring Penpot's own `penpot-penpot-valkey-1` pattern already proven on `pro-data-tech-prod` (image `valkey/valkey:8.1` or similar; loopback-only host binding; `network_mode: host` consistent with the rest of each stack, or a dedicated Docker network if preferred — executor's judgment, document choice)
- [ ] `REDIS_URL` set explicitly in each environment's `.env` file to point at the new service (no longer relying on the zod default `redis://localhost:6379`, made explicit and verified reachable)
- [ ] `api` container logs no longer show `ioredis ECONNREFUSED` / ECONNREFUSED-derived errors from `JtiRevocationService`, `OutboxRelayService`, internal-cron, or the Telegram module, in both environments
- [ ] Confirm token-revocation-on-signout actually takes effect (functional test: revoke a token, confirm it's rejected before natural expiry) in at least one environment
- [ ] No regression to the existing `api`/`postgres`/`oidc-stub` containers or to Penpot (on the prod host) — additive change only
- [ ] `landscape/hosts/pro-data-tech-qa.md`, `landscape/hosts/pro-data-tech-prod.md`, `landscape/services.md`, and `shared/app-registry.md` updated to reflect the new Redis/Valkey containers and remove the "Known gap" notes once resolved

## Result
<empty until closed; then: what actually happened, outcome, links to executing run(s) and commits, any deviations from the plan>

## Notes
- Low blast radius, full reversibility — this is an additive service to two already-working stacks; no existing container needs to be modified beyond an `.env`/environment-variable change.
- Priority set to P2 (default) since the gap is functionally real (auth-token revocation, background jobs) but did not block either T-0110 or T-0111's own acceptance criteria. Re-prioritize on promotion if auth-token revocation is judged security-sensitive enough to warrant P1.
- Consider doing QA first (lower blast radius) before prod, mirroring the T-0110→T-0111 sequencing precedent.

## History
- 2026-07-13: created from 2026-07-13-setup-aiqadam-prod-infra-001 (landscape-updater, step 08), based on findings from both 2026-07-13-setup-aiqadam-qa-infra-001 (T-0110) and 2026-07-13-setup-aiqadam-prod-infra-001 (T-0111)
