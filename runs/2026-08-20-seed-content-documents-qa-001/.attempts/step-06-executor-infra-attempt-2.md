---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 06
agent: executor-infra
verdict: FAIL
created: 2026-08-20T19:40:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/step-04-solution-designer.md
  - landscape/hosts/pro-data-tech-qa.md
  - .claude/agents/executor-infra.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-infra-attempt-1.md
artifacts_changed: []
next_step_hint: >-
  Phase 0 succeeded and resolved cleanly: pg_hba.conf on ai-qadam-test-db-1
  shows `local all all trust` (plus matching host 127.0.0.1/32 and ::1/128
  trust entries, with a later `host all all all scram-sha-256` catch-all that
  does not apply to local socket connections) — Branch A confirmed, local
  trust covers `aiqadam`, no password touched, zero secret handling as
  designed. Step 1.1 also passed: both `aiqadam_test` and `aiqadam_qa`
  databases exist. Step 1.2 then failed: `\d directus_roles` /
  `directus_policies` / `directus_access` / `directus_permissions` against
  `aiqadam_qa` all returned "Did not find any relation." A plan-sanctioned
  fallback catalog query (the same `SELECT tablename FROM pg_tables WHERE
  tablename LIKE 'directus_%'` that step 1.5 explicitly authorizes as a
  fallback) returned zero rows — `aiqadam_qa` has no directus_* tables at
  all, though it is not an empty database (8 tables exist in its public
  schema; contents not enumerated, out of plan scope). This falsifies the
  plan's core premise ("this is where the RBAC diagnosis... must run") and
  matches step 1.1's own defined halt condition ("If aiqadam_qa is absent,
  STOP... premise about where Directus's schema lives is wrong" — the same
  logic applies one level down: the database exists but does not hold
  Directus's schema). A follow-up solution-designer pass should determine
  where Directus's actual system schema lives before any further RBAC
  diagnosis is attempted. Candidates worth checking read-only, in order of
  likelihood: (a) `aiqadam_test` (the OTHER database in the same container —
  plan attempt's `services.md`-derived assumption may have picked the wrong
  one of the two databases that share this container); (b) a non-`public`
  schema inside `aiqadam_qa` (this run's catalog query did not filter or
  report schemaname, only tablename — worth re-running as `SELECT
  schemaname, tablename FROM pg_tables WHERE tablename LIKE 'directus_%'`
  across all schemas, and separately confirming which schema
  `aiqadam-qa-directus-1`'s own DB connection string actually points at,
  e.g. from its compose env, without touching credential values); (c) the
  Directus container's own configured DB connection settings (name/host/port
  only, not secret values) to confirm which of the two databases and which
  schema it is actually configured to use, since that is ground truth and
  this plan appears to have inferred the target from a landscape doc
  comment rather than the container's live config. None of these three
  checks were performed by this step — they are out of the approved plan's
  scope and are left for the next solution-designer iteration. This is the
  third executor-infra attempt on this run; each attempt has corrected one
  layer of a wrong assumption (attempt 1: wrong role name; this attempt:
  right role, right auth, but wrong schema location) — worth flagging to
  the user/orchestrator as a pattern suggesting the plan's source material
  (services.md / landscape doc commentary) may need a live-verification
  pass rather than continued incremental correction.
retry_of: step-06
---

## Summary

Phase 0 (the live pg_hba.conf branch check) and step 1.1 (database existence) of the approved plan both succeeded: local Unix-socket trust authentication covers `aiqadam` (Branch A), so Phase 1 proceeded with zero secret handling, and both `aiqadam_test` and `aiqadam_qa` databases were confirmed to exist. Execution then halted at step 1.2: none of the four expected Directus RBAC tables (`directus_roles`, `directus_policies`, `directus_access`, `directus_permissions`) exist anywhere in `aiqadam_qa`'s public schema, and a plan-sanctioned fallback catalog query confirms zero `directus_*` tables of any kind are present in that database. This falsifies the plan's premise about where Directus's system schema lives. Per role instructions, no substitute path was improvised; the diagnostic could not be completed, and this is reported as a plan-vs-reality mismatch. No secret was read, derived, or used at any point in this run — Branch A made that unnecessary, exactly as the plan intended.

## Details

### Pre-execution checks
- Approval handoff verified: yes — `runs/2026-08-20-seed-content-documents-qa-001/step-04-solution-designer.md` frontmatter `verdict: PASS`.
- Approval verdict: PASS (auto-approved per `shared/verdicts.md`). Confirmed no `step-05-user-approval.md` file exists in the run directory (directory listing shows steps 01–04, this step-06, and a sibling `step-06-executor-cicd.md` from a parallel track; no step-05).
- Design references match: yes — plan references `landscape/hosts/pro-data-tech-qa.md`, read in full before execution.

### Execution log

#### Phase 0 / Step 0.0: check whether local Unix-socket trust auth covers `aiqadam`
- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 cat /var/lib/postgresql/data/pg_hba.conf"`
- Exit code: 0
- Output (relevant lines, comments trimmed):
  ```
  local   all             all                                     trust
  host    all             all             127.0.0.1/32            trust
  host    all             all             ::1/128                 trust
  local   replication     all                                     trust
  host    replication     all             127.0.0.1/32            trust
  host    replication     all             ::1/128                 trust
  host all all all scram-sha-256
  ```
- Result: success
- Branch determination: **Branch A** — the `local all all trust` line matches all databases and all users (including `aiqadam`) for Unix-domain-socket connections, with no more specific preceding `local` line taking precedence. The later `host all all all scram-sha-256` line governs non-local TCP connections only and does not affect the local-socket path used by `docker exec ... psql`. Proceeding to Phase 1 with `-U aiqadam`, no password.
- Backup taken: n/a (read-only)

#### Step 1.1: confirm target databases exist
- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -Atc \"SELECT datname FROM pg_database WHERE datname IN ('aiqadam_test','aiqadam_qa');\""`
- Exit code: 0
- Output:
  ```
  aiqadam_test
  aiqadam_qa
  ```
- Result: success — both databases present.
- Backup taken: n/a (read-only)

#### Step 1.2: confirm table shapes (schema introspection)
- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -c \"\\d directus_roles\" -c \"\\d directus_policies\" -c \"\\d directus_access\" -c \"\\d directus_permissions\""`
- Exit code: 1
- Output (verbatim):
  ```
  Did not find any relation named "directus_roles".
  Did not find any relation named "directus_policies".
  Did not find any relation named "directus_access".
  Did not find any relation named "directus_permissions".
  ```
- Result: **failure**
- Backup taken: n/a (read-only step, nothing to back up)

Per role instructions, execution stopped here rather than inventing a substitute schema/database. Two plan-sanctioned diagnostic queries were run to characterize the failure (the fallback catalog query text is drawn verbatim from the plan's own step 1.5 fallback clause, applied one step earlier since the failure surfaced at 1.2, not 1.5):

- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -Atc \"SELECT tablename FROM pg_tables WHERE tablename LIKE 'directus_%' ORDER BY 1;\""`
- Exit code: 0
- Output: *(empty — zero rows)*
- Finding: no table whose name starts with `directus_` exists anywhere in `aiqadam_qa`'s searchable schema path.

- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -Atc \"SELECT count(*) FROM pg_tables WHERE schemaname = 'public';\""`
- Exit code: 0
- Output: `8`
- Finding: `aiqadam_qa`'s public schema is not empty (8 tables exist), so this is not a case of an uninitialized/empty database — some other application owns those 8 tables, or Directus's schema lives in a non-`public` schema, or Directus is actually configured against `aiqadam_test` rather than `aiqadam_qa`. None of these three possibilities was distinguished; doing so is out of this plan's scope (no step in the approved plan covers identifying an alternate schema/database).

Steps 1.3 through 1.7 were **not attempted** — they all depend on 1.2's schema being present.

### Rollback executed

Not needed. Every command run (plan-defined and the two plan-sanctioned fallback catalog queries) is a pure read: `cat` of a config file, `psql -Atc SELECT`, `psql \d`, and `pg_tables` catalog queries. Nothing was created, altered, or deleted on the host, in either database, or in any container.

### Resources changed

- Files on host: none.
- Services restarted: none.
- External resources changed: none.

## Issues / risks

- **Blocking: the plan's premise about where Directus's RBAC schema lives is factually wrong for this host.** `aiqadam_qa` exists and is non-empty, but holds no `directus_*` tables at all. This is the same class of "STOP — premise is wrong" condition step 1.1 itself defines for the case where the database is entirely absent; it applies here one level down, where the database exists but does not hold the expected application schema. Retrying step 1.2 verbatim will fail identically every time — this needs a redesigned step 04, not a retry of step 06.
- **Two live, plan-adjacent hypotheses are now available for the next solution-designer pass**, neither confirmed nor ruled out by this step: (a) Directus's schema may actually live in `aiqadam_test` (the sibling database in the same container) rather than `aiqadam_qa`; (b) it may live in a non-`public` schema inside `aiqadam_qa` that a schema-qualified or `search_path`-aware query would find. A third, lower-probability possibility: the running `aiqadam-qa-directus-1` container's actual DB connection configuration may point somewhere this plan never considered — checking its connection *settings* (host/port/dbname only, no credential values) against its compose env would give ground truth rather than continuing to infer from `landscape/` doc commentary.
- **This is the third executor-infra attempt on this run, and the second consecutive wrong assumption about this same diagnostic's target.** Attempt 1 had the wrong role name (`postgres` vs `aiqadam`); this attempt has the right role and right auth method but the wrong schema location. Worth surfacing to the user as a pattern — the plan's source material may benefit from a live-verification pass (e.g., checking the Directus container's actual configured DB target) before a fourth attempt is designed, rather than continuing to correct one layer at a time.
- **Zero secret handling occurred in this run**, consistent with the plan's entire design intent — Branch A made `POSTGRES_PASSWORD` (old value or the T-0138-flagged exposed value) completely unnecessary. T-0138's in-flight rotation is untouched and irrelevant to this failure.
- **All four of the plan's substantive RBAC diagnostic questions remain unanswered.** T-0136's underlying blocker (why the QA Directus admin token gets 403 on `content_documents` writes) is no closer to resolution. This is purely a wrong-target failure, not a finding about the RBAC data itself.
- No destructive action occurred. Blast radius realized is zero, consistent with the plan's `estimated_reversibility: full` framing.

## Open questions (optional)

- Should the next solution-designer step check the Directus container's own live DB connection configuration (`aiqadam-qa-directus-1`'s compose env — `DB_DATABASE`/`DB_HOST`/`DB_PORT`/`DB_SCHEMA` names only, no credential values) as ground truth for where its schema actually lives, rather than continuing to infer from `landscape/` doc commentary that has now been wrong twice in two attempts?
- Should `landscape/hosts/pro-data-tech-qa.md` be updated (at step 08, by the appropriate agent) to explicitly record which database and schema Directus's system tables actually live in, once determined, so future plans don't repeat this assumption a third time?
- Given the two consecutive wrong assumptions (role name, then schema location), does the user want the next solution-designer pass to include one additional live discovery step up front (checking the Directus container's own config) even though that adds a step beyond the minimal diagnostic scope, to avoid a fourth attempt correcting a third wrong assumption?
