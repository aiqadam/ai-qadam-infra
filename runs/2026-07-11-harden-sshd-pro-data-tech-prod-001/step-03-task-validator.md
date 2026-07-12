---
run_id: 2026-07-11-harden-sshd-pro-data-tech-prod-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0102-harden-sshd-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-02-landscape-reader.md
  - tasks/T-0102-harden-sshd-on-pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: solution-designer (step 04) — design the sshd hardening plan for pro-data-tech-prod, modelled on T-0093 / 2026-07-08-harden-sshd-pro-data-tech-qa-001, with the root-in-sshusers ordering constraint made explicit
---

## Summary

Task T-0102 is valid and safe to proceed. All six validation checks pass: the task is well-formed with 12 explicit acceptance criteria, correctly scoped to the infrastructure workflow, not already done (host is currently UNHARDENED), free of landscape conflicts, fully discoverable from existing landscape data, and satisfies all three workflow-specific rules. The critical ordering constraint (create sshusers group and add root before applying AllowGroups) is documented in the task and in both upstream handoffs. Rollback is possible via backup + sshd -t gate. Root is the sole account and remains the only SSH principal until T-0105 lands, which is expected and safe. Verdict: PASS.

## Details

### Validation results

1. **Well-formed: PASS** — The task names a concrete, verifiable end state: 12 acceptance criteria (9 sshd directives, sshd -t validation gate, active-session preservation, 20+ verification checks), all machine-verifiable. No vague intent language.

2. **In-scope: PASS** — Workflow `infrastructure` covers "OS package install/upgrade, systemd unit changes, firewall rules" and "Any change to a managed host." Modifying sshd configuration on `pro-data-tech-prod` is squarely within scope.

3. **Not already done: PASS** — Landscape confirms host is UNHARDENED: `PermitRootLogin yes`, `PasswordAuthentication yes`, `MaxAuthTries 6`, `LoginGraceTime 120`, `X11Forwarding yes`, no `AllowGroups` restriction, no project-managed drop-in files under `/etc/ssh/sshd_config.d/`. None of the target directives are in place.

4. **No conflict with current state: PASS** — No landscape fact contradicts the change. The host has no AllowGroups restriction that would be broken by adding one. The only structural difference from the QA reference run (no operator users) is explicitly documented in both the task ("Must create sshusers group and add root to it BEFORE setting AllowGroups sshusers") and step-02 — and the mitigation (root in sshusers temporarily, until T-0105) is unambiguous.

5. **Discoverable scope: PASS** — All facts needed for design are present in the landscape:
   - Current sshd parameter values: known (from `sshd -T` probe in T-0101 discovery run)
   - Target drop-in file contents: fully specified (QA post-T-0093 files documented in step-02)
   - SSH access path and key: documented (`root@95.46.211.224`, `pro-data.tech-prod-instance_rsa.ppk`)
   - No-operator-users difference: documented with explicit mitigation
   - Advisory gap (confirm root-only during execution via `getent passwd`) is non-blocking; executor can verify live

6. **Workflow-specific rules respected: PASS**
   - *Idempotency*: Drop-in file creation under `/etc/ssh/sshd_config.d/` is idempotent; re-running the executor overwrites the same files and reloads sshd. sshd -t gate prevents reload of invalid config on any retry.
   - *Backup before destructive changes*: Step 01 confirms the design requires a backup of the original sshd_config before any changes. Rollback path is: delete drop-in files, reload sshd — restoring cloud-init defaults. Satisfiable.
   - *Verify in two places*: Task requires 20+ on-host verification checks (sshd -T output assertions) and the QA reference run included session-preservation verification. External verification (SSH connection test from outside the active session) is achievable by the execution-validator. Satisfiable.

## Issues / risks

- **Lockout risk (CRITICAL, mitigated):** `AllowGroups sshusers` will deny ALL SSH logins if the `sshusers` group has no members at reload time, or if root is not in the group. Since no operator users exist on prod, root MUST be added to `sshusers` before the drop-in files are loaded. The solution designer must make this step non-optional and pre-validated — the executor must confirm `id root | grep sshusers` returns positive before every sshd reload.
- **No fallback console access confirmed:** pro-data.tech provider console access is not documented in the landscape. If root is locked out despite safeguards, out-of-band recovery path is unknown. This amplifies the lockout risk: the `sshd -t` gate and `sshusers` pre-check are the only safeguards; neither must be skipped.
- **root-in-sshusers is temporary:** Root will be in `sshusers` only until T-0105 provisions operator users. The landscape update (step 08) must record this transitional state clearly so T-0105 knows to add operator users to `sshusers` and optionally remove root from it.
- **12 pending package upgrades outstanding** on the host (including possible openssh-server update, tracked separately). Executor should check `apt list --upgradable` at session start and flag if openssh-server is in the list; no action required in this run.
