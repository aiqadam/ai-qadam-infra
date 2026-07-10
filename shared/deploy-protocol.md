---
name: deploy-protocol
version: 1
---

# Deploy protocol

How work flows between project agents and the infra orchestrator.

## Authority model

- **Infra agents are admin.** They have read/write access to all project repos under `ai-dala/`.
- **Project agents have NO access to this infra repo.** They cannot create infra tasks.
- **The user is the bridge** for project→infra handoffs (until an automated signal mechanism is built).

---

## Lifecycle

### 1 — Project signals readiness

When a project agent finishes a build cycle it creates (or updates) a signal file in its
own repo at `tasks/deploy-request.md`:

```markdown
# Deploy request
app: productfactory
ref: <git-tag or branch>
env: test
ready: true
notes: <what changed>
```

Infra agents can read this file. It is not a binding command — it is a signal.

### 2 — User initiates the infra workflow

The user tells the infra orchestrator: *"deploy ProductFactory to test"* or *"execute T-XXXX"*.
The orchestrator reads the task file and runs the `deploy-app` workflow (8 steps).

### 3 — Infra executes

Standard 8-step `deploy-app` workflow. See `workflows/deploy-app.md`.

### 4a — Success

- Container running, health check passes.
- `landscape/services.md` updated.
- Deploy task → `done`.
- Signal file `tasks/deploy-request.md` in project repo set to `ready: false` by landscape-updater.

### 4b — App-level failure

The deployed container starts but health check fails due to app code:

1. Execution-validator captures container logs (`docker logs pf-test --tail 100`).
2. Landscape-updater creates `tasks/T-NNNN-<slug>.md` **in the project repo's `tasks/` dir**.
3. Infra deploy task → `status: failed`, `related: [project-task-path]`.
4. User notified with project task path.
5. Project agent picks up the task on its next run, fixes the code, re-signals readiness.

### 4c — Infrastructure failure

Missing nginx vhost, DNS not resolved, firewall gap, missing `.env` on host, etc.:

1. Execution-validator documents the infra issue.
2. Orchestrator creates a new infra task to fix it.
3. Deploy task → `status: blocked`, `blocked_by: [new-infra-task]`.
4. After the infra task is done, deploy task is retried.

---

## Reading a project's deploy request (infra side)

The executor-cicd agent may read `<project-root>/tasks/deploy-request.md` to determine
the exact git ref to deploy. If the file does not exist or `ready: false`, the executor
MUST halt and report `BLOCKED` — do not guess a ref.

---

## One-time setup vs. repeat deploys

| Task type | When | Workflow |
|---|---|---|
| Setup infra (T-XXXX-setup-\<app\>-deploy-infra) | Once per app | `infrastructure` |
| Deploy to test (T-XXXX-deploy-\<app\>-to-test) | Each release | `deploy-app` |
| Promote to prod (T-XXXX-promote-\<app\>-to-prod) | Each prod release | `deploy-app` |

Setup tasks use the `infrastructure` workflow (nginx, DNS, UFW, directories) because
they change host-level config. Actual deploys use `deploy-app`.
