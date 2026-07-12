---
run_id: 2026-07-11-create-operator-users-pro-data-tech-prod-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0105-create-operator-users-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-06-executor-infra.md
  - runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-07-execution-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md
  - tasks/_index.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - landscape/hosts/pro-data-tech-prod.md
  - tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md
  - tasks/_index.md
next_step_hint: run complete — orchestrator may close the run
---

## Summary

`landscape/hosts/pro-data-tech-prod.md` updated to reflect T-0105 completion (operator users provisioned, security baseline established); `tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md` transitioned to `done`; `tasks/_index.md` updated accordingly.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| `landscape/hosts/pro-data-tech-prod.md` | Frontmatter (status, last_verified_note, ssh_user); SECURITY WARNING → maintenance note; Security posture "no hardening" blockquote replaced; Access section (SSH user/host bullets, sudo bullet, local users bullet, allowgroups table row, sshusers group bullet); Security gaps table (row #3 removed); Operator users subsection (filled); Open tasks section (T-0105 reference removed); Change log (T-0105 row added) | 2026-07-11 |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0105 | in-progress | done | succeeded |

### Task files created (read-only runs surfacing new issues)

None.

### tasks/_index.md

- Updated: yes
- Rows changed: 1 (T-0105: in-progress → done; moved from open section to closed section)

### Diff summary

**`landscape/hosts/pro-data-tech-prod.md`:** Frontmatter `status` changed from `populated` to `hardened`; `ssh_user` changed from `root` to `tvolodi`; `last_verified_note` updated to reflect T-0105 completion and security baseline complete. The SECURITY WARNING banner at the top of the file was downgraded to a "Security baseline complete" maintenance note (all P1 tasks now done). The "no hardening applied" blockquote in the Security posture section was similarly replaced with a "Host is hardened" note. In the Access section: the "SSH user (root, only account)" bullet was replaced with separate primary (`tvolodi`) and break-glass (`root`) bullets; "SSH host" split into primary/break-glass; the Sudo bullet updated to list the three project-managed sudoers drop-ins; "Other local users" updated to list all four login-capable accounts; the `allowgroups` row in the sshd config table updated from "sole member: root (transitional)" to all four members; and the erroneous "root will be removed from sshusers once T-0105 provisions operator accounts" note was deleted and replaced with a confirmation that root is a permanent break-glass member. Security gaps table row #3 (No operator users / T-0105) removed — only gaps #4 (auditd) and #5 (pending upgrades) remain. Operator users subsection filled with the confirmed table of tvolodi/viktor_d/binali_r (UIDs, GIDs, homes, groups, sudoers paths, key comments). Open tasks section: T-0105 bullet removed; replaced with a note that no open P1 tasks remain. Change log: T-0105 row appended (date 2026-07-11, run ID, one-sentence summary noting all P1 security tasks complete and security baseline established).

**`tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md`:** `status` → `done`; `outcome` → `succeeded`; `closed` → `2026-07-11`; `updated` → `2026-07-11`. Result section filled with actual UIDs/keys/drop-in paths, note that root was not removed from sshusers, links to executor and validator handoffs, no deviations noted. History entry appended: `2026-07-11: status → done, outcome succeeded, run ..., commit <pending>`.

**`tasks/_index.md`:** T-0105 row moved from open (in-progress, P1) to closed (done, P1) section. Row count unchanged; sort order maintained (P1 done tasks sorted by ID within the closed P1 group).

### Files intentionally NOT updated

| File | Reason |
|---|---|
| `landscape/services.md` | T-0105 created OS-level users only; no service entries were added or changed. |
| `landscape/cloudflare.md`, `landscape/domains.md` | Unrelated to this run. |
| `landscape/hosts/pro-data-tech-qa.md` | Not touched by this run; only the prod host was changed. |
| `landscape/hosts/ubuntu-16gb-nbg1-1.md` | Not touched by this run. |

## Issues / risks

- **`commit <pending>` placeholder in T-0105 History:** the commit hash will be added once the orchestrator commits and pushes this batch of changes. This is expected per the landscape-updater rules.
- No conflicts found between validator-confirmed state and existing landscape claims. The erroneous "root will be removed from sshusers" note has been deleted as directed by both the executor and validator handoffs.
