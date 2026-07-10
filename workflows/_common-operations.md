---
name: common-operations
version: 3
description: The canonical 8-step skeleton shared by all workflows. Individual workflow files override the executor and landscape scope but reuse this skeleton. Read-only workflows can declare state_changing=false to skip the approval gate. State-changing workflows require a pre-existing task file (see tasks/README.md).
---

# Common operations skeleton

Every workflow in this repo is a specialization of this 8-step skeleton. Workflow files (`workflows/infrastructure.md`, `workflows/cicd.md`, …) declare:
- Which **executor** subagent runs at step 06.
- Which **landscape files** the landscape-reader is expected to consult at step 02.
- Any workflow-specific validators, hooks, or extra steps.

They do NOT redefine the skeleton.

## The 8 steps

| # | Step | Agent | Read-only? | Produces verdict |
|---|---|---|---|---|
| 01 | Read task | `task-reader` | yes | PASS / BLOCKED |
| 02 | Read landscape | `landscape-reader` | yes | PASS / BLOCKED |
| 03 | Validate task | `task-validator` | yes | PASS / FAIL / BLOCKED |
| 04 | Design solution | `solution-designer` | yes | NEEDS_APPROVAL / BLOCKED |
| 05 | User approval | (orchestrator-written) | yes (writes handoff only) | APPROVED / REJECTED — **skipped** when step 04 verdict is `PASS` |
| 06 | Execute | `executor-<workflow>` | NO — changes state | PASS / FAIL / BLOCKED |
| 07 | Validate execution | `execution-validator` | yes | PASS / FAIL |
| 08 | Update landscape | `landscape-updater` | writes to `landscape/` only | PASS / FAIL |

## Cascade table — which prior handoffs each step reads

The orchestrator MUST include these paths in `inputs_read` of each step's prompt. Subagents read them from disk; the orchestrator never pastes their content.

| Step | Reads handoffs from steps | Reads landscape files? |
|---|---|---|
| 01 task-reader | (none — raw user request) | no |
| 02 landscape-reader | 01 | yes (workflow-specified) |
| 03 task-validator | 01, 02 | yes (workflow-specified) |
| 04 solution-designer | 01, 02, 03 | yes (workflow-specified) |
| 05 user-approval | 04 | no |
| 06 executor | 04, 05 | yes (workflow-specified) |
| 07 execution-validator | 04, 06 | yes (workflow-specified) |
| 08 landscape-updater | 02, 04, 06, 07 | yes — and writes back |

## Read-only workflows (`state_changing: false`)

Workflows that declare `state_changing: false` in their frontmatter follow a shortened path: step 05 (user approval) is skipped. Step 04 (solution-designer) may still run if the workflow wants a written plan, OR it may be skipped — each workflow declares this.

For a read-only workflow:

| # | Step | Status |
|---|---|---|
| 01 | Read task | required |
| 02 | Read landscape | required |
| 03 | Validate task | required |
| 04 | Design solution | optional (workflow declares) |
| 05 | User approval | **skipped** |
| 06 | Execute (read-only) | required |
| 07 | Validate execution | required |
| 08 | Update landscape | required |

The orchestrator MUST verify the conditions in `shared/approval-protocol.md` before skipping step 05: the workflow's frontmatter flag, the executor's tool allowlist, and the executor's instructions all must affirm read-only. If any check fails, the gate runs anyway.

## Routing rules

The orchestrator applies these rules after reading each step's handoff frontmatter. See `shared/verdicts.md` for the canonical action table.

- `PASS` → advance to the next step. Exception: `PASS` from step 04 means auto-approved — skip step 05 and advance directly to step 06.
- `FAIL` → retry the same step (budget: 2 retries). If budget exhausted, escalate to the user and halt.
- `NEEDS_APPROVAL` → produced only by step 04. Halt; run the approval protocol (`shared/approval-protocol.md`); continue from step 06 if `APPROVED`.
- `BLOCKED` → halt; report the blocker to the user with a specific ask; do not auto-retry.
- `APPROVED` / `REJECTED` → produced only by step 05 (when step 04 emitted `NEEDS_APPROVAL`). `APPROVED` → step 06. `REJECTED` → halt and report.

## Task file requirement

State-changing workflows (those without `state_changing: false` in their frontmatter) REQUIRE a pre-existing task file at `tasks/T-NNNN-<slug>.md` referenced by the user when they invoke the orchestrator. If no task file is referenced, the orchestrator MUST:

1. Halt the run before any subagent invocation.
2. Ask the user to either name an existing task ID or first create one (via the promotion workflow or manually).
3. Refuse to proceed until either action is taken.

Read-only / discovery workflows (`state_changing: false`) do NOT require a task file. They may, however, CREATE new observation-status task files at step 08 when they surface issues — see the `task-reader` and `landscape-updater` agent instructions.

## Run initialization

When the orchestrator receives a new user task, before invoking any subagent it MUST:

1. **For state-changing workflows:** verify the user named a task file under `tasks/`. Read its frontmatter to confirm `status` is `pending` or `in-progress`. If `done`/`wontfix`/`superseded`/`blocked`, refuse to proceed and explain.
2. **For all workflows:** generate a `run_id` of the form `YYYY-MM-DD-<short-slug>-NNN` where `<short-slug>` is a 2-5 word kebab-case summary of the task and `NNN` starts at `001`. If `runs/<run_id>/` already exists for that date+slug, increment `NNN`.
3. Create the directory `runs/<run_id>/`.
4. **For state-changing workflows:** transition the task file's `status` to `in-progress`, append the run_id to its `executed_by_runs:` list, and append a History line: `- YYYY-MM-DD: status -> in-progress, run <run_id>`.
5. Initialize working state (which step is in progress, retry counters) — using `TodoWrite` in Claude Code, or the equivalent task tracking in Copilot.

## Run finalization

After step 08 completes successfully, the orchestrator MUST:

1. Confirm `landscape/` updates were committed (or at least staged) in the working tree.
2. **For state-changing workflows:** confirm the task file's status was transitioned to `done` (with `outcome: succeeded` and `closed: <today>`) or `failed`, and that a History entry was appended. This is the landscape-updater (step 08)'s responsibility — verify it happened.
3. **For read-only workflows that surfaced new issues:** confirm any new observation-status task files were created in `tasks/` (one per issue) and added to `tasks/_index.md`.
4. Write a short closing message to the user summarizing what was done, what changed in `landscape/`, any task transitions, and any follow-up items captured in step 07's "Open questions".
5. The `runs/<run_id>/` directory is retained for audit. The orchestrator does not delete it.

## Forbidden behaviours

- Skipping step 02 (landscape-reader) because the orchestrator "already knows" the system. The landscape file is the source of truth; the orchestrator's memory is not.
- Skipping step 05 (user approval) for state-changing workflows. Even if the user said "go ahead" earlier in the conversation, each run requires its own approval handoff.
- Merging two steps into one subagent invocation. Each step is one subagent, one handoff file.
- Running step 06 (executor) without verifying step 05's approval handoff exists with `verdict: APPROVED`.
- Running a state-changing workflow without a task file reference. The task file is the durable audit record; runs without one cannot be audited later.
- Transitioning a task to a closed status (`done`/`wontfix`/`superseded`) without appending a History entry. The History section is the audit trail and must capture every status change.
