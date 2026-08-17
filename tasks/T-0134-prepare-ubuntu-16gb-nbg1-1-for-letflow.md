---
id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
title: Prepare ubuntu-16gb-nbg1-1 as an application host for Letflow (Docker, firewall, sshd hardening)
kind: task
status: done
priority: P1
created: 2026-08-17
updated: 2026-08-17
closed: 2026-08-17
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-08-17-prepare-letflow-host-001]
affects: [landscape/hosts/ubuntu-16gb-nbg1-1.md, landscape/services.md, landscape/secrets-inventory.md]
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0135]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Prepare ubuntu-16gb-nbg1-1 as an application host for Letflow

## Why

The user wants to run the `letflow` project (an Elixir/OTP BPM engine under
active development at `c:\Users\tvolo\dev\ai-dala\letflow`) on a Hetzner host
in parallel with local development, to support multi-host agent-driven
development coordinated via the already-deployed `letflow-queue` service
(`queue-test.ai-dala.com`). `ubuntu-16gb-nbg1-1` (46.225.239.60, Hetzner
project "ai-qadam") was explicitly identified by the user (2026-08-17) as
currently unused and available for this purpose.

Its landscape file (`landscape/hosts/ubuntu-16gb-nbg1-1.md`) records `role:
unassigned` and explicitly states under "Open questions": *"Role: what is
this host for? UFW, sshd hardening, and any application deployments are
blocked until the user decides."* This task represents that decision being
made.

This task covers only host-level readiness. A follow-on task (not yet
created) will cover the letflow-specific deploy-app setup (Cloudflare DNS,
nginx vhost, `shared/app-registry.md` registration, first deploy) once this
lands, using the deploy scaffolding already committed to the letflow repo's
`deploy/` directory (Dockerfile, `docker-compose.test.yml`, nginx conf,
redeploy script) as a starting point, adapted for this host's actual paths
and ports.

## What done looks like

- [x] Docker Engine + Compose plugin installed on `ubuntu-16gb-nbg1-1`
- [x] Hetzner Cloud Firewall for this host allows inbound TCP 80/443 (currently
      only TCP 22 from the management workstation IP is allowed — see the
      host's landscape file "Hetzner Cloud Firewall" section)
- [x] sshd hardening applied for parity with this project's other managed
      hosts (`PasswordAuthentication no`, `PermitRootLogin
      prohibit-password`, matching T-0093/T-0102's precedent) — this is the
      host's own landscape file's deferred item #4
- [x] `landscape/hosts/ubuntu-16gb-nbg1-1.md` frontmatter `role:` updated to
      reflect its new purpose
- [x] `landscape/services.md` gains a section for this host (Docker present,
      no containers running yet)

## Result

Completed 2026-08-17 via run `2026-08-17-prepare-letflow-host-001` (4th executor-infra
attempt, PASS; independently verified by execution-validator, PASS). Final end state
on `ubuntu-16gb-nbg1-1`:

- **Docker:** Engine 29.7.2 + Compose plugin v5.4.0 installed, active, enabled;
  `docker run hello-world` and live container-egress test both passed; no
  `after.rules` change was needed.
- **sshd hardening:** fleet-standard pattern applied (`AllowGroups sshusers`,
  `MaxAuthTries 3`, `LoginGraceTime 30`, `PermitRootLogin prohibit-password`,
  tightened KEX/Ciphers/MACs) — matching T-0093/T-0102 on `pro-data-tech-qa`/
  `pro-data-tech-prod`.
- **Hetzner Cloud Firewall** (`ai-qadam-mgmt-ssh`, id `11204449`): 3 rules — port 22
  reconfirmed world-open (`0.0.0.0/0`+`::/0`, per explicit user decision — see
  Deviations below), ports 80/443 newly opened world-open.
- **`role:`** set to `letflow-app`.
- **`landscape/services.md`:** gained Docker status + `docker.service` systemd entry
  for this host.

Links: executor handoff
[`runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md`](../runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md);
validator handoff
[`runs/2026-08-17-prepare-letflow-host-001/step-07-execution-validator.md`](../runs/2026-08-17-prepare-letflow-host-001/step-07-execution-validator.md).

### Deviations from the original "What done looks like" checklist

- **Account handling (not originally listed as an acceptance criterion, but forced by
  a live discovery):** two undocumented, real, sudo-capable accounts (`viktor_d`,
  `binali_r`) were found present on the host during Phase 0. Per user decision, they
  were locked (expired + password-locked, not deleted), not left untouched and not
  deleted. See [T-0135](./T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md).
- **Firewall port-22 CIDR:** the original checklist's framing ("currently only TCP 22
  from the management workstation IP is allowed") assumed the landscape's documented
  state was still accurate. Live-state re-verification found port 22 had already been
  widened to `0.0.0.0/0`+`::/0` out-of-band, undocumented, dated 2026-06-27. Per
  explicit user instruction ("Leave it open to anywhere"), this run preserved that
  widened state rather than narrowing it back to the workstation IP — the acceptance
  criterion "allows inbound TCP 80/443" was met, but port 22's final state differs
  from what the checklist implied it would be.
- **sshd hardening baseline:** the checklist assumed a "not yet hardened" starting
  point (per the then-current landscape file). Live state showed an undocumented
  `T-0087`-labeled hardening pass already in effect, with a different (stricter in
  some respects, e.g. post-quantum KEX; looser in others, e.g. `MaxAuthTries 6` vs.
  fleet's `3`) posture than the fleet standard. This run replaced it with the
  fleet-standard pattern rather than building hardening from scratch.
- New observation task [T-0135](./T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md)
  opened to track the unresolved process-gap investigation behind both discoveries.

## Notes

Solution-designer should treat Docker install, the Cloud Firewall rule
change, and sshd hardening as likely `NEEDS_APPROVAL` per
`shared/approval-protocol.md`'s "Always requires NEEDS_APPROVAL" list
(package installs, firewall rule changes) — this is expected, not a defect
in scoping.

## History
- 2026-08-17: created
- 2026-08-17: status -> in-progress, run 2026-08-17-prepare-letflow-host-001
- 2026-08-17: executor-infra attempt 1 FAILed — SSH config alias `ubuntu-16gb-nbg1-1`
  missing from the management workstation's `C:\Users\tvolo\.ssh\config` (present as
  of a 2026-06-27 backup, absent from the live file, mtime 2026-08-15 — an out-of-band
  workstation edit unrelated to this run). No host state touched. Alias restored
  out-of-band before retry.
- 2026-08-17: executor-infra attempt 2 FAILed — Phase 0 live-state reconfirmation
  found the host's sshd already hardened by an undocumented `T-0087`-labeled drop-in
  (`AllowUsers tvolodi viktor_d binali_r`, applied 2026-06-27, no task/run record
  anywhere in this repo) and two undocumented, real, sudo-capable accounts
  (`viktor_d`, `binali_r`) present on the host, directly contradicting the landscape
  file's "clean slate" claim. Proceeding with the then-approved plan would have
  silently revoked SSH access for both accounts as an unintended side effect. No host
  state touched. Required a full solution-designer re-plan (attempt-2 design) to
  address the discovery and get fresh user approval for locking (not deleting) the two
  accounts and reconciling the sshd hardening.
- 2026-08-17: solution-designer revised the plan (superseding the original approved
  design) to lock `viktor_d`/`binali_r` (not delete), replace `T-0087`'s sshd drop-in
  with the fleet-standard pattern, and open a new observation task for the T-0087
  discovery. Re-approved by the user.
- 2026-08-17: executor-infra attempt 3 FAILed — Phase 0 re-run (per the revised plan's
  explicit full-re-run instruction) found the Hetzner Cloud Firewall's port-22 rule
  already widened to `0.0.0.0/0`+`::/0` (self-described "widened 2026-06-27" in its own
  `description` field), contradicting the plan's assumption that port 22 was still
  scoped to the workstation IP. No task/run record found for this change either. No
  host or firewall state touched. Halted for a user decision on how to handle the
  live discrepancy.
- 2026-08-17: user decided: "Leave it open to anywhere" — do not narrow port 22 back.
- 2026-08-17: solution-designer revised the plan a second time to preserve the
  live wide-open port-22 state instead of narrowing it, and expanded the scope of the
  planned observation task to cover both undocumented discoveries (T-0087 sshd/
  accounts, and the firewall widening) as a single process-gap investigation.
  Re-approved by the user (fresh approval-gate pass, since the firewall-widening
  decision had only been given as a bare answer to a halt, not reviewed as part of a
  concrete plan before this point).
- 2026-08-17: executor-infra attempt 4 PASSed — full Phase 0 re-run found zero further
  drift; executed account lockout, sshd hardening reconciliation, Docker install, and
  Hetzner Cloud Firewall update exactly as designed. No rollback needed.
- 2026-08-17: execution-validator independently re-verified all designer-specified
  checks against live host state and the live Hetzner API — PASS.
- 2026-08-17: status -> done, outcome succeeded, run 2026-08-17-prepare-letflow-host-001, commit <pending>
