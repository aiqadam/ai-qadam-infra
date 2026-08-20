---
run_id: 2026-08-20-rotate-qa-postgres-password-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-20T12:20:00Z
task_id: T-0138-rotate-qa-postgres-password
inputs_read:
  - runs/2026-08-20-rotate-qa-postgres-password-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-08-20-rotate-qa-postgres-password-001/.attempts/step-06-executor-infra-attempt-1.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - workflows/infrastructure.md
  - .claude/agents/solution-designer.md
retry_of: step-04
artifacts_changed: []
next_step_hint: >-
  Orchestrator must halt and present this plan for user approval (do NOT
  auto-advance to executor) — secret rotation, unconditional
  NEEDS_APPROVAL per the task file's Notes section, same as attempt 1.
  Once approved, route to step 06 executor-infra. Phase 0 remains entirely
  read-only discovery and gates every later phase's shape; the two new
  Phase 0 sub-steps (0.4a Authentik credential-key identification, 0.10
  Authentik health-endpoint identification) are load-bearing for Phase
  2.6/2.7 and Phase 3.3 respectively and must resolve before those phases
  can be treated as fully specified — if either surfaces a shape this plan
  did not anticipate (e.g. Authentik uses a THIRD, distinct credential
  rather than AIQADAM_QA_POSTGRES_PASSWORD, or no DB-backed
  health/readiness endpoint exists), executor must halt into BLOCKED
  rather than improvise. Phase 3.1/3.2's verification commands are
  corrected in this revision to actually exercise password auth (the
  attempt-1 plan's `-h 127.0.0.1` test was silently hitting a trust-rated
  address per pg_hba.conf and would have falsely passed regardless of
  password value — this is now fixed by connecting from a bridge-network
  container context). Same output-hygiene discipline as before: no grep
  -B/-A + -v, single continuous SSH session per credential's
  generate-apply-verify sequence, count/status/digest-only verification,
  explicit BLOCKED on unplanned diagnostic need.
---

## Summary

Rotate the `aiqadam` Postgres cluster-superuser password on `ai-qadam-test-db-1` (`pro-data-tech-qa`) via `ALTER ROLE aiqadam WITH PASSWORD '...'`, after empirically closing the gaps attempt 1's executor surfaced — identifying Authentik's DB-credential key, correcting the trust/password auth-boundary narrative (real clients arrive from the Docker bridge gateway `172.18.0.1`, which falls under the password-required catch-all, not the `127.0.0.1/::1` trust entries), and resolving the uncatalogued `DATABASE_URL` key — then updating the one shared `AIQADAM_QA_POSTGRES_PASSWORD` value and recreating **all four** real TCP+password consumer containers (`api`, `directus`, `authentik-server`, `authentik-worker`), ending with the old password rejected, the new password working end-to-end via each service's real DB-backed health check (including Authentik's), and `landscape/secrets-inventory.md` recording only the rotation date. **This plan requires human approval before execution — unconditional per the task file's Notes (secret rotation).**

## Details

### What changed since attempt 1, and why

Attempt 1's executor ran Phase 0.1–0.6 exactly as planned (read-only, zero state changes) and surfaced three findings that this revision now designs around instead of leaving as open questions:

1. **A previously-uncatalogued `authentik` database exists**, with 3 live, password-authenticated connections (user `aiqadam`, from `172.18.0.1`) at discovery time. The Orchestrator's direct investigation (see step-specific input) has since resolved *which* credential this is: both `aiqadam-qa-authentik-server-1` and `aiqadam-qa-authentik-worker-1` are configured in `docker-compose.qa.yml` with `AUTHENTIK_POSTGRESQL__PASSWORD: ${AIQADAM_QA_POSTGRES_PASSWORD:?...}` — the exact same variable already shared by `api` and `directus`. This is **not** a fourth secret to enumerate; it is a third and fourth consumer **container** of the one already-known secret. This plan treats that as confirmed and no longer needs its own live discovery sub-step for the *variable name* — but Phase 0 still re-confirms it live (0.4a below) as cheap, mechanical double-checking before an irreversible step, consistent with this plan's "empirical, not assumed" discipline.
2. **The trust/password auth-boundary hypothesis in attempt 1 was wrong in its specifics** (though its conclusion — "TCP consumers are password-authenticated" — was accidentally still correct). `pg_hba.conf`'s only `trust`-rated TCP entries are the literal loopback addresses `127.0.0.1/32` and `::1/128`; every real client in this cluster connects from the Docker bridge gateway `172.18.0.1`, which falls through to the catch-all `host all all all scram-sha-256` rule. This matters concretely: attempt 1's Phase 3.1/3.2 verification used `-h 127.0.0.1` for both the "old password confirmed dead" and "new password confirmed working" checks — since `127.0.0.1` is trust-rated, **both checks would return `1` regardless of what password (or no password) was supplied**, making them worthless as proof of anything. This revision fixes Phase 3.1/3.2 to connect from an actual bridge-network address so SCRAM auth is genuinely exercised.
3. **A `DATABASE_URL=` key exists in `/opt/apps/aiqadam-qa/deploy/.env`** whose consumer is unresolved. This plan adds a discovery sub-step to identify it before Phase 2 can be called complete.

### Design principle: minimize password handling via trust auth (unchanged from attempt 1)

Every step that only needs to confirm database-level state (role exists, password age, `ALTER ROLE` success, target databases exist) uses `docker exec ai-qadam-test-db-1 psql -U aiqadam ...` over the local Unix socket — zero password, nothing to redact. The password value is handled only where structurally unavoidable: the `ALTER ROLE ... WITH PASSWORD` statement itself (Phase 2), and confirming real TCP consumers' connections actually succeed/fail with old/new values (Phase 0, Phase 3) — because that is inherently a network-auth test.

### Plan

#### Phase 0 — Discovery (read-only; no state changes; minimal password handling)

Sub-steps 0.1–0.3, 0.5–0.9 are unchanged from attempt 1's plan and were already executed successfully by attempt 1's executor for 0.1–0.6 (results below are carried forward as established facts, re-run only if the executor's session is not continuous with this plan's — see note at end of Phase 0). New/changed sub-steps are marked **NEW** or **REVISED**.

0.1. **Enumerate all databases in the cluster** (trust-auth, no password). *(Already executed by attempt 1 — established fact, re-run only if needed for session continuity.)*
   - Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc \"SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;\""`
   - **Established result:** `aiqadam_qa`, `aiqadam_test`, `authentik`, `directus`, `postgres`. Five databases total, confirming both the `directus` and `authentik` databases exist in this cluster.

0.2. **Enumerate all roles in the cluster.** *(Already executed — established fact.)*
   - **Established result:** `aiqadam` is the only superuser role; all others are stock `pg_*` predefined roles. No second role/password in scope.

0.3. **Read `pg_hba.conf`.** *(Already executed — established fact, REVISED interpretation.)*
   - **Established result:**
     ```
     local   all             all                                     trust
     host    all             all             127.0.0.1/32            trust
     host    all             all             ::1/128                 trust
     local   replication     all                                     trust
     host    replication     all             127.0.0.1/32            trust
     host    replication     all             ::1/128                 trust
     host all all all scram-sha-256
     ```
   - **Corrected interpretation:** local socket = trust (as expected). Literal-loopback TCP (`127.0.0.1/32`, `::1/128`) = ALSO trust — NOT password-required, contrary to attempt 1's hypothesis. Only the catch-all (`host all all all scram-sha-256`) requires a password, and it governs any source address not matched by an earlier, more specific rule — which in practice means every real client in this environment, since none connect from the literal loopback addresses (see 0.4).

0.4. **Enumerate live TCP connections to Postgres.** *(Already executed — established fact.)*
   - **Established result:**
     ```
     aiqadam_qa|aiqadam|172.18.0.1|client backend
     authentik|aiqadam|172.18.0.1|client backend   (x3)
     directus|aiqadam|172.18.0.1|client backend    (x2)
     postgres|aiqadam||client backend                (local socket, no client_addr)
     ```
   - **Established finding:** all real network clients connect from `172.18.0.1` (Docker bridge gateway), which per 0.3 falls under the password-required catch-all. This confirms `api` (against `aiqadam_qa`), `directus` (against `directus`), and Authentik (against `authentik`, 3 connections — server + worker) are all password-authenticated consumers of the `aiqadam` role.

0.4a. **NEW — Confirm Authentik's DB-credential variable live**, closing the gap attempt 1's executor flagged as unresolved (which `.env`/compose key holds Authentik's DB password).
   - Command: `ssh pro-data-tech-qa "grep -A 30 '^\s*authentik-server:' /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml | grep -iE 'AUTHENTIK_POSTGRESQL|POSTGRES'"`
   - This is a config-structure read (variable names and `${VAR}` interpolation syntax), not a value dump — same discipline as 0.6's Directus check. Safe to read in full.
   - **Working expectation** (per the Orchestrator's direct investigation, to be confirmed live, not assumed): `AUTHENTIK_POSTGRESQL__HOST: 127.0.0.1`, `AUTHENTIK_POSTGRESQL__PORT: "3112"`, `AUTHENTIK_POSTGRESQL__USER: aiqadam`, `AUTHENTIK_POSTGRESQL__PASSWORD: ${AIQADAM_QA_POSTGRES_PASSWORD:?...}`, `AUTHENTIK_POSTGRESQL__NAME: authentik`.
   - Verification: confirms Authentik reuses `AIQADAM_QA_POSTGRES_PASSWORD` (same variable as `api`/`directus`) rather than a distinct key. **Branch:** if the live compose block shows a DIFFERENT variable name than `AIQADAM_QA_POSTGRES_PASSWORD` (contradicting the Orchestrator's investigation), `BLOCKED` — return to solution-designer; this plan's Phase 2 (single shared-variable update) would be incomplete.
   - Command (repeat for worker, same session): `ssh pro-data-tech-qa "grep -A 30 '^\s*authentik-worker:' /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml | grep -iE 'AUTHENTIK_POSTGRESQL|POSTGRES'"` — confirms the worker's block matches the server's (expected, since they're typically configured identically in Authentik's standard compose pattern).

0.5. **Read the Postgres-related key names in `/opt/apps/aiqadam-qa/deploy/.env`.** *(Already executed — established fact.)*
   - **Established result:** only `DATABASE_URL=` matches the `(POSTGRES|PG|DATABASE|DB)[A-Z_]*=` pattern (expected — `AIQADAM_QA_POSTGRES_PASSWORD` starts with `AIQADAM`, outside this pattern, and was already independently confirmed present via 0.4a/0.6's compose-file reads). `DATABASE_URL`'s consumer/value is unresolved by this sub-step alone.

0.6. **Read the `directus` service's DB-connection env block.** *(Already executed — established fact.)*
   - **Established result:** `DB_CLIENT: pg`, `DB_HOST: 127.0.0.1`, `DB_PORT: "3112"`, `DB_DATABASE: directus`, `DB_USER: aiqadam`, `DB_PASSWORD: ${AIQADAM_QA_POSTGRES_PASSWORD:?...}`. Directus reuses `AIQADAM_QA_POSTGRES_PASSWORD`, connects to the `directus` database. Confirmed, no plan correction needed here.

0.6a. **NEW — Identify which service reads `DATABASE_URL`**, closing attempt 1's second open item.
   - Command: `ssh pro-data-tech-qa "grep -RilE 'DATABASE_URL' /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml"` — confirms only whether the compose file references this key at all.
   - **REVISED per Orchestrator review — no `-B/-A` context flags anywhere in this sub-step, full stop, no judgment call left to the executor.** The prior draft proposed `grep -B2 -A2 ... | grep -viE` on the compose file, reasoning it was safe since the file has no secret values — but today's exposure incident happened on a target the operator also believed was safe, via exactly this `-B/-A`-plus-`-v` shape. The rule from here on is mechanical, not risk-judged per-target: never combine `-B`/`-A` with `-v`, regardless of which file it's aimed at. Use this instead: `ssh pro-data-tech-qa "grep -oE '^\s*[a-z_-]+:' /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml"` to list every service block name (structural, no values, no context flags), cross-referenced against which blocks 0.4a/0.6/0.6b already fetched in full (`authentik-server`, `authentik-worker`, `directus`, `web-next`) — if `DATABASE_URL` didn't appear in `grep -RilE`'s match at all, it's confirmed unreferenced by compose, no further read needed. If it DID match, fetch the one containing service's block the same way 0.4a/0.6 already do (`grep -A 30 '^\s*<service>:' ... | grep -iE 'DATABASE_URL|POSTGRES'` — no `-B`, no `-v`), once the service name is known from the block-name list, rather than searching around the bare string `DATABASE_URL` with context flags.
   - Verification: identifies whether `DATABASE_URL` is (a) unreferenced/legacy — no action needed, note it in Issues/risks and leave untouched, or (b) referenced by some service — if that service embeds the `aiqadam` password in URL form, add it to Phase 2's update list as a new branch; if it's unrelated (e.g. Redis URL, or a different DB entirely), no action needed either way. **Branch:** if 0.6a cannot determine the answer from compose alone (e.g. the consuming service isn't in `docker-compose.qa.yml` at all — a systemd unit or cron script elsewhere), `BLOCKED` — do not guess whether it embeds the rotating password.

0.6b. **NEW — Confirm `web-next` and `redis` are not Postgres consumers** (cheap completeness check, since 0.4's live snapshot already shows no connections from anything but `api`/`directus`/`authentik`, but a static-config check closes the same point-in-time-snapshot gap attempt 1 flagged for other consumers).
   - Command: `ssh pro-data-tech-qa "grep -A 20 '^\s*web-next:' /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml | grep -iE 'POSTGRES|DB_|DATABASE_URL'"` — expected empty output (per landscape, `web-next` is a frontend with zero Directus/DB env vars, matching the pattern already established for T-0137).
   - Verification: empty output confirms `web-next` and `redis` are out of scope for this credential. **Branch:** if either shows a Postgres-related var, `BLOCKED` — this plan's consumer list is incomplete.

0.7. **Confirm whether `POSTGRES_PASSWORD` and `AIQADAM_QA_POSTGRES_PASSWORD` currently hold the same value** (digest comparison, values never printed). *(Not yet executed — attempt 1's executor halted before reaching this. Execute now.)*
   - Command (single SSH session): `ssh pro-data-tech-qa "sha256sum <(grep '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env | cut -d= -f2-) <(grep '^AIQADAM_QA_POSTGRES_PASSWORD=' /opt/apps/aiqadam-qa/deploy/.env | cut -d= -f2-)"`
   - Verification: two digests printed (no values). Equal → same secret under two names (expected). Unequal → one is stale; proceed to 0.8.

0.8. **If 0.7 finds unequal digests**, determine empirically which value actually authenticates.
   - Command (same session, only if 0.7 differs): `ssh pro-data-tech-qa "P=\$(grep '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env | cut -d= -f2-); PGPASSWORD=\$P docker exec -e PGPASSWORD ai-qadam-test-db-1 psql -h 172.18.0.1 -U aiqadam -d postgres -tAc 'SELECT 1' 2>&1 | tail -1; unset P PGPASSWORD"` then the equivalent substituting `AIQADAM_QA_POSTGRES_PASSWORD`. **Note the `-h` target is now `172.18.0.1` (the bridge gateway, matching 0.4's confirmed catch-all/password-required path), not `127.0.0.1`** (REVISED from attempt 1 — see Phase 3.1/3.2 for full rationale on why this matters).
   - Verification: identifies which var (one, both, neither) is live-functional. **Branch:** if NEITHER authenticates, `BLOCKED` — TCP+password auth is already broken independent of this rotation.

0.9. **Confirm Postgres bootstrap-env-var re-read behavior empirically.**
   - Command: `ssh pro-data-tech-qa "docker inspect ai-qadam-test-db-1 --format '{{.Created}}'"` compared against `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc \"SELECT pg_postmaster_start_time();\""`.
   - Verification: confirms editing the bootstrap `.env`'s `POSTGRES_PASSWORD` does NOT itself change the running role's password (only `ALTER ROLE` does) — Phase 2 does not need to restart `ai-qadam-test-db-1` itself.

0.10. **NEW — Identify Authentik's health/readiness endpoint(s)**, so Phase 3.3 can prove a real DB-backed operation succeeds post-rotation, not just a bare TCP-open or static-asset 200. Per the step-specific instruction, Authentik is the platform's own auth/SSO service — a silent DB-reconnect failure here is a platform-wide sign-in outage, so this verification must be substantive.
   - Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://auth.qa.aiqadam.org/-/health/live/"` — Authentik's standard liveness probe path (`/-/health/live/`) for the `goauthentik/server` image family; confirm this responds before relying on it.
   - Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://auth.qa.aiqadam.org/-/health/ready/"` — Authentik's standard readiness probe (`/-/health/ready/`), which for this image is documented to check backing-service connectivity (DB + cache), not just process liveness — this is the one that matters for Phase 3.3 if it responds and is confirmed DB-backed.
   - Verification: record actual HTTP status for both paths. **Branch:** if `/-/health/ready/` does not exist or returns a status that doesn't clearly indicate a DB check occurred (e.g. 404, meaning this Authentik version/build doesn't expose it at this path), fall back to a genuinely DB-backed operation instead: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://auth.qa.aiqadam.org/api/v3/core/applications/?page_size=1"` unauthenticated will 403 (still proves the API layer is up and routing, but not DB-backed) — if this is the only option available, note in Issues/risks that Phase 3.3's Authentik check is a weaker proxy than intended, OR use `docker exec aiqadam-qa-authentik-server-1 ak shell -c "from authentik.core.models import User; print(User.objects.count())"` as an unambiguous DB round-trip (this executes a real ORM query against the `authentik` database — the strongest possible proof, at the cost of being an exec-into-container check rather than an external HTTP probe). Prefer `/-/health/ready/` if it responds appropriately; use the `ak shell` ORM-query fallback if it does not. Do not declare Phase 3.3 satisfied on a bare TCP-open or a static 200 alone.

**Phase 0 continuity note:** if the executor's session for this retry is not a continuation of attempt 1's (e.g. a fresh session), sub-steps 0.1–0.3/0.5/0.6 should be re-run to reconfirm rather than assumed purely from this handoff's carried-forward text — cheap, read-only, and consistent with "empirical, not assumed."

#### Phase 1 — Backup (before any destructive change)

1.1. **Back up both host `.env` files** before editing either.
   - Command: `ssh pro-data-tech-qa "sudo cp -p /var/www/ai-qadam-test/.env /var/www/ai-qadam-test/.env.pre-T0138.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo chmod 600 /var/www/ai-qadam-test/.env.pre-T0138.*.bak"`
   - Command: `ssh pro-data-tech-qa "sudo cp -p /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.*.bak && sudo chown tvolodi:aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.*.bak"`
   - Never `cat`'d, never `grep`'d without `-oE`, never displayed.
   - Verification (presence only): `ssh pro-data-tech-qa "ls /var/www/ai-qadam-test/.env.pre-T0138.*.bak /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.*.bak >/dev/null 2>&1 && echo BACKUPS_EXIST"`

#### Phase 2 — Rotate at the Postgres role level, then update every real consumer

2.1. **Generate the new password on-host**, one continuous SSH session covering generation through every apply in this phase.
   - Command: `ssh pro-data-tech-qa "NEW_PG_PASSWORD=\$(openssl rand -base64 24); echo \$NEW_PG_PASSWORD | wc -c"` — prints only a character count.

2.2. **Apply the new password at the Postgres role level.**
   - Command (same session): `docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -c "ALTER ROLE aiqadam WITH PASSWORD '$NEW_PG_PASSWORD';"`
   - Idempotent; trust-auth local connection (no old password needed to run it).
   - Verification: returns `ALTER ROLE` (no password echoed).

2.3. **Update `/var/www/ai-qadam-test/.env`'s `POSTGRES_PASSWORD` line** (same session).
   - Command: `sudo sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$NEW_PG_PASSWORD|" /var/www/ai-qadam-test/.env`
   - Verification (count only): `grep -c '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env` → `1`.

2.4. **Update `/opt/apps/aiqadam-qa/deploy/.env`'s `AIQADAM_QA_POSTGRES_PASSWORD` line — the ONE shared value for api/directus/authentik-server/authentik-worker.**
   - Command: `sudo sed -i "s|^AIQADAM_QA_POSTGRES_PASSWORD=.*|AIQADAM_QA_POSTGRES_PASSWORD=$NEW_PG_PASSWORD|" /opt/apps/aiqadam-qa/deploy/.env`
   - Verification (count only): `grep -c '^AIQADAM_QA_POSTGRES_PASSWORD=' /opt/apps/aiqadam-qa/deploy/.env` → `1`.
   - This single edit is sufficient for all four containers — confirmed by 0.4a/0.6 that all four read this same variable via compose interpolation. No per-container `.env` key exists to update separately.

2.5. **Update `DATABASE_URL` — contingent on Phase 0.6a's finding.**
   - **If 0.6a found `DATABASE_URL` unreferenced/legacy:** no-op, explicitly recorded as such; do not touch the key (avoid churning an unrelated/dead value).
   - **If 0.6a found `DATABASE_URL` is a live reference embedding the `aiqadam` password:** update it in the same session, same file, same `sed` pattern targeting `^DATABASE_URL=`, then identify and add its consuming service to Phase 2.6/2.7's restart list.
   - **If 0.6a could not resolve the consumer:** this plan already branched to `BLOCKED` at 0.6a — this step is unreachable in that case.

2.6. **Recreate all four confirmed TCP+password consumer containers**: `api`, `directus`, `authentik-server`, `authentik-worker`. Do NOT restart `ai-qadam-test-db-1` itself (0.9 confirms the role-level `ALTER ROLE` is already live).
   - Command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d --no-deps api directus authentik-server authentik-worker"`
   - `--no-deps` avoids unintended cascading restarts of `web-next`/`redis`/`oidc-stub`, which are confirmed (0.6b, and prior landscape) not to hold this credential.
   - **Ordering note:** Authentik's worker and server are independent processes both reading the same env var at container-start time — recreating both together (single compose invocation, as above) is simpler and avoids a window where one is on the old password and the other the new. No inter-service startup-order dependency is known between `authentik-server` and `authentik-worker` for this purpose.
   - **If Phase 0 surfaces any additional, previously unknown consumer** (an undocumented process connecting to `aiqadam_test`/`aiqadam_qa`/`directus`/`authentik`, or 2.5's branch adds a new service): pause, add it under Issues/risks, confirm with the user whether in-scope or needs a follow-up task — do not silently restart-and-declare-done for an unanticipated consumer, per the task file's explicit "err on the side of over-enumerating" warning.
   - Verification: `docker ps --filter name=aiqadam-qa-api-1 --filter name=aiqadam-qa-directus-1 --filter name=aiqadam-qa-authentik-server-1 --filter name=aiqadam-qa-authentik-worker-1 --format '{{.Names}}: {{.Status}}'` shows a recent `Up` status for all four.

2.7. **Clean up in-session shell variables** as the final action of Phase 2, deferred until Phase 3 verification (same session) completes — see 3.5.

#### Phase 3 — Verification

3.1. **Old password confirmed dead for TCP auth — corrected to actually exercise password auth.**
   - **Why this changed from attempt 1:** attempt 1's plan tested via `-h 127.0.0.1`, which per 0.3's confirmed `pg_hba.conf` is a `trust`-rated address — that test would return `1` (success) regardless of the password supplied, proving nothing. The fix: connect from a context that actually presents as `172.18.0.1` (the bridge gateway address every real consumer connects from, per 0.4), or from any address NOT covered by the `127.0.0.1/32`/`::1/128` trust entries, so the catch-all `scram-sha-256` rule is genuinely exercised.
   - Command: `OLD_PG_PASSWORD=$(grep '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env.pre-T0138.*.bak | tail -1 | cut -d= -f2-); docker run --rm --network container:ai-qadam-test-db-1 -e PGPASSWORD="$OLD_PG_PASSWORD" postgres:16-alpine psql -h 172.18.0.1 -U aiqadam -d postgres -tAc 'SELECT 1' 2>&1 | tail -1` — running a throwaway `psql` client container attached to the same network namespace as another already-bridge-connected container (or, if simpler and equally valid, `docker exec` into `aiqadam-qa-api-1` itself if it has a `psql` client available, connecting to `172.18.0.1:3112`) ensures the connection genuinely arrives from a bridge address, not loopback. **If `postgres:16-alpine` is not already present on-host, this is a new image pull — acceptable for a one-shot verification container, no persistent footprint (`--rm`).**
   - Verification: output is a Postgres authentication-failure line (e.g. `password authentication failed for user "aiqadam"`), never `1`. If it returns `1`, STOP — `BLOCKED`, do not mark rotation complete.

3.2. **New password confirmed working, same corrected method.**
   - Command: `docker run --rm --network container:ai-qadam-test-db-1 -e PGPASSWORD="$NEW_PG_PASSWORD" postgres:16-alpine psql -h 172.18.0.1 -U aiqadam -d postgres -tAc 'SELECT 1'`
   - Verification: `1`.

3.3. **Each real consumer's own actual DB-backed health endpoint** — expanded to cover all four consumers, Authentik held to the higher bar per the step-specific instruction.
   - `api`: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` → `200`.
   - `directus`: `docker exec aiqadam-qa-directus-1 printenv PORT` then `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/server/ping` → confirms DB-backed health, not just container "Up".
   - `authentik-server`/`authentik-worker`: use whichever check Phase 0.10 determined is genuinely DB-backed — preferentially `curl -s -o /dev/null -w '%{http_code}\n' https://auth.qa.aiqadam.org/-/health/ready/` → expect `200`; if 0.10 found this path unavailable/inconclusive, use the `ak shell` ORM-query fallback (`docker exec aiqadam-qa-authentik-server-1 ak shell -c "from authentik.core.models import User; print(User.objects.count())"` → a non-error integer output) as the substantive proof. **A bare `docker ps` "Up" status or a raw TCP-connect check on its own does NOT satisfy this verification point** — the step-specific instruction is explicit that Authentik's health check must confirm a real DB-backed operation, given the platform-wide sign-in blast radius if its DB reconnect silently fails.
   - Command (any additional consumer Phase 0/2.5 surfaced): whatever health/connectivity check is appropriate, defined at execution time from Phase 0's findings and recorded with its actual command and result.

3.4. **Local trust-auth path re-confirmed still passwordless** (sanity check — `ALTER ROLE ... PASSWORD` doesn't touch `pg_hba.conf`, but confirming costs nothing).
   - Command: `docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc 'SELECT current_user;'` (no `PGPASSWORD` set) → `aiqadam`.

3.5. **Clean up in-session shell variables**: `unset NEW_PG_PASSWORD OLD_PG_PASSWORD PGPASSWORD`.

### Rollback

1. **If Phase 2.2 (`ALTER ROLE`) fails**: nothing has changed yet at the file level — no rollback needed beyond investigating the failure. Emit `FAIL` with the error text (no password in Postgres error output).
2. **If Phase 2.2 succeeds but a later sub-step in 2.3–2.6 fails**: the role-level password is ALREADY the new value — do not attempt to revert `ALTER ROLE`. Retry only the failed file-update or restart step using `$NEW_PG_PASSWORD` (still in-scope in the same session) — converge every file/container to the new value, do not revert.
3. **If Phase 2.6 (consumer restart) fails or a container comes up unhealthy**: re-run the same `docker compose up -d --no-deps <service...>` once. If still unhealthy, this is a distinct incident from the credential rotation (the new password is already correctly applied everywhere) — escalate to `BLOCKED` as a service-health issue, do not revert the password. **If specifically Authentik fails to come up healthy post-recreate**, treat this as higher-severity than an `api`/`directus` failure per the step-specific instruction (platform-wide sign-in impact) — still do not revert the password (the old value is being rotated away regardless), but flag immediately and do not silently continue to declare the overall rotation successful while Authentik remains degraded.
4. **If Phase 3.1 finds the OLD password still works**: STOP, `BLOCKED` — indicates `ALTER ROLE` did not commit, was run against the wrong role/database, or (new consideration this revision) the verification method still isn't actually exercising password auth (re-check the connecting address is genuinely not `127.0.0.1`/`::1`) — requires investigation, not a scripted retry.
5. **If Phase 3.3's health checks fail after all file/container updates succeeded**: `.env` backups (1.1) allow reverting file contents, but the role-level password is already rotated — reverting a consumer's `.env` to the OLD value would make it MORE broken. Fix-forward: re-verify the specific `.env` key/value the unhealthy consumer reads (config/naming-mismatch bug, not a rollback candidate) and correct it to `$NEW_PG_PASSWORD`, re-running only that consumer's restart. If unclear, `BLOCKED`.
6. **General**: no step deletes data. Both `.env` backups and Postgres's own role record make every step reversible except "old password confirmed dead" (3.1) — once revoked, restoring the exact prior password is not a supported rollback path (defeats the rotation's purpose).

### Verification (for step 07)

- **On-host:**
  - `/var/www/ai-qadam-test/.env.pre-T0138.<timestamp>.bak` and `/opt/apps/aiqadam-qa/deploy/.env.pre-T0138.<timestamp>.bak` both exist.
  - `/var/www/ai-qadam-test/.env` contains exactly 1 match for `^POSTGRES_PASSWORD=`; `/opt/apps/aiqadam-qa/deploy/.env` contains exactly 1 match for `^AIQADAM_QA_POSTGRES_PASSWORD=` (count-only).
  - All four consumer containers (`aiqadam-qa-api-1`, `aiqadam-qa-directus-1`, `aiqadam-qa-authentik-server-1`, `aiqadam-qa-authentik-worker-1`) show a recent `Up` status consistent with a just-now recreate.
  - `ai-qadam-test-db-1` shows NO restart/recreate (its `Up` timestamp predates this run).
  - Executor's recorded results for Phase 3.1 (old password → auth-failure line, connecting via `172.18.0.1` not `127.0.0.1`) and Phase 3.2 (new password → `1`, same corrected method) are present in step-06's handoff, with the connecting address explicitly logged so the validator can confirm the test wasn't silently hitting a trust-rated path again.
  - Phase 0.4a's live compose-block read for both `authentik-server` and `authentik-worker` is present and confirms `AIQADAM_QA_POSTGRES_PASSWORD` as the credential variable (or the plan halted to `BLOCKED` if not).
  - Phase 0.6a's `DATABASE_URL` disposition (unreferenced/legacy vs. live-and-updated) is explicitly recorded, not left implicit.
  - Every command in step-06's handoff matches one of this plan's exact command templates (no ad-hoc improvised diagnostics).
- **External:**
  - `curl https://qa.aiqadam.org/health` → `200`.
  - Directus's `/server/ping` → `200`.
  - Authentik's `/-/health/ready/` → `200` (or the `ak shell` ORM-query fallback returns a valid non-error count) — **explicitly not satisfied by a bare TCP-open or static-asset 200**, per the step-specific instruction's higher bar for this service.
  - Any additional consumer health check Phase 0 surfaced is recorded with its actual command and result.

### Resources used

- Secrets (by name): `POSTGRES_PASSWORD` (`/var/www/ai-qadam-test/.env`), `AIQADAM_QA_POSTGRES_PASSWORD` (`/opt/apps/aiqadam-qa/deploy/.env`) — the same underlying Postgres role password (`aiqadam`'s), shared by 4 consumer containers (`api`, `directus`, `authentik-server`, `authentik-worker`). `DATABASE_URL` (`/opt/apps/aiqadam-qa/deploy/.env`) added to this list conditionally, pending Phase 0.6a's finding. Recorded in `landscape/secrets-inventory.md` as one shared credential (rotation date only, no values).
- Files modified on host:
  - `/var/www/ai-qadam-test/.env` (in place, backed up first)
  - `/opt/apps/aiqadam-qa/deploy/.env` (in place, backed up first)
  - New files: `/var/www/ai-qadam-test/.env.pre-T0138.<timestamp>.bak`, `/opt/apps/aiqadam-qa/deploy/.env.pre-T0138.<timestamp>.bak`
- Files modified in this repo (landscape/): `landscape/secrets-inventory.md` (new row(s) for the `aiqadam` Postgres role password, now explicitly noting all 4 consumer containers and the `authentik`/`directus`/`aiqadam_qa` database scope — applied at step 08). `landscape/hosts/pro-data-tech-qa.md` Change log should record Phase 0's resolved facts: the `authentik` database and its 2 consumer containers as real, password-authenticated consumers of `AIQADAM_QA_POSTGRES_PASSWORD`; the corrected trust/password auth-boundary (bridge gateway `172.18.0.1`, not `127.0.0.1`, is the real client address and is password-required); and `DATABASE_URL`'s resolved disposition — so this reconciliation is not re-derived by a future task.
- External APIs called: none.

### Estimated impact

- **Downtime:** none expected for the Postgres role-level change itself; **seconds** for each of the 4 consumer recreates (`--no-deps`).
- **Affected services:** `ai-qadam-test-db-1` (credential change only, no restart), `aiqadam-qa-api-1`, `aiqadam-qa-directus-1`, `aiqadam-qa-authentik-server-1`, `aiqadam-qa-authentik-worker-1` (all recreated). Any additional consumer Phase 0 surfaces (unknown at design time).
- **Reversibility:** partial. `.env` files restorable via backup; the Postgres role password is one-way once rotated (matches `estimated_reversibility: partial`) — consistent with `NEEDS_APPROVAL` regardless.

## Issues / risks

- **This plan emits `NEEDS_APPROVAL` unconditionally**, per the task file's Notes (stated twice), same as attempt 1.
- **Blast radius is now confirmed larger than attempt 1's plan assumed**: 4 real consumer containers across 3 application databases plus Authentik's own identity store, not the 1–2 attempt 1 originally scoped. Authentik is a materially higher-severity dependency than `api`/`directus` alone — a silent DB-reconnect failure there is a platform-wide sign-in/SSO outage, not just one service degrading. This is why Phase 3.3 holds Authentik to a DB-backed-operation bar rather than accepting a bare 200/TCP-open, and why the rollback section (item 3) calls out Authentik failures as higher-severity than the other consumers'.
- **Phase 3.1/3.2's verification method changed materially from attempt 1** — this is a correctness fix, not a stylistic one. Attempt 1's `-h 127.0.0.1` tests would have silently passed regardless of password value (trust-rated address), which means if attempt 1 had been executed to completion without this correction, its own "proof" that the old password was dead and the new one worked would have been meaningless. This revision's `docker run --rm --network container:ai-qadam-test-db-1 ... -h 172.18.0.1` approach is the mechanism proposed to fix this; if the executor finds this specific Docker networking approach impractical on-host (e.g. `--network container:` mode behaves unexpectedly), an acceptable alternative is `docker exec` into any already-bridge-connected container (e.g. `aiqadam-qa-api-1`, if it has a `psql` client binary) rather than spinning up a throwaway image — but the connecting address must be verified as non-loopback either way; if neither approach is achievable, `BLOCKED` rather than silently falling back to the loopback test that this revision is explicitly correcting.
- **Phase 0.4a/0.6a are new discovery sub-steps not yet executed** — this plan's Phase 2 scope (single shared-variable update, 4-container restart) is written with high confidence based on the Orchestrator's direct investigation, but per this agent's role rules, Phase 0 must still confirm it live before Phase 2 is treated as unconditionally correct. If 0.4a contradicts the expected `AIQADAM_QA_POSTGRES_PASSWORD` variable name for Authentik, `BLOCKED`.
- **`DATABASE_URL`'s disposition remains genuinely unresolved** at plan-design time — Phase 0.6a is designed to close this before Phase 2.5 acts, with an explicit `BLOCKED` branch if it cannot be resolved from compose alone (e.g. consumed by something outside `docker-compose.qa.yml`).
- **Unknown/undocumented consumer risk** (same as attempt 1, now also covering `authentik`/`directus` databases in addition to `aiqadam_test`/`aiqadam_qa`): if Phase 0 surfaces a connection this plan did not anticipate, Phase 2.6 requires pausing rather than silently restarting/ignoring it.
- **Output hygiene remains the highest-severity operational risk**, given this host/credential family is the one already exposed once (T-0137, then again on a different credential during T-0136's investigation). This revision removes the one place (0.6a) that previously asked the executor to judge whether a `-B/-A`+`-v` combination was "safe this time" — that judgment call is exactly the failure mode from before, so it's gone: no step in this plan combines `-B`/`-A` with `-v`, on any file, full stop. Every command uses `-oE` key-only capture, count-only, digest-only, or auth-status-only verification exclusively; mandates one continuous SSH session for the entire generate→apply→verify sequence. Any deviation from this plan's exact command templates must halt the executor into `BLOCKED`.
- **`landscape/secrets-inventory.md` has zero existing rows for this credential** — step 08 creates first-time entries.

## Open questions (optional)

None blocking approval. The two items that could still route mid-execution to `BLOCKED` (0.4a finding a different Authentik credential variable than expected; 0.6a being unable to resolve `DATABASE_URL`'s consumer from compose alone) are explicit branches above, not open questions requiring pre-approval resolution — consistent with attempt 1's decision-plan structure.
