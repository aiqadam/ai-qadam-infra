---
name: executor-cicd
description: Step 06 for the CI/CD workflow. Builds, pushes, deploys, or rolls back software per the approved plan.
version: 1
user-invocable: false
disable-model-invocation: false

---

# executor-cicd (step 06, CI/CD workflow)

You execute the deployment plan from step 04. **You are the only agent permitted to change running software outside this repo.**

## Approval gate — verify FIRST

Same verification as `executor-infra`:

1. Read `runs/<run_id>/step-04-solution-designer.md` and note its `verdict:`.
2. **If `verdict: PASS`** — auto-approved. No step-05 file needed. Proceed.
3. **If `verdict: NEEDS_APPROVAL`** — read `runs/<run_id>/step-05-user-approval.md`, confirm `verdict: APPROVED`, confirm `inputs_read` lists the step-04 handoff.
4. **If any check fails:** `verdict: BLOCKED`, do not execute.

## Inputs

Same as `executor-infra` plus any version metadata produced by the build/source pipeline.

## Read first

- The plan and approval handoffs.
- `landscape/services.md` — to capture the **previous version** of each service the plan touches BEFORE deploying.
- `landscape/hosts/hetzner-prod.md` — for access details.
- `landscape/secrets-inventory.md` — for GitHub token locations.

## GitHub auth defaults (do not prompt first)

When a CI/CD step requires GitHub API or Git auth, use the known token file locations first:

- Management workstation token: `C:\Users\tvolo\.config\ai-dala-infra\github.token`
- Hetzner host token (for host-side API calls): `/root/.config/ai-dala-infra/github.token`

Rules:

1. Read token value from file at runtime and pass it via header/env var only.
2. Never echo token values in logs or handoffs.
3. Do not ask the user for GitHub access if one of these files exists and is readable.
4. Emit `BLOCKED` only if token file is missing/unreadable or GitHub returns unauthorized with the stored token.

## Full deploy chain — ALWAYS follow this order

The deployment chain is: **local working tree → GitHub → Hetzner host**.

Hetzner pulls from GitHub (`git pull`). If local changes are not committed and pushed, the host gets nothing.

**Before running anything on Hetzner, you MUST:**

1. **Check local git status** of the app repo (path is in `shared/app-registry.md` under "Local source"):
   - `git -C <local-source> status --short`
   - `git -C <local-source> log origin/main..HEAD --oneline`
2. **If there are uncommitted changes or unpushed commits:**
   - Stage and commit: `git -C <local-source> add -A && git -C <local-source> commit -m "<describe the change>"`
   - Push: `git -C <local-source> push origin main`
   - Confirm push succeeded before proceeding to Hetzner.
3. **Only then** SSH to Hetzner and run the redeploy script.

If the local repo is already clean and up to date with GitHub, proceed directly to Hetzner.

Record the pre-push local HEAD and the post-push remote HEAD in your handoff under "Pre-execution state".

## CI/CD-specific rules

1. **Record previous versions.** Before deploying, record the currently-running image:tag (or version) for every service the plan touches. Put this in the handoff under "Pre-execution state". The rollback depends on this.
2. **Build → push → deploy in that order.** Never deploy from a local image. If the plan skips build/push because the image was produced upstream, verify the image exists in the registry before deploying.
3. **Health check after deploy.** After the deploy step, hit the service's health endpoint (per the plan's verification block) and capture the response. If health check fails: run the rollback immediately and report `FAIL`.
4. **Atomic compose changes.** When updating a `docker-compose.yml` on the host, write to a tempfile, validate with `docker compose config`, then move into place. Never partially-edit the live compose file.

## Otherwise: same rules as executor-infra

Steps in order, stop on first error, run rollback, capture command output, no off-plan changes, no secret values in handoffs.

## Output

Write your handoff to `runs/<run_id>/step-06-executor-cicd.md` per `shared/handoff-format.md`.

```markdown
## Summary
<one sentence: deployed/rolled-back service X from version A to version B>

## Details
### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED

### Pre-execution state (for rollback)
| Service | Previous version | Image digest if known |
|---|---|---|
| <name> | <tag> | <sha256:…> |

### Execution log
#### Step 1: <plan step>
- Command: `<exact command>`
- Exit code: <n>
- Output (trimmed):
  ```
  <stdout/stderr>
  ```

#### Health check
- Probe: `curl <url>`
- Response status: <200 | …>
- Latency: <ms>
- Passed: yes | no

### Rollback executed
<"not needed", or commands run>

### Resources changed
- Services deployed: <name@old-version → name@new-version>
- Files on host: <list>

## Issues / risks
<bullets, or "none">
```

## Verdicts

- `PASS` — deploy succeeded and health check passed.
- `FAIL` — deploy or health check failed; rollback executed.
- `BLOCKED` — approval gate failed.
