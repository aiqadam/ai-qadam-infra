---
run_id: 2026-07-21-harden-stalwart-auto-ban-001
step: "08"
agent: landscape-updater
verdict: PASS
created: 2026-07-21T00:00:00Z
task_id: T-0121-harden-stalwart-auto-ban-against-bridge-ip
inputs_read:
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-02-landscape-reader.md
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-04-solution-designer.md
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-06-executor-infra.md
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-07-execution-validator.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md
  - tasks/_index.md
artifacts_changed:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md
  - tasks/_index.md
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-08-landscape-updater.md
next_step_hint: run complete — no further steps
---

## Summary

`landscape/hosts/pro-data-tech-prod.md` and `landscape/services.md` updated to reflect T-0121 outcomes (AllowedIp entries, nginx loopback restriction, monitoring cron, proxyTrustedNetworks finding, JMAP runbook); task `T-0121-harden-stalwart-auto-ban-against-bridge-ip.md` closed done; `tasks/_index.md` row moved from in-progress to done.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| `landscape/hosts/pro-data-tech-prod.md` | Frontmatter (`last_verified`, `last_verified_note`); "What runs here" Stalwart description; "nginx vhost (admin UI)" — Access URL replaced with restriction info + nginx headers note; NEW subsections: "AllowedIp configuration (T-0121, 2026-07-21)", "Monitoring (T-0121, 2026-07-21)", "Stalwart JMAP emergency remediation runbook", "proxyTrustedNetworks — PROXY protocol, not X-Forwarded-For"; Stalwart CLI gotchas last sub-bullet updated (T-0121 now done); nginx section Config (Stalwart mail admin UI) updated with IP restriction note; Change log row added for 2026-07-21 | 2026-07-21 |
| `landscape/services.md` | Frontmatter (`last_verified`, `last_verified_note`); `stalwart-mail-server-1` container row (purpose column updated, image tag noted as v0.16.13, AllowedIp and nginx restriction documented); nginx Status entry updated (T-0121 added, Config note updated); "Scheduled tasks" updated (root crontab no longer empty — monitoring cron documented); Change log row added for 2026-07-21 | 2026-07-21 |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0121-harden-stalwart-auto-ban-against-bridge-ip | in-progress | done | Implemented all three mitigations: (A) AllowedIp entries for 172.19.0.1 and 172.19.0.0/16 created; (B) nginx admin UI restricted to loopback; (C) proxyTrustedNetworks is PROXY protocol binary — reverted, deferred. Monitoring cron installed. JMAP technique documented. |

### Task files created (read-only runs surfacing new issues)

None — this was a state-changing run.

### tasks/_index.md

- Updated: yes
- Rows changed: 1 (T-0121 removed from in-progress section, inserted after T-0117 in done/P1 section with `status: done`, `updated: 2026-07-21`)

### Diff summary

**landscape/hosts/pro-data-tech-prod.md:** `last_verified` bumped to 2026-07-21; `last_verified_note` prepended with T-0121 completion summary. "What runs here" Stalwart sentence updated to note admin UI is loopback-restricted. In the Stalwart Mail > nginx vhost (admin UI) subsection, the old "Access URL: HTTP 200/302 confirmed from external workstation" bullet was replaced with the new IP restriction bullet (allow 127.0.0.1; deny all, external HTTP 403, SSH port-forward procedure) and a note about the X-Forwarded-For headers. Four new subsections inserted between the Dual TLS section and Stalwart CLI gotchas: "AllowedIp configuration" (table of the two JMAP IDs), "Monitoring" (script path, schedule, checks, logging), "Stalwart JMAP emergency remediation runbook" (full peer-container JMAP command examples for BlockedIp and AllowedIp operations), and "proxyTrustedNetworks" (explanation that it enables PROXY protocol binary, not X-Forwarded-For; not to be set without nginx PROXY protocol support). The last sub-bullet of the auto-ban gotcha was updated from "not yet resolved as of 2026-07-20" to a summary of the T-0121 resolution and references to the new subsections. The nginx Config (Stalwart mail admin UI) entry was updated to mention X-Forwarded-For headers and the IP restriction. A 2026-07-21 change log row was appended documenting all four mitigation outcomes.

**landscape/services.md:** `last_verified` bumped to 2026-07-21; `last_verified_note` prepended with T-0121 summary. The `stalwart-mail-server-1` container row now notes the nginx loopback restriction, the AllowedIp JMAP IDs, all three provisioned mailboxes, and the T-0121 hardening date. The nginx Status entry now includes T-0121 in the date range and notes the IP restriction in the Stalwart mail admin UI config description. The Scheduled tasks section now documents the root crontab entry for the monitoring cron. A 2026-07-21 change log row was appended.

**tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md:** Frontmatter: `status` → `done`, `closed` → `2026-07-21`, `outcome` filled with one-paragraph summary of all three mitigations. Result section filled with full outcome narrative (Mitigations A/B/C details, monitoring, JMAP documentation, deviations from plan). History entry appended: `2026-07-21: status → done`.

**tasks/_index.md:** T-0121 row removed from the in-progress block; re-inserted after T-0117 in the done/P1 block with `status: done`, `updated: 2026-07-21`.

### Files intentionally NOT updated

| File | Reason |
|---|---|
| `landscape/cloudflare.md` | No Cloudflare DNS changes were made in this run |
| `landscape/domains.md` | No domain record changes were made |
| `landscape/secrets-inventory.md` | No new secrets introduced; existing credentials (stalwart-mail-admin-password) unchanged |
| `landscape/hosts/pro-data-tech-qa.md` | QA host not touched by this run |
| `shared/app-registry.md` | No application registry changes |

## Issues / risks

- The validator noted that the Stalwart IP settings backup file (`/var/backups/stalwart-ip-settings.pre-T0121.20260721T150507Z.bak`) was not separately re-verified during step-07 (it was not re-read; the live AllowedIp/BlockedIp state was confirmed via JMAP queries instead). This is a non-issue for landscape accuracy — the live JMAP state is the authoritative source.
- `proxyTrustedNetworks` (Mitigation C) is deferred. No task file has been created for the follow-on (nginx PROXY protocol + Stalwart proxyTrustedNetworks). If the user wants to track this, a new T-NNNN observation task should be created. Not created here because no new issue was *surfaced* — the finding is documented in the landscape and the task Result section, and the user can create the follow-on task when ready.
- T-0121 History includes `Commit: <pending>` — to be updated when the user commits and pushes these landscape changes.
