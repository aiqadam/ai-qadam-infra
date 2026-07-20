---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-07-17T07:15:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
retry_of: null
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-06-executor-infra.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-07-execution-validator.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - tasks/_index.md
artifacts_changed:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - tasks/_index.md
next_step_hint: "T-0112 remains status: in-progress by explicit instruction — on-host provisioning (deploy user, deploybots group, per-env secrets groups, forced-command SSH keys, placeholder deploy.sh) is done and verified on both hosts, but the task's own acceptance criteria also require pasting the private/host keys into GitHub Actions repository secrets (QA_SSH_DEPLOY_KEY, PROD_SSH_DEPLOY_KEY, QA_SSH_HOST_KEY, PROD_SSH_HOST_KEY in aiqadam/ai-qadam-platform) — a manual user action outside this repo's tooling. When the user confirms that paste is complete, a follow-up landscape-updater pass (or manual edit) should flip T-0112 to status: done, outcome: succeeded, set closed:, and check off the two remaining checklist items. T-0113 (the CI/CD workflow file) is blocked on that same manual step in practice, even though tasks/_index.md doesn't encode a formal blocked_by edge for it."
---

## Summary
Updated `landscape/hosts/pro-data-tech-qa.md`, `landscape/hosts/pro-data-tech-prod.md`, and `landscape/secrets-inventory.md` to reflect the now-live `deploy` CI user, `deploybots`/`aiqadam-<env>-secrets` groups, forced-command SSH keys, and placeholder `deploy.sh` on both hosts; updated `tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md` per the run's explicit deviation instructions (stays `in-progress`, checklist partially checked, `closed`/`outcome` left blank) and re-sorted `tasks/_index.md`.

## Details
### Landscape files updated
| File | Sections changed | last_verified set to |
|---|---|---|
| [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) | frontmatter (`last_verified`, `last_verified_note`); Access § SSH daemon config + sshd drop-in description (AllowGroups now `sshusers deploybots`); Access § "Other local users" line; new "CI/CD deploy user" subsection under Access; AiQadam application stack § `.env` line (group/mode); Change log table (new row) | 2026-07-17 |
| [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) | frontmatter (`last_verified`, `last_verified_note`); Access § sshd -T table (`allowgroups` row); Access § sshd drop-in file description + new "deploybots group" bullet; Access § "Local users" line; new "CI/CD deploy user" subsection under Operator users; AiQadam Prod § `.env` line (group/mode); "Open tasks affecting this host" § removed a now-stale "No open P1 tasks" sentence (T-0112 is P1/in-progress); Change log table (new row) | 2026-07-17 |
| [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) | Added `aiqadam-qa-deploy-ssh-key` row under "AiQadam QA"; added `aiqadam-prod-deploy-ssh-key` row under "AiQadam Prod" — names + storage-location text only, no values. This file carries no `last_verified` frontmatter (confirmed by step-02's landscape-reader note — it's a live-maintained key registry, not a dated snapshot), so none was added. | n/a (no frontmatter convention on this file) |

### Task files updated (state-changing runs)
| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0112-github-actions-ssh-deploy-keys-aiqadam | in-progress | in-progress (unchanged, by explicit instruction) | outcome left blank — task not yet closed |

Checklist: checked off "keypairs generated," "public keys installed," "secrets-inventory updated," and "live SSH test verified." Left unchecked: "private keys added as GitHub Actions repository secrets" and "host public keys recorded as GitHub Actions secrets" (both annotated as manual user action, not yet done). `updated:` set to 2026-07-17. `closed:`/`outcome:` left blank. Appended a History entry documenting on-host provisioning completion (4th execution attempt, after 3 failed/rolled-back attempts) and the remaining GitHub-secrets-paste blocker.

### Task files created (read-only runs surfacing new issues)
None — this is a state-changing run with a `task_id` set, not a read-only/discovery run, so no observation tasks were created by this step.

### tasks/_index.md
- Updated: yes
- Rows changed: 1 content change (T-0112's `updated` date, 2026-07-14 → 2026-07-17); full-table re-sort performed per the file's own maintenance rule ("re-sort the entire table after any change, do not just append"). The pre-existing table had status-group violations (the two P3 `observation` rows T-0096a/T-0098 were sitting after the `pending`/`in-progress` P1 block instead of before it, per the stated sort order `observation > pending > in-progress > blocked > failed`, then closed). Corrected: all 5 open `observation` rows now precede all 3 `pending` rows, which precede the 1 `in-progress` row (T-0112), which precedes the closed `done` block. No task's `status`, `priority`, `kind`, or `affects` value was altered — only row order and T-0112's `updated` cell changed.

### Diff summary
**landscape/hosts/pro-data-tech-qa.md**: Documents that sshd's `AllowGroups` directive now reads `sshusers deploybots` (was `sshusers`), backed by a new pre-edit backup of the drop-in file. Adds a new "CI/CD deploy user" subsection describing the `deploy` system user (uid 999, shell `/bin/bash`, groups `deploy`/`docker`/`deploybots`/`aiqadam-qa-secrets`), its forced-command-restricted `authorized_keys` entry, the `deploybots` and `aiqadam-qa-secrets` groups, and the placeholder `deploy.sh` script, plus an explicit note that the GitHub Actions secrets paste for this key remains outstanding. Updates the QA app's `.env` file description to show its new group ownership (`tvolodi:aiqadam-qa-secrets`) and mode (640, was 600), with content explicitly noted as untouched. Appends one Change log row for this run.

**landscape/hosts/pro-data-tech-prod.md**: Same shape of change as QA — `AllowGroups` now `sshusers deploybots` in both the `sshd -T` table and the drop-in file description, plus a new "deploybots group" bullet; new "CI/CD deploy user" subsection (uid 999, shell `/bin/bash`, groups including `aiqadam-prod-secrets`), with an explicit note that the sshd reload and every subsequent step were gated by a Penpot no-regression check; `.env` description updated to `tvolodi:aiqadam-prod-secrets 640` (was `tvolodi:tvolodi 600`), content untouched; removed a now-inaccurate "No open P1 tasks for this host" sentence from the "Open tasks" pointer section (T-0112 is P1 and in-progress) rather than list the task itself, per the rule against enumerating pending work in landscape files; appended one Change log row.

**landscape/secrets-inventory.md**: Added two new rows, one per environment, recording the secret *names* `aiqadam-qa-deploy-ssh-key` / `aiqadam-prod-deploy-ssh-key` and their storage location as "GitHub Actions repository secrets in aiqadam/ai-qadam-platform... NOT YET PASTED — pending user action." No key value appears anywhere in the file (consistent with the file's own git-ignored, names-only convention).

**tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md**: `updated:` bumped to 2026-07-17; `status:` intentionally left at `in-progress` (not `done`) because two of the task's own six acceptance-criteria checkboxes — pasting the private keys and host keys into GitHub Actions secrets — are outside this run's executed scope and remain manual user actions. Four of six checkboxes now checked. Appended one History entry summarizing the successful 4th-attempt on-host provisioning and naming the remaining blocker.

**tasks/_index.md**: T-0112's `updated` cell bumped; whole table re-sorted to correct pre-existing status-group ordering violations (unrelated to this run's own change, but required by the file's "re-sort the entire table after any change" rule).

### Files intentionally NOT updated
- `landscape/services.md` — not listed in the designer's "Files modified in this repo (landscape/)" section or the executor's "Resources changed"; the deploy user/keys are host-access-layer changes, not new Docker services, so this file is out of scope.
- `shared/app-registry.md` — not in scope per the designer's plan; the app checkout paths, images, and containers themselves were not touched by this run (only the `.env` file's group/mode and the surrounding access layer changed).
- `landscape/cloudflare.md`, `landscape/domains.md` — no DNS or Cloudflare changes were made by this run.
- `tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md` (and T-0114/T-0115) — these tasks are blocked-by/sequenced-after T-0112 conceptually, but this run did not change their own status, scope, or content; not touched.

## Issues / risks
- None blocking. One judgment call worth flagging: `tasks/_index.md`'s pre-existing row order had two status-group violations unrelated to this run (P3 `observation` rows placed after `pending`/`in-progress` P1 rows). Per the index's own stated rule ("re-sort the entire table after any change, do not just append"), I corrected this as part of the required re-sort rather than leaving it and only touching T-0112's row. No row's `status`/`priority`/`kind`/`affects` values were changed — only order, plus T-0112's `updated` cell.
- T-0112 stays open (`in-progress`) by design per this run's explicit instructions — the landscape now accurately reflects that the on-host provisioning is real, permanent, and independently verified, while the task itself correctly signals unfinished business (the GitHub Actions secrets paste) rather than being prematurely closed.
