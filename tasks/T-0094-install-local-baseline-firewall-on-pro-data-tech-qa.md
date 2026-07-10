---
id: T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
title: Install local baseline firewall on pro-data-tech-qa (UFW deny-incoming, allow 22/tcp from any source — no source restrictions per user decision 2026-07-08)
kind: task
status: done
priority: P2
created: 2026-07-08
updated: 2026-07-08
closed: 2026-07-08
outcome: succeeded
created_by: 2026-07-08-discovery-pro-data-tech-qa-001
source_runs:
  - 2026-07-08-discovery-pro-data-tech-qa-001
executed_by_runs:
  - 2026-07-08-install-ufw-pro-data-tech-qa-001
affects:
  - landscape/hosts/pro-data-tech-qa.md
workflow: infrastructure
blocks: []
blocked_by:
  - T-0093-harden-sshd-on-pro-data-tech-qa
related:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
  - T-0093-harden-sshd-on-pro-data-tech-qa
  - T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
estimated_blast_radius: medium
estimated_reversibility: full
---

# Install local baseline firewall on pro-data-tech-qa (UFW deny-incoming, allow 22/tcp from any source — no source restrictions per user decision 2026-07-08; no cloud-provider firewall equivalent for pro-data.tech)

## Why
Discovery run [`2026-07-08-discovery-pro-data-tech-qa-001`](../../runs/2026-07-08-discovery-pro-data-tech-qa-001/) (probe F) shows `pro-data-tech-qa` has no host-level firewall: `ufw` is installed but `Status: inactive`; `nft list ruleset` returns empty (no rules loaded); `iptables` and `ip6tables` have all chains at `policy ACCEPT` and no rules. The only thing between sshd and the public Internet is whatever the pro-data.tech provider's network does (which is opaque from the host's perspective). pro-data.tech may or may not provide a control-plane firewall analogous to Hetzner Cloud Firewall — this is outside the host's view. The project's [Backups & storage policy](../README.md#backups--storage-policy) declares no paid provider add-ons, and the analogous position for `pro-data-tech-qa` is: **enable a host-level firewall (UFW) for defense-in-depth**, regardless of whether the provider exposes its own firewall. Sibling hosts `hetzner-prod` ([T-0002](../tasks/T-0002-add-host-firewall.md), done 2026-05-12) and `ubuntu-16gb-nbg1-1` ([T-0083](../tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md), done 2026-06-27) both have UFW active as the host-layer filter. The same baseline is required here.

## What done looks like
- [x] UFW enabled with `default deny incoming`, `default allow outgoing`, and `default forward accept` ~~(preserved for Docker parity)~~. **Partial deviation:** `DEFAULT_FORWARD_POLICY="DROP"` per user decision 2026-07-08 (deliberate divergence from sibling hosts, see "CRITICAL note for T-0090" under `## Result`). DROP is currently a no-op since `/proc/sys/net/ipv4/ip_forward=0`.
- [x] `IPV6=yes` in `/etc/default/ufw` (v4+v6 rules).
- [x] UFW allow rule for `22/tcp` from **any source** (`ufw allow 22/tcp` — no IP filter, per user decision 2026-07-08). The pro-data.tech host has no Hetzner Cloud Firewall equivalent and no operator-keyed source-IP allowlist on the workstation; source restrictions are deferred to a future decision. Host-level defense-in-depth is still provided by UFW itself (only 22/tcp is open; no 80/443/services-bound-to-public-IPs).
- [x] Pre-change `/etc/default/ufw` backed up at `/etc/default/ufw.bak` (mode 0644, owner root:root). Verified intact at step-07 V03 (1897 B).
- [⚠] UFW persistence across `sudo reboot` verified live. **Not explicitly tested in this run** — `systemctl is-enabled ufw` returns `enabled` and `/etc/ufw/ufw.conf` has `ENABLED=yes`, which is the standard boot-persistence mechanism. Same gap as T-0083; a literal reboot verification is a future housekeeping item.
- [x] External probe: `Test-NetConnection 95.46.211.230 -Port 22` from management workstation → `TcpTestSucceeded: True`; non-allowed ports return `False` (80, 443 — V08 PASS).
- [x] `landscape/hosts/pro-data-tech-qa.md` updated: `## Network` rewritten with UFW status + ruleset; `## What needs to happen` item #4 marked done.

## Result

UFW installed and active on 2026-07-08 via run [2026-07-08-install-ufw-pro-data-tech-qa-001](../runs/2026-07-08-install-ufw-pro-data-tech-qa-001/). Defaults: deny-incoming / allow-outgoing / forward-DROP / IPv6 yes. 22/tcp allowed (v4+v6) from any source per user decision. 10/10 verification checks passed after rollback-timer fix (setsid process-group cancellation).

- **Executor handoff:** [step-06-executor-infra.md](../runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-06-executor-infra.md) (re-execution with `setsid` + `kill -9 -- -PGID` group-kill, fixing the first-run nohup-orphaned-sleep bug)
- **Validator handoff:** [step-07-execution-validator.md](../runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-07-execution-validator.md) (PASS, 10/10: V01-V10)
- **Landscape updates:** [step-08-landscape-updater.md](../runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-08-landscape-updater.md)

### Deviations from "What done looks like" checklist

| Acceptance criterion | Actual outcome |
|---|---|
| UFW enabled with `default deny incoming`, `default allow outgoing`, `default forward accept` | **Partial deviation.** `DEFAULT_INPUT_POLICY="DROP"` ✓, `DEFAULT_OUTPUT_POLICY="ACCEPT"` ✓, `DEFAULT_FORWARD_POLICY="DROP"` ✗ (deliberate — see "CRITICAL note for T-0090" below). `/proc/sys/net/ipv4/ip_forward=0` so the DROP is currently a no-op. |
| `IPV6=yes` in `/etc/default/ufw` (v4+v6 rules) | ✓ Both 22/tcp rules confirmed v4+v6. |
| UFW allow rule for `22/tcp` from any source | ✓ `ufw allow 22/tcp` from `Anywhere` (v4 + v6), comment `sshd - operator access T-0094 baseline`. |
| Pre-change `/etc/default/ufw` backed up at `/etc/default/ufw.bak` | ✓ Verified intact: 1897 B, mode 0644, owner root:root, mtime `Dec 6 2025`. |
| UFW persistence across `sudo reboot` verified live | ⚠ **Not explicitly tested in this run.** The systemd unit `ufw.service` is `enabled` + `active`, and `/etc/ufw/ufw.conf` has `ENABLED=yes`, which is the standard mechanism for UFW boot persistence — but a literal reboot was not performed. (Same gap as T-0083 — noted as residual risk for a future housekeeping run.) |
| External probe: port 22 → True; non-allowed ports → False | ✓ V08 PASS: 22 = `TcpTestSucceeded: True`; 80 = False; 443 = False. |
| Landscape update | ✓ Step 08 (this file's author after closure) — see `landscape/hosts/pro-data-tech-qa.md` `## Network` section. |

### CRITICAL note for T-0090 (Docker install) — `DEFAULT_FORWARD_POLICY="DROP"`

This task was completed with `DEFAULT_FORWARD_POLICY="DROP"` (NOT `ACCEPT` like sibling `hetzner-prod` and `ubuntu-16gb-nbg1-1`) per explicit user decision 2026-07-08, because Docker is not yet installed on this host. The DROP policy is currently a no-op (since `/proc/sys/net/ipv4/ip_forward=0`), but **the moment T-0090 enables IP forwarding for Docker, all bridged container traffic will be silently dropped.**

**T-0090 executor MUST reconcile this before installing Docker.** Two acceptable paths:

1. **Flip FORWARD policy to ACCEPT** (Docker manages iptables itself):
   ```bash
   sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
   sudo ufw reload
   ```
2. **Configure Docker with `"iptables": false`** (UFW routes all Docker traffic through explicit rules):
   ```bash
   sudo mkdir -p /etc/docker
   echo '{"iptables": false}' | sudo tee /etc/docker/daemon.json
   sudo systemctl restart docker
   ```

If neither is done, Docker containers will be unable to reach the host's network or each other across the bridge.

This task is now DONE with the FORWARD=DROP state; the reconciliation is T-0090's responsibility, not T-0094's. T-0090's task file (`tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md`) and the landscape `## Network` section both call this out.

## History

- 2026-07-08: created from discovery run 2026-07-08-discovery-pro-data-tech-qa-001 (status observation; promoted to task when blockers T-0093 satisfied)
- 2026-07-08: status observation -> pending (promoted by user delegation; depends on T-0093; queued after sshd hardening run)
- 2026-07-08: status -> in-progress — run 2026-07-08-install-ufw-pro-data-tech-qa-001 started; 4 steps done (task-reader, landscape-reader, task-validator, solution-designer + auto-approved per "just go" delegation)
- 2026-07-08: status -> done — run 2026-07-08-install-ufw-pro-data-tech-qa-001 completed (after retry); UFW active, 22/tcp allowed v4+v6, defaults deny-in/allow-out/forward-DROP/IPv6-yes; rollback-timer cancellation fixed via setsid + kill -- -PGID; commit <pending>

## Notes
- **pro-data.tech vs Hetzner Cloud Firewall:** Unlike `hetzner-prod` and `ubuntu-16gb-nbg1-1` (where the Hetzner Cloud Firewall provides an outer network-layer filter), `pro-data-tech-qa` has no analogous outer filter. The host-level UFW is the only firewall in the network path. This is documented in the host landscape file's "Network" section.
- **`DEFAULT_FORWARD_POLICY="DROP"` — deliberate divergence from sibling hosts:** This host ships with `DEFAULT_FORWARD_POLICY="DROP"` per explicit user decision 2026-07-08, NOT `ACCEPT` like `hetzner-prod` and `ubuntu-16gb-nbg1-1` (which use ACCEPT because Docker is installed). The DROP policy is currently a no-op (since `/proc/sys/net/ipv4/ip_forward=0`), but **the moment T-0090 enables IP forwarding for Docker, all bridged container traffic will be silently dropped**. See the "CRITICAL note for T-0090" section under `## Result` above for the two acceptable reconciliation paths.
- **No source restrictions (user decision 2026-07-08):** the user's stated policy for this host is `ufw allow 22/tcp` from any source — no source-IP allowlist. Defense-in-depth comes from (a) UFW only opening 22/tcp (no 80/443 or other inbound services yet), and (b) the AllowGroups sshusers restriction from [T-0093](./T-0093-harden-sshd-on-pro-data-tech-qa.md) plus fail2ban from [T-0095](./T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md), not from network-layer IP filtering. This differs from `ubuntu-16gb-nbg1-1`, which uses Hetzner Cloud Firewall for source-IP restriction at the cloud layer; pro-data.tech has no comparable outer filter.
- **Sibling task pattern:** [T-0083](../tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md) is the closest analog — same UFW baseline pattern, same persistence-across-reboot verification (though Docker's FORWARD=ACCEPT differs from this host's deliberate FORWARD=DROP).
- **Predecessor T-0094 was lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md).** This re-created file restores the observation.
