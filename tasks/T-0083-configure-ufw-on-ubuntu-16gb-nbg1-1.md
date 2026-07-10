---
id: T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1
title: Configure UFW on ubuntu-16gb-nbg1-1 (deny-by-default, allow 22/80/443)
kind: task
status: done
priority: P1
created: 2026-06-27
updated: 2026-06-27
closed: 2026-06-27
outcome: succeeded
created_by: 2026-06-27-discovery-host-001
source_runs:
  - 2026-06-27-discovery-host-001
executed_by_runs:
  - 2026-06-27-configure-ufw-001
affects:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0002-add-host-firewall
  - T-0082-add-ubuntu-16gb-nbg1-1-to-inventory
estimated_blast_radius: low
estimated_reversibility: full
---

# Configure UFW on ubuntu-16gb-nbg1-1 (deny-by-default, allow 22/80/443)

## Why
The discovery run `2026-06-27-discovery-host-001` found that the second Hetzner server `ubuntu-16gb-nbg1-1` (46.225.239.60) has **no host firewall**: the `ufw` binary is present but inactive, the `nft` binary is present but its ruleset is empty, and `iptables`/`ip6tables` show all chains at default ACCEPT. Every port not bound to localhost is reachable from the internet, mitigated only by the Hetzner Cloud Firewall (whose status is itself unknown — out of scope for on-host discovery; see T-0082 open questions). This is an internet-facing fresh server with the cloud image's permissive default, which is materially below the project's baseline (`hetzner-prod` has UFW deny-by-default with allow 22/80/443 since 2026-05-12 via run `2026-05-12-add-host-firewall-001` / T-0002).

The service inventory on this host is currently zero — no Docker, no nginx, no app ports — so a minimal UFW rule set is appropriate: deny inbound, allow outbound, allow 22/tcp for management. 80/tcp and 443/tcp are included for forward parity with `hetzner-prod` even though no listener currently binds them; if/when nginx lands here, the rules are already in place.

## What done looks like
- [ ] UFW enabled on `ubuntu-16gb-nbg1-1` with default-deny inbound, default-allow outbound (or parity with `hetzner-prod`'s `DEFAULT_FORWARD_POLICY="ACCEPT"` if Docker will eventually run here — decision deferred to role assignment).
- [ ] Allow rules in place: `22/tcp` (v4+v6), `80/tcp` (v4+v6), `443/tcp` (v4+v6).
- [ ] `sudo ufw status verbose` from the management workstation shows the ruleset active and persistent across reboot.
- [ ] `ufw.service` enabled (`systemctl is-enabled ufw` → `enabled`).
- [ ] SSH from management workstation still works after UFW enable (verified live, not just on-paper).
- [ ] `landscape/hosts/ubuntu-16gb-nbg1-1.md` updated to reflect the new firewall state in the "Network" section (and frontmatter `last_verified` bumped to the run date). `landscape/services.md` change-log row added.
- [ ] Run handoff under `runs/<run_id>/step-08-landscape-updater.md` reflects the new state.

## Result

UFW configured on `ubuntu-16gb-nbg1-1` (46.225.239.60) per the T-0002 proven pattern (allow-rule-before-enable, quote-safe sed, `at`-based rollback timer, fresh-connection SSH proof). End state matches `step-04-solution-designer.md` plan exactly.

**What was actually done:**
- UFW enabled; defaults `deny (incoming)`, `allow (outgoing)`. Six allow rules committed (22/tcp, 80/tcp, 443/tcp — each on v4 + v6).
- `/etc/default/ufw`: `DEFAULT_FORWARD_POLICY` changed `DROP` → `ACCEPT` (preserved Docker parity with `hetzner-prod`). `IPV6=yes` confirmed unchanged. `/etc/default/ufw.bak` created (1897 bytes, mode 0644, owner root:root, mtime preserved from original Dec 6 2025 file). `diff` vs backup shows exactly the FORWARD-policy line differing — no Ubuntu 26.04 UFW package drift.
- systemd: `ufw.service` flipped from "enabled-but-inactive" to "enabled and active" (`UnitFileState=enabled`, `ActiveState=active`, `SubState=exited` — the exited sub-state is normal).
- SSH survived every post-enable step (each `ssh` invocation is a fresh TCP/22 connection).
- External probe from management workstation: port 22 reachable (`TcpTestSucceeded: True`); ports 80/443 return `False` with immediate RST (allowed by UFW, no listener → RST from host stack); port 21 returns `False` with timeout (UFW drops). This three-way distinction confirms UFW is actively filtering.
- Reboot persistence verified live: post-`sudo reboot`, `ufw status verbose` matches pre-reboot output (active, 6 allow rules, FORWARD=ACCEPT), `systemctl is-enabled ufw` returns `enabled`.

**Two minor adaptations** (both consistent with the design's stated intent):
1. **Step 1 grep form:** the design used `grep -E "^(DEFAULT_|IPV6)="` which contains parentheses; wrapped in single quotes for PowerShell SSH, bash on the remote side interpreted `(` as a subshell open. Executor substituted a parentheses-free two-grep form (`grep ^DEFAULT_` and `grep ^IPV6=`). Same output lines; no data loss.
2. **`disabled (routed)` rendering in `ufw status verbose`:** the design set `DEFAULT_FORWARD_POLICY="ACCEPT"` for Docker parity. With IP forwarding disabled on this host (`/proc/sys/net/ipv4/ip_forward=0`), UFW correctly reports the FORWARD policy as `disabled (routed)` — the FORWARD policy only applies when IP forwarding is enabled. The `ACCEPT` value is preserved in `/etc/default/ufw` and will activate when IP forwarding is enabled (e.g., when Docker lands here). The design explicitly anticipated this: *"Today, with no Docker installed, ACCEPT is a no-op."*

**Deviations from "What done looks like":** none. All seven acceptance criteria satisfied.

**Links:**
- Plan: [runs/2026-06-27-configure-ufw-001/step-04-solution-designer.md](../../runs/2026-06-27-configure-ufw-001/step-04-solution-designer.md)
- Approval: [runs/2026-06-27-configure-ufw-001/step-05-user-approval.md](../../runs/2026-06-27-configure-ufw-001/step-05-user-approval.md) (verdict: APPROVED)
- Execution log: [runs/2026-06-27-configure-ufw-001/step-06-executor-infra.md](../../runs/2026-06-27-configure-ufw-001/step-06-executor-infra.md) (verdict: PASS)
- Independent verification: [runs/2026-06-27-configure-ufw-001/step-07-execution-validator.md](../../runs/2026-06-27-configure-ufw-001/step-07-execution-validator.md) (verdict: PASS)

**Landscape impact:** [landscape/hosts/ubuntu-16gb-nbg1-1.md](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) updated (Network section rewritten with UFW block; TCP-listener reachability statement updated from "given no UFW" to "filtered by UFW allow rules"; "What needs to happen" item #3 marked done; change-log row appended). `landscape/services.md` unchanged (per prod convention, UFW ruleset lives in the host file, not the services file).

## Notes
- **Independence from role assignment:** this task is independent of `role: unassigned` for `ubuntu-16gb-nbg1-1` (T-0082 open question). Every internet-facing server in this project should ship with UFW deny-by-default regardless of its eventual role, so this can run before the role is decided.
- **Mirror T-0002:** the same workflow that brought UFW to `hetzner-prod` (`2026-05-12-add-host-firewall-001`, see [T-0002](../../tasks/T-0002-add-host-firewall.md)) is the model here. Differences to watch for on Ubuntu 26.04: any new UFW package version may have a different default rules syntax; verify `DEFAULT_FORWARD_POLICY="ACCEPT"` setting (in `/etc/default/ufw`) is preserved — it was set on `hetzner-prod` to keep Docker's FORWARD chain working once Docker was installed.
- **Hetzner Cloud Firewall is out of scope here:** a follow-on Hetzner-API workflow run (token scope for project 15130993 must be verified first — see T-0082 open questions) should audit and possibly apply a Cloud Firewall as the outer-layer protection. UFW is the inner layer.
- **Companion tasks (not yet created):** fail2ban install, sshd hardening (disable password auth + PermitRootLogin + drop SHA-1 MACs) are independent of role and could be batched into the same hardening workflow. They are not observations yet — file them as separate tasks when promoting this work.

## History
- 2026-06-27: created from run `2026-06-27-discovery-host-001` (Probe F finding: UFW inactive, all chains default ACCEPT; no firewall protection between the internet and any future service on this host)
- 2026-06-27: promoted observation -> task, priority P1, by user (implicit via "go on" after discovery run 2026-06-27-discovery-host-001)
- 2026-06-27: status -> in-progress, run 2026-06-27-configure-ufw-001
- 2026-06-27: status -> done, outcome succeeded, run 2026-06-27-configure-ufw-001, commit c0a9e45 (executor infra; landscape-updater commit pending)
