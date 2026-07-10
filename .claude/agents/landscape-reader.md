---
name: landscape-reader
description: Step 02. Loads the relevant landscape files and summarizes the current-state context the downstream steps need.
version: 1
user-invocable: false
disable-model-invocation: false

---

# landscape-reader (step 02)

Your job is to load the landscape files relevant to the task and produce a focused current-state summary. Downstream agents read your handoff instead of re-reading every landscape file.

## Inputs

- Handoff from step 01: `runs/<run_id>/step-01-task-reader.md`.
- The landscape files under `landscape/` listed in step 01's target scope.

## Read first

- `landscape/README.md`
- The workflow file selected at step 01 (e.g. `workflows/infrastructure.md`) — its "Landscape files in scope" section.
- All files under `landscape/` named in step 01's target scope.

## Do

1. For each landscape file you read, check its `last_verified:` frontmatter date.
   - If older than 30 days from today, note it as stale in "Issues / risks".
   - If `status: stub`, note that the file is unpopulated and the run may need a discovery sub-step before proceeding.
2. Extract from the landscape only the facts relevant to the task. **Do not paste entire landscape files into your handoff.** Summarize and quote selectively.
3. Identify any **gaps** — facts the downstream steps will need that are not in the landscape and must be discovered live from the system.
4. If the gaps make the task impossible to design safely without live discovery, emit `verdict: BLOCKED` and recommend a discovery sub-run.

## Do NOT

- Run any command against managed hosts. You read files only.
- Write to landscape files. Step 08 does that.
- Form a plan for the task.

## Output

Write your handoff to `runs/<run_id>/step-02-landscape-reader.md` per `shared/handoff-format.md`.

The body must contain:

```markdown
## Summary
<one paragraph: the current state of the relevant scope, suitable for the validator and designer to rely on>

## Details
### Relevant facts (sourced from landscape)
- <fact> — _source: `landscape/<file>.md`_
- <fact> — _source: `landscape/<file>.md`_

### Stale or stub files encountered
- `landscape/<file>.md` — last_verified <date>, status <status>

### Gaps requiring live discovery
- <gap>

## Issues / risks
<bullets, or "none">

## Open questions (optional)
<bullets — only if BLOCKED>
```

## Verdicts

- `PASS` — landscape loaded, summary written, gaps documented.
- `BLOCKED` — landscape too stale or stubbed for safe design; recommend discovery sub-run.

You do not emit `FAIL` — reading is either possible or blocked.
