---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 02
agent: landscape-reader
verdict: BLOCKED
created: 2026-08-20T13:35:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/step-01-task-reader.md
  - tasks/T-0136-seed-content-documents-qa.md
  - workflows/deploy-app.md
  - landscape/README.md
  - landscape/services.md
  - shared/app-registry.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/domains.md
  - landscape/cloudflare.md
artifacts_changed: []
next_step_hint: task-validator (step 03) should treat this as BLOCKED per deploy-app.md's app-registration requirement — app-registry.md's QA section is stale relative to services.md/hosts file, and neither source enumerates Directus's host port or admin-token location. A discovery sub-step against pro-data-tech-qa (or a manual operator lookup) is needed to resolve Directus's reachable URL and token before a plan can be designed safely.
retry_of: null
---

## Summary

The landscape confirms QA's Directus container exists and is healthy but leaves two facts this task needs unresolved: Directus's actual reachable URL/port, and any record of its admin token. `landscape/services.md` (last_verified 2026-08-17) and `landscape/hosts/pro-data-tech-qa.md` (last_verified 2026-07-29) both describe `aiqadam-qa-directus-1` (image `directus/directus:11`, part of the 7-container `aiqadam-qa` Compose project, `network_mode: host`) as "Up (healthy)" but explicitly say its host port was "not enumerated" by the discovery run (T-0126) that first found it. There is no nginx vhost, no `landscape/domains.md` entry, and no `shared/app-registry.md` field for a Directus URL — the only public vhost documented for this host is `qa.aiqadam.org`, which proxies to the NestJS `api` container on port 3113, not Directus. `landscape/secrets-inventory.md` does not exist in this checkout (confirmed via glob — zero matches); per `landscape/README.md` it is git-ignored and must be created locally by an operator, so no admin-token reference exists in the repo at all. Separately, `shared/app-registry.md`'s aiqadam QA section is stale (`last_updated: 2026-07-17`) and contradicts the newer `services.md`/host file: it still documents only 2 containers (`oidc-stub`, `api`) and the retired `qa-uz.aiqadam.org` vhost, with no mention of Directus, and has no `Scripts` table entry of any kind (confirmed via grep — no "Scripts" or "seed" match anywhere in the file), so deploy-app.md's script-first execution model has nothing to fall back to but the manual sequence, and even that requires facts not present in the landscape.

## Details

### Relevant facts (sourced from landscape)

- QA host is `pro-data-tech-qa` (95.46.211.230, provider pro-data.tech), `role: ai-qadam-qa`. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- The `aiqadam-qa` Compose project (`/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml`, `network_mode: host`) runs 7 containers: `oidc-stub`, `api`, `web-next`, `directus`, `authentik-server`, `authentik-worker`, `redis`. — _source: `landscape/services.md`, `landscape/hosts/pro-data-tech-qa.md`_
- `aiqadam-qa-directus-1` runs image `directus/directus:11`, status "Up (healthy)" at the time of the 2026-07-27 discovery (T-0126), host port **"not enumerated"** — explicitly flagged as an open gap in both files. — _source: `landscape/services.md` line ~91, `landscape/hosts/pro-data-tech-qa.md` line ~135_
- Since the container uses `network_mode: host`, Directus is reachable at whatever port it binds on the host's loopback/interface directly — but that port was never captured by any discovery run. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- The only documented public vhost for this host is `qa.aiqadam.org` (nginx → `127.0.0.1:3113`, the `api` container) — there is no Directus-specific vhost, subdomain, or Cloudflare DNS record anywhere in `landscape/domains.md` or `landscape/cloudflare.md`. — _source: `landscape/domains.md`, `landscape/cloudflare.md`_
- `landscape/secrets-inventory.md` does not exist on disk (glob returned zero matches); per `landscape/README.md` this file is git-ignored by design and "operators must create this file locally" — there is no committed reference to a QA Directus admin token, or to any QA Directus secret at all. — _source: `landscape/README.md`_
- `shared/app-registry.md`'s "Test environment (QA instance on pro-data-tech-qa)" section (`last_updated: 2026-07-17`) documents only 2 containers (`oidc-stub`, `api`) and the now-retired `qa-uz.aiqadam.org` vhost — it predates the T-0126 discovery that found the other 5 containers (including Directus) and predates the `qa-uz` → `qa` vhost migration. It is stale relative to `services.md`/the host file. — _source: `shared/app-registry.md`_
- `shared/app-registry.md` has no `Scripts` table of any kind for the `aiqadam` app (confirmed by grep across the whole file) — deploy-app.md's script-first model has no registered entry point for this or any other operational script. — _source: `shared/app-registry.md`_
- Directus admin access precedent exists for a *different* Authentik-related purpose: `landscape/hosts/pro-data-tech-qa.md` notes "no persisted Authentik admin credential exists in `secrets-inventory.md` for QA" and that operators instead use `docker exec -i aiqadam-qa-authentik-server-1 ak shell` — suggesting the operational pattern on this host, when a UI/API credential isn't recorded, is direct container exec rather than a stored token. The same pattern (`docker exec` into `aiqadam-qa-directus-1`, or reading its env file directly on-host) may be the only way to obtain Directus's admin token/URL live, since nothing is recorded in the landscape. — _source: `landscape/hosts/pro-data-tech-qa.md`_

### Stale or stub files encountered

- `shared/app-registry.md` — `last_updated: 2026-07-17`, i.e. 34 days before today (2026-08-20), exceeding the 30-day staleness threshold. Its QA section is also substantively wrong (2 containers documented vs. 7 actually running), not just old.
- `landscape/domains.md` / `landscape/cloudflare.md` — both `last_verified: 2026-07-23`, within the 30-day window (not flagged stale), but neither has ever had a reason to record Directus since it has no public DNS/vhost presence.

### Gaps requiring live discovery

- **Directus's actual host port / bind address on `pro-data-tech-qa`** — not recorded anywhere in the landscape. Needed to construct `DIRECTUS_URL` for the seed script (likely something like `http://127.0.0.1:<port>` if loopback-only, given the pattern of every other container in this stack, but the exact port is unconfirmed).
- **Directus admin token for QA** — no reference exists in `secrets-inventory.md` (file absent) or anywhere else in the repo. Must be obtained live, e.g. via `docker exec -i aiqadam-qa-directus-1 ...` to inspect its env, or by generating a fresh static token through the Directus admin UI/API if reachable, or by reading `/opt/apps/aiqadam-qa/deploy/.env` on-host (the same env file already documented as holding other QA secrets by name only).
- **Whether `/opt/apps/aiqadam-qa/`'s on-host checkout is already at or past the commit that added `infrastructure/directus/seed-content-documents.sh`** — the landscape's most recent recorded git HEAD for this checkout is stale (`dfd2a7c` per `shared/app-registry.md`, itself flagged stale above; `landscape/hosts/pro-data-tech-qa.md`'s CI/CD section mentions HEAD `b5250071` as of T-0125/2026-07-29, still likely earlier than the PR #272 merge this task depends on). Must be confirmed live via `git log`/`git fetch` on-host, not assumed from the landscape.

## Issues / risks

- **`shared/app-registry.md` drift is itself worth flagging to the user/orchestrator as a standalone landscape-hygiene issue**, independent of this task: it has been silently wrong about QA's container topology and vhost name for over three weeks while `services.md` and the host file were correctly updated by T-0126/T-0130/T-0131. Nothing in this run's scope requires fixing that drift, but step-08 (landscape-updater) should consider a corrective note or a follow-up task, since deploy-app.md's own "App registration requirement" leans on this file being authoritative.
- No committed secret reference exists for QA Directus at all — this is not just a stale pointer, it is a total absence. The executor cannot proceed without either a human supplying the token directly (out-of-band, never in a committed file) or a live discovery sub-step that reads it off the host.
- Because `network_mode: host` is used for every container in this Compose project, "internal" vs "external" port distinctions collapse to whatever the container binds on the host directly — the discovery gap here is a real operational unknown, not just a documentation lag.

## Open questions (optional)

- Should step 03 (task-validator) route this straight to a discovery sub-run against `pro-data-tech-qa` (SSH `docker exec`/`docker inspect` on `aiqadam-qa-directus-1`, plus a look at `/opt/apps/aiqadam-qa/deploy/.env`) before solution-designer can write a real plan? This landscape-reader recommends that path rather than solution-designer guessing at a port/token.
- Should the `shared/app-registry.md` staleness be raised as its own follow-up task (e.g. "sync app-registry.md's QA section with the T-0126/T-0130/T-0131 findings already in services.md/hosts file"), given deploy-app.md treats app-registry.md as the authoritative gate for whether a deploy-app workflow may even execute?
