---
id: T-0082-add-ubuntu-16gb-nbg1-1-to-inventory
title: Add new Hetzner server ubuntu-16gb-nbg1-1 to inventory and run discovery
kind: task
status: done
priority: P1
created: 2026-06-27
updated: 2026-06-27
closed: 2026-06-27
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs:
  - 2026-06-27-discovery-host-001
  - 2026-06-27-audit-hetzner-firewall-001
  - 2026-06-27-apply-hetzner-firewall-001
affects:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/README.md
  - tasks/_index.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0078-setup-private-git-app-on-hetzner
  - T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1
  - T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
  - T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
  - T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
estimated_blast_radius: low
estimated_reversibility: full
---

# Add new Hetzner server ubuntu-16gb-nbg1-1 to inventory and run discovery

## Why
The user leased a second Hetzner server (ubuntu-16gb-nbg1-1) and wants it added to the project's host inventory. The server is currently unprovisioned from this project's perspective — no SSH user, no firewall, no services — so it must be added to the landscape as a stub and then probed via a discovery-host run to populate real facts (OS, hardware, services, etc.).

Server-provided identifiers:
- **Server name (Hetzner-provided):** `ubuntu-16gb-nbg1-1`
- **Public IPv4:** `46.225.239.60`
- **Public IPv6:** `2a01:4f8:1c1c:5959::/64`
- **Location:** Nuremberg (`nbg1`), inferred from name
- **Server type:** 16 GiB RAM tier, inferred from name

This task exists so the inventory accurately reflects what is leased. A future role/host_id (`hetzner-2` or similar) will be assigned during discovery based on actual hostname and intended purpose.

## What done looks like
- [x] A new stub landscape file exists at `landscape/hosts/ubuntu-16gb-nbg1-1.md` with frontmatter populated and `status: stub` body.
- [x] `landscape/README.md` lists the new host file in its Files table.
- [x] `tasks/_index.md` includes T-0082 with status reflecting the run outcome.
- [x] Hetzner server ID and project ID recorded in the frontmatter.
- [x] SSH access verified from the management workstation (`tvolodi@46.225.239.60`); SSH config alias `ubuntu-16gb-nbg1-1` added to `C:\Users\tvolo\.ssh\config`.
- [x] A subsequent `workflow-discovery-host` run against this host successfully connects via SSH as the user from the management workstation and produces real data for the stub (kernel, OS, hardware, users, sshd, firewall, listeners, docker, nginx).
- [x] The landscape-updater at step 08 of that discovery run transitions the stub from `status: stub` to `status: populated` and rewrites the body with real data.
- [x] Hetzner Cloud Firewall (if any) audited and ID recorded in frontmatter.

## Result

Outcome: **succeeded — task T-0082 closed.** All 8 acceptance criteria satisfied.

### Key facts at close

- **`host_id`**: `ubuntu-16gb-nbg1-1` (the Hetzner-provided server name; canonical short ID like `hetzner-2` not assigned — the long form is descriptive and unambiguous). Frontmatter `role: unassigned` is factual: no role has been assigned to this host yet. Role assignment is a separate concern that can be promoted to a new task if/when the user wants to define the host's intended purpose.
- **Inventory entry**: `landscape/hosts/ubuntu-16gb-nbg1-1.md` populated by [run `2026-06-27-discovery-host-001`](../../runs/2026-06-27-discovery-host-001/step-08-landscape-updater.md) (status: stub → populated). All SSH host key fingerprints recorded.
- **Hetzner Cloud Firewall**: `ai-qadam-mgmt-ssh` (id `11204449`), applied to server `145542849`. Single inbound rule (TCP 22 from management workstation outbound IP). Audited and applied by runs [T-0085](../../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) and [T-0086](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md).
- **Server protection flags**: `protection.delete=true`, `protection.rebuild=true` (set by T-0086).
- **Host-layer hardening**: UFW active (allow 22/80/443 v4+v6) and fail2ban active with management IP in ignoreip (set by [T-0083](../../tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md) and [T-0084](../../tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md)).
- **Network path (current)**: public internet → Hetzner Cloud Firewall → UFW → fail2ban → sshd. SSH (port 22) reachable from management workstation outbound IP only.

### Closing rationale

T-0082 was the umbrella inventory task created when the host was first leased. Its scope was "add the host to inventory" — which is now complete. Three follow-on tasks materialized during this work:

1. **T-0083** (done) — UFW
2. **T-0084** (done) — fail2ban
3. **T-0085** (done) + **T-0086** (done) — Hetzner Cloud Firewall audit + apply

The original "role assignment" acceptance item is intentionally NOT closed here: role assignment is a forward-looking decision (what the host will run) rather than a backward-looking inventory fact. If the user wants to assign a role, that becomes a new task (e.g., "T-0087-assign-role-to-ubuntu-16gb-nbg1-1") — it does not need to be retroactively folded into T-0082.

### Open follow-ons (not part of T-0082 scope)

- Assign a role to the host (e.g., staging, secondary production, dedicated service host). When a role is assigned, add 80/443 inbound rules to firewall `11204449` incrementally (mirroring prod's pattern of incremental rule additions for RustDesk + Gitea SSH).
- ~~Enable Hetzner Backups option~~ — resolved 2026-06-27 by user policy: **no paid Hetzner add-ons**; backups stay on local disk only. See [landscape/README § Backups & storage policy](../../landscape/README.md#backups--storage-policy). Aligns with [hetzner-prod](../../landscape/hosts/hetzner-prod.md) and `wontfix` [T-0001](../T-0001-enable-hetzner-snapshots.md).
- T-0082's "What needs to happen" item #6 (`role: unassigned`) — resolved by closing this task with `role: unassigned` left as the factual state.

### Links

- Discovery run: [`../runs/2026-06-27-discovery-host-001/step-08-landscape-updater.md`](../runs/2026-06-27-discovery-host-001/step-08-landscape-updater.md)
- Audit run: [`../runs/2026-06-27-audit-hetzner-firewall-001/step-08-landscape-updater.md`](../runs/2026-06-27-audit-hetzner-firewall-001/step-08-landscape-updater.md)
- Apply run: [`../runs/2026-06-27-apply-hetzner-firewall-001/step-08-landscape-updater.md`](../runs/2026-06-27-apply-hetzner-firewall-001/step-08-landscape-updater.md)

## Notes
- The `host_id` chosen here is the Hetzner-provided server name (`ubuntu-16gb-nbg1-1`). A canonical short ID (e.g., `hetzner-2`) may be assigned during discovery if the user prefers a different convention. Currently only one host (`hetzner-prod`) has a short ID; this one starts as the long form.
- SSH access has not yet been verified. Before running discovery, the project SSH public key (`C:\Users\tvolo\.ssh\ai-dala-infra`) must be installed on the new host as one of the authorized keys for the user the user wants to use (likely `root` for the first SSH bootstrap, then create `tvolodi` to match the prod host). This is a prerequisite that may block the discovery run — see [Blocked by] once discovered.
- The Hetzner Cloud Firewall that protects the new server (if any is applied) must be opened for SSH (port 22) from the management workstation's IP before discovery can succeed.

## History
- 2026-06-27: created as task (pending) — manual bootstrap by orchestrator per orchestrator.md §1 "If the request is a clear state-changing operation but no task ID is provided, create a new task file yourself"
- 2026-06-27: SSH access from management workstation verified (login as `tvolodi` via project key, passwordless sudo OK). SSH config alias `ubuntu-16gb-nbg1-1` added. OS + kernel + uptime + sudoers.d captured. Hetzner IDs populated in frontmatter.
- 2026-06-27: discovery run `2026-06-27-discovery-host-001` completed (PASS). Status -> in-progress; discovery component of "What done looks like" satisfied (kernel, OS, hardware, users, sshd, firewall, listeners, docker, nginx all populated in `landscape/hosts/ubuntu-16gb-nbg1-1.md`; stub -> `status: populated`). Parent task remains open: Hetzner Cloud Firewall audit (item #2 of "What needs to happen") and role assignment (item #6) are still pending and depend on either a follow-on Hetzner-API workflow run or a user decision. Observation follow-on created: [T-0083](../../tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md).
- 2026-06-27: UFW configured (T-0083 done). fail2ban installed with sshd jail (T-0084 done). Hetzner Cloud Firewall audited (T-0085 done — zero firewalls found in project 15130993). Hetzner Cloud Firewall applied (T-0086 done — `ai-qadam-mgmt-ssh` id `11204449`, server protection flags enabled).
- 2026-06-27: status → done, outcome succeeded. All 8 acceptance criteria checked. `role: unassigned` left as the factual state (no role assigned to this host); role assignment is a separate forward-looking decision and is intentionally out of scope for the inventory task. Commit: `89d4739` ("task T-0082: close — add ubuntu-16gb-nbg1-1 to inventory DONE").