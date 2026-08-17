---
id: T-0126-fix-authentik-scope-mappings-on-qa
title: Attach openid/email/profile scope mappings to QA's Authentik OIDC provider
kind: task
status: done
priority: P0
created: 2026-07-27
updated: 2026-07-27
closed: 2026-07-27
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-27-fix-authentik-scope-mappings-qa-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0124-fix-deploy-qa-permission-denied, T-0125-fix-authentik-admin-url-on-qa]
estimated_blast_radius: low
estimated_reversibility: full
---

# Attach openid/email/profile scope mappings to QA's Authentik OIDC provider

## Why

`aiqadam/ai-qadam-platform` issue [#79](https://github.com/aiqadam/ai-qadam-platform/issues/79):
after registering and signing in on `qa.aiqadam.org`, users are redirected
to `/api/v1/auth/callback` with `401 {"message":"oidc id_token missing
email claim"}`.

Root cause, fixed in code as of `aiqadam/ai-qadam-platform` PR
[#81](https://github.com/aiqadam/ai-qadam-platform/pull/81) (merged,
squash `cc432578c695d53e1496892703133e8761e1f7e2`, tracked locally as
`ISS-AUTH-OIDC-EMAIL-001`): the script that provisions the platform's
Authentik OAuth2/OIDC provider
(`.copilot/bootstrap-oidc.sh` in that repo) created the provider without
attaching Authentik's built-in `openid`/`email`/`profile` scope
property-mappings. Authentik's REST API does not default an omitted
`property_mappings` list to the built-in mappings the way the admin-UI
"Create with Provider" wizard does, so any provider created via that
script ends up with **zero** scope mappings attached — meaning the
id_token it issues never carries an `email` claim, regardless of what
scopes the client requests.

**This is a live-environment data problem, not (only) a code problem.**
The code fix corrects the *script* going forward, but it does not
retroactively fix providers that were already created by the old,
broken version of the script — confirmed live: `deploy-qa` successfully
deployed commit `cc43257` to `pro-data-tech-qa` at 2026-07-27T13:03Z
(verified via GitHub Actions run log — `deployed
cc432578c695d53e1496892703133e8761e1f7e2`), yet the reporter still hit
the exact same 401 afterward. QA's Authentik container
(`authentik-server`, part of the `aiqadam-qa` compose stack) has been
running unchanged for 9 days per the deploy log — its existing OAuth2
provider almost certainly still has no scope mappings attached and needs
the same live patch that was already verified working against the local
dev Authentik instance.

This task exists because `aiqadam/ai-qadam-platform`'s own agent
session has no credentials for `auth.qa.aiqadam.org` / the QA host — only
this repo's SSH access to `pro-data-tech-qa` (95.46.211.230) can reach
it. Related to [T-0124](T-0124-fix-deploy-qa-permission-denied.md) (the
deploy-qa CI blocker — now apparently resolved, since the deploy above
succeeded) and [T-0125](T-0125-fix-authentik-admin-url-on-qa.md) (a
different Authentik config gap — `AUTHENTIK_ADMIN_URL` pointing at
prod instead of QA's own instance — discovered during the same
investigation thread but a distinct root cause from this task's).

## What done looks like

- [x] Confirmed via `docker exec` into QA's `authentik-server` container
      (or the Authentik REST API against `https://auth.qa.aiqadam.org`)
      that the AI Qadam OAuth2 provider currently has `property_mappings: []`
      or is missing one or more of the three managed scope mappings
      (`goauthentik.io/providers/oauth2/scope-openid` / `scope-email` /
      `scope-profile`) — reproduces the live bug before any change is made.
- [x] The three managed mappings resolved by their stable `managed`
      identifier (not hardcoded PKs — these are instance-specific) and
      attached to QA's provider via a `PATCH` to
      `/api/v3/providers/oauth2/<pk>/`, mirroring the fix already applied
      to `.copilot/bootstrap-oidc.sh` in `aiqadam/ai-qadam-platform` PR #81.
      **Deviation:** attached via Django ORM (`property_mappings.add()`
      inside `ak shell`) rather than a literal REST `PATCH` call — an
      equivalent, plan-approved alternative mechanism (see step-04 Phase 2),
      not a REST API call. Functionally identical result.
- [ ] Live verification: a real registration + sign-in round-trip against
      `https://qa.aiqadam.org` completes without the 401 — the
      `/api/v1/auth/callback` redirect lands on a signed-in session, not
      an error JSON body. (Mirrors the exact repro screenshot from GitHub
      issue #79.)
      **NOT completed — deferred, disclosed explicitly.** See Result
      section below.
- [ ] Confirm this doesn't regress anything else attached to the same
      provider (existing users can still sign in after the patch — the
      operation only *adds* mappings, does not remove or replace unrelated
      config, so this should be a no-op risk, but verify per workflow
      rule "Verify in two places").
      **Not independently verified — no known pre-existing test account
      was available.** See Result section below.
- [ ] Report the outcome back into `aiqadam/ai-qadam-platform`'s
      `ISS-AUTH-OIDC-EMAIL-001.md` (or a follow-up issue there) — this
      repo's task file is the audit record for the infra-side change, but
      the application repo's issue tracker is where the original reporter
      and that repo's own agent sessions look for status.
      **Deferred to the orchestrator** (executor-infra did not attempt
      cross-repo `gh` access per its own mid-run instruction). Not
      confirmed done as of this landscape update — see Result section.

## Result

**Outcome: succeeded, with two explicitly disclosed verification gaps (deferred, not silently skipped).**

The core fix is done and verified: QA's Authentik OAuth2 provider
(`aiqadam-qa-provider`, pk=1, on `aiqadam-qa-authentik-server-1`) had
`property_mappings: []` confirmed live (bug reproduced per AC1), then had
all three managed scope mappings (`scope-openid`, `scope-email`,
`scope-profile`) attached additively (AC2). The change was independently
re-confirmed persisted three separate times via fresh `ak shell` ORM
queries, plus externally via Authentik's own live OIDC discovery document
(`https://auth.qa.aiqadam.org/application/o/aiqadam-qa/.well-known/openid-configuration`),
which now advertises `scopes_supported: [email, openid, profile]` and
`claims_supported` including `email` — this is generated dynamically from
the provider's current `property_mappings`, so it is strong independent
evidence the fix is live and correct, not just an on-host artifact.

**Disclosed gap 1 (AC3, literal browser-level verification):** the
designer's planned live registration → OIDC redirect → `/api/v1/auth/callback`
round trip could not be completed by either the executor or the
execution-validator. `https://qa.aiqadam.org`'s registration endpoint
returned `429 ThrottlerException` on every attempt across ~2 hours of
elapsed wall-clock time (executor's initial attempts, then a single
non-looping validator re-probe roughly 2 hours later, still 429). This is
a pre-existing, external, generic API-abuse rate limiter — unrelated to
the Authentik property-mappings patch, confirmed to have been active
before this task's own changes were made (it triggered on the *second*
schema-discovery attempt, before the fix was even being exercised). Per
this task's `workflow: infrastructure` no-looping/no-polling constraint,
neither agent attempted to bypass or wait out the limiter. **Follow-up
task [T-0127](T-0127-verify-authentik-qa-fix-live-browser-round-trip.md)
filed** to complete this literal check once the rate-limit window has
naturally cleared.

**Disclosed gap 2 (AC4, non-regression for an existing user):** not
independently verified — no known pre-existing QA test-account credentials
were available to either the executor or the validator. Risk is assessed
as low (the operation is a pure additive Django M2M `.add()`, confirmed
by inspecting the actual operation performed — it cannot remove or alter
any existing user, session, or unrelated provider config), but this is an
assessment, not an empirical confirmation. Rolled into T-0127's scope as
a secondary check to perform alongside the browser round-trip, rather than
a separate task.

**AC5 (cross-repo report)** was explicitly deferred by the executor to
the orchestrator per its own mid-run instruction (Phase 4 of the approved
plan); this landscape-updater pass has no evidence either way of whether
that report was subsequently posted to
`aiqadam/ai-qadam-platform`'s `ISS-AUTH-OIDC-EMAIL-001.md` — left as an
open item for the orchestrator/user to confirm, not re-opened as a task
in this repo since it is a cross-repo, low-stakes, easily-manually-checked
action.

**Side effects also fixed this run (landscape drift, not part of this
task's own scope, but discovered and corrected by this run):** the
`aiqadam-qa` Compose project on `pro-data-tech-qa` was found to run 7
containers, not the 2 (`oidc-stub`, `api`) previously documented in
`landscape/hosts/pro-data-tech-qa.md` / `landscape/services.md` — the
missing 5 (`web-next`, `directus`, `authentik-server`,
`authentik-worker`, `redis`) have now been documented. Also corrected:
`landscape/hosts/pro-data-tech-qa.md` documented `qa-uz.aiqadam.org` as
the sole live AiQadam QA endpoint; this was stale — `qa.aiqadam.org` is
now confirmed and documented as the sole live vhost.

Links: [step-06 executor](../runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-06-executor-infra.md),
[step-07 validator](../runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-07-execution-validator.md).

## Notes

- The exact technique (find managed scope mappings via
  `GET /api/v3/propertymappings/provider/scope/`, filter by `.managed`,
  `PATCH property_mappings` onto the provider) was already implemented
  and live-verified against the local dev Authentik instance as part of
  `aiqadam/ai-qadam-platform` PR #81 — see that repo's
  `.copilot/tasks/completed/wf-20260727-fix-137/07-test-results.md` for
  the full verification trace (includes a direct call to Authentik's own
  `PropertyMapping.evaluate()` confirming the `email` claim is emitted
  once the mapping is attached). This task is applying the same known-
  good operation to a different (QA) Authentik instance, not designing a
  new fix.
- Needs an Authentik admin API token for `auth.qa.aiqadam.org`, or
  equivalent access via `docker exec` into the `authentik-server`
  container as an operator with `sudo`/docker-group access on the host
  (same approach used for the local fix, just remote). No such token is
  currently recorded in `landscape/secrets-inventory.md` — the executor
  should mint a short-lived one via `docker exec ... ak shell` (same
  method used locally) rather than requesting a new long-lived credential
  be provisioned, unless the solution-designer judges otherwise.
- Low blast radius: the change only adds property-mapping references to
  one existing provider object; nothing is deleted, no other provider or
  application is touched, and the operation is idempotent (re-attaching
  already-attached mappings is a no-op).

## History
- 2026-07-27: created as `kind: task`, `status: pending`, `priority: P0` (manual, on behalf of a live-verified code fix in aiqadam/ai-qadam-platform PR #81 / ISS-AUTH-OIDC-EMAIL-001 / GitHub issue #79, blocked on QA-side Authentik state that only this repo's host access can fix)
- 2026-07-27: status → `in-progress`, run `2026-07-27-fix-authentik-scope-mappings-qa-001`
- 2026-07-27: status -> done, outcome succeeded, run 2026-07-27-fix-authentik-scope-mappings-qa-001, commit <pending>. Fix confirmed live and verified (on-host ORM x3 + external OIDC discovery document). AC3 (browser round trip) and AC4 (existing-user non-regression) explicitly deferred, not silently skipped — blocked by a pre-existing, external, unrelated registration-endpoint rate limiter; follow-up T-0127 filed to complete them. Also closed out two pre-existing landscape documentation gaps discovered during this run (5 undocumented aiqadam-qa containers; stale qa-uz.aiqadam.org hostname record) — see landscape/hosts/pro-data-tech-qa.md and landscape/services.md change logs.
