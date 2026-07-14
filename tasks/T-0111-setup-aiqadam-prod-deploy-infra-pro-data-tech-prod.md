---
id: T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod
title: Set up AiQadam prod deploy infra on pro-data-tech-prod (app container, nginx, Cloudflare DNS for aiqadam.org)
kind: task
status: done
priority: P1
created: 2026-07-12
updated: 2026-07-13
closed: 2026-07-13
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-13-setup-aiqadam-prod-infra-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - shared/app-registry.md
workflow: infrastructure
blocks: [T-0112, T-0115]
blocked_by: [T-0110]
related: []
estimated_blast_radius: high
estimated_reversibility: full
---

# Set up AiQadam prod deploy infra on pro-data-tech-prod

## Why
Mirrors [T-0110](../../tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md) but for the production environment. `pro-data-tech-prod` (95.46.211.224) already hosts Penpot (7-container Docker Compose stack under `/opt/penpot/`, nginx vhost for `penpot.aiqadam.org`) — this task adds the AiQadam app alongside it, on the bare domain `aiqadam.org`, without disturbing the existing Penpot deployment.

Sequenced after T-0110 so the QA setup (simpler, lower blast radius) validates the app's deployable shape (Dockerfile, compose file, env vars) before touching the prod host.

## What done looks like
- [x] App repo cloned on `pro-data-tech-prod` at a project-standard path (e.g. `/opt/apps/aiqadam-prod/`) from `https://github.com/aiqadam/ai-qadam-platform.git`, pinned to a specific tagged/reviewed ref (never `HEAD` of a moving branch for a first prod deploy) — pinned to `dfd2a7c` (detached HEAD), the same commit already validated on QA via T-0110
- [x] Production `docker-compose.yml` for prod (same shape validated in T-0110, adjusted for prod env vars/secrets/scaling as needed) — `docker-compose.prod.yml`, 3 services (postgres, oidc-stub, api)
- [x] `.env` file on host (mode 600) with PRODUCTION secrets — distinct from QA secrets, values never committed to any repo
- [x] Dedicated postgres for prod (do NOT reuse QA's database) — new Docker volume `aiqadam-prod_aiqadam_prod_pgdata`, new container `aiqadam-prod-postgres-1` (postgres:16), db `aiqadam_prod`
- [x] Free host port chosen (prod host currently only has 9001 bound for Penpot's frontend) — avoid collision — chose `3114` (postgres), `9998` (oidc-stub), `3115` (api)
- [x] App container(s) built and running, healthy — all 3 containers `Up (healthy)`, `RestartCount=0`
- [x] nginx vhost added for the bare domain `aiqadam.org` proxying to the app's host port — added as a NEW vhost file (`/etc/nginx/sites-available/aiqadam.org`) alongside the existing `penpot.aiqadam.org` vhost. `www.aiqadam.org` was explicitly out of scope per step-05 user approval (bare-apex-only).
- [x] UFW: 80/tcp and 443/tcp already allowed on this host (from T-0103) — confirmed no change needed
- [x] Cloudflare DNS: A record `aiqadam.org` (root/apex) → `95.46.211.224` in the `aiqadam.org` zone — repointed the pre-existing record (ID `bf1113199732117bd147ebd87d6e356d`) from a third-party host, per step-05 approval
- [x] Let's Encrypt TLS cert obtained via certbot for `aiqadam.org` — separate cert from `penpot.aiqadam.org`'s (executor's documented choice), expires 2026-10-11
- [x] `curl -I https://aiqadam.org` returns 200 from an external workstation, AND `curl -I https://penpot.aiqadam.org` still returns 200 (no regression to existing Penpot service) — **deviation, accepted:** bare `GET /` returns 404 JSON (no root route in the Express app, same as QA's known deviation); `GET /health` returns 200 and was used as the plan's own documented substitute. `penpot.aiqadam.org` confirmed 200 throughout.
- [x] `shared/app-registry.md` updated: prod environment section filled in
- [x] `landscape/hosts/pro-data-tech-prod.md`, `landscape/services.md`, `landscape/cloudflare.md`, `landscape/domains.md` updated

## Notes
- **Blast radius is HIGH** because this host runs a live, working Penpot instance. The solution-designer must explicitly verify the plan cannot disrupt the existing `penpot` Docker Compose project, its nginx vhost, or its TLS cert — e.g. use a distinct Compose project name (not `penpot`), a distinct `/opt/apps/...` directory (not `/opt/penpot/`), and additive nginx config (new `sites-available` file, not editing the existing one).
- First production deploy should use a reviewed/tagged git ref, not an arbitrary branch tip — confirm the exact ref with the user at plan-approval time (step 05).

## Open questions
- **`www.aiqadam.org` too, or bare domain only?** Confirm with user before the Cloudflare DNS step. — **Resolved:** bare apex only, per step-05 user approval.
- **Prod database provisioning:** fresh empty DB, or migrated data from somewhere? Assume fresh (this is a new deployment) unless the user says otherwise. — **Resolved:** fresh, dedicated `aiqadam_prod` database in a new container.
- **Resource contention with Penpot:** prod host has 16 vCPU / 31 GiB RAM / 339 GB disk with only Penpot running — headroom should not be an issue, but the solution-designer should note current utilization before adding the app stack. — **Resolved:** no contention; Penpot confirmed unregressed at every checkpoint.

## Result

Deployed successfully. AiQadam prod app stack (Compose project `aiqadam-prod`: `aiqadam-prod-postgres-1`, `aiqadam-prod-oidc-stub-1`, `aiqadam-prod-api-1`) is running on `pro-data-tech-prod` alongside the pre-existing Penpot deployment, with no regression to Penpot at any checkpoint. `https://aiqadam.org/health` returns 200; the Cloudflare apex A record was repointed from a third-party host to `95.46.211.224`; a dedicated Let's Encrypt cert was issued (expires 2026-10-11).

The run required two prior executor attempts before this one succeeded: attempt 1 hit a pre-flight SSH-key documentation error (the RSA `.ppk` key documented as usable for `tvolodi` is actually root-only; `ai-dala-infra` ED25519 is correct — corrected in `landscape/hosts/pro-data-tech-prod.md`), and attempt 2 crash-looped the `api` container because the Postgres password (generated via `openssl rand -base64 32`) happened to contain URL-metacharacters that broke `DATABASE_URL` parsing — fixed by switching to `openssl rand -hex 24` in a revised, re-approved plan (step-04 revision, step-05 re-approval).

One off-plan gap was identified and left unresolved by design (outside this task's written scope, confirmed non-blocking by both the executor and the validator): no Redis/Valkey service was provisioned, so the `api` container logs continuous `ioredis ECONNREFUSED` from `JtiRevocationService`/`OutboxRelayService`/internal-cron/Telegram — token-revocation-on-signout and background cron/Telegram features are silently non-functional. The same gap exists in the QA environment (T-0110) and was retroactively noted in `shared/app-registry.md`. A follow-on observation task has been created to track adding a dedicated Redis/Valkey container mirroring Penpot's own `valkey` pattern.

All 13 "What done looks like" items are satisfied, with one documented, plan-accepted deviation: the literal `curl -I https://aiqadam.org` returns 404 (JSON, from the Express app's lack of a root route) rather than 200 — `/health` (200) was used as the plan's own pre-approved substitute, consistent with the identical QA architecture.

- Executor handoff: [`runs/2026-07-13-setup-aiqadam-prod-infra-001/step-06-executor-infra.md`](../runs/2026-07-13-setup-aiqadam-prod-infra-001/step-06-executor-infra.md)
- Validator handoff: [`runs/2026-07-13-setup-aiqadam-prod-infra-001/step-07-execution-validator.md`](../runs/2026-07-13-setup-aiqadam-prod-infra-001/step-07-execution-validator.md)

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain
- 2026-07-13: status → in-progress, run 2026-07-13-setup-aiqadam-prod-infra-001
- 2026-07-13: status -> done, outcome succeeded, run 2026-07-13-setup-aiqadam-prod-infra-001, commit <pending>. Journey: SSH key documentation corrected (RSA .ppk is root-only, ai-dala-infra ED25519 is correct for tvolodi), Postgres password generation fixed (base64→hex to avoid URL-metacharacters breaking DATABASE_URL), Cloudflare apex A record repointed from a third-party host to 95.46.211.224. Redis/Valkey gap flagged as a follow-on task, not blocking.
