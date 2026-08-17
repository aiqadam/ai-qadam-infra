---
id: T-0127-verify-authentik-qa-fix-live-browser-round-trip
title: Complete the deferred live browser registration/sign-in round trip for QA's Authentik fix
kind: observation
status: observation
priority: P2
created: 2026-07-27
updated: 2026-07-27
closed:
outcome:
created_by: 2026-07-27-fix-authentik-scope-mappings-qa-001
source_runs: [2026-07-27-fix-authentik-scope-mappings-qa-001]
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0126-fix-authentik-scope-mappings-on-qa]
estimated_blast_radius: low
estimated_reversibility: full
---

# Complete the deferred live browser registration/sign-in round trip for QA's Authentik fix

## Why

[T-0126](T-0126-fix-authentik-scope-mappings-on-qa.md) attached the three
managed scope mappings (`openid`/`email`/`profile`) to QA's Authentik
OAuth2 provider (`aiqadam-qa-provider`, pk=1), fixing the root cause of
GitHub issue #79 (missing `email` claim → 401 on
`/api/v1/auth/callback`). The fix itself is verified live via three
independent on-host `ak shell` ORM queries and externally via Authentik's
own OIDC discovery document (`scopes_supported`/`claims_supported` now
include `email`) — strong evidence the fix is correct and effective.

However, the task's own acceptance criteria called for a literal
end-to-end browser registration → OIDC redirect → `/api/v1/auth/callback`
round trip (mirroring the exact repro screenshot from GitHub issue #79),
and this was **not completed** by either the executor
(`runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-06-executor-infra.md`)
or the execution-validator
(`runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-07-execution-validator.md`).
`https://qa.aiqadam.org`'s registration endpoint returned
`429 {"statusCode":429,"message":"ThrottlerException: Too Many Requests"}`
on every attempt across roughly 2 hours of elapsed wall-clock time
(executor's initial attempts, then one further non-looping validator
probe ~2 hours later — still 429). This is a pre-existing, external,
generic API-abuse rate limiter unrelated to the Authentik patch — it is
outside this task's scope to bypass, and neither agent was permitted to
loop/poll waiting for it to clear.

Additionally, [T-0126](T-0126-fix-authentik-scope-mappings-on-qa.md)'s
non-regression check (an existing, pre-patch user can still sign in
after the fix) was also not independently verified — no known
pre-existing QA test-account credentials were available to either
session. Risk is assessed as low (the change is a pure additive M2M
`.add()`), but this has not been empirically confirmed.

This task exists so that gap is tracked and closed out deliberately,
rather than silently dropped once T-0126 closes.

## What done looks like

- [ ] Once the registration endpoint's rate limiter has naturally
      cleared (unknown exact window — observed still active ~2 hours
      post-patch; check via a single non-looping probe before
      attempting a real registration), complete a real registration +
      sign-in round trip against `https://qa.aiqadam.org`: register a
      new, never-used test account, complete the Authentik OIDC
      redirect, confirm the `/api/v1/auth/callback` redirect lands on a
      signed-in session (not the `401 {"message":"oidc id_token missing
      email claim"}` error from GitHub issue #79).
- [ ] If a pre-existing QA test account is available (or can be
      registered once the limiter clears and then reused), confirm that
      account can still sign in after T-0126's patch — the
      non-regression check T-0126 could not complete.
- [ ] Record the actual rate-limit window duration observed (useful
      context for future QA verification tasks that hit the same
      endpoint).
- [ ] Update `landscape/hosts/pro-data-tech-qa.md` to note the completed
      live verification (or, if the round trip surfaces a *new* defect
      unrelated to the rate limiter, file a fresh task for that defect
      rather than reopening T-0126).

## Result

<empty until closed>

## Notes

- Not urgent/blocking — the underlying fix (property_mappings attached)
  is already independently verified via two other methods (on-host ORM,
  external OIDC discovery document). This task closes the gap between
  "verified via equivalent means" and "verified via the exact literal
  acceptance-criterion path," which is good practice but not evidence of
  an actual defect.
- Consider whether a lighter-weight, throttle-exempt verification path
  (e.g. a pre-provisioned test account, or a direct token-endpoint probe
  using client credentials, bypassing the public registration endpoint
  entirely) should be added to this workflow's toolkit for future
  Authentik-provider tasks — the public registration endpoint's
  throttling makes this style of live verification unreliable to
  complete within a single session's time budget. Flagged by both the
  executor and the execution-validator of T-0126's run as an open
  question; not itself in scope for this task unless the user wants it
  folded in.

## History
- 2026-07-27: created from 2026-07-27-fix-authentik-scope-mappings-qa-001 (observation, filed by landscape-updater per T-0126's closure — literal browser-level verification and existing-user non-regression check both explicitly deferred, not silently skipped)
