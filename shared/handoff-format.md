---
name: handoff-format
version: 2
description: Canonical format for handoff files produced by every subagent step. Adds task_id linkage in v2.
---

# Handoff file format

Every subagent step produces exactly one handoff file. The orchestrator reads its YAML frontmatter to route the workflow; subsequent subagents read the markdown body for substantive context.

## File location

```
runs/<run_id>/step-<NN>-<agent-name>.md
```

Where:
- `<run_id>` — date-prefixed, hyphenated, descriptive. Example: `2026-05-12-add-fail2ban-001`. Append `-NNN` suffix if multiple runs on the same date share a topic.
- `<NN>` — two-digit zero-padded step number matching the workflow's step order.
- `<agent-name>` — kebab-case name of the producing agent, matching its file in `.claude/agents/`.

## Frontmatter schema

All fields are required unless marked optional.

```yaml
---
run_id: <string>              # matches the runs/ directory name
step: <NN>                    # two-digit step number
agent: <agent-name>           # kebab-case, matches .claude/agents/<name>.md
verdict: <verdict>            # PASS | FAIL | NEEDS_APPROVAL | BLOCKED — see shared/verdicts.md
created: <ISO-8601 UTC>       # e.g. 2026-05-12T14:32:11Z
task_id: <T-NNNN-...>         # OPTIONAL. Required for state-changing workflow runs; absent for read-only/discovery. See tasks/README.md.
inputs_read:                  # paths to handoff files (or other files) this agent read
  - <path>
  - <path>
artifacts_changed:            # files/resources changed on disk or in the system; empty list if none
  - <path-or-resource-id>
next_step_hint: <string>      # optional, advisory only — orchestrator decides routing
retry_of: <step-NN>           # optional, set only if this is a retry. Names the failed step.
---
```

## Body structure

Use these markdown sections in this order. Omit a section only when its content would be empty AND the section is marked optional below.

```markdown
## Summary
<one paragraph: what this step did and what it concluded>

## Details
<the substance — findings, plan, command output, validation results, etc.>

## Issues / risks
<bullets, or the literal word "none">

## Open questions (optional)
<bullets — anything the next agent or the user needs to resolve>
```

## Rules

1. **Never paste content from earlier handoffs into this file's body.** List them in `inputs_read` so the next agent can fetch them directly. This keeps the file bounded and avoids drift.
2. **The verdict in frontmatter is authoritative.** The body may explain *why* the verdict was chosen, but the orchestrator's routing logic looks only at the frontmatter field.
3. **`artifacts_changed` is cumulative for the step**, not the run. If your step changed nothing on disk, use an empty list.
4. **Timestamps are UTC**, in ISO-8601 with `Z` suffix.
5. **Filenames are lowercase**, hyphens only. No spaces, no underscores.
