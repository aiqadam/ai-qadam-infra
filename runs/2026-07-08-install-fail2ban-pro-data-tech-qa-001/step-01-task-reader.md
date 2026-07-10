---
run_id: 2026-07-08-install-fail2ban-pro-data-tech-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
inputs_read:
  - tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md
  - tasks/_index.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: task-validator
---

## Summary
T-0095 asks to install fail2ban with the sshd jail on host `pro-data-tech-qa` (95.46.211.230), matching the baseline already established on `hetzner-prod` and `ubuntu-16gb-nbg1-1`. Status is `pending`, dependency `T-0093` (sshd hardening) is `done`, and the user has pre-approved execution via "just go" delegation.

## Details
- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-qa.md` (Security posture + What needs to happen #5 + SSH hardening tooling line)
  - `landscape/services.md` (pro-data-tech-qa systemd-units table gains `fail2ban.service` row)
  - Host: `pro-data-tech-qa` (95.46.211.230, Ubuntu 26.04)
- **Constraints stated by user / task:**
  - Auto-approved via "just go" delegation — no approval gate needed
  - Install AFTER T-0093 (sshd hardening) so the jail's `logpath` resolves to post-hardening sshd logs and `maxretry` count is meaningful
  - Reuse the sibling pattern from T-0084 verbatim: same `maxretry=3`, `bantime=600s`, `findtime=600s`, same `ignoreip` line including management IP `178.89.57.135`, same `banaction=iptables-multiport`
  - Stock Ubuntu 26.04 fail2ban version expected `1.1.0-9` (matches `ubuntu-16gb-nbg1-1`)
- **Information gaps for downstream steps:**
  - None blocking. Executor should verify the post-T-0093 sshd `LogLevel` so jail `logpath` resolves correctly
  - Step 03 (task-validator) should confirm `AllowGroups sshusers` is in effect, which makes password-auth brute-force unlikely — the residual value of fail2ban is banning repeated key-failed attempts
  - Step 04 (solution-designer) should reference `runs/2026-06-27-install-fail2ban-ubuntu-16gb-nbg1-1` for the sibling run structure if available

## Issues / risks
- fail2ban's residual value is reduced because T-0093 already enforced `PasswordAuthentication no` and `AllowGroups sshusers` — brute-force is mostly key-failed noise. Still worth installing per sibling baseline consistency.
- The `banaction = iptables-multiport` choice on Ubuntu 26.04 should be re-validated against the available iptables/nftables stack before solution-design step (T-0094 installed UFW, which uses iptables-nft; `iptables-multiport` should still work but worth checking).

## Open questions
- none