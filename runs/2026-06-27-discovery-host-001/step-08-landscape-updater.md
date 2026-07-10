---
run_id: 2026-06-27-discovery-host-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-06-27T05:30:00Z
inputs_read:
  - runs/2026-06-27-discovery-host-001/step-02-landscape-reader.md
  - runs/2026-06-27-discovery-host-001/step-06-executor-discovery.md
  - runs/2026-06-27-discovery-host-001/step-07-execution-validator.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/README.md
  - landscape/secrets-inventory.md
  - tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md
  - tasks/_template.md
  - tasks/_index.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/README.md
  - tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md
  - tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md
  - tasks/_index.md
next_step_hint: Run complete; orchestrator may finalize the run (commit hash placeholder for task files to be filled at commit time).
retry_of: ~
---

## Summary

Updated the landscape to reflect the verified findings of discovery run `2026-06-27-discovery-host-001`: replaced the `landscape/hosts/ubuntu-16gb-nbg1-1.md` stub with the populated body (status `stub` → `populated`), appended a `## ubuntu-16gb-nbg1-1` per-host section to `landscape/services.md`, refreshed the Files table in `landscape/README.md`, updated `landscape/services.md` frontmatter `last_verified` to today, transitioned `tasks/T-0082` to in-progress (without closing) and added a History row, created a new observation task `tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md`, and re-sorted `tasks/_index.md`.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| [landscape/hosts/ubuntu-16gb-nbg1-1.md](../landscape/hosts/ubuntu-16gb-nbg1-1.md) | Full file replacement (stub → populated). Frontmatter: `status: stub` → `status: populated`; `last_verified: 2026-06-27` (unchanged). Sections: replaced "Identity (provided by user)" with "Hardware & OS" (verified facts from probes B/C); rewrote "Access" (added all three SSH host key fingerprints RSA/ECDSA/ED25519, replaced "sudoers.d is empty" with drop-in present at mtime 2026-06-27 04:46, documented no project hardening yet); populated "What runs here" (per-host systemd services table); populated "Network" (UFW inactive, TCP/UDP listeners from probe G); populated "Backups" (no tooling); added "apt posture" section (13 pending upgrades, security + ESM only); added "Open questions" section (Hetzner Cloud Firewall ID unknown, snapshot backups unknown, host_id rename, role); updated "What needs to happen" (item #4 retired — drop-in already done; items renumbered; added sshd hardening and fail2ban as separate follow-ons); added "Open tasks affecting this host" section (links to T-0082, T-0083); added change-log row for this run. | 2026-06-27 |
| [landscape/services.md](../landscape/services.md) | Frontmatter `last_verified: 2026-06-10` → `2026-06-27`. New top-level section `## ubuntu-16gb-nbg1-1` with subsections `### Docker` (not installed), `### nginx` (not installed), `### Native systemd services of note` (table mirroring hetzner-prod's structure with this host's running services), `### Scheduled tasks` (stock cron + 18 stock systemd timers, no app-backup, no certbot). Appended one change-log row dated 2026-06-27. | 2026-06-27 |
| [landscape/README.md](../landscape/README.md) | Files table row for `hosts/ubuntu-16gb-nbg1-1.md`: "stub, awaiting discovery" → "populated by discovery run `2026-06-27-discovery-host-001` (see T-0082, in-progress)". | n/a (README has no frontmatter) |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0082 | in-progress | in-progress | (unchanged — read-only discovery run does NOT close the parent task) |

T-0082 frontmatter was already `status: in-progress` before this step (the orchestrator had pre-set it when assigning the discovery run to `executed_by_runs`). Per the user prompt and the landscape-updater rule, T-0082 is NOT closed by this discovery run — only the discovery component of "What done looks like" is satisfied. The remaining items (Hetzner Cloud Firewall audit, role assignment) depend on either a follow-on Hetzner-API workflow or a user decision.

Body changes to T-0082:
- Filled "Result" section with a one-line summary of this run pointing to this handoff file.
- Added a "related" link to T-0083 in frontmatter.
- Appended a History row for the discovery run completion.

### Task files created (read-only runs surfacing new issues)

| New task ID | kind | priority | affects | source finding |
|---|---|---|---|---|
| [T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1](../tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md) | observation | P1 | landscape/hosts/ubuntu-16gb-nbg1-1.md | Probe F (executor step-06 F10): `ufw` binary present but inactive, `nft` empty ruleset, `iptables`/`ip6tables` all chains at default ACCEPT — fresh internet-facing server with no host firewall protection between the public internet and any future service. Out-of-parity with `hetzner-prod` (UFW active since 2026-05-12 via T-0002). |

Why T-0083 and not also observation tasks for fail2ban / auditd / sshd hardening: per the user's prompt, the most actionable observation is UFW (concrete state-changing follow-on). fail2ban and sshd hardening are noted in the host file's "What needs to happen" list (items #4 and #5) as future state-changing workflows to be created when promoted, not as observation tasks — they have no findings beyond "not installed / defaults in place" and don't need observation tracking; they need direct execution.

The other observations flagged by the executor (no fail2ban, no auditd, no Hetzner Cloud Firewall ID, secrets-inventory.md 32 days old with embedded gitea admin password) are not converted to observation tasks at this time:
- `no fail2ban` / `no auditd`: covered by the host file's "What needs to happen" list with explicit work items; promoting now would be premature.
- `no Hetzner Cloud Firewall ID`: this is an open question for a follow-on Hetzner-API workflow run, not a state-changing action on the host itself.
- `secrets-inventory.md` drift: pre-existing, not introduced by this run, out of scope per the user prompt.

### tasks/_index.md

- Updated: yes
- Rows changed: 3 (added T-0083 in observation/P1; moved T-0082 from pending/P1 to in-progress/P1; T-0082's `affects` field unchanged)
- Table re-sorted: yes (open statuses first — observation / pending / in-progress — then done / wontfix / superseded; within each section by priority then id)

### Diff summary

- **landscape/hosts/ubuntu-16gb-nbg1-1.md**: stub body replaced with a populated host file modeled on [hetzner-prod.md](../landscape/hosts/hetzner-prod.md). The file now describes a freshly-provisioned Ubuntu 26.04 cloud image in Hetzner project "Al-Qadam" with verified OS, kernel, hardware, user, sudoers, sshd, firewall, listener, systemd, timer, and apt facts. All three SSH host key fingerprints recorded. The stub's "What needs to happen" item #4 (create `/etc/sudoers.d/90-tvolodi`) is marked done and replaced by item #3 (sshd hardening) and item #5 (fail2ban install). Hetzner Cloud Firewall ID, snapshot-backup status, host_id rename, and role assignment are open questions pending a Hetzner-API workflow run or user decision.

- **landscape/services.md**: added a new per-host `## ubuntu-16gb-nbg1-1` section noting "no project services, no Docker, no nginx" and listing the stock cloud-image systemd units + timers in the same table structure used for `hetzner-prod`. Frontmatter `last_verified` refreshed to 2026-06-27. Change log got one new row.

- **landscape/README.md**: one row in the Files table updated to reflect the host file is populated (not stub).

- **tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md**: status remains `in-progress`. Added a one-line Result entry pointing to this run, added T-0083 to the `related` field, appended a History entry for the discovery run completion. Not closed.

- **tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md** (new): observation task tracking the UFW enable follow-on. Includes acceptance criteria (deny-by-default, allow 22/80/443, persistence across reboot, live SSH re-verification), parity notes with T-0002, and a note that this task is independent of role assignment.

- **tasks/_index.md**: re-sorted with T-0083 in the observation/P1 section (after T-0058, before T-0021 in id order within P1) and T-0082 moved from pending/P1 to in-progress/P1.

### Files intentionally NOT updated

- `landscape/secrets-inventory.md` — pre-existing drift (32-day-old `last_verified`, embedded `gitea:admin-password` value) is out of scope for this discovery run per the user prompt; not touched.
- `landscape/hosts/hetzner-prod.md` — not affected by this run; cross-referenced only.
- `landscape/cloudflare.md`, `landscape/domains.md` — not affected; the new host has no DNS or proxied zones yet.
- `.github/copilot-instructions.md`, `.github/agents/*`, `.claude/agents/*` — no agent behavior change warranted by this run.
- `landscape/hosts/` other than `ubuntu-16gb-nbg1-1.md` — no other host files in scope.

## Issues / risks

- None new from this landscape-update step. All drift surfaced by the executor (sudoers drop-in pre-existence, duplicate ed25519 in `tvolodi`'s authorized_keys, ED25519 fingerprint reconciliation on management workstation, Hetzner API token scope for project 15130993) is documented either in the populated host file (Open questions section), in T-0083 (What done looks like), or in this handoff's notes — none require landscape mutation outside of what was done.
- The executor's "ED25519 fingerprint reconciliation" item (steps-07 open question) is NOT an issue for landscape-updater to resolve; it lives on the management workstation's `known_hosts`, not in this repo. Flagged in the host file's Open questions for the user to handle.
- `secrets-inventory.md` drift remains pre-existing and out of scope.

## Open questions (optional)

- (For the user) The "What needs to happen" items #2 (Hetzner Cloud Firewall audit) and #7 (Hetzner snapshot backups audit) both depend on a follow-on Hetzner-API workflow run that requires verifying that the existing `hetzner-api-token:ai-dala-infra:read-write` has access to project 15130993. Confirm whether the token should be scoped to both projects or whether a separate token should be provisioned.
- (For the user) Role assignment for `ubuntu-16gb-nbg1-1` is the gating decision for items #4 (sshd hardening) and #5 (fail2ban) — though the host file's notes already observe that those are independent of role and could be batched regardless.
- (For the orchestrator at run finalization) The T-0082 and T-0083 History rows contain the literal `<pending>` placeholder for the commit hash per the landscape-updater convention. The orchestrator or the user should replace these at commit time.
