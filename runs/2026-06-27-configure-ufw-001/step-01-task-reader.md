---
run_id: 2026-06-27-configure-ufw-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1
inputs_read:
  - tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md
  - workflows/_common-operations.md
  - workflows/infrastructure.md
  - tasks/README.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader — read landscape/hosts/ubuntu-16gb-nbg1-1.md, landscape/services.md, landscape/secrets-inventory.md (SSH key path only)
---

## Summary

Parsed task T-0083 (configure UFW deny-by-default on `ubuntu-16gb-nbg1-1`, allow 22/80/443 tcp, enable service, verify SSH survives). Task is a state-changing infrastructure change on a single managed host; workflow is `infrastructure`; status is `pending` (the orchestrator will flip to `in-progress` during run init per `_common-operations.md` §"Run initialization" §4). All acceptance criteria are concrete and executable. One open design question (DEFAULT_FORWARD_POLICY) is flagged for step 04 to resolve.

## Details

- **Workflow:** infrastructure (state-changing, requires approval gate at step 05).
- **Source run / parent task:** T-0083 was promoted from observation by `2026-06-27-discovery-host-001` (Probe F finding). Related: T-0002 (mirror implementation on `hetzner-prod`, run `2026-05-12-add-host-firewall-001`) and T-0082 (host inventory + Hetzner API open questions).

### Why (verbatim from task file)

> The discovery run `2026-06-27-discovery-host-001` found that the second Hetzner server `ubuntu-16gb-nbg1-1` (46.225.239.60) has **no host firewall**: the `ufw` binary is present but inactive, the `nft` binary is present but its ruleset is empty, and `iptables`/`ip6tables` show all chains at default ACCEPT. Every port not bound to localhost is reachable from the internet, mitigated only by the Hetzner Cloud Firewall (whose status is itself unknown — out of scope for on-host discovery; see T-0082 open questions). This is an internet-facing fresh server with the cloud image's permissive default, which is materially below the project's baseline (`hetzner-prod` has UFW deny-by-default with allow 22/80/443 since 2026-05-12 via run `2026-05-12-add-host-firewall-001` / T-0002).
>
> The service inventory on this host is currently zero — no Docker, no nginx, no app ports — so a minimal UFW rule set is appropriate: deny inbound, allow outbound, allow 22/tcp for management. 80/tcp and 443/tcp are included for forward parity with `hetzner-prod` even though no listener currently binds them; if/when nginx lands here, the rules are already in place.

### Target scope

Landscape files this task will touch (read at step 02, written at step 08):

- [landscape/hosts/ubuntu-16gb-nbg1-1.md](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) — update "Network" section, bump `last_verified` frontmatter field.
- [landscape/services.md](../../landscape/services.md) — append change-log row.

Execution targets (host-level state change):

- `ubuntu-16gb-nbg1-1` (46.225.239.60, ssh alias `ubuntu-16gb-nbg1-1`) — ufw package config + ruleset + systemd enable.

### Constraints stated by user

- Default-deny inbound, default-allow outbound (parity with `hetzner-prod`).
- Allow rules for `22/tcp`, `80/tcp`, `443/tcp` (both v4 and v6).
- UFW service must be `enabled` (survives reboot).
- SSH from management workstation MUST keep working after enable (verified live, not just on-paper) — implies executor needs a second SSH session / reverse-tunnel contingency.
- `DEFAULT_FORWARD_POLICY` decision deferred to role assignment (Docker or not) — `hetzner-prod` uses `"ACCEPT"`. Flag for step 04.
- Mirrors the playbook from T-0002 (`2026-05-12-add-host-firewall-001`) — but executor must verify on Ubuntu 26.04 LTS (newer than `hetzner-prod`'s 24.04 at the time) since the UFW package version may differ.
- Hard rule from repo: **no off-site storage / no external targets** — not directly relevant here (no backup work in this task), but landscape-updater must not invent backup targets.

### Acceptance criteria (from "What done looks like") — translated for downstream steps

1. UFW enabled, default-deny inbound, default-allow outbound (or `DEFAULT_FORWARD_POLICY="ACCEPT"` per step-04 decision).
2. Allow rules: `22/tcp` (v4+v6), `80/tcp` (v4+v6), `443/tcp` (v4+v6).
3. `sudo ufw status verbose` from management workstation shows ruleset active.
4. Ruleset persists across reboot (verified via `systemctl is-enabled ufw` → `enabled`).
5. Live SSH connectivity from `tvolodi@<management>` to `ubuntu-16gb-nbg1-1` succeeds after enable.
6. `landscape/hosts/ubuntu-16gb-nbg1-1.md` updated: Network section reflects new firewall state, `last_verified` frontmatter bumped.
7. `landscape/services.md` change-log row appended.
8. `runs/2026-06-27-configure-ufw-001/step-08-landscape-updater.md` reflects the new state.

### Information gaps for downstream steps

- **DEFAULT_FORWARD_POLICY:** task explicitly defers. Step 04 (solution-designer) must pick `"ACCEPT"` (Docker-ready, matches `hetzner-prod`) or `"DROP"` (stricter, current Docker-less reality). My read: pick `"ACCEPT"` for parity with `hetzner-prod` since the task says "forward parity" — but step 04 owns the decision.
- **Ubuntu 26.04 UFW package defaults:** task notes "any new UFW package version may have a different default rules syntax". Step 03 (task-validator) and step 06 (executor-infra) should verify the on-host `/etc/default/ufw` after install before applying rules.
- **Pre-existing duplicate ssh key in `/home/tvolodi/.ssh/authorized_keys`:** noted in landscape but out of scope for this task. Executor must not touch it.
- **Hetzner Cloud Firewall:** out of scope (per task Notes and T-0082). Outbound-only mitigation isn't required — UFW default-allow outbound covers it.

## Issues / risks

- **SSH lockout risk:** UFW enabling with SSH allowed is normally safe — but if `DEFAULT_FORWARD_POLICY="DROP"` and executor applies it before the 22/tcp allow rule, OR if the v6 allow rule fails to apply, the management workstation gets locked out. Executor must apply the 22/tcp allow rule BEFORE toggling `ufw enable`, and must verify with a live second-session SSH test before declaring done. This is exactly the risk `2026-05-12-add-host-firewall-001` faced — check that run's handoffs for the proven pattern.
- **Step-04 should re-evaluate blast radius:** task rates it `low` and reversibility `full`. I concur, conditional on the SSH lockout risk being mitigated by the executor's order-of-operations. This should remain `low` → solution-designer emits `PASS` (auto-approve), not `NEEDS_APPROVAL`.

## Open questions

- none — task is clear enough to proceed.
