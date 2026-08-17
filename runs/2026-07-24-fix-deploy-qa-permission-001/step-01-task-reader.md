---
run_id: 2026-07-24-fix-deploy-qa-permission-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-24T00:00:00Z
task_id: T-0124-fix-deploy-qa-permission-denied
inputs_read:
  - tasks/T-0124-fix-deploy-qa-permission-denied.md
artifacts_changed: []
next_step_hint: proceed to step 02 landscape-reader; scope includes landscape/hosts/pro-data-tech-qa.md and landscape/services.md
---

## Summary
Execute task T-0124: diagnose and fix the file-ownership/permission-denied error blocking the `deploy-qa` GitHub Actions job on `pro-data-tech-qa`, then prove a fresh deploy reaches QA and the registration endpoint responds correctly.

## Details
- **Workflow:** cicd
- **Target scope:**
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
- **Constraints stated by user:**
  - Do not run `git clean` on the host checkout under any circumstances — `deploy/` (deploy.sh, compose files, `.env`) is untracked and would be destroyed; this is an explicit hard rule already documented in `deploy.sh`'s own header comment on the host.
  - Fix must be scoped to ownership/permissions on `pro-data-tech-qa` — no code changes implied by this task.
  - Root cause must be confirmed via SSH as an operator (not assumed) before applying a fix.
- **Information gaps for downstream steps:**
  - Exact current ownership/mode of `/opt/apps/aiqadam-qa/package.json` and `/opt/apps/aiqadam-qa/pnpm-lock.yaml` is not yet known — task's "Why" section states a hypothesis (group-write bit insufficient or dropped since hand-off) but this is unconfirmed.
  - Output of `id deploy` on the host is not yet available — needed to confirm which group(s) the `deploy` user actually holds today.
  - Whether the ISS-USR-REG-002 Authentik-credential issue is fully resolved by PR #51 alone, or whether a second remaining blocker exists, is unconfirmed — the acceptance criteria explicitly allow for a `400 registration_failed` outcome as a partial-success signal distinct from a `500`.
  - Current `deploy/.last-deployed-commit` value on the host (to confirm how stale QA currently is relative to `main`) is not yet read.

## Why (quoted verbatim from task file)
> `aiqadam/ai-qadam-platform`'s `.github/workflows/ci-cd.yml` `deploy-qa` job has
> failed on every push to `main` since the run immediately following PR #44
> (`af30beb`, the last successful deploy). Every attempt since fails inside
> `deploy.sh` (per that repo's `docs/04-development/infrastructure/runbooks/pro-data-tech-cicd.md`)
> with:
>
> ```
> error: unable to unlink old 'package.json': Permission denied
> error: unable to unlink old 'pnpm-lock.yaml': Permission denied
> ```
>
> This is almost certainly the documented failure class in that runbook's
> "Common failure modes" section — file ownership drift between the `deploy`
> system user and whatever user (`tvolodi`, per the runbook's precedent for
> the analogous `dubious ownership` issue) owns the checkout at
> `/opt/apps/aiqadam-qa/` on `pro-data-tech-qa` (95.46.211.230). The runbook
> notes `deploy` was granted group membership in `tvolodi`'s group at
> hand-off, but a `git checkout --detach` overwriting tracked files still
> needs write permission on the files themselves, not just the containing
> directory — if any files in that checkout have been touched/recreated
> with different ownership since hand-off (e.g. by a manual `pnpm install`
> run as `tvolodi`, or a partial/interrupted deploy), the group-write bit
> may not be enough, or may have been dropped.
>
> **Impact:** this blocks live verification of
> [ISS-USR-REG-002](../../aiqadam/.copilot/issues/ISS-USR-REG-002.md) (a
> merged, tested bug fix in `aiqadam/ai-qadam-platform` PR #51) and blocks
> every subsequent commit to `main` from ever reaching the QA environment.
> QA is currently pinned to the code as of PR #44, several days/commits
> stale.

## Target scope (translated from "What done looks like")
- [ ] **Root cause confirmation**: exact file ownership/mode mismatch on `pro-data-tech-qa` identified via SSH as an operator — specifically `ls -la /opt/apps/aiqadam-qa/package.json /opt/apps/aiqadam-qa/pnpm-lock.yaml` and `id deploy` output captured and interpreted.
- [ ] **Permission fix applied**: ownership/permissions on `pro-data-tech-qa` corrected so the `deploy` user can overwrite `package.json`/`pnpm-lock.yaml` (and any other tracked file showing the same issue) during `git checkout --detach`.
- [ ] **Fresh deploy succeeds end-to-end**: a re-triggered or new `deploy-qa` GitHub Actions run on `aiqadam/ai-qadam-platform` completes successfully, including both health checks returning 200 (`https://qa.aiqadam.org/health` and `https://qa.aiqadam.org/`).
- [ ] **Deployed commit advanced**: `deploy/.last-deployed-commit` on the host reflects current `main` tip (proof the deploy moved past PR #44's `af30beb`).
- [ ] **Live functional proof**: `POST https://qa.aiqadam.org/api/v1/auth/register` with a well-formed body returns `302`, OR a clean `400 registration_failed` (acceptable if a separate Authentik-credential issue remains) — but explicitly NOT a bare `500`. This result must be reported back to the `aiqadam` repo.

## Constraints
- Hard rule: never run `git clean` on the host checkout (would destroy untracked `deploy/` — deploy.sh, compose files, `.env`).
- Blast radius declared `low`, reversibility `full` per task frontmatter — supports a lean approval path at step 04/05, but that determination belongs to the solution-designer, not this step.
- Task priority is `P0` — treat as urgent for scheduling/retry purposes.
- This task's `affects:` list is authoritative for step 02's landscape scope: `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md`.

## Information gaps for downstream steps
- Live SSH access/credentials to `pro-data-tech-qa` (95.46.211.230) as an operator capable of running `ls -la`, `id`, and ownership-changing commands (`chown`/`chmod`/`setfacl`) — availability not yet confirmed for this session.
- Whether `aiqadam/ai-qadam-platform`'s GitHub Actions has a manual re-run trigger accessible, or whether a no-op commit to `main` will be needed to force a fresh `deploy-qa` run.
- Confirmation that PR #51 (the ISS-USR-REG-002 fix) is already merged to `main` as stated, so the "fresh deploy" criterion actually picks it up.
- The referenced queued follow-up `wf-20260723-fix-128-deploy-qa-permission-fix` in the `aiqadam` repo's `.copilot/tasks/queued/` — its handoff.yaml may contain prior partial diagnosis worth reading at step 02/03, though it lives outside this repo's landscape scope.

## Issues / risks
- The task's own hypothesis (group-write bit dropped/insufficient) is explicitly stated as unconfirmed ("almost certainly," "may not be enough, or may have been dropped") — step 02/03 must not treat it as established fact, only as the leading hypothesis to verify via SSH.
- The fix touches a production-adjacent QA host's filesystem permissions directly (not via IaC/config-as-code visible in this repo), so the executor step must be precise about exactly which files/directories are touched to keep blast radius genuinely low as declared.
- Acceptance criteria depend on an external repo (`aiqadam/ai-qadam-platform`) for triggering the GitHub Actions run and for the live registration-endpoint check — this run cannot fully close the task using only `ai-qadam-infra` repo contents; cross-repo coordination is required by design (per the task's own "Notes" section).

## Open questions (optional)
none — verdict is PASS, task is clear and workflow is correctly identified as `cicd`.
