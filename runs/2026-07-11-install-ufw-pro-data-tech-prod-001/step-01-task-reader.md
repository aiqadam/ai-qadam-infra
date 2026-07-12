---
run_id: 2026-07-11-install-ufw-pro-data-tech-prod-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0103-install-ufw-on-pro-data-tech-prod
inputs_read:
  - tasks/T-0103-install-ufw-on-pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader (step 02) — read pro-data-tech-prod host landscape file and confirm current firewall state
---

## Summary

Task T-0103 is `in-progress` with a clear scope: install UFW on pro-data-tech-prod (95.46.211.224), apply deny-incoming defaults with explicit allows for 22/tcp, 80/tcp, and 443/tcp, then enable. The task maps cleanly to the `infrastructure` workflow. Predecessor tasks T-0101 (discovery) and T-0102 (sshd hardening) are complete.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md`
  - `landscape/services.md`
- **Why (verbatim from task):** "pro-data.tech has no Hetzner Cloud Firewall equivalent. The only host-level protection is UFW. The QA instance was similarly configured via T-0094. This task applies the same deny-incoming baseline with explicit allows for SSH/HTTP/HTTPS to the production host."
- **Acceptance criteria (from task "What done looks like"):**
  - UFW installed (`apt-get install ufw`)
  - `DEFAULT_FORWARD_POLICY="DROP"` set in `/etc/default/ufw`
  - `ufw default deny incoming`
  - `ufw default allow outgoing`
  - `ufw allow 22/tcp` — must be applied **before** `ufw --force enable`
  - `ufw allow 80/tcp`
  - `ufw allow 443/tcp`
  - `ufw --force enable`
  - `ufw status verbose` shows expected rules
  - SSH access verified after enable
- **Reference run:** `2026-07-08-install-ufw-pro-data-tech-qa-001` (T-0094, identical pattern on QA host)
- **Constraints stated by user/task:**
  - `ufw allow 22/tcp` MUST be applied before `ufw --force enable` to prevent lockout
  - `DEFAULT_FORWARD_POLICY="DROP"` required in `/etc/default/ufw`
  - No Docker installed on this host (confirmed by T-0101 discovery) — no Docker/iptables interaction risk
- **Information gaps for downstream steps:**
  - Landscape file for pro-data-tech-prod should be read by step 02 to confirm current UFW/iptables state matches T-0101 discovery (inactive UFW, ACCEPT-all iptables)
  - SSH credentials/access method (key, user) — executor will need these from `credentials.md` or landscape

## Issues / risks

- Enabling UFW without prior `allow 22/tcp` would lock out SSH — the ordered execution sequence (allow rules first, enable second) is the critical safety control; solution-designer must enforce this ordering explicitly
- `DEFAULT_FORWARD_POLICY="DROP"` is safe here (no Docker), but the edit to `/etc/default/ufw` must precede `ufw --force enable`
- Production host (not QA) — any lockout has higher impact; SSH verification step after enable is mandatory
