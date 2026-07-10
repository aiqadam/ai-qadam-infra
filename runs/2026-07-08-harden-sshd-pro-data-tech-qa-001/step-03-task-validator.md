---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-02-landscape-reader.md
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - tasks/_index.md
  - landscape/hosts/pro-data-tech-qa.md
  - workflows/infrastructure.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: Pass to solution-designer (step 04).
---

## Summary

Validated — T-0093 is well-formed, in-scope, not already done, and ready for the solution-designer (step 04). All 14 criteria PASS. One soft concern (`AllowGroups sshusers` sequencing relative to T-0097) is deferred to step 04.

## Details

### Validation results (14 criteria)

| # | Criterion | Verdict | Reason |
|---|---|---|---|
| 1 | Task file exists at `tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md` | PASS | File present, frontmatter parses, body intact (read in full). |
| 2 | Frontmatter: `kind: task, status: pending, priority: P1, workflow: infrastructure` | PASS | All four fields match exactly. `blocks: [T-0090-...]` and `blocked_by: []` are consistent with sibling-task graph in `tasks/_index.md`. |
| 3 | Acceptance criteria are specific, testable, cover the sshd hardening directives | PASS | Six checkbox items: (a) `40-disable-password.conf` with two directives, (b) `40-ai-dala-infra.conf` with seven hardening directives + SHA-1 MAC drop, (c) `sshd -T` post-change verification, (d) management-workstation login probe, (e) provider-key preservation in `/root/.ssh/authorized_keys`, (f) landscape file update. Each is independently verifiable; collectively they cover the full surface area. |
| 4 | Estimated blast radius = medium | PASS | Frontmatter says `estimated_blast_radius: medium`. Correct: an incorrect drop-in can lock every operator out. Mitigations are baked into the task (provider key as break-glass, sibling precedents, `sshd -T` + login probe verification). |
| 5 | Estimated reversibility = full | PASS | Frontmatter says `estimated_reversibility: full`. Correct: removing both drop-ins + `systemctl restart ssh` reverts to the pre-task cloud-init default state. |
| 6 | No pre-existing run for T-0093 in flight | PASS | `runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/` currently contains only `step-01-task-reader.md` and `step-02-landscape-reader.md` (verified via `list_dir`). No other run directory references T-0093 in its handoffs (searched `tasks/_index.md`: `executed_by_runs: []` for T-0093; only `source_runs: [2026-07-08-discovery-pro-data-tech-qa-001]` which is the discovery baseline, not an execution). |
| 7 | SSH access from management workstation to pro-data-tech-qa verified | PASS | `landscape/hosts/pro-data-tech-qa.md` `## Access`: `ssh_user: root`, `ssh_port: 22`, public IPv4 `95.46.211.230`, management-workstation key `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` (OpenSSH-format RSA-2048), 14 SSH probes succeeded during discovery. Config alias `Host pro-data-tech-qa` in `C:\Users\tvolo\.ssh\config`. Reachability confirmed; no firewall/port issue. |
| 8 | Sibling precedent on `hetzner-prod` exists (T-0007 done 2026-05-12, drop-in pattern captured) | PASS | `tasks/_index.md`: `T-0007-disable-ssh-password-auth … status: done … 2026-05-12`. `landscape/hosts/hetzner-prod.md` records the canonical drop-in contents (verbatim, 4 lines including header comment). Run `2026-05-12-disable-ssh-password-auth-001` archived. The drop-in file name (`40-disable-password.conf`) and the `first-wins` semantic are captured as a reusable pattern. |
| 9 | Discovery run captured baseline sshd config | PASS | `landscape/hosts/pro-data-tech-qa.md` `## Access` "SSH daemon config (sshd -T effective, 2026-07-08)" lists `PermitRootLogin yes`, `PasswordAuthentication yes` (via `60-cloudimg-settings.conf`), `MaxAuthTries 6`, `LoginGraceTime 120`, `X11Forwarding yes`, `ClientAliveInterval 0`. Drop-in directory contains only `60-cloudimg-settings.conf` (27 bytes, single line). Matches the criterion verbatim. |
| 10 | `AllowGroups sshusers` requires the group to exist or staged application (soft concern, deferred to step 04) | PASS (soft) | Task-reader flagged this; landscape-reader's `## Issues / risks` lists two sequencing options (A: defer `AllowGroups` until after T-0097; B: pre-create `sshusers` + add `root` to it in the same `set -e` step). Neither option blocks design — both are executable at step 06 once step 04 picks one. Not a hard blocker. |
| 11 | No other concurrent run is touching pro-data-tech-qa | PASS | `runs/` shows only the discovery run (`2026-07-08-discovery-pro-data-tech-qa-001`, complete) and this run for T-0093. The three sibling tasks `T-0094` (UFW), `T-0095` (fail2ban), `T-0097` (operator users) are explicitly `blocked_by: T-0093` in `tasks/_index.md` and have no executing runs. `T-0090` is the downstream consumer; no run is in flight for it either. No coordination conflict. |
| 12 | User said "just go" (full delegation, no approval gate blocking) | PASS | The 2026-07-08 user decision is recorded in `landscape/hosts/pro-data-tech-qa.md` `## Open questions` "Single-user vs. multi-user, and root login policy" and applies to the broader T-0093 → T-0097 → T-0090 sequence. The orchestrator's standing instruction (full delegation) means step 04 emits `NEEDS_APPROVAL` (blast radius is medium, not low), step 05 runs the approval gate, and the user can respond in one line. Not a blocker; just sets the expected step-05 behaviour. |
| 13 | Provider key preserved as break-glass; do NOT remove before T-0097 | PASS | `landscape/hosts/pro-data-tech-qa.md` explicitly records: "Provider key … comment `rsa-key-20260707` … break-glass anchor … The provider key is **not** in `sshusers`." Task body acceptance line 5 says: "Provider key (comment `rsa-key-20260707`) still in `/root/.ssh/authorized_keys` (1 line) as break-glass anchor." Both align. The T-0097 cross-reference is captured. |
| 14 | Change is scoped to one host, one service, one config-file location | PASS | Task frontmatter `affects: [landscape/hosts/pro-data-tech-qa.md]`. Task body operates exclusively on `/etc/ssh/sshd_config.d/40-disable-password.conf` and `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` on host `pro-data-tech-qa`. Workflow `infrastructure` (per `workflows/infrastructure.md` step bindings → step 06 = `executor-infra`). Cross-host blast radius is zero. |

### Workflow-specific rule check (per `workflows/infrastructure.md`)

| Rule | Verdict | Reason |
|---|---|---|
| Idempotency required | PASS (deferrable to step 04) | The plan re-applying the same drop-ins must be a no-op (re-`tee` same content → identical file). Designer must call this out at step 04. |
| Backup before destructive | PASS (deferrable to step 06) | `sshd_config` itself is not modified; only `/etc/ssh/sshd_config.d/` drop-ins are added. Drop-ins are new files (no overwrite). Backup rule is satisfied by default; if step 04 plans to *edit* an existing drop-in, the executor must snapshot first. |
| Verify in two places | PASS (deferrable to step 07) | Acceptance items (c) `sshd -T` + (d) login probe cover both (a) on-host config and (b) externally-observable SSH behavior. |

### Cross-checks against prior handoffs

- **Step 01 (task-reader) verdict:** PASS. Consistent.
- **Step 02 (landscape-reader) verdict:** PASS. Consistent. No information surfaced in step 02 that would invalidate the task.
- **Landscape freshness:** `landscape/hosts/pro-data-tech-qa.md` `last_verified: 2026-07-08` (today). No staleness.
- **`tasks/_index.md` row for T-0093:** `task | pending | P1 | landscape/hosts/pro-data-tech-qa.md | 2026-07-08`. Matches frontmatter exactly. Sibling pending rows for T-0094, T-0095, T-0097 confirm the dependency tree.

## Issues / risks

- **`AllowGroups sshusers` sequencing (medium probability, high impact; soft concern — defer to step 04).** As flagged in the landscape-reader's `## Issues / risks`: if the `sshusers` group does not exist on the host (likely, since T-0097 is downstream and unblocked-by T-0093), then `AllowGroups sshusers` will silently deny every login — including the root break-glass via the provider key, because the directive blocks root if root is not in `sshusers`. The user decision recorded in the landscape is that the provider key is the break-glass anchor governed by `PermitRootLogin`, **not** `AllowGroups`. Step 04 (solution-designer) MUST pick a sequencing strategy and call it out explicitly in the plan:
  - **Option A (safest):** apply `40-disable-password.conf` + `40-ai-dala-infra.conf` *without* `AllowGroups sshusers` first; verify `sshd -T` and login probe; defer `AllowGroups sshusers` to a follow-up edit after T-0097 creates the operator users and adds them to `sshusers`. This keeps T-0093 atomic and minimizes risk.
  - **Option B (acceptable):** include `AllowGroups sshusers` from the start but explicitly `groupadd sshusers` and `usermod -aG sshusers root` in the same `set -e` step (so root is a member of `sshusers` via the `AllowGroups` directive). Slightly more complex but keeps T-0093's acceptance checklist intact in one change.
  - **Option C (NOT recommended):** include `AllowGroups sshusers` without pre-creating the group or adding root — would lock every operator + the break-glass key out. Reject if proposed.

- **First-wins drop-in prefix.** The cloud-init drop-in on this host is `60-cloudimg-settings.conf` (not `50-cloud-init.conf` as on `hetzner-prod`). The `40-` prefix still sorts before `60-` lexicographically, so first-wins still gives the project drop-in the win. Solution-designer should reference the actual filename in the drop-in header comment.

- **No other soft concerns.** The `maxauthtries` / `login_grace_time` / `client_alive_*` directives are independent of the `AllowGroups` concern; their `sshd -T` post-verification is straightforward.

## Open questions

- None. The user decisions are baked into the task body and landscape (root-login policy via `PermitRootLogin prohibit-password` + provider key as break-glass; `sshusers` group membership for operators; no source-IP allowlist on UFW in T-0094). The `AllowGroups sshusers` sequencing question is an execution-time detail, not a blocker for step 03.