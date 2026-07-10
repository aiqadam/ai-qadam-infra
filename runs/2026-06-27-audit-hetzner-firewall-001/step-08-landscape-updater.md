---
run_id: 2026-06-27-audit-hetzner-firewall-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-06-27T09:00:00Z
task_id: T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-audit-hetzner-firewall-001/step-01-task-reader.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-02-landscape-reader.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-03-task-validator.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-06-executor-discovery.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-07-execution-validator.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - tasks/_index.md
  - tasks/_template.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-06-27-discovery-host-001/step-08-landscape-updater.md
artifacts_changed:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/secrets-inventory.md
  - tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - tasks/_index.md
next_step_hint: Run complete; orchestrator may finalize the run (commit hash placeholder in T-0085/T-0086 History rows to be filled at commit time).
retry_of: ~
---

## Summary

Updated the landscape to reflect the verified findings of Hetzner Cloud Firewall audit run `2026-06-27-audit-hetzner-firewall-001`: [landscape/hosts/ubuntu-16gb-nbg1-1.md](../landscape/hosts/ubuntu-16gb-nbg1-1.md) now records that **project 15130993 ("ai-qadam") has zero Hetzner Cloud Firewalls and the server is exposed at the cloud layer with only UFW + fail2ban protection** (new dedicated "Hetzner Cloud Firewall" section, resolved Open questions items #1 and #2, updated "What needs to happen" items #2 and #7, Location updated to `nbg1-dc3`, change-log row appended); [landscape/secrets-inventory.md](../landscape/secrets-inventory.md) frontmatter `last_verified` bumped to `2026-06-27`, inventory row's housekeeping placeholder removed, and a new "Hetzner ai-qadam token — identifying metadata (safe to commit)" section added with the SHA-256 fingerprint of the per-project Hetzner token; [tasks/T-0085](../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) transitioned to `done`/`succeeded` with all 6 acceptance criteria checked and Result filled; new [tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md](../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) created as a P1 observation task to track the actual firewall-apply as a future state-changing workflow; [tasks/_index.md](../tasks/_index.md) re-sorted and the malformed 3-rows-on-one-line formatting bug at the previous line 42 fixed.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| [landscape/hosts/ubuntu-16gb-nbg1-1.md](../landscape/hosts/ubuntu-16gb-nbg1-1.md) | "Hardware & OS": Location `nbg1` → `nbg1-dc3` (Nuremberg DC3); Hetzner Backups option resolved to "NOT enabled" (`backup_window=""` per Hetzner API 2026-06-27, captured incidentally); Hetzner Cloud Firewall resolved to "NONE applied" with cross-reference to new section + T-0086. New top-level section "Hetzner Cloud Firewall" added between "Network" and "Backups" — records the no-firewall finding, the verified Hetzner API probe (with three URL variants re-confirmed by execution-validator), the default-exposure language verbatim, the Hetzner-side protection flags / private_net / created timestamp, the recommendation, and the cross-reference to `hetzner-prod`'s `firewall-1`. "Backups" section updated with the confirmed-not-enabled status and cross-reference to T-0001. "Open questions" section: removed items #1 (Hetzner Cloud Firewall ID) and #2 (Hetzner snapshot backups); kept canonical-short-host-id, role, known_hosts items; added new "Hetzner server protection flags" item pointing to T-0086. "What needs to happen" item #2 rewritten: "Audit complete 2026-06-27 … finding: project 15130993 has zero Cloud Firewalls; server exposed at cloud layer with only UFW + fail2ban. T-0085 done. Follow-on T-0086 created." Item #7 rewritten: "Audit complete 2026-06-27 (incidental to firewall audit probe C) — backup_window='' confirms NOT enabled." "Open tasks affecting this host" section: added T-0085 (done) and T-0086 (observation) rows. Change log: appended one row dated 2026-06-27 describing the audit outcome. | 2026-06-27 (unchanged — file was already verified today by step-02) |
| [landscape/secrets-inventory.md](../landscape/secrets-inventory.md) | Frontmatter `last_verified: 2026-05-26` → `2026-06-27` (32-day staleness resolved). Inventory row for `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`: removed trailing housekeeping placeholder ("SHA-256 fingerprint below in 'Cloudflare read-only token' style section — to be added on next housekeeping pass"); Last rotated date `2026-06-27` preserved (token was provisioned today and not yet rotated). New section "Hetzner ai-qadam token — identifying metadata (safe to commit)" added after the Cloudflare metadata section, mirroring its structure: Token name, SHA-256 fingerprint (`fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`), scope (`project_id 15130993` only, NOT `12287574` which is served by the separate `hetzner-api-token:ai-dala-infra:read-write` token), verified-active date `2026-06-27`. | 2026-06-27 |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| [T-0085](../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) | in-progress | done | succeeded |

T-0085 changes:
- Frontmatter: `status: done`, `closed: 2026-06-27`, `updated: 2026-06-27`, `outcome: succeeded`. `related:` array now includes `T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1`.
- "What done looks like": all 6 boxes checked (`[x]`). Note added to the token-verify checkbox explaining the probe-A substitution (`GET /v1/projects` is not accessible to project-scoped tokens; substituted with two project-scoped GETs that returned HTTP 200).
- "Result" populated with: outcome, key facts (token, project firewalls count, server status), deviation from probe plan, and links to executor/validator/landscape-updater handoffs + the new T-0086 follow-on.
- "Notes" retained and augmented with adjacent captured facts (Backups NOT enabled, protection flags at Hetzner defaults).
- "History": appended `2026-06-27: status → done, outcome succeeded, run 2026-06-27-audit-hetzner-firewall-001, commit <pending>`. Placeholder `<pending>` to be filled at commit time by the orchestrator or the user.

### Task files created (read-only runs surfacing new issues)

| New task ID | kind | priority | affects | source finding |
|---|---|---|---|---|
| [T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1](../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) | observation | P1 | landscape/hosts/ubuntu-16gb-nbg1-1.md, landscape/services.md | The audit's primary finding: project 15130993 has zero Hetzner Cloud Firewalls; server exposed at the cloud layer with only UFW + fail2ban protection. Per the documented default-exposure language, the server is reachable on all ports from the public internet. The audit cannot (and did not) apply a Cloud Firewall — that is a state-changing workflow requiring human approval (medium blast radius — risk of locking out management if management IP omitted). The new observation task tracks the follow-on; promoting to a state-changing workflow run is the user's decision. |

T-0086 contents:
- Frontmatter: `kind: observation`, `status: observation`, `priority: P1`, `created_by: 2026-06-27-audit-hetzner-firewall-001`, `source_runs: [2026-06-27-audit-hetzner-firewall-001]`, `affects: [landscape/hosts/ubuntu-16gb-nbg1-1.md, landscape/services.md]`, `related: [T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1]`, `estimated_blast_radius: medium`, `estimated_reversibility: full`.
- "Why" quotes the audit's default-exposure finding and links to T-0085 and `landscape/hosts/ubuntu-16gb-nbg1-1.md`.
- "What done looks like": 10 unchecked boxes for the future state-changing workflow's acceptance criteria (firewall created in project 15130993; inbound TCP 22 from management IP `178.89.57.135`; optional TCP 80/443 from `0.0.0.0/0` and `::/0`; outbound default; applied to server_id `145542849`; pre/post-reachability tests; landscape update mirroring `hetzner-prod` pattern; consideration of `protection.delete=True` / `protection.rebuild=True` as defense-in-depth).
- "Result": `<empty until promoted to state-changing workflow and run>`.
- "Notes": cross-reference to `hetzner-prod`'s `firewall-1` pattern; token-usage notes for the future POST operations; risk consideration (lockout mitigation via Hetzner Console and KVM-over-IP); workflow-shape suggestion (`infrastructure`).
- "History": `- 2026-06-27: created from discovery run 2026-06-27-audit-hetzner-firewall-001`.

### tasks/_index.md

- Updated: yes
- Rows changed: 3 (T-0085 transitioned in-progress → done, moved from in-progress/P1 to done/P1 at correct id-ordered position; T-0086 added in observation/P1 at correct id-ordered position; pre-existing formatting bug at the old line 42 — where T-0084 + T-0085 + T-0081 were concatenated on one display line — fixed by full table rewrite into proper one-row-per-line format).
- Table re-sorted: yes (open statuses first: observation / pending / in-progress / blocked / failed; then done / wontfix / superseded; within each by priority then id; 90 lines total).
- New shape: T-0086 sits in observation/P1 between T-0058 and T-0021 (id-ordered within P1). T-0085 sits in done/P1 immediately after T-0084 (id-ordered within P1). All other rows preserved unchanged.

### Diff summary

- **[landscape/hosts/ubuntu-16gb-nbg1-1.md](../landscape/hosts/ubuntu-16gb-nbg1-1.md)**: Multiple targeted edits. "Hardware & OS" now records the verified Hetzner Cloud Firewall state (NONE applied), Hetzner Backups state (NOT enabled), and refined Location (`nbg1-dc3`). A new top-level "Hetzner Cloud Firewall" section provides the full audit context (probe, default-exposure language, recommendation, cross-reference). "Backups" section updated with the confirmed-not-enabled status. "Open questions" items #1 (Cloud Firewall ID) and #2 (snapshot backups) removed (resolved); new "Hetzner server protection flags" item added. "What needs to happen" item #2 reflects audit-complete + follow-on-T-0086; item #7 reflects audit-complete + user-decision-pending. "Open tasks affecting this host" lists T-0085 (done) and T-0086 (observation). Change log gained one row describing the audit outcome.

- **[landscape/secrets-inventory.md](../landscape/secrets-inventory.md)**: Frontmatter `last_verified` bumped to `2026-06-27`. The `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` row lost its trailing housekeeping placeholder. A new bottom section "Hetzner ai-qadam token — identifying metadata (safe to commit)" mirrors the existing Cloudflare section, with token name, SHA-256 fingerprint, scope (project_id 15130993 only), and verified-active date.

- **[tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md](../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md)**: Closed as done/succeeded. All 6 acceptance criteria checked. "Result" populated with outcome summary, key facts, deviation note (probe-A substitution), and links to handoffs and follow-on T-0086. History entry appended with `<pending>` commit hash placeholder.

- **[tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md](../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md)** (new): P1 observation task. Acceptance criteria for the future state-changing workflow laid out (firewall create + inbound rules + applied_to + reachability tests + landscape update). Notes capture pattern reference (`firewall-1` on `hetzner-prod`), token-usage notes, lockout risk mitigation, and workflow-shape suggestion.

- **[tasks/_index.md](../tasks/_index.md)**: Full table rewrite to fix the malformed 3-rows-on-one-line formatting bug at the previous line 42 (T-0084 + T-0085 + T-0081 concatenated). T-0085 moved from in-progress/P1 to done/P1 (at id-ordered position after T-0084). T-0086 added in observation/P1 (at id-ordered position after T-0058). All other rows preserved unchanged.

### Files intentionally NOT updated

- **[landscape/services.md](../landscape/services.md)** — in scope per the user's prompt (T-0086's `affects:` lists it) but no actual content change is warranted by this audit. The audit did not introduce or remove any services; it only discovered an absence of a Cloud Firewall. T-0086's `affects:` inclusion is forward-looking (the future firewall-apply workflow may add firewall-related notes to services.md). T-0086 task frontmatter is acceptable as-is; step 08 will not pre-emptively touch services.md.
- **[landscape/hosts/hetzner-prod.md](../landscape/hosts/hetzner-prod.md)** — referenced as the pattern for the recommended firewall; no factual change. The existing "Network" section entry for `firewall-1` (id=10145783) is unchanged and is correctly cited as the model to mirror.
- **[landscape/cloudflare.md](../landscape/cloudflare.md)**, **[landscape/domains.md](../landscape/domains.md)** — not affected; the audit was Hetzner-API-only and the host has no DNS or Cloudflare zones yet.
- **[landscape/README.md](../landscape/README.md)** — no host added/removed (ubuntu-16gb-nbg1-1 was already in the Files table as populated per run `2026-06-27-discovery-host-001`); no update required.
- **Any file under `runs/`** — audit trail is immutable; the executor's findings live in `step-06-executor-discovery.md` and `step-07-execution-validator.md`, which are unchanged.
- **[landscape/secrets-inventory.md](../landscape/secrets-inventory.md)** other than the three changes listed above — pre-existing drift (the `gitea:admin-password` row still contains the literal password value `eT96ulleryIpd38VJeQNRGm3lQ3qcUO3`) is out of scope for this run per the user's prompt and was already noted by step-03 task-validator. Not touched.

## Issues / risks

- None new from this landscape-update step. All drift surfaced by the audit (zero Cloud Firewalls in project 15130993; Backups option NOT enabled; protection flags at Hetzner defaults) is documented either in `landscape/hosts/ubuntu-16gb-nbg1-1.md` (the new "Hetzner Cloud Firewall" section, the updated "Backups" section, the new "Open questions" item) or in `tasks/T-0086` (the follow-on observation task). None require landscape mutation outside of what was done.

- **Pre-existing formatting bug in `tasks/_index.md`** (line 42 had three rows concatenated: T-0084 + T-0085 + T-0081 on one display line) was fixed as part of the full table re-sort required for this run's T-0085 transition. No semantic change — purely formatting — but worth recording since it was found incidentally while preparing the update.

- **The `_index.md` line count went from 87 to 90** because the three concatenated rows on the old line 42 are now three separate rows (a net +2 line change: -1 from splitting the joined row, +3 from separating its three constituents, but one row was already an existing valid row in its own right — net is +2 because the old joined line had 3 entries on 1 line = 2 saved separators, and we now have 3 entries on 3 lines = no saved separators → +2).

- **The T-0085 and T-0086 History rows contain the literal `<pending>` placeholder for the commit hash** per the landscape-updater convention. The orchestrator or the user should replace these at commit time.

## Open questions (optional)

- (For the orchestrator at run finalization) The T-0085 History row and T-0086 file reference `<pending>` commit-hash placeholders. These should be filled at commit time.
- (For the user) The actual firewall-apply — opening a state-changing workflow run with design + approval — is a user decision triggered by the existence of T-0086. The observation task will remain in `observation` status until the user promotes it.
- (For the user) The Hetzner server protection flags (`protection.delete=False`, `protection.rebuild=False`) are at Hetzner defaults. T-0086's "What done looks like" item #10 raises enabling both as defense-in-depth; bundling with the firewall-apply or splitting is the user's call.
- (For the user / orchestrator at next opportunity) The pre-existing `landscape/secrets-inventory.md` drift (the `gitea:admin-password` row contains the literal password value `eT96ulleryIpd38VJeQNRGm3lQ3qcUO3`, violating the file's own "Never put secret values in this file" rule) remains out of scope per the user's prompt. Surface as a separate cleanup task if desired.
