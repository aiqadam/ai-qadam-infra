---
run_id: 2026-06-27-audit-hetzner-firewall-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
inputs_read:
  - runs/2026-06-27-audit-hetzner-firewall-001/step-01-task-reader.md
  - landscape/README.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - workflows/discovery-cloudflare.md
  - workflows/_common-operations.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-05-12-discovery-cloudflare-001/step-02-landscape-reader.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — verify token file is readable, confirm project_id 15130993 and server_id 145542849 still resolve to an ai-qadam server in Hetzner Cloud, and re-check the 6 acceptance criteria from step-01 against the present landscape.
---

## Summary

The landscape is **sufficient** for executor-discovery to design and run the Hetzner Cloud API probes. `landscape/hosts/ubuntu-16gb-nbg1-1.md` is `populated` (last verified today, 2026-06-27) and explicitly carries "Hetzner Cloud Firewall: status unknown — out of scope for the discovery workflow (requires Hetzner API call against project 15130993)" — that placeholder is exactly the gap this run fills. The new per-project Hetzner API token is catalogued in `landscape/secrets-inventory.md` with file path, scope, and rotation date; the token file itself was verified to exist on the management workstation (64 bytes, readable). There is no dedicated `workflows/discovery-hetzner.md` yet — `workflows/discovery-cloudflare.md` is the structural template the executor should mirror, substituting Hetzner endpoints and the ai-qadam token. No staleness or stub blocks exist that would force a BLOCKED verdict.

## Details

### Relevant facts (sourced from landscape)

**Confirmed Hetzner identifiers for the new host** — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md` frontmatter_
- `host_id: ubuntu-16gb-nbg1-1`
- `provider: hetzner`
- `role: unassigned`
- `last_verified: 2026-06-27`
- `status: populated`
- `hetzner_server_name: ubuntu-16gb-nbg1-1`
- `hetzner_server_id: 145542849`
- `hetzner_project_id: 15130993`
- `hetzner_server_type: CX43`
- `hetzner_project_name: ai-qadam`
- `os: ubuntu-26.04`, `kernel: 7.0.0-22-generic`

**Confirmed Hetzner identifiers for the production host** (reference pattern for Cloud Firewall lookup) — _source: `landscape/hosts/hetzner-prod.md` frontmatter_
- `host_id: hetzner-prod`
- `hetzner_project_id: 12287574`
- `hetzner_server_id: 112603990`

**Hetzner Cloud Firewall on hetzner-prod** (the reference pattern) — _source: `landscape/hosts/hetzner-prod.md` "Network" section_
- `Hetzner Cloud Firewall: firewall-1 (id=10145783) applied to this server.`
- Updated 2026-05-26 to permit inbound TCP on port 2222 (Gitea SSH git).
- Updated 2026-05-13 to permit inbound TCP on 21115–21119 (RustDesk).
- This is the **only** Hetzner Cloud Firewall currently documented in the landscape; it is on project `12287574` ("ai-dala"), NOT on project `15130993` ("ai-qadam") — so it provides no protection to `ubuntu-16gb-nbg1-1`.

**Hetzner snapshot backups status on hetzner-prod** — _source: `landscape/hosts/hetzner-prod.md`_
- "Hetzner Backups option: NOT enabled as of 2026-05-12. See [T-0001](../../tasks/T-0001-enable-hetzner-snapshots.md) (status: wontfix)."
- Reference for what "no backups" looks like; out of scope for this run but useful context for the adjacent Open Question #3 on `ubuntu-16gb-nbg1-1`.

**Hetzner API token for ai-qadam (the new project's per-project token)** — _source: `landscape/secrets-inventory.md`_
- Secret name: `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`
- Purpose: "Hetzner Cloud API read+write access for the **ai-qadam** project (id `15130993`) only — covers the new server `ubuntu-16gb-nbg1-1` (server_id `145542849`) and any future ai-qadam-project resources. Scoped per-project, not per-zone."
- Storage location: `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`
- ACL: user-only read/write
- Used by: "management workstation, future infrastructure workflows that manage ai-qadam-project resources (Hetzner Cloud Firewall for ubuntu-16gb-nbg1-1, server resizing/rebuild, etc.)"
- Rotation: "on-demand (rotate on suspected compromise)"
- Last rotated: 2026-06-27 (provisioned today; SHA-256 fingerprint below in 'Cloudflare read-only token' style section — **to be added on next housekeeping pass**)
- Note (frontmatter): `last_verified: 2026-05-26` for the secrets inventory file overall; the ai-qadam row was added today but does not yet have its own row-level "last rotated" updated timestamp beyond the 2026-06-27 provisioning date.

**Existing Hetzner token for the ai-dala project (different file, different scope)** — _source: `landscape/secrets-inventory.md`_
- Secret name: `hetzner-api-token:ai-dala-infra:read-write`
- Covers project_id `12287574` (hetzner-prod's project) — NOT `15130993`.
- Storage location: `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-dala.token`.
- This is the token that has been used in past runs that modified `firewall-1` (id 10145783) on project 12287574. The new ai-qadam token is a separate, scoped-per-project companion.

**Token file existence verified on management workstation** — _source: live `Test-Path` + `(Get-Item).Length` (2026-06-27)_
- `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` exists; size 64 bytes. NOT opened, NOT echoed. The 64-byte size is consistent with a Hetzner Cloud API token (typical 64-character printable ASCII string, no trailing newline). Step 03 task-validator should re-confirm readability and compute the SHA-256 fingerprint as part of housekeeping.

**What is already hardened on `ubuntu-16gb-nbg1-1` (the inner layers)** — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- UFW: "active and enabled at boot as of 2026-06-27 (run `2026-06-27-configure-ufw-001` / T-0083). `IPV6=yes` … `DEFAULT_FORWARD_POLICY='ACCEPT'` preserved for Docker parity with `hetzner-prod`." Ruleset: allow 22/tcp (v4+v6), allow 80/tcp (v4+v6), allow 443/tcp (v4+v6). Six rules total.
- fail2ban: "fail2ban 1.1.0-9 installed and active; sshd jail enabled (maxretry=3, bantime=600s, findtime=600s, ignoreip includes 178.89.57.135 (management workstation for this host), banaction=iptables-multiport); config: `/etc/fail2ban/jail.d/sshd.local`" — installed 2026-06-27 via run `2026-06-27-install-fail2ban-001` (T-0084).
- The Hetzner Cloud Firewall sits at the OUTERMOST layer (public internet → Cloud Firewall → host firewall (UFW) → sshd), so this audit covers the layer NOT covered by the recent UFW + fail2ban work.

**sshd hardening status** — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Access" section_
- "defaults from Ubuntu 26.04 cloud image — `Port 22`, `PermitRootLogin yes`, **`PasswordAuthentication yes`**, `PubkeyAuthentication yes`, … **No project hardening yet** (no `40-disable-password.conf`; no `AllowUsers` / `AllowGroups` filters)."
- This is adjacent context: the host currently allows password auth, which compounds the case for an outer-layer Cloud Firewall restricting source IPs. Not blocking — task T-0086 (a future state-changing workflow) is the appropriate place to address sshd hardening, independent of this read-only audit.

**Open Questions on the host file that this run resolves** — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- Item #1 (in "Open questions"): **Hetzner Cloud Firewall ID: unknown — requires Hetzner API call against project 15130993.** Resolution: write a "Hetzner Cloud Firewall" section in step 08 (firewall id, rules summary, applied-to confirmation) or a "No Hetzner Cloud Firewall applied — default-exposure note."
- Item #2 (in "Open questions"): **Hetzner snapshot backups: status unknown — same API-call dependency.** Out of scope for this run per step-01; explicitly deferred to a follow-on Hetzner-API workflow.
- "What needs to happen" item #2 (in the host file): ⏳ Hetzner Cloud Firewall — "Audit and (if needed) apply a firewall permitting management IP. Record firewall ID. **Status unknown** — defer to a follow-on Hetzner-API workflow run after token-scope for project 15130993 is verified." → this run resolves the "audit" part; "apply" remains a follow-on state-changing task.

**Adjacent reference pattern: Cloudflare API discovery workflow** — _source: `workflows/discovery-cloudflare.md` + `runs/2026-05-12-discovery-cloudflare-001/step-02-landscape-reader.md`_
- Discovery-cloudflare shares the same skeleton: `state_changing: false`, `skip_design_step: true`, steps 04/05 skipped, executor at step 06 runs read-only HTTP GET, step 08 writes the landscape. Token is read by name from `landscape/secrets-inventory.md`; the token value never appears in any handoff. Step 02 handoff lists token name + path + scope and explicitly defers per-zone detail to step 06's probes.
- This structural pattern is the working template for the Hetzner audit: same shape, different base URL (`https://api.hetzner.cloud/v1` vs `https://api.cloudflare.com/client/v4`), different scope (project-scoped vs zone-scoped).

### Stale or stub files encountered

- `landscape/secrets-inventory.md` — `last_verified: 2026-05-26` at file level, but the `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` row is dated 2026-06-27. The 2026-05-26 file-level date is technically stale relative to today, but the row itself is current (provisioned today). Step 08 landscape-updater should update the file's `last_verified:` to 2026-06-27 when it lands the SHA-256 fingerprint housekeeping. NOT a blocker — the file is the right reference for this audit.
- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `last_verified: 2026-06-27`, `status: populated`. Fresh.
- `landscape/services.md` — `last_verified: 2026-06-27`, `status: populated`. Fresh.
- No `status: stub` files in scope.
- No `discovery-hetzner.md` workflow file exists yet — this run will use `workflows/discovery-cloudflare.md` inline as the structural template (per step-01's `next_step_hint`).

### Gaps requiring live discovery

These are the facts that cannot be derived from the landscape and must be enumerated via the Hetzner Cloud API in step 06 (executor-discovery). They are the audit's actual deliverables.

- **Project resource exists** — `GET /v1/projects/15130993` (or `GET /v1/projects?project_id=15130993` depending on Hetzner API capability) confirms the token is valid for project `ai-qadam` and returns the project record. Token-verify analog of `workflows/discovery-cloudflare.md` probe A.
- **Firewalls enumerated for project 15130993** — `GET /v1/firewalls?project_id=15130993` returns all Cloud Firewalls in the project. For each: id, name, inbound rules (source IPs/CIDRs, ports, protocols), outbound rules, `applied_to` server list. The Hetzner Cloud API exposes `applied_to` per firewall resource; the executor must explicitly check whether `server_id 145542849` is in any firewall's `applied_to` array, or use the per-firewall `actions/get_applied_to` endpoint, and report per-firewall whether `ubuntu-16gb-nbg1-1` is covered.
- **Server confirmed on Hetzner side** — `GET /v1/servers/145542849` confirms the server exists in project `ai-qadam`, returns its Hetzner-side network configuration (public IPv4/IPv6 already known from landscape; cross-check, plus datacenter, server status, any private network attachments), and confirms `protection` flags (delete protection, rebuild protection). Adjacent useful probes (step 06 may include if helpful, but not required by step-01's 6 acceptance criteria): `GET /v1/servers/145542849/iso` (boot ISO), `GET /v1/servers/145542849/actions` (pending or recent Hetzner actions).
- **Backups option (adjacent, out of scope but cheap to capture)** — the server record's `backup_window` field reveals whether the Hetzner Backups option is enabled. Step-01 explicitly defers this to a follow-on run; the executor should NOT prioritize it but may note it in the findings if it surfaces incidentally.
- **Default-exposure language** — if the audit finds NO firewall applied, the landscape-updater (step 08) must use precise wording: Hetzner Cloud servers with no Cloud Firewall applied are reachable on all ports from the public internet, blocked only by the host firewall (UFW, currently allow 22/80/443 v4+v6). The landscape must not invent the absence of risk; this is a finding to surface to the user (likely triggers a follow-on state-changing task to apply a Cloud Firewall).

## Issues / risks

- **First Hetzner-API run in this project.** No prior run has probed a Hetzner Cloud API endpoint. The executor-discovery subagent's hard rule #4 (Cloudflare API: only HTTP GET requests) is the structural model but worded for Cloudflare; the orchestrator must brief the subagent that the equivalent rule for Hetzner applies. The four probes A–D from step-01 are the working set; the executor should not invent additional probes that require non-GET verbs.
- **No dedicated `workflows/discovery-hetzner.md`.** T-0085's Notes say: "if the workflow proves useful, a dedicated `discovery-hetzner.md` workflow file should be added." This run will use the structural template from `workflows/discovery-cloudflare.md` inline. If subsequent Hetzner-API runs are needed (snapshot backups audit per Open Question #2), a dedicated workflow file should be created and this run cited as the precedent.
- **Token file existence/permissions.** Verified today: file exists at `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, 64 bytes, readable. Task-validator (step 03) should re-confirm readability on its own run and verify the SHA-256 fingerprint computation works (it is `Get-FileHash -Algorithm SHA256` on the file path — the token value is never logged, only the fingerprint hash is recorded).
- **`applied_to` is the authoritative answer.** Hetzner Cloud Firewalls are project-scoped resources; the `applied_to` field of a firewall resource is the list of servers the firewall protects. The executor must explicitly look up server_id `145542849` in each firewall's `applied_to` list and report per-firewall whether `ubuntu-16gb-nbg1-1` is covered. Reporting "firewalls exist in project ai-qadam" without resolving whether THIS server is covered is incomplete and would fail step-07.
- **No secret values in handoff files.** Repeated for emphasis — the ai-qadam token is read by name from disk, never echoed, never in `Authorization` headers pasted into handoffs. Per `shared/handoff-format.md` rule 1, no prior handoff content should be pasted; this run's executor should be similarly disciplined.
- **SSH password auth still on** — UFW allows 22 globally, fail2ban is the only current mitigation. If the audit reveals NO Hetzner Cloud Firewall is applied, the host's only protection against SSH brute force from arbitrary source IPs is fail2ban (maxretry=3, bantime=600s, findtime=600s). The landscape-updater must NOT characterize this as "low risk"; the default-exposure language must be explicit.

## Open questions (optional)

- (For step 08 landscape-updater) Where exactly to place the new "Hetzner Cloud Firewall" section in `landscape/hosts/ubuntu-16gb-nbg1-1.md` — inline replacement of the "Hetzner Cloud Firewall: status unknown" line in "Hardware & OS", or a new top-level section between "Hardware & OS" and "Access"? Step-01 recommends inline replacement unless a dedicated section adds clarity; either is acceptable.
- (For orchestrator after step 08) T-0085 has `kind: task` and `status: in-progress`. After a successful audit, the orchestrator decides whether to transition T-0085 to `done` (with `outcome: succeeded`) if firewalls are found and documented, or to `pending` if a follow-on state-changing task must be created to apply a firewall. Step 08 only writes the landscape.
- (For step 08 landscape-updater) Whether to also touch T-0082's History section. The host file's "Open tasks affecting this host" section lists T-0082 as "in-progress (this discovery run completed 2026-06-27; stub → populated transition done; parent task remains open pending role assignment and follow-on hardening)" — adding a history line about the Hetzner Cloud Firewall audit being complete is reasonable, but the precise wording is the landscape-updater's call.
- (For step 03 task-validator) Whether to spot-check the Hetzner API token via a single `curl GET /v1/projects` request during validation, in addition to confirming the file exists and is readable. Doing so costs one HTTP call and gives the validator a real "token is active" signal before the executor runs. Optional — not required, but cheap insurance against step-06 BLOCKing on a token-revocation surprise.