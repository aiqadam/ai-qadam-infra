---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-08-21T03:20:00Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-04-solution-designer.md
artifacts_changed: []
approved_by: user
---

## Summary
User approved the two-phase design.

## Details
Presented the plan: Phase 1 (companion PR against aiqadam/ai-qadam-platform
adding a third nginx server-block for cms.qa.aiqadam.org, merged before
touching the live host) and Phase 2 (Cloudflare DNS record, cert SAN
expansion, nginx reload, PUBLIC_DIRECTUS_URL + web-next recreate), with
before/after checks for qa.aiqadam.org and auth.qa.aiqadam.org since they
share the same nginx file. User responded: "APPROVE (Recommended)".

## Issues / risks
Carried forward from step-04: Phase 2 cannot start until Phase 1's PR is
confirmed MERGED (explicit precondition check, not assumed); Directus's
live port must be re-confirmed in Step 0.1 rather than trusted from the
task file's 3119 assertion; cert --expand must list all existing SANs
plus the new one or it will drop the existing ones.
