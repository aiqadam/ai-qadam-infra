---
run_id: 2026-08-21-provision-rules-downloads-qa-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-21T09:30:00Z
task_id: T-0141-provision-rules-source-file-downloads-qa
inputs_read:
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-01-task-reader.md
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-02-landscape-reader.md
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-03-task-validator.md
  - tasks/T-0141-provision-rules-source-file-downloads-qa.md
  - tasks/T-0142-expose-qa-directus-vhost.md
  - landscape/hosts/pro-data-tech-qa.md
next_step_hint: Awaiting user approval. Once approved, executor-infra should run Phase 1 (scp) then Phase 2 (bootstrap.sh) then Phase 3 (seed-content-documents.sh) then Phase 4 (verification), in that order, stopping and reporting BLOCKED rather than improvising if bootstrap.sh reports any unexpected non-FR-CMS-008 delta.
---

## Summary
Resumes this run after T-0142 closed the one open design question
(step-03's "is Directus reachable anonymously, and at what origin?") —
`cms.qa.aiqadam.org` is now live, TLS-valid, and wired into
`web-next` as `PUBLIC_DIRECTUS_URL`. No scope expansion, no nginx
change needed. Plan below executes T-0141's own unchanged scope: copy
5 files, run `bootstrap.sh`, run `seed-content-documents.sh`, verify
end-to-end via the new public origin.

## Details

### Resolution of step-03's open question
`cms.qa.aiqadam.org` → `95.46.211.230`, nginx-proxied to Directus's
loopback port `3119`, TLS via the shared `qa.aiqadam.org` cert
lineage (SAN-expanded). Confirmed live: `https://cms.qa.aiqadam.org/
server/ping` → 200/`pong` (T-0142's own step-07 execution-validator).
This is the origin AC-4/AC-6 will check against. No nginx/DNS/TLS work
remains for this task.

### Phase 1 — Copy the 5 source files (scp)
- Source (management workstation):
  `c:\Users\tvolo\dev\ai-dala\aiqadam\portal-content\20260819\`
- Destination (QA host): `/opt/apps/aiqadam-qa/portal-content/20260819/`
- Copy **exactly** these 5 files, not the directory (13 other files —
  PDFs/PPTX/HTML/.doc/a non-matching factsheet .docx — must NOT be
  copied):
  1. `AI Qadam Manifesto.docx`
  2. `AI Qadam Charter v0 1.docx`
  3. `AI_Qadam_Kazakhstan_MoU-2105 (3).docx`
  4. `AI Qadam Global Board Положение (2).docx`
  5. `AI Qadam Soglashenie v1 (2).docx`
- Command shape: `scp` each file individually (not glob-copy the
  directory) to avoid pulling in the 13 unrelated files, preserving
  exact filenames — 3 of 5 contain spaces/parens/Cyrillic, and the
  transfer crosses Windows→Linux.
- Verify after copy: `ls -la` on the destination directory, confirm
  exactly 5 files, byte-exact names (a mangled name fails silently —
  the seed script skips missing files non-fatally, so this check is
  load-bearing, not cosmetic).
- Ownership: match the existing checkout (`tvolodi:tvolodi`), so the
  seed script (run as `tvolodi` or via sudo) can read them.

### Phase 2 — Run `bootstrap.sh` against QA Directus
- Command: `cd /opt/apps/aiqadam-qa && infrastructure/directus/bootstrap.sh`
  (env: `DIRECTUS_URL=http://127.0.0.1:3119`, `DIRECTUS_ADMIN_TOKEN`
  read fresh from `deploy/.env` — exactly that key, not
  `DIRECTUS_TOKEN`, per step-03's flagged desync risk).
- Expected delta: `content_documents.source_file` field + relation to
  `directus_files`, `public-documents` folder created, folder-scoped
  anonymous read grant on `directus_files`, `source_file` appended to
  `content_documents`'s public-read field allowlist.
- **STOP condition (armed, per step-03):** any collection other than
  the FR-CMS-008 additions reports a *new* change (not a repeat of the
  already-applied, dated `F-S2.12 operator_invites` cleanup, which
  should now be a no-op since T-0136 already applied it). If
  `bootstrap.sh`'s output shows an unexpected modification to a
  pre-existing collection, STOP and report BLOCKED rather than
  proceeding — do not treat this as "close enough."
- A 403 anywhere in this phase's own verification most likely means
  "does not exist yet," not "no permission" (T-0136's own hard-won
  lesson) — check existence before concluding a permissions problem.

### Phase 3 — Run `seed-content-documents.sh` against QA
- Command: `cd /opt/apps/aiqadam-qa && infrastructure/directus/seed-content-documents.sh`
  (same env as Phase 2).
- Expected delta: the 5 `content_documents` rows (already present from
  T-0136 — this should be a near-total no-op on the row-upsert half)
  each get their `source_file` set to a newly-uploaded
  `directus_files` row in the `public-documents` folder. 5 files
  uploaded total.
- Idempotency check: if re-run, must not create duplicate
  `directus_files` rows (script's own `find_existing_file_id()` is
  folder-scoped for this reason — confirm no duplicates appear if this
  phase is retried for any reason).
- **Ordering is load-bearing:** never run this before Phase 2 — an
  uploaded-but-unattached-permission file is unreadable, not merely
  incomplete.

### Phase 4 — Verification (the actual acceptance signal)
1. **Anonymous asset access (AC-4):**
   `curl -sS -o /dev/null -w '%{http_code}' 'https://cms.qa.aiqadam.org/assets/<id>?download'`
   for each of the 5 uploaded files → expect `200`, and a HEAD/verbose
   check confirms `Content-Disposition: attachment; filename="..."`
   with the real original filename preserved.
2. **Negative check (AC-5):** pick any asset outside
   `public-documents` (e.g., an existing unrelated file, if one
   exists, or the folder-scope filter itself) and confirm anonymous
   access still 403s; confirm anonymous `GET /files` does not
   enumerate the whole table (folder-filtered query only).
3. **Live page check (AC-6):** `https://qa.aiqadam.org/rules/manifesto`
   (and the other 4 slugs: `charter-v0-1`, `kazakhstan-mou`,
   `global-board-polozhenie-v1`, `soglashenie-v1`) render a working
   download link whose `href` resolves to `cms.qa.aiqadam.org` — never
   the internal `directus:8055`/`127.0.0.1:3119` form.
4. **Regression check:** `https://qa.aiqadam.org/rules`, `/about`,
   `/history`, `/partners` all still 200.

### Rollback (authored, no existing precedent — per step-03 gap 7)
Ordered to revert the security-relevant piece first:
1. Revoke the anonymous `directus_files` read grant (delete the
   permission row scoped to the `public-documents` folder).
2. Delete the 5 uploaded `directus_files` rows and the
   `public-documents` folder.
3. Null out `source_file` on the 5 `content_documents` rows (or leave
   the column — see step 4).
4. Drop the `content_documents.source_file` field + relation (only if
   fully reverting the schema; leaving the column nullable and unused
   is also an acceptable partial rollback if only the public exposure
   needs undoing urgently).
5. `rm -rf /opt/apps/aiqadam-qa/portal-content/20260819/` on the host
   (safe — did not exist before this run).
This plan does not anticipate needing rollback (additive, low blast
radius per the task's own rating), but per `deploy-app`'s requirement
an explicit command is recorded here rather than deferred to incident
time.

### Health check (step 07 correction, per step-03)
Use `https://qa.aiqadam.org/health` — NOT the registry's stale
`qa-uz.aiqadam.org` endpoint.

## Issues / risks
Carried forward from step-03, all still applicable: secret-handling
discipline (read exactly `DIRECTUS_ADMIN_TOKEN`, never glob/dump
`deploy/`), the seed script's non-fatal skip as the main silent-failure
mode, DB-level verification (if needed) must use the bridge-network
method not `--network container:`, and `shared/app-registry.md`'s
staleness (still not corrected — out of this task's `affects:` scope).

## Open questions
None remaining — the one substantive question (public Directus origin)
is resolved by T-0142.
