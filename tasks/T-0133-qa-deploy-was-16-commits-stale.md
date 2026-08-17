---
id: T-0133-qa-deploy-was-16-commits-stale
title: QA silently ran a 16-commit-stale build for a full day with no alert
kind: observation
status: observation
priority: P2
created: 2026-07-29
updated: 2026-07-29
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: none
blocks: []
blocked_by: []
related: []
estimated_blast_radius: low
estimated_reversibility: full
---

# QA silently ran a 16-commit-stale build for a full day with no alert

## Why

Discovered 2026-07-29 while diagnosing a live HTTP 500 on
`https://qa.aiqadam.org/workspace/admin/users`, reported by
vladimir.titenko. Root cause: `aiqadam/ai-qadam-platform` merged a fix
for exactly this crash (`ISS-WEB-NEXT-SSR-JSDOM-001`, PR #117, commit
`eed2305`, merged 2026-07-29) and that workflow's own close-out notes
explicitly flagged: *"QA deployment confirmation — the fix hasn't
redeployed to QA yet... should be re-checked after the next QA deploy
completes."* No deploy followed. `pro-data-tech-qa` was found still
running `d53b1973` (2026-07-28), 16 commits behind `main` at diagnosis
time (`b5250071`) — meaning QA had been serving a known-broken build for
roughly a day, discovered only because a human happened to click the
broken page, not by any automated signal.

This repo's own `docker-compose.qa.yml`'s `web-next`/`api` health checks
only verify the process is up and responding — they cannot and do not
detect "this container is running old, known-superseded code." The gap
is a missing **deploy-freshness** signal, distinct from the
already-covered **container-health** signal.

## What done looks like

*(This is an observation, not yet a committed plan — the user/executor
should size and choose an approach, not assume this exact list.)*

- [ ] Decide the desired mechanism: e.g. (a) `aiqadam-platform`'s CI
      auto-triggers a QA deploy on every merge to `main` (the landscape
      doc's own "Deploy strategy" note nearby already documents that a
      `deploy-qa` CI job exists for `ci-cd.yml` — worth checking why it
      didn't fire or wasn't wired for this merge), (b) a periodic drift
      check comparing `deploy/.last-deployed-commit` on the host against
      `origin/main`'s HEAD and alerting (Telegram, per this project's
      existing `TELEGRAM_ALERT_BOT_TOKEN` convention) when they diverge
      beyond some threshold, or (c) both.
- [ ] If (a): confirm/fix the existing `deploy-qa` GitHub Actions job
      actually ran for PR #117/#119 and, if it didn't, find out why (job
      disabled? scoped to a different branch? silently failed?).
- [ ] If (b): a small script or systemd timer on `pro-data-tech-qa` (or a
      GitHub Actions scheduled workflow) that periodically diffs deployed
      vs. `origin/main` HEAD and pages someone when stale beyond N hours.
- [ ] Either way, this task should close with a documented answer to "how
      would a future stale-QA situation be caught automatically, without
      a human stumbling into the broken page first."

## Result

<empty until closed>

## Notes

- Not urgent/blocking — QA is now current (`b5250071`, confirmed live
  2026-07-29) — this is a process gap, not an active incident.
- Related but distinct from T-0132 (that's about one specific config
  line's drift; this is about the whole-build staleness class of
  problem).

## History
- 2026-07-29: created as `kind: observation`, `status: observation`, `priority: P2` (manual, discovered while diagnosing the /workspace/admin/users 500 for vladimir.titenko)
