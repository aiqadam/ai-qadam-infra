---
run_id: 2026-08-20-rotate-qa-directus-token-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-08-20T00:00:00Z
task_id: T-0137-rotate-qa-directus-admin-token
inputs_read:
  - tasks/T-0137-rotate-qa-directus-admin-token.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-06-executor-cicd.md
artifacts_changed: []
next_step_hint: Step 04 (solution-designer) MUST emit NEEDS_APPROVAL for this — the task's own Notes section is explicit that secret rotation is never auto-approved here, regardless of the low/full blast-radius/reversibility estimate in frontmatter. Step 02 (landscape reader) should confirm which credential qa.aiqadam.org's running app container actually consumes before the plan assumes zero app-side blast radius.
retry_of: null
---

## Summary

Rotate the QA Directus admin token (`DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN`) and `DIRECTUS_ADMIN_PASSWORD` on `pro-data-tech-qa`, after both values briefly appeared in a Claude Code session transcript on this workstation due to a filter bug in a diagnostic `grep` command run by `executor-cicd` during T-0136's execution.

## Details

### Why
> During `2026-08-20-seed-content-documents-qa-001` (executing T-0136), the `executor-cicd` subagent ran a disambiguation command against `/opt/apps/aiqadam-qa/deploy/.env` intended to print only comment/context lines around two candidate token variable names (`grep -n -B2 -A0 -E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN)=' deploy/.env | grep -v -E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN)='`). The intended `-v` exclusion filter did not suppress the matched lines as designed, so the actual plaintext values of `DIRECTUS_TOKEN` / `DIRECTUS_ADMIN_TOKEN` (identical values — the same secret referenced by two variable names) and an adjacent `DIRECTUS_ADMIN_PASSWORD` appeared in that subagent's tool-call output for one turn.
>
> **Scope of exposure:** local Claude Code session transcript only (this management workstation). Not committed to any file, not pushed to any git remote, not posted anywhere network-reachable. No evidence of external access. Self-reported immediately by the executor per its own "stop and report" instruction — not discovered after the fact.
>
> **User decision (2026-08-20):** rotate proactively rather than treat as acceptable risk, per standard practice for any credential that appears somewhere it shouldn't, even briefly and even in a private, single-viewer session.

Confirmed against the originating run's step-06 handoff (`2026-08-20-seed-content-documents-qa-001`, "Issues / risks" section): the executor itself confirms the deviation, names the exact command, confirms zero further propagation (no file, no repeat printing, no push), and explicitly leaves rotation as "the user's call, not pre-decided here" — which the user has now made.

That same source run also independently resolved a fact this task's checklist asks to reconfirm: Phase 1 step 3 established that `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` are two env-var names for the *same* secret value (not independent secrets) — disambiguated via the seed script's own hard dependency on the literal name `DIRECTUS_TOKEN`. This task's first checklist item asks to reconfirm this during execution rather than assume it; flagging it here as already-observed-but-not-yet-reverified.

- **Workflow:** infrastructure
- **Target scope:**
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
- **Constraints stated by user:**
  - Rotate both `DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN` and `DIRECTUS_ADMIN_PASSWORD` now (task title and Why section; user's verbatim request also names both explicitly).
  - Old token must be confirmed dead, not merely superseded (task Notes: "a rotation that leaves the old token functional defeats the purpose").
  - This is a secret rotation — per `workflows/infrastructure.md` / `shared/approval-protocol.md`, step 04 MUST emit `NEEDS_APPROVAL`, never auto-approve `PASS`, regardless of the task's own `estimated_blast_radius: low` / `estimated_reversibility: full` frontmatter (task Notes, stated twice for emphasis).
  - Sequencing: T-0136's eventual retry (blocked separately on an RBAC gap, not part of this task's scope) must happen *after* this rotation completes, so it doesn't reuse the compromised value.
  - `landscape/secrets-inventory.md` update must record rotation date only — never the value itself (repo hard rule, restated in task's "What done looks like").
- **Information gaps for downstream steps:**
  - Whether `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` are truly the same secret under two names needs re-confirmation during this execution (previously observed, not yet independently re-verified per this task's own checklist wording) — relevant because rotation must update both variable names consistently to the new value, in `/opt/apps/aiqadam-qa/deploy/.env`.
  - Which credential `qa.aiqadam.org`'s running app container actually uses for its own Directus reads is unconfirmed — task requires this be checked before assuming the app has zero blast radius from the rotation (it may use a separate, non-admin credential, or the same one).
  - Exact mechanism for rotating the Directus admin user's password/token (Directus admin UI vs REST `/users/me` or `/auth` endpoints vs CLI) is not yet established — a step-02 landscape read against `pro-data-tech-qa` and possibly Directus's own API docs will be needed.
  - How Directus needs to be restarted/reloaded (if at all — some Directus token rotation paths don't require a restart) after the .env update, to make the new token live, is unconfirmed.
  - T-0136's separate Directus RBAC permission gap (role lacks create permission on `content_documents`) is explicitly out of scope for this task — do not attempt to fix it here; it has its own follow-up task per step-06's "Open questions."

## Issues / risks

- This task executes on the same host (`pro-data-tech-qa`) and same credential family that produced the very exposure it's remediating — downstream steps (especially step-06 executor) must apply stricter output hygiene than the originating run did (e.g., never `grep` for a value pattern without `-o` capturing only the key name, never rely on a `-v` exclusion filter to suppress a secret value that could appear in matched-line context).
- Old-value revocation must be verified with a live negative test (old token → 401/403), not inferred from the .env file being overwritten — Directus may cache tokens or the admin user record may retain the old static token if only the .env is changed without also updating it at the Directus DB/API level.
- Approval gate risk: task Notes flag this explicitly as a case where an auto-`PASS` at step 04 would be a protocol violation regardless of blast-radius scoring — worth restating for step 04's benefit since the task's own frontmatter (`estimated_blast_radius: low`, `estimated_reversibility: full`) could otherwise look like an auto-approve candidate under the general low/reversible heuristic.

## Open questions (optional)

None — task is unambiguous and unblocked (`status: in-progress`, workflow declared, verdict PASS). The information gaps above are for step 02/03/04 to resolve, not blockers to starting this run.
