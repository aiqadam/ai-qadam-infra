---
run_id: 2026-07-17-cicd-workflow-aiqadam-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-17T07:15:36Z
task_id: T-0113-github-actions-cicd-workflow-aiqadam-platform
inputs_read:
  - tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md
artifacts_changed: []
next_step_hint: landscape-reader should load shared/app-registry.md and shared/deploy-protocol.md, plus landscape files describing pro-data-tech-qa and pro-data-tech-prod deploy setups (from T-0110/T-0111) to confirm the actual deploy mechanics (git pull + docker compose up -d --build vs. registry-based).
---

## Summary
Author `.github/workflows/ci-cd.yml` in the `aiqadam/ai-qadam-platform` repo implementing build-on-push, auto-deploy to QA on trunk push, and a manually-approved promote-to-prod job, using the SSH deploy keys and host-key secrets provisioned by T-0112.

## Details
- **Workflow:** cicd

  Note: the task file's own frontmatter field reads `workflow: infrastructure` (with a "Notes" section explaining this was a deliberate choice — treating the pipeline *configuration* as a one-time infra setup, distinct from the repeat deploys it will trigger). However, the orchestrator's run context for this run explicitly specifies `Workflow: cicd`, the run directory is named `2026-07-17-cicd-workflow-aiqadam-001`, and the task's substance (authoring a CI/CD pipeline file, deploying via SSH to QA/prod, GitHub Environment approval gates) matches `workflows/cicd.md`'s purpose ("Building, testing, deploying software to managed hosts") far more closely than `workflows/infrastructure.md`. Proceeding with **cicd** per explicit orchestrator instruction; flagging the frontmatter mismatch below for step 02/08 awareness — the landscape-updater may want to correct the task file's `workflow:` field when it closes this task, or the user may want to confirm the intended value.

- **Target scope:**
  - [shared/app-registry.md](../../shared/app-registry.md) — needs a new `CI/CD` section (workflow file path, trigger branches, environment names)
  - [shared/deploy-protocol.md](../../shared/deploy-protocol.md) — signal-file convention (`tasks/deploy-request.md` in the project repo) must either be wired in or explicitly declared unused
  - External artifact (outside this repo): `.github/workflows/ci-cd.yml` in `c:\Users\tvolo\dev\ai-dala\aiqadam` (remote `https://github.com/aiqadam/ai-qadam-platform.git`) — per [shared/deploy-protocol.md](../../shared/deploy-protocol.md), infra agents have read/write access to project repos under `ai-dala/` and may author this file directly

- **Constraints stated by user:**
  - `build` job must run on every push to any branch / PR: install deps, lint, run tests, build app image(s); must fail the workflow (blocking deploy) on any failure
  - `deploy-qa` job: triggered only on push to the trunk branch (name TBD — `main` vs `master`, must be confirmed), runs only after `build` passes; deploys via SSH to `pro-data-tech-qa` using the `QA_SSH_DEPLOY_KEY` secret; deploy mechanism should match whatever T-0110's executor actually built (`git pull` + `docker compose up -d --build` or equivalent) — not assumed
  - `deploy-prod` job: manually triggered (`workflow_dispatch` or a GitHub Environment with required reviewers); SSH to `pro-data-tech-prod` using `PROD_SSH_DEPLOY_KEY`; deploys a specific git ref/tag chosen at trigger time
  - `deploy-prod` MUST use a GitHub Environment (e.g. `production`) with required reviewers configured in repo settings — this is the explicit human-approval gate the user asked for at the GitHub level (separate from this repo's own approval-protocol gate)
  - Workflow MUST use the `known_hosts` / host-key secrets from T-0112 (`QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`) to pin SSH host keys — `StrictHostKeyChecking=no` is explicitly disallowed
  - `shared/app-registry.md` must be updated with the new CI/CD section
  - `shared/deploy-protocol.md`'s signal-file convention must be either wired in (CI writes `tasks/deploy-request.md` after a successful QA deploy) or explicitly noted as not used, per user preference
  - Blast radius / reversibility are declared `low` / `full` in the task frontmatter — informs step 04's approval-routing decision, not something this step verifies

- **Information gaps for downstream steps:**
  - Exact trunk branch name (`main` vs `master`) for `aiqadam/ai-qadam-platform` — unconfirmed, needs verification (landscape-reader or task-validator should check the repo)
  - Whether PRs should also deploy to an ephemeral/preview environment — task says out of scope unless the user asks; downstream steps should not add this unprompted
  - Whether `https://github.com/aiqadam/ai-qadam-platform.git` is actually the `origin` remote of `c:\Users\tvolo\dev\ai-dala\aiqadam` — flagged as unverified in T-0110 and again here; must be confirmed before the executor writes/pushes the workflow file
  - Test suite maturity in the aiqadam repo: does it have a runnable test/lint config wired for CI? If not, `build` should run whatever exists (build/typecheck at minimum) rather than block on nonexistent tests — needs confirmation during solution design (step 04), per the task's own "Open questions"
  - Image strategy: build-and-push to a registry (e.g. GHCR) with the host `docker pull`-ing, versus building locally on the host from a `git pull` (matching the existing `hetzner-prod` "local builds on host" convention). Task's own notes recommend matching the existing convention (build on host) for consistency unless the user wants a registry-based flow — this should be confirmed against what T-0110/T-0111 actually deployed, which the landscape-reader (step 02) is best positioned to surface
  - Exact deploy command T-0110's executor used on `pro-data-tech-qa` (and T-0111's on `pro-data-tech-prod`) — needed so the new `deploy-qa`/`deploy-prod` jobs replicate the real deploy script rather than inventing one
  - T-0112 is recorded as done with all four secrets confirmed live in `aiqadam/ai-qadam-platform` (QA_SSH_DEPLOY_KEY, PROD_SSH_DEPLOY_KEY, QA_SSH_HOST_KEY, PROD_SSH_HOST_KEY) and both hosts have a forced-command-restricted `deploy` system user — this unblocks T-0113 but the exact forced-command syntax/restrictions on that `deploy` user (which may constrain what the SSH deploy step in the workflow is allowed to run) should be pulled from landscape by step 02, since a forced command could restrict the deploy job to a specific script rather than arbitrary SSH commands

## Issues / risks
- Task frontmatter's `workflow:` field says `infrastructure`, conflicting with the orchestrator-assigned `cicd` workflow for this run. Proceeding with `cicd` per explicit run instruction (also consistent with the workflow's actual purpose per `workflows/README.md`), but this mismatch should be corrected in the task file at step 08, or raised with the user for a definitive call.
- This task's artifact of record (`.github/workflows/ci-cd.yml`) lives outside this repo, in the `aiqadam/ai-qadam-platform` app repo. Downstream steps (landscape-reader, executor) need read/write access to `c:\Users\tvolo\dev\ai-dala\aiqadam` and its git remote to complete this task — confirm that access exists before step 06 attempts to write/push.
- `deploy-prod`'s required-reviewers GitHub Environment gate is configured in GitHub repo settings, not in this repo's `shared/approval-protocol.md` mechanism — the executor will need direct GitHub repo-settings access (via `gh` CLI or the GitHub UI) to configure it, which is a different capability than the SSH/file-editing access used for most infra tasks.

## Open questions (optional)
none — task is well-specified enough to proceed to step 02. Workflow mismatch noted above is a flag, not a blocker.
