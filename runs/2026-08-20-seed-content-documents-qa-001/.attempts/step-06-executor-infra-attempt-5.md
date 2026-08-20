---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 06
agent: executor-infra
verdict: BLOCKED
created: 2026-08-20T22:45:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/step-04-solution-designer.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-qa.md
artifacts_changed:
  - pro-data-tech-qa: directus database — bootstrap.sh executed (Phase 1). content_pages and content_documents collections created (expected). operator_invites collection had 7 fields DROPPED (destination_gmail, cf_destination_address_id, cf_destination_verified_at, cf_rule_id, resend_key_id, email_setup_status, email_setup_failed_reason) — unexpected, triggers this plan's STOP condition.
retry_of: step-06
next_step_hint: >-
  bootstrap.sh's output contained a real, already-executed modification to a
  pre-existing collection (operator_invites lost 7 fields via an
  [F-S2.12 — drop F-S2.8.x operator_invites.* email-routing fields] block),
  not just the "~77 no-ops + 2 creates" the approved plan's Phase 1.1
  verification expected. Per the plan's explicit STOP condition, execution
  halted immediately after Phase 1 — Phase 2 (schema verification), Phase 3
  (seed script), and Phase 4 (full verification) were NOT run. This needs a
  fresh solution-designer assessment: (a) is the operator_invites field drop
  itself safe/intended (it looks like a legitimate, deliberate schema
  cleanup — F-S2.12 reads as a real ticket/ADR reference for removing a
  superseded Cloudflare-email-routing feature's fields, not corruption), and
  (b) crucially, content_pages/content_documents WERE created successfully
  by this same bootstrap.sh run (confirmed further down in the verbatim
  output below) — so the original T-0136 schema gap this run exists to fix
  is now CLOSED as a side effect, even though this plan halted before its
  own Phase 2 could confirm that. The next agent should re-verify Phase
  2/3/4's checks fresh (they were never run under this plan's approval) and
  should explicitly decide whether the operator_invites field drop needs
  separate handling (rollback, landscape note, or accepted-as-intended) before
  proceeding, rather than treating the schema-gap fix as done or undone.
---

## Summary

Executed Phases 0 and 1 of the approved plan. Phase 0 (pre-flight) passed with one baseline-figure discrepancy (directus_collections held 50 rows, not the plan's approximate "~77", explained by directus_collections tracking only app-facing collections, not all 79 Postgres tables — not a blocker). Phase 1 (bootstrap.sh) ran to completion, exit code 0, and created the two target collections (content_pages, content_documents) as expected — but its output also contained an explicit block dropping 7 fields from the pre-existing operator_invites collection, which is a real schema modification to a pre-existing collection, not a no-op "exists" confirmation. Per the plan's explicit Phase 1.1 STOP condition, execution halted immediately; Phases 2–4 were NOT run. Verdict: BLOCKED.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (step-05-user-approval.md)
- Design references match: yes (step-05's inputs_read lists step-04-solution-designer.md)

### Execution log

#### Phase 0.1: Re-confirm checkout at or past target commit
- Command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git fetch origin && git log --oneline -1 && git merge-base --is-ancestor 627cd91 HEAD && echo AT_OR_PAST_TARGET || echo BEHIND_TARGET"`
- Exit code: 0
- Output:
  ```
  6e67229 chore(workflow): archive wf-20260819-feat-212, update workspace-state after FR-CMS-007 merge (#273)
  AT_OR_PAST_TARGET
  ```
- Result: success

#### Phase 0.2: Confirm both scripts present
- Command: `ssh pro-data-tech-qa "test -f /opt/apps/aiqadam-qa/infrastructure/directus/bootstrap.sh && test -f /opt/apps/aiqadam-qa/infrastructure/directus/seed-content-documents.sh && echo BOTH_SCRIPTS_PRESENT"`
- Exit code: 0
- Output: `BOTH_SCRIPTS_PRESENT`
- Result: success

#### Phase 0.3: Snapshot baseline collection count, confirm gap still present
- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -Atc \"SELECT count(*) FROM directus_collections;\" -c \"SELECT collection FROM directus_collections WHERE collection IN ('content_pages','content_documents');\""`
- Exit code: 0
- Output: count `50`; gap-check query returned zero rows (both collections absent, as expected).
- Result: success, with one discrepancy noted below.
- **Discrepancy investigated (read-only, still Phase 0):** the plan's baseline expectation was "~77" collections, based on today's earlier findings. Actual `directus_collections` row count was 50. Verified via `psql -l` that the correct `directus` database was targeted (confirmed present alongside `aiqadam_qa`, `aiqadam_test`, `authentik`, `postgres`), and via `\dt` that the database has 79 tables total — consistent with prior findings. The gap between 79 Postgres tables and 50 `directus_collections` rows is explained by `directus_collections` only tracking app-facing/user-defined collections, not Directus's own internal system tables (`directus_users`, `directus_sessions`, etc.), which are still real Postgres tables but never appear in `directus_collections`. This is a semantic clarification of the plan's approximate figure, not evidence of drift or a wrong target — the critical fact (content_pages/content_documents absent) was confirmed correctly. Proceeded to Phase 1 on this basis.

#### Phase 1.1: Run bootstrap.sh
- Command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && DIRECTUS_URL=http://127.0.0.1:3119 DIRECTUS_TOKEN=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) bash infrastructure/directus/bootstrap.sh"`
- Exit code: 0
- Output (trimmed of the long "exists" no-op stream; full stream was reviewed in full before this trim — see note below):
  ```
  ... [several hundred lines, majority pattern: "✓ <item> (exists)" — no-op confirmations for pre-existing collections/fields/relations/policies/permissions] ...

  [FR-EVT-007 — topics]
    + collection topics (created)
    + relation topics.country -> countries.code (created)
  [FR-EVT-007 — seed topics for uz/kz/tj]
    + topic <24 topic rows> (created)
  [FR-EVT-007 — event_topics]
    + collection event_topics (created)
    ... relations (created)

  [FR-NTF-005 — directus_users.notification_email_enabled]
    + field directus_users.notification_email_enabled (created)
  [FR-NTF-005 — directus_users.notification_telegram_enabled]
    + field directus_users.notification_telegram_enabled (created)

  [ISS-SEC-PUBLIC-UNMANAGED-001 — scope Public reads on events / speakers / event_speakers]
    ✓ revoke public events/read (already absent)
    ✓ revoke public speakers/read (already absent)
    ✓ revoke public event_speakers/read (already absent)
    + perm public events/read (created)
    + perm public speakers/read (created)
    + perm public event_speakers/read (created)
  [✓ ISS-SEC-PUBLIC-UNMANAGED-001 fix complete]

  [policy.member / policy.speaker / policy.sponsor_rep / policy.organizer / policy.country_lead / policy.svc_bot / policy.svc_worker — read/write grants]
    + perm <~35 permission rows across 7 existing policies> (created)

  [F-S1.6 — directus_users fields]
    ... mostly "(exists)" ...
  [ISS-RBAC-ONBOARDED-AT-001 — directus_users.onboarded_at]
    + field directus_users.onboarded_at (created)

  [F-S2.7 — operator_invites]
    ✓ collection operator_invites (exists)
    ✓ relation operator_invites.created_by -> directus_users.id (exists)
    ✓ relation operator_invites.revoked_by -> directus_users.id (exists)
    ✓ relation operator_invites.target_user -> directus_users.id (exists)
  [F-S2.12 — drop F-S2.8.x operator_invites.* email-routing fields]
    - field operator_invites.destination_gmail (dropped)
    - field operator_invites.cf_destination_address_id (dropped)
    - field operator_invites.cf_destination_verified_at (dropped)
    - field operator_invites.cf_rule_id (dropped)
    - field operator_invites.resend_key_id (dropped)
    - field operator_invites.email_setup_status (dropped)
    - field operator_invites.email_setup_failed_reason (dropped)

  [F-WebU3/F-WebU9/F-WebU12/F-WebU11 — event_materials / event_photos / event_questions / event_sponsors]
    ... mostly "(exists)" ...
    + perm event_materials/read (public, created)
    + perm event_photos/read (public, created)
    + perm event_questions/read (public, created — status=published, restricted fields)
    + perm event_sponsors/read (public, created)
    + perm sponsors/read (public, created — restricted fields, status=active)

  [site_settings] / [press_page] / [badge_definitions] / [team_members]
    ... mostly "(exists)" ...
    + perm site_settings/read (public, created)
    + perm press_page/read (public, created)
    + perm badge_definitions/read (public, created)
    + perm team_members/read (public, created)

  [content_pages]
    + collection content_pages (created)
  [content_documents]
    + collection content_documents (created)
  [FR-CMS-007 — public read: content_pages, content_documents]
    + perm public content_pages/read (created)
    + perm public content_documents/read (created)

  ✅ Directus schema bootstrapped.
  Next: run infrastructure/directus/migrate-from-platform.sh to copy
  the existing platform.events / .registrations / .point_awards rows.
  ```
- Result: **script exit 0, but STOP condition triggered on review of output.**
- Backup taken: n/a (Phase 1 has no pre-declared backup step per the plan; bootstrap.sh's own design was assessed by the plan as additive/idempotent, which is contradicted by the operator_invites finding below)

### STOP condition evaluation (per plan's Phase 1.1 and the task's explicit instruction)

The plan's Phase 1.1 verification required: exit code 0 (met); ~77 pre-existing collections shown as no-op "exists" (largely met — vast majority of output is `✓ ... (exists)` lines); **exactly two new creation lines for content_pages and content_documents** (NOT met in isolation — content_pages/content_documents were created as expected, but the run also contained substantial additional creation activity: a new `topics` collection + `event_topics` collection + ~24 topic rows, ~2 new fields on `directus_users`, ~35+ new permission rows across 7 existing policies, several new public read permissions on existing collections (event_materials, event_photos, event_questions, event_sponsors, sponsors, site_settings, press_page, badge_definitions, team_members), and — critically — **an explicit field-drop block removing 7 fields from the pre-existing `operator_invites` collection**.

The field-drop is the decisive trigger. It is verified, independently, as a real and already-executed change: a follow-up read-only query against `information_schema.columns` for `operator_invites` confirms none of the 7 dropped field names exist on the table post-bootstrap. This is not a "no-op-confirm exists" line — it is bootstrap.sh **modifying** a pre-existing collection by deleting fields from it, which is exactly what the plan's Phase 1.1 STOP condition names verbatim: *"If the output shows bootstrap.sh attempting to modify (not just no-op-confirm) any of the ~77 pre-existing collections (e.g. altering fields, changing permissions on collections other than the 2 new ones): STOP immediately, do not proceed to Phase 2, emit BLOCKED, and report the unexpected diff verbatim."*

Per that instruction, execution halted immediately after Phase 1. Phase 2 (schema-gap verification), Phase 3 (seed script), and Phase 4 (full external verification) were **not attempted**.

#### Read-only confirmation query (post-hoc verification of the field drop, not a Phase-2 step)
- Command: `ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -Atc \"SELECT column_name FROM information_schema.columns WHERE table_name='operator_invites' ORDER BY 1;\""`
- Exit code: 0
- Output: 20 columns listed (aup_accepted_at, aup_version, authentik_user_id, consumed_at, country, created_at, created_by, delivery_channel, display_name, email, expires_at, id, notes, revoked_at, revoked_by, role_groups, status, target_user, token_hash, token_prefix) — none of the 7 dropped field names present.
- Result: confirms the drop took effect; this is a fact-finding query about the completed Phase 1 action, not a Phase 2 plan step.

### Rollback executed

Not executed. The plan's rollback section for Phase 1 describes bootstrap.sh as "additive/idempotent... not expected to alter or delete any of the ~77 pre-existing collections" — the operator_invites finding contradicts that premise, so this plan's own rollback guidance may not be the right response (the field drop may be an intended, separate schema-cleanup change under its own ticket `F-S2.12`/`F-S2.8.x`, not an accident). Per my role definition (§ "Stop on first error... run rollback steps for everything already applied" applies to FAIL, not necessarily to this STOP-and-reassess BLOCKED case) and the plan's own instruction to "report the unexpected diff verbatim" rather than improvise, I did not attempt to reverse the field drop or drop the two new collections. That decision is deferred to a fresh solution-designer assessment, per the plan's own STOP-condition language ("this would... need a fresh assessment, not continued execution").

### Resources changed

- **Files on host:** none (bootstrap.sh operates via Directus REST API, not file edits).
- **Services restarted:** none.
- **External resources changed:**
  - `directus` database, `directus_collections`/`directus_fields`/`directus_permissions` etc. (via Directus schema API): `content_pages` and `content_documents` collections created (target of this run — expected and matches T-0136's goal), plus a substantial amount of other additive schema (new `topics`/`event_topics` collections, new fields on `directus_users`, many new permission rows across existing policies) that bootstrap.sh's broader FR/ISS-scoped design intent covers but which exceeds the "~77 no-op + 2 create" delta this specific plan's approval was scoped around.
  - `operator_invites` collection (pre-existing): 7 fields dropped (destination_gmail, cf_destination_address_id, cf_destination_verified_at, cf_rule_id, resend_key_id, email_setup_status, email_setup_failed_reason) — confirmed via live schema query.
  - No seed data was written (Phase 3 never reached) — `content_documents` table exists but is empty.

## Issues / risks

- **STOP condition fired: operator_invites lost 7 fields during bootstrap.sh.** This is the primary reason for BLOCKED. The change is already live on QA (bootstrap.sh already ran to completion; there is no way to have partially stopped it mid-script since the plan's Phase 1.1 command is a single atomic invocation). Whether this is a benign, intended cleanup (the label `F-S2.12 — drop F-S2.8.x operator_invites.* email-routing fields` reads as a legitimate, deliberate removal of a superseded Cloudflare-email-routing feature's fields — plausibly landed in the `aiqadam` repo's bootstrap.sh source between whenever QA was last bootstrapped and now) or an unreviewed side effect that should be flagged more broadly is a judgment call this executor is not positioned to make — per my role's "no off-plan changes... note it for the user" rule and the plan's own explicit STOP instruction, I am surfacing it rather than deciding.
- **The original T-0136 schema gap (content_pages/content_documents missing) is now closed as a side effect of this same bootstrap.sh run**, even though this plan halted before Phase 2 could formally confirm it. Both collections show `+ ... (created)` in the verbatim output, and the operator_invites-column query (a live DB read) incidentally confirms the DB is responsive and schema changes are taking effect. The next agent should not need to re-run bootstrap.sh — only re-verify Phase 2/3/4 fresh and resolve the operator_invites question first.
- **Phase 3 (seed script) and Phase 4 (external verification) were not run.** The 5 governance-document rows are NOT yet seeded; `/rules`, `/about`, `/history`, `/partners` were not checked this attempt.
- **No secret values were echoed, logged, or written anywhere in this handoff** — `DIRECTUS_ADMIN_TOKEN` was read fresh via inline command substitution in each SSH session per the plan's redaction discipline.
- **Baseline collection-count figure in the approved plan ("~77") does not match `directus_collections`'s actual row count (50).** Explained (see Phase 0.3 above) by `directus_collections` tracking only app-facing collections, not all 79 Postgres tables. Not a blocker for this run, but worth correcting in the landscape/task record so the next plan doesn't re-encounter the same apparent (but benign) discrepancy as a fresh surprise.

## Open questions (optional)

- Should `operator_invites`'s 7 dropped fields be reinstated, or is this drop an intended, already-decided cleanup (per its own `F-S2.12`/`F-S2.8.x` ticket reference) that simply hadn't been applied to QA yet, same as the content_pages/content_documents gap itself? This determines whether the "unexpected diff" is actually unexpected or just previously-undeployed intended work — needs someone with visibility into the `F-S2.12`/`F-S2.8.x` ticket history to confirm, not something inferable from this host alone.
- Given content_pages/content_documents are now confirmed created (per bootstrap.sh's own output), should the next attempt re-run bootstrap.sh at all, or skip straight to a fresh Phase 2 (schema verification) once the operator_invites question is resolved? Re-running bootstrap.sh is expected to be a safe no-op for everything just created (idempotent by design), but given this run's finding that "idempotent" doesn't mean "delta-limited to what this plan expected," a fresh solution-designer pass should decide explicitly rather than defaulting to re-run.
