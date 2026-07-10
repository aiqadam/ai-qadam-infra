# ai-qadam-infra — Copilot entry point

Management project for the ai-qadam infrastructure: `ubuntu-16gb-nbg1-1` (Hetzner project "ai-qadam", 46.225.239.60) and `pro-data-tech-qa` (pro-data.tech, 95.46.211.230), plus the AiQadam application QA environment on `pro-data-tech-qa`.

## Operating model

Work in this repo follows an **orchestrator + specialized subagents** pattern. When you open this workspace, the default agent is the **orchestrator** ([.claude/agents/orchestrator.md](../.claude/agents/orchestrator.md)). The orchestrator does not perform tasks itself — it delegates to specialized subagents via the `runSubagent` (or `agent`) tool.

Other Copilot agents in this workspace (task-reader, landscape-reader, task-validator, solution-designer, executor-infra, executor-cicd, execution-validator, landscape-updater) are subagent-only (`user-invocable: false`). They are invoked by the orchestrator, not directly by you.

## Read these on every fresh conversation

1. [.claude/agents/orchestrator.md](../.claude/agents/orchestrator.md) — orchestrator role and run lifecycle.
2. [workflows/_common-operations.md](../workflows/_common-operations.md) — the 8-step skeleton every run follows.
3. [shared/handoff-format.md](../shared/handoff-format.md) — handoff format used by every step.
4. [shared/verdicts.md](../shared/verdicts.md) — verdict vocabulary that drives routing.
5. [shared/subagent-invocation.md](../shared/subagent-invocation.md) — how to call subagents in Copilot (use `runSubagent`, pass the agent's `name:` frontmatter value as `agentName`).
6. [shared/approval-protocol.md](../shared/approval-protocol.md) — human approval gate.

## Runtime notes (Copilot-specific)

- **Subagent invocation:** `runSubagent` tool. `agentName` is the `name:` field of the agent's frontmatter (which matches the filename stem).
- **Agent source of truth:** `.claude/agents/*.md`. VS Code Copilot reads this directory natively — no need to duplicate files under `.github/agents/`.
- **Task tracking:** use Copilot's todo / task list to keep one entry per workflow step.
- **Working directory:** `c:\Users\tvolo\dev\ai-dala\ai-qadam-infra` on Windows. PowerShell locally; SSH to managed hosts uses Linux shell semantics.

## Project layout

```
.claude/agents/        # canonical agent definitions — read by both Copilot and Claude Code
.github/copilot-instructions.md   # this file
shared/                # cross-cutting protocol fragments
workflows/             # workflow definitions + the 8-step skeleton
landscape/             # source of truth about managed systems
runs/                  # per-run audit trail
```

## Hard rules

- **Never edit managed systems directly from the orchestrator.** Always go through a workflow run.
- **Never skip the approval gate** for state-changing workflows.
- **Never put secret values in any file in this repo.** Reference by name only.
- **Use markdown links** like `[filename.md](path/to/filename.md)` for file references, not inline code formatting.
- **No off-site/external storage.** All backups stay on the local host disk only. Never ask about or design for off-site storage targets.

## Dual-runtime note

Agent files are shared with Claude Code via `.claude/agents/`. If you edit an agent definition, both runtimes pick up the change. The only runtime-specific file is `shared/subagent-invocation.md`.
