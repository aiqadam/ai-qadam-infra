---
id: T-0137-rotate-qa-directus-admin-token
title: Rotate QA Directus admin token/password after transcript exposure during T-0136
kind: task
status: done
priority: P1
created: 2026-08-20
updated: 2026-08-20
closed: 2026-08-20
outcome: succeeded
created_by: manual
source_runs: [2026-08-20-seed-content-documents-qa-001]
executed_by_runs: [2026-08-20-rotate-qa-directus-token-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0136-seed-content-documents-qa]
estimated_blast_radius: low
estimated_reversibility: full
---

# Rotate QA Directus admin token/password after transcript exposure during T-0136

## Why

During `2026-08-20-seed-content-documents-qa-001` (executing T-0136), the
`executor-cicd` subagent ran a disambiguation command against
`/opt/apps/aiqadam-qa/deploy/.env` intended to print only comment/context
lines around two candidate token variable names
(`grep -n -B2 -A0 -E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN)=' deploy/.env
| grep -v -E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN)='`). The intended
`-v` exclusion filter did not suppress the matched lines as designed, so
the actual plaintext values of `DIRECTUS_TOKEN` /
`DIRECTUS_ADMIN_TOKEN` (identical values — the same secret referenced by
two variable names) and an adjacent `DIRECTUS_ADMIN_PASSWORD` appeared in
that subagent's tool-call output for one turn.

**Scope of exposure:** local Claude Code session transcript only (this
management workstation). Not committed to any file, not pushed to any
git remote, not posted anywhere network-reachable. No evidence of
external access. Self-reported immediately by the executor per its own
"stop and report" instruction — not discovered after the fact.

**User decision (2026-08-20):** rotate proactively rather than treat as
acceptable risk, per standard practice for any credential that appears
somewhere it shouldn't, even briefly and even in a private, single-viewer
session.

## What done looks like

- [x] New value generated for the QA Directus admin token
      (`DIRECTUS_TOKEN` / `DIRECTUS_ADMIN_TOKEN` — confirm during
      execution whether these are truly the same secret under two names,
      as observed during T-0136's Phase 1 discovery, or need independent
      rotation). Confirmed: same Directus identity at rotation time
      (same-identity branch); both `.env` keys now hold the same new value.
- [x] New value generated for `DIRECTUS_ADMIN_PASSWORD`.
- [x] Both new values applied on `pro-data-tech-qa` (Directus's own admin
      user record + `/opt/apps/aiqadam-qa/deploy/.env`) and Directus
      restarted/reloaded so the new token is what's actually live.
      (Rotation confirmed live via `PATCH /users/me`; no Directus restart
      required per Directus 11.17.4's own mechanism — DB-row fields read
      per-request, not env-seeded on boot.)
- [x] Old token confirmed revoked (a request using the OLD token value
      returns 401/403, not 200) — do not just add a new token alongside
      the old one; the old one must stop working.
- [x] New token confirmed working: `curl .../users/me` with the new
      token returns 200. Write-to-`content_documents` verification
      (once T-0136's RBAC blocker — see `T-0136-seed-content-documents-qa.md`
      and its follow-up RBAC task — is separately resolved) remains
      explicitly out of this task's scope, per the approved plan; T-0136's
      retry may now proceed against the new token.
- [x] `qa.aiqadam.org` itself (the app, not just Directus admin) confirmed
      still healthy after rotation — the app's own Directus-reading paths
      (public content pages, `/press`, `/rules` once seeded, etc.) must
      not break from a token/password change if the app uses a
      *different* credential for its own reads (confirm which credential
      the running app container actually uses before assuming zero
      blast radius on the app itself). Confirmed: `api` consumes
      `DIRECTUS_ADMIN_TOKEN` via compose interpolation (digest-matched);
      recreated and healthy; `/health` and `/press` both 200 post-rotation.
- [x] `landscape/secrets-inventory.md` updated with the new
      rotation date for this secret (value never recorded, per this
      repo's hard rule — reference by name/location and rotation date
      only).

## Result

Executed via run
[`2026-08-20-rotate-qa-directus-token-001`](../runs/2026-08-20-rotate-qa-directus-token-001/)
(plan: [step-04](../runs/2026-08-20-rotate-qa-directus-token-001/step-04-solution-designer.md),
approval: [step-05](../runs/2026-08-20-rotate-qa-directus-token-001/step-05-user-approval.md),
execution: [step-06](../runs/2026-08-20-rotate-qa-directus-token-001/step-06-executor-infra.md),
validation: [step-07](../runs/2026-08-20-rotate-qa-directus-token-001/step-07-execution-validator.md),
verdict `PASS`).

- Live discovery (Phase 0) found `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN`
  resolved to the **same** Directus identity (`admin@aiqadam.org`) despite
  holding different literal `.env` strings — a correction of T-0136's
  original "same secret under two names" premise; the two `.env` keys had
  drifted into different literal strings while both still authenticated
  as the same admin DB row. `DIRECTUS_ADMIN_TOKEN` confirmed (digest match)
  as the canonical, compose-wired credential the `api` container actually
  consumes.
- Directus 11.17.4 confirmed; rotation mechanism confirmed as
  `PATCH /users/me` (live, no Directus restart needed).
- `DIRECTUS_ADMIN_TOKEN` and `DIRECTUS_ADMIN_PASSWORD` rotated via
  `PATCH /users/me`. `DIRECTUS_TOKEN`'s `.env` line updated to the same
  new admin-token value (same-identity branch — no separate REST call
  needed; old value already dead as a side effect of the admin-token
  rotation).
- `deploy/.env` backed up first
  (`deploy/.env.pre-T0137.<timestamp>.bak`, 1563 B, on-host only).
- `aiqadam-qa-api-1` recreated (mandatory — env vars are not
  hot-reloaded); came up healthy. `web-next` confirmed to reference zero
  Directus env vars, correctly not recreated.
- All old values confirmed dead (401/403 via `GET /users/me`); all new
  values confirmed live (200). App health confirmed post-rotation:
  `https://qa.aiqadam.org/health` → 200, `/press` → 200.
- No secret value was printed, logged, or written anywhere in this run
  (output-hygiene discipline from T-0136's exposure incident held
  throughout).
- `landscape/secrets-inventory.md` created for the first time in this
  checkout (git-ignored, was previously absent) with rotation-date
  entries for all three secret names.
- No deviations from the "What done looks like" checklist — every item
  completed as specified. The write-permission check against
  `content_documents` remains explicitly out of scope, tracked by
  T-0136's separate RBAC-gap follow-up, which may now proceed since this
  rotation is complete.

## Notes

- This is a **secret rotation** — per `workflows/infrastructure.md` /
  `shared/approval-protocol.md`, this ALWAYS requires `NEEDS_APPROVAL`
  at step 04, never auto-approved (`PASS`), regardless of blast radius
  estimate. Do not let solution-designer auto-approve this one.
- Old value must be confirmed dead, not just superseded — a rotation
  that leaves the old token functional defeats the purpose of rotating
  in response to an exposure.
- This task blocks nothing else directly, but note `T-0136`'s eventual
  retry (once its separate RBAC permission gap is resolved) will need
  the NEW token value, not the one that was exposed — sequence-check
  that T-0136's retry happens after this rotation completes, not before,
  so the retry doesn't end up re-using the compromised value.
- Full detail on the originating exposure:
  `runs/2026-08-20-seed-content-documents-qa-001/step-06-executor-cicd.md`
  ("Issues / risks" section, self-reported by the executor).

## History
- 2026-08-20: created (manual, on behalf of a self-reported secret
  exposure during T-0136's execution, run
  `2026-08-20-seed-content-documents-qa-001`)
- 2026-08-20: status → `in-progress`, run `2026-08-20-rotate-qa-directus-token-001`
- 2026-08-20: status -> done, outcome succeeded, run 2026-08-20-rotate-qa-directus-token-001, commit <pending>
