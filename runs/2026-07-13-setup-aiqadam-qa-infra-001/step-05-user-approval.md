---
run_id: 2026-07-13-setup-aiqadam-qa-infra-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-07-13T07:15:00Z
task_id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
retry_of: step-05
inputs_read:
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md
artifacts_changed: []
approved_by: user
---

## Summary
User approved the hostname-rename plan (retry_of: step-04, second revision) as-is, including deleting the orphaned `qa.aiqadam.org` DNS record and TLS certificate.

## Details
Phase 10 of the previous execution attempt failed because `apps/api` performs hostname-based tenant routing and rejects any Host header whose leftmost label is an unregistered 2-character code — `qa` is not registered (only `uz`/`kz`/`tj` are). The user was asked how to resolve this and chose the pragmatic rename option: `qa-uz.aiqadam.org`.

The solution-designer then investigated the app's actual tenant-resolution source (`apps/api/src/modules/tenants/tenant.middleware.ts`) and found a subtlety: `qa-uz`'s leftmost label is 5 characters, which fails the app's `length !== 2` check entirely and falls through to `DEFAULT_TENANT_CODE = 'uz'` — the hostname works, but via the default-tenant fallback, not genuine subdomain-to-tenant matching. This nuance was surfaced explicitly to the user before this approval, who confirmed proceeding with `qa-uz.aiqadam.org` via the fallback is acceptable for this QA smoke-test scope.

User was then asked to approve the final plan (new Cloudflare A record + nginx vhost + Let's Encrypt cert for `qa-uz.aiqadam.org`; delete the orphaned `qa.aiqadam.org` record and cert with backups first; update `.env`'s `WEB_BASE_URL`/`OIDC_REDIRECT_URI`; recreate the `api` container) as written in `runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md`. **Approved as-is, including the cleanup deletions of the old record and cert.** No modifications requested.

Executor-infra should execute Phases A through F exactly as written, reusing the already-healthy `oidc-stub`/`api` containers, checkout, and database untouched.

## Issues / risks
None — user approved the designer's full recommended plan, including the default-tenant-fallback tradeoff and the old-record/cert cleanup, both explicitly disclosed before this approval.
