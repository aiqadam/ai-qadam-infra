---
id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
title: Apply Hetzner Cloud Firewall to ubuntu-16gb-nbg1-1 (project 15130993)
kind: task
status: done
priority: P1
created: 2026-06-27
updated: 2026-06-27
closed: 2026-06-27
outcome: succeeded
created_by: 2026-06-27-audit-hetzner-firewall-001
source_runs:
  - 2026-06-27-audit-hetzner-firewall-001
executed_by_runs:
  - 2026-06-27-apply-hetzner-firewall-001
affects:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
estimated_blast_radius: medium
estimated_reversibility: full
---

# Apply Hetzner Cloud Firewall to ubuntu-16gb-nbg1-1 (project 15130993)

## Why

Discovery run `2026-06-27-audit-hetzner-firewall-001` (task [T-0085](../../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md), now done) found that **Hetzner project `ai-qadam` (project_id `15130993`) contains zero Hetzner Cloud Firewalls**, leaving server `ubuntu-16gb-nbg1-1` (server_id `145542849`) exposed at the cloud layer with only host-level filtering (UFW + fail2ban) as protection.

Per the audit's documented default-exposure language:

> The server is reachable on all ports (1–65535, TCP and UDP, IPv4 and IPv6) from the public internet. Hetzner does NOT impose a default-deny at the cloud layer. Any service bound to a public IP is reachable directly, with no Hetzner-side filtering.

This compounds with the sshd posture captured in `landscape/hosts/ubuntu-16gb-nbg1-1.md` ("Access" section): `PasswordAuthentication yes` (cloud-init default), `PermitRootLogin yes`. A Cloud Firewall restricting source IPs for port 22 to the management workstation outbound IP (`178.89.57.135`) is the single highest-leverage hardening step available before independent role assignment — and mirrors the pattern already established on [hetzner-prod](../landscape/hosts/hetzner-prod.md) (`firewall-1`, id `10145783`, project 12287574).

This task was promoted from `kind: observation` on 2026-06-27 after user refinement of the acceptance criteria. The actual firewall-apply is a state-changing workflow requiring human approval at the solution-designer step (medium blast radius — applying rules to a project firewall could lock out management if scoped too tight). Per `shared/approval-protocol.md`, firewall rule changes always emit `NEEDS_APPROVAL` regardless of reversibility.

## What done looks like

Acceptance criteria for the future state-changing workflow (refined 2026-06-27 — SSH-only initial scope, mirrors prod `firewall-1` pattern, bundles server protection flags):

- [x] Pre-flight: management workstation outbound IP re-verified via `api.ipify.org` immediately before the API calls (record timestamp + IP in handoff).
- [x] Hetzner Cloud Firewall created in project `15130993` ("ai-qadam") named `ai-qadam-mgmt-ssh` (or similar user-discretion name — user may rename during approval).
- [x] Inbound rule: TCP 22 from `178.89.57.135/32` (single IPv4 address, explicit; NOT `0.0.0.0/0`).
- [x] No inbound rules for 80/443 or any other port (host has no role yet; web ports to be added later when role is assigned).
- [x] Outbound rules: Hetzner default (allow all) — no customization needed.
- [x] Firewall applied to server_id `145542849` (`ubuntu-16gb-nbg1-1`) via `applied_to` resource list.
- [x] Server protection flags enabled: `protection.delete=True`, `protection.rebuild=True` (separate API calls; both verified post-set). Server 145542849 currently has both at `False` (Hetzner defaults) per T-0085 audit.
- [x] Post-apply live SSH verification from management workstation: `Test-NetConnection 46.225.239.60 -Port 22` → True.
- [x] `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Hetzner Cloud Firewall" section updated to reflect new firewall id, name, rule list, `applied_to`, and protection flags.
- [x] `landscape/services.md` updated if applicable (no expectation of a change for this minimal SSH-only rule set, but landscape-updater should confirm).
- [x] `tasks/_index.md` re-sorted (this promotion satisfies this criterion already — T-0086 moved from observation/P1 to pending/P1).

## Result

**Outcome:** succeeded (run [`2026-06-27-apply-hetzner-firewall-001`](../../runs/2026-06-27-apply-hetzner-firewall-001/) attempt 3 PASS).

- **Firewall:** Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`) applied to server `145542849` (`ubuntu-16gb-nbg1-1`) in project 15130993 ("ai-qadam"). Single inbound rule: TCP 22 from `178.89.57.135/32` (management workstation outbound IP). Labels: `managed-by=ai-dala-infra`, `purpose=ssh-management-only`, `host=ubuntu-16gb-nbg1-1`. Created `2026-06-27T07:14:31Z` (during run attempt 1's improvised retry, reused in attempt 3 per the design's idempotency contract); applied `2026-06-27T07:30:40Z` in attempt 3.
- **Server protection flags:** `protection.delete=True`, `protection.rebuild=True` (both set to `true` from Hetzner defaults `false`/`false`). Action ID `638945111775820`; HTTP 201; synchronous terminal.
- **SSH reachability:** `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True` (both post-apply probe in executor handoff and independent re-probe in validator handoff).
- **Functional SSH:** `ssh ubuntu-16gb-nbg1-1 "..."` returns hostname, date, fail2ban `active`, ufw `active`. Lockout risk did not materialize.
- **Deviations from "What done looks like":** none material. Two body-shape bugs in the design (flat `rules` array, top-level `apply_to` field) were corrected mid-run across attempts 1–3; the corrected shape matches `hetznercloud/hcloud-go` schema exactly and was preserved in [repo memory](../../memories/repo/hetzner-firewall-api.md) for future runs.
- **Executor handoff:** [step-06-executor-infra.md](../../runs/2026-06-27-apply-hetzner-firewall-001/step-06-executor-infra.md) (verdict PASS, attempt 3).
- **Validator handoff:** [step-07-execution-validator.md](../../runs/2026-06-27-apply-hetzner-firewall-001/step-07-execution-validator.md) (verdict PASS; all four target end-states independently re-verified).
- **Landscape impact:** [`landscape/hosts/ubuntu-16gb-nbg1-1.md`](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) — "Hetzner Cloud Firewall" section replaced with the verified post-apply state (firewall id/name/rule/created timestamp/labels), UFW section augmented with the cloud-layer-firewall network-path note, "Open questions" item "Hetzner server protection flags" resolved, "What needs to happen" item #2 marked done, "Open tasks affecting this host" entry updated to done, change-log row appended. `landscape/services.md` — no change required (firewall is host-scoped, not a service).

## Notes

- **Pattern reference:** the existing Hetzner Cloud Firewall on [hetzner-prod](../landscape/hosts/hetzner-prod.md) is `firewall-1` (id `10145783`) in project `12287574` ("ai-dala"), applied to server_id `112603990`. Updated 2026-05-13 for RustDesk ports and 2026-05-26 for Gitea SSH git (port 2222). The new firewall for `ubuntu-16gb-nbg1-1` should follow the same incremental-rule pattern: start with SSH-only allow for management IP, add ports as the host's role requires (no applications are deployed yet, so a minimal SSH-only allow is the right starting point).
- **Token:** the `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` (project_id 15130993-scoped, fingerprint `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`) is the token to use for both the firewall-create POST and the firewall-apply action. Token is read+write scoped; the create operation will be a `POST /v1/firewalls` and a `POST /v1/firewalls/{id}/actions/apply_to_resources` (Hetzner API conventions).
- **Risk consideration:** if the firewall is scoped too tight (e.g., management IP omitted by mistake), the host becomes unreachable from the management workstation. Mitigation: verify outbound IP via `api.ipify.org` immediately before POSTing rules; keep the Hetzner Cloud Console open to manually delete/recreate the firewall in an emergency; remember that Hetzner Cloud Console direct console access (KVM-over-IP) is also available as a fallback.
- **Workflow shape:** the appropriate workflow is `infrastructure` (or a future dedicated `apply-hetzner-cloud-firewall` workflow). Promoted from observation to pending 2026-06-27; the actual apply will run as a state-changing workflow run.
- **Related:** [T-0085](../../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) (the discovery run that found the gap); [T-0082](../../tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md) (the parent inventory task).

## History
- 2026-06-27: created from discovery run 2026-06-27-audit-hetzner-firewall-001
- 2026-06-27: promoted from observation → pending (workflow: infrastructure) — refined scope to SSH-only + protection flags
- 2026-06-27: status → in-progress — run 2026-06-27-apply-hetzner-firewall-001 started
- 2026-06-27: status → done, outcome succeeded, run 2026-06-27-apply-hetzner-firewall-001, commit bd92f53
