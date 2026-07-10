# ai-qadam-infra — Claude Code entry point

This is the management project for the ai-qadam infrastructure. In scope: two servers — `ubuntu-16gb-nbg1-1` (Hetzner project "ai-qadam", 46.225.239.60) and `pro-data-tech-qa` (pro-data.tech, 95.46.211.230) — plus the AiQadam application QA environment running on `pro-data-tech-qa`.

## Operating model

Work in this repo is performed by an **orchestrator + specialized subagents** pattern. The main agent (you, when invoked here) **does not perform tasks directly** — it delegates to subagents defined in `.claude/agents/`. You are the orchestrator unless explicitly invoked as a subagent.

## Read these on every fresh conversation

1. [`.claude/agents/orchestrator.md`](./.claude/agents/orchestrator.md) — your role and run lifecycle.
2. [`workflows/_common-operations.md`](./workflows/_common-operations.md) — the 8-step skeleton every run follows.
3. [`shared/handoff-format.md`](./shared/handoff-format.md) — the format every subagent uses.
4. [`shared/verdicts.md`](./shared/verdicts.md) — verdict vocabulary that drives routing.
5. [`shared/subagent-invocation.md`](./shared/subagent-invocation.md) — how you call subagents in Claude Code (use the `Agent` tool with `subagent_type: <agent-filename-stem>`).
6. [`shared/approval-protocol.md`](./shared/approval-protocol.md) — human approval gate.

## Runtime notes (Claude Code-specific)

- **Subagent invocation:** `Agent` tool, `subagent_type` = filename stem under `.claude/agents/`.
- **Todo tracking:** use `TodoWrite` to maintain the per-run todo list (one entry per workflow step).
- **File ops:** use `Read`, `Edit`, `Write`, `Grep`, `Glob`. Use `Bash` only when the workflow explicitly calls for it (i.e., inside the executor subagent's tools).
- **Working directory:** `c:\Users\tvolo\dev\ai-dala\ai-qadam-infra` (Windows). Use PowerShell syntax in `Bash` calls when invoking shell tools locally; SSH to managed hosts uses Linux shell semantics.

## Project layout

```
.claude/agents/        # canonical agent definitions — also read by VS Code Copilot
.github/               # Copilot-only files (.github/copilot-instructions.md)
shared/                # cross-cutting protocol fragments (handoff format, verdicts, approval, invocation)
workflows/             # workflow definitions + the 8-step skeleton
landscape/             # source of truth about the systems we manage (hosts, services, secrets inventory)
runs/                  # per-run audit trail (one subdir per run_id)
```

## Hard rules

- **Never edit managed systems directly from the main agent.** Always go through a workflow run.
- **Never skip the approval gate** for state-changing workflows.
- **Never put secret values in any file in this repo.** Reference by name only; values live in external storage per `landscape/secrets-inventory.md` (git-ignored — never committed).
- **Use markdown links** like `[filename.md](path/to/filename.md)` for file references (per VSCode extension conventions), not backticks.
- **No off-site/external storage.** All backups stay on the local host disk only. Never ask about or design for off-site storage targets.

## Dual-runtime note

The same agent files in `.claude/agents/` are consumed by both Claude Code and VS Code Copilot. If you edit an agent definition, both runtimes get the change automatically. The only runtime-specific file is `shared/subagent-invocation.md`, which documents the tool name to use in each runtime.
