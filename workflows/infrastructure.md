---
name: workflow-infrastructure
version: 1
description: Infrastructure management workflow — changes to hosts, services, networking, Cloudflare, DNS, certificates, OS packages.
extends: workflows/_common-operations.md
---

# Infrastructure workflow

Specialization of `workflows/_common-operations.md` for infrastructure changes.

## When this workflow applies

- Any change to a managed host (currently: `landscape/hosts/hetzner-prod.md`).
- Docker / Compose changes on the server.
- nginx config changes.
- Cloudflare DNS, WAF, or page-rule changes.
- TLS certificate operations.
- OS package install/upgrade, systemd unit changes, firewall rules.
- Backup configuration changes.
- New tool installation or removal on managed hosts.

## Step bindings

| Step | Agent |
|---|---|
| 01 | `task-reader` |
| 02 | `landscape-reader` |
| 03 | `task-validator` |
| 04 | `solution-designer` |
| 05 | (orchestrator-written approval) |
| 06 | **`executor-infra`** |
| 07 | `execution-validator` |
| 08 | `landscape-updater` |

## Landscape files in scope

Steps 02, 03, 04, 06, 07, 08 should read these files when relevant to the task:

- `landscape/hosts/hetzner-prod.md` — always for tasks touching that host
- `landscape/services.md` — for changes to anything running on a host
- `landscape/cloudflare.md` — for DNS, WAF, or Cloudflare config
- `landscape/domains.md` — for domain or certificate changes
- `landscape/secrets-inventory.md` — when secrets are referenced (read only the inventory, never the values)

The landscape-reader (step 02) decides which subset is relevant for the specific task and lists them in its handoff's `inputs_read`.

## Workflow-specific rules

1. **Idempotency required.** Any plan produced by `solution-designer` must be safe to re-run — failures must not leave the host in a half-configured state. If a non-idempotent change is needed, the designer must explicitly call this out in "Issues / risks" and the executor must add rollback steps.
2. **Backup before destructive changes.** Before any change that overwrites config files or deletes data, the executor must capture a backup to a path the validator can verify.
3. **Verify in two places.** The execution-validator (step 07) must verify both (a) the change on the host, and (b) the externally-observable behavior (HTTP probe, DNS lookup, etc.) wherever applicable.
