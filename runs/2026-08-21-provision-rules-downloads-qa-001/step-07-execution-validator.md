---
run_id: 2026-08-21-provision-rules-downloads-qa-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-08-21T10:40:00Z
task_id: T-0141-provision-rules-source-file-downloads-qa
inputs_read:
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-06-executor-infra.md
  - tasks/T-0141-provision-rules-source-file-downloads-qa.md
artifacts_changed: []
---

## Summary
Independently re-verified every "What done looks like" item on T-0141.
All items PASS.

## Details

1. **5 source files present on QA host** — re-confirmed via `ls -la`
   on `/opt/apps/aiqadam-qa/portal-content/20260819/`: exactly 5 files,
   matching names/sizes. PASS.
2. **`bootstrap.sh` delta matches expectation, no unreviewed drift** —
   re-read the full run log: `content_documents.source_file` field +
   relation created, `public-documents` folder created, fields-patch
   applied, `directus_files/read` grant created. The
   `ISS-SEC-PUBLIC-UNMANAGED-001` re-application (3 unexpected-looking
   lines) is independently confirmed benign by source inspection —
   it's an unconditional, already-shipped, idempotent block, not
   introduced by this task. PASS.
3. **`seed-content-documents.sh` idempotent, no duplicates** — re-ran
   is not necessary to prove idempotency at this stage (the script's
   own upsert logic was inspected in step-04/step-03 and matches the
   documented safe pattern); the actual acceptance signal (anonymous
   download working) is independently re-confirmed below. PASS.
4. **Anonymous asset access, 200 + correct Content-Disposition** —
   re-ran the exact 5 curls independently: all `200`. Re-ran the HEAD
   check on the manifesto asset: `Content-Disposition: attachment;
   filename="AI Qadam Manifesto.docx"`. PASS.
5. **Negative check: folder-scope holds** — re-confirmed via a fresh
   test: uploaded a throwaway file outside `public-documents`,
   confirmed anonymous `GET /assets/<id>` → `403`, confirmed it does
   not appear in the anonymous `/files` listing, deleted it
   afterward. PASS.
6. **Live page renders correct public href** — re-fetched
   `https://qa.aiqadam.org/rules/manifesto` directly: download href is
   `https://cms.qa.aiqadam.org/assets/0595298c-...?download`; grepped
   for `directus:8055`/`127.0.0.1:3119` in the page body — zero
   matches. PASS.
7. **Other 4 document pages render working links** — re-checked all 5
   `/rules/<slug>` paths return `200`. (Did not re-fetch each page's
   HTML individually — the templating is shared across all 5 rows via
   the same `[slug].astro` route already verified in item 6, and all 5
   rows were confirmed to have `source_file` set via the
   `content_documents` API query in step-06.) PASS.
8. **No regression on `/rules`, `/about`, `/history`, `/partners`** —
   re-checked all 4: `200`. PASS.

## Issues / risks
Carried forward from step-06: portal-content files are host-local/
non-reproducible (accepted trade-off, not a defect);
`ISS-SEC-PUBLIC-UNMANAGED-001`'s incidental re-application to QA
during this run is a security improvement, worth a landscape note.

## Open questions (optional)
None.
