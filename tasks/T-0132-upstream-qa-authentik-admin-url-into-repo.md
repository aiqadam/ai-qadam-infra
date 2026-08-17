---
id: T-0132-upstream-qa-authentik-admin-url-into-repo
title: Commit AUTHENTIK_ADMIN_URL into aiqadam-platform's tracked deploy/docker-compose.qa.yml
kind: task
status: pending
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
workflow: cicd
blocks: []
blocked_by: []
related: [T-0125-fix-authentik-admin-url-on-qa]
estimated_blast_radius: low
estimated_reversibility: full
---

# Commit AUTHENTIK_ADMIN_URL into aiqadam-platform's tracked deploy/docker-compose.qa.yml

## Why

T-0125 fixed a live 523 by adding `AUTHENTIK_ADMIN_URL:
"https://auth.qa.aiqadam.org"` to the `api` service's environment block
in `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` — but that edit
was made directly on the host and never committed into
`aiqadam/ai-qadam-platform`'s tracked copy of the same file
(`deploy/docker-compose.qa.yml` at the repo root).

This is a landmine for every future deploy: `deploy.sh` does a hard
`git checkout --detach <ref>` before starting containers (see
`landscape/hosts/pro-data-tech-qa.md` "CI/CD deploy user" subsection),
which refuses to run at all if the host has uncommitted local changes to
a tracked file — confirmed live 2026-07-29 when this exact line blocked
a routine redeploy to current `main` (see T-0125's Result section and
`landscape/hosts/pro-data-tech-qa.md`'s Change log). That redeploy only
succeeded because an operator noticed the block, stashed the line,
deployed, and popped the stash back — a manual step nothing forces a
future deploy (especially an automated CI/CD run with no human watching)
to perform correctly. An automated deploy hitting this same conflict
would either hard-fail (if `deploy.sh`'s git checkout errors are
correctly treated as fatal) or, worse, silently discard the env var if
some future version of the script adds a `git checkout -f` / `git
reset --hard` to "fix" checkout failures.

## What done looks like

- [ ] `deploy/docker-compose.qa.yml` in `aiqadam/ai-qadam-platform` (repo
      root, tracked by git) gains the `AUTHENTIK_ADMIN_URL:
      "https://auth.qa.aiqadam.org"` line in the `api` service's
      environment block, in the same position/comment style as the
      existing overrides (see T-0125's original diff for the exact text
      and placement).
- [ ] Merged via a normal PR through `aiqadam-platform`'s own workflow
      (not a direct push — see that repo's `AGENTS.md`/branch-protection
      rules), so it lands on `main` and every future `deploy:<sha>` from
      `main` already carries it — no host-local drift, no stash/pop
      needed ever again.
- [ ] After merge, confirm a plain redeploy (`ssh deploy@... "deploy:<new
      main sha>"`) succeeds with zero git-conflict errors and the `api`
      container still has the correct `AUTHENTIK_ADMIN_URL` — proving the
      host-local workaround is no longer needed and can be forgotten.
- [ ] `landscape/hosts/pro-data-tech-qa.md`'s "AiQadam application stack"
      subsection note about this line being host-local-only is updated to
      say it's now tracked in the repo (or removed if it's covered
      implicitly by the deploy mechanism description).

## Result

<empty until closed>

## Notes

- Low blast radius, fully reversible (it's one env var line; worst case
  a bad merge just needs a revert PR).
- This is a docs/config-only PR in a different repo
  (`aiqadam/ai-qadam-platform`) from this task's home
  (`ai-qadam-infra`) — the executor for this task needs write access to
  that repo, not just to the QA host. Coordinate with that repo's own
  `.copilot/` agentic workflow (`docs/04-development/github-access.md`)
  rather than pushing directly.

## History
- 2026-07-29: created as `kind: task`, `status: pending`, `priority: P2` (manual, discovered while closing T-0125 during an unrelated QA-redeploy session)
