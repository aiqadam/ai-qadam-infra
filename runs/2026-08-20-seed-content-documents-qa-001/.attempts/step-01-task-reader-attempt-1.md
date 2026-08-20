---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 01
agent: task-reader
verdict: BLOCKED
created: 2026-08-20T08:07:59Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - tasks/T-0136-seed-content-documents-qa.md
artifacts_changed: []
next_step_hint: Orchestrator must halt and ask the user to either point this task at an existing workflow (infrastructure or cicd are the closest fits) or confirm/author a new workflows/deploy-app.md file before any subagent proceeds past this step.
---

## Summary
T-0136 asks that `infrastructure/directus/seed-content-documents.sh` (from `aiqadam/ai-qadam-platform`, shipped in merged PR #272 / FR-CMS-007) be run against QA's Directus instance to populate the `content_documents` collection with 5 governance documents, closing the gap where `qa.aiqadam.org/rules` currently renders the empty state instead of the seeded documents — but the task is not well-formed as written because its `workflow: deploy-app` field names a workflow file that does not exist in this repo.

## Details
- **Workflow:** `deploy-app` — **does not exist**. `workflows/README.md`'s current-workflows table lists only `infrastructure.md`, `cicd.md`, `discovery-host.md`, `discovery-cloudflare.md`, `audit-host.md`, `audit-repo.md` (all inheriting `_common-operations.md`'s 8-step skeleton). No `workflows/deploy-app.md` file exists on disk. `tasks/README.md`'s own frontmatter schema enumerates the legal `workflow:` values as `infrastructure | cicd | discovery-host | discovery-cloudflare | manual | none` — `deploy-app` is not among them. The task's own **Notes** section is transparent about this: it says `deploy-app` was chosen "by analogy since no dedicated 'seed app content' workflow exists yet in this repo," and explicitly flags the gap for whoever picks up the task. Per my role definition (`task-reader.md` step A.3: "Use the task's `workflow:` field to select the workflow"), I cannot select a workflow that isn't real, so this run cannot proceed to step 02 as specified.
- **Task status check:** `status: in-progress` (was set when this run — `2026-08-20-seed-content-documents-qa-001` — started, per the task's own History). This is a valid non-closed status, so the task is otherwise eligible for execution once the workflow question is resolved.
- **Target scope:**
  - `landscape/services.md` — exists (`landscape/services.md`, 56420 bytes, present in the repo). This is the sole `affects:` entry and is a valid landscape file path for step 02 to consult (expected to cover the QA Directus service entry, if one exists there).
  - `landscape/secrets-inventory.md` — exists and is referenced in the task's first acceptance criterion as the likely home for QA Directus URL/token references; not formally listed in `affects:` but landscape-reader should check it too since the task explicitly names it.
- **Constraints stated by user:**
  - Do not put the actual QA Directus admin token value in any committed file — reference it only per the repo's normal secret-reference convention.
  - Do not seed `content_pages` (the sibling collection from the same PR) — out of scope by design, per the task's Notes.
  - Content-seeding only — no app rebuild/redeploy; only Directus data changes.
- **Information gaps for downstream steps:**
  - Whether `landscape/services.md` and/or `landscape/secrets-inventory.md` actually document a QA Directus instance (`pro-data-tech-qa`) with a resolvable URL and a token reference — landscape-reader (step 02) must confirm this exists before task-validator can pass.
  - Whether `infrastructure` or `cicd` (the two real state-changing workflows) is the better fit by content, given `deploy-app` isn't real. `infrastructure.md` covers "hosts, services, networking, Cloudflare, certificates"; `cicd.md` covers "building, testing, deploying software to managed hosts." This is a one-off idempotent data-seed against an already-deployed app's backend service — it does not cleanly match either description, which is exactly the gap the task's own Notes flag.
  - Whether the orchestrator/user wants to author a minimal `workflows/deploy-app.md` (or a narrower "seed-content" workflow) now, versus temporarily re-pointing this task at `infrastructure` for this one run.

## Issues / risks
- **Blocking defect in the task file itself:** `workflow: deploy-app` is not a resolvable workflow. This is not an ambiguity in the user's request (the request itself — "run the seed script against QA" — is unambiguous) but a structural defect in how T-0136 was authored, which the task's own Notes already anticipated and disclosed.
- Low operational risk once unblocked: the task itself documents low blast radius (`estimated_blast_radius: low`, `estimated_reversibility: full`) and an idempotent script (safe to re-run).

## Open questions
- Should this run be redirected to use `workflows/infrastructure.md` (closest existing match — "services" scope) for this execution, with a follow-up task filed to formally add a dedicated content-seed/deploy-app workflow? Or should the user first author `workflows/deploy-app.md` before this run proceeds?
- Should T-0136's `workflow:` field be corrected in place (and a History entry appended) once the above is decided, so the task file itself is no longer inconsistent with `tasks/README.md`'s schema?
