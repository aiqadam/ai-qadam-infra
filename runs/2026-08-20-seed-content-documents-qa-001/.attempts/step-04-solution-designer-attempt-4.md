---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-08-20T19:05:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-04-solution-designer-attempt-3.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-infra-attempt-1.md
  - landscape/hosts/pro-data-tech-qa.md
  - tasks/T-0138-rotate-qa-postgres-password.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-01-task-reader.md
  - .claude/agents/solution-designer.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
next_step_hint: >-
  Verdict PASS — orchestrator skips step 05, advances directly to
  executor-infra (step 06). Phase 0 is a single read-only pg_hba.conf
  check that determines which of two mutually exclusive branches the
  executor takes. Branch A (local trust covers `aiqadam`): proceed with
  the same four read-only SELECT diagnostics as attempt 3, using
  `-U aiqadam` in place of the nonexistent `-U postgres`, still zero
  secret handling. Branch B (trust does not cover `aiqadam`): the
  executor MUST NOT fetch or use POSTGRES_PASSWORD (old OR the value
  observed incidentally in attempt-1's transcript) under any
  circumstance — that credential is mid-rotation under T-0138 and using
  it now would be knowingly using a compromised secret while a rotation
  is in flight. In Branch B the executor stops after the pg_hba.conf
  check and emits BLOCKED with the two-option note from this handoff's
  Issues/risks verbatim in its own handoff, so the orchestrator can put
  the choice to the user rather than the executor deciding unilaterally.
  Either way, the four RBAC SELECT queries themselves (unchanged from
  attempt 3, still gated on live \d schema introspection) remain valid
  and are only reached in Branch A.
retry_of: step-04
---

## Summary

A two-phase, entirely read-only plan: first, inspect `pg_hba.conf` inside `ai-qadam-test-db-1` to determine (without touching any secret) whether local Unix-socket trust authentication covers the `aiqadam` role — the cluster's actual and only superuser, per attempt 1's finding that no `postgres` role exists — and only if it does, proceed with the same four narrowly-scoped `SELECT` diagnostics against Directus's RBAC tables as attempt 3, now correctly using `-U aiqadam` with no password; if trust does not cover `aiqadam`, the plan halts at that checkpoint and the executor must emit `BLOCKED` rather than reach for `POSTGRES_PASSWORD`, since that credential is currently mid-rotation under T-0138 and using it — even though technically still valid until rotation completes — would mean knowingly relying on a credential already flagged compromised. No fix, no seed-script run, no schema change, and no rotation happen in this plan either way.

## Details

### What changed from attempt 3

Attempt 3's entire connection strategy assumed a `postgres` cluster-superuser role reachable via local Unix-socket trust auth, to avoid all secret handling. Attempt 1 (executor-infra) proved that role does not exist on `ai-qadam-test-db-1` — the container was initialized with `POSTGRES_USER=aiqadam`, so `aiqadam` is the cluster's bootstrap/only superuser. Attempt 1's off-plan diagnostic (`docker exec ... env`) additionally, incidentally, exposed `POSTGRES_PASSWORD` in plaintext in that session's transcript — never written to any file, never reused — which is why a separate task, T-0138, now exists to rotate it. This redesign:

1. Replaces the failed `-U postgres` assumption with a live, read-only check of whether trust auth extends to `-U aiqadam` — the cleanest possible fix if true, preserving attempt 3's entire "zero secret handling" rationale unchanged.
2. Explicitly forbids the executor from touching `POSTGRES_PASSWORD` (old value, or the value glimpsed in attempt 1's transcript) anywhere in this plan, in either branch. That credential is out of scope for this diagnostic — it belongs to T-0138, a separate, already-created, already-`NEEDS_APPROVAL`-gated rotation task. Using it here, even "just to unblock a read," would preempt that task's own approval gate and use a credential already flagged for rotation because of exposure.
3. Does not attempt to design around a missing password by any other means (no fetching it from `.env`, no asking the executor to derive it) — if local trust doesn't cover `aiqadam`, this diagnostic plan's only correct move is to stop and surface the choice to the user, not solve it unilaterally.

### Where the data lives (unchanged from attempt 3)

Per `landscape/hosts/pro-data-tech-qa.md`: Directus's Postgres backend is `ai-qadam-test-db-1` (image `pgvector/pgvector:pg16`), Compose project `ai-qadam-test`, published on loopback `127.0.0.1:3112` → `5432`. The `aiqadam_qa` database (created by T-0110) holds Directus's own system schema (`directus_roles`, `directus_policies`, `directus_access`, `directus_permissions`) — this is where the RBAC diagnosis for role `b3350300-c590-430f-b4ea-c020638bc2d1` / policy `5029fc70-bcec-4dc6-a549-ab42b5ac5377` must run. `aiqadam` is confirmed (attempt 1) to be the cluster's only superuser; no separate `postgres` role exists.

### Plan

**Phase 0 — Determine connection method (read-only, no secret touched)**

0.0. **Check whether local Unix-socket trust auth covers `aiqadam` for local connections** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 cat /var/lib/postgresql/data/pg_hba.conf"
```
— verification: inspect the output for the line(s) governing `local` connections (method column). Two possible outcomes:
  - **Branch A — trust covers it:** a `local   all   all   trust` line (or an equivalent line explicitly matching `all`/`aiqadam` with method `trust`, with no more specific `local ... aiqadam ... md5`/`scram-sha-256` line preceding it that would take precedence) is present. Proceed to Phase 1 using `-U aiqadam`, no password.
  - **Branch B — trust does not cover it:** the `local` line(s) specify `md5`, `scram-sha-256`, `peer`, or any non-`trust` method for `all`/`aiqadam`. **STOP HERE.** Do not proceed to Phase 1. Do not read, derive, or use `POSTGRES_PASSWORD` from any source (container env, `.env` file, attempt 1's transcript, or anywhere else). Emit `BLOCKED` per this handoff's Issues/risks section, verbatim, so the orchestrator can put the choice to the user.

This command reads a config file only — no query, no connection attempt with credentials, no secret in the output (`pg_hba.conf` contains auth *method* configuration, not credential values).

**Phase 1 — RBAC diagnosis (read-only, only reached in Branch A)**

Identical in structure and intent to attempt 3's Phase 0.2–0.7, with `-U postgres` replaced by `-U aiqadam` throughout and no `-u postgres` container-user flag needed (the socket connection's Postgres *role* is selected via `psql -U`, independent of which OS user runs `docker exec`; run as the default container user since local trust — confirmed in Phase 0 — does not require a specific `docker exec -u`).

1.1. **Confirm the target database exists** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d postgres -Atc \"SELECT datname FROM pg_database WHERE datname IN ('aiqadam_test','aiqadam_qa');\""
```
— verification: output contains both `aiqadam_test` and `aiqadam_qa`. If `aiqadam_qa` is absent, STOP — emit `BLOCKED` (premise about where Directus's schema lives is wrong).

1.2. **Confirm table shapes (schema introspection)** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -c \"\\d directus_roles\" -c \"\\d directus_policies\" -c \"\\d directus_access\" -c \"\\d directus_permissions\""
```
— verification: all four `\d` calls return a column listing. Executor records the actual admin-access-equivalent column name(s) found, and uses them (not the example names below) in 1.3–1.6 if they differ.

1.3. **Question 1 — does the role row exist, and what does its own admin-access-equivalent column (if any) say?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -c \"SELECT id, name, icon, description FROM directus_roles WHERE id = 'b3350300-c590-430f-b4ea-c020638bc2d1';\""
```
— verification: exactly one row or zero rows (both informative — record which). If 1.2 showed `directus_roles` has its own admin-access-equivalent column, re-run including it by name.

1.4. **Question 2 — does the policy row exist, and what does ITS admin_access say?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -c \"SELECT id, name, icon, admin_access, app_access FROM directus_policies WHERE id = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: exactly one row (record `admin_access`/`app_access` verbatim) or zero rows. Zero rows would fully explain the REST 403/empty-list finding from attempt 2. Adjust column names to 1.2's real schema if they differ.

1.5. **Question 3 — is the role↔policy junction intact?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -c \"SELECT * FROM directus_access WHERE role = 'b3350300-c590-430f-b4ea-c020638bc2d1' OR policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: record row count (0, 1, or >1) and whether `role`/`policy` are both non-null and match in the same row. If `\d directus_access` in 1.2 reported "did not find relation," fall back to:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -Atc \"SELECT tablename FROM pg_tables WHERE tablename LIKE 'directus_%' ORDER BY 1;\""
```
and identify the real junction table name before re-running.

1.6. **Question 4 — does `directus_permissions` have any rows at all for this identity?** — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -c \"SELECT id, policy, collection, action FROM directus_permissions WHERE policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```
— verification: record row count and, if non-zero, `(collection, action)` pairs. Zero rows is the expected/consistent finding if `admin_access = true` (bypass-all needs no explicit grants). If 1.2 shows `directus_permissions` still carries a `role` column directly, also run:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_qa -c \"SELECT id, role, policy, collection, action FROM directus_permissions WHERE role = 'b3350300-c590-430f-b4ea-c020638bc2d1' OR policy = '5029fc70-bcec-4dc6-a549-ab42b5ac5377';\""
```

1.7. **Synthesize the finding (no command — executor's own summary).** Same X/Y/Z/other scenario classification as attempt 3:
   - **Scenario X:** policy row missing (1.4 = zero rows) → role has no working policy → explains every 403.
   - **Scenario Y:** policy row exists, `admin_access = true`, junction intact, zero permission rows → correct bypass-all config; REST 403 would then be a genuine Directus-level bug unrelated to the RBAC data.
   - **Scenario Z:** policy row exists, `admin_access = false`/NULL → confirms the "missing grant" hypothesis at the DB level.
   - **Any other combination:** report raw findings verbatim; do not force-fit.

### Rollback

Not applicable in either branch. Phase 0 reads a config file; Phase 1 (if reached) is exclusively `SELECT`/`\d`/catalog reads. Nothing is created, altered, or deleted anywhere. If Branch B is hit, the plan halts with zero commands beyond the Phase 0 config read — nothing to roll back there either.

### Verification (for step 07)

- **On-host:**
  - 0.0's `pg_hba.conf` local-auth-method finding recorded verbatim (which branch was taken, and the exact matching line(s)).
  - If Branch A: 1.1's database-existence confirmation; 1.2's four `\d` outputs with real column names identified; 1.3–1.6's row contents/counts recorded per question; 1.7's scenario classification (X/Y/Z/other) stated explicitly.
  - If Branch B: confirmation that no command beyond 0.0 was run, and that no secret value (from any source) appears anywhere in the executor's handoff or this run's artifacts.
- **External:** none — pure on-host/in-container diagnostic; nothing externally observable changes.

### Resources used

- **Secrets (by name):** none read or used in Branch A (local trust auth requires no credential). In Branch B, explicitly **none** — this is the entire point of the halt; `POSTGRES_PASSWORD` (old value or the T-0138-flagged exposed value) is deliberately not touched by this plan under any circumstance.
- **Files modified on host:** none.
- **Files modified in this repo (`landscape/`), to be applied at step 08:** none from this step itself. If Branch A completes, the executor's findings should feed a follow-up solution-designer fix plan; if Branch B is hit, no landscape update is warranted beyond what the orchestrator/user decide about sequencing with T-0138.
- **External APIs called:** none.

### Estimated impact

- **Downtime:** none in either branch.
- **Affected services:** none, functionally. `pg_hba.conf` read and (if Branch A) a handful of trivial `SELECT`s against small system tables — negligible load on `ai-qadam-test-db-1`; no other consumer of the same Postgres instance is affected.
- **Reversibility:** fully reversible — nothing is modified in either branch.

## Issues / risks

- **Branch B requires a human decision this plan cannot make.** If `pg_hba.conf` shows local trust does NOT cover `aiqadam`, this diagnosis cannot proceed without a password, and the only currently-known password (`POSTGRES_PASSWORD`) is the exact credential flagged for rotation under T-0138 because of its transcript exposure. Using it now — even though it remains technically valid until T-0138's rotation completes — would mean knowingly using a credential already identified as compromised while its own rotation task is in flight. This diagnostic plan does not have standing to make that call unilaterally. **If Branch B is hit, the executor must emit `BLOCKED`** and the orchestrator should present the user with exactly two options, verbatim: **(1)** wait until T-0138's rotation completes, then re-run this diagnosis (a new step-04) using the NEW password sourced through T-0138's own proper channels (its handoff / `secrets-inventory.md` update), or **(2)** the user explicitly authorizes, right now, a one-time use of the current (soon-to-be-rotated) password for this specific read-only diagnostic — a decision only the user should make, not the designer or executor, since it means consciously accepting continued use of a flagged credential for one more read. Neither option is pre-selected by this plan.
- **This plan does not touch, reference, or depend on T-0138's rotation in Branch A.** If local trust covers `aiqadam` (the expected/hoped-for outcome, consistent with attempt 3's original zero-secret-handling design intent), this diagnosis and T-0138's rotation are fully independent and can proceed in either order with no coordination needed — noted explicitly since T-0138's own Notes section flags exactly this sequencing question.
- **Column-name assumptions in 1.3/1.4/1.6 are provisional**, gated on 1.2's live schema output, same caveat as attempt 3 (Directus's role→policy→permissions schema has shifted across major versions; this instance is pinned 11.17.4 per `pro-data-tech-qa.md`, but the plan still verifies live rather than assuming).
- **Using the `aiqadam` role (the cluster's actual superuser) rather than a lower-privilege role.** Unavoidable now that `postgres` is confirmed not to exist — `aiqadam` is the only role available and is guaranteed to see ground truth. Same acceptable-tradeoff reasoning as attempt 3 applied to `-U postgres`: momentary, `SELECT`-only, standard practice for inspecting a Postgres instance's own system state, and it deliberately excludes `directus_users` (no query in this plan touches that table).
- No item above is high-severity in the sense of touching prod, DNS, firewall, or an irreversible action — Branch B's flagged decision is a judgment call to surface to the user, not a plan defect, and the plan's own commands (Phase 0's config read, Phase 1's SELECTs) remain within `PASS` scope by the same reasoning attempt 3 used (narrowly scoped, read-only, no `directus_users`, structured findings only). The only reason this isn't reclassified as `NEEDS_APPROVAL` outright is that Phase 0's single command is unconditionally safe to run regardless of which branch it reveals, and Phase 1 is only reached in the branch where zero secrets are involved; Branch B's halt is itself the safety mechanism, not a gap in one.

## Open questions (optional)

None — verdict is `PASS`, not `BLOCKED`. All five `shared/approval-protocol.md` PASS conditions hold: (1)/(2) task frontmatter (`estimated_blast_radius: low` / `estimated_reversibility: full`, confirmed via `runs/.../step-01-task-reader.md`) unaffected, since nothing is written in either branch; (3) no irreversible step in the plan itself — Branch B is a clean halt, not an irreversible action; (4) no designer doubts about the plan's own correctness remain — the one prior unknown (which role/auth method actually works) is resolved by a live, gated Phase 0 check rather than assumed, and the one genuine open decision (Branch B's password question) is explicitly routed to the user via `BLOCKED`, not guessed at; (5) no Issues/risks item is high-severity in a way that would block Phase 0 from running — Branch B's fork is the plan correctly refusing to overreach, not a defect requiring `NEEDS_APPROVAL` on the read-only steps themselves.
