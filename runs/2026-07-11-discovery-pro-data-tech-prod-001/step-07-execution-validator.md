---
run_id: 2026-07-11-discovery-pro-data-tech-prod-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-11T05:30:00Z
task_id: T-0101-add-pro-data-tech-prod-to-inventory
inputs_read:
  - runs/2026-07-11-discovery-pro-data-tech-prod-001/step-06-executor-discovery.md
  - runs/2026-07-11-discovery-pro-data-tech-prod-001/step-01-task-reader.md
  - tasks/T-0101-add-pro-data-tech-prod-to-inventory.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Proceed to step 08 (landscape-updater). Create landscape/hosts/pro-data-tech-prod.md with full host profile and update landscape/services.md. Capture the 6 security gaps as issues/tasks (see "Issues / risks" section). Document the eth1 192.168.0.3/24 private LAN finding prominently — it is absent from the QA landscape file and needs a follow-up topology investigation.
---

## Summary

All 14 probes (A–L plus one supplemental network probe) ran cleanly against `root@95.46.211.224` (`drkkrgm-prod-instance`). Sixteen independent spot-checks were re-run from the management workstation and every one matches the executor's reported output. The host profile is complete and sufficient for landscape-updater to create `landscape/hosts/pro-data-tech-prod.md`. Verdict: **PASS**.

## Details

### Discovery workflow note

This is a read-only discovery run (`state_changing: false`). There is no step-04 solution designer and therefore no "Verification block" to run verbatim. This step performs independent re-observation of the executor's probe outputs by re-running key probes directly from the management workstation.

### On-host spot-checks

All probes used: `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" -o StrictHostKeyChecking=accept-new -o BatchMode=yes root@95.46.211.224 '<command>'`

| Check (from executor) | Command run | Expected | Actual | Pass |
|---|---|---|---|---|
| Target IP resolves to correct host | Connection to 95.46.211.224 | connects | connects, exit 0 | yes |
| Hostname is `drkkrgm-prod-instance` (NOT QA) | `hostname` | drkkrgm-prod-instance | drkkrgm-prod-instance | yes |
| User is root, uid 0 | `whoami` | root | root | yes |
| OS: Ubuntu 26.04 LTS | `/etc/os-release \| grep PRETTY_NAME` | Ubuntu 26.04 LTS | Ubuntu 26.04 LTS | yes |
| Kernel: 7.0.0-14-generic | `uname -r` | 7.0.0-14-generic | 7.0.0-14-generic | yes |
| UFW inactive | `ufw status verbose` | Status: inactive | Status: inactive | yes |
| iptables INPUT fully open | `iptables -L -n` | policy ACCEPT, no rules | policy ACCEPT, no rules | yes |
| iptables FORWARD fully open | `iptables -L -n` | policy ACCEPT, no rules | policy ACCEPT, no rules | yes |
| iptables OUTPUT fully open | `iptables -L -n` | policy ACCEPT, no rules | policy ACCEPT, no rules | yes |
| eth0 IP: 95.46.211.224/25 | `ip addr show` | 95.46.211.224/25 | 95.46.211.224/25 | yes |
| eth1 present: 192.168.0.3/24 | `ip addr show` | 192.168.0.3/24 | 192.168.0.3/24 | yes |
| sshd PasswordAuthentication yes | `sshd -T \| grep passwordauth` | passwordauthentication yes | passwordauthentication yes | yes |
| sshd PermitRootLogin yes | `sshd -T \| grep permitrootlogin` | permitrootlogin yes | permitrootlogin yes | yes |
| No operator users (uid≥1000) | `getent passwd` filtered for login shells | no uid≥1000 login accounts | none found | yes |
| fail2ban absent | `which fail2ban-server` | not installed | fail2ban: not found | yes |
| auditd absent | `which auditd` | not installed | auditd: not installed | yes |
| Docker absent | `which docker` | not found | docker: not found | yes |
| 12 pending upgrades | `apt list --upgradable 2>/dev/null \| grep -c upgradable` | 12 | 12 | yes |

### External checks

| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| SSH port 22 reachable from management workstation | SSH connection succeeds (all spot-check probes above used real SSH) | TCP 22 open | 18 SSH sessions completed, all exit 0 | yes |
| No HTTP/HTTPS exposure | SSH probe: `ss -tlnp` shows only port 22 bound on 0.0.0.0/[::] | no 80/443 listeners | only sshd:22 on 0.0.0.0 and [::] | yes |

### Probe coverage reconciliation

| Probe (A–H mandatory per task spec) | Executor ran it | Output returned | Silent failure | Status |
|---|---|---|---|---|
| A: Identity & access | yes | root/uid-0/hostname/SUDO_OK | no | PASS |
| B: OS & kernel | yes | Ubuntu 26.04 LTS / 7.0.0-14-generic | no | PASS |
| C: Hardware | yes | 16 vCPU / 32 GiB / 339 GB root | no | PASS |
| D: Users & groups | yes | root only, no uid≥1000, sudoers cloud-init drop-in | no | PASS |
| E: SSH daemon config | yes | full sshd -T output + drop-in listing | no | PASS |
| F: Firewall | yes | UFW inactive, nftables empty, iptables all-ACCEPT | no | PASS |
| G: Network listeners | yes | sshd on 22, systemd-resolved on loopback | no | PASS |
| H: Docker | yes | docker not installed | no | PASS |
| I: nginx (bonus) | yes | nginx not installed | no | PASS |
| J: Systemd units (bonus) | yes | 21 running services listed | no | PASS |
| K: Scheduled tasks (bonus) | yes | stock Ubuntu timers only | no | PASS |
| L: Package posture (bonus) | yes | 12 pending upgrades, APT sources clean | no | PASS |
| Supplemental: network interfaces | yes | eth0 + eth1 full ip-addr output | no | PASS |

All 14 probes returned output. No silent failures detected.

### Target identity confirmation

The executor connected to `root@95.46.211.224` and received hostname `drkkrgm-prod-instance`. Independently re-confirmed by this validator. This is NOT the QA host (`drkkrgm-qa-instance`, `95.46.211.230`). Target identity is correct.

### Completeness assessment for landscape-updater

The probe data is sufficient to populate `landscape/hosts/pro-data-tech-prod.md`. All mandatory fields can be written:

| Field | Source | Status |
|---|---|---|
| Public IPv4 | Probe G / ip-addr | 95.46.211.224 ✓ |
| Hostname | Probe A | drkkrgm-prod-instance ✓ |
| OS + kernel | Probes B | Ubuntu 26.04 LTS / 7.0.0-14-generic ✓ |
| Hardware | Probe C | 16 vCPU / 32 GiB RAM / 339 GB disk ✓ |
| Virtualization type | Probe C | KVM (systemd-detect-virt) ✓ |
| Users | Probe D | root only; no operator users ✓ |
| sshd effective config | Probe E | full sshd -T output ✓ |
| Firewall state | Probe F | UFW inactive, iptables open ✓ |
| Network listeners | Probe G | sshd:22 only externally ✓ |
| Second NIC | Supplemental | eth1 192.168.0.3/24 ✓ |
| Running services | Probe J | 21 units listed ✓ |
| Scheduled tasks | Probe K | stock only ✓ |
| apt posture | Probe L | 12 pending upgrades, sources clean ✓ |
| Docker / nginx | Probes H, I | neither installed ✓ |

Items genuinely unknown at discovery time (acceptable gaps): provider plan tier/cost, datacenter location, whether a control-plane firewall is available at the pro-data.tech provider layer.

### Acceptance criteria against T-0101

| Criterion | Met by this run? | Notes |
|---|---|---|
| `landscape/hosts/pro-data-tech-prod.md` created | No — deferred to step 08 | Expected; creation is landscape-updater's job |
| `landscape/services.md` updated | No — deferred to step 08 | Expected |
| sshd config, OS, kernel, users, firewall recorded | Yes — executor probe output is complete | Ready for step 08 to consume |
| Open security gaps identified | Yes — 6 critical/high gaps documented; tasks T-0102–T-0105 pre-created | Landscape-updater should capture these explicitly |

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| (none — `artifacts_changed: []`) | No landscape files changed; no host files written | yes |

### eth1 192.168.0.3/24 follow-up needed

Independent probe confirmed `eth1` is live with IP `192.168.0.3/24` on the prod host. The QA host (`pro-data-tech-qa`, `95.46.211.230`) has **no eth1** in its landscape file. This asymmetry means:
- The prod instance is on a private provider LAN that QA is not (or QA's eth1, if any, was never discovered).
- Other hosts on `192.168.0.0/24` are unknown; the landscape-updater should flag a follow-up to enumerate the LAN occupants.
- UFW is currently inactive — when UFW is deployed (T-0102 equivalent), the eth1 interface and the 192.168.0.0/24 route must be considered in the ruleset (inbound from the private LAN should likely be restricted, not inheriting the same posture as eth0).

## Issues / risks

- **CRITICAL: UFW inactive, iptables fully open.** The host is currently unfiltered on all ports. Port 22 is the only active listener, but any new service started before UFW is deployed will be immediately internet-exposed. This is the highest-priority gap. Maps to a new task (T-0102 candidate: install-ufw-on-pro-data-tech-prod).
- **HIGH: PasswordAuthentication yes.** Password-based SSH login is enabled. Combined with `PermitRootLogin yes`, any successful brute-force against root's password would yield full system access. Maps to T-0103 candidate: harden-sshd-on-pro-data-tech-prod.
- **HIGH: PermitRootLogin yes.** Root login unrestricted (not even `prohibit-password`). Should be `prohibit-password` at minimum, consistent with the QA baseline. Same task as above.
- **HIGH: No fail2ban.** No brute-force rate-limiting on SSH (port 22 is fully exposed to the internet). Maps to T-0104 candidate: install-fail2ban-on-pro-data-tech-prod.
- **MEDIUM: No auditd.** No kernel-level audit trail. Maps to T-0105 candidate: enable-auditd-on-pro-data-tech-prod.
- **MEDIUM: No operator users.** Root is the only login-capable account. This must be addressed after sshd hardening (same ordering constraint observed on QA: T-0093 → T-0097). A T-0106 candidate for create-operator-users.
- **MEDIUM: 12 pending package upgrades.** `unattended-upgrades` is enabled but has not yet run. Should be applied after initial hardening to avoid rebooting mid-configuration. Analogous to T-0099 (kernel upgrade) on QA.
- **LOW: X11Forwarding yes, MaxAuthTries 6, ClientAliveInterval 0, LoginGraceTime 120.** All deviate from the QA baseline hardened values (X11Forwarding no, MaxAuthTries 3, ClientAliveInterval 300, LoginGraceTime 30). Will be corrected by the sshd hardening task above.
- **NOTE: eth1 192.168.0.3/24 private LAN.** The QA host has no eth1; this prod host does. UFW ruleset design must account for the second interface. A topology investigation (what is on 192.168.0.0/24?) should be added to the T-0102 solution design or as a separate issue. Without it, the private LAN could be an unmonitored lateral-movement vector once UFW is deployed on eth0 only.
- **NOTE: open-vm-tools.service enabled** on a KVM host — unusual; may be a provider image artefact. Functionally harmless but worth noting in the landscape file.

## Open questions

- What other hosts are on the `192.168.0.0/24` private LAN reachable via eth1? The QA host (95.46.211.230) was not observed to have an eth1 — is it on this LAN at a different address, or is it absent entirely?
- Does pro-data.tech offer a control-plane firewall product? If so, is it enabled by default on this host? (Cannot be determined from within the host — verify in provider console.)
- Why does the prod instance have 16 vCPU / 32 GiB (vs. QA's 8 vCPU / 15 GiB)? Different plan tier? Landscape file should note this difference for cost/capacity awareness.
