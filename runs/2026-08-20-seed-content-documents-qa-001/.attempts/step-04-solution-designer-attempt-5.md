---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-08-20T20:15:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-04-solution-designer-attempt-4.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-infra-attempt-2.md
  - landscape/hosts/pro-data-tech-qa.md
  - .claude/agents/solution-designer.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - workflows/deploy-app.md
  - tasks/T-0138-rotate-qa-postgres-password.md
retry_of: step-04
next_step_hint: >-
  Verdict PASS — orchestrator skips step 05, advances directly to
  executor-infra (step 06). The database-location question is now closed:
  the Orchestrator's direct read of docker-compose.qa.yml shows Directus's
  DB_DATABASE is literally `directus`, a third database in the same
  ai-qadam-test-db-1 Postgres cluster, distinct from both aiqadam_test and
  aiqadam_qa (which attempt 2 of executor-infra proved holds no directus_*
  tables at all — 8 unrelated tables, different application). This plan
  drops Phase 1's database-existence guessing entirely and connects
  straight to `-d directus`. Auth strategy is unchanged and does not need
  re-verification: attempt 2 already live-confirmed `local all all trust`
  in pg_hba.conf, so Phase 0 of this plan is a lightweight optional
  re-check (not mandatory) rather than a full re-run — the executor may
  skip 0.0 entirely and go straight to `-U aiqadam` with no password if it
  trusts attempt 2's finding, since that finding does not depend on which
  database holds Directus's schema. New in this plan: step 1.0a, a
  read-only grep of deploy/.env's KEY NAMES ONLY (never values) to check
  whether AIQADAM_QA_POSTGRES_PASSWORD and POSTGRES_PASSWORD are both
  present as distinct keys — this determines whether T-0138's rotation
  scope (currently written only in terms of "POSTGRES_PASSWORD") needs to
  be expanded to also cover AIQADAM_QA_POSTGRES_PASSWORD before that
  rotation is considered complete. This finding should be handed to
  whoever owns T-0138, not acted on in this run. If 1.0a finds the two
  keys ARE distinct, flag prominently in step 06's handoff and step 08
  should append a note to T-0138 (not edit its rotation logic — out of
  this run's scope). The four RBAC SELECT queries (role/policy/junction/
  permissions) are otherwise structurally identical to attempt 4's Phase 1,
  now targeting `-d directus` instead of `-d aiqadam_qa`, with the same
  live \d schema-introspection gate before assuming column names.
---

## Summary

A read-only plan that connects to the newly-identified `directus` database (a third, separate database inside the same `ai-qadam-test-db-1` Postgres cluster, per the Orchestrator's direct read of `docker-compose.qa.yml` showing Directus's own `DB_DATABASE: directus`) using the already-confirmed `aiqadam` role under local Unix-socket trust auth, and runs the same four narrowly-scoped `SELECT`/`\d` RBAC diagnostics from attempt 4 against that database's real schema; it also adds one new, strictly read-only check — grepping `deploy/.env` for the mere *presence* of the key names `AIQADAM_QA_POSTGRES_PASSWORD` and `POSTGRES_PASSWORD` (never their values) — to determine whether T-0138's password-rotation scope, as currently written, actually covers the credential Directus itself consumes. No fix, no seed-script run, no schema change, no rotation, and no secret value is read anywhere in this plan.

## Details

### What changed from attempt 4

Attempt 4 correctly resolved the role/auth question (`-U aiqadam`, local trust, no password) but guessed the wrong database: it assumed Directus's schema lives in `aiqadam_qa` (a database that does exist, per T-0110's landscape note, but — per executor-infra attempt 2's live finding — holds zero `directus_*` tables; it belongs to a different, unidentified application). The Orchestrator has since read `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` directly on the host and found Directus's service block sets:

```
DB_DATABASE: directus
```

This is ground truth from the container's own configuration — not inferred from landscape-doc commentary, which is exactly the kind of live-verification executor-infra attempt 2's `next_step_hint` recommended. `directus` is a third database in the same cluster/container (`ai-qadam-test-db-1`), distinct from `aiqadam_test` (T-0090's original QA postgres db) and `aiqadam_qa` (T-0110's db, which turned out to belong to something else). This redesign:

1. Replaces every `-d aiqadam_qa` in attempt 4's Phase 1 with `-d directus`.
2. Keeps attempt 4's Phase 0 (pg_hba.conf trust check) as an **optional** re-verification rather than a mandatory gate — executor-infra attempt 2 already live-confirmed `local all all trust` covers `aiqadam`, and that finding is auth-method-scoped, not database-scoped, so it remains valid unchanged. The executor may re-run it for belt-and-suspenders confidence or skip straight to Phase 1's `-U aiqadam -d directus` connection; either is acceptable.
3. Drops attempt 4's step 1.1 (`aiqadam_test`/`aiqadam_qa` existence check) — superseded by the compose-file finding, which is more authoritative than a `pg_database` existence probe would be. Replaced with a lighter existence check scoped to `directus` itself (new step 1.1).
4. Adds new step 1.0a: a read-only, key-names-only grep of `deploy/.env` to check whether `AIQADAM_QA_POSTGRES_PASSWORD` and `POSTGRES_PASSWORD` are both present as distinct keys. This is orthogonal to the RBAC diagnosis itself but was explicitly requested this iteration to clarify T-0138's rotation scope — it reads no value, only key names, preserving the same secret-discipline as every prior attempt today.

### Where the data lives (corrected)

Per the Orchestrator's direct compose-file read (superseding `landscape/hosts/pro-data-tech-qa.md`'s current text, which does not yet document this): Directus's Postgres backend is `ai-qadam-test-db-1` (unchanged — same container, same image `pgvector/pgvector:pg16`, same Compose project `ai-qadam-test`, same loopback publish `127.0.0.1:3112→5432`), but the **database** Directus actually uses is `directus`, set via `DB_DATABASE: directus` in `docker-compose.qa.yml`'s Directus service block — not `aiqadam_qa`. `aiqadam` remains the cluster's only superuser (no `postgres` role exists, per executor-infra attempt 1), and local trust auth covers it (per executor-infra attempt 2, live-confirmed). This is the RBAC diagnosis target for role `b3350300-c590-430f-b4ea-c020638bc2d1` / policy `5029fc70-bcec-4dc6-a549-ab42b5ac5377`.

The compose block's `DB_PASSWORD` for Directus is sourced from `AIQADAM_QA_POSTGRES_PASSWORD` (a variable name, read from `deploy/.env`) — **not** used anywhere in this plan, since local trust auth makes any password unnecessary. This detail is relevant only to step 1.0a's key-presence check, not to connecting.

### Plan

**Phase 0 — Optional re-verification of trust auth (read-only, no secret touched)**

0.0. **(Optional — skip if trusting executor-infra attempt 2's live finding.)** Re-check local Unix-socket trust auth covers `aiqadam` — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 cat /var/lib/postgresql/data/pg_hba.conf"
```
— verification: look for `local   all   all   trust` (or equivalent covering `aiqadam` with no more specific preceding `local` line requiring a password). Executor-infra attempt 2 already confirmed this exact output live on 2026-08-20; if the executor chooses to skip this step, it should note in its handoff that it relied on attempt 2's finding rather than re-running. If re-run and the result differs from attempt 2 (i.e., trust no longer covers `aiqadam`), **STOP** — do not proceed to Phase 1, do not touch any password, emit `BLOCKED` and report the discrepancy (auth config would have changed between attempts, which is itself notable).

**Phase 1 — RBAC diagnosis against the correct database (read-only)**

1.0a. **Key-name-only presence check in `deploy/.env`** (new this iteration) — command:
```
ssh pro-data-tech-qa "grep -oE '^(AIQADAM_QA_POSTGRES_PASSWORD|POSTGRES_PASSWORD)=' /opt/apps/aiqadam-qa/deploy/.env"
```
— verification: this prints only the matched key names followed by `=` (via `-oE`, which prints only the matched portion of each line — the value after `=` is never captured or displayed, since the regex stops at `=`). Record which of the two key names appear (both, one, or neither). **Do not** modify the command to drop `-o` or otherwise capture values. **Do not** open `deploy/.env` in any editor or view its full contents. If the command's exit code is non-zero (no matches, e.g. file path wrong or neither key present), record that as a finding — not a failure of the plan — and note it for T-0138's owner to investigate separately; it does not block Phase 1's RBAC diagnosis, which is independent.
  - **Finding interpretation (no further action taken here):** if both keys appear as distinct lines → T-0138's rotation, as currently scoped to "POSTGRES_PASSWORD," likely does **not** cover the literal credential Directus consumes (`AIQADAM_QA_POSTGRES_PASSWORD`) unless T-0138's own plan already accounts for rotating both names to the same new value. If only `POSTGRES_PASSWORD` appears → `AIQADAM_QA_POSTGRES_PASSWORD` may be sourced from a different file/mechanism not yet located, or Directus's compose var substitution falls back to something else — worth a separate follow-up, not this run's job to chase. If only `AIQADAM_QA_POSTGRES_PASSWORD` appears → the Postgres container's own bootstrap `POSTGRES_PASSWORD` (the one incidentally exposed in executor-infra attempt 1's `docker exec ... env` transcript) is set through some other path (a different env file, or hardcoded in the Postgres service's compose block) — also a follow-up, not this run's job.

1.1. **Confirm the `directus` database exists** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -Atc \"SELECT datname FROM pg_database WHERE datname = 'directus';\""
```
— verification: output is exactly `directus`. If empty, **STOP** — emit `BLOCKED`; the compose file's `DB_DATABASE: directus` would then not match cluster reality, which would be a materially different and more surprising finding than anything seen in attempts 1–4, worth surfacing to the user directly rather than guessing further.

1.2. **Confirm table shapes (schema introspection)** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -c \"\\d directus_roles\" -c \"\\d directus_policies\" -c \"\\d directus_access\" -c \"\\d directus_permissions\""
```
— verification: all four `\d` calls return a column listing (not "Did not find any relation"). Executor records the actual admin-access-equivalent column name(s) found, and uses them (not the example names below) in 1.3–1.6 if they differ. If this again returns "Did not find any relation" for all four, **STOP** — emit `BLOCKED`; this would mean the compose file's `DB_DATABASE: directus` is itself pointing somewhere unexpected (e.g. Directus auto-created its schema in a non-`public` schema within `directus`), which is a new, different failure mode from attempts 1–4 and should go back to the user rather than trigger a fifth guess.

1.3. **Question 1 — does the role row exist, and what does its own admin-access-equivalent column (if any) say?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -c \"SELECT id, name, icon, description FROM directus_roles WHERE id = 'b3350300-c590-430f-b4ea-c020638bc2d1';\""
```
— verification: exactly one row or zero rows (both informative — record which). If 1.2 showed `directus_roles` has its own admin-access-equivalent column, re-run including it by name.

1.4. **Question 2 — does the policy row exist, and what does ITS admin_access say?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -c \"SELECT id, name, icon, admin_access, app_access FROM directus_policies WHERE id = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: exactly one row (record `admin_access`/`app_access` verbatim) or zero rows. Zero rows would fully explain the REST 403/empty-list finding from the original T-0136 investigation. Adjust column names to 1.2's real schema if they differ.

1.5. **Question 3 — is the role↔policy junction intact?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -c \"SELECT * FROM directus_access WHERE role = 'b3350300-c590-430f-b4ea-c020638bc2d1' OR policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: record row count (0, 1, or >1) and whether `role`/`policy` are both non-null and match in the same row. If `\d directus_access` in 1.2 reported "did not find relation," fall back to:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -Atc \"SELECT tablename FROM pg_tables WHERE tablename LIKE 'directus_%' ORDER BY 1;\""
```
and identify the real junction table name before re-running.

1.6. **Question 4 — does `directus_permissions` have any rows at all for this identity?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -c \"SELECT id, policy, collection, action FROM directus_permissions WHERE policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: record row count and, if non-zero, `(collection, action)` pairs. Zero rows is the expected/consistent finding if `admin_access = true` (bypass-all needs no explicit grants). If 1.2 shows `directus_permissions` still carries a `role` column directly, also run:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -c \"SELECT id, role, policy, collection, action FROM directus_permissions WHERE role = 'b3350300-c590-430f-b4ea-c020638bc2d1' OR policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```

1.7. **Synthesize the finding (no command — executor's own summary).** Same X/Y/Z/other scenario classification as attempt 4:
   - **Scenario X:** policy row missing (1.4 = zero rows) → role has no working policy → explains every 403.
   - **Scenario Y:** policy row exists, `admin_access = true`, junction intact, zero permission rows → correct bypass-all config; REST 403 would then be a genuine Directus-level bug unrelated to the RBAC data.
   - **Scenario Z:** policy row exists, `admin_access = false`/NULL → confirms the "missing grant" hypothesis at the DB level.
   - **Any other combination:** report raw findings verbatim; do not force-fit.

### Rollback

Not applicable. Every command in this plan — the optional pg_hba.conf read, the `.env` key-name grep, and all Phase 1 steps — is a pure read (`cat`, `grep -oE` on key names only, `psql -Atc SELECT`, `psql \d`, catalog queries). Nothing is created, altered, or deleted anywhere. If either STOP condition in 1.1 or 1.2 is hit, the plan halts with zero writes — nothing to roll back.

### Verification (for step 07)

- **On-host:**
  - (If run) 0.0's pg_hba.conf finding, or an explicit note that it was skipped in favor of trusting executor-infra attempt 2's result.
  - 1.0a's key-presence finding recorded verbatim: which of `AIQADAM_QA_POSTGRES_PASSWORD` / `POSTGRES_PASSWORD` appear as distinct keys in `deploy/.env` — key names only, zero values anywhere in the handoff or run artifacts.
  - 1.1's `directus` database-existence confirmation.
  - 1.2's four `\d` outputs with real column names identified.
  - 1.3–1.6's row contents/counts recorded per question.
  - 1.7's scenario classification (X/Y/Z/other) stated explicitly.
- **External:** none — pure on-host/in-container diagnostic; nothing externally observable changes.

### Resources used

- **Secrets (by name):** none read or used. `AIQADAM_QA_POSTGRES_PASSWORD` and `POSTGRES_PASSWORD` are referenced by **name only** in step 1.0a (presence check, not value read); local trust auth means no password is needed for any `psql` connection in this plan.
- **Files modified on host:** none.
- **Files modified in this repo (`landscape/`), to be applied at step 08:** none from this step itself. If this plan's Phase 1 completes, `landscape/hosts/pro-data-tech-qa.md` should be updated by step 08 to record that Directus's actual database is `directus` (not `aiqadam_qa`) — closing the gap executor-infra attempt 2 flagged. If 1.0a finds both key names present, step 08 (or the orchestrator, out-of-band) should add a note to `tasks/T-0138-rotate-qa-postgres-password.md`'s scope — not edit its rotation logic, which remains a separate, already-gated task.
- **External APIs called:** none.

### Estimated impact

- **Downtime:** none.
- **Affected services:** none, functionally. A handful of trivial `SELECT`s/`\d` calls against small system tables, plus one `cat` and one `grep` of small text files — negligible load, no other consumer of the same Postgres instance or host affected.
- **Reversibility:** fully reversible — nothing is modified.

## Issues / risks

- **1.0a's finding may reveal a gap in T-0138's rotation scope, but this plan does not act on it.** If both `AIQADAM_QA_POSTGRES_PASSWORD` and `POSTGRES_PASSWORD` are present as distinct keys, T-0138 (currently written in terms of "POSTGRES_PASSWORD" only, per its task file and attempt 4's Issues/risks) may need its scope expanded to explicitly cover `AIQADAM_QA_POSTGRES_PASSWORD` too, or explicitly confirm both keys are rotated to the same new value in lockstep. This plan surfaces the fact for the record; deciding whether/how to amend T-0138 is a follow-up for its owner, not this diagnostic run.
- **`directus` as the target database is now grounded in the container's own live compose configuration** (the strongest form of evidence available — stronger than a landscape-doc comment, which is exactly the class of evidence that was wrong twice already this run for `aiqadam_qa`). Residual risk is limited to: (a) the compose file on disk might not match what the running container was actually started with (e.g., if it was started with an older compose file before a since-edited `DB_DATABASE` line) — mitigated by 1.1's live existence check and 1.2's live schema check, both of which independently corroborate or falsify the compose file's claim before any RBAC query runs; (b) Directus 11.17.4 could in principle use a non-`public` schema inside `directus` — 1.2's explicit STOP-and-BLOCKED condition (rather than silently trying harder) is the safeguard here, consistent with the "no substitute path improvised" discipline executor-infra has followed each attempt.
- **Using the `aiqadam` role (the cluster's actual superuser) rather than a lower-privilege role** remains unavoidable — `postgres` does not exist on this cluster (confirmed attempt 1). Same acceptable-tradeoff reasoning as every prior attempt: momentary, `SELECT`-only, standard practice for inspecting a Postgres instance's own system state, deliberately excluding `directus_users`.
- **Column-name assumptions in 1.3/1.4/1.6 are provisional**, gated on 1.2's live schema output, same caveat as every prior attempt.
- **This is the fifth solution-designer attempt on this run.** Unlike attempts 2–4 (each correcting one layer of a wrong assumption incrementally), this attempt is grounded in the Orchestrator's own direct, authoritative read of the container's live configuration file rather than another inference — the class of evidence executor-infra attempt 2 itself recommended seeking. No further guessing dimension is known to remain: role (attempt 1 fixed), auth method (attempt 4 fixed and attempt 2 live-confirmed), and now database (this attempt, grounded in compose-file ground truth) are all resolved from live evidence, not inference.
- No item above is high-severity in the sense of touching prod, DNS, firewall, secrets, or an irreversible action. Both STOP conditions (1.1, 1.2) are the plan correctly refusing to overreach if the compose-file evidence turns out to be stale, not defects requiring `NEEDS_APPROVAL` on the read-only steps themselves.

## Open questions (optional)

None — verdict is `PASS`, not `BLOCKED`. All five `shared/approval-protocol.md`-equivalent PASS conditions hold: (1)/(2) task frontmatter (`estimated_blast_radius: low` / `estimated_reversibility: full`, per `runs/.../step-01-task-reader.md`) unaffected, since nothing is written by this plan; (3) no irreversible step — both STOP conditions are clean halts, not irreversible actions; (4) no designer doubts remain about this plan's own correctness — the database-location question that blocked attempt 4's premise is now resolved via the strongest available evidence (the container's own compose configuration), and the one adjacent question (T-0138 key-name scope) is explicitly routed to a follow-up rather than guessed at or acted on; (5) no Issues/risks item is high-severity in a way that would block this plan's read-only steps from running.
