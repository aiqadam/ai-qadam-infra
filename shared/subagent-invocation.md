---
name: subagent-invocation
version: 1
description: Runtime-specific mechanics for invoking subagents. The only file in this repo that branches by runtime.
---

# Subagent invocation

The orchestrator's logic is runtime-agnostic. When its instructions say **"invoke the `<Agent Name>` subagent with the following prompt"**, the orchestrator MUST translate that to the concrete mechanism for its current runtime, listed below.

The semantics in both runtimes are identical:
- The orchestrator passes the subagent a structured prompt (see "Prompt template" below).
- The subagent runs autonomously, reads any files listed in the prompt, performs its task, writes its handoff file under `runs/<run_id>/`, and returns a brief summary.
- The orchestrator reads the handoff file's frontmatter to determine the verdict and route the workflow accordingly.

## Runtime: Claude Code

- **Tool:** `Agent`
- **Parameter naming:** `subagent_type` is the agent's filename stem in `.claude/agents/` (e.g. `solution-designer`).
- **Prompt:** passed as the `prompt` parameter, free-form text following the template below.
- **Result:** returned as the tool result; the orchestrator must still read the handoff file from disk for the verdict.

## Runtime: VS Code Copilot

- **Tool:** `runSubagent` (the `agent` tool).
- **Parameter naming:** `agentName` is the value of the `name:` frontmatter field in the agent's `.claude/agents/<name>.md` file (Copilot reads `.claude/agents/` natively).
- **Prompt:** passed as the `prompt` parameter, free-form text following the template below.
- **Result:** returned to the parent agent; the orchestrator must still read the handoff file from disk for the verdict.

## Prompt template (identical for both runtimes)

The orchestrator constructs every subagent prompt using this exact structure:

```
Context:
- Run ID: <run_id>
- Run directory: runs/<run_id>/
- Workflow: <workflow-name>           # e.g. infrastructure, cicd
- Step: <NN> of <total>               # e.g. 04 of 08
- Your agent name: <agent-name>

=== Read these files in full before starting ===
<list only the handoff files relevant to this step, per the workflow's cascade table>
<for landscape-aware steps, also list relevant landscape/ files>

=== Step-specific input ===
<For the very first step: include the raw user request verbatim>
<For retry steps: include the path to the failed prior attempt, e.g. runs/<run_id>/.attempts/step-<NN>-<agent>-attempt-1.md, and the path to the validator's FAIL handoff>
<For approval step: include the design handoff path>

=== Task ===
<one paragraph describing what this agent should do and what its handoff file should contain>

=== Output ===
Write your handoff file to: runs/<run_id>/step-<NN>-<your-agent-name>.md
Follow the format defined in shared/handoff-format.md.
Use the verdict vocabulary defined in shared/verdicts.md.
After writing the handoff file, return a one-paragraph summary to me.
```

## Prompt construction rules

1. **Never paste prior step output into the prompt body.** Pass file paths instead — the subagent reads them with its own file tool.
2. **Always include the run ID and run directory.**
3. **List only the files relevant to this step** per the workflow's cascade table. Avoid dumping the entire `runs/<run_id>/` listing.
4. **First step:** include the user's raw request verbatim, no paraphrasing.
5. **Retry step:** include the prior failed attempt path AND the validator's FAIL handoff so the agent understands what to fix.
6. **Approval step:** the orchestrator typically writes this file itself after presenting the design to the user and receiving sign-off — it does not invoke a "user-approval" subagent.

## After subagent returns

1. Read `runs/<run_id>/step-<NN>-<agent-name>.md`.
2. Parse the `verdict:` field from frontmatter.
3. Route per `shared/verdicts.md`.
4. Update the workflow's TODO/state to reflect step completion or retry.
