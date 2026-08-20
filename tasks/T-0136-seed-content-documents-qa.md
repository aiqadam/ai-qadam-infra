---
id: T-0136-seed-content-documents-qa
title: Seed content_documents collection on QA Directus (aiqadam FR-CMS-007)
kind: task
status: done
priority: P2
created: 2026-08-20
updated: 2026-08-20
closed: 2026-08-20
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-08-20-seed-content-documents-qa-001, 2026-08-20-rotate-qa-directus-token-001]
affects:
  - landscape/services.md
workflow: deploy-app
blocks: []
blocked_by: []
related: []
estimated_blast_radius: low
estimated_reversibility: full
---

# Seed content_documents collection on QA Directus (aiqadam FR-CMS-007)

## Why

`aiqadam/ai-qadam-platform` PR #272 (merged, `FR-CMS-007`) shipped a new
public page, `/rules` (Community Rules & Documents), on the aiqadam QA
deployment (`qa.aiqadam.org`). The page code and its Directus schema
(`content_pages`, `content_documents` collections, added to
`infrastructure/directus/bootstrap.sh`) are already live and working on
QA — visiting `qa.aiqadam.org/rules` renders the page correctly with no
error. The gap: `infrastructure/directus/seed-content-documents.sh` (a
new script in that same PR, which populates `content_documents` with 5
rows — the community's governance documents: Manifesto, Charter v0.1,
Kazakhstan MoU, Global Board Положение v1.0, Soglashenie v1.0) has never
been run against QA's Directus instance. Confirmed by grep across the
`aiqadam` repo: this script is not called from any deploy/CI automation
— `bootstrap.sh` itself is also not automated (it's run manually or via
`scripts/uat-seed.sh` for UAT setup), and the content-seed script is a
level further removed still. This was a known, disclosed gap in the
PR's own workflow artifacts (`.copilot/tasks/completed/wf-20260819-feat-212/`)
but was verified only against a local throwaway Directus container, not
against the real QA environment.

**User-visible symptom:** `qa.aiqadam.org/rules` currently renders "Пока
нет опубликованных документов." (no published documents) instead of the
5 governance document entries.

**Confirmed NOT a code defect** — this is purely missing data. The
seed script itself was verified end-to-end during the aiqadam workflow
(including a Windows/MSYS `ARG_MAX` bug fix, confirmed fixed and
verified against a live local Directus with all 5 documents seeding
correctly, largest at 43KB).

## What done looks like

- [x] **(added after first attempt)** QA Directus admin role confirmed
      to have create/update permission on `content_documents` — first
      attempt (run `2026-08-20-seed-content-documents-qa-001`) hit
      HTTP 403 on the very first item: the admin token authenticates
      fine but its role lacks a permission grant on this collection
      (`bootstrap.sh` created the collection + a PUBLIC read-only
      grant, but apparently no explicit Administrator/admin-role grant
      — Directus's built-in Administrator policy normally bypasses
      collection-level permission checks entirely, so this is worth
      re-investigating empirically rather than assuming a specific
      fix, e.g. confirm the admin user's actual role/policy assignment
      first). Grant (or fix) whatever is actually missing before
      retrying the seed step.
      **Turned out to be a red herring, not an actual RBAC gap:** the
      Administrator policy's real permission set (`admin_access: true,
      app_access: true`) was genuine bypass-all the entire time. Every
      403 was Directus correctly reporting that `content_documents`
      did not exist yet, not a permission grant issue. Diagnosis and
      resolution both happened this run, so this item is satisfied —
      see Result section.
- [x] QA Directus URL and admin token identified (per
      `landscape/secrets-inventory.md` / whatever this repo's normal
      secret-reference convention is for `pro-data-tech-qa`'s Directus
      instance — do not put the actual token value in this task file or
      any committed file).
- [x] `infrastructure/directus/seed-content-documents.sh` (from the
      `aiqadam/ai-qadam-platform` repo, current `main`) run against QA's
      Directus with `DIRECTUS_URL`/`DIRECTUS_TOKEN` pointed at QA.
- [x] Confirmed via Directus REST API (`GET
      <qa-directus-url>/items/content_documents`) that all 5 rows exist:
      `manifesto`, `charter-v0-1`, `kazakhstan-mou`,
      `global-board-polozhenie-v1`, `soglashenie-v1`.
- [x] Live browser/curl check: `https://qa.aiqadam.org/rules` lists all
      5 documents (not the empty-state message), and
      `https://qa.aiqadam.org/rules/charter-v0-1` (or another slug)
      renders full document content.
- [x] Superseded-label check: `global-board-polozhenie-v1` and
      `soglashenie-v1` pages show a "Superseded by Charter v0.1" label;
      the other 3 do not.

## Result

**Succeeded, after a long investigation (6+ solution-designer/executor
attempts across `runs/2026-08-20-seed-content-documents-qa-001/` and its
archived `.attempts/`) that worked through multiple root-cause
misdiagnoses before landing on the truth.**

**The journey:** the task was originally scoped as a pure content-seed
operation. The first attempt hit an HTTP 403 on the very first item,
which looked like an RBAC/permissions gap (the admin token authenticates
fine but apparently lacks a grant on `content_documents`) — this became
the "added after first attempt" checklist item above and drove several
subsequent attempts to investigate Directus policy/role/permission
plumbing (including discovering and correcting a mistaken identification
of which UUID was "the policy" — see
`runs/2026-08-20-seed-content-documents-qa-001/step-04-solution-designer.md`'s
root-cause recap). A parallel thread (`T-0137`) rotated
`DIRECTUS_ADMIN_TOKEN`/`DIRECTUS_ADMIN_PASSWORD` after a transcript-
exposure self-report during discovery, and disambiguated `DIRECTUS_TOKEN`
vs `DIRECTUS_ADMIN_TOKEN` as the same live credential under two `.env`
keys. None of this was the actual bug.

**The actual root cause**, confirmed by live evidence in the final
solution-designer pass: `content_pages` and `content_documents` did not
exist in QA's `directus_collections` table at all.
`infrastructure/directus/bootstrap.sh`'s FR-CMS-007 additions (from
`aiqadam` PR #272, merged, live in the checked-out code since) had never
actually been run to completion against this QA instance. RBAC was never
broken — the Administrator policy's real permission row
(`admin_access: true, app_access: true`) was genuine bypass-all the
entire time. Directus's own 403 message ("...or it does not exist") was
accurate about the "does not exist" half throughout every prior attempt.

**Resolution (run `2026-08-20-seed-content-documents-qa-001`, final
attempt):**
1. Ran `infrastructure/directus/bootstrap.sh` against QA — created
   `content_pages` and `content_documents` plus their PUBLIC read
   grants. All ~77 pre-existing collections confirmed idempotent no-op,
   with one exception: a dated, already-decided cleanup block
   (`F-S2.12 — drop F-S2.8.x operator_invites.* email-routing fields`,
   2026-05-25) dropped 7 legacy fields from the pre-existing
   `operator_invites` collection. This first surfaced as a `BLOCKED`
   verdict (executor-infra correctly halting per its plan's explicit
   STOP condition on unexpected pre-existing-collection modification —
   see archived
   `.attempts/step-06-executor-infra-attempt-5.md`), then was cleared
   by an out-of-band Orchestrator investigation confirming the drop is
   safe, dated, and already accounted for in live `apps/api` code
   (`admin-invites.controller.ts:51`, comment references the same
   `F-S2.12` cleanup) — not a new risk.
2. Ran `infrastructure/directus/seed-content-documents.sh` — 5/5
   governance-document rows seeded (manifesto, charter-v0-1,
   kazakhstan-mou, global-board-polozhenie-v1, soglashenie-v1).
3. Full external verification, independently re-confirmed by
   execution-validator (step 07, verdict PASS) via live public HTTPS
   probes: `/rules` lists all 5 documents (no more empty-state
   message), `/rules/charter-v0-1` renders full content, superseded
   labels present on exactly `global-board-polozhenie-v1` and
   `soglashenie-v1` and absent on the other 3, `/about`/`/history`/
   `/partners` all still 200 (no regression from `content_pages`
   existing).

**Deviation from the original plan, noted and accepted:** the approved
plan's Phase 4.1 verification command referenced a nonexistent field
(`superseded_by`); the executor self-corrected to the real field
(`status_label`) via a read-only introspection query rather than halting
per executor-infra.md's literal rule 1. The execution-validator
independently corroborated the corrected data from the external HTTPS
surface and assessed this as an acceptable one-time exception, not a
precedent — see step-07's "Issues / risks" for the full reasoning and
the recommendation to tighten rule 1 with a narrow carve-out (tracked as
an open question, not actioned in this task).

**Full historical record:** `runs/2026-08-20-seed-content-documents-qa-001/`
(final handoffs: `step-04-solution-designer.md`,
`step-05-user-approval.md`, `step-06-executor-infra.md`,
`step-07-execution-validator.md`) plus its `.attempts/` directory,
which preserves every earlier misdiagnosis and dead end for anyone
reconstructing the investigation later.

**Follow-ups filed as a result of this investigation:**
- `T-0139` (observation) — check for other undiscovered QA Directus
  schema drift, since bootstrap.sh had apparently never been run to
  completion against QA before today.
- Open question (not filed as a task; see step-07's recommendation) —
  whether `.claude/agents/executor-infra.md`'s rule 1 should get a
  narrow read-only-diagnostic carve-out, given this run hit the tension
  twice (once correctly halting, once correctly making a judged
  exception).

## Notes

- This is a **content-seeding operation, not a code deploy** — no new
  app version needs to be built/deployed, the running QA app version
  already contains the `/rules` page code. Only Directus's data needs
  to change. Closest existing workflow is `deploy-app` (per its "Rotating
  secrets / environment variables for a running deployment" scope note
  and general precedent for app-level post-deploy operations), used here
  by analogy since no dedicated "seed app content" workflow exists yet
  in this repo — flagging that gap for whoever picks this up, in case a
  narrower workflow is worth adding later for recurring content-seed
  operations (this may not be the last one).
- The seed script is idempotent (updates existing rows by slug rather
  than erroring/duplicating), so this task is safe to re-run if the
  first attempt is interrupted.
- Source PR: `aiqadam/ai-qadam-platform` PR
  [#272](https://github.com/aiqadam/ai-qadam-platform/pull/272)
  (`FR-CMS-007`, merged `627cd91`). Full workflow artifacts:
  `.copilot/tasks/completed/wf-20260819-feat-212/` in that repo,
  particularly `03-code-summary.md`'s "Retry 2" section (documents the
  `ARG_MAX` fix and its local verification) and `07-test-results.md`
  (documents the original E2E-attempt finding of this exact gap,
  locally).
- Do not seed `content_pages` (the other new collection from the same
  PR) as part of this task unless separately requested — it has no seed
  script by design (`FR-CMS-007`'s own scope: About/History page
  structural content is hardcoded in the Astro pages, not Directus-driven;
  Partner With Us's dynamic fields are an intentional post-deploy
  content-authoring gap, not something this task should fill blind).

## History
- 2026-08-20: created (manual, on behalf of a live gap found in
  `aiqadam/ai-qadam-platform` FR-CMS-007 while checking `qa.aiqadam.org/rules`
  post-merge)
- 2026-08-20: status → `in-progress`, run `2026-08-20-seed-content-documents-qa-001`
- 2026-08-20: run `2026-08-20-seed-content-documents-qa-001` completed
  Phase 1 discovery cleanly but hit `verdict: BLOCKED` on the actual
  seed write (HTTP 403 — admin role lacks `content_documents`
  create/update permission). Zero rows written, no rollback needed.
  Also surfaced a self-reported secret-exposure incident during
  discovery (see `T-0137-rotate-qa-directus-admin-token`, now `done` —
  rotation completed 2026-08-20 via run
  `2026-08-20-rotate-qa-directus-token-001`). Retry queued, now
  unblocked (must use the rotated credential, not the exposed one) —
  RBAC gap added to "What done looks like" above.
- 2026-08-20: status -> done, outcome succeeded, run
  `2026-08-20-seed-content-documents-qa-001`, commit <pending>. Root
  cause corrected from RBAC (misdiagnosis) to missing
  `content_pages`/`content_documents` collections (bootstrap.sh's
  FR-CMS-007 additions never applied to QA); bootstrap.sh run to
  completion, both collections created, 5 governance documents seeded,
  full end-to-end verification PASS (step 07). Follow-up T-0139 filed
  for broader schema-drift risk.
