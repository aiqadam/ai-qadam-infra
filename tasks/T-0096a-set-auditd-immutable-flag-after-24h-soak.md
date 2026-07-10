---
id: T-0096a-set-auditd-immutable-flag-after-24h-soak
title: Set auditd immutable flag (-e 2) on pro-data-tech-qa after 24h soak
kind: observation
status: observation
priority: P3
created: 2026-07-10
updated: 2026-07-10
closed:
outcome:
created_by: 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
source_runs:
  - 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by:
  - T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
related:
  - T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
estimated_blast_radius: low
estimated_reversibility: partial
---

# Set auditd immutable flag (-e 2) on pro-data-tech-qa after 24h soak

## Why
T-0096 (run 2026-07-10-enable-auditd-on-pro-data-tech-qa-001) installed auditd with the project CIS-derived ruleset (15 keys, 67 rules). The ruleset was deliberately written WITHOUT the immutable flag (`-e 2`) so debugging a misconfigured rule wouldn't require a reboot. Per CIS hardening, the immutable flag is the final lock — once set, the rules table can only be changed by rebooting into a recovery shell, which provides strong assurance against runtime ruleset tampering.

## What done looks like
- [ ] Wait 24h after T-0096 closure (2026-07-10) to allow soak.
- [ ] Verify no crash or kernel-module-load regression in `journalctl -u auditd` for the 24h window.
- [ ] Run `sudo auditctl -e 2` to set the immutable flag.
- [ ] Verify `auditctl -s` reports `enabled 2` (immutable).
- [ ] Verify `auditctl -l` still shows the same 67 rules (immutable = locked, not disabled).
- [ ] Update `landscape/hosts/pro-data-tech-qa.md` auditd section: change "immutable flag (-e 2) deferred to follow-up T-0096a" to "immutable flag SET 2026-07-XX (24h soak clean)".
- [ ] Document that future ruleset changes require a reboot into recovery mode.

## Notes
- The 24h soak starts 2026-07-10 (T-0096 closure). Earliest action: 2026-07-11.
- This is a 1-command change (`auditctl -e 2`) but a state-changing infrastructure run per project protocol; a full 8-step workflow is required to maintain the audit trail.
- The 24h wait is operational; it can be done by a follow-up audit-host run that checks the journal for the 24h window.

## History
- 2026-07-10: created as kind: observation by 2026-07-10-enable-auditd-on-pro-data-tech-qa-001 (T-0096 follow-up; defer immutable flag until 24h soak confirms no regression)
