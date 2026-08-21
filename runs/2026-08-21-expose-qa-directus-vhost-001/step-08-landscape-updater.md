---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-08-21T09:15:00Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-06-executor-infra.md
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-07-execution-validator.md
  - tasks/T-0142-expose-qa-directus-vhost.md
artifacts_changed:
  - landscape/cloudflare.md (new cms.qa.aiqadam.org A record row + record-count reconciliation entry)
  - landscape/hosts/pro-data-tech-qa.md (last_verified/last_verified_note bumped to 2026-08-21; nginx vhost section updated to 3 hostnames; PUBLIC_DIRECTUS_URL documented in the .env/compose subsection)
---

## Summary
Applied the landscape deltas from T-0142's two phases (nginx vhost PR
#278, `.env`-wiring follow-up PR #279, and the live DNS/TLS/nginx
changes executor-infra made on `pro-data-tech-qa`).

## Details

### `landscape/cloudflare.md`
- Added a row for `cms.qa.aiqadam.org` (A, `95.46.211.230`,
  proxied:false, ttl:1, record ID `0b4ddd97899b5b7cd6d756a03c25e7ae`)
  to the core-web-records table, owner `T-0142 / this repo`.
- Updated the record-count reconciliation: 47 (post-T-0122) + 1
  (`cms.qa.aiqadam.org`, T-0142) = **48 records**, confirmed via the
  full zone dump executor-infra took in Step 1 (before: 47, after: 48,
  diff shows exactly one added ID).
- Updated the zone's `last_verified`/`last_verified_note` frontmatter.

### `landscape/hosts/pro-data-tech-qa.md`
- Updated `last_verified` → `2026-08-21`, prepended a `last_verified_note`
  entry for T-0142 (nginx 3rd vhost, TLS SAN expansion, PUBLIC_DIRECTUS_URL
  wiring, web-next recreate — same terse style as prior entries, existing
  entries preserved verbatim below it per this doc's established pattern).
- Updated the "AiQadam application stack" nginx-vhost description to
  note `cms.qa.aiqadam.org` as a third hostname on the same file/cert.
- Documented `PUBLIC_DIRECTUS_URL` in the `deploy/.env`/compose
  subsection alongside the existing `DATABASE_URL`/secrets notes.

Both docs' existing content (SSH access notes, operator-user tables,
prior task histories, etc.) left untouched — this is an additive
landscape update matching the pattern of every prior task's
landscape-updater step in this repo.

## Issues / risks
None beyond what step-06/step-07 already flagged (SSH alias
`User root` vs. documented `User tvolodi` drift — left as-is, not this
task's scope to resolve).

## Open questions (optional)
None.
