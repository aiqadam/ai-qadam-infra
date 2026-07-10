---
step: 08
agent: landscape-updater
run_id: 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
task_id: T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
verdict: PASS
inputs_read:
  - runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-04-solution-designer.md
  - runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-06-executor-infra.md
  - runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-07-execution-validator.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md
  - tasks/_index.md
---

# Step 08 — landscape-updater

## Summary
Landscape updated to reflect T-0096 done: `auditd 1:4.1.2-1build1 + audispd-plugins` installed on `pro-data-tech-qa` with project CIS-derived ruleset (15 keys, 67 kernel rules), daemon active+enabled, kernel audit subsystem loaded (CONFIG_AUDIT=y built-in). Task T-0096 closed `done/succeeded` and follow-up observation T-0096a created for the immutable-flag (`-e 2`) 24h-soak + lock step.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| `landscape/hosts/pro-data-tech-qa.md` | frontmatter (last_verified_note); "## Access / SSH hardening tooling on host" (auditd installed added); "## Security posture" (auditd line rewritten from "NOT installed" to full T-0096 state); "## What needs to happen" item #6 (✅ done with run link); "## Open tasks affecting this host" (T-0096 line replaced with done-summary); "Change log" (new T-0096 row) | 2026-07-10 |
| `landscape/services.md` | frontmatter (last_verified_note); pro-data-tech-qa → "## Apt posture" (new "Kernel audit subsystem" bullet); pro-data-tech-qa → "## Native systemd services of note" (new `auditd.service` row); "## Change log" (new T-0096 row) | 2026-07-10 |

### Task files updated (state-changing run)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa | in-progress (last in history) | done | T-0096 done 2026-07-10 via run 2026-07-10-enable-auditd-on-pro-data-tech-qa-001. auditd 1:4.1.2-1build1 installed with project CIS-derived ruleset (15 keys, 67 kernel rules), daemon active+enabled, kernel audit subsystem loaded. 8/9 V-checks PASS; V07 PARTIAL with documented architectural rationale. Pre-install snapshot preserved at /var/backups/pre-T0096.20260710T123137Z/. Immutable flag (-e 2) deferred to follow-up T-0096a. |

### Task files created (follow-up observation)

| New task ID | kind | priority | affects | source finding |
|---|---|---|---|---|
| T-0096a-set-auditd-immutable-flag-after-24h-soak | observation | P3 | landscape/hosts/pro-data-tech-qa.md | T-0096 (step-06 executor) noted the ruleset was deliberately written without `-e 2` so debugging a misconfigured rule wouldn't require a reboot; CIS recommends locking the ruleset via `auditctl -e 2` after a soak confirms stability |

### tasks/_index.md
- Updated: yes
- Rows changed: 3 (T-0096 transitioned `pending` → `done`; T-0096a inserted at correct sorted P3 observation position between T-0053 and T-0098; T-0096 done row added to done block at P3 position adjacent to T-0066)

### Diff summary

**`landscape/hosts/pro-data-tech-qa.md`** — The host file now describes the host as having auditd installed (T-0096) rather than deferring it (T-0088 / observation pre-T-0096). Frontmatter `last_verified_note` rewritten from a T-0099 (kernel-upgrade) summary to a T-0096 (auditd) summary. The `## Access / SSH hardening tooling on host` bullet that previously read "auditd NOT installed ([T-0096], deferrable per T-0088)" now reads "auditd installed 2026-07-10 (T-0096, 8/9 V-checks PASS) — see Security posture section for full configuration". The `## Security posture → auditd:` bullet now contains the full T-0096 state in one line: package version + audispd-plugins, daemon state, ruleset path & permissions, merged file location, audit log location & permissions, kernel-subsystem proof, immutable-flag deferral to T-0096a, pre-install snapshot path, and a pointer to the run dir. The "## What needs to happen" item #6 was repointed from "⏳ deferrable per T-0088" to "✅ DONE 2026-07-10 via run ... with full state". The "## Open tasks affecting this host" T-0096 line was replaced with a done-summary. A "Change log" row for 2026-07-10 / T-0096 was added.

**`landscape/services.md`** — Frontmatter `last_verified_note` rewritten from a T-0099 (kernel-upgrade) summary to a T-0096 (auditd) summary. The pro-data-tech-qa "## Apt posture" section gained a new bullet documenting that the kernel audit subsystem is `CONFIG_AUDIT=y` built-in to kernel 7.0.0-27-generic (post-T-0099) — this is the kernel-layer evidence that auditd has a subsystem to attach to. The pro-data-tech-qa "## Native systemd services of note" table gained a new `auditd.service` row with full state (path, user, what it does, audit-log perms, `kauditd` thread evidence, T-0096 provenance, key/rule summary). The "## Change log" table gained a new 2026-07-10 row for T-0096 (full state in 1 cell).

**`tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md`** — Closed: frontmatter `status: in-progress → done`, added `closed: 2026-07-10`, `outcome:` populated with the full closing summary. History entry appended (`- 2026-07-10: status → done, outcome succeeded (run ..., 8/9 V-checks PASS, 1 PARTIAL with documented rationale; in-place stime-syscall fix applied; project ruleset loaded, audit subsystem verified)`). All 6 "What done looks like" acceptance checkboxes ticked (`[x]`) with concrete evidence in the parentheticals. "## Result" section populated with 4 numbered subsections: §1 "What was done" (auditd install + ruleset + in-place stime fix + event coverage + pre-install snapshot); §2 "Deviations from the original plan" (3 items: out-of-band pre-install; stime fix in-place; V07 PARTIAL with documented rationale); §3 "Follow-up work" (points at T-0096a); §4 "Links" (points at the 3 upstream run handoffs + this file).

**`tasks/T-0096a-set-auditd-immutable-flag-after-24h-soak.md`** — Created from the task template. Frontmatter: `kind: observation`, `status: observation`, `priority: P3`, `created_by: 2026-07-10-enable-auditd-on-pro-data-tech-qa-001`, `source_runs: [<that>]`, `affected: landscape/hosts/pro-data-tech-qa.md`, `blocked_by: [T-0096]`, `related: [T-0096]`, `estimated_blast_radius: low`, `estimated_reversibility: partial`. Body: "Why" section explains the rationale (deferral for debug-friendliness; CIS recommends locking after soak); "What done looks like" checklist (7 items including the 24h wait, the `auditctl -e 2` invocation, the verification of `enabled 2`, and the landscape-update step); "Notes" (24h earliest 2026-07-11; 8-step workflow still required despite being a 1-command change). History has one entry: created as observation by T-0096 run on 2026-07-10.

### Files intentionally NOT updated

- `landscape/hosts/hetzner-prod.md` — T-0047 (auditd for hetzner-prod) remains an open observation; T-0096 is the pro-data-tech-qa equivalent, separate host.
- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — No auditd task exists for this host; out of T-0096 scope.
- `landscape/hosts/` siblings — only pro-data-tech-qa was touched by T-0096.
- `landscape/cloudflare.md`, `landscape/domains.md`, `shared/secrets-inventory.md`, `shared/app-registry.md` — T-0096 was a host-internal install; no DNS, secrets, or app-registry changes.
- `landscape/README.md` — No new policies or sections added by T-0096.
- `workflows/` — T-0096 followed the existing infrastructure workflow unchanged.

## Issues / risks
None.

## Verdict
**PASS** — Landscape is now in sync with the verified reality (T-0096 successfully installed auditd on pro-data-tech-qa; the validator independently re-verified all 9 V-checks). Task T-0096 closed `done/succeeded` per the run's evidence. Follow-up T-0096a observation created with an actionable acceptance checklist and a 24h earliest-action date.
