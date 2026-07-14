---
id: T-0114-first-deploy-aiqadam-to-qa
title: First end-to-end deploy of aiqadam to pro-data-tech-qa via the new CI/CD pipeline
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
  - landscape/hosts/pro-data-tech-qa.md
  - shared/app-registry.md
workflow: deploy-app
blocks: [T-0115]
blocked_by: [T-0113]
related: []
estimated_blast_radius: low
estimated_reversibility: full
---

# First end-to-end deploy of aiqadam to pro-data-tech-qa via the new CI/CD pipeline

## Why
Validates the full pipeline built by T-0110–T-0113 actually works end-to-end: a real push to `main` triggers GitHub Actions, which builds and deploys to `pro-data-tech-qa` without manual SSH intervention. This is the acceptance test for the user's original request.

## What done looks like
- [ ] A real (or trivial/no-op) commit is pushed to `main` on `https://github.com/aiqadam/ai-qadam-platform.git`
- [ ] GitHub Actions `build` job passes
- [ ] GitHub Actions `deploy-qa` job runs automatically and completes
- [ ] `curl -I https://qa.aiqadam.org` returns 200 post-deploy
- [ ] App health endpoint (per `shared/app-registry.md`) returns expected response
- [ ] `shared/app-registry.md` QA section updated with the deployed git ref, image tag/build, timestamp
- [ ] `landscape/services.md` updated per the standard deploy-app "version recorded in landscape" rule

## Notes
- Per [workflows/deploy-app.md](../../workflows/deploy-app.md) this task follows the `deploy-app` workflow, not `infrastructure` — the setup is already done by the time this runs.
- If the GitHub Actions run fails, this task's step 07 (execution-validator) captures the GitHub Actions log output and the failure is triaged per `shared/deploy-protocol.md` §4b/4c (app-level vs infra-level failure).

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain
