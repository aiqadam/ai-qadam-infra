---
run_id: 2026-07-08-install-fail2ban-pro-data-tech-qa-001
step: "08"
agent: landscape-updater
verdict: PASS
created: 2026-07-08T18:30:00Z
task_id: T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-04-solution-designer.md
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-06-executor-infra.md
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-07-execution-validator.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md
  - tasks/_index.md
  - shared/handoff-format.md
artifacts_changed:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md
  - tasks/_index.md
next_step_hint: PASS — run is finalized; orchestrator should record commit hash in T-0095 frontmatter (replacing `<pending>`).
---

## Summary

Updated `landscape/hosts/pro-data-tech-qa.md` (Security posture fail2ban block, SSH hardening tooling note, "What needs to happen" #5 struck-through→done, Open tasks entry, change-log row, frontmatter `last_verified_note`); updated `landscape/services.md` (`## pro-data-tech-qa` bullet, systemd-units table row, change-log row, frontmatter `last_verified_note`); closed T-0095 (status in-progress→done, outcome filled, closed/updated dates, History entry, Result section); moved T-0095 from in-progress section to done/P2 section in `tasks/_index.md`.

## Details

### Landscape files updated

| File | Sections changed | last_verified set to |
|---|---|---|
| [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) | frontmatter `last_verified_note` (added fail2ban line); `## Access → SSH hardening tooling on host` (swapped fail2ban NOT installed → installed 2026-07-08 T-0095); `## Security posture → fail2ban` (replaced "NOT installed" line with the 7-line installed block — banaction, maxretry, findtime, bantime, ignoreip, logpath, backup, systemctl); `## Open questions → Hetzner-style hardening template parity` (kept — references fail2ban T-0095; no change needed); `## What needs to happen → #5` (⏳ → ✅ with run link); `## Open tasks affecting this host → T-0095` (strike-through + DONE blurb); `## Change log` (added row 2026-07-08 / 2026-07-08-install-fail2ban-pro-data-tech-qa-001 / T-0095 done) | 2026-07-08 |
| [landscape/services.md](../../landscape/services.md) | frontmatter `last_verified_note` (added fail2ban line); `## pro-data-tech-qa` open-bullets (added fail2ban sshd jail bullet between UFW and operator-users); `## pro-data-tech-qa → Native systemd services of note` (added fail2ban.service row after ufw.service, mirroring the same row used for ubuntu-16gb-nbg1-1); `## Change log` (added row 2026-07-08 / 2026-07-08-install-fail2ban-pro-data-tech-qa-001 / pro-data-tech-qa / fail2ban installed (T-0095)) | 2026-07-08 |

### Task files updated (state-changing runs)

| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0095 | in-progress | done | fail2ban 1.1.0-9 installed on 2026-07-08 via run 2026-07-08-install-fail2ban-pro-data-tech-qa-001. sshd jail active with iptables-multiport banaction; 7/7 verification checks passed. Mgmt workstation IP in ignoreip. |

### Task files created (read-only runs surfacing new issues)

None — this is a state-changing run, not a discovery run.

### tasks/_index.md

- Updated: yes
- Rows changed: 1 (T-0095)
  - Removed T-0095 from its prior in-progress-block position.
  - Inserted T-0095 (now `task | done | P2 | 2026-07-08`) into the P2 done block, immediately after T-0094 (T-0094-install-local-baseline-firewall-on-pro-data-tech-qa), preserving the priority→ID sort.
- Final state: exactly **1** T-0095 row in the index, status `done`, priority `P2`, in the correct section. Pre-existing duplicate T-0097 rows (lines 43 and 63) left untouched — out of scope for this diff.

### Diff summary

- **landscape/hosts/pro-data-tech-qa.md:** Security posture now lists fail2ban as installed with the iptables-multiport banaction, maxretry=3, findtime=600s, bantime=600s, ignoreip including the live mgmt workstation IP `178.89.57.135`, logpath `/var/log/auth.log` (with journalmatch fallback for 1.1.x), backup `/etc/fail2ban.pre-T0095.20260708T182109Z.bak/`, and `systemctl: active, enabled`. The "What needs to happen" checklist item #5 flipped from ⏳ to ✅ with a link to the install run; the "Open tasks" entry for T-0095 is strike-through and references the failing run. A new change-log row records the T-0095 close event.
- **landscape/services.md:** A new bullet under `## pro-data-tech-qa` records fail2ban sshd jail as active (600s ban after 3 attempts in 600s, iptables-multiport, UFW coexist unaffected). The systemd-units table gains a `fail2ban.service` row identical in shape to the `## ubuntu-16gb-nbg1-1` fail2ban row, customized for pro-data-tech-qa (installed 2026-07-08, ignoreip includes 178.89.57.135). A new change-log row records the T-0095 close event.
- **tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md:** Frontmatter flipped to `status: done`, `outcome:` filled with the executor-confirmed summary, `closed: 2026-07-08`, `updated: 2026-07-08`. History entry appended. The `## Result` section is now populated with: a full "what done looks like" checklist mapping (with the one accepted deviation noted — brute-force simulation was out of scope per the step-04 verification matrix, since T-0084 sibling already established live ban behavior with the same jail values), and links to both executor + validator handoffs.
- **tasks/_index.md:** T-0095 moved to the P2 done block at the correct sort position (right after T-0094).

### Files intentionally NOT updated

- **landscape/hosts/pro-data-tech-qa.md — `## Open questions → Hetzner-style hardening template parity` bullet:** references fail2ban T-0095 in the resolution text. Pre-existing answer; no semantic drift. Left unchanged (diff-minimal).
- **landscape/services.md — `## pro-data-tech-qa` intro paragraph line 186:** still contains the prior discovery narrative "...no host firewall, no fail2ban..." from the 2026-07-08 discovery run. The user's task brief did not authorize rewriting this paragraph; per diff-minimal rule, the existing bullet-level statements added under the open-bullets list above now overlay the correct state. Out of scope.
- **landscape/services.md — `## pro-data-tech-qa → Scheduled tasks` paragraph:** still says "**No `fail2ban.service`** (T-0095 pending)." This is now stale. The user's task brief listed only: Security posture block (in host file), bullet under `## pro-data-tech-qa` (in services.md), and change-log row. The scheduled-tasks line was not in scope. Diff-minimal: left alone. Note this for a future housekeeping pass.
- **landscape/services.md — `## ubuntu-16gb-nbg1-1 → Native systemd services of note` table:** the fail2ban.service row at line 171 still cites T-0084 + run 2026-06-27-install-fail2ban-001 — pre-existing, unrelated to pro-data-tech-qa.

## Issues / risks

None.

## Open questions (optional)

None for this run. Two diff-minimal items listed under "Files intentionally NOT updated" may be candidates for a future housekeeping task (e.g., folded into a T-0098 follow-up), but they do not block this run's PASS.

## Verdict

**PASS.** The landscape now matches the verified end state on `pro-data-tech-qa`: fail2ban 1.1.0-9 installed, sshd jail active with iptables-multiport banaction, mgmt IP `178.89.57.135` in ignoreip, service active+enabled. T-0095 transitions from in-progress to done with the expected outcome text, and `tasks/_index.md` correctly moves the row into the done section.
