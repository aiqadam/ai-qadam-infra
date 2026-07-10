---
name: workflow-audit-repo
version: 1
description: Read-only security audit of the ai-dala-infra repo itself. Scans for secrets-in-repo, unsafe permissions in .claude/settings, agent protocol gaps, fragile references, and external commands/URLs embedded in the corpus. Surfaces findings as observation task files. Touches NO external systems.
extends: workflows/_common-operations.md
state_changing: false
skip_design_step: true
---

# Audit: repo

Read-only security audit of the `ai-dala-infra` repository. **No host probes, no API calls, no external systems touched.** All probes are local Read/Grep/Glob over the working tree.

## Step bindings

| Step | Agent | Status |
|---|---|---|
| 01 | `task-reader` | required |
| 02 | `landscape-reader` | required (reads landscape for context — what the corpus claims is true vs. what files actually contain) |
| 03 | `task-validator` | required |
| 04 | `solution-designer` | **skipped** (`skip_design_step: true`) — probe list lives in this file |
| 05 | user-approval | **skipped** (`state_changing: false`) |
| 06 | **`executor-discovery`** | required |
| 07 | `execution-validator` | required |
| 08 | `landscape-updater` | required (creates observation task files; no landscape body edits beyond Change log on `landscape/README.md`) |

## Landscape files in scope

Read (for cross-reference, not modification):
- `landscape/secrets-inventory.md` — to verify referenced secret names exist in inventory
- `landscape/README.md` — Change log target for the audit run
- `tasks/_index.md` — to avoid duplicating already-open observations

Write (at step 08):
- `tasks/T-NNNN-<slug>.md` — one observation task per material finding
- `tasks/_index.md` — index update
- `landscape/README.md` — Change log row recording the audit run only

## Probe checklist for executor-discovery

The executor runs each probe using Read/Grep/Glob on the local working tree. All probes are scoped to the repo root `c:\Users\tvolo\dev\ai-dala\ai-dala-infra`.

### A. Pre-flight
```
- Confirm working directory is the repo root (presence of CLAUDE.md, workflows/, landscape/, .claude/)
- Capture git status (working tree clean? untracked files?) and current branch/commit
- Verify .gitignore exists and inspect what it excludes
```

### B. Secret-pattern scan
Grep the entire tree (excluding `.git/`, `runs/.attempts/`, anything in `.gitignore`) for these patterns. The executor records **file + line number + match length** but NEVER copies the matched substring into the handoff if the surrounding context suggests a real secret value.

Patterns:
- High-entropy hex strings: `[a-fA-F0-9]{32,}` (token-shaped)
- Base64-like blobs: `[A-Za-z0-9+/]{40,}={0,2}` (key-shaped)
- AWS-style: `AKIA[0-9A-Z]{16}`, `aws_secret_access_key`
- Generic: `(api[_-]?key|secret|password|token|passwd|pwd)\s*[:=]\s*['"][^'"]{8,}['"]`
- PEM blocks: `-----BEGIN (RSA |EC |OPENSSH |DSA |)?PRIVATE KEY-----`
- SSH keys: `ssh-(rsa|ed25519|dss|ecdsa) AAAA[A-Za-z0-9+/=]{50,}` (note: public keys are safe; record but don't escalate)
- Cloudflare tokens: `[a-zA-Z0-9_-]{40}` near "cloudflare" / "Bearer"
- GitHub PATs: `gh[posr]_[A-Za-z0-9]{36}`, `github_pat_[A-Za-z0-9_]{82}`

For each hit, classify:
- **Confirmed safe** — explicitly a public key, a fingerprint, a hash, a token *name* not value, or text in a doc explaining "this is what a secret looks like"
- **Suspect** — looks like a real value; needs human review
- **False positive** — pattern matched but context shows not a secret

### C. Reference-secret-name validation
```
Grep landscape/ workflows/ shared/ .claude/agents/ tasks/ for references to secret names of the form:
  - <type>:<scope>:<name> (e.g. cloudflare-api-token:ai-dala-infra:read-only)
  - file paths like C:\Users\tvolo\.config\ai-dala-infra\*.token
  - file paths like C:\Users\tvolo\.ssh\ai-dala-infra*

For each reference, verify the corresponding row exists in landscape/secrets-inventory.md.
Findings:
  - Reference but no inventory row → broken reference
  - Inventory row but no references → unused / dead secret (informational)
```

### D. `.claude/agents/` integrity
```
For each .claude/agents/<name>.md:
  - Confirm YAML frontmatter parses (name, description present)
  - Confirm any `agents:` list members exist as files in the same directory
  - For executor-* agents:
      - read instructions for the documented approval-gate check (per shared/approval-protocol.md "defense in depth")
      - flag any executor whose instructions DON'T require checking step-NN-user-approval.md
  - For all agents: flag any that claim to read landscape/ files that don't exist
```

### E. `.claude/settings*.json` permission scope
```
If .claude/settings.json or .claude/settings.local.json or ~/.claude/settings.json exist:
  - List allowed Bash patterns
  - Flag overly broad allows (e.g. "Bash(*)" without restriction, "WebFetch(*)")
  - Flag any hooks that run shell commands on every prompt (audit for safety)
If none exist: record as informational; default permission prompt applies.
```

### F. Workflow / agent / shared cross-reference integrity
```
- For each markdown link `[text](path)` in workflows/, shared/, .claude/agents/, CLAUDE.md, README.md:
  - Verify the target path resolves
  - Flag broken links

- For each workflow file's `extends:` and `executor` reference:
  - Confirm the referenced agent exists in .claude/agents/

- For each agent's `agents:` list:
  - Confirm every listed agent exists
```

### G. tasks/ audit hygiene
```
- Confirm every T-NNNN file referenced in tasks/_index.md exists
- Confirm every T-NNNN file on disk is listed in tasks/_index.md
- For each open (observation/pending/in-progress/blocked) task:
  - Confirm it has the required body sections (Why, What done looks like, History)
  - Confirm History has at least one entry
- Flag tasks where `affects:` names a landscape file that doesn't exist
```

### H. runs/ audit hygiene
```
- For each runs/<run_id>/ directory:
  - Confirm step-NN-*.md files are in numeric order
  - For state-changing runs: confirm step-05-user-approval.md exists (or the workflow declares state_changing: false)
  - Confirm referenced task_id (in step-01 handoffs) exists in tasks/
- Flag any "abandoned" runs (no step-08, no closing summary)
```

### I. Embedded external commands and URLs
```
- Grep workflows/, .claude/agents/, shared/ for:
  - URLs (http://, https://) — confirm they reference legitimate services (api.cloudflare.com, etc.) and don't include credentials in the URL
  - SSH targets (ssh <host>) — confirm hosts referenced are documented in landscape/hosts/
  - File paths on the management workstation (C:\Users\tvolo\...) — confirm referenced files are documented in secrets-inventory.md or landscape/

- Flag any URL with `?token=` or `?key=` inline
- Flag any command that performs writes to managed systems from a workflow declared state_changing: false
```

### J. CLAUDE.md and project-level instructions
```
- Confirm CLAUDE.md exists
- Confirm "Hard rules" section is present and unchanged in spirit (no secret values, no editing managed systems directly)
- Look for any instruction that contradicts shared/approval-protocol.md or shared/handoff-format.md
```

### K. Git hygiene
```
- Confirm .gitignore excludes:
  - runs/<run_id>/ output that contains tokens? (NO — handoffs MUST not contain values; but verify)
  - C:\Users\tvolo\.config\* references are NOT excluded (they're outside the repo)
  - Any .env files
- Run git log on landscape/secrets-inventory.md and check that no historical revision added a secret value
  (use: git log -p -- landscape/secrets-inventory.md | grep -iE 'token|key|secret' | head -50)
- Run git log --all --full-history --source for any file matching pattern *secret*, *token*, *key*, *.env
  (informational: confirm no historical addition of secrets)
- Confirm git remote URLs (if any) don't embed credentials
```

### L. Dependency / supply-chain (light)
```
- List any package manifests in the repo (package.json, requirements.txt, Cargo.toml, go.mod, pyproject.toml)
- If any: list direct deps (do not install or run them)
- If none: record as "no application code in this repo — meta-config only" (expected for an infra-meta repo)
```

## Validation criteria for step 07 (execution-validator)

The execution-validator MUST:

1. Confirm probes A–L all ran and produced an output entry.
2. For each Suspect hit in probe B, attempt to classify (with the executor's quoted context excerpt — minimum 10 chars surrounding, but never the secret value itself) as actually-secret vs. false-positive.
3. Confirm any "Suspect actually-secret" hit is reported P0 in Findings.
4. For each broken reference, broken link, or integrity gap in probes C/D/F/G/H/J/K, assign severity:
   - **P0**: actual secret value committed to the repo; instruction contradiction that lets the executor bypass approval
   - **P1**: missing approval-gate check in an executor; broken reference to a token file path; mismatch between index and tasks/ on disk
   - **P2**: broken markdown link; stale orphaned task file; unused secret-inventory row
   - **Informational**: cosmetic typos, formatting drift
5. Cross-check `tasks/_index.md` to avoid duplicating already-open observations.
6. Produce a Findings table: `(probe, finding, severity, action: new-task | already-tracked T-NNNN | no-action)`.

## Landscape-update guidance for step 08

The landscape-updater MUST:

1. For each Finding marked `action: new-task`, create one observation task file with:
   - `kind: observation`, `status: observation`
   - `priority: <as judged>`
   - `created_by: <run_id>`, `source_runs: [<run_id>]`
   - `affects:` — names the relevant repo path (e.g. `.claude/agents/executor-cicd.md`, `landscape/secrets-inventory.md`)
   - `workflow: manual` (most repo audit findings are addressed by direct edit, not by a state-changing workflow)
2. Append new task IDs to `tasks/_index.md` (correct sorted position).
3. Update ONLY two things in `landscape/README.md`:
   - The frontmatter `last_verified:` date (if present).
   - One Change log row: `<run_id> | audit-repo run; N findings (N1 P0, …); see [T-NNNN, ...]`. If `landscape/README.md` doesn't have a Change log section, append findings as a one-line summary at the end of the file body rather than restructuring.
4. Do NOT modify any other landscape file.

## Findings policy

| Severity | Examples | Action |
|---|---|---|
| P0 | actual secret value committed in any tracked file; agent instructions that let executor bypass approval gate | New observation task, P0. Raise in closing summary. |
| P1 | executor agent lacks the approval-gate check from shared/approval-protocol.md; missing inventory row for a referenced token file; broken cross-reference between agent file and its `agents:` list | New observation task, P1. |
| P2 | broken markdown link; stale task file not in index; .claude/settings.json with overly broad permissions | New observation task, P2. |
| Informational | formatting drift, cosmetic typos, dead inventory rows for retired secrets | Step 07 handoff only. No task. |
| Already tracked | Finding overlaps with an open T-NNNN | Note + reference T-NNNN. No duplicate. |
