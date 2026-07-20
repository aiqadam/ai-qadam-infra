---
run_id: 2026-07-17-cicd-workflow-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-17T07:31:46Z
task_id: T-0113-github-actions-cicd-workflow-aiqadam-platform
inputs_read:
  - runs/2026-07-17-cicd-workflow-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-17-cicd-workflow-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-17-cicd-workflow-aiqadam-001/step-03-task-validator.md
  - tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - shared/deploy-protocol.md
  - shared/app-registry.md
  - workflows/cicd.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-06-executor-infra.md (live probe: nature of the prior nologin/forced-command deviation, to confirm it does not implicate SSH_ORIGINAL_COMMAND)
  - c:\Users\tvolo\dev\ai-dala\aiqadam (live probe: git remotes/branch/HEAD, .github/workflows/*, package.json scripts, apps/api/Dockerfile, confirmed docker-compose.qa.yml/docker-compose.prod.yml/deploy/ do not exist anywhere in this repo's git history)
artifacts_changed: []
next_step_hint: Verdict is NEEDS_APPROVAL — orchestrator must halt and present this plan to the user before invoking executor-cicd. Key items the user should specifically confirm when reviewing: (1) the SSH_ORIGINAL_COMMAND ref-passing design and its input-validation regex, (2) that deploy.sh's git operations are scoped to never run `git clean` (the deploy/ directory and its compose/.env files are untracked-in-git, host-only artifacts — confirmed by live repo probe — and must survive every deploy), (3) the decision to leave the deploy-protocol.md signal-file convention explicitly unused for this pipeline, (4) the GitHub Environment `production` reviewer list is not yet known and must be supplied by the user at execution time.
---

## Summary
Plan authors `.github/workflows/ci-cd.yml` (three jobs: `build`, `deploy-qa`, `deploy-prod`) in the `aiqadam/ai-qadam-platform` repo alongside the untouched `deploy.yml`/`ci.yml`, replaces both hosts' placeholder `deploy.sh` with a real script that reads the target git ref from `SSH_ORIGINAL_COMMAND` (validated by strict regex + `git ls-remote` before checkout), performs `git fetch` + hard checkout of that ref while never touching the untracked host-local `deploy/` directory, records the previous commit for rollback, runs `docker compose up -d --build`, and the workflow verifies each deploy against its health endpoint — ending state: both hosts capable of CI-driven, ref-selectable deploys with a required-reviewer gate on prod.

## Details

### Design decisions made in this step (not deferred further)

**1. Ref-passing mechanism: `SSH_ORIGINAL_COMMAND`, not scp-a-ref-file.**
Chosen over the scp-then-invoke pattern because it requires no change to the `authorized_keys` forced-command line, no second SSH/SCP round-trip (so no partial-state window where a ref file is staged but the deploy hasn't run, or vice versa), and OpenSSH guarantees `SSH_ORIGINAL_COMMAND` is set in the forced command's environment to the exact string the client requested — this is documented, stable OpenSSH `sshd_config` `ForceCommand`/`command=` behavior, independent of PAM or login-shell configuration. I checked whether this contradicts step 03's caution flag ("prior PAM/nologin surprise" during T-0112): it does not. That prior surprise (`runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-06-executor-infra.md`) was specifically that `/usr/sbin/nologin` as `deploy`'s shell refused to execute `-c <forced-command>` at all, requiring a switch to `/bin/bash`; both hosts now have `/bin/bash` confirmed live-working for the forced-command path (including a genuine command-injection negative control). That deviation was about shell invocation, not about env var passthrough — it does not implicate `SSH_ORIGINAL_COMMAND`. I still add a discovery/verification sub-step (Step 3 below) that proves `SSH_ORIGINAL_COMMAND` actually arrives at `deploy.sh` on both hosts before any job depends on it, so the design is verified rather than assumed.

**2. `deploy.sh` behavior is identical in shape for QA and prod; only who triggers it differs.**
- `deploy-qa`: workflow always sends `ssh ... deploy@qa-host "deploy:${{ github.sha }}"` — i.e., the exact commit that passed `build` on this push to `main`. Not "always latest main" (avoids a race where main moves between build and deploy) and not operator-chosen (QA remains fully automatic per the task).
- `deploy-prod`: workflow sends `ssh ... deploy@prod-host "deploy:${{ inputs.git_ref }}"` where `git_ref` is a `workflow_dispatch` input the approving human supplies (commit SHA or tag), gated by the `production` GitHub Environment's required reviewers.
- Both paths converge on the same `deploy.sh` contract: `SSH_ORIGINAL_COMMAND` must match `^deploy:[0-9a-fA-F]{7,40}$` (7-40 hex chars — covers both short and full SHAs; tags are intentionally NOT accepted in this first version to keep the regex simple and unambiguous, since the task's "specific git ref/tag" requirement is satisfied by full-SHA pinning and QA already only ever sends a SHA). If the user wants tag support later, that is a follow-up, not silently added here.

**3. `deploy.sh` never runs `git clean`.**
Live repo probe (this step) confirmed `docker-compose.qa.yml`, `docker-compose.prod.yml`, and the `deploy/` directory itself do not exist anywhere in `c:\Users\tvolo\dev\ai-dala\aiqadam`'s git history — they are host-only artifacts created directly on `/opt/apps/aiqadam-<env>/deploy/` during T-0110/T-0111, untracked by git. `git fetch` + `git reset --hard <ref>` does NOT delete untracked files (only `git clean -fd` would), so the compose files and `.env` survive a hard reset safely — but `deploy.sh` must never call `git clean` or the deploy/ directory (including secrets) would be destroyed with no rollback. This is stated as a hard constraint in the script and in Issues/risks below.

**4. deploy-protocol.md's `tasks/deploy-request.md` signal file: explicitly NOT used for this pipeline.**
Per step 02/03's flagged semantic mismatch: the signal-file convention is documented as a *pre-action request* a project agent writes before a human tells the infra orchestrator to deploy (`deploy-app` workflow, 8-step run per deploy). This new pipeline is CI-triggered and self-contained — `ci-cd.yml` deploys automatically on push to `main` (QA) or on human-approved `workflow_dispatch` (prod), with no infra-orchestrator run in the loop at deploy time. Writing `tasks/deploy-request.md` after the fact would only be a post-hoc record, not a request, which is a different semantic than the protocol defines, and nothing reads it downstream (no infra run is triggered by it for this path). Decision: **do not wire it in.** `shared/deploy-protocol.md` gets a short addendum (Step 9 below) stating this pipeline is out of scope for the signal-file convention and explaining why, so a future reader isn't left wondering why `ci-cd.yml` doesn't write it.

**5. `production` GitHub Environment reviewers: cannot be finalized in this plan — needs a value from the user.**
The task requires required reviewers configured on the `production` GitHub Environment. No reviewer list has been supplied by the user in any input read for this run. The plan creates the environment with `deployment_branch_policy` unrestricted-by-default-but-tag/SHA-triggerable (workflow_dispatch is not a branch push, so branch protection is not the applicable gate) and required reviewers, but the executor must obtain the actual reviewer GitHub usernames/team from the user before running the `gh api` call that sets them — this is flagged as an open item, not silently defaulted to the run's operator (`tvolodi`) alone.

### Plan

**Scope statement (binding on the executor):** `.github/workflows/deploy.yml` (Coolify) and `.github/workflows/ci.yml` (advisory-only) are NOT to be modified, disabled, referenced, or reconciled with in any way by this plan. `ci-cd.yml` is a new, fully independent file. Do not edit `ci.yml`'s `continue-on-error` behavior under any circumstance.

#### Part A — App repo (`c:\Users\tvolo\dev\ai-dala\aiqadam`, remote `https://github.com/aiqadam/ai-qadam-platform.git`)

1. **Verify preconditions** — command:
   ```
   cd "c:\Users\tvolo\dev\ai-dala\aiqadam" && git remote get-url origin && git branch --show-current && git status --short && gh secret list --repo aiqadam/ai-qadam-platform
   ```
   Verification: `origin` prints `https://github.com/aiqadam/ai-qadam-platform.git`; branch prints `main`; `git status --short` is empty (clean tree, so the new file is the only change); `gh secret list` shows all four of `QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`. If any secret is missing, halt — do not author a workflow that references a secret that isn't there.

2. **Check for an existing `production` GitHub Environment** — command:
   ```
   gh api repos/aiqadam/ai-qadam-platform/environments --jq '.environments[].name'
   ```
   Verification: capture output. If `production` is already listed, record its current `reviewers` config (`gh api repos/aiqadam/ai-qadam-platform/environments/production --jq '.protection_rules'`) before changing anything — do not blindly overwrite an existing reviewer list without showing the user what's there today.

3. **Verify `SSH_ORIGINAL_COMMAND` arrives at the forced command, both hosts** — command (run once per host; uses the human operator's own SSH access, NOT the CI deploy key, since this is a read-only diagnostic, not a real deploy):
   ```
   ssh -o BatchMode=yes -i "C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci" -o IdentitiesOnly=yes deploy@95.46.211.230 "diagnostic:probe-only"
   ```
   and the prod equivalent:
   ```
   ssh -o BatchMode=yes -i "C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci" -o IdentitiesOnly=yes deploy@95.46.211.224 "diagnostic:probe-only"
   ```
   This runs BEFORE `deploy.sh` is replaced (Part B), so it exercises the placeholder script only — expected output is the placeholder's marker line + `docker compose ps` table (proves the SSH path itself works exactly as it did in T-0112's live verification; does not yet prove `SSH_ORIGINAL_COMMAND` parsing, since the placeholder ignores it). This step exists to catch any drift in host/key state before Part B modifies `deploy.sh`. The actual `SSH_ORIGINAL_COMMAND` proof happens in Part B Step 8 below, against the real script.

4. **Author `.github/workflows/ci-cd.yml`** — file write (not a shell command; executor creates this file directly). Full content:

   ```yaml
   name: ci-cd

   # Independent of deploy.yml (Coolify) and ci.yml (advisory-only CI) —
   # neither of those files is modified or referenced by this workflow.
   # This workflow's own `build` job is a hard gate for ITS OWN
   # deploy-qa/deploy-prod jobs only; it does not affect ci.yml's
   # continue-on-error posture or deploy.yml's Coolify pipeline.

   on:
     push:
       branches: ['**']
     pull_request:
       branches: [main]
     workflow_dispatch:
       inputs:
         git_ref:
           description: 'Commit SHA to deploy to production (7-40 hex chars)'
           required: true
           type: string

   concurrency:
     group: ci-cd-${{ github.ref }}
     cancel-in-progress: false

   jobs:
     build:
       name: build
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: pnpm/action-setup@v4
           with:
             version: 9.15.0
         - uses: actions/setup-node@v4
           with:
             node-version: '22'
             cache: 'pnpm'
         - name: Install dependencies
           run: pnpm install --frozen-lockfile
         - name: Lint
           run: pnpm lint
         - name: Typecheck
           run: pnpm typecheck
         - name: Test
           run: pnpm test
         - name: Build
           run: pnpm build
         - name: Build api Docker image (verification only, not pushed)
           run: docker build -f apps/api/Dockerfile -t aiqadam-api:ci-${{ github.sha }} .

     deploy-qa:
       name: deploy-qa
       needs: build
       if: github.ref == 'refs/heads/main' && github.event_name == 'push'
       runs-on: ubuntu-latest
       environment: qa
       steps:
         - name: Add QA host key to known_hosts
           run: |
             mkdir -p ~/.ssh
             echo "${{ secrets.QA_SSH_HOST_KEY }}" >> ~/.ssh/known_hosts
             chmod 600 ~/.ssh/known_hosts
         - name: Write QA deploy key
           run: |
             mkdir -p ~/.ssh
             echo "${{ secrets.QA_SSH_DEPLOY_KEY }}" > ~/.ssh/qa_deploy_key
             chmod 600 ~/.ssh/qa_deploy_key
         - name: Trigger deploy.sh with ref ${{ github.sha }}
           run: |
             ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=~/.ssh/known_hosts \
               -i ~/.ssh/qa_deploy_key -o IdentitiesOnly=yes \
               deploy@95.46.211.230 "deploy:${{ github.sha }}"
         - name: Health check
           run: |
             for i in 1 2 3 4 5; do
               code=$(curl -s -o /dev/null -w '%{http_code}' https://qa-uz.aiqadam.org/health)
               if [ "$code" = "200" ]; then echo "healthy"; exit 0; fi
               sleep 10
             done
             echo "QA health check failed after deploy" >&2
             exit 1
         - name: Clean up key material
           if: always()
           run: rm -f ~/.ssh/qa_deploy_key

     deploy-prod:
       name: deploy-prod
       needs: build
       if: github.event_name == 'workflow_dispatch'
       runs-on: ubuntu-latest
       environment: production
       steps:
         - name: Validate git_ref format
           run: |
             ref="${{ inputs.git_ref }}"
             if ! echo "$ref" | grep -Eq '^[0-9a-fA-F]{7,40}$'; then
               echo "git_ref must be a 7-40 character hex commit SHA, got: $ref" >&2
               exit 1
             fi
         - name: Add prod host key to known_hosts
           run: |
             mkdir -p ~/.ssh
             echo "${{ secrets.PROD_SSH_HOST_KEY }}" >> ~/.ssh/known_hosts
             chmod 600 ~/.ssh/known_hosts
         - name: Write prod deploy key
           run: |
             mkdir -p ~/.ssh
             echo "${{ secrets.PROD_SSH_DEPLOY_KEY }}" > ~/.ssh/prod_deploy_key
             chmod 600 ~/.ssh/prod_deploy_key
         - name: Trigger deploy.sh with ref ${{ inputs.git_ref }}
           run: |
             ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=~/.ssh/known_hosts \
               -i ~/.ssh/prod_deploy_key -o IdentitiesOnly=yes \
               deploy@95.46.211.224 "deploy:${{ inputs.git_ref }}"
         - name: Health check
           run: |
             for i in 1 2 3 4 5; do
               code=$(curl -s -o /dev/null -w '%{http_code}' https://aiqadam.org/health)
               if [ "$code" = "200" ]; then echo "healthy"; exit 0; fi
               sleep 10
             done
             echo "Prod health check failed after deploy" >&2
             exit 1
         - name: Clean up key material
           if: always()
           run: rm -f ~/.ssh/prod_deploy_key
   ```

   Notes on this file:
   - `known_hosts` is built from the `QA_SSH_HOST_KEY`/`PROD_SSH_HOST_KEY` secrets (expected format: the full `<host> <keytype> <base64>` line as produced by `ssh-keyscan`, matching what T-0112 stored) — `StrictHostKeyChecking=yes` is used, never `no`, satisfying the task's explicit requirement.
   - `deploy-qa`'s `environment: qa` is a lightweight environment with no required reviewers (auto-deploy is the task's explicit design) — created only if useful for secret scoping; if the executor finds `environment: qa` adds no value beyond `production`'s reviewer gate, it may omit the `environment:` key from `deploy-qa` and use repo-level secrets directly. This is a minor implementation latitude, not a scope change — the secret *names* and *values* referenced do not change either way.
   - `deploy-prod` triggers only on `workflow_dispatch` (not on tag push, not on a schedule) — matches the task's "manually triggered... deploys a specific git ref/tag chosen at trigger time" requirement exactly.
   - The `git_ref` regex validation happens both in the workflow (defense in depth, fails fast in the Actions UI) and again inside `deploy.sh` on the host (the authoritative check, since the workflow-side check is bypassable by anyone who can reach the SSH key directly, e.g. if the key ever leaks).
   - Verification: file exists at `.github/workflows/ci-cd.yml`, `git diff --stat` shows exactly one new file, no changes to `deploy.yml`/`ci.yml`/any other existing workflow file.

5. **Commit and push the new workflow file** — command:
   ```
   cd "c:\Users\tvolo\dev\ai-dala\aiqadam" && git add .github/workflows/ci-cd.yml && git commit -m "Add ci-cd.yml: build gate + QA auto-deploy + prod manual promote via SSH forced-command deploy.sh" && git push origin main
   ```
   Verification: `git log -1 --format=%H` on `origin/main` (via `gh api repos/aiqadam/ai-qadam-platform/commits/main --jq .sha`) matches the local commit hash; `gh run list --workflow=ci-cd.yml --limit 1` shows a run triggered by this push (the `build` job will run since this is a push to `main`; `deploy-qa` will also fire — this is expected and desired, since T-0113's acceptance criteria implies the pipeline should work end-to-end, and T-0114 is the task that formally exercises the first CI-driven QA deploy — but note this in Issues/risks: authoring this file on `main` WILL trigger a real QA deploy immediately, see below).

6. **Create/confirm the `production` GitHub Environment with required reviewers** — command (reviewer list supplied by the user; placeholder below must be filled in before execution, not defaulted):
   ```
   gh api repos/aiqadam/ai-qadam-platform/environments/production -X PUT -f "wait_timer=0" -F "reviewers[][type]=User" -F "reviewers[][id]=<REVIEWER_USER_ID>" -f "deployment_branch_policy=null"
   ```
   Verification: `gh api repos/aiqadam/ai-qadam-platform/environments/production --jq '.protection_rules[] | select(.type=="required_reviewers")'` returns the configured reviewer(s). **Open item:** the reviewer's GitHub user ID/username is not supplied anywhere in this run's inputs — the executor must obtain it from the user before running this command (see Open questions).

#### Part B — Both hosts (`pro-data-tech-qa` 95.46.211.230, `pro-data-tech-prod` 95.46.211.224), executed identically per environment with `<env>` substituted `qa`/`prod`, `<port>` substituted `3113`/`3115`, `<compose-file>` substituted `docker-compose.qa.yml`/`docker-compose.prod.yml`, `<health-url>` substituted `https://qa-uz.aiqadam.org/health`/`https://aiqadam.org/health`:

7. **Backup the current placeholder `deploy.sh` before overwriting** — command (SSH as `tvolodi`, who has sudo, NOT as the locked-down `deploy` user):
   ```
   ssh tvolodi@<host-ip> "sudo cp /opt/apps/aiqadam-<env>/deploy/deploy.sh /opt/apps/aiqadam-<env>/deploy/deploy.sh.pre-T0113.$(date -u +%Y%m%dT%H%M%SZ).bak"
   ```
   Verification: `ssh tvolodi@<host-ip> "ls -la /opt/apps/aiqadam-<env>/deploy/deploy.sh.pre-T0113.*.bak"` shows the backup file, mode/owner preserved.

8. **Write the new `deploy.sh`** — the executor writes this exact content to a local temp file, then `scp`s it to `/opt/apps/aiqadam-<env>/deploy/deploy.sh` as `tvolodi` (who has sudo/write access to `/opt/apps/`), then fixes ownership/mode to match the original (`deploy:deploy`, `750`):

   ```bash
   #!/bin/bash
   # deploy.sh — forced-command target for the `deploy` CI user.
   # Installed by T-0113. Reads the requested git ref from
   # SSH_ORIGINAL_COMMAND (set by sshd even though this script itself
   # is invoked via authorized_keys' command= override — this is
   # standard, documented OpenSSH behavior, distinct from and
   # unaffected by the /bin/bash-vs-nologin forced-command issue found
   # during T-0112).
   #
   # Expected invocation: ssh deploy@host "deploy:<40-or-7-char-hex-sha>"
   # Anything else (wrong format, missing, unparseable) is rejected.
   #
   # HARD RULE: this script must NEVER run `git clean`. The deploy/
   # directory (this script, the compose files, and .env) is untracked
   # by git — `git reset --hard` does not remove untracked files, but
   # `git clean` would destroy them irrecoverably with no backup. Do
   # not add `git clean` to this script under any circumstance.

   set -euo pipefail

   APP_DIR="/opt/apps/aiqadam-<env>"
   COMPOSE_FILE="deploy/<compose-file>"
   COMPOSE_PROJECT="aiqadam-<env>"
   LAST_DEPLOYED_FILE="$APP_DIR/deploy/.last-deployed-commit"
   LOG_PREFIX="[deploy.sh $(date -u +%Y-%m-%dT%H:%M:%SZ)]"

   echo "$LOG_PREFIX invoked; SSH_ORIGINAL_COMMAND=${SSH_ORIGINAL_COMMAND:-<unset>}"

   # --- Parse and validate the requested ref ---
   if [[ -z "${SSH_ORIGINAL_COMMAND:-}" ]]; then
     echo "$LOG_PREFIX ERROR: no SSH_ORIGINAL_COMMAND set; refusing to deploy" >&2
     exit 1
   fi

   if [[ "$SSH_ORIGINAL_COMMAND" =~ ^deploy:([0-9a-fA-F]{7,40})$ ]]; then
     REQUESTED_REF="${BASH_REMATCH[1]}"
   else
     echo "$LOG_PREFIX ERROR: SSH_ORIGINAL_COMMAND did not match ^deploy:<7-40 hex chars>$, got: $SSH_ORIGINAL_COMMAND" >&2
     exit 1
   fi

   cd "$APP_DIR"

   # --- Confirm the ref actually exists on the remote before touching the checkout ---
   # (never eval/exec the raw string; only ever pass $REQUESTED_REF, which is
   # already regex-constrained to hex characters, as a git argument)
   git fetch origin --quiet
   if ! git cat-file -e "${REQUESTED_REF}^{commit}" 2>/dev/null; then
     echo "$LOG_PREFIX ERROR: ref $REQUESTED_REF not found after fetch; refusing to deploy" >&2
     exit 1
   fi

   # --- Record current commit for rollback before switching ---
   PREVIOUS_COMMIT="$(git rev-parse HEAD)"
   echo "$PREVIOUS_COMMIT" > "$LAST_DEPLOYED_FILE.previous"

   # --- Checkout the requested ref (detached HEAD, matches existing convention) ---
   git checkout --detach "$REQUESTED_REF" --quiet

   # --- Record new commit as the current deployed ref ---
   git rev-parse HEAD > "$LAST_DEPLOYED_FILE"

   # --- Build and (re)start the stack ---
   docker compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_FILE" up -d --build

   echo "$LOG_PREFIX deployed $REQUESTED_REF (was $PREVIOUS_COMMIT)"
   docker compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_FILE" ps
   ```

   Verification: `ssh tvolodi@<host-ip> "sudo -u deploy test -x /opt/apps/aiqadam-<env>/deploy/deploy.sh && echo EXECUTABLE"` prints `EXECUTABLE`; `ssh tvolodi@<host-ip> "stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh"` prints `deploy:deploy 750` (unchanged from the placeholder's ownership/mode).

9. **Live-verify the real deploy path end-to-end on QA only, using the current pinned commit as a no-op self-deploy (safe rehearsal before relying on it from CI)** — command:
   ```
   ssh -i "C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci" -o IdentitiesOnly=yes deploy@95.46.211.230 "deploy:dfd2a7c479c18e9acea5b3e0f53e19aca3f777bb"
   ```
   Verification: output shows `deployed dfd2a7c... (was dfd2a7c...)` (previous == new, since this is a self-deploy of the already-running commit), `docker compose ps` table shows both `aiqadam-qa` containers `Up`; `curl -s -o /dev/null -w '%{http_code}' https://qa-uz.aiqadam.org/health` returns `200`; `ssh tvolodi@95.46.211.230 "cat /opt/apps/aiqadam-qa/deploy/.last-deployed-commit"` shows the full 40-char SHA of `dfd2a7c...`. This proves `SSH_ORIGINAL_COMMAND` parsing, the fetch/checkout/rebuild cycle, and the rollback-marker-file mechanism all work, without ever deploying an untested ref to a live environment. **Do not run this same rehearsal against prod** — prod's equivalent proof happens naturally the first time `deploy-prod` is actually used (T-0115), under the required-reviewer gate; rehearsing against prod here would be an unreviewed prod change and is out of this plan's low-risk auto-rehearsal scope.

10. **Repeat Steps 7–8 for prod** (Step 9's live rehearsal is QA-only per the note above; prod's `deploy.sh` is installed and byte-verified for syntax (`ssh tvolodi@95.46.211.224 "bash -n /opt/apps/aiqadam-prod/deploy/deploy.sh && echo SYNTAX_OK"`) but not invoked against the running stack by this plan).

#### Part C — This infra repo (`c:\Users\tvolo\dev\ai-dala\ai-qadam-infra`)

11. **Update `shared/app-registry.md`** — add a new `### CI/CD` subsection under the existing `## AiQadam` section (after the Production environment table), containing:
    - Workflow file: `.github/workflows/ci-cd.yml` in `aiqadam/ai-qadam-platform`
    - Jobs: `build` (all branches/PRs, hard-fails on lint/typecheck/test/build failure — independent gate from `ci.yml`'s advisory posture), `deploy-qa` (auto, push to `main`, needs `build`), `deploy-prod` (manual, `workflow_dispatch`, needs `build`, gated by `production` GitHub Environment required reviewers)
    - Ref-passing mechanism: `SSH_ORIGINAL_COMMAND` read inside `deploy.sh` on each host, format `deploy:<7-40 hex char commit SHA>`, validated by regex + `git cat-file -e` before checkout
    - Rollback marker: `/opt/apps/aiqadam-<env>/deploy/.last-deployed-commit` (current) and `.last-deployed-commit.previous` (prior, written by `deploy.sh` before every checkout)
    - Secrets used (names only): `QA_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_DEPLOY_KEY`, `PROD_SSH_HOST_KEY`
    - Explicit note: `deploy.yml` (Coolify) and `ci.yml` (advisory) are separate, untouched pipelines in the same repo — not related to this CI/CD section.

12. **Update `shared/deploy-protocol.md`** — add a short addendum noting that the AiQadam `ci-cd.yml` pipeline (T-0113) does NOT use the `tasks/deploy-request.md` signal-file convention, with the one-sentence rationale from Design decision 4 above (CI-triggered deploys are not "requests" in the sense the protocol defines — there's no infra-orchestrator run in the loop at deploy time).

13. **Update both host landscape files** (`landscape/hosts/pro-data-tech-qa.md`, `landscape/hosts/pro-data-tech-prod.md`) — replace the "Deploy script placeholder" bullet under "CI/CD deploy user" with a description of the real `deploy.sh` (path, purpose, `SSH_ORIGINAL_COMMAND` mechanism, rollback marker file, backup file location from Step 7). This is normally step 08's job (landscape-updater) — listed here so the executor knows which files it must NOT edit itself; the executor should leave landscape/ updates to step 08 except where explicitly instructed otherwise. Flagging this ownership boundary explicitly to avoid the executor overstepping into step 08's territory.

### Rollback

**Workflow file (Part A):**
1. Revert the commit — command: `cd "c:\Users\tvolo\dev\ai-dala\aiqadam" && git revert --no-edit <commit-sha-from-step-5> && git push origin main`. This removes `ci-cd.yml` from `main` (a revert commit, not a force-push) without touching `deploy.yml`/`ci.yml`.
2. `production` Environment: `gh api repos/aiqadam/ai-qadam-platform/environments/production -X DELETE` (only if it did not previously exist — Step 2 must confirm this before Step 6 creates it, so rollback knows whether to delete or restore prior state).

**`deploy.sh` (Part B, per host):**
1. Restore the pre-change backup — command: `ssh tvolodi@<host-ip> "sudo cp /opt/apps/aiqadam-<env>/deploy/deploy.sh.pre-T0113.<timestamp>.bak /opt/apps/aiqadam-<env>/deploy/deploy.sh && sudo chown deploy:deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh && sudo chmod 750 /opt/apps/aiqadam-<env>/deploy/deploy.sh"`.
2. If a real deploy already ran against the new script and changed the running containers (e.g. QA's rehearsal in Step 9, or any real T-0114/T-0115 deploy after this task closes) and the *application* needs to roll back to the previously-running commit (not just the script): `ssh -i <deploy-key> deploy@<host-ip> "deploy:$(cat /opt/apps/aiqadam-<env>/deploy/.last-deployed-commit.previous)"` — this is the exact, mechanical rollback command the workflow-specific rule requires, made possible by Step 8's `.last-deployed-commit.previous` marker file. Note this only works once the NEW `deploy.sh` is in place (a chicken-and-egg case: if rolling back the script itself per bullet 1, the app-level rollback in bullet 2 must be run BEFORE restoring the placeholder script, since the placeholder cannot parse `deploy:<ref>` at all).

**This plan is not idempotent** for Part B Step 9 (the QA rehearsal runs a real `docker compose up -d --build`, which is safe to repeat but does briefly recreate containers each time it's re-run) — re-running Step 9 is safe (self-deploy of the same pinned commit, health-checked immediately after) but is not a no-op against container uptime. All other steps (backup, file write, landscape edits) are idempotent or safely re-runnable.

### Verification (for step 07)

- **On-host (QA):** `ssh tvolodi@95.46.211.230 "docker compose -p aiqadam-qa -f /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml ps"` shows both `oidc-stub` and `api` containers `Up`; `cat /opt/apps/aiqadam-qa/deploy/.last-deployed-commit` contains a valid 40-char SHA matching the last-deployed ref; `stat -c '%a' /opt/apps/aiqadam-qa/deploy/deploy.sh` returns `750`; `stat -c '%U:%G' /opt/apps/aiqadam-qa/deploy/deploy.sh` returns `deploy:deploy`.
- **On-host (prod):** same checks against `/opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml` and the 3-container stack; `bash -n /opt/apps/aiqadam-prod/deploy/deploy.sh` exits 0 (syntax-valid, since Step 10 does not live-invoke it).
- **On GitHub:** `gh run list --repo aiqadam/ai-qadam-platform --workflow=ci-cd.yml --limit 5` shows at least one `build` run and one `deploy-qa` run both `completed`/`success` (from the Step 5 push); `gh api repos/aiqadam/ai-qadam-platform/environments/production --jq '.protection_rules'` shows a `required_reviewers` rule with at least one reviewer configured.
- **External:** `curl -s -o /dev/null -w '%{http_code}' https://qa-uz.aiqadam.org/health` → `200`; `curl -s https://qa-uz.aiqadam.org/health | grep -q '"status":"ok"'` → match. Prod: `curl -s -o /dev/null -w '%{http_code}' https://aiqadam.org/health` → `200` (already true before this plan runs; must remain `200` throughout — Part B prod steps do not restart the running containers, only replace/syntax-check the script).
- **Regression check:** Penpot on `pro-data-tech-prod` (`curl -s -o /dev/null -w '%{http_code}' https://penpot.aiqadam.org` → `200`, `docker ps --filter name=penpot- --format '{{.Names}}: {{.Status}}'` shows all 7 containers `Up`) must be re-verified unregressed after Part B's prod steps, per the standing convention on this host from every prior T-011x run.

### Resources used
- Secrets (by name): `QA_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_DEPLOY_KEY`, `PROD_SSH_HOST_KEY` (all read-only references inside the new workflow file and via existing on-host authorized_keys; no secret value is written to any file in this repo).
- Files modified on host:
  - `pro-data-tech-qa`: `/opt/apps/aiqadam-qa/deploy/deploy.sh` (replaced), `/opt/apps/aiqadam-qa/deploy/deploy.sh.pre-T0113.<ts>.bak` (new backup), `/opt/apps/aiqadam-qa/deploy/.last-deployed-commit` and `.last-deployed-commit.previous` (new, written by the script itself on first invocation).
  - `pro-data-tech-prod`: `/opt/apps/aiqadam-prod/deploy/deploy.sh` (replaced), `/opt/apps/aiqadam-prod/deploy/deploy.sh.pre-T0113.<ts>.bak` (new backup). No `.last-deployed-commit` files yet (script not live-invoked on prod by this plan).
- Files modified in this repo (landscape/, to be applied at step 08): `shared/app-registry.md` (new CI/CD subsection), `shared/deploy-protocol.md` (signal-file-not-used addendum), `landscape/hosts/pro-data-tech-qa.md`, `landscape/hosts/pro-data-tech-prod.md` (deploy.sh description update).
- External APIs called: GitHub REST API via `gh` (repo secrets list, environments list/create, workflow runs list), GitHub Actions itself (the new `ci-cd.yml` runs on GitHub's infrastructure once pushed).

### Estimated impact
- Downtime: none expected. `docker compose up -d --build` recreates containers with brief (sub-second to a few seconds) service interruption per container during restart, consistent with every prior T-0110/T-0111 deploy pattern on these hosts. QA's Step 9 rehearsal causes exactly one such brief interruption; prod has none (script not invoked).
- Affected services: `aiqadam-qa` stack (oidc-stub, api) — one real restart cycle via Step 9. `aiqadam-prod` stack — script replaced but not invoked, zero container impact. Penpot — untouched, re-verified as a regression check only.
- Reversibility: fully reversible. The workflow file is revertible via `git revert` (Part A rollback). `deploy.sh` is restorable from the Step 7 backup on each host. The one destructive-if-misused surface (`git checkout --detach` inside `deploy.sh`) never runs `git clean`, so no untracked file (compose files, `.env`) is ever at risk; `git reset`/`checkout` are non-destructive to those files by construction.

## Issues / risks

- **Authoring `ci-cd.yml` on `main` and pushing (Step 5) will trigger a real, live `deploy-qa` run immediately** — GitHub Actions fires on push to `main` regardless of intent, so the moment this file lands, `build` runs and (assuming it passes) `deploy-qa` executes for real against `pro-data-tech-qa`, deploying whatever commit is at `origin/main` at push time (very likely NOT `dfd2a7c`, since `main` has presumably moved since T-0110 pinned that commit). This is a live QA deploy of a commit that has never been deployed to QA before, happening as a side effect of authoring a config file — not something T-0113's task description frames as an explicit acceptance criterion, but it is the mechanical, unavoidable consequence of a push-triggered workflow. **This is why this plan is `NEEDS_APPROVAL`, not `PASS`**, despite the task's `estimated_blast_radius: low` / `estimated_reversibility: full` frontmatter — the frontmatter describes the *file authoring* task, but the actual first execution of this plan produces a real, unreviewed deploy to a real (if non-production) environment, deploying app code that has not been through this exact pipeline before. The user should decide, before approving: (a) accept that Step 5 triggers a real QA deploy of current `main`, (b) have the executor confirm with the user what commit `origin/main` is at before pushing, or (c) explicitly sequence this so T-0114 (the task nominally chartered for "first CI-driven deploy to QA") is the one that knowingly exercises this, and this plan pushes the workflow file from a branch/PR first, merging to `main` only once T-0114 is ready to proceed. Flagging rather than deciding unilaterally, since the task's own dependency graph (`blocks: [T-0114]`) suggests T-0114 was meant to be the moment of first real deploy, not a side effect of T-0113.
- **Prod `deploy.sh` is written but never invoked by this plan** (Step 10) — this is intentional (no live prod change without the reviewer-gated `deploy-prod` job, consistent with `NEEDS_APPROVAL` posture for anything touching prod), but means Step 8's script for prod is verified only for syntax, not for a real end-to-end `SSH_ORIGINAL_COMMAND` → checkout → compose cycle, until T-0115 exercises it for the first time. That first real prod invocation should be treated with the same scrutiny as any first-time prod deploy per `shared/approval-protocol.md` ("Always `NEEDS_APPROVAL`: first-time deploys to prod").
- **`production` GitHub Environment reviewer list is not supplied by any input to this run.** Step 6 cannot be executed as literally written until the user provides at least one reviewer identity. Executor must ask before running Step 6's `gh api` call — do not default to a single hardcoded reviewer.
- **Regex accepts short SHAs (7+ hex chars), which are ambiguous in a large/old repo.** For this repo's current size this is a low practical risk, but a determined attacker with valid key access could theoretically supply an ambiguous short prefix. `git cat-file -e "<ref>^{commit}"` will fail loudly (not silently resolve to the wrong commit) if a short ref is ambiguous in this local checkout, so the risk is caught, not masked — noted as acceptable, not a blocker.
- **This plan intentionally does not add tag-ref support** (regex only matches hex SHAs) even though the task text says "ref/tag" — full-SHA deploys satisfy "specific ref chosen at trigger time" and are strictly safer (unambiguous, unforgeable-by-renaming) than tag names; tag support is a reasonable, separable follow-up, not silently smuggled into this task's scope.
- **Blast radius beyond target scope:** none identified — all host changes are confined to `/opt/apps/aiqadam-<env>/deploy/` on the two named hosts, plus the new workflow file and `production`/`qa` Environments in the single named GitHub repo. sshd config, UFW, nginx, TLS, and Penpot are not touched by any step in this plan.

## Open questions (optional)
- Who should be listed as required reviewer(s) on the `production` GitHub Environment? (Blocks Step 6 — must be answered before execution, not defaulted.)
- Should Step 5 (push `ci-cd.yml` to `main`) proceed knowing it will trigger an immediate real `deploy-qa` run of whatever commit is currently at `origin/main` — or should the executor instead open this as a PR first and let the user merge (and thus trigger the first real deploy) at a moment of their choosing, effectively treating that merge as the true T-0114 trigger event? This materially changes when/whether a live QA deploy happens as a side effect of this task, and is the primary reason this plan is `NEEDS_APPROVAL`.
