---
id: T-0113-github-actions-cicd-workflow-aiqadam-platform
title: Author .github/workflows/ci-cd.yml in aiqadam/ai-qadam-platform (build on push, auto-deploy to QA, manual promote to prod)
kind: task
status: in-progress
priority: P1
created: 2026-07-12
updated: 2026-07-17
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: [2026-07-17-cicd-workflow-aiqadam-001]
affects:
  - shared/app-registry.md
  - shared/deploy-protocol.md
workflow: cicd
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
- [x] `.github/workflows/ci-cd.yml` created in the aiqadam repo with (at minimum) these jobs: (authored, content-verified byte-for-byte against the approved plan; live on branch `add-ci-cd-workflow` via [PR #15](https://github.com/aiqadam/ai-qadam-platform/pull/15), **not yet merged to `main`** — see History)
  - `build`: on every push to any branch / PR — install deps, lint, run tests, build the app image(s). Fails the workflow on any failure (no deploy proceeds).
  - `deploy-qa`: on push to `main` (or the project's chosen trunk branch) only, after `build` passes — SSH to `pro-data-tech-qa` using the `QA_SSH_DEPLOY_KEY` secret (from T-0112) and run the deploy script (`git pull` + `docker compose up -d --build` or equivalent, per what T-0110's executor actually built)
  - `deploy-prod`: manually triggered (`workflow_dispatch`, or a GitHub Environment with required reviewers) — SSH to `pro-data-tech-prod` using `PROD_SSH_DEPLOY_KEY` (from T-0112), deploys a specific git ref/tag chosen at trigger time
- [x] `deploy-prod` job uses a GitHub Environment (e.g. `production`) with required reviewers configured in the repo settings, so promotion needs an explicit human approval click in GitHub — this is the "when I like changes I can upload to prod" gate the user asked for (`production` Environment created, required reviewer `tvolodi` id `25960910`, confirmed live via `gh api`)
- [x] Workflow uses the `known_hosts` secrets from T-0112 to pin SSH host keys (no `StrictHostKeyChecking=no`) (`StrictHostKeyChecking=yes` confirmed in the merged workflow content)
- [x] `shared/app-registry.md` updated with a `CI/CD` section: workflow file path, trigger branches, environment names (done by the executor in step 06, out of this landscape-updater's scope per the run's explicit carve-out)
- [x] `shared/deploy-protocol.md`'s "signal file" convention (`tasks/deploy-request.md` in the project repo) is either wired into this workflow (CI writes the signal file after a successful QA deploy) or explicitly noted as not used for this app if the user prefers GitHub's native deploy tracking instead (explicitly noted as not used — addendum added by the executor in step 06)
- [ ] `deploy-qa` has actually fired for a real, CI-triggered push to `main` (blocked on merging PR #15; only a manual SSH rehearsal of `deploy.sh` itself has been exercised so far, on QA only) — **out of this task's literal checklist scope but tracked here for visibility; the first real CI-driven deploy is T-0114's job**
- [ ] `deploy-prod`'s `deploy.sh` has been exercised end-to-end against a real ref (prod's script is installed and syntax-valid only; first real invocation is T-0115's job)

## Notes
- **Workflow corrected 2026-07-17: `infrastructure` → `cicd`.** Originally classified `infrastructure` on the theory that authoring pipeline *configuration* is a one-time setup step, per the "one-time setup vs. repeat deploys" convention in `shared/deploy-protocol.md`. On review, that table only distinguishes host-level setup (`infrastructure`) from repeat app deploys (`deploy-app`) — it doesn't cover "author the CI/CD pipeline definition itself." `workflows/cicd.md`'s own scope explicitly lists "pipeline configuration changes (when those pipelines are managed from this repo)" and binds step 06 to `executor-cicd`, which is the correct executor for this task (authoring/validating a GitHub Actions workflow, not touching host OS/network config). User confirmed `cicd` at run start. The original rationale about *subsequent* deploys not being tracked as per-run infra tasks still holds and is unaffected by this correction — that's about T-0114/T-0115, not this task.
- Confirm the exact trunk branch name (`main` vs `master`) and whether PRs also deploy to any ephemeral/preview environment (out of scope unless the user asks) before finalizing the workflow file.
- The executor for this task should also verify `https://github.com/aiqadam/ai-qadam-platform.git` is in fact the `origin` remote of `c:\Users\tvolo\dev\ai-dala\aiqadam` — flagged as unverified in T-0110 as well.

## Open questions
- **Test suite maturity:** does the aiqadam repo currently have a runnable test suite / lint config wired for CI? If not, the `build` job should still run whatever exists (even just a build/typecheck step) rather than block on tests that don't exist yet — confirm scope with the user during solution design.
- **Image registry:** does the workflow build-and-push to a registry (e.g. GHCR) and have the host `docker pull`, or does the host build locally from a `git pull` (matching the existing `deploy-app.md` "local builds on host" convention used for `hetzner-prod`)? Recommend matching the existing convention (build on host) for consistency unless the user wants a registry-based flow.

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain
- 2026-07-17: status → in-progress, run 2026-07-17-cicd-workflow-aiqadam-001
- 2026-07-17: workflow field corrected infrastructure → cicd (see Notes); step 01 (task-reader) flagged the mismatch, user confirmed cicd before proceeding to step 02
- 2026-07-17: run 2026-07-17-cicd-workflow-aiqadam-001 step 07 PASS (execution-validator), status remains in-progress (not done) — `.github/workflows/ci-cd.yml` authored and content-verified, opened as [PR #15](https://github.com/aiqadam/ai-qadam-platform/pull/15) against `main`, **still OPEN, not merged**; `production` GitHub Environment created with required reviewer `tvolodi`. Both hosts' `deploy.sh` replaced with the real `SSH_ORIGINAL_COMMAND`-driven deploy mechanism — QA rehearsed end-to-end (self-deploy of the pinned commit, health check 200, rollback markers correct), prod installed and syntax-checked but never invoked. Unplanned fix applied on both hosts: `deploy` user added to the `tvolodi` group (plus a `git safe.directory` config entry on QA) to grant git write access to the `tvolodi`-owned checkout — permanent, live change, recorded in `landscape/hosts/pro-data-tech-qa.md` and `pro-data-tech-prod.md`. Informational, not this task's blocker: the app repo's own `lint` step is currently failing on PR #15's CI run, which would block `deploy-qa` from firing for real immediately after merge until fixed — the user's call on timing. Remains `in-progress`: no real CI-triggered deploy has happened yet (PR not merged) and prod's script is unexercised — both are T-0114/T-0115's scope, not re-opened here.
