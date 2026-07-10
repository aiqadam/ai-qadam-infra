---
run_id: 2026-06-27-apply-hetzner-firewall-001
step: "01"
agent: task-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - tasks/.promotions/T-0086-promotion-2026-06-27.md
  - workflows/infrastructure.md
  - tasks/_index.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - runs/2026-06-27-install-fail2ban-001/step-01-task-reader.md
  - runs/2026-05-12-add-host-firewall-001/step-01-task-reader.md
artifacts_changed: []
next_step_hint: landscape-reader — focus on landscape/hosts/ubuntu-16gb-nbg1-1.md "Hetzner Cloud Firewall", "Access", and "Hardware & OS" sections; cross-reference landscape/hosts/hetzner-prod.md "Network" section for the firewall-1 pattern reference. Confirm the per-project Hetzner token metadata against landscape/secrets-inventory.md. Surface any gaps in token scope (15130993 only) or management-workstation outbound IP freshness.
---

## Summary

Task T-0086 is well-formed and ready for downstream steps. The run originated from a prior task-promoter step (not direct user input) — the user gave "Up to you" implicit approval to proceed with the highest-value open task. The task is to apply a Hetzner Cloud Firewall to server `ubuntu-16gb-nbg1-1` (server_id `145542849`, project_id `15130993` "ai-qadam") to close the cloud-layer exposure gap identified by the T-0085 audit, plus enable the `protection.delete` and `protection.rebuild` server-side flags as bundled defense-in-depth. The workflow `infrastructure` applies; blast radius is `medium` and reversibility is `full`, but per `shared/approval-protocol.md` firewall rule changes **always** require `NEEDS_APPROVAL` regardless of blast/reversibility — so the orchestrator should expect a user approval gate between step 04 and step 06.

## Details

### Provenance (how this run started)

- This run did NOT originate from a direct user request. The user said "Up to you" earlier in conversation; the orchestrator selected T-0086 as the highest-value open task (it is the only P1 pending task whose `workflow: infrastructure` is non-read-only and state-changing, and it is the follow-on to the T-0085 audit completed the same day).
- The task was promoted from `kind: observation` to `kind: task` by run `2026-06-27-promote-T-0086` (handoff at [tasks/.promotions/T-0086-promotion-2026-06-27.md](../../tasks/.promotions/T-0086-promotion-2026-06-27.md)) on 2026-06-27. The promotion refined the acceptance criteria to scope the firewall to SSH-only inbound from the management workstation outbound IP, mirroring the prod `firewall-1` pattern, and bundled the two server protection flags into the same run.
- Current task frontmatter (verified 2026-06-27): `kind: task`, `status: in-progress`, `workflow: infrastructure`, `priority: P1`, `estimated_blast_radius: medium`, `estimated_reversibility: full`, `created: 2026-06-27`, `executed_by_runs: [2026-06-27-apply-hetzner-firewall-001]`.

### Goal statement (verbatim from task "Why")

> Discovery run `2026-06-27-audit-hetzner-firewall-001` (task T-0085, now done) found that **Hetzner project `ai-qadam` (project_id `15130993`) contains zero Hetzner Cloud Firewalls**, leaving server `ubuntu-16gb-nbg1-1` (server_id `145542849`) exposed at the cloud layer with only host-level filtering (UFW + fail2ban) as protection.
>
> [Per the audit's documented default-exposure language] The server is reachable on all ports (1–65535, TCP and UDP, IPv4 and IPv6) from the public internet. Hetzner does NOT impose a default-deny at the cloud layer. Any service bound to a public IP is reachable directly, with no Hetzner-side filtering.

The single-paragraph synthesis for downstream steps: **apply a Hetzner Cloud Firewall to `ubuntu-16gb-nbg1-1` to close the cloud-layer exposure gap identified by T-0085 audit; enable server protection flags `protection.delete=True` and `protection.rebuild=True` in the same run as defense-in-depth.**

### Acceptance criteria (verbatim from task "What done looks like")

- [ ] **Pre-flight:** management workstation outbound IP re-verified via `api.ipify.org` immediately before the API calls (record timestamp + IP in handoff).
- [ ] **Firewall created:** Hetzner Cloud Firewall created in project `15130993` ("ai-qadam") named `ai-qadam-mgmt-ssh` (or similar user-discretion name — user may rename during approval).
- [ ] **Inbound rule:** TCP 22 from `178.89.57.135/32` (single IPv4 address, explicit; NOT `0.0.0.0/0`).
- [ ] **No other inbound rules:** No inbound rules for 80/443 or any other port (host has no role yet; web ports to be added later when role is assigned).
- [ ] **Outbound rules:** Hetzner default (allow all) — no customization needed.
- [ ] **Applied to server:** Firewall applied to server_id `145542849` (`ubuntu-16gb-nbg1-1`) via `applied_to` resource list.
- [ ] **Server protection flags:** `protection.delete=True`, `protection.rebuild=True` (separate API calls; both verified post-set). Server 145542849 currently has both at `False` (Hetzner defaults) per T-0085 audit.
- [ ] **Post-apply live SSH verification:** from management workstation: `Test-NetConnection 46.225.239.60 -Port 22` → True.
- [ ] **Landscape updated:** `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Hetzner Cloud Firewall" section updated to reflect new firewall id, name, rule list, `applied_to`, and protection flags.
- [ ] **Landscape updated if applicable:** `landscape/services.md` updated if applicable (no expectation of a change for this minimal SSH-only rule set, but landscape-updater should confirm).
- [ ] **Index re-sorted:** `tasks/_index.md` re-sorted (already satisfied by the promotion — T-0086 is now in the P1 pending block; final close to `done` after this run will move it to the `done` block).

### Scope boundaries

**In scope:**

1. Create a Hetzner Cloud Firewall in project 15130993 ("ai-qadam") named `ai-qadam-mgmt-ssh` (default; user may rename at approval).
2. Apply the firewall to server_id `145542849` (`ubuntu-16gb-nbg1-1`) via the `applied_to` resource list.
3. Define the inbound rule: TCP 22 from `178.89.57.135/32`. No other inbound rules.
4. Use Hetzner default outbound rules (allow all). No customization.
5. Enable server-side protection flags: `protection.delete=True`, `protection.rebuild=True` (via `POST /v1/servers/{id}/actions/change_protection`).
6. Pre-flight: re-verify management workstation outbound IP via `api.ipify.org` immediately before POSTing rules; record timestamp + IP in handoff.
7. Post-apply verification: `Test-NetConnection 46.225.239.60 -Port 22` from management workstation → True.
8. Update `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Hetzner Cloud Firewall" section with firewall id, name, rule list, `applied_to`, and protection flags.
9. Confirm `landscape/services.md` does not need changes (this run only touches Hetzner-side state, not services running on the host).

**Out of scope:**

- UFW changes (already done in T-0083 / run `2026-06-27-configure-ufw-001`).
- fail2ban changes (already done in T-0084 / run `2026-06-27-install-fail2ban-001`).
- sshd hardening on the host itself (T-0083/T-0084 sibling hardening; tracked as a future state-changing task — `PermitRootLogin yes`, `PasswordAuthentication yes`, no `40-disable-password.conf` drop-in yet per `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Access" section).
- Role assignment for the host (`role: unassigned` in landscape frontmatter; user decision required).
- Enabling Hetzner Backups (`backup_window=""` confirmed NOT enabled; tracked separately as a follow-on if the user decides).
- Setting up Cloudflare DNS / proxy for the host (no domain yet — host has no role).
- Adding inbound rules for 80/443 or any other port (no role yet; web ports added later).

### Workflow shape confirmation

- **Workflow:** `infrastructure` (verified in task frontmatter `workflow: infrastructure` and matches [workflows/infrastructure.md](../../workflows/infrastructure.md) "When this workflow applies" — specifically the bullet "OS package install/upgrade, systemd unit changes, **firewall rules**").
- **State-changing:** Yes — Hetzner Cloud API mutations (firewall create + apply + protection flag change) are all state-changing.
- **Blast radius:** `medium` (task frontmatter) — applying rules to a project firewall could lock out management if scoped too tight.
- **Reversibility:** `full` (task frontmatter) — firewall can be deleted, protection flags can be unset.
- **Approval gate:** Per [shared/approval-protocol.md](../../shared/approval-protocol.md) §"Always requires `NEEDS_APPROVAL`": **firewall rule changes always emit `NEEDS_APPROVAL`** regardless of reversibility. The solution-designer at step 04 MUST emit `verdict: NEEDS_APPROVAL` (NOT `verdict: PASS`) — the medium/full rating alone does not auto-approve this work.
- **Step bindings** (per [workflows/infrastructure.md](../../workflows/infrastructure.md)):

  | Step | Agent | Notes for this run |
  |---|---|---|
  | 01 | `task-reader` | This handoff. |
  | 02 | `landscape-reader` | Read `landscape/hosts/ubuntu-16gb-nbg1-1.md` (focus on "Hetzner Cloud Firewall", "Access", "Hardware & OS" sections), cross-reference `landscape/hosts/hetzner-prod.md` "Network" section for the `firewall-1` pattern, verify token metadata against `landscape/secrets-inventory.md`. |
  | 03 | `task-validator` | Validate the task against frontmatter schema, confirm the refined acceptance criteria are reachable, surface any blockers. |
  | 04 | `solution-designer` | Design the firewall JSON body (rules.inbound[] / rules.outbound[] / applied_to[]), the protection flag call, and the pre/post verification probes. **MUST emit `verdict: NEEDS_APPROVAL`** — do not auto-approve. |
  | 05 | (orchestrator-written user approval) | Halts on `NEEDS_APPROVAL`; user replies APPROVE / REJECT / MODIFY. |
  | 06 | `executor-infra` | Apply the firewall and protection flags; verify. **MUST verify the step-04 verdict is `NEEDS_APPROVAL` AND that a step-05 file with `verdict: APPROVED` exists** before mutating Hetzner state. |
  | 07 | `execution-validator` | Verify the firewall was created, applied, and protection flags set; confirm live SSH still works; confirm the firewall is visible via `GET /v1/firewalls/{id}`. |
  | 08 | `landscape-updater` | Update `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Hetzner Cloud Firewall" section; update `landscape/services.md` only if applicable; re-sort `tasks/_index.md`; transition T-0086 to `done`. |

### Key identifiers (for downstream steps)

| Item | Value |
|---|---|
| Server ID | `145542849` |
| Server hostname | `ubuntu-16gb-nbg1-1` |
| Server public IPv4 | `46.225.239.60` |
| Server public IPv6 | `2a01:4f8:1c1c:5959::/64` |
| Hetzner project ID | `15130993` |
| Hetzner project name | `ai-qadam` |
| Token name | `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` |
| Token scope | project_id `15130993` only (read+write) |
| Token SHA-256 fingerprint | `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153` |
| Token file (local) | `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` (per landscape change log) |
| Management workstation outbound IP | `178.89.57.135/32` (re-verify live via api.ipify.org pre-flight) |
| SSH config alias | `Host ubuntu-16gb-nbg1-1` (in `C:\Users\tvolo\.ssh\config`) |
| SSH user | `tvolodi` |
| SSH key (workstation) | `C:\Users\tvolo\.ssh\ai-dala-infra` (ed25519, no passphrase) |
| Pattern reference | `firewall-1` id `10145783`, project `12287574` ("ai-dala"), applied to server_id `112603990` (prod) — see `landscape/hosts/hetzner-prod.md` "Network" section |
| Hetzner API endpoint (firewall create) | `POST https://api.hetzner.cloud/v1/firewalls` |
| Hetzner API endpoint (firewall apply) | `POST https://api.hetzner.cloud/v1/firewalls/{id}/actions/apply_to_resources` |
| Hetzner API endpoint (protection flag) | `POST https://api.hetzner.cloud/v1/servers/{id}/actions/change_protection` |
| Hetzner API endpoint (verify post-apply) | `GET https://api.hetzner.cloud/v1/firewalls/{id}` and `GET https://api.hetzner.cloud/v1/servers/{id}` |
| Firewall name (default) | `ai-qadam-mgmt-ssh` (user may rename at approval) |

### Risks and prerequisites

1. **Lockout risk (HIGH if mishandled).** If the firewall is scoped too tight (e.g., management IP omitted by mistake), the host becomes unreachable from the management workstation. **Mitigations:**
   - Pre-flight: re-verify outbound IP via `api.ipify.org` immediately before POSTing rules; record timestamp + IP in handoff.
   - Hetzner Cloud Console remains available as a fallback to manually delete/recreate the firewall.
   - Hetzner Cloud Console direct console access (KVM-over-IP) is also available as a fallback for console-level recovery.
   - UFW + fail2ban remain active on the host, so even if the Cloud Firewall were accidentally misapplied to block all traffic, host-level SSH would still be denied — meaning the *only* recovery path would be Hetzner Console (delete the firewall) or KVM console.

2. **Token scope discipline.** The token `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` is project_id `15130993`-scoped (read+write). All API calls for this run (firewall create, apply, protection flag set, verification reads) stay within that scope. The token is **insufficient** to touch project `12287574` (prod). **Confirm scope before any API call** — the executor should include the project filter explicitly in any `GET` and confirm the create body is well-formed before POST.

3. **API call shape — firewall create.** Hetzner `POST /v1/firewalls` body uses `rules.inbound[]` and `rules.outbound[]` arrays; `applied_to[]` references server resources by `{type: "server", server: {id: <id>}}`. The solution-designer (step 04) should produce the exact JSON body and the executor should reuse it verbatim — no live schema exploration during execution.

4. **API call shape — protection flag.** Hetzner `POST /v1/servers/{id}/actions/change_protection` body uses `{delete: true, rebuild: true}` (Hetzner API accepts both flags in one call). The acceptance criteria says "separate API calls; both verified post-set" — this is **inconsistent with the Hetzner API which accepts both in one call**. The solution-designer (step 04) should decide and document: either (a) one combined call `{delete: true, rebuild: true}` (simpler, fewer round-trips, matches Hetzner API), or (b) two separate calls (per acceptance criteria wording). My read: the criteria wording reflects a general safety principle (verify each flag post-set), not a hard requirement to split into two HTTP calls. **Solution-designer should make the call and document explicitly in the handoff.**

5. **Pre-flight IP staleness.** The IP `178.89.57.135` was recorded in fail2ban's `ignoreip` (T-0084) and is the same value used in the audit (T-0085). However, the management workstation outbound IP could change if the user's ISP rotates IPs. The acceptance criteria correctly require a live re-verification via `api.ipify.org` immediately before the POST. **Step 06 (executor) must perform this re-verification and refuse to proceed if the IP differs from `178.89.57.135`** without an explicit override.

6. **Outbound rules.** Default allow-all (Hetzner's default behavior) — no need to specify an explicit `rules.outbound` array. The solution-designer (step 04) should document whether the body includes an explicit empty outbound array or omits it (Hetzner API accepts both; default behavior is identical).

7. **Firewall name finality.** The default name is `ai-qadam-mgmt-ssh`. The user may rename at the approval step. The solution-designer (step 04) should lock in the name and emit it for approval.

8. **Pattern source.** The pattern reference is `firewall-1` (id `10145783`) on prod — `landscape/hosts/hetzner-prod.md` "Network" section. Step 02 (landscape-reader) should read that section to surface any details relevant to the design (e.g., how prod's outbound rules are structured, even though prod's inbound has been incrementally added over time for RustDesk / Gitea SSH, neither of which apply to the unprovisioned new host).

### Information gaps for downstream steps

- **Pre-flight IP not yet re-verified for THIS run.** The IP `178.89.57.135` is recorded in `landscape/hosts/ubuntu-16gb-nbg1-1.md` (T-0084 fail2ban ignoreip) but it has NOT been re-verified within the time window of this run. Step 06 (executor) MUST perform the `api.ipify.org` re-verification as the very first action and abort if the IP differs.
- **Hetzner API exact body schema for `applied_to[]`.** The task says "via `applied_to` resource list" but does not specify the exact JSON shape (e.g., does `applied_to` go in the create body, or only via a separate `apply_to_resources` action call?). **Step 04 (solution-designer) must consult the Hetzner Cloud API docs and document the exact body.** Per Hetzner API, both `POST /v1/firewalls` with `applied_to` in the body and a separate `POST /v1/firewalls/{id}/actions/apply_to_resources` action are valid approaches; the task's "token" mention references both endpoints ("a `POST /v1/firewalls` and a `POST /v1/firewalls/{id}/actions/apply_to_resources` (Hetzner API conventions)"), suggesting the executor may use the separate action call (which is the safer choice — separate the create from the apply to allow rollback if rules are wrong before application).
- **Protection-flag call shape.** See Risks #4 above — one combined call vs two separate calls is a design decision for step 04.
- **IPv6 inbound.** The task says inbound is IPv4-only (`178.89.57.135/32` is an IPv4 address). The audit's "default exposure" language mentions IPv6, but the task is scoped to IPv4. Step 04 should confirm whether IPv6 traffic is intentionally out of scope (i.e., the firewall will be IPv4-only) or whether IPv6 ICMP/TCP inbound from `178.89.57.135` (translated to v6 equivalent or left to v4-only) needs an explicit rule. The audit used `GET /v1/firewalls?project_id=15130993` (no v6 hint); Hetzner Cloud Firewalls can filter on `direction`, `protocol`, `port`, `source_ips` (each can be IPv4 or IPv6 CIDR). **Default expectation: IPv4-only firewall (matches task wording); IPv6 inbound remains unrestricted until role assignment.** Document this assumption explicitly in step 04.
- **Existing firewall ID.** Confirmed via audit that project `15130993` contains zero firewalls. No need to update or delete an existing firewall. Step 02 (landscape-reader) should re-confirm via `GET /v1/firewalls?project_id=15130993` immediately before the executor's POST (defense-in-depth — though the audit is recent, a same-day re-check is cheap).

### Task frontmatter verification

| Field | Value | Status |
|---|---|---|
| `kind` | `task` | ✓ |
| `status` | `in-progress` | ✓ (valid for execution; task-promoter transitioned observation→pending, then orchestrator set in-progress on run start) |
| `workflow` | `infrastructure` | ✓ |
| `priority` | `P1` | ✓ |
| `created` | `2026-06-27` | ✓ |
| `created_by` | `2026-06-27-audit-hetzner-firewall-001` | ✓ |
| `source_runs` | `[2026-06-27-audit-hetzner-firewall-001]` | ✓ |
| `executed_by_runs` | `[2026-06-27-apply-hetzner-firewall-001]` | ✓ (this run) |
| `affects` | `[landscape/hosts/ubuntu-16gb-nbg1-1.md, landscape/services.md]` | ✓ |
| `blocks` | `[]` | ✓ |
| `blocked_by` | `[]` | ✓ |
| `related` | `[T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1]` | ✓ |
| `estimated_blast_radius` | `medium` | ✓ |
| `estimated_reversibility` | `full` | ✓ |

Task is well-formed. Status is `in-progress` which is valid for execution (per task-reader instructions: "Verify its frontmatter `status` is `pending` or `in-progress`. If anything else ... emit `verdict: BLOCKED`").

## Issues / risks

- **Approval gate is mandatory (not auto-approve).** Per `shared/approval-protocol.md` §"Always requires `NEEDS_APPROVAL`": firewall rule changes **always** require explicit human sign-off. Step 04 (solution-designer) must emit `verdict: NEEDS_APPROVAL` regardless of the task's `medium/full` blast/reversibility rating. The task's medium/full rating is correct for record-keeping but does not auto-approve. **The orchestrator should expect a step-05 file before advancing to step 06.**
- **Lockout risk is the dominant operational risk.** Mitigated by pre-flight IP re-verification, by the Hetzner Cloud Console fallback, and by the fact that the separate-action apply pattern lets the executor create the firewall (with rules) without applying it to the server — they can validate the JSON one more time before issuing the apply action.
- **Token scope is narrow but sufficient.** The token is project-scoped to `15130993` only — exactly the project this run needs to touch. The executor must NOT attempt to verify against project `12287574` (prod); the token will return `403` or similar.
- **Bundled protection flags are low-risk, high-value.** Per the task-promoter handoff: "Defense-in-depth, low-risk — one API call each, easily reversible". Step 04 should bundle them into the same run as the firewall apply, not split into a separate workflow.
- **The "Why" paragraph in T-0086 references audit findings verbatim.** The solution-designer (step 04) should be aware that the audit (T-0085) and the discovery (T-0082) are the source of truth for current host state; landscape-reader (step 02) should cross-reference both.
- **No deviations from task file's intent.** This handoff parses and structures the task's intent verbatim — no scope expansion, no scope reduction, no second-guessing the refined acceptance criteria. Where the criteria wording is ambiguous (e.g., one combined protection-flag call vs two separate), I have flagged it for step 04 to resolve explicitly.

## Open questions (optional)

- **Firewall name finality:** default is `ai-qadam-mgmt-ssh`. The user may rename at approval. Step 04 should lock it in.
- **Protection-flag call shape:** one combined `{delete: true, rebuild: true}` call vs two separate calls. The acceptance criteria's "separate API calls; both verified post-set" wording leans toward separate calls, but the Hetzner API supports a combined call. **Step 04 should make this explicit decision and document it.** (My read: combined call, then two `GET` verifications — matches the "both verified post-set" intent with fewer HTTP round-trips.)
- **IPv6 inbound scope:** task is silent on IPv6. Default expectation: IPv4-only firewall. Step 04 should confirm or adjust.