---
id: T-0098-host-level-backup-strategy-for-pro-data-tech-qa
title: Host-level backup strategy for pro-data-tech-qa (local-disk only; no paid provider snapshots; no off-site targets)
kind: observation
status: observation
priority: P3
created: 2026-07-08
updated: 2026-07-08
closed:
outcome:
created_by: 2026-07-08-discovery-pro-data-tech-qa-001
source_runs:
  - 2026-07-08-discovery-pro-data-tech-qa-001
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
  - T-0001-enable-hetzner-snapshots (wontfix — sibling precedent)
  - T-0009-define-app-backup-strategy (done — application-level backup on hetzner-prod)
estimated_blast_radius: low
estimated_reversibility: full
---

# Host-level backup strategy for pro-data-tech-qa (local-disk only; no paid provider snapshots; no off-site targets)

## Why
Discovery run [`2026-07-08-discovery-pro-data-tech-qa-001`](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/) (probe N) shows no application-level backup tooling on `pro-data-tech-qa`: no `restic`, no `borg`, no `duplicity`, no `app-backup.timer`, no `pro-data.tech`-specific snapshot agent. `/var/backups/` is the stock Ubuntu directory only. The host has no databases, no Compose volumes, no application state — there is nothing to back up **yet**. Per the project-wide [Backups & storage policy](../README.md#backups--storage-policy) (declared 2026-06-27), backups stay on the local host disk; no paid provider add-ons (no pro-data.tech snapshots, no Hetzner-style off-host backup, no S3 / B2 / R2 / Google Drive / NFS). The backup strategy for this host will be defined when a role is assigned (e.g., the `ai-qadam` QA instance will likely need `pg_dump` + tar of any persistent volumes, mirroring the [hetzner-prod app-backup strategy](../landscape/hosts/hetzner-prod.md#backups) implemented by [T-0009](./T-0009-define-app-backup-strategy.md)). The sibling Hetzner snapshot precedent is [T-0001](./T-0001-enable-hetzner-snapshots.md) (status: `wontfix` — the user has decided not to pay for provider snapshots).

## What done looks like
- [ ] **Deferred.** No immediate action. The strategy will be defined when [T-0090](./T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md) assigns a role and the data flow becomes concrete. When promoted:
  - [ ] Local-disk application-level backup script (e.g., `/usr/local/bin/app-backup.sh`, mode 750 root:root).
  - [ ] Staging directory (e.g., `/var/backups/app/`, mode 700 root:root).
  - [ ] systemd timer (e.g., `app-backup.timer`, daily at 02:00 UTC, `Persistent=true`).
  - [ ] Retention: 7 days local (pruned by `find -mtime +7 -delete`).
  - [ ] Restore procedure documented and tested.
  - [ ] `landscape/hosts/pro-data-tech-qa.md` updated: `## Backups` section rewritten with the strategy; `## What needs to happen` item #7 marked done.

## Result
(empty until closed; then: what actually happened, outcome, links to executing run(s) and commits, any deviations from the plan)

## Notes
- **Why P3:** no data to back up yet; the strategy is forward-looking and depends on a role assignment. P3 is the project's "deferred / low-priority / informational" bucket.
- **Hygiene note (T-0098 dual-purpose):** this task also captures the cosmetic hygiene recommendation to rename `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` to `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa` (the file is OpenSSH-format RSA-2048, not PuTTY `.ppk`). SSH/SCP autodetect format from contents so the alias works, but the extension is a documentation/hygiene hazard. Renaming the file is a single `mv` command on the management workstation; the SSH config alias would need to be updated to match.
- **Sibling precedent for "no paid provider snapshots":** [T-0001](./T-0001-enable-hetzner-snapshots.md) (status: `wontfix`, closed 2026-05-12). The reasoning (paid add-ons scale by host count or data volume, out of scope at current data volumes) applies to pro-data.tech snapshots the same way.
- **Sibling precedent for "app-level backup on local disk":** [T-0009](./T-0009-define-app-backup-strategy.md) (status: `done`, closed 2026-05-13) on `hetzner-prod` — `pg_dump` via `docker exec`, systemd timer daily 02:00 UTC, 7-day local retention, restore procedure tested. The same shape can be applied here when the data flow is concrete.
- **Predecessor T-0098 was lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md).** This re-created file restores the observation.

## History
- 2026-07-08: created from discovery run 2026-07-08-discovery-pro-data-tech-qa-001 (status observation; deferred until role is assigned)
