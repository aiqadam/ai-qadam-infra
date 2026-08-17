---
id: T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1
title: Investigate undocumented 2026-06-27 changes on ubuntu-16gb-nbg1-1 (T-0087 sshd/account provisioning; Hetzner firewall port-22 widening)
kind: observation
status: observation
priority: P2
created: 2026-08-17
updated: 2026-08-17
closed:
outcome:
created_by: 2026-08-17-prepare-letflow-host-001
source_runs: [2026-08-17-prepare-letflow-host-001]
executed_by_runs: []
affects: [landscape/hosts/ubuntu-16gb-nbg1-1.md]
workflow: none
blocks: []
blocked_by: []
related: [T-0105, T-0134]
estimated_blast_radius: low
estimated_reversibility: full
---

# Investigate undocumented 2026-06-27 changes on ubuntu-16gb-nbg1-1

## Why

While executing task [T-0134](./T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md) (run
`2026-08-17-prepare-letflow-host-001`), the executor's mandatory Phase-0 live-state
reconfirmation surfaced two changes to `ubuntu-16gb-nbg1-1` that were made entirely
outside this repo's task/workflow/landscape-update discipline. Both are dated on or
around 2026-06-27 and neither has any corresponding task or run record anywhere in
`tasks/` or `runs/` in this repo.

**Finding 1 — sshd hardening + operator account provisioning, labeled `T-0087`.**
Attempt 2 of executor-infra (`runs/2026-08-17-prepare-letflow-host-001/.attempts/step-06-executor-infra.attempt2.md`,
step 0.2c/0.2d) found `/etc/ssh/sshd_config.d/40-ssh-hardening.conf` on the host, whose
own header comment reads `# Managed by ai-dala-infra. T-0087.`, applying
`PermitRootLogin no`, `AllowUsers tvolodi viktor_d binali_r`, `MaxAuthTries 6`,
`LoginGraceTime 120`, and post-quantum KexAlgorithms (`mlkem768x25519-sha256`,
`sntrup761x25519-sha512`) — none of which match this project's fleet-standard sshd
pattern (T-0093/T-0102). A `.bak.20260627T145652Z` sibling file shows the `AllowUsers`
line was edited in place, growing from `tvolodi` alone to `tvolodi viktor_d binali_r`.
Two real, provisioned, sudo-capable local accounts, `viktor_d` (uid 1001) and
`binali_r` (uid 1002), exist on the host with home directories showing activity as
recently as 2026-06-28 — both accounts and this hardening directly contradicted
`landscape/hosts/ubuntu-16gb-nbg1-1.md`'s then-current claims that sshd hardening was
"⏳ pending" and that the account list was a "clean slate" of `root`, `nobody`,
`tvolodi` only. A grep across this repo's `tasks/` and `runs/` trees (performed by the
attempt-3 executor) found no task or run numbered or labeled `T-0087` anywhere.

There is a **plausible but unconfirmed** corroborating pattern: task
[T-0105](./T-0105-create-operator-users-on-pro-data-tech-prod.md) ("Create non-root
operator users on pro-data-tech-prod") provisioned operator accounts named exactly
`viktor_d` and `binali_r` on `pro-data-tech-prod`, using the same
`<user>@ai-dala-infra-2026-06-27`-style key-naming convention, closed the same week.
This is a plausible explanation for where the `ubuntu-16gb-nbg1-1` accounts and
hardening pattern might have come from (e.g. a script or session that provisioned both
hosts and only recorded the pro-data-tech-prod side as a task) — but this is
speculation, not a confirmed causal link. T-0105's own task file and its executor/
validator handoffs make no mention of `ubuntu-16gb-nbg1-1` at all.

**Finding 2 — Hetzner Cloud Firewall port-22 rule widened to the entire internet.**
Attempt 3 of executor-infra (`runs/2026-08-17-prepare-letflow-host-001/step-0-6-firewall-baseline.json`,
captured via `GET /v1/firewalls/11204449`) found the firewall's TCP-22 inbound rule
carrying `source_ips: ["0.0.0.0/0", "::/0"]` and a `description` field reading
literally `"SSH from anywhere (widened 2026-06-27)"` — replacing what
`landscape/hosts/ubuntu-16gb-nbg1-1.md` and the original apply run
(`2026-06-27-apply-hetzner-firewall-001`, task T-0086) had documented as a single rule
scoped to `178.89.57.135/32` (the management workstation's outbound IP). No task or
run anywhere in this repo's `tasks/` or `runs/` trees documents this widening.
**Unlike Finding 1, no corroborating explanation or matching pattern was found
elsewhere in the repo for this change** — it is a bare, unexplained fact. The rule's
own `description` field is the only source for the 2026-06-27 date; no API audit log
or other record was consulted (Hetzner Cloud's API does not expose one to this
project's token scope).

Both findings share the same process-gap pattern: a deliberate-looking, named change
to this host's security posture, made entirely outside this repo's task/workflow/
landscape-update discipline. T-0134's solution-designer folded both into this single
observation task rather than splitting them, reasoning that "who/what changed this
host outside the process on 2026-06-27" is one coherent investigative question
regardless of whether the answer turns out to be one actor or several unrelated ones
(see `runs/2026-08-17-prepare-letflow-host-001/step-04-solution-designer.md`, section
"Revised scope of T-0135").

T-0134 itself has already reconciled the *symptoms* on `ubuntu-16gb-nbg1-1` (sshd
hardening replaced with the fleet-standard pattern; `viktor_d`/`binali_r` locked, not
deleted; the firewall's port-22 rule reconfirmed world-open per explicit user
instruction, not narrowed). This task is about the unanswered **process question**:
who or what made these changes, why did they bypass this repo's workflow, and whether
other undocumented changes exist elsewhere in the fleet that have not yet been
discovered.

## What done looks like

(Initial guess at acceptance criteria — refine on promotion to `pending`.)

- [ ] Determine, to the extent possible, who or what applied the `T-0087`-labeled sshd
      hardening and provisioned `viktor_d`/`binali_r` on `ubuntu-16gb-nbg1-1` on
      2026-06-27 (e.g. by comparing timing/tooling/key-naming fingerprints against
      T-0105's known-good record on `pro-data-tech-prod`, checking for shared
      provisioning scripts or automation outside this repo, or asking the user directly
      if they recall performing or authorizing this work manually).
- [ ] Determine, to the extent possible, who or what widened the Hetzner Cloud
      Firewall's port-22 rule to `0.0.0.0/0`+`::/0` on 2026-06-27. No corroborating
      lead currently exists for this one; document the investigation's outcome even if
      it is "cause could not be determined."
- [ ] Decide and document whether the `T-0087` label refers to a real task/run that
      existed in a different repo, a different tracking system, or was simply never
      recorded — and if a durable process gap is identified (e.g. a manual change
      path that bypasses this repo's workflow entirely), propose a fix.
- [ ] Spot-check whether similar undocumented changes exist on the other two managed
      hosts (`pro-data-tech-qa`, `pro-data-tech-prod`) or the Cloudflare zone, given
      that two independent undocumented changes were found on the same host on the
      same day — decide whether this warrants a broader audit.

## Result
<empty until closed>

## Notes

- This is an `observation`, not a `pending` task: it was discovered during T-0134's
  execution rather than being deliberately scoped work, and the acceptance criteria
  above are the landscape-updater's best initial guess, not user-refined criteria.
  Promote to `pending` (via `task-promoter`) once the user wants this actively worked.
- Both findings are already reflected as factual state in
  [`landscape/hosts/ubuntu-16gb-nbg1-1.md`](../landscape/hosts/ubuntu-16gb-nbg1-1.md)
  (Access section and Change log) — this task tracks the open *investigation*, not the
  remediation, which T-0134 already completed.
- Related: [T-0105](./T-0105-create-operator-users-on-pro-data-tech-prod.md) (the
  plausible-but-unconfirmed corroborating account-provisioning task on
  `pro-data-tech-prod`); [T-0134](./T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md)
  (the task whose execution discovered both findings and reconciled their on-host
  symptoms).

## History
- 2026-08-17: created from 2026-08-17-prepare-letflow-host-001
