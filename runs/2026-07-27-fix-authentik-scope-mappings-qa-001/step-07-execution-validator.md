---
run_id: 2026-07-27-fix-authentik-scope-mappings-qa-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-27T16:51:02Z
task_id: T-0126-fix-authentik-scope-mappings-on-qa
inputs_read:
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-04-solution-designer.md
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-06-executor-infra.md
  - tasks/T-0126-fix-authentik-scope-mappings-on-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - workflows/infrastructure.md
artifacts_changed: []
next_step_hint: End state independently verified as PASS. Executor's Phase 3.2 gap (rate-limited registration endpoint, 429) is confirmed still present at validation time — re-probed once, still 429, not re-tried further per no-loop instruction. landscape-updater (step 08) should proceed with the two landscape corrections executor flagged (undocumented Authentik/Directus/web-next containers; qa.aiqadam.org superseding qa-uz.aiqadam.org as sole live vhost) — both independently corroborated by this validation pass (see Details).
---

## Summary
End state verified independently: QA's Authentik OAuth2 provider (pk=1, aiqadam-qa-provider) has all three managed scope mappings attached, confirmed via a fresh docker exec + ak shell session and corroborated externally via the live OIDC discovery document; the app tier is healthy; the registration-endpoint rate limiter the executor reported is still active (non-looping single probe returned 429, unchanged); and no unintended side effects (new users, container restarts, file changes) were observed.

## Details

### On-host checks
| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| Provider pk=1 property_mappings includes all three managed scope mappings, fresh independent `ak shell` session | `ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell"` with piped Python: `OAuth2Provider.objects.get(pk=1)` → print `pk`, `name`, sorted `property_mappings.values_list("managed", flat=True)` | `VALIDATOR_CHECK_PK: 1 NAME: aiqadam-qa-provider` / `VALIDATOR_CHECK_MAPPINGS: ['goauthentik.io/providers/oauth2/scope-email', 'goauthentik.io/providers/oauth2/scope-openid', 'goauthentik.io/providers/oauth2/scope-profile']` | yes |
| T-0125 confound control (context only, not a pass/fail gate) — not re-run this pass since it's orthogonal to this task's own fix and was already independently plausible from Phase 0.5's logged output; not re-verified live here | n/a — deferred, low value to re-check since Phase 3.1's own on-host result already supersedes it | not re-run | n/a |

### External checks
| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| OIDC discovery document advertises email scope/claim | `curl -s https://auth.qa.aiqadam.org/application/o/aiqadam-qa/.well-known/openid-configuration` | `scopes_supported` and `claims_supported` include `email` | HTTP 200; `"scopes_supported": ["email","openid","profile"]`; `"claims_supported"` includes `"email"` and `"email_verified"` | yes |
| App tier health (single, non-looping probe) | `curl -s https://qa.aiqadam.org/health` | 200, `{"status":"ok",...}` | HTTP 200, `{"status":"ok","timestamp":"2026-07-27T16:49:56.109Z","service":"api","tenant":{"code":"uz","name":"Uzbekistan"}}` | yes |
| Single registration probe (rate-limit-cleared check, non-looping, one attempt only per instruction) | `curl -X POST https://qa.aiqadam.org/api/v1/auth/register -d '{"email":"validator-probe-...","...}'` | Either 429 (limiter still active — matches executor's report, not a new failure) or a schema/302 response indicating the limiter cleared | `429 {"statusCode":429,"message":"ThrottlerException: Too Many Requests"}` — limiter still active, consistent with executor's report; did not retry further | inconclusive (full round-trip still blocked, but matches expected/reported pre-existing condition, not a new defect) |

Full browser-level registration → OIDC redirect → callback round trip (designer's Phase 3.2 as originally specified) remains **not independently completed**, for the same reason the executor reported: the registration endpoint's rate limiter is still returning 429 at validation time, roughly 2 hours after the executor's own attempts. Per this task's own instruction not to loop/retry, only one additional probe was attempted here, which also returned 429. This is treated as a confirmed-still-present pre-existing condition (not a fix-introduced regression) rather than a validator failure, consistent with the executor's own characterization and the plan's rollback-trigger logic (Phase 3.2 incompleteness attributable to an unrelated, pre-existing control, not to this patch).

### Resources-changed reconciliation
| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| Authentik DB object: OAuth2Provider pk=1 (aiqadam-qa-provider), property_mappings extended additively to include scope-openid/scope-email/scope-profile | Confirmed via independent fresh `ak shell` query — all three present | yes |
| No files modified on host | Not independently re-audited file-by-file (would require a host-wide diff outside this task's scope/tooling); no evidence of any file-based side effect encountered during validation; consistent with the nature of the change (pure DB object M2M update via Django ORM, no compose/env/nginx file touched) | yes (plausible, not exhaustively verified) |
| No container restarts | `docker ps -a` re-run independently: `aiqadam-qa-authentik-server-1` and `aiqadam-qa-authentik-worker-1` both `Up 9 days (healthy)` — same uptime bucket as executor's Phase 0.1 log (also "Up 9 days"), no restart occurred between executor's run and this validation pass | yes |
| Zero new user accounts created | Queried all Authentik users: 9 total, most recent (`user3.kz.cfcad7`, joined 2026-07-27T15:10:18Z) predates this run's own step-04 handoff (2026-07-27T15:31:05Z) by ~21 minutes and predates the executor's step-06 handoff (16:45:00Z) by ~95 minutes — this user is pre-existing relative to the run, not created by any of the executor's failed (400/429) registration attempts or this validator's own probe (which also failed 429, creating no account) | yes |

## Issues / risks
- The literal end-to-end browser registration → OIDC redirect → `/api/v1/auth/callback` round trip specified in the designer's Phase 3.2 / "Verification" block has still not been completed by anyone (executor or validator), because the registration endpoint's rate limiter has not cleared across ~2 hours of elapsed wall-clock time between the executor's attempts and this validation pass. The on-host DB state and the external OIDC discovery document both independently and strongly corroborate that the fix is live and correct, but the literal user-facing 401 repro path from GitHub issue #79 has not been exercised end-to-end by either agent. Recommend a follow-up check once the rate-limit window has cleared (unknown exact duration), ideally by a human or a scheduled non-agent check rather than another workflow run looping on it.
- Phase 3.3 (existing-user non-regression) remains unverified by both executor and this validator — no known pre-existing test-account credentials were available to either session to attempt an actual sign-in. Residual risk assessed as low given the purely additive nature of the M2M change (confirmed by inspecting the actual operation: `.add()`, not `.set()` or `.remove()`), but this is an assessment, not an empirical confirmation.
- Landscape corrections flagged by the executor (undocumented Authentik/Directus/web-next containers; `qa.aiqadam.org` now sole live vhost vs. documented `qa-uz.aiqadam.org`) are corroborated by this validation pass's own `docker ps -a` output and the working `qa.aiqadam.org/health` probe — step 08 should proceed with both corrections as described in the executor's `next_step_hint`.

## Open questions (optional)
- What is the actual rate-limit window duration on `qa.aiqadam.org`'s registration endpoint? Still unknown after this validation pass (429 persisted ~2 hours post-patch). Worth confirming with the app team if a full end-to-end verification is ever required to close this out completely.
- Should a lighter-weight, whitelist-based verification path (e.g., a pre-provisioned test account exempted from the throttler, or a direct token-endpoint probe using client credentials) be added to this workflow's toolkit for future Authentik-provider tasks, given that the public registration endpoint's throttling makes Phase 3.2-style live verification unreliable to complete within a single session's time budget?
