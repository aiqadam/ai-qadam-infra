---
run_id: 2026-08-20-rotate-qa-postgres-password-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-20T11:56:55Z
task_id: T-0138-rotate-qa-postgres-password
inputs_read:
  - runs/2026-08-20-rotate-qa-postgres-password-001/step-01-task-reader.md
  - runs/2026-08-20-rotate-qa-postgres-password-001/step-02-landscape-reader.md
  - runs/2026-08-20-rotate-qa-postgres-password-001/step-03-task-validator.md
  - tasks/T-0138-rotate-qa-postgres-password.md
  - workflows/infrastructure.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-04-solution-designer.md
  - .claude/agents/executor-infra.md
  - .claude/agents/solution-designer.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: >-
  Orchestrator must halt and present this plan for user approval (do NOT
  auto-advance to executor) — secret rotation, unconditional
  NEEDS_APPROVAL per the task file's own Notes section (no
  shared/approval-protocol.md or shared/verdicts.md file actually exists
  in this checkout despite being referenced by name in several role
  files — treating the task file's explicit, twice-stated instruction
  and this agent's own role-file verdict rules as the controlling
  source). Once approved, route to step 06 executor-infra per
  workflows/infrastructure.md's step binding. Phase 0 is entirely
  read-only discovery and gates every later phase's shape — the exact
  consumer set, the credential-name relationship, and the trust-auth
  scope are NOT assumed anywhere past Phase 0; every later phase branches
  on Phase 0's live findings. Executor must halt into BLOCKED (return to
  solution-designer) on any Phase 0 finding that contradicts this plan's
  working hypotheses, rather than improvising. Same output-hygiene
  discipline as T-0137: no grep -B/-A + -v, single continuous SSH session
  per credential's generate-apply-verify sequence, count/status/digest-
  only verification, explicit BLOCKED on unplanned diagnostic need.
retry_of: none
---

## Summary

Rotate the `aiqadam` Postgres cluster-superuser password on `ai-qadam-test-db-1` (`pro-data-tech-qa`) via `ALTER ROLE aiqadam WITH PASSWORD '...'`, after first empirically enumerating every real TCP+password consumer (Phase 0 discovery — resolving the `directus`-database question, the `POSTGRES_PASSWORD` vs. `AIQADAM_QA_POSTGRES_PASSWORD` naming relationship, and which containers actually need the password value at all given confirmed local trust auth), then updating every enumerated consumer's own env-var reference and restarting only the containers that need it, ending with the old password rejected, the new password working end-to-end (including each service's real health endpoint), and `landscape/secrets-inventory.md` recording only the rotation date. **This plan requires human approval before execution — unconditional per the task file's Notes (secret rotation), regardless of the user's standing "keep going" instruction.**

## Details

### Design principle: minimize password handling via trust auth

Per the step-specific instruction and today's already-confirmed fact (local Unix-socket trust auth covers `aiqadam` with **zero password** from inside the container via `docker exec ... psql -U aiqadam`), every verification step in this plan that only needs to confirm *database-level* state (does the role exist, what is its password's age, did `ALTER ROLE` succeed, do the target databases exist) uses `docker exec ai-qadam-test-db-1 psql -U aiqadam ...` — no password, nothing to redact, nothing to leak. The password value is handled ONLY in the two places it structurally cannot be avoided: (a) the `ALTER ROLE ... WITH PASSWORD` statement itself (Phase 2), and (b) confirming each real TCP consumer's own connection actually succeeds/fails with old/new values (Phase 0.4, Phase 3) — because that is inherently a network-auth test, not a local-socket one. Every other step is trust-auth-only and handles no secret at all.

### What Phase 0 must resolve before Phase 2 can be written concretely

Per step 02/03's `BLOCKED`/routing findings, three facts are unconfirmed by committed landscape and must be established live, read-only, before rotation:

1. Does a `directus` **database** exist inside `ai-qadam-test-db-1`, or does Directus use a different backend entirely?
2. Are `POSTGRES_PASSWORD` (`/var/www/ai-qadam-test/.env`) and `AIQADAM_QA_POSTGRES_PASSWORD` (`/opt/apps/aiqadam-qa/deploy/.env`) the same secret (same role, so if both are meant to authenticate as `aiqadam`, they should hold the same string right now) — confirmed via digest comparison, values never printed.
3. Which containers actually connect via TCP+password (and therefore depend on the password value at all) versus which never touch Postgres or reach it only via local trust auth.

This plan is written as a **decision plan**, not a linear script: Phase 2's consumer-update list and Phase 3's verification list are both populated from Phase 0's findings, not assumed in advance. Working hypotheses are stated per step so the approver can see what's expected, but the executor must follow Phase 0's live result, not the hypothesis, wherever they diverge — and must `BLOCKED` back to solution-designer on any divergence not already covered by an explicit branch below.

### Plan

#### Phase 0 — Discovery (read-only; no state changes; minimal password handling)

0.1. **Enumerate all databases in the cluster** (trust-auth, no password).
   - Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc \"SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;\""`
   - Verification: resolves whether `directus` is really a database in this cluster (settling step 02's flagged gap) alongside the two landscape-confirmed databases (`aiqadam_test`, `aiqadam_qa`). Record the exact list returned.

0.2. **Enumerate all roles in the cluster** (trust-auth, no password) — confirms `aiqadam` is the only superuser role (per T-0136's prior finding) and whether any other role exists that might also need attention.
   - Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc \"SELECT rolname, rolsuper FROM pg_roles ORDER BY rolname;\""`
   - Verification: role list recorded; confirms no second role/password is silently in scope.

0.3. **Read `pg_hba.conf`** to settle the trust-auth boundary precisely (which auth methods apply to which connection type/source).
   - Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 cat /var/lib/postgresql/data/pg_hba.conf | grep -vE '^\s*#|^\s*$'"`
   - No secret content in this file (it's an auth-method map, not credentials) — safe to read in full.
   - Verification: confirms local/Unix-socket entries use `trust` (as already observed live today) and, critically, what method applies to `host`/TCP entries (expected: `scram-sha-256` or `md5`, i.e. password-required) — this is the empirical basis for classifying every consumer in 0.4.

0.4. **Enumerate which containers actually hold a live TCP connection to Postgres right now**, and for each, whether it authenticates via password or arrives over the Unix socket (containers connecting via `docker exec` from inside `ai-qadam-test-db-1` itself don't count — only genuinely separate containers/processes).
   - Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc \"SELECT datname, usename, client_addr, backend_type FROM pg_stat_activity WHERE backend_type = 'client backend' ORDER BY datname;\""`
   - `client_addr` empty/null = Unix socket (no password used for that session); a populated IP (expected `127.0.0.1` given the `127.0.0.1:3112→5432` binding) = TCP (password-authenticated, given 0.3's expected `host` entries).
   - Verification: produces the definitive "who actually uses the password" list — this result, not the task file's a-priori guesses, drives Phase 2's consumer-update scope. Since this is a point-in-time snapshot, cross-check against 0.5/0.6's static config enumeration (a consumer might not have an open connection at exactly this moment but still holds a password reference it will use on its next reconnect).

0.5. **Read the Postgres-related key names in `/opt/apps/aiqadam-qa/deploy/.env`** (names only, never values) to close the gap step 02 flagged (app-registry never enumerated these keys).
   - Command: `ssh pro-data-tech-qa "grep -oE '^(POSTGRES|PG|DATABASE|DB)[A-Z_]*=' /opt/apps/aiqadam-qa/deploy/.env | sort -u"`
   - `-oE` structurally cannot print anything past the matched `KEY=` token — same discipline as T-0137, never combine with `-B/-A` + `-v`.
   - Verification: confirms exactly which key(s) `aiqadam-qa-api-1` and (if applicable) `aiqadam-qa-directus-1` read for their Postgres connection, and whether `AIQADAM_QA_POSTGRES_PASSWORD` is the only one or there are siblings (e.g. a `DATABASE_URL` embedding the same value).

0.6. **Read the `directus` service's DB-connection env block in `docker-compose.qa.yml`** to confirm which variable name and which database Directus is configured against.
   - Command: `ssh pro-data-tech-qa "grep -A 20 '^\s*directus:' /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml | grep -iE 'DB_|DATABASE|POSTGRES'"`
   - This is a config-structure read (variable names and `${VAR}` interpolation syntax), not a value dump — compose files reference secrets by `${VAR_NAME}`, they don't embed literal values. Safe under the same discipline as T-0137's Phase 0.2/0.7 compose-file reads.
   - Verification: confirms/denies the task's step-specific premise that Directus uses `AIQADAM_QA_POSTGRES_PASSWORD` (the same variable as `api`) rather than a distinct key, and confirms which database name Directus's `DB_DATABASE` (or equivalent) points at — cross-checked against 0.1's live database list.

0.7. **Confirm whether `POSTGRES_PASSWORD` and `AIQADAM_QA_POSTGRES_PASSWORD` currently hold the same value**, via digest comparison — values never printed, never compared as plaintext, never leave the remote shell.
   - Command (single SSH session): `ssh pro-data-tech-qa "sha256sum <(grep '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env | cut -d= -f2-) <(grep '^AIQADAM_QA_POSTGRES_PASSWORD=' /opt/apps/aiqadam-qa/deploy/.env | cut -d= -f2-)"`
   - Verification: two digests printed side by side (no values). Equal digests → same secret under two names (expected, since a Postgres role has exactly one password — if both vars are meant to authenticate as `aiqadam`, they must currently match, or one of them is already stale/non-functional). Unequal digests → one of the two is NOT actually the live, functional `aiqadam` password right now — a distinct, separately-noteworthy finding requiring its own live-auth check (0.8) before Phase 2 can assume which one is "the" current password.

0.8. **If 0.7 finds unequal digests**, determine empirically which of the two values (if either) actually authenticates against Postgres right now — do not guess.
   - Command (same session, only run if 0.7's digests differ): `ssh pro-data-tech-qa "P=\$(grep '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env | cut -d= -f2-); PGPASSWORD=\$P docker exec -e PGPASSWORD ai-qadam-test-db-1 psql -h 127.0.0.1 -U aiqadam -d postgres -tAc 'SELECT 1' 2>&1 | tail -1; unset P PGPASSWORD"` then the equivalent substituting `AIQADAM_QA_POSTGRES_PASSWORD`. Output is `1` (success, no error text) or a Postgres auth-failure line (which does not contain the password) — never the value itself.
   - Verification: identifies which var (one, both, or neither) is the live TCP-auth-functional password today. This directly informs Phase 2's "what is the CURRENT password we're rotating away from" question, which `ALTER ROLE` does not require knowing (it sets unconditionally) but which the "old password confirmed dead" verification in Phase 3 does require targeting correctly.
   - **Branch:** if NEITHER value authenticates, this means TCP+password auth to `aiqadam` is already broken independent of this rotation — `BLOCKED`, return to solution-designer; do not proceed to write a rotation plan on top of an already-broken baseline without the user seeing this first.

0.9. **Confirm Postgres bootstrap-env-var re-read behavior empirically** for this exact image, to correctly scope whether editing `/var/www/ai-qadam-test/.env`'s `POSTGRES_PASSWORD` line alone has any live effect without a restart, or is purely a hygiene/consistency edit.
   - Command: `ssh pro-data-tech-qa "docker inspect ai-qadam-test-db-1 --format '{{.Created}}'"` compared against `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc \"SELECT pg_postmaster_start_time();\""` — if postmaster start time is later than container creation time by more than a routine restart gap, or if research on the `pgvector/pgvector:pg16` image (based on the standard `postgres` Docker entrypoint) confirms `POSTGRES_PASSWORD` is read only by `docker-entrypoint.sh`'s first-run initdb path — record the definitive answer.
   - Verification: a stated conclusion in the executor's handoff: editing the bootstrap `.env` file does NOT by itself change the running role's password (only `ALTER ROLE` does) — it only matters for what a **future fresh volume init** would bootstrap with. This confirms Phase 2 does not need to restart/recreate `ai-qadam-test-db-1` itself for the password change to take effect.

#### Phase 1 — Backup (before any destructive change)

1.1. **Back up both host `.env` files** before editing either.
   - Command: `ssh pro-data-tech-qa "sudo cp -p /var/www/ai-qadam-test/.env /var/www/ai-qadam-test/.env.pre-T0138.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo chmod 600 /var/www/ai-qadam-test/.env.pre-T0138.*.bak"`
   - Command: `ssh pro-data-tech-qa "sudo cp -p /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.*.bak && sudo chown tvolodi:aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.*.bak"`
   - These backups contain the OLD secret values by design. Never `cat`'d, never `grep`'d without `-oE`, never displayed.
   - Verification (presence only): `ssh pro-data-tech-qa "ls /var/www/ai-qadam-test/.env.pre-T0138.*.bak /opt/apps/aiqadam-qa/deploy/.env.pre-T0138.*.bak >/dev/null 2>&1 && echo BACKUPS_EXIST"`

#### Phase 2 — Rotate at the Postgres role level, then update every real consumer

2.1. **Generate the new password on-host**, one continuous SSH session covering generation through every apply in this phase (never round-tripped to the workstation, never written to disk outside the intended `.env` targets, never logged).
   - Command (opens the session Phase 2.2 onward continues inside): `ssh pro-data-tech-qa "NEW_PG_PASSWORD=\$(openssl rand -base64 24); echo \$NEW_PG_PASSWORD | wc -c"` — prints only a character count (non-secret sanity check).

2.2. **Apply the new password at the Postgres role level.**
   - Command (same session): `docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -c "ALTER ROLE aiqadam WITH PASSWORD '$NEW_PG_PASSWORD';"`
   - This is naturally idempotent (safe to re-run with the same or a corrected value) and is a trust-auth local connection (no old password needed to run it).
   - Verification: command returns `ALTER ROLE` (success text, no password echoed back by Postgres).

2.3. **Update `/var/www/ai-qadam-test/.env`'s `POSTGRES_PASSWORD` line** (same session).
   - Command: `sudo sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$NEW_PG_PASSWORD|" /var/www/ai-qadam-test/.env`
   - Verification (count only): `grep -c '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env` → `1`.

2.4. **Update `/opt/apps/aiqadam-qa/deploy/.env`'s `AIQADAM_QA_POSTGRES_PASSWORD` line — contingent on Phase 0.7/0.5's findings:**
   - **If Phase 0.7 found the two vars already held the same value** (expected case): update this line to the same `$NEW_PG_PASSWORD`, keeping both files consistent with the one role password.
   - **If Phase 0.7 found them different, and Phase 0.8 identified `AIQADAM_QA_POSTGRES_PASSWORD` as the one actually live/functional** (i.e. `POSTGRES_PASSWORD` was already stale before this rotation): still set both to `$NEW_PG_PASSWORD` now — the rotation makes them consistent going forward regardless of which was stale before, since there is only one real role password after 2.2.
   - Command: `sudo sed -i "s|^AIQADAM_QA_POSTGRES_PASSWORD=.*|AIQADAM_QA_POSTGRES_PASSWORD=$NEW_PG_PASSWORD|" /opt/apps/aiqadam-qa/deploy/.env`
   - Verification (count only): `grep -c '^AIQADAM_QA_POSTGRES_PASSWORD=' /opt/apps/aiqadam-qa/deploy/.env` → `1`.

2.5. **Update any additional Postgres-related key found by Phase 0.5/0.6** (e.g. a distinct Directus `DB_PASSWORD`/`DATABASE_URL` key, if 0.6 finds Directus does NOT reuse `AIQADAM_QA_POSTGRES_PASSWORD`) — same file, same `sed` pattern, same session. **If Phase 0.6 confirms Directus reuses `AIQADAM_QA_POSTGRES_PASSWORD` via the SAME variable** (per the step-specific input's working hypothesis), this step is a no-op — 2.4 already covers it, do not double-apply.
   - Verification (count only, same pattern as above) for whichever additional key(s) 0.5/0.6 identified.

2.6. **Restart/recreate only the containers Phase 0.4/0.6 identified as real TCP+password consumers of this credential.** Do NOT restart `ai-qadam-test-db-1` itself (Phase 0.9 establishes the role-level `ALTER ROLE` already took effect live; the bootstrap `.env` edit in 2.3 only matters for a hypothetical future fresh-volume init, not the running container).
   - Command (per identified consumer, `--no-deps` to avoid unintended cascading restarts): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d --no-deps api"` — and the same for `directus` if Phase 0.4/0.6 confirms it is a real TCP consumer using this credential.
   - **If Phase 0.1 finds NO `directus` database exists in this cluster at all** (Directus uses a different backend): Directus is not a consumer of this credential; skip its recreate entirely and record this explicitly as a correction to the task's premise.
   - **If Phase 0.4's live snapshot shows a legacy/manual consumer of `aiqadam_test`** beyond the two known app containers (e.g. an ad-hoc cron or script identified by `usename`/`client_addr` in 0.4's output that isn't `aiqadam-qa-api-1` or `aiqadam-qa-directus-1`): this is exactly the "err on the side of over-enumerating" case the task file warns about — do not proceed to restart-and-declare-done; add a note under Issues/risks and confirm with the user whether that consumer is addressable within this plan's scope or needs a follow-up task, since this plan cannot enumerate an unknown, undocumented process in advance.
   - Verification: `docker ps --filter name=<container> --format '{{.Status}}'` shows a recent `Up` status for each recreated container.

2.7. **Clean up in-session shell variables** as the final action of Phase 2, before moving to Phase 3's verification (which reuses the variable within the SAME session, so this is done only once verification is complete — see Phase 3.5).

#### Phase 3 — Verification

3.1. **Old `POSTGRES_PASSWORD`/`AIQADAM_QA_POSTGRES_PASSWORD` value confirmed dead** for TCP auth (same session, reusing whichever old value(s) Phase 0.8 confirmed were live before rotation — if both were live per 0.7's equal-digest case, one check suffices since it's the same role/password; if 0.8 found them different, check whichever was actually functional).
   - Command: `OLD_PG_PASSWORD=$(grep '^POSTGRES_PASSWORD=' /var/www/ai-qadam-test/.env.pre-T0138.*.bak | tail -1 | cut -d= -f2-); PGPASSWORD=$OLD_PG_PASSWORD docker exec -e PGPASSWORD ai-qadam-test-db-1 psql -h 127.0.0.1 -U aiqadam -d postgres -tAc 'SELECT 1' 2>&1 | tail -1`
   - Verification: output is a Postgres authentication-failure line (e.g. `password authentication failed for user "aiqadam"`), never `1`. If it returns `1`, STOP — do not mark rotation complete, emit `BLOCKED` with the observed result; do not improvise further.

3.2. **New password confirmed working via direct TCP+password connection** (the minimum-viable proof the role-level change is live).
   - Command: `PGPASSWORD=$NEW_PG_PASSWORD docker exec -e PGPASSWORD ai-qadam-test-db-1 psql -h 127.0.0.1 -U aiqadam -d postgres -tAc 'SELECT 1'`
   - Verification: `1`.

3.3. **Each real consumer's own actual health endpoint**, not just a bare `psql` test — per the task's explicit "not just a bare psql connection test" requirement.
   - Command: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` → `200` (confirms `aiqadam-qa-api-1`'s DB connection pool reconnected against `aiqadam_qa`).
   - Command (if Directus is confirmed a real consumer by Phase 0): `docker exec aiqadam-qa-directus-1 printenv PORT` then `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/server/ping` → confirms Directus's own DB-backed health, not just container "Up" status. If Phase 0 found Directus is NOT a Postgres consumer of this credential (different backend, or read-only via trust auth somehow — unlikely for a networked service but not to be assumed), substitute the appropriate confirmation per what Phase 0 actually found.
   - Command (legacy `aiqadam_test` consumer, if Phase 0.4 identified one beyond the two app containers): whatever health/connectivity check is appropriate to that specific consumer — to be defined at execution time from Phase 0's findings, since none is currently known to exist.

3.4. **Local trust-auth path re-confirmed still passwordless** (sanity check that the rotation did not inadvertently affect `pg_hba.conf` or local-socket behavior — it shouldn't, since `ALTER ROLE ... PASSWORD` doesn't touch `pg_hba.conf`, but confirming costs nothing and closes the loop on the "exploit trust auth" design goal).
   - Command: `docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -tAc 'SELECT current_user;'` (no `PGPASSWORD` set) → `aiqadam`.
   - Verification: succeeds with zero password needed, confirming local Unix-socket verification paths used throughout Phase 0/2 remain valid for any future rotation of this same credential.

3.5. **Clean up in-session shell variables**: `unset NEW_PG_PASSWORD OLD_PG_PASSWORD PGPASSWORD`.

### Rollback

1. **If Phase 2.2 (`ALTER ROLE`) fails**: nothing has changed yet at the file level (2.3/2.4 haven't run) — no rollback needed beyond investigating the failure. Emit `FAIL` with the error text (Postgres error output does not contain the password).
2. **If Phase 2.2 succeeds but a later sub-step in 2.3–2.6 fails**: the role-level password is ALREADY the new value — do not attempt to revert `ALTER ROLE` back to the old value (the old value should be treated as compromised/rotating-away regardless of file-sync failures downstream). Instead, retry only the failed file-update or restart step using `$NEW_PG_PASSWORD` (still in-scope in the same session) — the goal is to finish converging every file/container to the new value, not to revert.
3. **If Phase 2.6 (consumer restart) fails or the container comes up unhealthy**: re-run the same `docker compose up -d --no-deps <service>` once. If still unhealthy, this is a distinct incident from the credential rotation itself (the new password is already correctly applied and in every `.env` file) — escalate to `BLOCKED` as a service-health issue, do not revert the password.
4. **If Phase 3.1 finds the OLD password still works** (rotation did not actually take effect): STOP, `BLOCKED`, do not proceed to declare success; this indicates `ALTER ROLE` did not commit or was run against the wrong role/database — requires investigation, not a scripted retry.
5. **If Phase 3.3's health checks fail after all file/container updates succeeded**: the `.env` backups (1.1) allow reverting file contents, but note the role-level password is already rotated — reverting a consumer's `.env` file to the OLD value at this point would make that consumer MORE broken (old value + already-rotated role = guaranteed auth failure), not less. The correct fix-forward action is to re-verify the specific `.env` key/value the unhealthy consumer is reading (a config/naming-mismatch bug, not a rollback candidate) and correct it to `$NEW_PG_PASSWORD`, re-running only that consumer's restart. If the cause is unclear, `BLOCKED`, do not guess further live.
6. **General**: no step deletes data. Both `.env` backups (1.1) and Postgres's own role record (only the password field changed) make every step reversible except "old password confirmed dead" (3.1) — once revoked, Postgres does not support restoring the exact prior password value (a fresh `ALTER ROLE` would be needed with the old value re-typed from the backup file, which defeats the rotation's purpose and is explicitly not a supported rollback path here).

### Verification (for step 07)

- **On-host:**
  - `/var/www/ai-qadam-test/.env.pre-T0138.<timestamp>.bak` and `/opt/apps/aiqadam-qa/deploy/.env.pre-T0138.<timestamp>.bak` both exist.
  - `/var/www/ai-qadam-test/.env` contains exactly 1 match for `^POSTGRES_PASSWORD=`; `/opt/apps/aiqadam-qa/deploy/.env` contains exactly 1 match for `^AIQADAM_QA_POSTGRES_PASSWORD=` (count-only, no value shown).
  - Every container Phase 0 identified as a real consumer shows a recent `Up` status consistent with a just-now recreate (`aiqadam-qa-api-1` at minimum; `aiqadam-qa-directus-1` if Phase 0 confirms it's a consumer).
  - `ai-qadam-test-db-1` itself shows NO restart/recreate (its own `Up` timestamp predates this run) — confirms Phase 0.9's finding was correctly acted on (no unnecessary Postgres-container restart).
  - Executor's recorded results for Phase 3.1 (old password → auth-failure line, not `1`) and Phase 3.2 (new password → `1`) are present in step-06's handoff.
  - Every command in step-06's handoff matches one of this plan's exact command templates (no ad-hoc improvised diagnostics) — validator spot-checks by comparing logged commands against this plan's text.
- **External:**
  - `curl https://qa.aiqadam.org/health` → `200`.
  - Directus's `/server/ping` (or equivalent, per Phase 0's findings on whether/how Directus is a consumer) → `200`.
  - Any additional consumer health check Phase 0 surfaced and this plan's Phase 3.3 had to define at execution time is recorded with its actual command and result, not just "passed."

### Resources used

- Secrets (by name): `POSTGRES_PASSWORD` (`/var/www/ai-qadam-test/.env` on `pro-data-tech-qa`), `AIQADAM_QA_POSTGRES_PASSWORD` (`/opt/apps/aiqadam-qa/deploy/.env` on `pro-data-tech-qa`) — pending Phase 0.7's confirmation, both names likely refer to the same underlying Postgres role password (`aiqadam`'s), to be recorded in `landscape/secrets-inventory.md` as such (rotation date only, no values). Any additional key Phase 0.5/0.6 surfaces is added to this list at execution time before step 08 acts on it.
- Files modified on host:
  - `/var/www/ai-qadam-test/.env` (in place, backed up first)
  - `/opt/apps/aiqadam-qa/deploy/.env` (in place, backed up first)
  - New files: `/var/www/ai-qadam-test/.env.pre-T0138.<timestamp>.bak`, `/opt/apps/aiqadam-qa/deploy/.env.pre-T0138.<timestamp>.bak`
- Files modified in this repo (landscape/): `landscape/secrets-inventory.md` (new row(s) for the `aiqadam` Postgres role password — first entry for this credential, no prior baseline to compare against — applied at step 08). `landscape/hosts/pro-data-tech-qa.md` Change log should also record Phase 0's resolved facts (directus-database existence/non-existence, the credential-name relationship, and the trust-auth boundary) so this reconciliation is not re-derived by a future task — same pattern as T-0137's landscape update.
- External APIs called: none (Postgres role change is entirely on-host via `docker exec`; health checks are loopback/local HTTPS, not third-party).

### Estimated impact

- **Downtime:** none expected for the Postgres role-level change itself (live `ALTER ROLE`, no restart of `ai-qadam-test-db-1`); **seconds** for each real consumer's mandatory recreate (`aiqadam-qa-api-1` at minimum, `--no-deps`, matching T-0125/T-0137 precedent), possibly `aiqadam-qa-directus-1` pending Phase 0's findings.
- **Affected services:** `ai-qadam-test-db-1` (credential change only, no restart), `aiqadam-qa-api-1` (recreate), `aiqadam-qa-directus-1` (recreate, conditional on Phase 0 confirming it's a real consumer), any additional consumer Phase 0.4 surfaces (unknown at design time — see Issues/risks).
- **Reversibility:** partial. `.env` files and their content are restorable via backup, but the actual Postgres role password is one-way once rotated (matches `estimated_reversibility: partial` in the task frontmatter) — consistent with why this plan is `NEEDS_APPROVAL` regardless.

## Issues / risks

- **This plan emits `NEEDS_APPROVAL` unconditionally**, per the task file's Notes (stated twice) — this holds even though no `shared/approval-protocol.md` file actually exists in this checkout (verified via search; only referenced by name in role files). The task file itself is unambiguous and is treated as the controlling instruction for this run.
- **Genuinely higher blast radius than T-0137**: this credential is shared across at least 2 (landscape-confirmed) and possibly 3 (Phase-0-pending) databases and their respective consumer containers, versus T-0137's Directus-only scope. Phase 0's enumeration is the load-bearing safety mechanism for this entire plan — if it under-enumerates a real consumer, that consumer breaks silently post-rotation until its next connection-pool retry surfaces the auth failure, exactly as the task file warns.
- **Phase 0.4's live-snapshot enumeration (`pg_stat_activity`) is a point-in-time view, not a guarantee of completeness** — a consumer with no currently-open connection (e.g. an idle connection pool between requests, or a cron job that hasn't fired recently) will not appear in this snapshot even though it holds a password reference it will use on its next connection attempt. This plan mitigates this by cross-checking 0.4 against the STATIC config enumeration in 0.5/0.6 (which finds consumers by config reference, not live connection state) — but if Phase 0 uncovers a consumer named in config that 0.4's snapshot doesn't show connected, the executor must still update and restart it, not skip it because "it wasn't seen connecting." This is called out explicitly so the executor doesn't under-scope based on 0.4 alone.
- **Unknown/undocumented `aiqadam_test` consumer risk** (explicitly flagged by the task file's own risk note: "err on the side of over-enumerating"): if Phase 0.4 surfaces a connection from a process/host this plan did not anticipate (e.g. a developer's ad-hoc local psql session, an old cron job), this plan's Phase 2.6 branch requires pausing to note it under Issues/risks rather than silently restarting/ignoring it — that specific sub-case cannot be fully pre-scripted since the consumer is currently unknown. If it turns out to be a real, addressable consumer, the executor should still update its credential reference if the plan's existing steps cover its file location; if it's an out-of-band manual session (not a service), no restart is needed or possible for it — the old password simply stops working for it going forward, which is expected and acceptable (a human re-typing a password is not a "broken service").
- **Phase 0.9's bootstrap-env-var-behavior conclusion is asserted as "standard Postgres Docker image behavior" by the task file** but is being empirically checked, not assumed, per the task's explicit instruction — if Phase 0.9 contradicts this (e.g. finds evidence the entrypoint DOES re-read `POSTGRES_PASSWORD` on some restart path for this specific image build), the plan's assumption that `ai-qadam-test-db-1` itself never needs restarting would be wrong; the executor must `BLOCKED` back to solution-designer in that case rather than silently adjusting Phase 2.6's scope.
- **Output hygiene remains the highest-severity operational risk**, given this exact host/credential family is the one already exposed once today. Every command in this plan avoids `grep -B/-A` + `-v`-exclusion combinations; uses `-oE` key-only capture, count-only, digest-only, or auth-status-only verification exclusively; mandates one continuous SSH session for the entire generate→apply→verify sequence (Phase 2 through Phase 3.5). Any deviation from this plan's exact command templates must halt the executor into `BLOCKED` rather than an improvised live diagnostic — this is the exact failure mode that created T-0138 in the first place.
- **Sequencing with T-0136**: per the host landscape file's `last_verified_note`, T-0136 closed out today (2026-08-20, root cause resolved, RBAC was never actually broken) before this run began — no live race exists. Re-confirmed by this step; no further coordination action needed.
- **`landscape/secrets-inventory.md` has zero existing rows for this credential** (only Directus-family entries from T-0137) — step 08 creates first-time entries, no prior rotation-date baseline to reconcile against.

## Open questions (optional)

None blocking approval. Phase 0 is the resolution mechanism for every identity/enumeration question raised by steps 01–03, structured as explicit, branch-labeled discovery sub-steps rather than upfront assumptions. The items that could still route the plan to `BLOCKED` mid-execution (an unrecognized `aiqadam_test` consumer surfacing in Phase 0.4, Phase 0.8 finding neither password variant currently functional, or Phase 0.9 contradicting the bootstrap-only assumption) are called out above as explicit branches, not open questions requiring resolution before this approval request.
