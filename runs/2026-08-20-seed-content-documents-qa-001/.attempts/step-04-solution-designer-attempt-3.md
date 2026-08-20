---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-08-20T17:20:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-04-solution-designer-attempt-2.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-cicd-attempt-2.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - infrastructure/directus/bootstrap.sh (aiqadam repo — grepped for admin_access/Administrator/directus_roles/directus_policies/directus_access/ADMIN_TOKEN — confirms bootstrap.sh assumes but never creates the Administrator role/policy)
  - .claude/agents/solution-designer.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
next_step_hint: >-
  Verdict PASS — orchestrator skips step 05, advances directly to
  executor-cicd (step 06). This is a pure read-only diagnostic pass: it
  queries Directus's own Postgres system tables directly (bypassing the
  opaque REST layer) to determine the actual admin_access truth value for
  role b3350300-c590-430f-b4ea-c020638bc2d1 and policy
  5029fc70-bcec-4dc6-a549-ab42b5ac5377, and whether the row/linkage even
  exists. NO permission grant, NO seed-script run, NO write of any kind
  happens in this step — that is explicitly out of scope, deferred to a
  follow-up step-04 (a new solution-designer plan) once these findings are
  in. Executor MUST record the raw query output for all 4 questions in its
  handoff verbatim (ids, booleans, row counts) so the follow-up plan can
  branch on it without re-querying.
retry_of: step-04
---

## Summary

A single-phase, entirely read-only plan: `docker exec` into the Postgres container `ai-qadam-test-db-1` on `pro-data-tech-qa` and run four narrowly-scoped `SELECT` queries against the `aiqadam_qa` database's Directus system tables (`directus_roles`, `directus_policies`, `directus_access`, `directus_permissions`) to determine, at the database level, whether role `b3350300-c590-430f-b4ea-c020638bc2d1` and policy `5029fc70-bcec-4dc6-a549-ab42b5ac5377` actually exist, what their `admin_access` columns say, whether the role↔policy junction row is intact, and whether any permission rows exist for this identity — resolving the ambiguity the REST API could not (its own policy read returning 403/empty-list to itself). No fix, no seed-script run, no schema change; this plan produces a diagnosis only, to unblock a subsequent fix-design step.

## Details

### Why direct DB access, and why now

Attempt 2's Phase 0 diagnosis (via REST) found: the admin token resolves to role `b3350300-c590-430f-b4ea-c020638bc2d1` (name "Administrator"), that role has exactly one attached policy id (`5029fc70-bcec-4dc6-a549-ab42b5ac5377`) per `GET /roles/<id>`, but `GET /policies/<id>` for that same policy returns `403 FORBIDDEN` with the same token, and a filtered list query (`GET /policies?filter[id][_eq]=...`) returns `[]` — the policy is not merely field-restricted, it is invisible to this identity via REST entirely. This means the load-bearing `admin_access` boolean (Directus 9+ bypass-all gate) cannot be confirmed true or false through the API, by any identity available to this project, at all. REST is the layer that's opaque here; going one layer down to the database Directus itself reads from is the only way to see the raw row state. The user explicitly approved continuing via direct DB inspection rather than stopping.

### Where the data lives

Per `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md`: Directus's Postgres backend is the pre-existing container `ai-qadam-test-db-1` (image `pgvector/pgvector:pg16`), Compose project `ai-qadam-test`, published on loopback `127.0.0.1:3112` → container port `5432`. Two databases live in this one Postgres instance: `aiqadam_test` (unrelated, pre-existing) and `aiqadam_qa` (created by T-0110 specifically to back the `aiqadam-qa` app stack — this is where Directus's own system schema, including `directus_roles`/`directus_policies`/`directus_access`/`directus_permissions`, lives, since Directus was deployed against this same Postgres instance/database per this repo's documented infra layout). Both databases are owned by role `aiqadam` (per `services.md`: "dbs `aiqadam_test` + `aiqadam_qa`, user `aiqadam`").

**Credential handling — no secret is read from `.env` at all for this plan.** Rather than grepping `POSTGRES_USER`/`POSTGRES_PASSWORD` out of `/var/www/ai-qadam-test/.env` (which would require handling a secret value inline, same discipline burden as the Directus token), every command below runs `psql` **inside the container**, invoked as the container's own `postgres` superuser via `docker exec -u postgres`, which uses the container's local Unix-domain-socket trust authentication (the standard behavior of the official `postgres`/`pgvector` images — local socket connections from inside the container as the cluster's bootstrap superuser do not require a password). This sidesteps secret-handling entirely for a purely diagnostic, read-only pass. `-U postgres` is the Postgres *cluster* superuser (distinct from the `aiqadam` application role) and is guaranteed to exist and have full read access to every table in `aiqadam_qa`, including Directus's system tables — appropriate for this diagnosis since the goal is to see ground truth, not to test what the `aiqadam` role can see.

### Approval-boundary judgment call (flagged explicitly, per role instructions)

This plan is 100% `SELECT`-only — no `INSERT`/`UPDATE`/`DELETE`, no schema change, no container restart, no `.env` edit. Weighed against `shared/approval-protocol.md`'s "Always requires NEEDS_APPROVAL" list (prod deployments, DNS/firewall changes, secret rotations/credential changes, package installs, destructive operations, or "any plan the designer is uncertain about") — none apply. Nothing here is a secret rotation or credential change (no token/password is read, generated, or altered); nothing is destructive or irreversible (nothing is modified, so there is nothing to roll back); this is a QA-only host, not prod. Judged against the task's own `estimated_blast_radius: low` / `estimated_reversibility: full` frontmatter (unaffected — this step changes nothing), all five `PASS` conditions hold.

That said, **querying a system's own internal access-control tables directly, bypassing the access-control layer itself, is qualitatively different from a routine read** — it is a deliberate authorization-boundary bypass, chosen precisely because the boundary is malfunctioning/opaque. I considered whether that alone should force `NEEDS_APPROVAL` regardless of read-only status. I judge **it should not**, for these reasons, consistent with how attempt 2 reasoned about its Phase 0.4 permission-grant call:
- The queries below are scoped to exactly 4 narrow, explicit-column `SELECT`s against 4 named tables, filtered to the 2 already-known ids (role, policy) plus one unfiltered-but-narrow query on `directus_permissions` (bounded to matching role/policy ids). No `SELECT *`, and critically, **no query touches `directus_users`** (which holds password hashes and other user-sensitive columns) — the plan does not need that table to answer any of the 4 questions, so it is deliberately excluded from scope even though it would be trivially accessible with the same superuser session.
- The user has already explicitly approved this specific investigative approach in chat (per this step's own task input: "The user explicitly approved continuing this investigation via direct database inspection rather than stopping") — this is not the designer unilaterally deciding to escalate access; it is executing a user-directed diagnostic method.
- The output is 4 short structured facts (row exists y/n, boolean values, FK integrity, row counts) — nothing in the output plan writes raw table dumps to a handoff; the executor should record only the specific answer to each of the 4 questions, not full-row output, further narrowing exposure.
- This is a QA environment with no real user PII riding on this specific set of tables (RBAC config, not user data).

**If the reviewing user disagrees with this framing, the safe correction is to treat this as `NEEDS_APPROVAL` before any command runs** — flagged transparently here exactly as instructed, rather than silently deciding either way.

### Plan

**Phase 0 — Direct DB diagnosis (read-only, single phase, no fix)**

0.1. **Confirm the Postgres container is up and confirm which databases exist (read-only, sanity check before targeting `aiqadam_qa`)** — command:
```
ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d postgres -Atc \"SELECT datname FROM pg_database WHERE datname IN ('aiqadam_test','aiqadam_qa');\""
```
— verification: output contains both `aiqadam_test` and `aiqadam_qa` on separate lines. If `aiqadam_qa` is absent, STOP — the premise that Directus's system schema lives in this Postgres instance is wrong; emit `BLOCKED` rather than guessing at an alternate location.

0.2. **Confirm `directus_roles` and `directus_policies` table shapes (read-only schema introspection — resolves the task's own instruction to check actual column names rather than assume)** — command:
```
ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d aiqadam_qa -c \"\\d directus_roles\" -c \"\\d directus_policies\" -c \"\\d directus_access\" -c \"\\d directus_permissions\""
```
— verification: all four `\d` calls return a column listing (not "Did not find any relation"). Executor records the exact column names found for the admin-access-equivalent field on `directus_roles` and on `directus_policies` (Directus 11's schema may name this `admin_access` on `directus_policies` only, with `directus_roles` holding no such column directly — confirm from this output rather than assuming either shape). This is the answer to diagnostic question 1's schema-shape sub-part and directly informs how 0.3/0.4 below must be phrased.

0.3. **Question 1 — does the role row exist, and what does its own admin-access-equivalent column (if any) say?** — command (column list adjusted per 0.2's actual findings; shown here assuming Directus 11's documented model where `admin_access` lives on `directus_policies`, not `directus_roles` — **executor must verify against 0.2's real output and adjust the column list if it differs**):
```
ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d aiqadam_qa -c \"SELECT id, name, icon, description FROM directus_roles WHERE id = 'b3350300-c590-430f-b4ea-c020638bc2d1';\""
```
— verification: exactly one row, or zero rows (both are informative findings — record which). If `directus_roles` in this Directus version DOES have its own `admin_access`/similar boolean column (per 0.2's findings), re-run including that column explicitly by name.

0.4. **Question 2 — does the policy row exist, and what does ITS admin_access column say?** — command:
```
ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d aiqadam_qa -c \"SELECT id, name, icon, admin_access, app_access FROM directus_policies WHERE id = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: exactly one row (with `admin_access`/`app_access` boolean values recorded verbatim), or zero rows. **Zero rows here would fully explain the REST 403/empty-list finding** — a role referencing a nonexistent policy id would behave exactly as observed (nothing to bypass with, nothing to read). If the column names `admin_access`/`app_access` don't match 0.2's actual schema output, adjust to the real names before running.

0.5. **Question 3 — does the role↔policy junction table have an intact row linking these two ids, and is anything about it malformed?** — command:
```
ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d aiqadam_qa -c \"SELECT * FROM directus_access WHERE role = 'b3350300-c590-430f-b4ea-c020638bc2d1' OR policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: record however many rows come back (0, 1, or more than 1 — more than 1 would itself be a finding), and specifically whether `role` and `policy` columns are both non-null and match the two ids in the SAME row (a row where `role` matches but `policy` is null or points elsewhere would explain the disconnect). **Note on table name:** `directus_access` is Directus 11's documented junction table name for role/user/policy linkage; if `\d directus_access` in 0.2 reported "did not find relation," fall back to listing all tables matching `directus_%` (`ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d aiqadam_qa -Atc \"SELECT tablename FROM pg_tables WHERE tablename LIKE 'directus_%' ORDER BY 1;\""`) and identify the actual junction table name from that list before re-running this query with the correct name.

0.6. **Question 4 — does `directus_permissions` have ANY rows at all for this role/policy identity, on any collection?** — command:
```
ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d aiqadam_qa -c \"SELECT id, policy, collection, action FROM directus_permissions WHERE policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: record the row count and, if non-zero, the list of `(collection, action)` pairs. **Zero rows is the expected/consistent finding if this identity is supposed to be bypass-all** (a genuine admin_access=true policy needs zero explicit grants — everything is implicitly allowed). Zero rows combined with `admin_access` confirmed `false` (or the policy row missing entirely, per 0.4) would be the complete, self-consistent explanation for every 403 seen across both prior attempts: an identity with no bypass flag and no explicit grants can do nothing except what the Public policy separately covers.

   Directus 11 associates `directus_permissions` rows with a `policy` id (not directly with a `role` id — the role→policy→permissions chain is exactly what 0.5 confirms or refutes), so this query filters on `policy`, matching the schema model attempt 2's Issues/risks section already flagged as the likely actual shape. If 0.2's real schema shows `directus_permissions` still carries a `role` column directly (an older-schema holdover), also run:
```
ssh pro-data-tech-qa "docker exec -u postgres ai-qadam-test-db-1 psql -U postgres -d aiqadam_qa -c \"SELECT id, role, policy, collection, action FROM directus_permissions WHERE role = 'b3350300-c590-430f-b4ea-c020638bc2d1' OR policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```

0.7. **Synthesize the finding (no command — executor's own summary in its handoff).** Based on 0.3–0.6, the executor must state plainly which of these (or another) scenarios matches:
   - **Scenario X:** policy row missing entirely (0.4 = zero rows) → role has no working policy despite the array reference → `admin_access` is structurally false/undefined → fully explains every 403 in both attempts.
   - **Scenario Y:** policy row exists, `admin_access = true`, junction (0.5) intact, zero permission rows (0.6) → this is the textbook correct bypass-all admin configuration and the REST-layer 403/invisible-policy behavior would then be a genuine Directus-level bug (cache staleness, a stale JWT/session artifact, or a REST-layer regression) unrelated to the RBAC data itself — worth escalating to Directus's own issue tracker if confirmed.
   - **Scenario Z:** policy row exists, `admin_access = false` (or NULL) → same as the "Case B" custom-role-missing-a-grant scenario attempt 2 anticipated, except now confirmed at the DB level instead of guessed at via an inaccessible REST object.
   - **Any other combination:** report the raw findings verbatim and let the follow-up solution-designer step interpret it — do not force-fit an unexpected result into X/Y/Z.

### Rollback

Not applicable — no state-changing action occurs anywhere in this plan. Every command is a `SELECT`, a `\d` schema-introspection meta-command, or a `pg_tables`/`pg_database` catalog read. Nothing is created, altered, or deleted on the host, in the container, or in the database.

### Verification (for step 07)

- **On-host:**
  - 0.1's `aiqadam_qa` presence confirmed in `pg_database`.
  - 0.2's four `\d` outputs captured, with the actual admin-access-equivalent column name(s) identified per table.
  - 0.3's role-row existence + full row content recorded.
  - 0.4's policy-row existence + `admin_access`/`app_access` values (or explicit "zero rows") recorded.
  - 0.5's junction-table row(s) recorded, with explicit note on whether `role` and `policy` both resolve correctly in the same row.
  - 0.6's permission-row count and any `(collection, action)` pairs recorded.
  - 0.7's scenario classification (X/Y/Z/other) stated explicitly in the executor's handoff body.
- **External:** none — this is a pure on-host/in-container diagnostic pass; nothing externally observable changes (correctly so, since nothing is written).

### Resources used

- **Secrets (by name):** none. This plan deliberately avoids reading `DIRECTUS_ADMIN_TOKEN`/`DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_PASSWORD` and avoids reading `POSTGRES_USER`/`POSTGRES_PASSWORD` from `/var/www/ai-qadam-test/.env` — all queries run as the Postgres container's own `postgres` superuser via local Unix-socket trust auth inside `docker exec`, which needs no credential material handled by the executor at all.
- **Files modified on host:** none.
- **Files modified in this repo (`landscape/`), to be applied at step 08:** none from this step itself (diagnosis only) — `landscape/hosts/pro-data-tech-qa.md` Change log entry for this run will be written once the *fix* (a follow-up step-04/06 pair) actually executes; this diagnostic pass alone does not warrant a landscape change-log entry since it changes no state, though the executor may note the finding in its own handoff for the next solution-designer to consume via `inputs_read`.
- **External APIs called:** none. All access is local to the host (`ssh` + `docker exec` + in-container `psql`).

### Estimated impact

- **Downtime:** none. No container is restarted, recreated, or has its state touched. Read-only queries against a live Postgres instance add negligible, momentary load.
- **Affected services:** none, functionally. `ai-qadam-test-db-1` serves a handful of trivial `SELECT`s against small system tables — no measurable impact on `aiqadam-qa-directus-1`, `aiqadam-qa-api-1`, or any other consumer of the same Postgres instance (including the unrelated `aiqadam_test` database, which this plan never queries).
- **Reversibility:** fully reversible — there is nothing to reverse; no state changes.

## Issues / risks

- **The core approval-boundary judgment call (documented in detail above) is the single most important thing to flag: this plan reads Directus's internal RBAC tables directly, bypassing the exact access-control layer it is diagnosing.** Judged as within `PASS` scope because it is strictly read-only, narrowly scoped (excludes `directus_users` and any other sensitive table not needed to answer the 4 questions), explicitly user-directed per this step's own task input, and produces only small structured findings rather than raw data dumps. If the user disagrees on review, the correction is straightforward: halt before 0.1 and require an explicit `APPROVED` step-05 file — none of the *content* of the plan needs to change, only the approval gate.
- **Column-name assumptions in 0.3/0.4/0.6 are provisional and explicitly gated on 0.2's live schema output.** Directus's schema has shifted across major versions (role-embedded permissions in older versions vs. the role→policy→permissions chain in 11.x); the plan tells the executor explicitly to re-derive real column/table names from 0.2 before trusting the example queries in 0.3–0.6 verbatim, rather than assuming Directus 11.17.4's documented shape holds exactly as expected on this instance (attempt 2's own Issues/risks section already flagged this exact uncertainty once, for the REST-layer `role.admin_access` field — this plan carries the same caution down to the DB layer).
- **Using the Postgres cluster superuser (`-U postgres`, via `docker exec -u postgres`) rather than the application role `aiqadam`.** This guarantees the query can see the ground truth regardless of `aiqadam`'s own grants (which are irrelevant to what Directus's own service account sees), but it is a broader-privilege session than strictly minimal. Judged acceptable because: (a) it is momentary and confined to `SELECT`/`\d`, (b) it is the standard, expected way to inspect a Postgres instance's own system state from inside its own container, (c) the alternative (connecting as `aiqadam` with a password pulled from `.env`) would require handling a credential value for no added safety benefit, working against this plan's explicit goal of avoiding secret handling entirely.
- **Directus itself is not stopped or paused during these reads.** A `SELECT` against small system tables while Directus is live is safe (no locks held beyond the query's own transaction, no schema change), but if Directus is mid-migration or executing a large write at the exact moment of a query, an extremely brief lock wait is theoretically possible — considered negligible risk for hand-count system tables (`directus_roles`, `directus_policies`, `directus_access`, `directus_permissions` are all tiny, low-write-frequency tables) and not worth pausing the service for.
- No item above is high-severity in the sense of touching prod, DNS, firewall, secrets, or an irreversible action.

## Open questions (optional)

None — verdict is `PASS`, not `BLOCKED`. All five `shared/approval-protocol.md` PASS conditions hold: (1)/(2) task frontmatter (`estimated_blast_radius: low` / `estimated_reversibility: full`) unchanged and, in fact, unaffected by this plan since nothing is written; (3) no irreversible step — nothing is modified at all; (4) no designer doubts remain about correctness — the one genuine unknown (exact column/table names for this Directus version) is explicitly handled by a live schema-introspection sub-step (0.2) that gates all subsequent queries, rather than assumed; (5) no Issues/risks item is high-severity — the approval-boundary judgment call is flagged transparently but assessed as within PASS scope for the reasons stated, consistent with how attempt 2 handled its own comparable judgment call on the permission-grant step.
