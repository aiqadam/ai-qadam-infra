---
run_id: 2026-07-11-install-fail2ban-pro-data-tech-prod-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0104-install-fail2ban-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-06-executor-infra.md
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-07-execution-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - tasks/T-0104-install-fail2ban-on-pro-data-tech-prod.md
  - tasks/_index.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - tasks/T-0104-install-fail2ban-on-pro-data-tech-prod.md
  - tasks/_index.md
next_step_hint: run complete
---

## Summary

Updated `landscape/hosts/pro-data-tech-prod.md` and `landscape/services.md` to reflect fail2ban 1.1.0-9 installed and active (sshd jail, T-0104); closed task `T-0104` as done/succeeded; updated `tasks/_index.md` to move T-0104 to done.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| `landscape/hosts/pro-data-tech-prod.md` | Frontmatter `last_verified_note`; security warning banner; security gaps table (removed row #2 — fail2ban gap resolved); `### fail2ban` section (Not installed → Installed and active); `## Native systemd services` table (added `ufw.service` + `fail2ban.service` rows); `## Open tasks` (removed T-0104 entry); `## Change log` (appended T-0104 entry) | 2026-07-11 (already set) |
| `landscape/services.md` | Frontmatter `last_verified_note`; `## pro-data-tech-prod` security warning banner (updated from "UNHARDENED" state to reflect T-0102/T-0103/T-0104 done); `ssh.service` row updated from UNHARDENED to HARDENED; added `ufw.service` row (T-0103, backfilled); added `fail2ban.service` row (T-0104); `## Change log` (appended T-0104 entry) | 2026-07-11 |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0104 | in-progress | done | succeeded |

### tasks/_index.md

- Updated: yes
- Rows changed: 1 (T-0104: `in-progress` → `done`; moved from open section to done section; T-0104 row added alongside T-0103 in the done block)

### Diff summary

**landscape/hosts/pro-data-tech-prod.md:** Frontmatter `last_verified_note` updated to reflect T-0104 as the most recent completed task. Security warning banner revised: "fail2ban **not installed** (T-0104)" gap removed; banner now correctly lists only T-0105 as the remaining open gap. Security gaps table: row #2 (fail2ban not installed / HIGH / T-0104) deleted — 3 gaps remain (#3 operator users, #4 auditd, #5 pending upgrades). `### fail2ban` section expanded from "Not installed." to full active-state description: version, service state, jail parameters, config path, currently-banned count, journal backend, and the management-IP deviation note. Native systemd services table gained two new rows: `ufw.service` (T-0103, which was missing from the table) and `fail2ban.service` (T-0104). Open tasks section: T-0104 entry removed; T-0105 remains. Change log: one new row appended for this run.

**landscape/services.md:** Frontmatter `last_verified_note` updated. The pro-data-tech-prod security warning block replaced: previously stated sshd was at cloud-init defaults, UFW inactive, no fail2ban — all factually wrong after T-0102/T-0103 (those runs' landscape-updater steps did not update `services.md`). Warning now accurately reflects current state: T-0102 done, T-0103 done, T-0104 done, T-0105 the sole remaining gap. The `ssh.service` table row updated from UNHARDENED to HARDENED with T-0102 detail. Two new rows added: `ufw.service` (backfilled from T-0103) and `fail2ban.service` (T-0104). Change log: one new row appended noting both the T-0104 fail2ban addition and the T-0102/T-0103 backfill for services.md.

**tasks/T-0104-install-fail2ban-on-pro-data-tech-prod.md:** Frontmatter: `status` → `done`, `outcome` → `succeeded`, `closed` → `2026-07-11`, `updated` → `2026-07-11`. Result section filled with all five acceptance criteria marked satisfied, the management-IP deviation noted, and links to executor + validator handoffs. History: one new entry appended.

**tasks/_index.md:** T-0104 row updated: `status` `in-progress` → `done`, `updated` `2026-07-11`. Row moved from open section to done section alongside T-0103.

### Files intentionally NOT updated

| File | Reason |
|---|---|
| `landscape/hosts/ubuntu-16gb-nbg1-1.md` | Not touched by this run; no executor changes to this host. |
| `landscape/hosts/pro-data-tech-qa.md` | Not touched by this run. |
| `landscape/cloudflare.md`, `landscape/domains.md` | No DNS/CDN changes in this run. |

## Issues / risks

- **services.md pro-data-tech-prod was stale for T-0102/T-0103:** the previous landscape-updater runs for those tasks did not update `services.md`. This run corrected the stale state as part of editing the file (ssh.service row, ufw.service row, security warning). All values written are confirmed by step-07 validator evidence.
- **Management workstation IP absent from ignoreip:** pre-acknowledged deviation carried forward. No landscape action required; noted in the host file fail2ban section and in the task Result.
