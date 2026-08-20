---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-08-20T23:10:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/step-04-solution-designer.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-05-user-approval.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-infra-attempt-5.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - pro-data-tech-qa: directus database — content_documents table populated with 5 governance-document rows (manifesto, charter-v0-1, kazakhstan-mou, global-board-polozhenie-v1, soglashenie-v1) via infrastructure/directus/seed-content-documents.sh. No schema change made in this step (Phase 1/bootstrap.sh already executed in the archived attempt 5, not re-run here).
retry_of: step-06
next_step_hint: >-
  All 4 plan phases now complete (Phase 1 in attempt 5, Phases 2-4 in this
  attempt). T-0136's acceptance criteria are met end-to-end: /rules lists
  all 5 documents, individual document pages render, superseded labeling is
  correct, and the pre-existing About/History/Partners pages did not
  regress. Ready for step 07 (verification/close-out) and step 08
  (landscape update) per workflow deploy-app.md. step 08 should record: (a)
  root cause was missing collections, not RBAC; (b) content_pages/
  content_documents now exist and are seeded; (c) the DIRECTUS_TOKEN vs
  DIRECTUS_ADMIN_TOKEN post-T-0137 disambiguation; (d) the F-S2.12
  operator_invites field-drop is confirmed benign/already-integrated
  cleanup (per Orchestrator's independent investigation, not re-derived by
  this agent); (e) the approved plan's Phase 4.1 verification command used
  a field name (superseded_by) that does not exist on content_documents —
  the actual field is status_label (free text, e.g. "Superseded by Charter
  v0.1") — worth correcting in any future plan/runbook that reuses this
  verification step.
---

## Summary

Executed Phases 2, 3, and 4 of the approved plan (step-04-solution-designer.md, approved in step-05-user-approval.md). Phase 1 (bootstrap.sh) was NOT re-run in this attempt — it already executed successfully to completion (exit code 0) in the archived `step-06-executor-infra-attempt-5.md`, which correctly halted afterward on an unexpected-modification STOP condition (an `operator_invites` field drop). The Orchestrator independently investigated that finding outside the agent pipeline and confirmed it is a safe, already-integrated, dated cleanup migration (`F-S2.12`, 2026-05-25) with no live app dependency — this cleared the STOP condition and authorized continuing straight to Phase 2 without re-running Phase 1. All three remaining phases passed: the schema gap is closed, all 5 governance documents are seeded, and full external verification (REST, `/rules`, individual document page, superseded labels, and the three FR-CMS-007 static pages) is green. Verdict: PASS.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (step-05-user-approval.md, inputs_read references step-04-solution-designer.md)
- Design references match: yes

### Phase 1 status (not executed in this attempt — carried forward)

Phase 1 (bootstrap.sh) was already run to completion in the archived attempt, `runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-infra-attempt-5.md`: exit code 0, `content_pages` and `content_documents` collections created as the plan intended. That attempt halted with `verdict: BLOCKED` per the plan's own explicit Phase 1.1 STOP condition, because bootstrap.sh's output also showed an unplanned modification to a pre-existing collection: 7 fields dropped from `operator_invites` under a block labeled `[F-S2.12 — drop F-S2.8.x operator_invites.* email-routing fields]`.

This attempt did **not** re-run bootstrap.sh — re-running was explicitly unnecessary (idempotent, already succeeded, no benefit) and out of scope for this task's instructions. What changed between attempt 5 and this attempt is not new live evidence from the host, but an **independent investigation by the Orchestrator**, conducted directly in the `aiqadam` source repo (outside this agent pipeline), which established:

1. The `operator_invites` field drop is a documented, dated (2026-05-25) cleanup migration, labeled `F-S2.12` in `bootstrap.sh`'s own comments (lines 3582-3601) — it has always been part of `bootstrap.sh`, not something newly introduced by FR-CMS-007's changes. QA's schema was simply stale on this too, the same underlying pattern as the missing `content_pages`/`content_documents` collections (this was the first time `bootstrap.sh` had been run to completion against QA).
2. Live application code (`apps/api/src/modules/admin-invites/admin-invites.controller.ts:51`) already accounts for the drop, with a comment explicitly referencing "F-S2.12 cleanup, 2026-05-25" — confirming nothing live depends on the 7 dropped columns.
3. `bootstrap.sh`'s field-drop calls are confirmed idempotent (script's own header comment: "Drop is idempotent (helper returns success on 404)").

This investigation is **not** re-derived or independently re-verified by this executor step — it is taken as a resolved input from the Orchestrator, per this step's task instructions, and is recorded here for audit trail per my role's requirement to cite it explicitly rather than imply it came from fresh on-host evidence.

### Execution log

#### Phase 2.1: Confirm both collections now exist in directus_collections
- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -Atc \"SELECT collection FROM directus_collections WHERE collection IN ('content_pages','content_documents') ORDER BY 1;\""`
- Exit code: 0
- Output:
  ```
  content_documents
  content_pages
  ```
- Result: success — exactly the two expected rows, matching plan verification exactly.
- Backup taken: n/a (read-only)

#### Phase 2.2: Confirm REST API responds without 403 on content_documents
- Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3119/items/content_documents"`
- Exit code: 0
- Output: `200`
- Result: success — HTTP 200, not 403. Plan's STOP condition (still-403) did not fire.
- Backup taken: n/a (read-only)

#### Phase 3.1: Run the seed script
- Command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && DIRECTUS_URL=http://127.0.0.1:3119 DIRECTUS_TOKEN=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) bash infrastructure/directus/seed-content-documents.sh"`
- Exit code: 0
- Output:
  ```
  [content_documents — Community Rules & Documents library]
    + content_documents/manifesto (seeded)
    + content_documents/charter-v0-1 (seeded)
    + content_documents/kazakhstan-mou (seeded)
    + content_documents/global-board-polozhenie-v1 (seeded)
    + content_documents/soglashenie-v1 (seeded)

  ✅ content_documents seeded (5 rows).
  ```
- Result: success — 5/5 upserts, no `✗ ... HTTP 403` lines (the prior blocked attempt's failure signature).
- Backup taken: n/a (upsert-by-slug script is its own safe re-run path per plan's rollback section; no pre-seed backup was declared by the plan for this phase).
- Redaction: token value substituted inline via command substitution in the same SSH session, never echoed or logged, consistent with the plan's redaction discipline.

#### Phase 4.1: REST confirmation of all 5 rows
- Command (as literally specified in the approved plan): `ssh pro-data-tech-qa "curl -s http://127.0.0.1:3119/items/content_documents?fields=slug,title,superseded_by | python3 -m json.tool"`
- Exit code: 0
- Output: a `FORBIDDEN`/"does not exist" GraphQL-style error for the `superseded_by` field — **the plan's verification command names a field that does not exist on `content_documents`.**
- Result: **plan-command defect, not an execution failure.** Investigated immediately (read-only): `information_schema.columns` for `content_documents` lists `body_md, date_created, date_updated, display_order, id, slug, source_document_label, status, status_label, title` — there is no `superseded_by` column. The "superseded" relationship is carried by the free-text `status_label` field (e.g. `"Superseded by Charter v0.1"`), which Phase 4.2's rendered HTML independently confirms is displaying correctly. Re-ran the equivalent query with correct field names for positive evidence:
  ```
  curl -s 'http://127.0.0.1:3119/items/content_documents?fields=slug,title,status,status_label' | python3 -m json.tool
  ```
  → exactly 5 items, slugs `manifesto`, `charter-v0-1`, `kazakhstan-mou`, `global-board-polozhenie-v1`, `soglashenie-v1` (matching the plan's expected set exactly), all `status: published`, `status_label` = `"Current"` for the first 3 and `"Superseded by Charter v0.1"` for the last 2.
- Backup taken: n/a (read-only)
- **Judgment call:** treated this as a plan-authoring defect in the verification command (wrong field name), not a genuine STOP condition — the plan's actual intent ("exactly 5 items with the 5 correct slugs, superseded status visible") is fully satisfied once the correct field name is used, and Phase 4.2/4.4 independently corroborate the superseded-status data is correct. No off-plan *change* was made (this was read-only re-querying with corrected field names, not a schema or data change), so this does not conflict with the "no off-plan changes" rule, which governs state-changing actions.

#### Phase 4.2: External /rules listing
- Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/rules"` then a body fetch.
- Exit code: 0
- Output: HTTP `200`. Body contains all 5 documents rendered as cards: "AI Qadam Manifesto" / "AI Qadam Charter v0.1" / "AI Qadam Kazakhstan MoU" (all badged "Current"), "AI Qadam Global Board Положение v1.0" / "AI Qadam Соглашение v1.0" (both badged "Superseded by Charter v0.1"). No "Пока нет опубликованных документов." empty-state text present.
- Result: success, matches plan verification exactly.

#### Phase 4.3: Individual document page
- Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/rules/charter-v0-1"`
- Exit code: 0
- Output: `200`
- Result: success.

#### Phase 4.4: Superseded-label check
- Command: per-slug fetch + grep for `Superseded by` pattern, all 5 slugs.
- Exit code: 0
- Output:
  ```
  global-board-polozhenie-v1: Superseded by Charter v0.1
  soglashenie-v1: Superseded by Charter v0.1
  manifesto: (no match)
  charter-v0-1: (no match)
  kazakhstan-mou: (no match)
  ```
- Result: success — label present on exactly the 2 expected documents, absent on the other 3, matching plan verification exactly.

#### Phase 4.5: content_pages existence does not regress the three FR-CMS-007 static pages
- Command: `ssh pro-data-tech-qa "for p in about history partners; do echo -n \"\$p: \"; curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/\$p; done"`
- Exit code: 0
- Output:
  ```
  about: 200
  history: 200
  partners: 200
  ```
- Result: success — all three return 200, no regression from `content_pages`'s existence.

### Rollback executed

Not needed. All phases succeeded; no STOP condition fired on any state-changing step.

### Resources changed

- **Files on host:** none (both bootstrap.sh — prior attempt — and the seed script operate via Directus REST API, not file edits).
- **Services restarted:** none.
- **External resources changed (this step only):** `content_documents` table — 5 rows inserted/upserted (manifesto, charter-v0-1, kazakhstan-mou, global-board-polozhenie-v1, soglashenie-v1). No schema change made in this step (schema change was Phase 1, already applied in attempt 5).

## Issues / risks

- **The approved plan's Phase 4.1 verification command references a nonexistent field (`superseded_by`) on `content_documents`.** The actual field carrying this information is `status_label` (free text). This is a defect in the plan document itself (`step-04-solution-designer.md`), not an execution problem — worked around by re-querying with correct field names, and independently corroborated by Phase 4.2's rendered page and Phase 4.4's direct label check, both of which used slug-based fetches unaffected by the field-name issue. Recommend step 08 (landscape/task update) or a future runbook note flag this so the field name is corrected before any future re-run of this verification pattern.
- **Phase 1 (bootstrap.sh) evidence in this handoff is entirely carried forward from `runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-infra-attempt-5.md`**, not re-verified live in this attempt. This is consistent with this step's explicit task instructions (do not re-run bootstrap.sh) and with bootstrap.sh's confirmed idempotency, but is noted for the record: Phase 2's checks (collections present, REST 200) are the live re-confirmation that Phase 1's effect is actually in place, so the schema-gap closure is independently re-verified in this attempt even though the script invocation itself was not re-run.
- **The STOP condition cleared for this run rests on the Orchestrator's out-of-band investigation (source-repo grep, bootstrap.sh comment dating, app-code comment cross-reference), not on new live evidence gathered by this or any agent step.** This is explicitly how the task instructed this step to proceed, and is recorded here transparently per handoff-format's audit expectations — this executor did not itself verify the `F-S2.12` ticket history or the cited `admin-invites.controller.ts:51` comment.
- No secret values were echoed, logged, or written anywhere in this handoff — `DIRECTUS_ADMIN_TOKEN` was read fresh via inline command substitution in the SSH session per the established redaction discipline.

## Open questions (optional)

None blocking. All 4 plan phases are now complete and all of T-0136's acceptance criteria are externally verified. Two non-blocking notes carried into `next_step_hint` for step 08: (1) landscape should record the confirmed-benign `F-S2.12` operator_invites field drop so it isn't re-flagged as a surprise in a future bootstrap.sh run elsewhere; (2) the plan's Phase 4.1 field-name defect (`superseded_by` → should be `status_label`) is worth a correction note for future reuse of this verification pattern.
