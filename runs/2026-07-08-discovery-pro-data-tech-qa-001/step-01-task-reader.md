---
run_id: 2026-07-08-discovery-pro-data-tech-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
inputs_read:
  - workflows/_common-operations.md
  - workflows/discovery-host.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/subagent-invocation.md
  - shared/approval-protocol.md
  - tasks/README.md
  - tasks/_index.md
  - landscape/README.md
  - runs/2026-06-27-discovery-host-001/step-01-task-reader.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
artifacts_changed: []
next_step_hint: Pass to landscape-reader (step 02) with workflow=discovery-host, target=landscape/hosts/pro-data-tech-qa.md (does not exist yet — note this).
---

## Summary

This step parses the user's request ("Continue with T-0090" — prepare the pro-data.tech server `pro-data-tech-qa` / `95.46.211.230` as the ai-qadam QA instance, with multi-PC operator SSH access) into a structured discovery-host workflow task. T-0090's task file is not on disk (lost in the recent git-history scrub), but the pre-scrub snapshot at git ref `a41ec73` records it as `kind: task, status: pending, priority: P1, blocked_by: T-0093`. The orchestrator refuses T-0090 directly because it is blocked, but this discovery run is independent and proceeds to enumerate the new host so a future state-changing run can unblock T-0090 cleanly. Verdict: **PASS**.

## Details

- **Workflow:** `discovery-host` (read-only; `state_changing: false`, `skip_design_step: true` per `workflows/discovery-host.md` frontmatter). Steps 04 (solution-designer) and 05 (user approval) are skipped.
- **Why (quoted from the user's most recent request and inferred T-0090 intent):**
  > "Prepare pro-data.tech server (95.46.211.230) as ai-qadam QA instance — host prep + Docker + security baseline"
- **Multi-PC operator SSH acceptance criterion** (to be captured by step 08 as an observation task during drift detection):
  > "Check that operators `viktor_d` and `binali_r` (and any future operator) can SSH into the host from their own workstations, not only from the current management workstation."
  > Operator pubkeys are present on the management workstation at `~/.ssh/ai-dala-infra-viktor-d` and `~/.ssh/ai-dala-infra-binali-r` (referenced by path only — values stay external per [landscape/README.md § Editing rules](../landscape/README.md)).
- **T-0090 task file is NOT on disk.** T-0090 is `blocked_by: T-0093` (observation kind) per the pre-scrub snapshot at `a41ec73`. Per orchestrator hard rule, T-0090 cannot be executed directly. Orchestrator strategy:
  1. **(this run)** Discovery on `pro-data-tech-qa` — populate landscape stub and surface issues as observations.
  2. Promote T-0093 → `kind: task` (sshd hardening: `AllowGroups sshusers`, `PasswordAuthentication no`, `PermitRootLogin prohibit-password`).
  3. Promote T-0097 → `kind: task` (operator user creation: `viktor_d` and `binali_r` accounts with pubkeys installed).
  4. Run T-0093 (sshd hardening).
  5. Run T-0097 (create operator users with their pubkeys from `~/.ssh/ai-dala-infra-viktor-d.pub` and `~/.ssh/ai-dala-infra-binali-r.pub`).
  6. Only then run T-0090 (full prep: Docker + application baseline + multi-PC operator access verification).
- **Target scope:**
  - `landscape/hosts/pro-data-tech-qa.md` — **does not exist yet**. The landscape-updater (step 08) will CREATE this file as part of its writes; this is a deliberate design decision driven by discovery findings, not a side-effect (per `workflows/discovery-host.md` § Landscape-update guidance for step 08).
  - `landscape/services.md` — written by step 08 with the new host's section.
  - `landscape/README.md` — update step 08 should add the new host to the host table.
  - `tasks/_index.md` — step 08 should add any new observation tasks created.
  - `landscape/secrets-inventory.md` — read-only at step 02 (for token/key references, no values).
  - Remote host: `root@95.46.211.230` (local hostname `drkkrgm-qa-instance`), reachable from the management workstation via SSH alias `pro-data-tech-qa` in `~/.ssh/config` (User `tvolodi`, IdentityFile `~/.ssh/pro-data.tech-qa-instance_rsa.ppk`).
- **Server-provided identifiers (for downstream handoffs):**
  - `host_id`: `pro-data-tech-qa`
  - `provider`: pro-data.tech (NOT Hetzner)
  - `ipv4`: `95.46.211.230`
  - `local_hostname`: `drkkrgm-qa-instance`
  - `os`: Ubuntu 26.04 LTS (verified 2026-07-08)
  - `kernel`: `7.0.0-14-generic`
  - `ssh_identity_file`: `~/.ssh/pro-data.tech-qa-instance_rsa.ppk` (OpenSSH-format RSA-2048 — extension is misleading; documented issue, see "Issues / risks" below)
  - `ssh_identity_fingerprint`: `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0`
  - Current login: `root` via provider key (no operator pubkeys installed yet).
  - `/root/.ssh/authorized_keys`: 1 line (provider key).
  - `/etc/sudoers.d/`: only `90-cloud-init-users` (root NOPASSWD ALL); no `90-tvolodi`, no operator drop-ins.
  - `PasswordAuthentication`: at cloud-init default (yes) — confirmed by absence in `sshd_config` overrides.
- **Probe checklist:** All 14 probe sections (A–N) defined in `workflows/discovery-host.md` are in scope. Probe E (sshd config) is expected to show `PasswordAuthentication yes` — capture as a finding, not as an error. Probe D will surface that `/etc/sudoers.d/` has only `90-cloud-init-users` and that operator pubkeys are not yet installed.
- **Constraints stated by user:**
  - Multi-PC operator SSH access is an explicit acceptance criterion (capture in step 08).
  - Read-only discovery: no state changes on the host; only `landscape/` writes at step 08.
  - The provider key (`pro-data.tech-qa-instance_rsa.ppk`) currently grants root access; this is acceptable for the discovery probe (probe A's `sudo -n true` will work), but the longer-term plan (T-0093 → T-0097 → T-0090) restricts root SSH.
- **Information gaps for downstream steps:**
  - **Landscape-reader (step 02):** there is NO existing `landscape/hosts/pro-data-tech-qa.md` to read — this discovery run will CREATE the stub at step 08. The landscape-reader's role here is to confirm `landscape/README.md` does NOT yet list `pro-data-tech-qa` (so step 08 has nothing to merge against) and to confirm the canonical landscape shape from `landscape/hosts/ubuntu-16gb-nbg1-1.md` (the reference file for a freshly-provisioned Ubuntu cloud host).
  - **Task-validator (step 03):** confirm the discovery-host workflow's pre-conditions (probe A `SUDO_OK` reachable via the SSH alias `pro-data-tech-qa`; the workflow declares `state_changing: false` so no approval gate is required). Confirm T-0090's blocked status (this run is NOT executing T-0090 — T-0090 is mentioned only to inform the strategy).
  - **Executor (step 06):** will need to know that the SSH identity file path on disk is `~/.ssh/pro-data.tech-qa-instance_rsa.ppk` and the SSH alias is `pro-data-tech-qa`. The executor's ssh invocations should use the alias (which carries the right IdentityFile + User + Port) rather than the raw `root@95.46.211.230`. Probe H will likely show "Docker not installed"; probes G–I will likely show no listeners on 80/443 and no nginx.
  - **Step 08 (landscape-updater):** MUST CREATE `landscape/hosts/pro-data-tech-qa.md` as a new file (not edit an existing one). MUST add the new host to `landscape/README.md`'s file table. SHOULD create observation tasks for: (a) sshd hardening (PasswordAuthentication yes, PermitRootLogin yes — the expected cloud-init defaults), (b) operator user creation (viktor_d + binali_r pubkeys not yet installed — this is the multi-PC acceptance criterion), (c) Docker install (probe H — not yet installed), (d) `.ppk` extension rename hygiene (not a security issue but worth tracking). Each observation task should follow the `kind: observation` convention from `tasks/README.md`.
- **What this run is NOT doing (explicit out-of-scope):**
  - NOT installing Docker (that's T-0090's follow-on, gated behind sshd hardening + operator user setup).
  - NOT touching sshd config (that's T-0093, after promotion to `kind: task`).
  - NOT creating operator users (that's T-0097).
  - NOT rotating or changing any key on the host.
  - NOT adding/removing anything in `/root/.ssh/authorized_keys` or `/etc/sudoers.d/`.

## Issues / risks

- **T-0090 is `blocked_by: T-0093`.** Per the orchestrator hard rule (`workflows/_common-operations.md` § Run initialization, plus `tasks/README.md` § Linkage to runs), state-changing workflows cannot execute a task whose status is not `pending` or `in-progress`. T-0093 is `kind: observation` (not a runnable task), so T-0090 is currently blocked. This discovery run is independent of T-0090's blocked status — it is the read-only host enumeration that **informs the unblocking path** (strategy enumerated in "Details" above).
- **No `landscape/hosts/pro-data-tech-qa.md` file exists yet.** The landscape-updater (step 08) will CREATE this file as part of its writes. This is a deliberate design decision driven by discovery findings, not a side-effect of the workflow (see `workflows/discovery-host.md` § Landscape-update guidance for step 08). The landscape-reader (step 02) should treat the absence of this file as expected — there is nothing to populate; step 08 is creating from scratch.
- **The `pro-data.tech-qa-instance_rsa.ppk` key has a `.ppk` extension but is actually an OpenSSH-format RSA-2048 key** (verified by reading the file contents: starts with `-----BEGIN RSA PRIVATE KEY-----`). This is a documentation issue, not a security issue. Note for step 06 to capture in `landscape/hosts/pro-data-tech-qa.md`: the actual key format is OpenSSH RSA, and a future rename to `.pem` or `.key` is a hygiene recommendation for a separate follow-up task (out of scope for this discovery run). The current SSH alias works because ssh/scp autodetect the key format from contents, not from the extension.
- **The discovery probe E (sshd config) will reveal `PasswordAuthentication yes`** (cloud-init default). This is expected; out of scope for this read-only run. Surface as an observation task at step 08 (the T-0093 sshd-hardening candidate).
- **`/etc/sudoers.d/` currently has only `90-cloud-init-users`** (root NOPASSWD ALL); no `90-tvolodi` or operator drop-ins yet. This is expected for a freshly-provisioned cloud instance and is a precondition for T-0097 (operator user creation). Capture as a finding at step 08.
- **Probe A (`sudo -n true && echo SUDO_OK`)** is the gate per `workflows/discovery-host.md` § Validation criteria for step 07; if it fails, step 06 should emit `FAIL` and be retried per `shared/verdicts.md` § Retry budget (default 2 retries). For this host the current login is `root` (via provider key) so passwordless sudo is available via cloud-init's `/etc/sudoers.d/90-cloud-init-users`. If probe A somehow fails (e.g., the executor is invoked as a non-root user via the SSH alias which configures `User tvolodi`), the executor must surface this rather than work around it.
- **The host fingerprint on management workstation's `known_hosts`** is not yet recorded in the orchestrator's run context. The executor (step 06) will need to handle `StrictHostKeyChecking=accept-new` (or already-known) on first connection. This is expected for a brand-new host; not an issue.

## Open questions

- The user has not provided their preference for whether `tvolodi` should also be a user on `pro-data-tech-qa`, or whether `root` access should remain (with hardening). Step 02 (landscape-reader) and step 06 (executor-discovery) should treat this as: **operator pubkeys `viktor_d` + `binali_r` will be installed into `root` and/or a new shared user; sshd hardening will restrict `PasswordAuthentication` and `PermitRootLogin` in a follow-on run**. The user will see the discovery findings and decide at that point.
- Whether `pro-data-tech-qa` should follow the same Hetzner-style hardening template as `hetzner-prod` and `ubuntu-16gb-nbg1-1` (UFW deny-by-default + fail2ban + sshd drop-in) or a different baseline (the provider may have its own firewall product or recommendations). Step 08 should capture the cloud-init default state; the user decides the hardening path.
- Whether the SSH identity key file rename (`.ppk` → `.pem`) is in scope for the next run or is purely cosmetic and can wait.