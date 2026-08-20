---
id: T-0138-rotate-qa-postgres-password
title: Rotate POSTGRES_PASSWORD for ai-qadam-test-db-1 (aiqadam superuser) after transcript exposure during T-0136
kind: task
status: done
priority: P1
created: 2026-08-20
updated: 2026-08-20
closed: 2026-08-20
outcome: succeeded
created_by: manual
source_runs: [2026-08-20-seed-content-documents-qa-001]
executed_by_runs: [2026-08-20-rotate-qa-postgres-password-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0136-seed-content-documents-qa, T-0137-rotate-qa-directus-admin-token]
estimated_blast_radius: medium
estimated_reversibility: partial
---

# Rotate POSTGRES_PASSWORD for ai-qadam-test-db-1 (aiqadam superuser) after transcript exposure during T-0136

## Why

During `2026-08-20-seed-content-documents-qa-001` (executing T-0136's RBAC
investigation), the `executor-infra` subagent ran an off-plan but
necessary diagnostic (`docker exec ai-qadam-test-db-1 env | grep -i
POSTGRES`) to understand why the plan's assumed `-U postgres` connection
failed. The command's output — by nature of dumping environment
variables — included `POSTGRES_PASSWORD` in plaintext for the
`ai-qadam-test-db-1` container's `aiqadam` superuser, appearing in this
session's transcript for one turn.

**Scope of exposure:** local Claude Code session transcript only. Not
written to any file, not committed, not pushed, not posted anywhere
network-reachable. Self-reported immediately per the executor's own
"flag transparently" instruction — not discovered after the fact.

**Blast radius note (higher than T-0137):** unlike the Directus admin
token (which only Directus itself and the `api` container's compose
interpolation depended on), this is a **Postgres cluster superuser
password** — every service that connects to `ai-qadam-test-db-1`
(both the `aiqadam_test` and `aiqadam_qa` databases live in this one
container/cluster) authenticates through this one credential. Rotating
it requires updating every consumer in lock-step, not just one `.env`
file. `estimated_blast_radius: medium` / `estimated_reversibility:
partial` reflects this — this is NOT a low-risk, trivially-reversible
change the way T-0137's Directus token rotation was.

**User decision (2026-08-20):** proceed with rotation via the normal
approval-gated infrastructure workflow — user gave standing approval to
work through to a result without pausing for a separate confirmation
round-trip per step, but this task still goes through
`NEEDS_APPROVAL` per `shared/approval-protocol.md`'s explicit "secret
rotations" rule (this is not waived by the standing-approval
instruction — it changes how much the orchestrator checks in between
steps, not whether the protocol's own gates still apply).

## What done looks like

- [x] **Enumerate every consumer of this credential BEFORE rotating**
      (this is the step T-0137 didn't need, since only 2 services
      depended on that token) — at minimum: `ai-qadam-test-db-1` itself
      (bootstrap env var, read only at first-ever container init, NOT
      re-read on restart per standard Postgres Docker image behavior —
      confirm this empirically, don't assume), and every app container
      that holds a `DATABASE_URL`/`PG*` connection string referencing
      `aiqadam`'s password — likely `aiqadam-qa-api-1` (via its own
      `deploy/.env` or compose file) and possibly `aiqadam-test`
      containers sharing the same DB instance (the `aiqadam_test`
      database, per `landscape/hosts/pro-data-tech-qa.md`, predates the
      QA app stack — check what if anything still reads it).
- [x] New password generated.
- [x] New password applied at the Postgres role level (`ALTER ROLE
      aiqadam WITH PASSWORD '...'` — via `psql`, value substituted
      in-session only, never written to disk/logged, same discipline
      as T-0137).
- [x] Every enumerated consumer's own credential reference updated to
      match (their own `.env`/compose files), and those services
      restarted/recreated as needed to pick up the change (Docker env
      vars are not hot-reloaded, per the T-0125/T-0137 precedent).
- [x] Old password confirmed dead (a connection attempt using the OLD
      password fails to authenticate).
- [x] New password confirmed working for every enumerated consumer —
      not just a bare `psql` connection test, but each dependent
      service's own actual health check (e.g. `aiqadam-qa-api-1`'s
      `/health`, confirming its DB connection pool actually
      reconnected successfully, not just that the container is
      running).
- [x] `landscape/secrets-inventory.md` updated with the new rotation
      date (value never recorded).

## Result

Rotation completed successfully but not cleanly end-to-end in a single
pass — see run [`2026-08-20-rotate-qa-postgres-password-001`](../runs/2026-08-20-rotate-qa-postgres-password-001/)
for the full account.

**Plan (2 attempts):** attempt 1 of the solution-designer step
([archived](../runs/2026-08-20-rotate-qa-postgres-password-001/.attempts/step-04-solution-designer-attempt-1.md))
surfaced three open questions during read-only discovery (an
uncatalogued `authentik` database with live password-authenticated
connections; a wrong trust/password auth-boundary hypothesis that
would have made the original Phase 3.1/3.2 verification meaningless;
an unresolved `DATABASE_URL` key). Attempt 2
([`step-04-solution-designer.md`](../runs/2026-08-20-rotate-qa-postgres-password-001/step-04-solution-designer.md))
closed all three, identified Authentik's `authentik-server`/`authentik-worker`
containers as two more real consumers of the same shared
`AIQADAM_QA_POSTGRES_PASSWORD` variable (4 consumers total, not the
1–2 originally scoped), and corrected the verification method. This
plan was `NEEDS_APPROVAL` (unconditional for secret rotations) and was
approved by the user
([`step-05-user-approval.md`](../runs/2026-08-20-rotate-qa-postgres-password-001/step-05-user-approval.md)).

**Execution (1 planned attempt, 1 unplanned Orchestrator takeover):**
the subagent originally assigned to execute the approved plan
completed Phase 0 (discovery) and most of Phase 2 (rotate + apply) —
`ALTER ROLE`, both `.env` backups, `POSTGRES_PASSWORD` and
`AIQADAM_QA_POSTGRES_PASSWORD` updated, all four consumer containers
recreated — then **stalled**: it launched a background SSH task and
stopped calling tools entirely without waiting for or checking the
result, and without writing a completed handoff
(the earlier `attempt-1` archived under `.attempts/` is a fully-formed
`BLOCKED` handoff against the *original*, pre-revision plan — an
unrelated, earlier event; there is no second archived attempt for this
stall, consistent with a stall producing no handoff at all rather than
a completed retry). This left `aiqadam-qa-api-1` crash-looping live in
a partially-rotated state with nothing in the run directory signaling
it.

The Orchestrator (direct, not a subagent) took over, found the
crash-loop, and diagnosed + fixed two real bugs along the way (full
detail in
[`step-06-executor-infra.md`](../runs/2026-08-20-rotate-qa-postgres-password-001/step-06-executor-infra.md)):

1. **`DATABASE_URL` gap.** `api` reads its Postgres connection string
   from a separate `DATABASE_URL` key in `deploy/.env` (via
   `env_file`), not from `AIQADAM_QA_POSTGRES_PASSWORD` directly — the
   exact key the approved plan's Phase 0.6a was designed to resolve,
   but the stalled run's Phase 2 never got to updating it. Fixed by
   syncing `DATABASE_URL`'s password segment to the new value.
2. **URL-encoding bug.** The new password (generated via `openssl rand
   -base64 24`, per the plan) contains a `/` character — a valid
   base64 character but an unescaped URL path-separator, which broke
   `DATABASE_URL`'s parser once embedded raw. This is a genuine gap in
   the plan itself (`ALTER ROLE` and flat `.env` lines don't care about
   special characters; a connection-string URL does), not an execution
   error. Fixed by percent-encoding the password before re-embedding.
   `api` came up healthy after this second fix.

The approved plan's own Phase 3.1/3.2 verification command
(`--network container:ai-qadam-test-db-1 -h 172.18.0.1`) also did not
work as written — it shares the *target* container's own network
namespace, making `172.18.0.1` the gateway as seen from inside that
namespace, not a valid peer to dial (produced "connection refused,"
not an auth result). Corrected empirically: `ai-qadam-test-db-1` lives
on user-defined bridge network `ai-qadam-test_default` (gateway
`172.18.0.1`, container's own IP `172.18.0.2`); the working method is
a throwaway `postgres:16-alpine` container attached to that same named
bridge network, connecting to the DB **by container name**
(`-h ai-qadam-test-db-1`), not by IP.

**Final verified state** (independently re-confirmed by step-07
execution-validator, PASS on every re-checkable point including the
stalled-subagent narrative itself — see
[`step-07-execution-validator.md`](../runs/2026-08-20-rotate-qa-postgres-password-001/step-07-execution-validator.md)):
old password confirmed dead, new password confirmed working, via the
corrected bridge-network method. All four consumer containers healthy
via real DB-backed checks — `api` (`/health` 200), `directus`
(`/server/ping` 200, `/rules` content intact), `authentik-server`/
`authentik-worker` (`/-/health/ready/` 200 plus an `ak shell` ORM
count of 13 users). `ai-qadam-test-db-1` itself confirmed not
restarted. No secret value was ever printed, logged, or written to any
file or handoff at any point, including during the unplanned recovery
work.

**Deviations from the original checklist:** none in substance — every
item above is satisfied — but the path to get there included the
unplanned Orchestrator takeover and both bugs described above, neither
of which the original plan's checklist anticipated by name (though the
task's own "err on the side of over-enumerating consumers" warning
proved prescient for `DATABASE_URL`).

**Follow-ups filed:** [T-0140](T-0140-executor-stall-without-handoff-process-gap.md)
(the stalled-subagent process gap — a stall-without-handoff after a
state-changing action is more dangerous than a clean `BLOCKED`, since
it leaves live state changed with no explanation).

## Notes

- This is a **secret rotation** — per `workflows/infrastructure.md` /
  `shared/approval-protocol.md`, this ALWAYS requires `NEEDS_APPROVAL`
  at step 04, never auto-approved (`PASS`), regardless of the standing
  "keep going" instruction the user gave for the surrounding
  investigation work — that instruction relaxed the check-in cadence,
  not this protocol gate.
- **This is materially riskier than T-0137.** Getting the consumer
  enumeration wrong (missing a service that still uses the old
  password) would break that service silently until its next
  connection-pool retry/restart surfaces the auth failure — potentially
  including the `aiqadam_test` database's own consumers, which this
  task's originating context (T-0136) never needed to touch or
  understand. Err on the side of over-enumerating consumers before
  rotating, not under.
- Full detail on the originating exposure:
  `runs/2026-08-20-seed-content-documents-qa-001/step-06-executor-infra.md`
  ("Off-plan diagnostic" and "Issues / risks" sections).
- Sequencing: this rotation is independent of T-0136's RBAC-connection
  fix (which should use `-U aiqadam` with THIS password, or discover
  whether local trust auth covers it — see T-0136's own next steps) —
  T-0136's redesigned diagnostic plan should use whichever password is
  CURRENT at the time it runs. If this rotation task completes first,
  T-0136 must use the NEW password; if T-0136's diagnosis runs first
  (e.g. because it turns out `pg_hba.conf` trusts `aiqadam` locally
  with no password needed at all, in which case this rotation's urgency
  for THAT specific use case drops, though the rotation is still
  warranted for the transcript-exposure reason regardless), it should
  use whatever is current then. Do not let these two efforts race in a
  way that leaves either using a stale value.

## History
- 2026-08-20: created (manual, on behalf of a self-reported secret
  exposure during T-0136's RBAC investigation, run
  `2026-08-20-seed-content-documents-qa-001`)
- 2026-08-20: status → `in-progress`, run `2026-08-20-rotate-qa-postgres-password-001`
- 2026-08-20: status -> done, outcome succeeded, run 2026-08-20-rotate-qa-postgres-password-001, commit <pending>
