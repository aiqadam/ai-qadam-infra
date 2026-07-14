---
run_id: 2026-07-13-setup-aiqadam-qa-infra-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-13T00:00:00Z
task_id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
inputs_read:
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-01-task-reader.md
  - landscape/README.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - shared/app-registry.md
  - landscape/secrets-inventory.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator and solution-designer can proceed without a discovery sub-run. Key facts to build the plan around — free port 3113 (3110-3119 range, 3112 taken), Dockerfiles already exist for apps/api, apps/web, apps/web-next in the app repo, origin remote CONFIRMED correct, UFW currently 22/tcp only, no nginx/certbot on pro-data-tech-qa, only penpot.aiqadam.org exists in the Cloudflare zone today.
---

## Summary
`pro-data-tech-qa` (95.46.211.230) has Docker 29.6.1 + Compose v5.3.1 installed and one running container, `ai-qadam-test-db-1` (pgvector/pgvector:pg16) bound to `127.0.0.1:3112` on Compose project `ai-qadam-test` at `/var/www/ai-qadam-test/`; there is no app container, no nginx, no certbot, and UFW allows only `22/tcp` (v4+v6, no source restriction) with default-deny incoming. The `aiqadam.org` Cloudflare zone currently contains exactly one DNS record, `penpot.aiqadam.org` → `95.46.211.224` (pro-data-tech-prod), so `qa.aiqadam.org` does not yet exist and must be created fresh — no cross-repo coordination is needed since this repo already owns the zone. `shared/app-registry.md`'s QA section only documents the postgres container; it has no app container name, host port, compose path, or health endpoint yet, all of which this task must fill in. Local reconnaissance of `c:\Users\tvolo\dev\ai-dala\aiqadam` confirms its `origin` remote is exactly `https://github.com/aiqadam/ai-qadam-platform.git` — the task's assumption is CORRECT, no halt needed — and the repo has a pnpm/turbo monorepo layout with `apps/api`, `apps/web`, `apps/web-next` (plus `bot`, `e2e`, `storybook`, `workers`), each with its own `Dockerfile` already present for api/web/web-next/storybook, and existing GitHub Actions workflows (`deploy.yml`, `deploy-web-next.yml`) that solution-designer may want to reference for image-build conventions (though T-0110 explicitly does not create CI workflows — that's T-0113).

## Details
### Relevant facts (sourced from landscape)
- Host `pro-data-tech-qa` has Docker engine 29.6.1 (build `8900f1d`) + Compose plugin v5.3.1 + containerd, installed 2026-07-08 by T-0090 Phases A–E. — _source: [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md)_
- Only running Compose project is `ai-qadam-test` at `/var/www/ai-qadam-test/docker-compose.yml` (mode 644, owner `tvolodi:tvolodi`), with `.env` at the same path (mode 600, owner `tvolodi:tvolodi`, contains `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB`). — _source: [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md)_
- The one container, `ai-qadam-test-db-1` (`pgvector/pgvector:pg16`), is bound `127.0.0.1:3112` → `5432`, status `Up (healthy)`, restart `unless-stopped`, db `aiqadam_test`, user `aiqadam`, volume `ai-qadam-test_ai_qadam_test_pgdata`. No app container (`ai-qadam-test-app-*`) exists yet. — _source: [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md), [landscape/services.md](../../landscape/services.md)_
- nginx: **not installed** on `pro-data-tech-qa`; no vhosts. certbot: not mentioned as installed anywhere on this host (contrast with `pro-data-tech-prod`, which has certbot 4.0.0 + python3-certbot-nginx + active `certbot.timer` from T-0109). — _source: [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md), [landscape/services.md](../../landscape/services.md)_
- UFW on `pro-data-tech-qa`: active, `Default: deny (incoming), allow (outgoing)`, `DEFAULT_FORWARD_POLICY="ACCEPT"` (flipped from DROP by T-0090 for Docker bridging), IPv6 enabled. Only inbound rule: `22/tcp` (v4+v6) from any source, no allowlist. Ports 80/443 are confirmed closed by an external TCP probe recorded in the landscape (`TcpTestSucceeded: False`). — _source: [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md)_
- `pro-data-tech-qa` is NOT behind Cloudflare — pro-data.tech manages its own networking; the host has no DNS presence in `landscape/cloudflare.md` or `landscape/domains.md` today. Adding `qa.aiqadam.org` will be the first DNS record pointing at this host. — _source: [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md)_
- `aiqadam.org` Cloudflare zone: Zone ID `bec8854d698d56ff17cf917367634100`, one record only — `penpot.aiqadam.org` A → `95.46.211.224` (pro-data-tech-prod, proxied `false`, record ID `fde29338774531998ae38c41cd2e28ad`). No record for `qa.aiqadam.org` exists — this task will create it fresh, no collision, no cross-repo coordination needed (this repo owns the zone). — _source: [landscape/cloudflare.md](../../landscape/cloudflare.md), [landscape/domains.md](../../landscape/domains.md)_
- Cloudflare API token / zone ID / account ID for `aiqadam.org` are referenced only by key name (`cloudflare-ai-qadam-zone-id`, `cloudflare-ai-qadam-api-token`, `cloudflare-ai-qadam-account-id`) in `credentials.md` — never in this repo. — _source: [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md)_
- Reference pattern from prod: T-0109 on `pro-data-tech-prod` installed nginx 1.28.3 + certbot 4.0.0 direct (HTTP-01 challenge, Cloudflare proxy OFF), producing `https://penpot.aiqadam.org` with cert at `/etc/letsencrypt/live/penpot.aiqadam.org/` (ECDSA, auto-renew via `certbot.timer`). This is the closed-form precedent the task file recommends following for `qa.aiqadam.org` unless the user wants Cloudflare-proxied TLS instead. — _source: [landscape/services.md](../../landscape/services.md), [landscape/domains.md](../../landscape/domains.md)_
- `shared/app-registry.md` QA section currently documents: server `pro-data-tech-qa`, checkout path `/var/www/ai-qadam-test/`, compose project `ai-qadam-test`, db container/volume/env-file paths — but **no app container, no host port, no compose file beyond the postgres-only one, no health endpoint**. Deploy status explicitly says "app container deferred (no app source clone yet)." Free port range `127.0.0.1:3110-3119` is reserved for test apps; `3112` is taken (postgres), so the next free port is `3113`. — _source: [shared/app-registry.md](../../shared/app-registry.md)_
- Local repo `c:\Users\tvolo\dev\ai-dala\aiqadam`: `git remote -v` shows `origin` = `https://github.com/aiqadam/ai-qadam-platform.git` (fetch+push) — **matches the task's assumed checkout URL exactly**. A second remote, `oldorigin` = `https://github.com/tvolodi/aiqadam.git`, also exists but is not `origin` and is irrelevant to the checkout target. Current branch `main` at commit `dfd2a7c479c18e9acea5b3e0f53e19aca3f777bb` (2026-07-09), working tree clean. — _source: live `git -C` inspection, read-only, this step_
- Local repo layout: pnpm + turbo monorepo. `apps/` contains `api`, `web`, `web-next`, `bot`, `e2e`, `storybook`, `workers`. Package names: `@aiqadam/api`, `@aiqadam/web`, `@aiqadam/web-next`. Dockerfiles already exist at `apps/api/Dockerfile`, `apps/web/Dockerfile`, `apps/web-next/Dockerfile`, `apps/storybook/Dockerfile` — no Dockerfile under `apps/bot` or `apps/workers` in the current tree. — _source: live filesystem inspection, read-only, this step_
- `infrastructure/docker-compose.yml` (11,708 bytes) exists in the app repo and is the file the task file already flags as local-dev-only ("Production runs on Coolify on the platform host; this file does not apply there") — confirmed present, not reusable verbatim per the task's stated constraint. — _source: live filesystem inspection, read-only, this step_
- Existing CI artifacts in the app repo worth solution-designer's awareness (not to be used/created by this task — T-0113's scope): `.github/workflows/deploy.yml`, `.github/workflows/deploy-web-next.yml`, `infrastructure/web-next/deploy.sh`. — _source: live filesystem inspection, read-only, this step_

### Stale or stub files encountered
- None. `landscape/hosts/pro-data-tech-qa.md` last_verified 2026-07-10 (3 days old, within freshness window). `landscape/services.md` last_verified 2026-07-11. `landscape/cloudflare.md` last_verified 2026-07-11, status `active` (not a stub — the README's "stub" note for this file is itself stale text left over from before T-0107/T-0108/T-0109 populated it; the file's own frontmatter and content are current and populated). `landscape/domains.md` last_verified 2026-07-11, status `active` (same README-stale-note caveat). `shared/app-registry.md` last_updated 2026-07-08 (5 days old) — still accurate as confirmed by cross-checking against `landscape/services.md`'s more recent entry for the same container.

### Gaps requiring live discovery (deferred to executor / already flagged for solution-designer)
- Exact resource needs / port bindings for whichever app service(s) get containerized (api vs web vs web-next vs multiple) — solution-designer must decide based on the confirmed `apps/` layout above and the task's health-endpoint note (`GET /` → 200, Next.js or Astro depending on build).
- Whether the existing `ai-qadam-test-db-1` schema/migration state is compatible with reuse, vs needing a fresh QA-scoped postgres — this can only be determined by connecting to the running container or inspecting the app's migration files, not from the landscape.
- Exact `.env` variable names/values the app needs at runtime — must come from the app repo's own `.env.example` or deploy docs (not read in this step; in scope for solution-designer to open `infrastructure/.env.example` if useful, since it's a local file, not a secret value).
- pro-data.tech provider-level firewall/NAT specifics are marked "unknown" in the host landscape file — not expected to block 80/443 UFW+nginx since 22/tcp already works the same way, but not independently confirmed for 80/443.

## Issues / risks
- None new beyond what step 01 already flagged. The two highest-leverage open items from step 01 (GitHub remote match, Coolify-vs-SSH decision) are now resolved: the remote match is CONFIRMED correct, and the SSH+Compose decision is already closed per the task's stated constraints.
- Medium blast radius stands: this task opens UFW 80/443 and creates the qa.aiqadam.org DNS record + TLS cert on a host that today only exposes SSH — task-validator and solution-designer should still treat this carefully even though the remote-mismatch risk is now cleared.
- Minor note: `landscape/README.md`'s file-scope table describes `cloudflare.md` and `domains.md` as stubs with a T-0090a cross-repo-coordination caveat — this description is now outdated (both files are populated and this repo owns the zone outright per T-0107/T-0108/T-0109). Not blocking, but landscape-updater (step 08) may want to correct `landscape/README.md`'s table text while it's updating other files, since it could mislead a future landscape-reader into over-flagging a coordination requirement that no longer applies.

## Open questions
none — verdict is PASS, no discovery sub-run needed. The remote-mismatch risk that could have produced a BLOCKED verdict was checked directly in this step and came back matching.
