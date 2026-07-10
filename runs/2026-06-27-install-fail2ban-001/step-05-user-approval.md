---
run_id: 2026-06-27-install-fail2ban-001
step: "05"
agent: user-approval
verdict: APPROVED
created: 2026-06-27T00:00:00Z
task_id: T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-install-fail2ban-001/step-04-solution-designer.md
artifacts_changed: []
approved_by: user
---

## Summary
User approved the fail2ban install plan for ubuntu-16gb-nbg1-1 without modification.

## Details
User response: APPROVE

The approved plan installs fail2ban from the Ubuntu 26.04 apt repo on ubuntu-16gb-nbg1-1 (46.225.239.60), creates /etc/fail2ban/jail.d/sshd.local with the sshd jail (3 failures / 10-minute ban, management IP in ignoreip), enables and starts the service. The executor will confirm the management workstation outbound IP live via `Invoke-WebRequest https://api.ipify.org` BEFORE any config write (task T-0084 explicitly forbids hardcoding the prod value `5.250.151.158`), verify the iptables backend with `iptables -V` and `update-alternatives --list iptables`, default to `banaction = iptables-multiport` with auto-fallback to `nftables-multiport` if needed, and verify post-install that the management workstation is not self-banned via `ssh -o BatchMode=yes ubuntu-16gb-nbg1-1 'echo ok'`.

## Issues / risks
none

## Open questions
none