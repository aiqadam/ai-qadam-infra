---
id: T-0113-github-actions-cicd-workflow-aiqadam-platform
title: Author .github/workflows/ci-cd.yml in aiqadam/ai-qadam-platform (build on push, auto-deploy to QA, manual promote to prod)
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
  - shared/app-registry.md
  - shared/deploy-protocol.md
workflow: infrastructure
blocks: [T-0114]
blocked_by: [T-0112]
related: []
estimated_blast_radius: low
estimated_reversibility: full
---

# Author GitHub Actions CI/CD workflow in aiqadam/ai-qadam-platform

## Why
This is the piece that actually implements "push to GitHub → CI builds → auto-deploy to QA → manual promote to prod." Everything before this task (T-0110, T-0111, T-0112) prepares the hosts and credentials; this task writes the pipeline definition itself.

**This file lives in the app repo (`c:\Users\tvolo\dev\ai-dala\aiqadam`, remote `https://github.com/aiqadam/ai-qadam-platform.git`), not in this infra repo.** Per [shared/deploy-protocol.md](../../shared/deploy-protocol.md), infra agents have read/write access to project repos under `ai-dala/` and may author this file directly, but the ongoing build/test logic inside it belongs to the app team going forward.

## What done looks like
- [ ] `.github/workflows/ci-cd.yml` created in the aiqadam repo with (at minimum) these jobs:
  - `build`: on every push to any branch / PR — install deps, lint, run tests, build the app image(s). Fails the workflow on any failure (no deploy proceeds).
  - `deploy-qa`: on push to `main` (or the project's chosen trunk branch) only, after `build` passes — SSH to `pro-data-tech-qa` using the `QA_SSH_DEPLOY_KEY` secret (from T-0112) and run the deploy script (`git pull` + `docker compose up -d --build` or equivalent, per what T-0110's executor actually built)
  - `deploy-prod`: manually triggered (`workflow_dispatch`, or a GitHub Environment with required reviewers) — SSH to `pro-data-tech-prod` using `PROD_SSH_DEPLOY_KEY` (from T-0112), deploys a specific git ref/tag chosen at trigger time
- [ ] `deploy-prod` job uses a GitHub Environment (e.g. `production`) with required reviewers configured in the repo settings, so promotion needs an explicit human approval click in GitHub — this is the "when I like changes I can upload to prod" gate the user asked for
- [ ] Workflow uses the `known_hosts` secrets from T-0112 to pin SSH host keys (no `StrictHostKeyChecking=no`)
- [ ] `shared/app-registry.md` updated with a `CI/CD` section: workflow file path, trigger branches, environment names
- [ ] `shared/deploy-protocol.md`'s "signal file" convention (`tasks/deploy-request.md` in the project repo) is either wired into this workflow (CI writes the signal file after a successful QA deploy) or explicitly noted as not used for this app if the user prefers GitHub's native deploy tracking instead

## Notes
- This task is `workflow: infrastructure` because it's a one-time setup of pipeline *configuration*, per the "one-time setup vs. repeat deploys" convention in `shared/deploy-protocol.md`. Actual subsequent deploys triggered by this pipeline are not tracked as infra tasks per-run (that would not scale) — this repo's landscape is updated at meaningful checkpoints (first deploy, version bumps worth recording) via T-0114/T-0115 and any future promote tasks, not on every push.
- Confirm the exact trunk branch name (`main` vs `master`) and whether PRs also deploy to any ephemeral/preview environment (out of scope unless the user asks) before finalizing the workflow file.
- The executor for this task should also verify `https://github.com/aiqadam/ai-qadam-platform.git` is in fact the `origin` remote of `c:\Users\tvolo\dev\ai-dala\aiqadam` — flagged as unverified in T-0110 as well.

## Open questions
- **Test suite maturity:** does the aiqadam repo currently have a runnable test suite / lint config wired for CI? If not, the `build` job should still run whatever exists (even just a build/typecheck step) rather than block on tests that don't exist yet — confirm scope with the user during solution design.
- **Image registry:** does the workflow build-and-push to a registry (e.g. GHCR) and have the host `docker pull`, or does the host build locally from a `git pull` (matching the existing `deploy-app.md` "local builds on host" convention used for `hetzner-prod`)? Recommend matching the existing convention (build on host) for consistency unless the user wants a registry-based flow.

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain
