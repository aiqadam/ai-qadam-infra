---
run_id: 2026-06-27-install-fail2ban-001
step: "01"
agent: task-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
inputs_read:
  - tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md
  - tasks/README.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-05-12-install-fail2ban-001/step-01-task-reader.md
  - tasks/T-0005-install-fail2ban.md
artifacts_changed: []
next_step_hint: landscape-reader — read landscape/hosts/ubuntu-16gb-nbg1-1.md (and landscape/services.md if needed) to confirm host identity, OS version, and current fail2ban/SSH posture before solution design.
---

## Summary
Task T-0084 asks the orchestrator to install `fail2ban` with an SSH default jail on the new Hetzner host `ubuntu-16gb-nbg1-1` (46.225.239.60, project `ai-qadam`), mirroring the pattern from T-0005 on `hetzner-prod`. The task is well-formed: workflow is `infrastructure` (state-changing → step-05 user approval gate applies unless step-04 emits auto-approve `PASS`), status is `in-progress`, blast radius is `low`, reversibility is `full`, and the acceptance criteria are concrete and verifiable.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` — primary affected file (security tools section, per task frontmatter `affects:`)
  - `landscape/services.md` — secondary affected file (per task frontmatter `affects:`)
- **Why (verbatim from task):**
  > The new host `ubuntu-16gb-nbg1-1` (46.225.239.60, project `ai-qadam`) was provisioned 2026-06-27 and now has UFW active with port 22 open to the public internet (T-0083). SSH PasswordAuthentication was not disabled on this host yet, and even if it is disabled in the future, internet-facing SSH without brute-force protection is constant noise and attack surface. This task mirrors T-0005 (fail2ban install on hetzner-prod) to apply the same SSH jail pattern on the new host.
- **Acceptance criteria (from "What done looks like"):**
  - [ ] `fail2ban` package installed via apt.
  - [ ] `/etc/fail2ban/jail.d/sshd.local` exists with `[sshd] enabled = true`, maxretry=3, bantime=600s, findtime=600s, ignoreip including management workstation IP.
  - [ ] `systemctl status fail2ban` shows `Active: active (running)`.
  - [ ] `fail2ban-client status sshd` shows the jail loaded with `Currently failed:` / `Currently banned:` fields.
  - [ ] Management workstation IP confirmed before writing to `ignoreip` (run `curl https://ifconfig.me` from workstation and verify).
  - [ ] `landscape/hosts/ubuntu-16gb-nbg1-1.md` security tools section updated with fail2ban details.
- **Constraints stated by user:**
  - New host runs Ubuntu 26.04 (not 24.04 like prod) — fail2ban package availability and iptables backend may differ; executor must check apt repository availability and active iptables backend before installing.
  - `ignoreip` must include the management workstation outbound IP, verified at run time. Do NOT hardcode `5.250.151.158` (the prod value) without confirming — the new host's workstation IP may differ.
  - This task is the second SSH-hardening layer on the new host; UFW is already in place from T-0083.
- **Related tasks:**
  - `T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1` — UFW already in place; this task is the brute-force layer on top.
  - `T-0005-install-fail2ban` — pattern source. Same jail parameters (maxretry=3, bantime=600s, findtime=600s) and config layout (`/etc/fail2ban/jail.d/sshd.local`) are intended to be reused. Executor may reference the closed T-0005 result for exact config wording.
- **Blast radius:** low
- **Reversibility:** full (apt purge + jail.d file removal restores prior state)
- **Workflow state:** `in-progress`, run `2026-06-27-install-fail2ban-001` already recorded in `executed_by_runs:`. Frontmatter is well-formed; no supersede/abandon signals present.
- **Information gaps for downstream steps (step 02 landscape-reader, step 03 task-validator, step 04 solution-designer, step 06 executor-infra):**
  - **Management workstation IP for the new host is NOT yet recorded.** The task explicitly forbids hardcoding `5.250.151.158`. Step 02 (landscape-reader) should:
    1. Confirm whether `landscape/hosts/ubuntu-16gb-nbg1-1.md` already records a current management workstation outbound IP.
    2. If not present, surface this as a gap and have the executor verify live (`curl https://ifconfig.me` from workstation) before writing `ignoreip`. The task itself states this verification step.
  - **Confirm Ubuntu 26.04 apt availability for `fail2ban`.** The new host runs Ubuntu 26.04, not the 24.04 used on `hetzner-prod`. Executor must check the apt repo before installing (task Notes section flags this).
  - **Confirm the iptables backend.** fail2ban on newer Ubuntu defaults vary (iptables vs nftables). The previous T-0005 used `banaction=iptables-multiport`. Executor should verify which backend is active on the new host and whether nftables-multiport is required instead.
  - **Confirm fail2ban is not already installed.** T-0005 had to handle a fresh host; the new host was provisioned 2026-06-27 and may or may not have fail2ban pre-baked in the cloud image.
  - **Confirm the SSH path the jail will protect.** T-0083 opened port 22 to public. Step 02 should verify port 22 is the actual SSH listener (`ss -tlnp | grep :22`) — cloud-init default ports should match but worth confirming.
  - **Confirm project/project tag association.** Task says project is `ai-qadam`. Landscape file should be cross-referenced to confirm before the executor reports.

## Issues / risks

- **Ubuntu 26.04 is newer than prod's 24.04.** fail2ban package name, default backend (iptables vs nftables), and shipped jail defaults may differ. Risk: low (Ubuntu major-version apt behavior is generally stable), but the task Notes explicitly flag this and require the executor to verify before installing.
- **Hardcoded prod workstation IP risk.** The previous T-0005 used `5.250.151.158`. The task forbids copying that value blindly. Step 02 should surface the recorded workstation IP (or the gap) before step 04 designs the config.
- **Layering with T-0083.** UFW is already active. fail2ban in jail.local adding its own iptables/nftables rules should not conflict (fail2ban inserts above UFW's chains by convention), but the executor should sanity-check `iptables -L -n` or `nft list ruleset` after enabling the service to confirm both layers coexist.
- **No `PasswordAuthentication` disable yet.** The task Why notes password auth has not been disabled on this host. fail2ban is therefore MORE valuable here than it was on prod (which already had password auth disabled via T-0007). Worth noting in the solution design.

## Open questions

none — the task is clear, the workflow is `infrastructure`, status is `in-progress`, and the gaps are concrete enough to delegate to step 02 (landscape-reader) and step 04 (solution-designer) without blocking.