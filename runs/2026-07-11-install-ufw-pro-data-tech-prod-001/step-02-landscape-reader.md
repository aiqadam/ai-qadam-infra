---
run_id: 2026-07-11-install-ufw-pro-data-tech-prod-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0103-install-ufw-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — validate task T-0103 against current landscape state before proceeding to solution design
---

## Summary

`pro-data-tech-prod` (95.46.211.224) has UFW installed but inactive; all iptables chains are fully open (`policy ACCEPT`, no rules). The host has no Docker and no provider-level firewall, making it fully exposed on all ports. sshd is hardened post-T-0102 (key-only, `prohibit-password`). A second NIC `eth1` (192.168.0.3/24) is present; UFW will manage both interfaces by default without interface-specific rules. The landscape file is fresh (last_verified: 2026-07-11). No landscape gaps block safe design of T-0103.

## Details

### Relevant facts (sourced from landscape)

- **UFW state:** installed but **INACTIVE** — `ufw status` would show `Status: inactive`; all iptables/ip6tables chains are `policy ACCEPT` with no rules loaded. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **nftables:** empty ruleset; no interference with UFW (UFW uses iptables/ip6tables backend). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Docker:** NOT installed on this host (confirmed by T-0101 discovery). No Docker iptables chains, no `DOCKER-USER` chain, no FORWARD chain complications. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **DEFAULT_FORWARD_POLICY:** Because there is no Docker on prod, `DEFAULT_FORWARD_POLICY="DROP"` in `/etc/default/ufw` is safe and correct. (Contrast: QA host had this flipped to `ACCEPT` during T-0090 Phase A2 to accommodate Docker.) — _source: `landscape/hosts/pro-data-tech-prod.md`_ and _`landscape/hosts/pro-data-tech-qa.md`_
- **Network interfaces:**
  - `eth0`: 95.46.211.224/25, gateway 95.46.211.129 — public internet.
  - `eth1`: 192.168.0.3/24 — provider-managed private LAN (not present on QA host). UFW will apply rules to both interfaces. No interface-specific allow/deny rules are needed unless the solution-designer explicitly calls for it. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Current TCP listeners (at discovery time):** only port 22 (sshd) bound on `0.0.0.0`. No HTTP/HTTPS listeners yet. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **SSH access:** `root@95.46.211.224`, key `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (OpenSSH RSA despite `.ppk` extension). Key-only, password auth disabled (T-0102 hardening applied 2026-07-11, 25/25 checks PASSED). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **sshd AllowGroups:** `AllowGroups sshusers`; root is currently the sole member (transitional — T-0105 will provision operator accounts). `PermitRootLogin prohibit-password` means root SSH access is governed by that directive, not by `AllowGroups`. Port 22 must be allowed in UFW before `ufw --force enable` to avoid lockout. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **OS:** Ubuntu 26.04 LTS (`VERSION_CODENAME=resolute`). UFW package is available from the Ubuntu repos. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **QA reference UFW config (post-T-0094, pre-Docker FORWARD flip):** `ufw default deny incoming`, `ufw default allow outgoing`, `DEFAULT_FORWARD_POLICY="DROP"`, `ufw allow 22/tcp` (v4+v6 from any source). Prod task T-0103 additionally requires `ufw allow 80/tcp` and `ufw allow 443/tcp`. — _source: `landscape/hosts/pro-data-tech-qa.md`_

### Stale or stub files encountered

- None. `landscape/hosts/pro-data-tech-prod.md` is `status: populated`, `last_verified: 2026-07-11` (today). `landscape/hosts/pro-data-tech-qa.md` is `status: populated`, `last_verified: 2026-07-10` (1 day ago — within the 30-day window).

### Gaps requiring live discovery

- None. The landscape file captures the exact UFW/iptables state from the T-0101 discovery run (2026-07-11). No live discovery sub-step is required before designing or executing T-0103.

## Issues / risks

- **eth1 private NIC:** the private LAN interface introduces no extra complexity for this task (UFW rules without an interface specifier apply to all interfaces by default), but the solution-designer should be aware of it. Any inbound traffic on `192.168.0.3` from other hosts on the provider's private LAN will also be subject to the deny-incoming default — this is the desired behaviour for a host with no workload yet.
- **SSH lockout risk:** the `ufw allow 22/tcp` rule MUST be applied before `ufw --force enable`. The landscape confirms there are no other SSH sessions or recovery paths (no out-of-band console configured in the landscape); lockout would require a provider-console recovery. The solution-designer must enforce strict command ordering.
- **Production host (higher blast radius than QA):** a misconfiguration or lockout on this host carries higher impact than on the QA host. The execution-validator's SSH verification check after `ufw --force enable` is mandatory.
- **Kernel 7.0.0-14-generic:** two minor versions behind the QA host (7.0.0-27-generic) with 12 pending upgrades. Not a blocker for T-0103, but noted for T-0105 and future tasks.
