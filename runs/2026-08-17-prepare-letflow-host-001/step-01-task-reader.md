---
run_id: 2026-08-17-prepare-letflow-host-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-08-17T02:36:25Z
task_id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
inputs_read:
  - tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md
artifacts_changed: []
next_step_hint: landscape-reader should read all three affects: files, with particular attention to ubuntu-16gb-nbg1-1.md's Hetzner Cloud Firewall section and deferred item #4, plus tasks T-0093 and T-0102 for sshd-hardening precedent.
---

## Summary
Execute task T-0134: prepare `ubuntu-16gb-nbg1-1` (46.225.239.60, Hetzner project "ai-qadam") as a Docker-ready, firewall-opened, sshd-hardened application host in anticipation of a Letflow deployment, updating its landscape role and adding it to `landscape/services.md`; app-level deployment is explicitly out of scope for this task.

## Details

- **Workflow:** infrastructure

- **Target scope:**
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/secrets-inventory.md

- **Why** (quoted verbatim from the task file):

  > The user wants to run the `letflow` project (an Elixir/OTP BPM engine under
  > active development at `c:\Users\tvolo\dev\ai-dala\letflow`) on a Hetzner host
  > in parallel with local development, to support multi-host agent-driven
  > development coordinated via the already-deployed `letflow-queue` service
  > (`queue-test.ai-dala.com`). `ubuntu-16gb-nbg1-1` (46.225.239.60, Hetzner
  > project "ai-qadam") was explicitly identified by the user (2026-08-17) as
  > currently unused and available for this purpose.
  >
  > Its landscape file (`landscape/hosts/ubuntu-16gb-nbg1-1.md`) records `role:
  > unassigned` and explicitly states under "Open questions": *"Role: what is
  > this host for? UFW, sshd hardening, and any application deployments are
  > blocked until the user decides."* This task represents that decision being
  > made.
  >
  > This task covers only host-level readiness. A follow-on task (not yet
  > created) will cover the letflow-specific deploy-app setup (Cloudflare DNS,
  > nginx vhost, `shared/app-registry.md` registration, first deploy) once this
  > lands, using the deploy scaffolding already committed to the letflow repo's
  > `deploy/` directory (Dockerfile, `docker-compose.test.yml`, nginx conf,
  > redeploy script) as a starting point, adapted for this host's actual paths
  > and ports.

- **Constraints stated by user** (from the task's "What done looks like"):
  - Docker Engine + Compose plugin must be installed on `ubuntu-16gb-nbg1-1`.
  - The host's Hetzner Cloud Firewall must be changed to allow inbound TCP 80/443 (currently only TCP 22 from the management workstation IP is allowed).
  - sshd hardening must be applied for parity with this project's other managed hosts — `PasswordAuthentication no`, `PermitRootLogin prohibit-password` — matching the precedent set by tasks T-0093 and T-0102; this is called out as the host's own landscape file's "deferred item #4".
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` frontmatter `role:` must be updated to reflect the host's new purpose (moving off `unassigned`).
  - `landscape/services.md` must gain a section for this host (Docker present, no containers running yet).
  - Scope boundary: host-level readiness only. Letflow's own deployment (Cloudflare DNS, nginx vhost, `shared/app-registry.md` registration, first container deploy) is explicitly deferred to a not-yet-created follow-on task and must NOT be attempted in this run.

- **Information gaps for downstream steps:**
  - The host's current Hetzner Cloud Firewall rule set and the exact wording of "deferred item #4" live in `landscape/hosts/ubuntu-16gb-nbg1-1.md` itself — step 02 must read that file directly rather than rely on this summary.
  - sshd-hardening precedent (exact config lines / commands used) lives in tasks T-0093 and T-0102, not in T-0134 — step 02/04 should locate and read those for parity details.
  - `affects:` in the task frontmatter names `landscape/secrets-inventory.md`, but no acceptance criterion in "What done looks like" explicitly names a secret. Downstream steps should determine why this file is in scope (e.g. new SSH key material, Docker registry credentials) or flag it if the task turns out not to touch it.
  - The management workstation IP currently permitted for TCP 22 is referenced but not given verbatim in the task file — must be read from the host's landscape file's firewall section.
  - The host's IP (46.225.239.60) and Hetzner project name ("ai-qadam") are asserted in the task's Why section; landscape-reader should confirm these against `landscape/hosts/ubuntu-16gb-nbg1-1.md` as the source of truth.

## Issues / risks
- The task's own Notes section flags that Docker install, the Cloud Firewall rule change, and sshd hardening are each likely to trigger `NEEDS_APPROVAL` at step 04 per `shared/approval-protocol.md`'s "Always requires NEEDS_APPROVAL" list (package installs, firewall rule changes). This is expected per the task author, not a scoping defect.
- Declared `estimated_blast_radius: medium` / `estimated_reversibility: full` — consistent with a host-prep task that touches firewall and sshd config but installs nothing destructive.

## Open questions (optional)
none — verdict is PASS, not BLOCKED.
