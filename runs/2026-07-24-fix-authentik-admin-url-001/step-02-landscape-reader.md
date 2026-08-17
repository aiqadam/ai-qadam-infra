---
run_id: 2026-07-24-fix-authentik-admin-url-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-24T02:20:00Z
task_id: T-0125-fix-authentik-admin-url-on-qa
inputs_read:
  - runs/2026-07-24-fix-authentik-admin-url-001/step-01-task-reader.md
  - landscape/README.md
  - workflows/infrastructure.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
artifacts_changed: []
next_step_hint: task-validator (step 03) can validate against landscape as-is; solution-designer (step 04) must instruct executor-infra (step 06) to read the live docker-compose.qa.yml api environment block before editing, since neither landscape file records its exact current text — this is expected and already flagged by step 01, not a blocker.
---

## Summary

Both landscape files are fresh (`services.md` last_verified 2026-07-23, `pro-data-tech-qa.md` last_verified 2026-07-17 — neither stale by the >30-day rule) and confirm the host-level shape of the task: `pro-data-tech-qa` runs Compose project `aiqadam-qa` (`network_mode: host`) from `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml`, with `oidc-stub` and `api` containers, `api` proxied by nginx at the public hostname, and QA's own Authentik reachable at `auth.qa.aiqadam.org` per `OIDC_ISSUER_URL`. However, **neither landscape file documents the `api` service's compose-level environment override block at all** — no mention of `PORT`, `REDIS_URL`, `DIRECTUS_URL`, `OIDC_ISSUER_URL`, or `AUTHENTIK_ADMIN_URL` as compose-file overrides, and no reference to a task T-0124 or T-0125 anywhere in `landscape/`. T-0113 (2026-07-17, the most recent aiqadam-qa change note) covers only the `deploy.sh` script rewrite, not this env block. This means the "already documented from T-0113" and "pending T-0124 step 08" premises in the step-01/task framing do not hold against the current landscape state: the 4-var block's exact text is not, and never has been, in the landscape. This is expected per the task's own step-01 handoff, which already flags live discovery as required — not a landscape staleness problem.

## Details

### Relevant facts (sourced from landscape)

- Host `pro-data-tech-qa` (95.46.211.230) runs Compose project `aiqadam-qa`; compose file `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml`; two services `oidc-stub` and `api`; `network_mode: host`. — _source: `landscape/hosts/pro-data-tech-qa.md` (§"AiQadam application stack (aiqadam-qa)", §"CI/CD deploy user"), `landscape/services.md` (§pro-data-tech-qa Docker)_
- App checkout at `/opt/apps/aiqadam-qa/`, git HEAD `dfd2a7c` (as of T-0110/T-0113); cloned from `https://github.com/aiqadam/ai-qadam-platform.git`. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- `aiqadam-qa-api-1` container: built from `apps/api/Dockerfile`, bound `127.0.0.1:3113` (loopback only, host network), proxied externally by nginx vhost `qa-uz.aiqadam.org` (HTTPS, Let's Encrypt, cert expires 2026-10-11). — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`_
- Env file `/opt/apps/aiqadam-qa/deploy/.env` (owner `tvolodi:aiqadam-qa-secrets`, mode 640 since T-0112) documents only `WEB_BASE_URL` and `OIDC_REDIRECT_URI` (both pointing at `qa-uz.aiqadam.org`) among its contents — the landscape does **not** enumerate the full `.env` var list, and does **not** describe the compose file's own `environment:` block for `api` at all. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Task's own step-01 handoff (verbatim from the task file) states QA's Authentik is confirmed live and reachable at `https://auth.qa.aiqadam.org` (`/if/flow/default-authentication-flow/` → 200, `/api/v3/root/config/` → 200) and that this is the same hostname already used in `OIDC_ISSUER_URL`'s value (`https://auth.qa.aiqadam.org/application/o/aiqadam-qa/`) — but this Authentik-reachability confirmation and the `OIDC_ISSUER_URL` value itself are **not** independently recorded anywhere in `landscape/` (neither host file nor services.md mentions Authentik, `auth.qa.aiqadam.org`, or an OIDC issuer URL value). It exists only in the task file's prose, carried forward by step 01. — _source: cross-check of step-01 handoff against `landscape/hosts/pro-data-tech-qa.md` + `landscape/services.md`, no landscape hits_
- `network_mode: host` is confirmed for the `aiqadam-qa` compose project generally (both `oidc-stub` and `api` run on host networking), consistent with the task's assumption that QA's own Authentik hostname is directly reachable from the `api` container without any container-network alias/DNS complication. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- No task file or run directory for `T-0124` exists anywhere in the repo (`tasks/` lists only up to `T-0113`; `runs/` has no `T-0124`-named or 2026-07-24-dated run other than this one and a distinct `2026-07-24-fix-deploy-qa-permission-001`, which step 01's own task text also treats as separate/already-resolved). The step-01 framing referencing "T-0124's own step 08" appears to describe a run that has not left any landscape or task-file trace as of this read. — _source: absence check across `tasks/*.md` and `runs/*` directory listing_
- No landscape file anywhere mentions `AUTHENTIK_ADMIN_URL`, `DIRECTUS_URL`, `REDIS_URL`, or the "4-var override" pattern by name — a repo-wide grep across `landscape/` for these strings returns zero matches. — _source: grep across `landscape/`_

### Stale or stub files encountered

- None. `landscape/hosts/pro-data-tech-qa.md` — last_verified 2026-07-17 (7 days old, within the 30-day threshold), status `populated`. `landscape/services.md` — last_verified 2026-07-23 (1 day old), status `populated`. Neither is a stub.

### Gaps requiring live discovery

- **Exact current text of the `api` service's `environment:` block** in `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` on the host — including the precise comment style/wording used for the existing 4 overrides (`PORT`, `REDIS_URL`, `DIRECTUS_URL`, `OIDC_ISSUER_URL`). Not present in the landscape in any form; must be read live via SSH before the executor edits it, to match formatting exactly as the task requires.
- **Whether `AUTHENTIK_ADMIN_URL` (or an equivalent config key) is read elsewhere in `apps/api/src`** with its own separate default — the landscape has no visibility into application source code at all; this must be confirmed via a live grep of the checkout at `/opt/apps/aiqadam-qa/apps/api/src` (or the upstream repo) as the task's step-01 handoff already anticipates.
- **Whether a second environment file (e.g., a host `.env` distinct from the compose file) also needs the fix** — the landscape only names two files that exist (`.env` and `docker-compose.qa.yml`) but does not enumerate `.env`'s full contents, so it cannot confirm or rule out a second silent-default path there.
- **Confirmation that QA's Authentik at `https://auth.qa.aiqadam.org` is still live/reachable today (2026-07-24)** — the landscape has no record of Authentik at all (it is not a project-deployed service tracked in `services.md`); the only evidence is the task file's own prose citing checks from "today" (ambiguous whether that means 2026-07-23 or 2026-07-24 relative to this run). Re-verify live rather than trust the secondhand citation.
- **The actual outcome of any run named after T-0124** — no such run exists in `runs/`, so whatever fix or verification T-0124 supposedly performed (permission-denied deploy blocker + ISS-USR-REG-002 code fix rehearsal) is not corroborated by the landscape. The closest matching run is `2026-07-24-fix-deploy-qa-permission-001` (steps 01–04 only, no further steps present), which appears to be a separate, still in-progress workflow — not proof that a "T-0124" registration-fix workflow ran to completion today.

## Issues / risks

- The task's framing implies the 4-var override pattern and Authentik configuration facts are "already documented in the landscape from T-0113's earlier work" — this is not accurate. T-0113 (2026-07-17) only touched `deploy.sh`'s deploy-script logic; it never touched or documented the compose file's `api` environment block. Downstream steps (solution-designer, executor) should not assume any landscape-recorded exact text for the 4-var block exists — it must be fetched live, exactly as step 01 already flagged.
- The referenced "T-0124" task/run cannot be located in this repo's `tasks/` or `runs/` directories. If a downstream step relies on T-0124's conclusions (e.g., "ISS-USR-REG-002's fix is merged and live on this host"), that reliance rests solely on the current task file's own prose, not on independently verifiable landscape state. Recommend the execution-validator (step 07) re-confirm the `api` container is actually running the PR #51 fix (e.g., via image build timestamp or a quick behavioral check of the 400-vs-500 distinction) rather than assuming it from this task's narrative alone.
- Low blast radius otherwise: this is a single-line env-var addition to a QA-only compose file, fully consistent with an established, already-used 4-var override pattern on this same host — no idempotency or rollback design complexity expected beyond what the executor-infra agent already does for compose edits (backup file before edit).

## Open questions (optional)

- none — gaps above are live-discovery items for step 04/06, not landscape ambiguities that block this step's own PASS verdict.
