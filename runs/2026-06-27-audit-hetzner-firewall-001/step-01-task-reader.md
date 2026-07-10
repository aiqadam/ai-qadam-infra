---
run_id: 2026-06-27-audit-hetzner-firewall-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - tasks/README.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - workflows/_common-operations.md
  - workflows/discovery-host.md
  - workflows/discovery-cloudflare.md
  - runs/2026-06-27-discovery-host-001/step-01-task-reader.md
  - runs/2026-05-12-discovery-cloudflare-001/step-01-task-reader.md
artifacts_changed: []
next_step_hint: Pass to landscape-reader (step 02) with workflow=discovery-host. The probe target is the Hetzner Cloud API (NOT SSH to the host) — first run of its kind; executor-discovery should treat `workflows/discovery-cloudflare.md` as the structural template, substituting Hetzner endpoints and the ai-qadam token.
---

## Summary

Task T-0085 is a read-only Hetzner Cloud Firewall audit for server `ubuntu-16gb-nbg1-1` (Hetzner project `ai-qadam`, project_id `15130993`, server_id `145542849`) via the Hetzner Cloud API. It maps onto the `discovery-host` workflow (frontmatter `state_changing: false`, `skip_design_step: true`) with steps 04 and 05 skipped per `workflows/_common-operations.md`. This is the first Hetzner-API-targeted discovery run in the project; the closest existing analog is `workflows/discovery-cloudflare.md`.

## Details

- **Workflow:** `discovery-host` (read-only; `state_changing: false`, `skip_design_step: true` — steps 04 and 05 are skipped; 01–03 and 06–08 run).
- **Probe target:** Hetzner Cloud API (NOT SSH to the host). All probes are HTTP GET against `https://api.hetzner.cloud/v1/...` from the management workstation. The closest structural template is `workflows/discovery-cloudflare.md` (Cloudflare API discovery); the executor-discovery subagent should mirror its shape (token verify → resource enumeration → per-resource detail) but substitute Hetzner endpoints and the ai-qadam token.
- **Why (quoted verbatim from T-0085):**

  > Discovery run `2026-06-27-discovery-host-001` confirmed: Hetzner Cloud Firewall status for the new server is unknown. The Hetzner Cloud Firewall sits in front of the Hetzner Cloud server in the network path (public internet → Cloud Firewall → host firewall (UFW) → sshd) and is the outermost layer. UFW + fail2ban are now configured (T-0083, T-0084), but the outermost layer is unchecked. Without a Hetzner API audit, we cannot confirm whether the server is exposed to arbitrary traffic or whether a Hetzner Cloud Firewall is filtering at the edge.
  >
  > A per-project Hetzner API token was provisioned 2026-06-27 (`hetzner-api-token:ai-dala-infra:ai-qadam-read-write`, file `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, project_id 15130993). This task performs the first Hetzner-API-based audit using that token.

- **Target scope (read & write):**
  - Read: `landscape/hosts/ubuntu-16gb-nbg1-1.md` — current host stub/populated file. The Hetzner Cloud Firewall section is already noted as "status unknown" and listed in Open Questions item #2 (per the file's existing content from run `2026-06-27-discovery-host-001`).
  - Read: `landscape/secrets-inventory.md` — for the per-project Hetzner token metadata (SHA-256 fingerprint, scope). Entry already exists; only "to be added on next housekeeping pass" placeholder for SHA-256 fingerprint is to be filled by step 08.
  - Write (at step 08): `landscape/hosts/ubuntu-16gb-nbg1-1.md` — add a "Hetzner Cloud Firewall" section (firewall id, name, inbound rules, outbound rules, applied-to confirmation). Resolve Open Questions item #2.
  - Write (at step 08, conditional): `landscape/secrets-inventory.md` — fill in the SHA-256 fingerprint + scope metadata for `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` if missing.
- **Probe target identifiers (for downstream handoffs — server-side facts already known, executor should verify via API not assume):**
  - Hetzner project name: `ai-qadam`
  - Hetzner project_id: `15130993`
  - Server name: `ubuntu-16gb-nbg1-1`
  - Server_id: `145542849`
  - Server type: `CX43`
  - Public IPv4: `46.225.239.60`
  - Public IPv6 prefix: `2a01:4f8:1c1c:5959::/64`
  - Hetzner project location: Nuremberg (`nbg1`), inferred from server name — should be confirmed via API.
- **Acceptance criteria (translated from "What done looks like" checkboxes — these are the validator's step 07 checks):**
  1. Token verified against Hetzner Cloud API (`GET /v1/projects` returns project `ai-qadam` id 15130993).
  2. `GET /v1/firewalls` for project 15130993 enumerated (firewall id, name, inbound rules, outbound rules, applied-to servers).
  3. `GET /v1/servers/145542849` confirms the new server and reports any Hetzner-side network configuration.
  4. Findings recorded: is there a Hetzner Cloud Firewall applied to `ubuntu-16gb-nbg1-1`? If yes, what rules? If no, what is the default exposure?
  5. `landscape/hosts/ubuntu-16gb-nbg1-1.md` updated with Hetzner Cloud Firewall section (firewall id, rules, applied-to confirmation). Open-question item #2 from discovery resolved.
  6. `landscape/secrets-inventory.md` updated if the Hetzner token metadata section needs an entry (SHA-256 fingerprint, scope, etc.).
- **Probe checklist (suggested for step 06 — derived from acceptance criteria; step 06 may refine but should not deviate materially):**
  - **A. Token verify (sanity):** `GET /v1/projects` (scoped to project 15130993) — confirms the ai-qadam read+write token is valid and returns the project resource. Analog of `workflows/discovery-cloudflare.md` probe A (`/user/tokens/verify`). If this fails, emit `BLOCKED` from step 06.
  - **B. Firewalls enumerated:** `GET /v1/firewalls?project_id=15130993` (or filter equivalent) — list all firewalls in project `ai-qadam`. For each firewall, capture id, name, inbound rules (with source IPs/CIDRs, ports, protocols), outbound rules, applied `server_id`s. (Hetzner Cloud API exposes `applied_to` per firewall; the executor should specifically check whether server_id `145542849` is in any firewall's applied-to list.)
  - **C. Server confirmation:** `GET /v1/servers/145542849` — confirms the server exists in project `ai-qadam` and reports Hetzner-side network configuration: public IPv4/IPv6, private network attachments, server status, datacenter. Cross-reference server_id in this response against firewall B's `applied_to` to confirm whether the server is covered by a Hetzner Cloud Firewall.
  - **D. Findings synthesis:** the executor must produce a single "findings summary" subsection in step-06 that explicitly answers: "Is there a Hetzner Cloud Firewall applied to `ubuntu-16gb-nbg1-1`? If yes, list rule summary. If no, describe default exposure (Hetzner Cloud servers with no Cloud Firewall applied are reachable on all ports from the public internet unless blocked at the host firewall layer)."
- **Constraints stated by user / task:**
  - Read-only. The Hetzner API token is read+write but this run uses ONLY HTTP GET methods (no POST/PUT/PATCH/DELETE on `/firewalls` or `/servers`). The executor must refuse and emit `BLOCKED` from step 06 if the plan asks for any non-GET method (analogous to `executor-discovery` rule 4 for Cloudflare).
  - Token never written into any handoff file. Referenced by name `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`; read from `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` at command time, passed via `-H "Authorization: Bearer $HETZNERTOK"`, never echoed or logged (analogous to `workflows/discovery-cloudflare.md` rule).
  - Preserve Hetzner-provided identifiers in the landscape update: server name `ubuntu-16gb-nbg1-1`, server_id `145542849`, project_id `15130993`, project name `ai-qadam`.
  - The 6 acceptance criteria are the step-07 validator's checks (per `tasks/README.md` linkage rule and `workflows/_common-operations.md` cascade table).
  - Open-question item #2 from `landscape/hosts/ubuntu-16gb-nbg1-1.md` (Hetzner Cloud Firewall ID) is the primary deliverable. Resolution = write a "Hetzner Cloud Firewall" section into that file with firewall id (or "none applied" + default-exposure note).
- **Related tasks (per task frontmatter `related:`):**
  - T-0082 — Add new Hetzner server ubuntu-16gb-nbg1-1 to inventory and run discovery. Parent inventory task; its "What done looks like" item #2 ("Hetzner Cloud Firewall (if any) audited and ID recorded in frontmatter") is what this run resolves.
  - T-0083 — Configure UFW on ubuntu-16gb-nbg1-1. **DONE** (per run `2026-06-27-configure-ufw-001`). UFW is the host-level firewall (innermost layer). This audit covers the Cloud-level firewall (outermost layer).
  - T-0084 — Install fail2ban on ubuntu-16gb-nbg1-1. **DONE** (per run `2026-06-27-install-fail2ban-001`). fail2ban is host-level intrusion prevention.
- **Estimated blast radius / reversibility:** low / full (per task frontmatter). Confirmed — read-only API calls, no state changes possible from this run.
- **Information gaps for downstream steps:**
  - **Landscape-reader (step 02):** confirm the current contents of `landscape/hosts/ubuntu-16gb-nbg1-1.md` (already populated by run `2026-06-27-discovery-host-001`; has "Hetzner Cloud Firewall: status unknown" placeholder) and `landscape/secrets-inventory.md` (the ai-qadam token row exists with a placeholder for SHA-256 fingerprint to be filled). Surface any drift between what's documented and what the task claims.
  - **Task-validator (step 03):** verify that the Hetzner Cloud API token file exists at `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` and is readable; verify project_id `15130993` and server_id `145542849` are still in scope (Hetzner resources can be destroyed externally — unlikely but worth a defensive check before the executor runs).
  - **Executor-discovery (step 06):** must NOT use the SSH-based probe list from `workflows/discovery-host.md` — those probes target the host, not the Hetzner API. The probe list above (A–D) is the working set; it may be expanded (e.g. `GET /v1/servers/145542849/iso` for ISO status, `GET /v1/servers/145542849/actions` for any pending Hetzner actions like backups/snapshots/resize) if useful, but the four core probes must run. The token is read by name from the secrets inventory — never paste into a handoff.
  - **Execution-validator (step 07):** confirm all four probes returned valid responses (token verify active, firewalls enumerated, server confirms with `ubuntu-16gb-nbg1-1` name, findings explicitly answer "applied or not applied"). Validate that the landscape update at step 08 resolves Open Questions item #2 from `landscape/hosts/ubuntu-16gb-nbg1-1.md`.
  - **Landscape-updater (step 08):** rewrite the "Hardware & OS" Hetzner Cloud Firewall line + the "What needs to happen" item #2 in `landscape/hosts/ubuntu-16gb-nbg1-1.md`. Resolve Open Questions item #2 by replacing it with either a populated "Hetzner Cloud Firewall" section (firewall id, rules summary, applied-to confirmation) or a "No Hetzner Cloud Firewall applied — default-exposure note" entry. If the SHA-256 fingerprint for the ai-qadam token is not already in `landscape/secrets-inventory.md`, fill it (compute via `Get-FileHash -Algorithm SHA256` on the management workstation; record only the fingerprint hash, never the value). T-0082 History section should also get an entry: `- 2026-06-27: Hetzner Cloud Firewall audit complete via run 2026-06-27-audit-hetzner-firewall-001 — <finding>`. T-0085 History section: do not transition to `done`/`closed` from step 08 because the task is a discovery (read-only) — per `workflows/_common-operations.md` "Run finalization" rule, the orchestrator decides status transition; step 08 only updates landscape. (Confirm with orchestrator whether to mark T-0085 as `done` after a successful audit, since it is `kind: task` not `kind: observation`.)

## Issues / risks

- **First run of its kind in this project.** No prior run has probed a Hetzner API endpoint. The executor-discovery subagent's hard rule #4 ("Cloudflare API: only HTTP GET requests") is the structural model but worded for Cloudflare; the orchestrator should ensure the subagent is told the equivalent rule for Hetzner. The probe target is documented above (A–D); the executor should not invent additional probes that require non-GET verbs.
- **No dedicated `discovery-hetzner.md` workflow file exists yet.** T-0085's Notes section says: "if the workflow proves useful, a dedicated `discovery-hetzner.md` workflow file should be added." This run will use the structural template from `workflows/discovery-cloudflare.md` inline. If subsequent Hetzner-API runs are needed (snapshot backups audit per `landscape/hosts/ubuntu-16gb-nbg1-1.md` Open Questions item #3), a dedicated workflow file should be created and this run's handoffs cited as the precedent.
- **Token file existence/permissions.** The token file at `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` was provisioned today; the task-validator (step 03) should verify the file is readable by the management workstation user before the executor runs, otherwise step 06 will BLOCK on the token verify probe.
- **Default exposure language.** If the audit reveals NO Hetzner Cloud Firewall is applied, the landscape-updater (step 08) must use precise wording: Hetzner Cloud servers with no Cloud Firewall applied are reachable on all ports from the public internet, blocked only by the host firewall (UFW, currently allow 22/80/443 v4+v6). The landscape must NOT invent the absence of risk; this is a finding to surface to the user (likely triggers a follow-on state-changing task to apply a Cloud Firewall).
- **No secret values in handoff files.** Repeated for emphasis — token read by name from disk, never echoed, never in `Authorization` headers pasted into handoffs. Per `shared/handoff-format.md` rule 1, no prior handoff content should be pasted; this run's executor should be similarly disciplined.
- **Firewall applied_to verification.** Hetzner Cloud Firewalls are project-scoped resources; the applied_to field of a firewall is the list of servers the firewall protects. The executor must explicitly look up server_id `145542849` in each firewall's applied_to list (or use a `GET /v1/firewalls/{id}/actions/get_applied_to` style query) and report per-firewall whether `ubuntu-16gb-nbg1-1` is covered. Reporting "firewalls exist in project ai-qadam" without resolving whether THIS server is covered is incomplete.

## Open questions (optional)

- (For step 02 landscape-reader) Confirm the placeholder text in `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Hetzner Cloud Firewall: status unknown" is the exact wording to be replaced by step 08, vs. an inline edit vs. a new section.
- (For step 08 landscape-updater) Should the new "Hetzner Cloud Firewall" section be placed under "Hardware & OS" (where the placeholder currently sits) or as a new top-level section between "Hardware & OS" and "Access"? The current placeholder is in "Hardware & OS"; recommend inline replacement unless a dedicated section adds clarity.
- (For orchestrator after step 08) T-0085 has `kind: task` and `status: in-progress`. After a successful audit, transition to `done` with `outcome: succeeded` (if firewalls are found and documented) or to `pending` (if a follow-on state-changing task must be created to apply a firewall). The orchestrator decides; step 08 only writes the landscape.