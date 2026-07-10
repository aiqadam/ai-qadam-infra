---
id: T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
title: Audit Hetzner Cloud Firewall state for ubuntu-16gb-nbg1-1 (project ai-qadam)
kind: task
status: done
priority: P1
created: 2026-06-27
updated: 2026-06-27
closed: 2026-06-27
outcome: succeeded
created_by: orchestrator
source_runs: []
executed_by_runs:
  - 2026-06-27-audit-hetzner-firewall-001
affects:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/secrets-inventory.md
workflow: discovery-host
blocks: []
blocked_by: []
related:
  - T-0082-add-ubuntu-16gb-nbg1-1-to-inventory
  - T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1
  - T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
  - T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
estimated_blast_radius: low
estimated_reversibility: full
---

# Audit Hetzner Cloud Firewall state for ubuntu-16gb-nbg1-1 (project ai-qadam)

## Why
Discovery run `2026-06-27-discovery-host-001` confirmed: Hetzner Cloud Firewall status for the new server is unknown. The Hetzner Cloud Firewall sits in front of the Hetzner Cloud server in the network path (public internet → Cloud Firewall → host firewall (UFW) → sshd) and is the outermost layer. UFW + fail2ban are now configured (T-0083, T-0084), but the outermost layer is unchecked. Without a Hetzner API audit, we cannot confirm whether the server is exposed to arbitrary traffic or whether a Hetzner Cloud Firewall is filtering at the edge.

A per-project Hetzner API token was provisioned 2026-06-27 (`hetzner-api-token:ai-dala-infra:ai-qadam-read-write`, file `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, project_id 15130993). This task performs the first Hetzner-API-based audit using that token.

## What done looks like
- [x] Token verified against Hetzner Cloud API (`GET /v1/projects` returns project `ai-qadam` id 15130993). **Done** — substituted `GET /v1/firewalls?project_id=15130993` + `GET /v1/servers/145542849` (project-scoped token does not have access to a top-level `/v1/projects` list endpoint; both project-scoped routes returned HTTP 200 with the expected resource bodies).
- [x] `GET /v1/firewalls` for project 15130993 enumerated (firewall id, name, inbound rules, outbound rules, applied-to servers). **Done** — enumeration returned ZERO firewalls in project 15130993 ("ai-qadam"). All three URL variants (`?project_id=`, `?project=`, no filter) returned the same empty body, independently re-confirmed by the execution-validator.
- [x] `GET /v1/servers/145542849` confirms the new server and reports any Hetzner-side network configuration. **Done** — server confirmed: id=145542849, name=ubuntu-16gb-nbg1-1, status=running, type=cx43, datacenter=nbg1-dc3 (Nuremberg DC3), IPv4=46.225.239.60, IPv6=2a01:4f8:1c1c:5959::/64, private_net=[], protection.delete=False, protection.rebuild=False, backup_window="", created=2026-06-27T04:26:39Z.
- [x] Findings recorded: is there a Hetzner Cloud Firewall applied to `ubuntu-16gb-nbg1-1`? **NO.** Project 15130993 contains zero Hetzner Cloud Firewalls; server is exposed on the public internet with no cloud-layer filtering. Default-exposure language captured in `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Hetzner Cloud Firewall" section.
- [x] `landscape/hosts/ubuntu-16gb-nbg1-1.md` updated with new "Hetzner Cloud Firewall" section (no-firewall finding + default-exposure language + recommendation + cross-reference to `hetzner-prod`'s `firewall-1`). Open-question items #1 (Cloud Firewall ID) and #2 (snapshot backups) both resolved. "What needs to happen" items #2 and #7 updated to reflect audit results. Change-log row appended.
- [x] `landscape/secrets-inventory.md` updated with SHA-256 fingerprint (`fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`) for `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` in a new "Hetzner ai-qadam token — identifying metadata (safe to commit)" section. File-level `last_verified` bumped from 2026-05-26 to 2026-06-27. Housekeeping placeholder removed from inventory row.

## Result

**Outcome: succeeded — Hetzner Cloud Firewall audit complete; project 15130993 ("ai-qadam") has zero Cloud Firewalls; server `ubuntu-16gb-nbg1-1` is exposed at the cloud layer with only UFW + fail2ban protection. Recommendation to apply a Cloud Firewall recorded as the new open follow-on task [T-0086](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md).**

### Key facts

- **Token:** `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` (file `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, 64 bytes; SHA-256 fingerprint `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`). Scope: project_id `15130993` only. Verified active 2026-06-27.
- **Project 15130993 firewalls:** `GET /v1/firewalls?project_id=15130993` → HTTP 200, `{"firewalls": [], "meta": {"pagination": {…total_entries: 0}}}`. Three URL variants re-run by execution-validator with identical results.
- **Server 145542849 status:** `running` on `cx43` in `nbg1-dc3` (Nuremberg). Public IPv4 `46.225.239.60`, IPv6 `2a01:4f8:1c1c:5959::/64`. No Hetzner-side protection flags (delete/rebuild both off). No private network. Backups option NOT enabled (`backup_window=""`).
- **Default-exposure language (verbatim from `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Hetzner Cloud Firewall" section):** the server is reachable on all ports (1–65535, TCP and UDP, IPv4 and IPv6) from the public internet. Hetzner does NOT impose a default-deny at the cloud layer. The only traffic filtering on this host is at the host level: UFW (allow 22/tcp, 80/tcp, 443/tcp on both IPv4 and IPv6; deny-by-default for everything else) plus fail2ban (sshd jail, maxretry=3, bantime=600s).

### Deviations from the original probe plan

- Probe A `GET /v1/projects` was substituted with `GET /v1/firewalls?project_id=15130993` + `GET /v1/servers/145542849` because the Hetzner Cloud API does not expose a top-level project list route visible to a project-scoped token. Both project-scoped routes returned HTTP 200 with the expected resource bodies, which together constitute a stronger token-verify signal than a single resource lookup. Documented in the step-06 handoff's Issues section; if a dedicated `discovery-hetzner.md` workflow file is added in the future, the canonical Hetzner token-verify pattern should be "hit any token-scoped resource; confirm HTTP 200".

### Links

- Executor handoff: [`../runs/2026-06-27-audit-hetzner-firewall-001/step-06-executor-discovery.md`](../runs/2026-06-27-audit-hetzner-firewall-001/step-06-executor-discovery.md)
- Validator handoff: [`../runs/2026-06-27-audit-hetzner-firewall-001/step-07-execution-validator.md`](../runs/2026-06-27-audit-hetzner-firewall-001/step-07-execution-validator.md)
- Landscape-updater handoff: [`../runs/2026-06-27-audit-hetzner-firewall-001/step-08-landscape-updater.md`](../runs/2026-06-27-audit-hetzner-firewall-001/step-08-landscape-updater.md)
- Follow-on observation: [T-0086](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md)

## Notes
- This was a **read-only discovery** task. The Hetzner API token is read+write but this run used ONLY GET methods. No firewall creation/modification/rule changes.
- Workflow shape: closest existing fit is `discovery-host` (state_changing: false). Probe target was Hetzner Cloud API via PowerShell `Invoke-WebRequest` from management workstation, not SSH to the host. This was the first Hetzner-API-targeted run in this project; if future Hetzner-API runs are needed (snapshot backups audit on additional servers, server lifecycle audits, etc.), a dedicated `discovery-hetzner.md` workflow file should be added. The structural template was `workflows/discovery-cloudflare.md` with the inline substitution noted under "Deviations" above.
- Reference: analogous shape is `workflows/discovery-cloudflare.md` — same read-only API discovery pattern against Cloudflare zones.
- The audit incidentally captured two adjacent facts: Hetzner Backups option NOT enabled (`backup_window=""`) and Hetzner server protection flags are at defaults (`protection.delete=False`, `protection.rebuild=False`). Both recorded in `landscape/hosts/ubuntu-16gb-nbg1-1.md`; the Backups finding resolves Open Question #2 from the host file; the protection flags are tracked in Open questions for user decision (could be bundled with T-0086 or split into a separate task).

## History
- 2026-06-27: created
- 2026-06-27: status → in-progress — run 2026-06-27-audit-hetzner-firewall-001 started
- 2026-06-27: status → done, outcome succeeded, run 2026-06-27-audit-hetzner-firewall-001, commit 5cea156