---
id: T-0124-fix-deploy-qa-permission-denied
title: Fix deploy-qa permission-denied unlink error on pro-data-tech-qa
kind: task
status: in-progress
priority: P0
created: 2026-07-24
updated: 2026-07-24
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: [2026-07-24-fix-deploy-qa-permission-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
workflow: cicd
blocks: []
blocked_by: []
related: []
estimated_blast_radius: low
estimated_reversibility: full
---

# Fix deploy-qa permission-denied unlink error on pro-data-tech-qa

## Why

`aiqadam/ai-qadam-platform`'s `.github/workflows/ci-cd.yml` `deploy-qa` job has
failed on every push to `main` since the run immediately following PR #44
(`af30beb`, the last successful deploy). Every attempt since fails inside
`deploy.sh` (per that repo's `docs/04-development/infrastructure/runbooks/pro-data-tech-cicd.md`)
with:

```
error: unable to unlink old 'package.json': Permission denied
error: unable to unlink old 'pnpm-lock.yaml': Permission denied
```

This is almost certainly the documented failure class in that runbook's
"Common failure modes" section — file ownership drift between the `deploy`
system user and whatever user (`tvolodi`, per the runbook's precedent for
the analogous `dubious ownership` issue) owns the checkout at
`/opt/apps/aiqadam-qa/` on `pro-data-tech-qa` (95.46.211.230). The runbook
notes `deploy` was granted group membership in `tvolodi`'s group at
hand-off, but a `git checkout --detach` overwriting tracked files still
needs write permission on the files themselves, not just the containing
directory — if any files in that checkout have been touched/recreated
with different ownership since hand-off (e.g. by a manual `pnpm install`
run as `tvolodi`, or a partial/interrupted deploy), the group-write bit
may not be enough, or may have been dropped.

**Impact:** this blocks live verification of
[ISS-USR-REG-002](../../aiqadam/.copilot/issues/ISS-USR-REG-002.md) (a
merged, tested bug fix in `aiqadam/ai-qadam-platform` PR #51) and blocks
every subsequent commit to `main` from ever reaching the QA environment.
QA is currently pinned to the code as of PR #44, several days/commits
stale.

## What done looks like

- [ ] Root cause of the permission-denied error confirmed (exact file
      ownership/mode mismatch identified via SSH as an operator, e.g.
      `ls -la /opt/apps/aiqadam-qa/package.json /opt/apps/aiqadam-qa/pnpm-lock.yaml`
      and `id deploy`).
- [ ] Ownership/permissions fixed on `pro-data-tech-qa` so `deploy` can
      overwrite `package.json`/`pnpm-lock.yaml` (and any other tracked
      file with the same issue) during `git checkout --detach`.
- [ ] A fresh `deploy-qa` GitHub Actions run (triggered by re-running the
      workflow or pushing a no-op commit to `aiqadam/ai-qadam-platform`
      `main`) completes successfully end-to-end, including both health
      checks (`https://qa.aiqadam.org/health` and `https://qa.aiqadam.org/`
      both return 200).
- [ ] `deploy/.last-deployed-commit` on the host reflects current `main`
      tip (confirms the deployed commit actually advanced past PR #44).
- [ ] Live confirmation, reported back to the `aiqadam` repo: `POST
      https://qa.aiqadam.org/api/v1/auth/register` with a well-formed
      body returns `302` (or a clean `400 registration_failed`, if the
      underlying Authentik-credential issue from ISS-USR-REG-002 turns
      out to be a second, separate remaining blocker) — NOT a bare `500`.

## Result

<empty until closed>

## Notes

- Do not run `git clean` on the host checkout under any circumstances —
  `deploy/` (deploy.sh, compose files, `.env`) is untracked and would be
  destroyed. This is an explicit hard rule already documented in
  `deploy.sh`'s own header comment on the host.
- This task's acceptance criteria intentionally include the live
  registration-endpoint check (last bullet) so this task closes with
  concrete, executed proof that the downstream `aiqadam` bug fix actually
  reached QA — not just that the CI job went green.
- Source repo / issue this task was opened on behalf of:
  `aiqadam/ai-qadam-platform` issue
  [#50](https://github.com/aiqadam/ai-qadam-platform/issues/50),
  local tracking `ISS-USR-REG-002`
  (`.copilot/issues/ISS-USR-REG-002.md`), queued follow-up
  `wf-20260723-fix-128-deploy-qa-permission-fix`
  (`.copilot/tasks/queued/wf-20260723-fix-128-deploy-qa-permission-fix/handoff.yaml`).

## History
- 2026-07-24: created as `kind: task`, `status: pending`, `priority: P0` (manual, on behalf of a blocked fix in aiqadam/ai-qadam-platform)
- 2026-07-24: status → `in-progress`, run `2026-07-24-fix-deploy-qa-permission-001`
