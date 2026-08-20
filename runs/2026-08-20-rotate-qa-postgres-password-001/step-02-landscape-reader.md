---
run_id: 2026-08-20-rotate-qa-postgres-password-001
step: 02
agent: landscape-reader
verdict: BLOCKED
created: 2026-08-20T17:10:00Z
task_id: T-0138-rotate-qa-postgres-password
inputs_read:
  - runs/2026-08-20-rotate-qa-postgres-password-001/step-01-task-reader.md
  - tasks/T-0138-rotate-qa-postgres-password.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - shared/app-registry.md
  - landscape/secrets-inventory.md
artifacts_changed: []
next_step_hint: >-
  Landscape is populated and recently verified but does NOT resolve the
  central question this task needs answered before design: the committed
  landscape has never documented a `directus` DATABASE living inside
  `ai-qadam-test-db-1` — only a `directus` APPLICATION/CMS service
  (`aiqadam-qa-directus-1`) that must connect to *some* Postgres backend,
  whose location and credential-variable name are not recorded anywhere in
  `landscape/`. Every landscape mention of "credentials for
  ai-qadam-test-db-1" names exactly `POSTGRES_USER`/`POSTGRES_PASSWORD`/
  `POSTGRES_DB` in `/var/www/ai-qadam-test/.env` as the bootstrap set for
  the `aiqadam` role, plus the app-registry's separate claim that
  `aiqadam-qa-api-1`'s env file uses `AIQADAM_QA_POSTGRES_PASSWORD` — but no
  landscape file states whether that second name is a duplicate/derived
  value of the same secret, a distinct DB-level password, or how Directus's
  own env var is named. This exact reconciliation gap was already flagged
  by step 01 as the top-priority open item; step 02 confirms it is a real
  landscape gap, not something step 01 missed reading. Recommend live
  discovery (read, not write, on `pro-data-tech-qa`) of: `docker exec
  ai-qadam-test-db-1 env | grep -i POSTGRES` (names only if re-run — task
  file's own precedent shows this command's OUTPUT is what caused the
  original exposure, so any discovery step must redact/never transcript
  the value), `/opt/apps/aiqadam-qa/deploy/.env` var names (not values) for
  every `PG*`/`POSTGRES*`/`DATABASE_URL` key, the `directus` service's env
  block in `docker-compose.qa.yml` for its DB connection var name, and
  `pg_hba.conf` on the container to settle the trust-auth question T-0136
  raised. This is a discovery sub-step, not a full re-run of step 02.
---

## Summary
The committed landscape (`landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`, `shared/app-registry.md`, `landscape/secrets-inventory.md`, all `last_verified: 2026-08-20`, `status: populated`, none stale) confirms `ai-qadam-test-db-1` is a single `pgvector/pgvector:pg16` container hosting the `aiqadam` superuser role across at least the `aiqadam_test` and `aiqadam_qa` databases, with the bootstrap credential set (`POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB`) living in `/var/www/ai-qadam-test/.env` on the host — but the landscape does **not** document a `directus` database inside this container at all (only a `directus` CMS *application* service, `aiqadam-qa-directus-1`, whose own database backend is never named), does not reconcile the `POSTGRES_PASSWORD` vs. `AIQADAM_QA_POSTGRES_PASSWORD` naming split the task itself flags as unresolved, records no rotation mechanism for this credential (unlike the just-completed Directus token rotation, T-0137, which is fully documented), and gives no evidence on whether the bootstrap env var is re-read on container restart. This is a genuine landscape gap, not a reading failure — verdict is `BLOCKED`, recommending a scoped, read-only live-discovery sub-step before step 03/04 can design the rotation safely.

## Details
### Relevant facts (sourced from landscape)

**Container / cluster topology**
- `ai-qadam-test-db-1` (`pgvector/pgvector:pg16`) is the sole Postgres container on `pro-data-tech-qa`, bound `127.0.0.1:3112` → `5432`, Compose project `ai-qadam-test`, volume `ai-qadam-test_ai_qadam_test_pgdata`. — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`_
- Two databases are explicitly documented inside this one container: `aiqadam_test` ("original," pre-QA-stack, user `aiqadam`) and `aiqadam_qa` ("new database... created inside the existing `ai-qadam-test-db-1` container (NOT a new container/instance)... the pre-existing `aiqadam_test` database is untouched," added 2026-07-13 by T-0110). Both use the same role, `aiqadam`. — _source: `landscape/hosts/pro-data-tech-qa.md` §"AI Qadam QA stack" and §"AiQadam application stack (aiqadam-qa)"; `shared/app-registry.md`_
- **No landscape file documents a `directus` database inside `ai-qadam-test-db-1`.** The `directus` CMS is documented only as an *application container* (`aiqadam-qa-directus-1`, image `directus/directus:11`, host-networked, "previously undocumented" until T-0126 on 2026-07-27) — its own Postgres backend/database name is never stated in any of the four files read. — _source: `landscape/hosts/pro-data-tech-qa.md` container table; `landscape/services.md`_

**Credential env-var names (the core open question)**
- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` are named explicitly as the contents of `/var/www/ai-qadam-test/.env` (mode 600, `tvolodi:tvolodi`) — the legacy, postgres-only Compose project's env file, used by `ai-qadam-test-db-1`'s own healthcheck (`pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}`). This is the container-bootstrap credential set. — _source: `landscape/hosts/pro-data-tech-qa.md` §"AI Qadam QA stack"; `landscape/services.md`_
- The app-registry independently records that `aiqadam-qa-api-1`'s connection info comes from a *different* file, `/opt/apps/aiqadam-qa/deploy/.env` (mode 600/640) — but neither `shared/app-registry.md` nor `landscape/hosts/pro-data-tech-qa.md` lists the actual key names inside that file for the Postgres connection (they enumerate `WEB_BASE_URL`, `OIDC_REDIRECT_URI`, two named-only secrets for JWT/internal-API, and — as of T-0125 — `AUTHENTIK_ADMIN_URL` — never a `POSTGRES_PASSWORD`, `AIQADAM_QA_POSTGRES_PASSWORD`, or `DATABASE_URL` key). — _source: `landscape/hosts/pro-data-tech-qa.md` §"AiQadam application stack (aiqadam-qa)"; `shared/app-registry.md`_
- **`AIQADAM_QA_POSTGRES_PASSWORD` does not appear anywhere in the four landscape files read.** It is cited only in step 01's handoff as coming from a *runtime* source (a prior run's live `.env` read, `2026-08-20-seed-content-documents-qa-001` step 1.0a), not from the committed landscape. The committed landscape therefore cannot confirm, deny, or explain the relationship between `POSTGRES_PASSWORD` and `AIQADAM_QA_POSTGRES_PASSWORD` — whether they're the same secret under two names, two independently-rotatable secrets, or a bootstrap-var vs. app-level-var pairing. — _source: absence confirmed by full read of all four files; contrast noted against `runs/2026-08-20-rotate-qa-postgres-password-001/step-01-task-reader.md`_

**Bootstrap-only vs. re-read behavior**
- No landscape file states or tests whether `POSTGRES_PASSWORD` is read only at first-ever container init. This is asserted only as "standard Postgres Docker image behavior" in the task file itself (an assumption to be empirically confirmed, not landscape fact). The closest landscape evidence is indirect: the container's named volume (`ai-qadam-test_ai_qadam_test_pgdata`) has persisted across at least one full reboot (T-0099, 2026-07-10) and multiple `docker compose up -d` recreates of *other* services in the stack, with no record of the Postgres container itself being force-recreated or its volume reset since original bootstrap (2026-07-08, T-0090 Phases A–E) — consistent with, but not proof of, bootstrap-only env consumption. — _source: `landscape/hosts/pro-data-tech-qa.md` Change log, full history 2026-07-08 through 2026-08-20_

**T-0136/T-0137 close-out context (today's prior rotation, same host)**
- T-0137 (2026-08-20, run `2026-08-20-rotate-qa-directus-token-001`) rotated `DIRECTUS_ADMIN_TOKEN`/`DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_PASSWORD` — a **Directus application-level** credential set, unrelated to the Postgres role password, confirmed via live `PATCH /users/me` (DB-row field, re-read per-request, no restart needed) — this rotation *mechanism* is documented in detail but is explicitly for Directus's own user auth, not for Postgres. `landscape/secrets-inventory.md` was created for the first time by this rotation. — _source: `landscape/hosts/pro-data-tech-qa.md` Change log 2026-08-20 entry; `landscape/secrets-inventory.md`_
- T-0136 (2026-08-20, run `2026-08-20-seed-content-documents-qa-001`) close-out confirms bootstrap.sh had never been fully run against QA before today (tracked as follow-up T-0139 for further schema-drift investigation) and confirms the RBAC 403s were a red herring (Administrator policy always had `admin_access: true`). Nothing in T-0136's close-out note in `pro-data-tech-qa.md` documents a `directus` *Postgres database* or reconciles the Postgres password naming — the "directus" database mentioned in this task's step-specific input is not corroborated by the committed landscape at all (it is asserted by the step-02 prompt itself as "discovered today," but the discovery is not reflected in any of the four landscape files read). — _source: `landscape/hosts/pro-data-tech-qa.md` frontmatter `last_verified_note` and Change log_

**Trust auth**
- No landscape file documents `pg_hba.conf` contents or any Unix-socket trust-auth configuration for `ai-qadam-test-db-1`. Step 01's handoff cites this as coming from the T-0136 run's live session context, not from committed landscape.

**Consumers enumerated in landscape (as distinct from the unconfirmed `AIQADAM_QA_POSTGRES_PASSWORD`/`directus`-DB questions above)**
- `ai-qadam-test-db-1` itself — bootstrap consumer via `/var/www/ai-qadam-test/.env`.
- `aiqadam-qa-api-1` — connects to `aiqadam_qa` (and per app-registry's original scope note, only `apps/api` is containerized for QA; `apps/web`/`apps/web-next` are not present in this Compose project, though `web-next` per T-0126 discovery IS running as a 7th container — its own DB dependency, if any, is not documented). No other `aiqadam-test`-labeled containers exist per the `ai-qadam-test` Compose project table (single container, postgres only) — so no sibling legacy consumer container exists at the Docker level; any external/manual `aiqadam_test` consumer (e.g. a developer's local psql session, an old cron job) is not enumerated anywhere in landscape.
- `aiqadam-qa-directus-1` — CMS service, presumed Postgres consumer given Directus requires a relational DB backend, but its actual DB target (this cluster vs. something else, database name, credential var name) is undocumented.
- No landscape file mentions backup/cron/monitoring jobs that read Postgres credentials for this host (`## Backups` section of `pro-data-tech-qa.md` explicitly states "no data to back up yet... no application-level backups... none configured" — though this predates the QA app stack's deployment and has not been re-verified since).

### Stale or stub files encountered
None. All four files read have `last_verified: 2026-08-20` (or, for `services.md`, `2026-08-17` with a `last_verified_note` referencing today's T-0137 rotation content indirectly via the linked host file) and `status: populated`. `landscape/secrets-inventory.md` is newly created today (first-ever version, per T-0137's Change log entry) and contains only Directus-family entries — no Postgres/`aiqadam` role entry exists yet, which is expected (this task's own final checklist item is to add one after rotation) but confirms the inventory currently has zero prior-rotation history for this specific credential to cross-check against.

### Gaps requiring live discovery
1. **Whether a `directus` *database* actually exists inside `ai-qadam-test-db-1`**, or whether Directus's CMS data lives in a different Postgres instance/container entirely (undocumented anywhere) — this materially changes the blast-radius/consumer-count claim in the task file itself.
2. **The relationship between `POSTGRES_PASSWORD` (in `/var/www/ai-qadam-test/.env`) and `AIQADAM_QA_POSTGRES_PASSWORD` (reported live in a prior run, not in committed landscape)** — same secret under two names, two different secrets, or a bootstrap-var/app-var pairing. Landscape has zero data point on this.
3. **The actual key name(s) inside `/opt/apps/aiqadam-qa/deploy/.env` used for the Postgres connection** (by `aiqadam-qa-api-1` and, if applicable, `aiqadam-qa-directus-1`) — never enumerated in `shared/app-registry.md` or `landscape/hosts/pro-data-tech-qa.md`, both of which list other keys from that file (`WEB_BASE_URL`, `OIDC_REDIRECT_URI`, `AUTHENTIK_ADMIN_URL`, named-only secrets) but never a Postgres-related one.
4. **Empirical confirmation of Postgres's bootstrap-only env-var read behavior** on this specific container/image (`pgvector/pgvector:pg16`) — landscape offers only indirect, non-conclusive circumstantial evidence (volume persistence across other services' recreates).
5. **`pg_hba.conf` auth method(s)** on `ai-qadam-test-db-1`, to determine whether any consumer (especially a same-host Unix-socket path) bypasses the password entirely.
6. **Whether `aiqadam-qa-web-next-1`** (confirmed running by T-0126 but with "not enumerated" ports/env) has any direct Postgres dependency of its own, distinct from `aiqadam-qa-api-1`'s.
7. **Any rotation mechanism for the Postgres role password specifically** — T-0137's documented mechanism (`PATCH /users/me`) is Directus-specific and does not transfer; the task file's own checklist already specifies `ALTER ROLE aiqadam WITH PASSWORD '...'` as the intended mechanism, but no landscape file has previously exercised or documented this for a live rotation, so there is no precedent to cross-check against (unlike T-0137, which had none either but at least had a working Directus-native rotation API to lean on).

## Issues / risks
- The step-specific input for this step asserts "the 'directus' database, discovered today" as settled fact, but none of the four required landscape files actually contains this fact — it is not in `pro-data-tech-qa.md`'s Change log, container tables, or Postgres section, nor in `services.md` or `app-registry.md`. Either the discovery was made in a live session that was never written back to landscape (a landscape-currency gap in its own right, separate from this task), or the premise needs re-verification live before step 03 treats "3 databases" as confirmed. Flagging rather than silently trusting the step-specific input over the landscape, per this agent's read-only, landscape-only mandate.
- Task file's blast-radius framing ("every service that connects to `ai-qadam-test-db-1`... authenticates through this one credential") is itself only partially verifiable from landscape — the landscape confirms 2 databases and 2 clear app-level consumers (`ai-qadam-test-db-1` bootstrap, `aiqadam-qa-api-1`), but the third alleged database/consumer (Directus) and the second alleged credential name (`AIQADAM_QA_POSTGRES_PASSWORD`) are both landscape-unconfirmed. Designing a rotation plan on the unconfirmed premise risks either under-enumerating (missing a real consumer) or over-scoping (treating a same-value alias as if it were a separate secret needing independent handling) — either failure mode is exactly what the task file's own risk section warns against.
- `landscape/secrets-inventory.md` currently has no row for the `aiqadam` Postgres role at all — step 08 (or whichever step updates landscape) will need to add a new row, not edit an existing one; there is no prior rotation-date baseline to compare against for this specific credential.

## Open questions
- Should step 03 (or a dedicated discovery sub-step) run a narrowly-scoped, read-only live check against `pro-data-tech-qa` to resolve gaps 1–6 above before design proceeds? Given the task file's own explicit mandate to "enumerate every consumer... BEFORE rotating" and "confirm empirically, don't assume" the bootstrap-only behavior, and given this agent's role boundary (landscape-only, no live commands), the answer appears to be yes — but that decision belongs to the orchestrator/step 03, not to this step.
- If a live discovery sub-step re-runs anything resembling `docker exec ai-qadam-test-db-1 env | grep -i POSTGRES`, it must not repeat the original exposure mode (dumping the raw password into a visible transcript) — e.g. redact the value, check only var *names* via a filtered command, or pipe through a value-suppressing transform. This constraint should be carried into whatever step performs the discovery.
