---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-07-14T01:00:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md
artifacts_changed: []
approved_by: user
---

## Summary
User approved the full T-0112 plan as-is: dedicated `deploy` system user on both `pro-data-tech-qa` and `pro-data-tech-prod`, admitted via a new `deploybots` group added to sshd's `AllowGroups` (alongside the existing `sshusers`), restricted to a forced-command placeholder script (`no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`), no sudo (`docker` group membership instead), two new dedicated local ed25519 keypairs (private keys never touch the hosts), and the mandatory Penpot no-regression check on prod immediately after the sshd reload.

## Details
The three converging design decisions from the solution-designer's plan were presented together with the overall approval ask, and all were accepted as recommended: (1) new `deploybots` group rather than reusing `sshusers`; (2) forced-command restriction (with `no-pty` added beyond the task's own baseline) rather than a general shell login; (3) no sudo — `docker` group membership instead, matching existing operator precedent.

User was also informed explicitly that after this task executes, they must manually paste four values into GitHub Actions repository secrets in `aiqadam/ai-qadam-platform` (`QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`), since this repo's tooling has no GitHub API write access to repo secrets — this is a hard, unavoidable manual step, not something executor-infra will attempt.

**Approved as-is, no modifications requested.** Executor-infra should execute Steps 0 through 13 exactly as written in `runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md`, including the hard escalate-don't-improvise gate at Step 0 if the checkout directory ownership/mode turns out more restrictive than expected.

## Issues / risks
None — user approved the designer's full recommended plan without changes, including acknowledging the manual GitHub Actions secrets step required afterward.
