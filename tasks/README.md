# Tasks

Durable, audit-friendly artifacts. One file per item — observation, task, or decision the user wants kept on the record.

## Why this exists

Discovery runs and ad-hoc reviews surface dozens of "things worth doing or knowing." Without a first-class place to put them, they accumulate as bullet points scattered across landscape files, decay into noise, and can't be tracked, prioritized, or audited.

This directory solves that. Every artifact here is a **permanent record** with its own ID, lifecycle, and audit history. Runs (in `runs/`) execute against tasks here. Landscape files (in `landscape/`) describe current state, NOT pending work — pending work lives here.

## File layout

```
tasks/
├── README.md                          # this file
├── _template.md                       # canonical template for new task files
├── _index.md                          # generated/maintained index — quick view of all tasks
└── T-NNNN-<kebab-slug>.md             # one file per task
```

## File naming

```
T-NNNN-<kebab-slug>.md
```

- `T-` prefix — distinguishes from runs (`runs/YYYY-MM-DD-...`).
- `NNNN` — four-digit zero-padded counter, globally monotonic. Never reused even after a task is closed.
- `<kebab-slug>` — short descriptive slug, 2–6 words.

Examples:
- `T-0001-enable-hetzner-snapshots.md`
- `T-0014-add-host-firewall.md`
- `T-0027-decide-bizdala-com-purpose.md`

The counter is project-wide. To pick the next ID, look at the highest existing `T-NNNN` in this directory and add 1.

## Frontmatter schema

Every task file MUST start with this frontmatter. See `_template.md` for the canonical version with comments.

```yaml
---
id: T-NNNN-<kebab-slug>           # MUST match filename
title: <one-line title>
kind: observation | task          # observation = surfaced but not yet decided; task = committed work
status: <status>                  # see "Status lifecycle" below
priority: P0 | P1 | P2 | P3       # see "Priority" below
created: YYYY-MM-DD
updated: YYYY-MM-DD
closed: YYYY-MM-DD                # set when status becomes done | wontfix | superseded
outcome: succeeded | failed | abandoned | superseded    # set when closed
created_by: <run_id or "manual">
source_runs: [<run_id>, ...]      # runs that surfaced this item
executed_by_runs: [<run_id>, ...] # runs that worked on this item
affects:                          # landscape files this task is about
  - landscape/<path>
workflow: infrastructure | cicd | discovery-host | discovery-cloudflare | manual | none
blocks: [T-NNNN, ...]             # other tasks that depend on this one
blocked_by: [T-NNNN, ...]
related: [T-NNNN, ...]
estimated_blast_radius: low | medium | high
estimated_reversibility: full | partial | one-way
---
```

## Body structure

The body follows this structure. Sections marked `*required*` MUST be present; others MAY be omitted if empty.

```markdown
# <Title>

## Why *required*
<the motivation — usually quoted/summarized from the source run that surfaced this>

## What done looks like *required*
- [ ] <acceptance criterion 1>
- [ ] <acceptance criterion 2>
- ...

## Result
<filled in when status transitions to done/wontfix/superseded — what actually happened, links to runs, link to commit, observations from execution>

## Notes
<freeform — design considerations, prior discussion, links>

## History *required*
- <YYYY-MM-DD>: created as `kind: observation` by `<run_id or human>`
- <YYYY-MM-DD>: promoted to `kind: task`, priority set to `<P?>`
- <YYYY-MM-DD>: status → `in-progress` by `<run_id>`
- <YYYY-MM-DD>: status → `done`, outcome `succeeded` (run `<run_id>`, commit `<sha>`)
```

The `History` section is append-only. Status changes that aren't recorded here are bugs.

## Status lifecycle

```
                       ┌─────────────────────────────────────────┐
                       │                                         ▼
  (observation)        │                                    [wontfix]
       │               │
       │ promote       │
       ▼               │
   [pending] ──┬──> [in-progress] ──┬──> [done]
       │       │                    │
       │       │                    └──> [failed] ──> [pending] (retry)
       │       │
       │       └──> [blocked] ──> [pending] (unblocked)
       │
       └──> [superseded] (replaced by another task)
```

| Status | Meaning |
|---|---|
| `observation` | Surfaced but not yet committed to act on. Default for items created by discovery runs. |
| `pending` | Committed to act on; not yet started. (Created by promotion from observation, or directly for tasks created with kind=task.) |
| `in-progress` | A workflow run has started executing this. Only one workflow run at a time should hold a task in `in-progress`. |
| `blocked` | Cannot proceed — dependency, external factor, awaiting decision. `blocked_by:` should explain. |
| `done` | Acceptance criteria met. Outcome = `succeeded`. Permanent state. |
| `failed` | A run attempted execution and failed. Outcome stays open until the user decides retry or abandon. |
| `wontfix` | Explicit decision NOT to act. Outcome = `abandoned`. Permanent state. |
| `superseded` | Replaced by another task (recorded in `related:`). Outcome = `superseded`. Permanent state. |

**Closed statuses** (`done`, `wontfix`, `superseded`) set `closed:` and `outcome:` and MUST NOT transition back to open states. If circumstances change, create a new task with a `related:` link to the original.

## Priority

| Priority | Meaning |
|---|---|
| `P0` | Critical. Production-impacting or actively exploitable. Drop everything else. |
| `P1` | Important. Should be done in the current planning horizon. |
| `P2` | Nice-to-have. Done when capacity exists. |
| `P3` | Backlog. May never be done; kept for record. |

Priority can be changed any time. Each change MUST add a History entry.

## Linkage to runs

- A workflow run that executes a task references it in its step-01-task-reader handoff (via `task_id` field in frontmatter).
- The task file's `executed_by_runs:` list is appended to when a run starts working it (status → `in-progress`).
- The task's History section gets one entry per run that touched it.
- When a run closes a task (status → `done`/`failed`), step-08-landscape-updater is responsible for both updating the landscape AND updating the task file.

## Linkage to landscape

- `affects:` names landscape files the task pertains to.
- Landscape files describe state, NOT pending work. They MUST NOT contain bullet-pointed lists of issues — instead, reference task IDs:

  > Known issues: see [T-0014](../tasks/T-0014-add-host-firewall.md), [T-0007](../tasks/T-0007-stop-exposing-postgres.md).

- When a task's `closed:` becomes set with `outcome: succeeded`, the landscape file referenced in `affects:` should already reflect the new state (step-08 of the run does both updates).

## When workflow runs require a task file

- **State-changing workflows** (e.g. `infrastructure.md`, `cicd.md`): a pre-existing task file is REQUIRED. The user invokes the orchestrator naming a `task_id`, and step 01 reads that file.
- **Read-only / discovery workflows** (`state_changing: false`): no task file required. The orchestrator may optionally create observation files as it goes (e.g. discovery runs that surface new issues).

## Observation auto-promotion policy

Discovery runs that surface new issues SHOULD create one task file per issue with `kind: observation`. The bootstrap-promotion of 2026-05-12 (this commit) does this for the issues surfaced by the first two discovery runs. Subsequent discovery runs do the same for their findings.

This produces some over-creation in the short term (many observations that will never become tasks) but the cost is cheap (one small file) and the audit value is large (nothing falls through the cracks).

## Index

`_index.md` is a maintained summary — title, status, priority, age, affects. Updated whenever a task is created or transitions status. Lets you see the whole landscape of pending work at a glance without opening every file.

## Audit

The task corpus is designed to be aggregatable. Useful queries on the file contents:

- "All `done` tasks closed in the last 30 days" → grep on frontmatter
- "All `pending` P1 tasks older than 14 days" → flag for review
- "All tasks affecting `landscape/hosts/hetzner-prod.md`" → grep on `affects:`
- "Average days from `pending` → `done` for `priority: P1`" → derive from History entries
- "How many observations got promoted to tasks vs marked wontfix" → status transitions

These queries are not implemented as tooling yet; they're enabled by the schema.
