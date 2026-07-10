---
name: workflow-deploy-app
version: 1
description: Application deployment workflow — building and deploying versioned apps to test or prod environments on hetzner-prod. Uses Option-A topology (same host, separate ports + nginx vhosts per environment).
extends: workflows/_common-operations.md
state_changing: true
---

# Deploy-app workflow

Specialization of `workflows/_common-operations.md` for deploying application code.

## When this workflow applies

- First-time deployment of an app to test or prod (after its setup task is done)
- Deploying a new version of a running app
- Promoting a version from test → prod
- Rolling back a deployment
- Rotating secrets / environment variables for a running deployment

## Step bindings

| Step | Agent |
|---|---|
| 01 | `task-reader` |
| 02 | `landscape-reader` |
| 03 | `task-validator` |
| 04 | `solution-designer` |
| 05 | (orchestrator-written approval) |
| 06 | **`executor-cicd`** |
| 07 | `execution-validator` |
| 08 | `landscape-updater` |

## Landscape files in scope

- `landscape/services.md` — running containers, ports, deployed versions
- `landscape/hosts/hetzner-prod.md` — target host
- `landscape/domains.md` — DNS subdomains that must exist before deploy
- `landscape/cloudflare.md` — Cloudflare DNS and SSL settings
- `shared/app-registry.md` — authoritative per-app config (ports, paths, image names)

## App registration requirement

Before a deploy-app workflow can execute, the application MUST be listed in
`shared/app-registry.md` with all fields populated, AND the app's setup task
(DNS, nginx vhost, server directories, env file) MUST have `status: done`.
If the setup task is not done, the task-validator MUST return `BLOCKED`.

## Deploy chain — local → GitHub → Hetzner

Hetzner pulls app code from GitHub. The full chain is:

**local working tree → commit → push to GitHub → `git pull` on Hetzner**

Every deploy plan MUST include a Phase 0 that runs on the management workstation (this Windows host) before any SSH:

1. Check local git status: `git -C <local-source> status --short` and `git -C <local-source> log origin/main..HEAD --oneline`
2. If uncommitted changes exist: commit them.
3. If unpushed commits exist: push to `origin main`.
4. Confirm GitHub remote HEAD matches local HEAD before proceeding to Hetzner.

If the local repo is already clean and in sync with GitHub, Phase 0 is a no-op — note it and proceed.

## Script-first execution model

Before constructing any command sequence manually, the solution-designer (step 04) and executor (step 06) MUST check the app's `Scripts` table in `shared/app-registry.md`.

- If a script exists for the operation → the executor runs that script. Do not reinvent the command sequence.
- If the script cell says "not yet created" → fall back to the manual sequence below and note in the handoff that a script should be created.

This keeps operational knowledge in the app repo (where it is tested and versioned) rather than re-derived in every plan.

## Build model (local builds on host — fallback when no script exists)

Images are built on the Hetzner host — no external registry is used.

The executor (step 06) follows this sequence when no script is available:

```
# 1. Connect to host
ssh hetzner-prod

# 2. Navigate to checkout (clone on first deploy)
cd /opt/apps/<app>-<env>/
# or on first deploy:
git clone <remote> /opt/apps/<app>-<env>/

# 3. Update code
git fetch && git checkout <ref>   # specific tag or branch tip

# 4. Preserve previous image for rollback
docker tag <app>-<env>:latest <app>-<env>:rollback-$(date +%Y%m%d) 2>/dev/null || true

# 5. Build new image
docker build -f deploy/Dockerfile -t <app>-<env>:latest .

# 6. Replace running container
docker compose -f deploy/docker-compose.<env>.yml up -d --force-recreate
```

## Rollback model

The solution-designer's plan MUST include the exact rollback command. Standard rollback:

```bash
docker tag <app>-<env>:rollback-<date> <app>-<env>:latest
docker compose -f deploy/docker-compose.<env>.yml up -d --force-recreate
```

The executor records the rollback image tag in its step-06 handoff.

## Health check requirement

The execution-validator (step 07) MUST:

1. Look up the app's **Health endpoint** field in `shared/app-registry.md` — do NOT assume `/api/health`. Each app declares its own path and expected response body.
2. Hit `GET http://127.0.0.1:<host-port><health-path>` using `curl -s -o /dev/null -w "%{http_code}"` to get the status code (avoids tripping rate-limit middleware), then a second call with `-s` to capture the body.
3. Assert HTTP 200 and that the response body matches the registry's expected value.
4. Record the full curl output verbatim in its handoff.

A health check failure → `verdict: FAIL`, even if the container is running.

## App-level failure → issue in project repo

If step 07 returns `FAIL` due to an app code issue (as opposed to infra):

- The landscape-updater (step 08) creates a task file in the project's own
  `tasks/` directory (infra has write access). Format: same frontmatter schema
  as infra tasks, but stored in the project repo.
- The infra deploy task transitions to `status: failed`, with `related:` pointing
  at the project task file path.
- The user is notified with the project task path so the project agent can pick it up.

## Infra failure → new infra task

If step 07 returns `FAIL` due to an infrastructure gap (missing nginx config,
firewall rule, DNS not resolved, etc.):

- The orchestrator creates a new infra task to fix it.
- The deploy task transitions to `status: blocked`, `blocked_by:` the new infra task.
- After the infra task is resolved, the deploy task is retried from step 04.

## Version recorded in landscape

The landscape-updater (step 08) MUST update `landscape/services.md` to record:
- App, environment, git ref deployed, Docker image tag, timestamp, container name, host port.
