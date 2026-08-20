---
run_id: 2026-08-20-rotate-qa-directus-token-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-08-20T15:10:00Z
task_id: T-0137-rotate-qa-directus-admin-token
inputs_read:
  - runs/2026-08-20-rotate-qa-directus-token-001/step-04-solution-designer.md
artifacts_changed: []
approved_by: user
---

## Summary
User approved the revised (attempt 2) design.

## Details
Presented the material change from attempt 1: `DIRECTUS_TOKEN` and
`DIRECTUS_ADMIN_TOKEN` are independent values, not one secret under two
names; `DIRECTUS_ADMIN_TOKEN` is the canonical, compose-wired live
credential also consumed by the `api` container; the plan now rotates
all three exposed values and mandatorily recreates `aiqadam-qa-api-1`.
User responded: "APPROVE (Recommended)", noting the extra rigor (tracing
the real compose-interpolation root cause rather than guessing) was
worth the added step.

## Issues / risks
Carried forward from step-04: Phase 0.6's REST-live-no-restart
assumption remains the plan's largest unverified premise, with an
explicit BLOCKED branch if contradicted. Phase 2.2's UI-fallback branch
remains a possible mid-run return-to-user point.
