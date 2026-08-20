---
id: T-0139-verify-no-other-stale-qa-directus-schema-drift
title: Verify no other stale/never-fully-bootstrapped QA Directus schema drift exists beyond what T-0136 happened to find
kind: observation
status: observation
priority: P2
created: 2026-08-20
updated: 2026-08-20
closed:
outcome:
created_by: 2026-08-20-seed-content-documents-qa-001
source_runs: [2026-08-20-seed-content-documents-qa-001]
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: none
blocks: []
blocked_by: []
related: [T-0136-seed-content-documents-qa]
estimated_blast_radius: low
estimated_reversibility: full
---

# Verify no other stale/never-fully-bootstrapped QA Directus schema drift exists beyond what T-0136 happened to find

## Why

`T-0136`'s investigation (run `2026-08-20-seed-content-documents-qa-001`,
final resolution documented in that task's Result section and in
`landscape/hosts/pro-data-tech-qa.md`'s Change log) found that
`infrastructure/directus/bootstrap.sh` had apparently never been run to
completion against QA's Directus instance before 2026-08-20 — despite
~77 other collections already existing there (presumably from some
earlier, partial, or differently-sourced provisioning path). The
task-scoped fix (running bootstrap.sh in full) closed the specific gap
T-0136 was looking for (`content_pages`/`content_documents` missing) and
incidentally applied one other pending change (`F-S2.12`'s
`operator_invites` field drop, confirmed benign and dated 2026-05-25).

Both of those were things bootstrap.sh's own source already knew about.
The open question this observation exists to capture: **if bootstrap.sh
had drifted this far out of sync with QA's actual state, are there other
FR/ISS-scoped schema changes in `bootstrap.sh` — or other Directus schema
expectations maintained elsewhere in the `aiqadam` codebase entirely
outside `bootstrap.sh` — that QA is also silently missing, which nobody
has happened to notice yet** because no one has hit the specific 403 or
missing-feature symptom the way T-0136 did for `/rules`? T-0136's
investigation was necessarily narrow (scoped to the one symptom reported)
and does not constitute a systematic audit.

Quoting the source run's own framing (`step-06-executor-infra.md`
Phase 1 discussion, corroborated by `step-04-solution-designer.md`'s
root-cause recap): "QA's schema was simply stale on this too, the same
underlying pattern as the missing `content_pages`/`content_documents`
collections (this was the first time `bootstrap.sh` had been run to
completion against QA)." The scope of what else might be stale beyond
that one run's findings was explicitly out of scope for T-0136 and is
carried forward here.

## What done looks like

- [ ] Determine (from `aiqadam` repo git history / commit messages, or
      from asking whoever provisioned QA's Directus originally) when
      `bootstrap.sh` was last actually run against QA before 2026-08-20,
      and by what mechanism the ~77 pre-existing collections got there
      if not via a full bootstrap.sh run.
- [ ] Diff `bootstrap.sh`'s full current intended schema (all
      FR-/ISS-tagged blocks) against QA's live `directus_collections` /
      `directus_fields` / `directus_permissions` state, beyond just the
      two collections and one field-drop T-0136 happened to touch —
      confirm there are no other pending creates/drops that simply
      haven't surfaced as a user-visible symptom yet.
- [ ] Check whether any other Directus schema expectations exist in the
      `aiqadam` codebase outside `bootstrap.sh` (e.g. other seed/migrate
      scripts, app-code assumptions about fields that may not be
      reflected in bootstrap.sh) that could have the same
      never-applied-to-QA gap.
- [ ] Decide whether QA needs an ongoing drift-detection mechanism (e.g.
      a scheduled dry-run comparison) so this class of gap surfaces
      proactively next time, rather than only when a user hits a broken
      page — this may overlap with the deploy-freshness gap already
      tracked by `T-0133`.
- [ ] Record findings in `landscape/hosts/pro-data-tech-qa.md`; file
      follow-up tasks for anything found, or explicitly note "no
      further drift found" if the audit comes back clean.

## Result

<empty until closed>

## Notes

- This is explicitly a "go looking for more of the same" task, not a
  report of a known additional gap — the audit itself may well come back
  clean. Its value is closing the open question T-0136 left behind, not
  a presumption that something is definitely broken.
- Related: `T-0133` (QA silently ran a 16-commit-stale build for a full
  day with no alert) is a different but adjacent staleness problem
  (code/deploy freshness, not schema freshness) — worth considering
  together when scoping any drift-detection mechanism.

## History
- 2026-08-20: created from run `2026-08-20-seed-content-documents-qa-001`
