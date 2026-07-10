---
run_id: 2026-07-08-install-ufw-pro-data-tech-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
inputs_read:
  - tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md
  - tasks/_index.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: Pass to landscape-reader (step 02).
---

## Task summary
Install a host-level baseline firewall (UFW) on `pro-data-tech-qa` (95.46.211.230): default-deny incoming, default-allow outgoing, default-forward ACCEPT (preserved for future Docker parity), IPv6 enabled, with a single allow rule for `22/tcp` from **any source** per the user's 2026-07-08 decision. The host has no cloud-provider firewall equivalent (pro-data.tech), so UFW is the only packet filter in the network path.

## Acceptance criteria (verbatim or paraphrased)
From T-0094 "What done looks like":
- [ ] UFW enabled with `default deny incoming`, `default allow outgoing`, `default forward accept`.
- [ ] `IPV6=yes` in `/etc/default/ufw` (v4+v6 rules).
- [ ] UFW allow rule for `22/tcp` from **any source** (`ufw allow 22/tcp` — no source-IP filter, per user decision 2026-07-08).
- [ ] Pre-change `/etc/default/ufw` backed up at `/etc/default/ufw.bak` (mode 0644, owner root:root).
- [ ] UFW persistence across `sudo reboot` verified live.
- [ ] External probe: `Test-NetConnection 95.46.211.230 -Port 22` from management workstation → `TcpTestSucceeded: True`; non-allowed ports return `False` with timeout.
- [ ] `landscape/hosts/pro-data-tech-qa.md` updated: `## Network` rewritten with UFW status + ruleset; `## What needs to happen` item #4 marked done.

## User decisions captured (no source restrictions per user decision 2026-07-08)
- **SSH allow rule has no source restrictions** — `ufw allow 22/tcp` from any source, not keyed to known operator IPs. Defense-in-depth comes from (a) UFW only opening 22/tcp (no 80/443/services-bound-to-public-IPs yet), (b) `AllowGroups sshusers` from T-0093, and (c) fail2ban from T-0095 (queued). Differs from `ubuntu-16gb-nbg1-1`, where Hetzner Cloud Firewall provides source-IP restriction at the cloud layer — pro-data.tech has no comparable outer filter.

## Details
- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-qa.md` (rewrite `## Network` section; mark "What needs to happen" item #4 done)
  - Live host: `pro-data-tech-qa` (95.46.211.230) — UFW package, `/etc/default/ufw`, UFW ruleset, reboot-persistence check
- **Constraints stated by user:**
  - UFW is already installed on the host but `Status: inactive` (per discovery probe F)
  - No source-IP filter on the SSH allow rule (user decision 2026-07-08)
  - `DEFAULT_FORWARD_POLICY="ACCEPT"` preserved (matches sibling hosts; harmless while IP forwarding is disabled)
  - No paid provider add-ons (Backups & storage policy)
  - Predecessor T-0093 (sshd hardening) must be done — confirmed `done` in `tasks/_index.md` (2026-07-08)
- **Information gaps for downstream steps:**
  - Current contents of `/etc/default/ufw` (only known to be installed; defaults not yet read) — step 02 (landscape-reader) should capture.
  - Whether IPv6 is already enabled at OS link level on `pro-data-tech-qa` — UFW `IPV6=yes` requires kernel IPv6 to be usable; landscape-reader should note.
  - Current `ufw` package version and whether `ufw.service` is enabled in systemd — landscape-reader should record.
  - Sibling pattern reference: `T-0083` (UFW on `ubuntu-16gb-nbg1-1`) is the closest prior art for verification commands and persistence check.

## Issues / risks
- **No outer firewall in the network path** — unlike Hetzner hosts where Cloud Firewall filters before the host's NIC, here UFW is the only filter. A misconfiguration (e.g. forgetting `default deny incoming`) would be the only line of defense. Executor must verify the active ruleset post-`ufw enable` rather than trust the configure step alone.
- **Tunneled IPv6 risk** — if `IPV6=yes` is set but the provider only ships IPv4 link, rules apply to a non-existent address family silently. Step 02 should check `ip -6 addr` output.
- **DEFAULT_FORWARD_POLICY="ACCEPT" activation** — currently a no-op (ip_forward=0) but will activate the moment Docker (or any other forwarder) is installed. Acceptable per task, but landscape file should note this clearly so future runs do not treat it as a bug.
- **Reboot test in a remote workflow** — persistence verification requires SSH-after-reboot, which means the operator must have access post-reboot. The sshusers / non-root user from T-0097 / T-0093 is in place to make this safe, but the executor should explicitly stage a re-connect plan before rebooting.

## Open questions
- none
