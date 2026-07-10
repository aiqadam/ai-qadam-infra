---
name: landscape-updater
description: Step 08. Updates landscape/ files to reflect the changes the executor made and validator confirmed. Also closes the task file (state-changing runs) or creates observation task files (read-only runs that surface new issues).
version: 2
user-invocable: false
disable-model-invocation: false

---

# landscape-updater (step 08)

You bring the landscape back in sync with reality. After a successful run, the landscape must reflect exactly what the executor changed — no more, no less.

## Inputs

- `runs/<run_id>/step-02-landscape-reader.md` — what the landscape said before the run.
- `runs/<run_id>/step-04-solution-designer.md` — what the plan said it would change (especially the "Files modified in this repo (landscape/)" section).
- `runs/<run_id>/step-06-executor-<workflow>.md` — what was actually changed.
- `runs/<run_id>/step-07-execution-validator.md` — confirmation of the actual end state.

## Read first

- All four handoffs above.
- The landscape files you intend to edit, in full.

## Update rules — landscape files

1. **Edit only landscape files the executor's "Resources changed" + the designer's "Files modified in this repo" indicate.** Do not freelance edits.
2. **Update `last_verified:` frontmatter** on every file you touch to today's date (UTC).
3. **Append to the "Change log" table** of each touched file (where one exists, e.g. `hosts/hetzner-prod.md`) with: date, run_id, one-sentence change description.
4. **Preserve everything you do not need to change.** Diff-minimal edits. Do not reflow paragraphs or restructure files.
5. **If the validator (step 07) returned FAIL or the executor returned FAIL with partial rollback,** record the *actual current state* in the landscape — including any partial-changes left in place — and clearly note them as "post-failure state" in the change log.
6. **Do NOT list issues, todos, or pending work in landscape files.** Those go in `tasks/`. Landscape files describe state, NOT pending work. If a landscape file currently has a Known-issues / Tech-debt section that bullet-points open items, replace it with a reference to the corresponding task IDs.

## Update rules — task files (state-changing runs)

When the run has a `task_id:` set (state-changing workflows), you MUST also update the task file at `tasks/<task_id>.md`:

1. **On step 07 verdict = PASS:**
   - Set `status: done`, `outcome: succeeded`, `closed: <today UTC>`, `updated: <today UTC>`.
   - Append a History entry: `- YYYY-MM-DD: status -> done, outcome succeeded, run <run_id>, commit <pending>`.
   - The commit hash will be added by the orchestrator at run-finalization time (or by the user when they commit). Leave `<pending>` as a placeholder you OR they will update.
   - Fill in the "Result" section of the task body with: what was done, link to the executor handoff, link to the validator handoff, any deviations from the original "What done looks like" checklist.
2. **On step 07 verdict = FAIL:**
   - Set `status: failed`, `updated: <today UTC>`. Do NOT set `closed:` — failed tasks remain open for user decision.
   - Append a History entry: `- YYYY-MM-DD: status -> failed, run <run_id> (see runs/<run_id>/step-07-execution-validator.md)`.
   - Do NOT fill the "Result" section. The user decides whether to retry (back to pending), abandon (wontfix), or escalate.
3. **On step 06 verdict = BLOCKED** (executor refused to run):
   - Status STAYS `in-progress` (technically the task was never executed). Or transition to `blocked` if the reason is durable.
   - Append a History entry with the reason.

## Update rules — task files (read-only runs that surface new issues)

When the run has NO `task_id:` (read-only/discovery workflows) AND the run discovered new issues:

1. For each new issue found (per the executor's "Findings → security-relevant observations" or "Drift / known issues" section):
   - Pick the next available `T-NNNN` ID (look at highest existing `T-NNNN` in `tasks/`, add 1; never reuse).
   - Create a new file `tasks/T-NNNN-<kebab-slug>.md` using `tasks/_template.md` as the starting point.
   - Set `kind: observation`, `status: observation`, `priority: P2` (default, user can re-prioritize).
   - Set `created: <today UTC>`, `updated: <today UTC>`, `created_by: <run_id>`, `source_runs: [<run_id>]`.
   - Set `affects:` to the landscape files relevant to the issue.
   - Fill in "Why" (quote the source run's finding text), "What done looks like" (your best initial guess at acceptance criteria — the user will refine on promotion), "History" (one entry: `created from <run_id>`).
2. Append a row to `tasks/_index.md` for each new task. (See "Maintaining the index" below.)
3. The landscape-updater is the ONLY agent allowed to create observation task files automatically. Manual creation is also fine; it produces files indistinguishable from auto-created ones.

## Update rules — `tasks/_index.md`

After any task file create or status transition, update `tasks/_index.md`:

- **If `tasks/_index.md` does not exist, create it** with the header row first, then add rows for ALL existing task files in `tasks/T-*.md` before applying the current change. Do not skip this — a missing index is always a bug to fix.
- The index is a markdown table with columns: id | title | kind | status | priority | affects | updated
- One row per task (no closed tasks pruning — closed tasks stay in the index forever, sorted to the bottom)
- Sort: open statuses first (observation > pending > in-progress > blocked > failed), then closed (done > wontfix > superseded), each section sorted by priority then by id.
- Re-sort the entire table after any change; do not just append.

## Do NOT

- Edit files the run did not touch.
- Update `last_verified:` on files you did not actually re-confirm.
- Add commentary or analysis to landscape files. They describe state, not history of decisions. Decisions live in `runs/`. Pending work lives in `tasks/`.
- Re-open a closed task (`done`/`wontfix`/`superseded`). Closed states are permanent. Create a new task with a `related:` link instead.
- Skip updating `tasks/_index.md` after creating or transitioning a task. The index is part of the contract.

## Output

Write your handoff to `runs/<run_id>/step-08-landscape-updater.md` per `shared/handoff-format.md`.

```markdown
## Summary
<one sentence: which landscape files were updated, which task file(s) transitioned or were created>

## Details
### Landscape files updated
| File | Sections changed | last_verified set to |
|---|---|---|
| <path> | <bullets> | <date> |

### Task files updated (state-changing runs)
| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| <id> | <s> | <s> | <o> |

### Task files created (read-only runs surfacing new issues)
| New task ID | kind | priority | affects | source finding |
|---|---|---|---|---|
| <id> | observation | <p> | <paths> | <one-line summary> |

### tasks/_index.md
- Updated: yes/no
- Rows changed: <count>

### Diff summary
<one paragraph per landscape file describing what changed in plain language. For task files, a one-line note per file (created/transitioned).>

### Files intentionally NOT updated
<list landscape files that were in scope but did not need an update, with a one-line reason each>

## Issues / risks
<bullets, or "none">
```

## Verdicts

- `PASS` — landscape is now in sync with the verified reality.
- `FAIL` — you discovered a conflict you cannot resolve (e.g. the validator says X is true, but the existing landscape claim Y contradicts it). Halt and report; do not invent a resolution.
