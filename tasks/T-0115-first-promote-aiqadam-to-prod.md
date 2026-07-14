---
id: T-0115-first-promote-aiqadam-to-prod
title: First manual promotion of aiqadam from QA to pro-data-tech-prod via the new CI/CD pipeline
kind: task
status: pending
priority: P1
created: 2026-07-12
updated: 2026-07-12
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: []
affects:
  - landscape/services.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/app-registry.md
workflow: deploy-app
blocks: []
blocked_by: [T-0111, T-0114]
related: []
estimated_blast_radius: high
estimated_reversibility: full
---

# First manual promotion of aiqadam from QA to pro-data-tech-prod

## Why
Closes the loop on the user's requested pipeline: "when I like changes I can upload to prod." This is the first real use of the `deploy-prod` GitHub Actions job (manually triggered, gated by required reviewers) built in T-0113, promoting a QA-validated ref to the production host.

## What done looks like
- [ ] A specific git ref (tag or commit SHA validated in QA via T-0114) is chosen for prod
- [ ] GitHub Actions `deploy-prod` job is triggered manually (`workflow_dispatch`) and requires the configured reviewer approval before running
- [ ] Deploy completes; `curl -I https://aiqadam.org` returns 200
- [ ] Existing `https://penpot.aiqadam.org` on the same host still returns 200 (no regression)
- [ ] App health endpoint on prod returns expected response
- [ ] Rollback path confirmed available (previous image tag / git ref recorded) per the standard `deploy-app` rollback requirement — this is the FIRST prod deploy so there may be no previous version to roll back to; the executor should note this explicitly rather than fabricate a rollback target
- [ ] `shared/app-registry.md` prod section updated with deployed ref, timestamp
- [ ] `landscape/services.md` and `landscape/hosts/pro-data-tech-prod.md` updated

## Notes
- **High blast radius** — first production deploy on a host that also serves a live Penpot instance. The execution-validator (step 07) must explicitly confirm Penpot's health after this deploy, not just the new app's.
- Because this is a first deploy (no prior prod version), the usual "preserve previous image for rollback" step has nothing to preserve — rollback for a failed first deploy means stopping/removing the new containers, not reverting to an older version. Document this distinction in the plan.

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain
