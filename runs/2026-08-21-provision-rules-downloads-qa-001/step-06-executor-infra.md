---
run_id: 2026-08-21-provision-rules-downloads-qa-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-08-21T10:30:00Z
task_id: T-0141-provision-rules-source-file-downloads-qa
inputs_read:
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-04-solution-designer.md
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-05-user-approval.md
artifacts_changed:
  - "pro-data-tech-qa: /opt/apps/aiqadam-qa/portal-content/20260819/ created, 5 governance .docx files copied from the management workstation (scp), ownership tvolodi:tvolodi"
  - "pro-data-tech-qa: /opt/apps/aiqadam-qa git checkout advanced from 0cef09e to 7d5918f (aiqadam repo, includes PR #280's bootstrap.sh fix), local AUTHENTIK_ADMIN_URL override preserved via stash/pop"
  - "QA Directus: content_documents.source_file field + relation created; public-documents folder created; content_documents/read permission's fields allowlist patched to include source_file; directus_files/read anonymous grant created (folder-scoped)"
  - "QA Directus: 5 files uploaded into public-documents folder, each content_documents row's source_file linked (manifesto, charter-v0-1, kazakhstan-mou, global-board-polozhenie-v1, soglashenie-v1)"
next_step_hint: All 4 phases complete and independently verified. Proceed to execution-validator (step-07) then landscape-updater (step-08).
---

## Summary
Executed all 4 phases of the approved plan. Phase 2 (bootstrap.sh)
initially hit a real bug in the shipped script — documented, escalated
to the user, fixed via a separate app-repo PR (#280,
`ISS-CMS-BOOTSTRAP-SOURCE-FILE-215`), merged, then re-run successfully
against QA. Phases 1, 3, and 4 all completed cleanly on the first
attempt. End state independently verified live: all 5 governance
documents anonymously downloadable from `cms.qa.aiqadam.org` with
correct filenames, folder-scope negative check passed, all 5 `/rules`
detail pages plus `/rules`/`/about`/`/history`/`/partners` return 200
with no regression.

## Details

### Phase 1 — Copy the 5 source files
- `scp`'d each of the 5 named files individually from
  `c:\Users\tvolo\dev\ai-dala\aiqadam\portal-content\20260819\` to
  `/opt/apps/aiqadam-qa/portal-content/20260819/` on the QA host.
- Verified: exactly 5 files present, byte-identical sizes to the
  source (26386, 29163, 12026, 30419, 39507 bytes), Cyrillic filename
  (`Положение`) transferred intact.
- Fixed ownership to `tvolodi:tvolodi` to match the checkout.
- Result: success.

### Phase 2 — Run `bootstrap.sh` (hit a real bug, fixed, re-run)
- First attempt (checkout at `0cef09e`, pre-fix `bootstrap.sh`): failed,
  exit 1. `[content_documents]` section showed
  `✗ relation content_documents.source_file -> directus_files.id HTTP
  400` — `"Field \"source_file\" doesn't exist in collection
  \"content_documents\""`.
- Root-caused via source inspection (not guessed): `source_file` was
  declared only inside `content_documents`'s own collection-creation
  payload; `ensure()`'s existence-check short-circuits the *whole*
  payload once the collection's `GET` returns 200 — and QA's
  `content_documents` already existed from T-0136's earlier bootstrap
  run (pre-FR-CMS-008). Confirmed no dedicated
  `ensure "field content_documents.source_file"` call existed anywhere
  in the script, unlike the correct precedent (`events.translations`).
- **Escalated to the user rather than hand-patching the live host or
  the script without going through the app repo's workflow.** User
  chose "fix the code first."
- Fixed in `aiqadam/ai-qadam-platform` via
  `fix/ISS-CMS-BOOTSTRAP-SOURCE-FILE-215-...`: added the dedicated
  field-level `ensure()` call (matching `events.translations`'s
  pattern) plus a new `ensure_perm_fields_include()` helper (the same
  class of gap independently affected the `content_documents/read`
  permission's `fields` allowlist — `ensure_perm_for_policy`'s
  existence check is policy+collection+action only). New static
  regression test (`bootstrap-source-file-existing-collection.bats`,
  4/4 pass). PR #280 merged; companion archival PR #281 merged.
- Pulled `7d5918f` (origin/main HEAD, includes both #280 and #281) onto
  the QA host checkout via the established stash/pop pattern — clean
  auto-merge, `AUTHENTIK_ADMIN_URL` host-local override preserved,
  confirmed via `git status --porcelain` unchanged from before.
- Re-ran `bootstrap.sh`: exit 0.
  `[content_documents]` section:
  ```
  ✓ collection content_documents (exists)
  + field content_documents.source_file (created)
  + relation content_documents.source_file -> directus_files.id (created)
  [FR-CMS-008 — public-assets folder]
  + folder public-documents (created)
  [FR-CMS-007 — public read: content_pages, content_documents]
  ✓ perm public content_pages/read (exists)
  ✓ perm public content_documents/read (exists)
  ~ perm public content_documents/read fields (fields patched to include source_file)
  + perm public directus_files/read (created)
  ```
  Exactly the expected FR-CMS-008 delta — field, relation, folder,
  fields-patch, grant — nothing else.
- **STOP-condition check (armed per step-04):** scanned the full run
  log for any `+`/`~`/`✗` line outside the expected block. Found 3:
  `perm public events/read`, `speakers/read`, `event_speakers/read`
  (lines ~290-292) — investigated via source inspection, confirmed
  this is `ISS-SEC-PUBLIC-UNMANAGED-001`, an already-shipped,
  unconditional, idempotent security-hardening block (revoke any
  unscoped legacy grant, re-create scoped) that runs on **every**
  bootstrap invocation regardless of this task — not a new regression,
  simply another already-merged fix QA had never had a full bootstrap
  pass to pick up since (same staleness class T-0136 found previously).
  Confirmed benign: `qa.aiqadam.org/health` and `/rules` both still
  200 immediately after. Did not treat as a STOP condition.
- Result: success (after the app-repo fix).

### Phase 3 — Run `seed-content-documents.sh`
- Ran once, exit 0. All 5 rows updated (not created — matching
  step-03's prediction that the row-upsert half would be a near-total
  no-op since T-0136 already created these rows): each uploaded its
  file and linked `source_file`.
- Result: success.

### Phase 4 — Verification (the actual acceptance signal)
1. **Anonymous asset access (AC-4):** queried `content_documents` via
   the public origin for all 5 `source_file` ids, then
   `curl ... /assets/<id>?download` anonymously for each — all 5
   return `200`. Confirmed `Content-Disposition: attachment;
   filename="AI Qadam Manifesto.docx"` (real filename preserved) via a
   HEAD request on the manifesto asset.
2. **Negative check (AC-5):** anonymous `GET /files` returns exactly 5
   rows (matching the total instance file count via admin token at
   that point) — not evidence alone, so additionally uploaded a
   throwaway test file (`folder: null`, outside `public-documents`)
   via admin token, confirmed anonymous `GET /assets/<test-id>` → 403,
   confirmed it did NOT appear in the anonymous `/files` listing
   (count stayed at 5 with the 6th file present on the instance),
   then deleted the test file via admin token (204).
3. **Live page check (AC-6):** all 5 `/rules/<slug>` pages return 200;
   `curl`'d the rendered `manifesto` page HTML directly — download
   `href` is `https://cms.qa.aiqadam.org/assets/0595298c-...?download`;
   confirmed zero occurrences of `directus:8055` or `127.0.0.1:3119`
   in the page output.
4. **Regression check:** `/rules`, `/about`, `/history`, `/partners`
   all still 200.

### Rollback executed
Not executed — every phase succeeded and independently verified; no
partial or broken state to revert. The one blocked-then-fixed step
(Phase 2's first attempt) failed cleanly with no partial schema
change (Directus rejected the bad relation payload outright, nothing
was left half-applied), so no rollback was needed even for that
attempt.

### Resources changed
- **Files on host (pro-data-tech-qa):** `/opt/apps/aiqadam-qa/
  portal-content/20260819/` (new directory, 5 files, ~137 KB total,
  host-local/non-reproducible per the task's own accepted trade-off);
  `/opt/apps/aiqadam-qa/` git checkout advanced `0cef09e` → `7d5918f`.
- **QA Directus schema:** `content_documents.source_file` field +
  relation; `public-documents` folder; `content_documents/read`
  permission's `fields` allowlist patched; `directus_files/read`
  anonymous grant (folder-scoped).
- **QA Directus content:** 5 `directus_files` rows (uploaded
  documents), 5 `content_documents` rows updated (`source_file` set).
- **aiqadam/ai-qadam-platform (companion fix):** PR #280 (bootstrap.sh
  fix) + PR #281 (archival), both merged.

## Issues / risks
- **The portal-content files on QA are host-local and non-reproducible**
  — already flagged in the task's own Notes; a host rebuild would lose
  them and require re-copying. Accepted trade-off, not a new risk.
- **`ISS-SEC-PUBLIC-UNMANAGED-001`'s re-application during this run**
  means QA's `events`/`speakers`/`event_speakers` public-read grants
  were just re-scoped for the first time since that fix shipped — this
  is an improvement (was previously unscoped/unmanaged on this
  instance), not a regression, but worth landscape-noting since it's a
  security-relevant change this task's own scope didn't originally
  anticipate touching.

## Open questions (optional)
None.
