---
name: workflow-repo-spinoff
version: 1
description: Spin off a new infrastructure-management repo from ai-dala-infra. Creates the new repo with a full copy of the agent/workflow framework, migrates designated landscape files, task files, and run history, then cleans up ai-dala-infra.
extends: workflows/_common-operations.md
state_changing: true
---

# Repo spin-off workflow

Specialization of `workflows/_common-operations.md` for splitting a new infrastructure-management project out of `ai-dala-infra`.

## When this workflow applies

- Spinning off a new infra repo (e.g. `ai-qadam-infra`) from the current one.
- All operations are **local PowerShell** on the management workstation plus `git` operations — **no SSH to managed hosts** required for the repo-split itself.
- The executor may also push new remote repos to Gitea or GitHub if the plan includes it.

## Step bindings

| Step | Agent |
|---|---|
| 01 | `task-reader` |
| 02 | `landscape-reader` |
| 03 | `task-validator` |
| 04 | `solution-designer` |
| 05 | (orchestrator-written approval) |
| 06 | **`executor-infra`** — runs local PowerShell; no SSH gate required for this workflow |
| 07 | `execution-validator` |
| 08 | `landscape-updater` |

## Landscape files in scope

Steps 02, 03, 04, 06, 07, 08 read:

- `landscape/hosts/<host>.md` — for every host being migrated
- `landscape/services.md` — for service entries being moved
- `landscape/cloudflare.md` — if DNS records are being re-assigned
- `landscape/domains.md` — if domains change ownership
- `shared/app-registry.md` — if apps move repos
- `tasks/_index.md` — to enumerate tasks being migrated

## Mandatory acceptance criteria for the new repo

The plan produced at step 04 MUST include ALL of the following for the new repo to be considered properly initialized:

1. **Framework files** (copied from source repo, then adapted):
   - `.claude/agents/*.md` — all agent definitions
   - `workflows/_common-operations.md` and all referenced workflow files
   - `shared/handoff-format.md`, `shared/verdicts.md`, `shared/approval-protocol.md`, `shared/subagent-invocation.md`
   - `tasks/README.md`, `tasks/_template.md`
   - `runs/README.md`
   - `CLAUDE.md` (adapted for the new project name/scope)
   - `.github/copilot-instructions.md` (adapted for the new project name/scope)

2. **Landscape files** migrated:
   - `landscape/README.md` (adapted)
   - All `landscape/hosts/<host>.md` files designated for the new repo
   - Relevant sections of `landscape/services.md` extracted into the new repo's `landscape/services.md`

3. **Task files** migrated:
   - All task files whose `affects:` only reference hosts/landscape files being migrated
   - `tasks/_index.md` (new, containing only migrated tasks)

4. **Run history** migrated:
   - All `runs/` directories whose subject host / service matches the migrated scope

5. **Git hygiene:**
   - New repo initialized as git, initial commit with all bootstrapped files
   - `.gitignore` created (at minimum covering `.tmp/`, `*.bak`)
   - Remote set if a Gitea/GitHub remote has been designated

6. **Cleanup in source repo:**
   - Migrated landscape host files removed from `landscape/hosts/`
   - Migrated task files removed from `tasks/` (or marked `status: superseded` with a link to the new repo)
   - `tasks/_index.md` updated (migrated tasks removed)
   - Migrated `runs/` directories removed (or preserved for audit, per user preference)
   - `landscape/services.md` trimmed of migrated-host sections

## Workflow-specific rules

1. **Copy framework first, migrate data second.** The new repo's `.claude/agents/`, `workflows/`, and `shared/` must exist before any data migration step, so the validator can verify the framework is complete.
2. **Adapt, don't just copy.** `CLAUDE.md`, `.github/copilot-instructions.md`, `landscape/README.md`, and `shared/app-registry.md` must be re-written/adapted for the new project scope — not literal copies.
3. **No host changes.** This workflow does NOT SSH to any host, does NOT change any firewall, DNS record, or running container. Any such work must be done in a separate infrastructure workflow run.
4. **Idempotency.** If the run is re-executed, it must not corrupt either repo. Use `Test-Path` guards before any `New-Item` / copy operations.
5. **Both repos must be in a clean git state at the end.** The executor must run `git status` and `git diff --stat` in both repos and confirm clean working trees before writing the step-06 handoff with `verdict: PASS`.
