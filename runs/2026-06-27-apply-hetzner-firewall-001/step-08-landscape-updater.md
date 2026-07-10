---
run_id: 2026-06-27-apply-hetzner-firewall-001
step: "08"
agent: landscape-updater
verdict: PASS
created: 2026-06-27T07:50:00Z
task_id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-apply-hetzner-firewall-001/step-04-solution-designer.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-06-executor-infra.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-07-execution-validator.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - tasks/_index.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-06-27-install-fail2ban-001/step-08-landscape-updater.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-08-landscape-updater.md
artifacts_changed:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - tasks/_index.md
next_step_hint: Orchestrator — run complete; finalize git commit + push (commit hash placeholder in T-0086 History entry to be filled at commit time).
---

## Summary

Landscape is now in sync with the verified end state of run `2026-06-27-apply-hetzner-firewall-001`: Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`) is applied to server `145542849` (`ubuntu-16gb-nbg1-1`) with a single inbound rule TCP 22 from `178.89.57.135/32`; server protection flags `protection.delete=true` and `protection.rebuild=true` are enabled. [landscape/hosts/ubuntu-16gb-nbg1-1.md](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) reflects the new cloud-layer posture (replaced "NONE applied" with the verified firewall facts, added a network-path note to the UFW section, resolved the remaining "Hetzner server protection flags" open question, marked "What needs to happen" item #2 done, updated "Open tasks affecting this host" entry, appended a change-log row); [tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) transitioned `in-progress` → `done` / `outcome: succeeded` / `closed: 2026-06-27` with all 11 acceptance-criteria checkboxes checked and the Result section populated; [tasks/_index.md](../../tasks/_index.md) re-sorted with T-0086 moved from `task / pending / P1` to `task / done / P1` (placed immediately after T-0085 in id-ascending order). `landscape/services.md` was inspected and confirmed to need no change (firewall is host-scoped, not a service).

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| [landscape/hosts/ubuntu-16gb-nbg1-1.md](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) | "Hardware & OS" — "Hetzner Cloud Firewall" bullet rewritten from "NONE applied" to APPLIED state (firewall name `ai-qadam-mgmt-ssh`, id `11204449`, project 15130993, scoped to server 145542849, single inbound rule TCP 22 from `178.89.57.135/32`, cross-references to the new "Hetzner Cloud Firewall" section and T-0086/done). New "Server protection flags" bullet added (both flags `true`, enabled 2026-06-27 as defense-in-depth). "Network" — UFW ruleset bullet augmented with the cloud-layer-firewall network-path note (public internet → Hetzner Cloud Firewall → UFW → fail2ban → sshd; inbound TCP 22 from `178.89.57.135` at the cloud layer; all other inbound blocked at the cloud layer). "Hetzner Cloud Firewall" section entirely rewritten with the post-apply facts (status APPLIED, project/firewall/server id triple, inbound rule, outbound default, labels, created timestamp 2026-06-27T07:14:31Z, Hetzner API verification path, protection flags enabled, lockout mitigation note). "Open questions" section — the "Hetzner server protection flags" item removed (resolved by this run); remaining items (canonical short `host_id`, role, ED25519 fingerprint) unchanged. "What needs to happen" — item #2 rewritten with both runs (audit + apply) and the firewall/protection flag outcomes, marked ✅ done with both T-0085 and T-0086 cross-references; other items unchanged. "Open tasks affecting this host" — T-0086 entry updated from "observation (follow-on to T-0085)" to "done (run 2026-06-27-apply-hetzner-firewall-001; firewall `ai-qadam-mgmt-ssh` id `11204449` applied; server protection flags enabled)". Change log: new row appended for the run. | 2026-06-27 (already today's date; no bump required per spec — see precedent in [runs/2026-06-27-install-fail2ban-001/step-08-landscape-updater.md](../../runs/2026-06-27-install-fail2ban-001/step-08-landscape-updater.md)) |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| [T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md) | in-progress | done | succeeded |

T-0086 changes:
- Frontmatter: `status: in-progress` → `status: done`, `outcome: succeeded`, `closed: 2026-06-27`, `updated: 2026-06-27`.
- "What done looks like": all 11 acceptance-criteria checkboxes marked `[x]` (pre-flight IP, firewall created with name, inbound rule from `178.89.57.135/32`, no other inbound ports, outbound default, applied_to server 145542849, protection flags enabled, post-apply SSH verification, host landscape update, services.md confirm, index re-sort).
- "Result" section populated with: outcome summary (attempt 3 PASS), firewall facts (name/id/rule/created timestamp/labels), server protection flag facts (action ID `638945111775820`, HTTP 201, synchronous terminal), SSH reachability (post-apply + independent re-probe both True), functional SSH confirmation (hostname + date + fail2ban active + ufw active), deviation note (none material; body-shape bugs corrected mid-run and saved to repo memory for future runs), links to executor + validator handoffs, landscape impact narrative naming both updated files.
- "History": appended `2026-06-27: status → done, outcome succeeded, run 2026-06-27-apply-hetzner-firewall-001, commit <pending>`. The `<pending>` commit-hash placeholder will be filled by the orchestrator/user at commit time per spec.

### Task files created (read-only runs surfacing new issues)

None — this is a state-changing run; the run did not surface any new observations.

### tasks/_index.md

- Updated: yes
- Rows changed: 1 (T-0086 row physically moved from the `pending / P1` block, where it appeared between T-0077 (pending/P1) and T-0026 (pending/P2), to the `done / P1` block, inserted immediately after T-0085 — the natural id-ascending position, since T-0086 > T-0085 > T-0084 > T-0083 are all P1 done entries in this block).
- Table re-sorted: yes (no other rows touched; the table is already sorted correctly within each status group by priority then id per the precedent set by the audit landscape-updater).
- Format check: one row per line, no multi-row-on-one-line formatting bugs (the previous bug at line 42 was fixed by the audit landscape-updater run).
- Pre-existing index inaccuracy noted (informational): T-0086 was listed as `status: pending` in the index before this update, while the task file frontmatter said `status: in-progress`. This inconsistency originated from the run start (T-0086 was promoted from observation to task/pending by [tasks/.promotions/T-0086-promotion-2026-06-27.md](../../tasks/.promotions/T-0086-promotion-2026-06-27.md) but the index did not get updated when the run began and the task file frontmatter transitioned to `in-progress`). Both surfaces are now consistent at `status: done`.

### Diff summary

**[landscape/hosts/ubuntu-16gb-nbg1-1.md](../../landscape/hosts/ubuntu-16gb-nbg1-1.md)** — Multiple targeted edits. "Hardware & OS" bullets for "Hetzner Cloud Firewall" and "Server protection flags" replaced with the post-apply facts (firewall APPLIED with id/name/rule; protection flags true/true; defense-in-depth rationale). "Network" UFW ruleset bullet augmented with the cloud-layer network-path note. "Hetzner Cloud Firewall" section entirely rewritten — gone is the "NONE applied" audit-state language; in its place are the verified post-apply facts (firewall name/id/rule/outbound/labels/created timestamp, Hetzner API verification path, server protection flags enabled, lockout mitigation note). "Open questions" lost the "Hetzner server protection flags" item (resolved by this run); the three remaining items (canonical short `host_id`, role, ED25519 fingerprint) preserved. "What needs to happen" item #2 rewritten with both runs (audit + apply) and the firewall/protection flag outcomes; marked done with both T-0085 and T-0086 cross-references. "Open tasks affecting this host" T-0086 entry updated to done. Change log gained one row describing the run outcome (firewall id, rule, protection flags, run_id, attempt count, body-shape-bug-fix note).

**[tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md](../../tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md)** — Frontmatter transitioned `status: in-progress` → `status: done`, `outcome: succeeded`, `closed: 2026-06-27`. All 11 acceptance-criteria boxes marked `[x]`. "Result" section populated with the attempt-3 PASS outcome, the firewall facts (name/id/rule/created timestamp/labels), the server protection flag facts (action ID, HTTP 201, synchronous terminal), the SSH reachability + functional SSH confirmation (lockout risk did not materialize), the deviation note (no material deviations; body-shape bugs corrected mid-run and preserved in repo memory), links to executor + validator handoffs, and a landscape-impact paragraph naming both updated files. "History" appended with the new `done` entry (commit hash `<pending>` to be filled at commit time).

**[tasks/_index.md](../../tasks/_index.md)** — T-0086 row physically moved from the `pending / P1` block to the `done / P1` block, inserted immediately after T-0085 in id-ascending order. The row's `status:` column updated from `pending` to `done` (matching the task file frontmatter). No other rows touched; sort order is correct within each status group (open statuses first: observation > pending > in-progress > blocked > failed; then done > wontfix > superseded; within each by priority then id).

### Files intentionally NOT updated

- **[landscape/services.md](../../landscape/services.md)** — explicitly inspected per the user's prompt. The firewall is host-scoped cloud-API configuration, not a service. The `## ubuntu-16gb-nbg1-1` section in services.md covers native systemd units (ssh, chrony, unattended-upgrades, qemu-guest-agent, cloud-init, snapd, apparmor, systemd-resolved, etc.), and the Hetzner Cloud Firewall does not add, remove, or change any of those. No service is added/removed by this cloud-API-only change. T-0086's `affects:` includes services.md forward-looking (in case a future firewall-apply workflow adds firewall-related notes); for this minimal SSH-only rule set, no change is warranted.
- **[landscape/hosts/hetzner-prod.md](../../landscape/hosts/hetzner-prod.md)** — referenced as the pattern for `firewall-1` (id `10145783`); not affected by this run. The existing entry for `firewall-1` in hetzner-prod's Network section is unchanged and remains the canonical reference for the prod Cloud Firewall posture.
- **[landscape/secrets-inventory.md](../../landscape/secrets-inventory.md)** — token file fingerprint (`fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`) is unchanged; validator independently re-confirmed it 2026-06-27 (per step-07). No rotation occurred in this run. The fingerprint slot does not need an update; `last_verified` was already bumped to 2026-06-27 by the audit landscape-updater run.
- **[landscape/cloudflare.md](../../landscape/cloudflare.md)**, **[landscape/domains.md](../../landscape/domains.md)** — not affected; this host has no DNS or Cloudflare zones yet.
- **[landscape/README.md](../../landscape/README.md)** — not affected; no host added/removed and no change to the managed-systems table.
- **[landscape/cloudflare.md](../../landscape/cloudflare.md)** — not affected for the same reason.
- **[shared/app-registry.md](../../shared/app-registry.md)**, **[shared/approval-protocol.md](../../shared/approval-protocol.md)**, **[workflows/*](../../workflows/)** — not affected.
- **[tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md](../../tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md)** — not affected; T-0085 was closed by the audit landscape-updater run and is already in done state. The fact that T-0086 is now also done does not change T-0085.
- **[tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md](../../tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md)** — not affected; T-0082 is the parent inventory task which remains in-progress pending role assignment. T-0086 closing does not change T-0082's status (T-0082's "done" criteria include role assignment + follow-on hardening, not firewall apply).
- **[tasks/T-0002-add-host-firewall.md](../../tasks/T-0002-add-host-firewall.md)**, **[tasks/T-0005-install-fail2ban.md](../../tasks/T-0005-install-fail2ban.md)** — these are prod-side equivalents and are unaffected by this run.
- **Any file under `runs/`** — audit trail is immutable; the executor + validator handoffs are not modified by step 08.

## Cross-checks

- **Landscape internal consistency:**
  - "Hardware & OS" `Hetzner Cloud Firewall: APPLIED` bullet is consistent with the new "Hetzner Cloud Firewall" section body (same id/name/rule/labels/created timestamp/protection flags).
  - "Hardware & OS" `Server protection flags: true/true` bullet is consistent with the "Hetzner Cloud Firewall" section's `Server protection flags enabled` bullet (same fact, two locations).
  - "Network" UFW ruleset bullet's network-path note (cloud layer → UFW → fail2ban → sshd) is consistent with the "Hetzner Cloud Firewall" section's `Lockout mitigation` note (management IP scoped) and the "What runs here" → "Access" → "SSH hardening tooling on host" note (fail2ban active).
  - "What needs to happen" item #2 marked done with both T-0085 and T-0086 references; the audit run is the parent task in T-0086's `related:` array, so the cross-reference is bidirectional and consistent.
  - "Open tasks affecting this host" T-0086 entry says "done (run 2026-06-27-apply-hetzner-firewall-001)" — matches the index row (`status: done`, `updated: 2026-06-27`) and the task file frontmatter (`status: done`, `closed: 2026-06-27`, `outcome: succeeded`).
  - Change-log row appended at the bottom of the table, after the audit-run row, consistent with the chronological convention used by previous landscape-updater runs.
- **Task file internal consistency:**
  - Frontmatter `status: done` + `closed: 2026-06-27` + `outcome: succeeded` are mutually consistent (per `shared/verdicts.md` vocabulary and the precedent set by closed tasks in `tasks/_index.md`).
  - "What done looks like" checkboxes all checked; "Result" populated — these together demonstrate task completion.
  - History entries are chronologically ordered (created → promoted → in-progress → done).
- **Index internal consistency:**
  - T-0086 row in done/P1 block is placed immediately after T-0085 (highest P1 done ID before this update); sort order is correct.
  - One row per line; no multi-row-on-one-line formatting bugs.
  - All other rows unchanged.

## Issues / risks

- **Pre-existing index inaccuracy (informational, now resolved).** Before this update, the T-0086 row in [tasks/_index.md](../../tasks/_index.md) showed `status: pending` while the task file frontmatter showed `status: in-progress`. This originated when the run started: the task-promotion record [tasks/.promotions/T-0086-promotion-2026-06-27.md](../../tasks/.promotions/T-0086-promotion-2026-06-27.md) updated the task file to `kind: task / status: pending`, but the index was not re-sorted at that point, and when the run began the task file frontmatter transitioned to `status: in-progress` without a corresponding index update. Both surfaces are now consistent at `status: done`. This was a minor cosmetic drift between the audit/run-start and the landscape-update; no semantic impact.

- **No new issues / risks from this landscape-update step.** The landscape-updater's job was a diff-minimal reconciliation between the executor's verified end state and the existing landscape. No conflicts were found between the validator's findings (PASS, all four target end-states independently re-verified) and the existing landscape claims. The two non-trivial adaptations in the executor's run (body-shape bug corrections for `rules` array and `apply_to` field) are documented in the run's audit trail and in repo memory at `memories/repo/hetzner-firewall-api.md` for future runs; they have no impact on the final landscape state.

- **T-0086 History entry contains the literal `<pending>` placeholder** for the commit hash per the landscape-updater convention. The orchestrator or the user should replace this at commit time.

- **No secret values introduced into any file.** The Hetzner API token is referenced by name and SHA-256 fingerprint only (`hetzner-api-token:ai-dala-infra:ai-qadam-read-write`, fingerprint `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`); no token VALUE appears in any landscape or task file. The validator independently re-confirmed the fingerprint matches the on-disk token file.

- **The "SSH hardening pending" annotation in the "Network" section's TCP listeners table (Port 22 row)** remains accurate — the Cloud Firewall protects inbound SSH at the cloud layer, but the sshd daemon itself still has `PasswordAuthentication yes` (cloud-init default) and `PermitRootLogin yes` (default). This is unchanged by the firewall-apply run and is captured by the open sshd-hardening item #4 in "What needs to happen" (not affected by this update).

- **Open questions left untouched:** the three remaining items in [landscape/hosts/ubuntu-16gb-nbg1-1.md](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) "Open questions" (canonical short `host_id`, role, ED25519 fingerprint on management workstation's `known_hosts`) are all user-decision-pending and were not addressed by this run. The "ED25519 fingerprint" item's description ("should be reconciled against `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`") is now satisfied implicitly — the fingerprint is already recorded and is not modified by this run; only the cosmetic reconciliation step is pending (out of scope).

## Open questions

None for step 08. The orchestrator should finalize the run with `git add` + commit + push (the user/commit author will replace the `pending` placeholder in T-0086's History entry at run-finalization time per the spec).
