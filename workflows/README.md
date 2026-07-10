# Workflows

Each workflow defines an end-to-end process for a class of tasks. All workflows share the 8-step skeleton in `_common-operations.md` and override only the executor and landscape scope.

## Current workflows

| File | Purpose |
|---|---|
| [`_common-operations.md`](./_common-operations.md) | The 8-step skeleton. All workflows inherit from this. |
| [`infrastructure.md`](./infrastructure.md) | Changes to hosts, services, networking, Cloudflare, certificates. State-changing. |
| [`cicd.md`](./cicd.md) | Building, testing, deploying software to managed hosts. State-changing. |
| [`discovery-host.md`](./discovery-host.md) | Read-only enumeration of a managed host. `state_changing: false` — no approval gate. |
| [`discovery-cloudflare.md`](./discovery-cloudflare.md) | Read-only enumeration of Cloudflare zones. `state_changing: false` — no approval gate. |
| [`audit-host.md`](./audit-host.md) | Read-only **vulnerability audit** of a managed host (CVE/patch posture, SSH/sudoers hardening, container security flags, nginx TLS, world-writable scan, log review). Creates observation tasks for findings. `state_changing: false`. |
| [`audit-repo.md`](./audit-repo.md) | Read-only audit of the `ai-dala-infra` repo itself (secrets-in-repo scan, agent protocol gaps, settings permission scope, cross-reference integrity). Touches no external systems. `state_changing: false`. |

## How a workflow is selected

The orchestrator selects a workflow at step 01 (task-reader) based on the user's request. The task-reader writes the chosen workflow name into its handoff's `Details` section. If the request fits no workflow, the task-reader emits `verdict: BLOCKED` and asks the user to clarify.

## Adding a new workflow

1. Copy `infrastructure.md` as a starting point.
2. Set the executor binding (step 06) to a new or existing executor subagent.
3. Declare which `landscape/` files are in scope.
4. Add any workflow-specific rules.
5. List it in this README.
6. Update the orchestrator's instructions to recognize it.
