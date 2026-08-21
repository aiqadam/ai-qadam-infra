---
id: T-0141-provision-rules-source-file-downloads-qa
title: Provision source-file downloads for /rules on QA Directus (aiqadam FR-CMS-008)
kind: task
status: blocked
priority: P2
created: 2026-08-21
updated: 2026-08-21
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: [2026-08-21-provision-rules-downloads-qa-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: deploy-app
blocks: []
blocked_by: []
related: [T-0136-seed-content-documents-qa, T-0139-verify-no-other-stale-qa-directus-schema-drift]
estimated_blast_radius: low
estimated_reversibility: full
---

# Provision source-file downloads for /rules on QA Directus (aiqadam FR-CMS-008)

## Why

`aiqadam/ai-qadam-platform` PR [#274](https://github.com/aiqadam/ai-qadam-platform/pull/274)
(merged, `FR-CMS-008`) makes the source-document filename on
`qa.aiqadam.org/rules/<slug>` a real download link instead of the inert
citation label FR-CMS-007 originally shipped. The **code** is merged and
live, but the **data and schema it depends on are not provisioned on QA**
— exactly the same gap class as T-0136, which is why this is being
tracked as its own task rather than assumed to happen automatically.

Two scripts must run against QA, in order:

1. `infrastructure/directus/bootstrap.sh` — creates the new
   `content_documents.source_file` field, its relation to
   `directus_files`, the dedicated `public-documents` Directus folder,
   and the **folder-scoped anonymous read grant** on `directus_files`.
2. `infrastructure/directus/seed-content-documents.sh` — uploads the 5
   governance `.docx` files into that folder and links each to its
   `content_documents` row.

**Current user-visible state:** `qa.aiqadam.org/rules/manifesto` shows
`AI Qadam Manifesto.docx` as plain text with no download link (confirmed
live 2026-08-21, post-merge). Per FR-CMS-008 AC-8 this is the *intended*
fallback when `source_file` is null, not a defect — but it is also not
the shipped feature.

**Why the ordering is load-bearing:** without step 1's grant, anonymous
`GET /assets/:id` returns **403** and every download link is broken even
though the page renders it. FR-CMS-008's security review established
this empirically (the prior assumption that Directus serves assets
without a `directus_files` permission grant was tested against live
Directus and found false). Running the seed before bootstrap produces
uploaded-but-unreadable assets.

## What done looks like

- [ ] **(prerequisite, confirmed missing 2026-08-21)** The 5 source
      `.docx` files are present at
      `/opt/apps/aiqadam-qa/portal-content/20260819/` on the QA host.
      Pre-flight check found `portal-content/` **does not exist there at
      all** — it is gitignored in the app repo, so it has never been
      deployed. The FR-CMS-008 *code* IS present (verified: 8
      `source_file` refs in `bootstrap.sh`, 5 `PUBLIC_ASSET_FOLDER_ID`
      refs in the seed script), so this is the only blocker.
      **User decision 2026-08-21: `scp` the 5 files from the management
      workstation** (`c:\Users\tvolo\dev\ai-dala\aiqadam\portal-content\20260819\`)
      rather than committing them to git or uploading directly to
      Directus. Note this makes the files host-local and non-reproducible
      — they would be lost on a host rebuild and would need re-copying;
      accepted trade-off to keep several MB of binary `.docx` out of git
      history.
- [ ] `bootstrap.sh` run against QA Directus. Expected delta: the
      `source_file` field + relation, the `public-documents` folder, and
      the folder-scoped `directus_files` read grant. **Every other
      collection must report `✓ exists` / no-op** — this script also
      carries unrelated schema-enforcement blocks (see T-0136's history:
      the `F-S2.12 operator_invites` field drop is a legitimate,
      already-integrated cleanup, but any *new* unexpected modification
      to a pre-existing collection is a STOP condition, not something to
      run past).
- [ ] `seed-content-documents.sh` run against QA. Expected: 5 files
      uploaded into `public-documents`, each row's `source_file` set.
      Script is idempotent — a re-run must not create duplicate
      `directus_files` rows.
- [ ] Anonymous (unauthenticated) `GET <directus>/assets/<id>?download`
      for a seeded file returns **200** with `Content-Disposition:
      attachment` preserving the real filename (e.g.
      `AI Qadam Manifesto.docx`) — this is the actual acceptance signal,
      not merely that the row has a non-null `source_file`.
- [ ] Negative check: an asset **outside** the `public-documents` folder
      still returns **403** to anonymous requests, and anonymous
      `GET /files` does not enumerate the whole file table. The grant is
      deliberately folder-scoped; confirming the scope held is part of
      done, since an over-broad grant would itself be a security finding.
- [ ] Live browser/curl check: `https://qa.aiqadam.org/rules/manifesto`
      renders a working download link alongside the existing label, and
      the link resolves to the **public** Directus host — not the
      internal `directus:8055` docker alias (FR-CMS-008 fixed this in
      code; confirming it on the real rendered page is what proves the
      fix works in the deployed environment).
- [ ] The other 4 document pages (`charter-v0-1`, `kazakhstan-mou`,
      `global-board-polozhenie-v1`, `soglashenie-v1`) each render a
      working download link.
- [ ] `qa.aiqadam.org/rules` and the 3 sibling FR-CMS-007 pages
      (`/about`, `/history`, `/partners`) still return 200 — no
      regression from the schema change.

## Result

**BLOCKED before execution — nothing on QA was touched.** Run
`2026-08-21-provision-rules-downloads-qa-001` completed steps 01–03
(all PASS) and stopped at pre-planning when the Orchestrator settled an
open question step 03 had flagged as potentially task-shape-changing.

**The blocker (a code gap, not an infra gap):** FR-CMS-008's merged code
hardcodes the public download host as a module constant —
`const PUBLIC_DIRECTUS_URL = 'https://cms.aiqadam.org'`
(`apps/web-next/src/lib/cms.ts:14`), consumed by `publicAssetUrl()` at
L875. There is **no environment override** — grep across
`apps/web-next/src/` finds only that one constant and its two uses, and
QA's `deploy/.env` has no `CMS_URL`/`PUBLIC_*` key of any kind (only the
6 `DIRECTUS_*` keys, all server-side).

Consequences, verified live 2026-08-21:
- `cms.qa.aiqadam.org` → does not resolve (`000`)
- `directus.qa.aiqadam.org` → does not resolve (`000`)
- `cms.aiqadam.org` → `523` (Cloudflare: origin unreachable)

So even if this task ran perfectly — files copied, `bootstrap.sh` and
`seed-content-documents.sh` both clean, `source_file` set on all 5 rows —
QA's rendered pages would emit download links pointing at a **production**
hostname that is currently **unreachable**. AC-4, AC-6 and AC-7 would be
unsatisfiable. This is precisely why step 03 required the question be
settled before planning rather than discovered at execution.

Worth noting: this is not a defect in what FR-CMS-008's own review
verified. Its security review correctly established that the *internal*
docker URL must not be emitted to browsers, and the fix for that is
sound. The gap is that the replacement is a single hardcoded production
constant, which no acceptance criterion in FR-CMS-008 exercised because
none of them ran against a non-production environment.

**User decision 2026-08-21:** fix the code first — make the public CMS
URL environment-configurable — rather than papering over it with an
infra-only change (adding a QA Directus vhost alone would NOT help, since
the code would still emit `cms.aiqadam.org` on QA). Two follow-ups are
therefore needed before this task can resume:

1. **App repo** (`aiqadam/ai-qadam-platform`): replace the hardcoded
   `PUBLIC_DIRECTUS_URL` with an env-configurable value, defaulting to
   the current production URL so prod behavior is unchanged.
2. **Infra** (likely a sibling task to this one): expose QA's Directus
   at a QA-specific public hostname (DNS + nginx vhost + TLS), and set
   the new env var in QA's `deploy/.env` to match.

This task resumes once both land. Its own scope (copy files, run the two
scripts, verify) is unchanged and still correct — it was simply never
runnable-to-green in the current environment.

## Notes

- **Source files location:** the 5 `.docx` files live at
  `portal-content/20260819/` in the `aiqadam` app repo checkout on the
  QA host (`/opt/apps/aiqadam-qa/`). That directory is **gitignored** —
  confirm it is actually present on the host before running the seed
  script; if it isn't, the script skips uploads (by design, non-fatal)
  and this task cannot complete until the files are placed there. This
  is the most likely blocker and should be checked in discovery, not
  discovered at execution time.
- **Checkout freshness:** the QA checkout must be at or past PR #274's
  merge commit for the scripts to contain the FR-CMS-008 changes at all.
  T-0136 found the checkout was already current, but re-verify — the
  scripts' new behavior is the entire point of this task.
- **Credential:** use `DIRECTUS_ADMIN_TOKEN` from
  `/opt/apps/aiqadam-qa/deploy/.env`, read fresh at execution time.
  Note this was rotated 2026-08-20 (T-0137) — do not reuse any value
  from an earlier run's notes.
- **Output hygiene:** this host/credential family had two secret-exposure
  incidents on 2026-08-20 (T-0137, T-0138). The standing rule applies:
  never combine `grep -B/-A` with `-v`, on any file; inline-substitute
  secrets within a single SSH session; verify via status codes, counts,
  or digests only.
- **Blast radius rationale (`low`/`full`):** additive schema + additive
  content, no credential change, no container restart expected, and the
  seed is idempotent. This is materially lower-risk than T-0138's
  rotation. The one elevated element is `bootstrap.sh`'s full-schema
  surface, which T-0136 already exercised once against this instance
  (the collections it would touch are now current), so the expected
  delta here is genuinely just the FR-CMS-008 additions.
- Source PR: `aiqadam/ai-qadam-platform`
  [#274](https://github.com/aiqadam/ai-qadam-platform/pull/274)
  (`FR-CMS-008`). Full workflow artifacts:
  `.copilot/tasks/completed/wf-20260821-feat-213/` in that repo —
  particularly `04-security-review.md`, which documents the anonymous-403
  finding and the folder-scoping requirement in detail.

## History
- 2026-08-21: created (manual, to provision the data/schema FR-CMS-008's
  merged code depends on — user requested immediately after PR #274
  merged)
- 2026-08-21: status → `in-progress`, run
  `2026-08-21-provision-rules-downloads-qa-001`. Pre-flight already
  established: FR-CMS-008 code present on the QA host; `portal-content/`
  absent (the one blocker); user chose `scp` as the delivery method.
- 2026-08-21: status → `blocked`. Steps 01–03 PASS; halted at
  pre-planning. Blocker: FR-CMS-008 hardcodes the public download host
  (`cms.aiqadam.org`) with no env override, and QA has no Directus vhost
  — QA links would point at an unreachable prod host. Nothing on QA
  touched. Resumes after the app-repo env-config fix + a QA Directus
  vhost land. See Result section.
