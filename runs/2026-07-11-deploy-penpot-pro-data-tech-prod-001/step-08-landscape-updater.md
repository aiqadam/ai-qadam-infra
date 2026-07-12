---
run_id: 2026-07-11-deploy-penpot-pro-data-tech-prod-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-07-11T14:30:00Z
task_id: T-0108-deploy-penpot-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-06-executor-infra.md
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-07-execution-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - tasks/T-0108-deploy-penpot-on-pro-data-tech-prod.md
  - tasks/_index.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - tasks/T-0108-deploy-penpot-on-pro-data-tech-prod.md
  - tasks/_index.md
---

## Summary

Updated `landscape/hosts/pro-data-tech-prod.md` and `landscape/services.md` to reflect Penpot 2.16 deployment; closed task `T-0108` (status → done, outcome succeeded); updated `tasks/_index.md` to move T-0108 from in-progress to done.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| `landscape/hosts/pro-data-tech-prod.md` | Frontmatter (role: unknown→penpot-prod; last_verified_note→T-0108), intro paragraph + security banner, "What runs here" section, new "## Penpot" section (containers table + all config details), Network TCP listeners table + loopback + effective exposure, Backups (updated from "no data" to Penpot volumes), Change log (appended T-0108 row) | 2026-07-11 |
| `landscape/services.md` | Frontmatter last_verified_note, pro-data-tech-prod high-level description + banner, Running Compose projects (None → penpot table), Running containers (None → 7-row table), Change log (appended T-0108 row) | 2026-07-11 |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0108 | in-progress | done | succeeded |

### Task files created (read-only runs surfacing new issues)

None.

### tasks/_index.md

- Updated: yes
- Rows changed: 2 (T-0108 removed from in-progress position; T-0108 inserted as done after T-0107)

### Diff summary

**landscape/hosts/pro-data-tech-prod.md:** Role changed from `unknown` to `penpot-prod`. Frontmatter note updated to reference T-0108. Intro paragraph updated to remove "fresh cloud image with no project-managed config / purpose TBD" language; security banner updated to note Penpot deployed. "What runs here" section updated to reference 7-container Penpot stack. New `## Penpot` section added between "What runs here" and "## Network", containing full deployment details: compose directory, env file facts, PENPOT_PUBLIC_URI, PENPOT_FLAGS, port bindings, MCP status, nginx pending note, first-admin-user note, Docker volumes, and a 7-row container table. Network section TCP listeners updated: table now has two rows (22/sshd + 9001/penpot-frontend) and loopback listeners include `127.0.0.1:1080` (penpot-mailcatch). Effective exposure paragraph updated to note port 9001 Docker bypass of UFW. Backups section "No data to back up yet" replaced with reference to the two Penpot volumes. Change log row appended for T-0108.

**landscape/services.md:** Frontmatter last_verified_note updated to T-0108. Pro-data-tech-prod section high-level description updated from "no application containers yet" to "Penpot 2.16 deployed"; banner updated accordingly. Running Compose projects section replaced from "None" to a one-row table for the `penpot` project. Running containers section replaced from "None" to a 7-row table. Change log row appended for T-0108.

**tasks/T-0108-deploy-penpot-on-pro-data-tech-prod.md:** Status → done, closed 2026-07-11, outcome succeeded. Result section filled with deployment summary, deviation note (.env owner root vs plan's tvolodi — non-security-regression), links to executor and validator handoffs, and remaining items. History entry appended.

**tasks/_index.md:** T-0108 row removed from in-progress position (was between T-0108 and T-0109); T-0108 inserted as done row after T-0107 (P1 done section, sorted by id).

### Files intentionally NOT updated

| File | Reason |
|---|---|
| `landscape/cloudflare.md` | Not touched by this run (Cloudflare DNS was T-0107, already updated) |
| `landscape/domains.md` | Not touched by this run |
| `landscape/hosts/pro-data-tech-qa.md` | Different host; not affected by this run |
| `landscape/secrets-inventory.md` | No secrets added to the inventory tracking file; .env on server is gitignored by design |

## Issues / risks

- Port 9001 is bound to `0.0.0.0` by Docker and Docker bypasses UFW's standard iptables chains. This means Penpot is reachable from the internet on port 9001 (HTTP, no TLS) until T-0109 puts nginx in front. Documented in the Network section. This is by design and tracked in T-0109.
- `.env` owner is `root` rather than `tvolodi` (validator step-07 confirmed this is non-regression — mode 600 owned by root is equally restrictive).
- Commit hash in task History is `<pending>` — will be filled in when the operator commits this repo.
