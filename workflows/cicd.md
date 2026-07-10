---
name: workflow-cicd
version: 1
description: CI/CD workflow — building, testing, deploying software projects to managed hosts or registries.
extends: workflows/_common-operations.md
---

# CI/CD workflow

Specialization of `workflows/_common-operations.md` for software delivery operations.

## When this workflow applies

- Building and pushing container images.
- Deploying a new version of an application to a managed host.
- Rolling back a deployment.
- Promoting a release between environments.
- Pipeline configuration changes (when those pipelines are managed from this repo).

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

- `landscape/services.md` — what runs on each host, current versions
- `landscape/hosts/hetzner-prod.md` — target host details
- `landscape/domains.md` — for deployments behind a specific domain
- `landscape/cloudflare.md` — only if the deployment affects Cloudflare config

## Workflow-specific rules

1. **No deploy without a known-good rollback.** The solution-designer's plan must include the exact rollback step (e.g., `docker compose up -d <service>:<previous-tag>`). The executor must record the previous version in its handoff so rollback is mechanical.
2. **Health check after deploy.** The execution-validator (step 07) must hit the application's health endpoint (or run its smoke test) and capture the response in its handoff. A passing health check is required for `verdict: PASS`.
3. **Version recorded in landscape.** The landscape-updater (step 08) must update `landscape/services.md` to reflect the new running version, with the timestamp of the change.
