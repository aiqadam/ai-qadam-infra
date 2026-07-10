# Runs

This directory holds the audit trail for every workflow run. One subdirectory per run.

## Layout

```
runs/
├── README.md                                    # this file
├── .gitkeep
└── <run_id>/
    ├── step-01-task-reader.md
    ├── step-02-landscape-reader.md
    ├── step-03-task-validator.md
    ├── step-04-solution-designer.md
    ├── step-05-user-approval.md
    ├── step-06-executor-infra.md             # or executor-cicd, etc.
    ├── step-07-execution-validator.md
    ├── step-08-landscape-updater.md
    └── .attempts/                             # archived prior attempts (retries)
        └── step-NN-<agent>-attempt-<M>.md
```

## Run ID format

`YYYY-MM-DD-<short-slug>-NNN`

- `YYYY-MM-DD`: UTC date the run started.
- `<short-slug>`: 2–5 word kebab-case summary of the task.
- `NNN`: zero-padded counter, starts at `001`, incremented if multiple runs on the same date share a slug.

Examples:
- `2026-05-12-add-fail2ban-001`
- `2026-05-12-deploy-ai-dala-prod-001`
- `2026-05-12-rotate-cloudflare-token-001`

## Handoff file format

See [`../shared/handoff-format.md`](../shared/handoff-format.md).

## Retention

Run directories are retained by default. They are not automatically pruned. If `runs/` grows large, archive old runs externally rather than deleting in-place — the audit trail is the point.

Do not commit secrets or PII into handoff files. The landscape's `secrets-inventory.md` lists *what* secrets exist; the values live elsewhere.
