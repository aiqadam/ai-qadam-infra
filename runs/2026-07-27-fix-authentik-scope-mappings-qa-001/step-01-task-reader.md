---
run_id: 2026-07-27-fix-authentik-scope-mappings-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-27T00:00:00Z
task_id: T-0126-fix-authentik-scope-mappings-on-qa
inputs_read:
  - tasks/T-0126-fix-authentik-scope-mappings-on-qa.md
artifacts_changed: []
next_step_hint: landscape-reader should load landscape/hosts/pro-data-tech-qa.md and landscape/services.md, plus landscape/secrets-inventory.md to confirm no Authentik QA admin token is already recorded.
---

## Summary
Attach Authentik's built-in `openid`/`email`/`profile` scope property-mappings to the AI Qadam OAuth2 provider on QA's Authentik instance (`pro-data-tech-qa`, `auth.qa.aiqadam.org`), so the OIDC id_token carries the `email` claim and the 401 "oidc id_token missing email claim" bug from `aiqadam/ai-qadam-platform` issue #79 stops reproducing on QA — mirroring the code fix already merged and live-verified against the local dev instance in PR #81.

## Details
- **Workflow:** infrastructure
- **Target scope:**
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
- **Constraints stated by user:**
  - Run through ai-qadam-infra's own orchestrator workflow with its normal approval gate — explicitly not an ad-hoc SSH session that bypasses it. This was confirmed by the user in response to a clarifying question, so it is a hard constraint on execution mechanics, not just a preference.
  - Only copy from ai-qadam-infra "those [credentials] which are needed" — i.e. minimal/scoped credential use, not a blanket credential dump. In practice this means: mint a short-lived Authentik admin token/session on QA via `docker exec ... ak shell` (same method used for the already-verified local fix) rather than requesting or provisioning a new long-lived credential, per the task's own Notes section — unless the solution-designer judges otherwise.
- **Information gaps for downstream steps:**
  - No Authentik admin API token for `auth.qa.aiqadam.org` is currently recorded in `landscape/secrets-inventory.md` (per task Notes) — landscape-reader should confirm this is still true, and solution-designer must decide the exact minting mechanism (`docker exec` into `authentik-server` + `ak shell`, matching the local-dev precedent from PR #81).
  - The QA provider's current `pk` (provider ID) and its current `property_mappings` state are not yet confirmed live — first acceptance criterion requires reproducing the bug (empty or partial `property_mappings`) before any patch, via `docker exec` or the REST API against `https://auth.qa.aiqadam.org`.
  - The three managed mapping identifiers (`goauthentik.io/providers/oauth2/scope-openid`, `scope-email`, `scope-profile`) must be resolved to QA-instance-specific PKs via `GET /api/v3/propertymappings/provider/scope/` filtered by `.managed` — not hardcoded, since PKs are instance-specific (explicit in task body).
  - Relationship to T-0124 (deploy-qa permission-denied — related, apparently resolved per task Why section, since the triggering deploy of commit cc43257 succeeded) and T-0125 (AUTHENTIK_ADMIN_URL pointing at prod instead of QA — a distinct root cause, discovered in the same investigation thread) should be checked by landscape-reader/task-validator for any residual interaction, even though the task author judges them independent.
  - After the infra-side fix, the task requires reporting the outcome back into `aiqadam/ai-qadam-platform`'s `ISS-AUTH-OIDC-EMAIL-001.md` or a follow-up issue there — this is a cross-repo reporting step that step-06/step-08 will need to account for (out of band from this repo's own landscape files).

## Issues / risks
- This is a P0 task modifying a live QA authentication provider. Blast radius is stated as low and reversibility as full (additive-only property-mapping attachment, idempotent), but step-04 solution-designer should still explicitly verify the "verify in two places" workflow rule called out in the task's acceptance criteria (confirm existing users can still sign in after the patch).
- Credential minting (short-lived Authentik admin token via `ak shell`) is itself a state-changing-adjacent action on the QA host; solution-designer and executor should treat it with the same care as the property-mapping patch itself, even though it's described as a known-good, previously-exercised technique.
- Task status was already `in-progress` with this run_id recorded in `executed_by_runs:` at time of reading (orchestrator's run-initialization step appears to have already transitioned it) — no action needed here, noted for downstream awareness.

## Open questions (optional)
none — task is clear and well-formed; proceeding with verdict PASS.
