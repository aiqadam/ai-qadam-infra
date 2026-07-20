---
run_id: 2026-07-17-cicd-workflow-aiqadam-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-17T09:10:00Z
task_id: T-0113-github-actions-cicd-workflow-aiqadam-platform
inputs_read:
  - runs/2026-07-17-cicd-workflow-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-17-cicd-workflow-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-17-cicd-workflow-aiqadam-001/step-06-executor-cicd.md
  - tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/app-registry.md
  - shared/deploy-protocol.md
  - workflows/cicd.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Proceed to step 08 (landscape-updater). It must update landscape/hosts/pro-data-tech-qa.md and landscape/hosts/pro-data-tech-prod.md with the real deploy.sh description (per step-04 Part C item 13) — those files were confirmed NOT touched by step 06 and are pending. One non-blocking finding to relay: the two ci-cd.yml Actions runs triggered so far (push to add-ci-cd-workflow, and the PR itself) both failed at the `Lint` step in the `build` job — an app-repo code-quality issue unrelated to this plan's infra scope, but worth flagging to the user before they merge PR #15, since deploy-qa needs `build` to pass to fire for real.
---

## Summary
End state independently verified — matches the executor's step-06 report on every checked dimension; verdict PASS.

## Details

### On-host checks
| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| QA containers Up | `ssh tvolodi@95.46.211.230 "docker compose -p aiqadam-qa -f .../docker-compose.qa.yml ps"` | `aiqadam-qa-api-1` Up (healthy, created 2026-07-17T08:17:50Z — matches rehearsal window); `aiqadam-qa-oidc-stub-1` Up (healthy, created 2026-07-13, untouched) | yes |
| QA `.last-deployed-commit` valid 40-char SHA | `cat /opt/apps/aiqadam-qa/deploy/.last-deployed-commit` | `dfd2a7c479c18e9acea5b3e0f53e19aca3f777bb` (40 hex chars) | yes |
| QA `.last-deployed-commit.previous` | `cat /opt/apps/aiqadam-qa/deploy/.last-deployed-commit.previous` | Same SHA (self-deploy, previous==new as expected) | yes |
| QA deploy.sh mode 750 | `stat -c '%U:%G %a' deploy.sh` | `deploy:deploy 750` | yes |
| QA deploy.sh executable as `deploy` | `sudo -u deploy test -x deploy.sh` | `EXECUTABLE` | yes |
| QA deploy.sh syntax valid | `sudo bash -n deploy.sh` | `SYNTAX_OK` | yes |
| QA deploy.sh no `git clean` invocation | `sudo grep -n 'git clean' deploy.sh` | 3 matches, lines 13/16/17, all inside the prohibition comment block; no executable invocation | yes |
| Prod deploy.sh mode 750 | `stat -c '%U:%G %a' deploy.sh` | `deploy:deploy 750` | yes |
| Prod deploy.sh executable as `deploy` | `sudo -u deploy test -x deploy.sh` | `EXECUTABLE` | yes |
| Prod deploy.sh syntax valid (`bash -n`) | `sudo bash -n deploy.sh` | `SYNTAX_OK`, exit 0 | yes |
| Prod deploy.sh no `git clean` invocation | `sudo grep -n 'git clean' deploy.sh` | 3 matches, lines 13/16/17, comment-only | yes |
| Prod `.last-deployed-commit` absent (never invoked) | `test -f .../.last-deployed-commit` | `ABSENT` | yes |
| Prod containers unrestarted (pre-existing Created timestamps) | `docker inspect --format '{{.Created}}'` on all 3 prod containers | `2026-07-13T16:2{7:11,7:51,8:16}...Z` for postgres/oidc-stub/api — all 3 days old, no recreate | yes |
| `deploy` user group membership fix (both hosts) | `id deploy` | QA: `groups=981(deploy),1001(tvolodi),986(docker),982(deploybots),980(aiqadam-qa-secrets)`; Prod: `groups=981(deploy),1001(tvolodi),986(docker),982(deploybots),980(aiqadam-prod-secrets)` — `tvolodi` group present on both | yes |
| QA `safe.directory` git config for `deploy` user | `sudo -u deploy git config --global --get-all safe.directory` | `/opt/apps/aiqadam-qa` | yes |

### External checks
| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| QA health endpoint | `curl -s -o /dev/null -w '%{http_code}' https://qa-uz.aiqadam.org/health` | `200` | `200`, body `{"status":"ok",...,"tenant":{"code":"uz",...}}` | yes |
| Prod health endpoint | `curl -s -o /dev/null -w '%{http_code}' https://aiqadam.org/health` | `200` | `200` | yes |
| Penpot external | `curl -s -o /dev/null -w '%{http_code}' https://penpot.aiqadam.org` | `200` | `200` | yes |
| Penpot containers | `docker ps --filter name=penpot- --format '{{.Names}}: {{.Status}}'` on prod | 7 containers Up | 7/7 Up (5 days, unchanged) — `frontend`, `backend`, `exporter`, `postgres` (healthy), `mailcatch`, `mcp`, `valkey` (healthy) | yes |
| PR #15 exists, OPEN, targets main | `gh pr view 15 --repo aiqadam/ai-qadam-platform --json ...` | OPEN, base=main, mergeable | `state: OPEN`, `baseRefName: main`, `headRefName: add-ci-cd-workflow`, `mergeable: MERGEABLE`, `headRefOid: ee5688a84c4ef0b6fad182c2c33acf12e4ee8730` | yes |
| PR #15 file diff — exactly one file, ci-cd.yml only | `gh pr view 15 --json files` | 1 file, `.github/workflows/ci-cd.yml` | 1 file, `.github/workflows/ci-cd.yml`, +126/-0 | yes |
| ci-cd.yml content matches approved plan | `gh api repos/.../contents/.github/workflows/ci-cd.yml?ref=add-ci-cd-workflow` decoded and read in full | byte-for-byte match to step-04's Step 4 content | Confirmed identical: 3 jobs (`build`, `deploy-qa`, `deploy-prod`), `StrictHostKeyChecking=yes`, regex-validated `git_ref`, `environment: production` gate, health-check retry loops, key cleanup steps | yes |
| `production` GitHub Environment reviewer | `gh api repos/.../environments/production --jq '.protection_rules[]...'` | `required_reviewers` with `tvolodi` | `required_reviewers` rule present, reviewer `tvolodi` (id `25960910`), `deployment_branch_policy: null` | yes |
| `main` branch HEAD unchanged (PR not merged) | `gh api repos/.../commits/main --jq .sha` | `dfd2a7c479c18e9acea5b3e0f53e19aca3f777bb` | `dfd2a7c479c18e9acea5b3e0f53e19aca3f777bb` — matches, confirms not merged | yes |
| `protect-branch` ruleset (id 18687633) untouched | `gh api repos/.../rulesets/18687633 --jq '{enforcement, bypass_actors}'` | `enforcement: active`, `bypass_actors: []` (unchanged from step-05's finding) | `enforcement: active`, `bypass_actors: []` | yes |
| `deploy.yml`/`ci.yml` untouched | Confirmed via PR diff (only ci-cd.yml in file list) and workflow directory listing | no changes | PR touches only ci-cd.yml; `deploy.yml`/`ci.yml` present unmodified in listing | yes |

### Resources-changed reconciliation
| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| Branch `add-ci-cd-workflow` pushed, head `ee5688a8...` | Confirmed via `gh pr view` and local `git log` on the branch | yes |
| PR #15 opened against `main`, OPEN, not merged | Confirmed OPEN, `mergeable: MERGEABLE`, main HEAD unchanged | yes |
| `production` Environment created, reviewer `tvolodi` (id 25960910) | Confirmed via `gh api` | yes |
| Local `aiqadam` clone: `main` reset to match `origin/main` | Confirmed: local main = `dfd2a7c...`, clean | yes |
| `/opt/apps/aiqadam-qa/deploy/deploy.sh` replaced, mode 750, owner deploy:deploy | Confirmed | yes |
| `/opt/apps/aiqadam-qa/deploy/deploy.sh.pre-T0113.20260717T081516Z.bak` created | Not independently re-verified (backup file existence not in designer's step-07 verification block; low-risk, executor's `ls -la` output already shown in step-06) | inconclusive (not in designer's checklist, no discrepancy suspected) |
| `.last-deployed-commit` / `.previous` on QA, both = `dfd2a7c...` | Confirmed both files, both correct SHA | yes |
| `deploy` user's `~/.gitconfig` gained `safe.directory = /opt/apps/aiqadam-qa` | Confirmed | yes |
| `deploy` user added to `tvolodi` group (both hosts) | Confirmed via `id deploy` on both hosts | yes |
| `aiqadam-qa-api-1` recreated once (rehearsal) | Confirmed via `docker inspect .Created` = `2026-07-17T08:17:50Z`, `oidc-stub` untouched since 2026-07-13 | yes |
| `/opt/apps/aiqadam-prod/deploy/deploy.sh` replaced, not invoked | Confirmed: file mode/owner correct, syntax-checked OK, `.last-deployed-commit` absent, all 3 prod containers show unchanged 2026-07-13 Created timestamps | yes |
| No prod container restarted | Confirmed via `docker inspect .Created` on all 3 prod containers — all pre-date this run | yes |
| `shared/app-registry.md` — CI/CD subsection added, `last_updated` bumped | Confirmed via `git diff`; content matches description exactly (workflow file, jobs, ref-passing, rollback marker, reviewer, secrets, QA rehearsal, prod not-invoked status, permission-fix note) | yes |
| `shared/deploy-protocol.md` — signal-file-exception addendum | Confirmed via `git diff`; matches described rationale | yes |
| `landscape/hosts/pro-data-tech-qa.md`, `pro-data-tech-prod.md` NOT touched by this step | Confirmed via `git diff` — both files' working-tree diffs are entirely attributable to T-0112 content (referencing run `2026-07-14-ssh-deploy-keys-aiqadam-001`); no mention of PR #15, `production` Environment, deploy.sh replacement, or the group-grant fix from T-0113 anywhere in either diff | yes |

## Issues / risks

- **Both `ci-cd.yml` Actions runs triggered so far (push to `add-ci-cd-workflow`, and the PR event) failed at the `build` job's `Lint` step**, with `Typecheck`/`Test`/`Build`/the Docker-image-build step all `skipped` as a consequence, and `deploy-qa`/`deploy-prod` both correctly `skipped` (their `if` gates require `main`-push or `workflow_dispatch`, neither of which applied to these trigger events — this is the workflow behaving exactly as designed, not a defect). The `Lint` failure itself is app-repo code-quality content, out of this infra plan's scope, and not something step 06 or this validation step should fix. Flagging because it's directly relevant to what happens when the user merges PR #15: `deploy-qa` needs `build` to pass on `main` to fire for real, and if the same lint issue exists on `main`'s post-merge tree, the first real QA deploy will not happen automatically until it's fixed. This does not affect this task's (T-0113) pass/fail — the pipeline definition itself is correct and gates properly — but the user should know before merging.
- No other discrepancies found between the executor's claims and independently observed state.

## Open questions (optional)
- Should T-0113 (or a follow-up) note the `build` job's lint failure as a blocking dependency for T-0114's "first CI-driven QA deploy," since merging PR #15 alone won't be sufficient if `main`'s current lint state fails the same way? Not this validator's call — surfacing for the user/orchestrator.
