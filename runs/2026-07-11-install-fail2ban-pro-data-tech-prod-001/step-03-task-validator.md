---
run_id: 2026-07-11-install-fail2ban-pro-data-tech-prod-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0104-install-fail2ban-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-install-fail2ban-pro-data-tech-prod-001/step-02-landscape-reader.md
  - tasks/T-0104-install-fail2ban-on-pro-data-tech-prod.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: solution-designer (step 04) — all checks pass; note jail.local values differ from QA reference and idempotency must be explicit in the plan
---

## Summary

T-0104 is validated: all six checks pass. Prerequisites (UFW active, sshd hardened) are confirmed in the landscape, fail2ban is absent on `pro-data-tech-prod`, the acceptance criteria are concrete and achievable, and no conflicts or blockers exist.

## Details

### Validation results

1. **Well-formed: PASS** — The task defines five concrete, command-verifiable end states: package installed, `/etc/fail2ban/jail.local` created with specific values (`bantime=1h`, `findtime=10m`, `maxretry=5`), service enabled+started, `fail2ban-client status sshd` active, 1 jail loaded. No vague intent — every criterion has a verification command.

2. **In-scope: PASS** — The infrastructure workflow explicitly covers "OS package install/upgrade, systemd unit changes, firewall rules" and "New tool installation or removal on managed hosts." Installing fail2ban (apt package + systemd unit + iptables integration) falls squarely within this scope.

3. **Not already done: PASS** — `landscape/hosts/pro-data-tech-prod.md` explicitly records fail2ban as NOT installed and flags it as a HIGH severity security gap. Step 02 confirms no iptables-level brute-force protection exists. Target state is not in place.

4. **No conflict with current state: PASS** — Both prerequisites stated in T-0104 are confirmed satisfied by the landscape:
   - UFW is active (T-0103 completed 2026-07-11; deny-incoming default; 22/tcp, 80/tcp, 443/tcp allowed).
   - sshd is hardened (T-0102 completed 2026-07-11; key-only auth; port 22; `MaxAuthTries 3`; `AllowGroups sshusers`).
   - No nginx on prod — the "no nginx jail" constraint is consistent with the actual host state.
   - Pending T-0105 (operator users) has not run, but this task does not interact with the `sshusers` group or user provisioning.

5. **Discoverable scope: PASS** — All facts required to design the solution are present in the landscape: SSH port (22), UFW rules, sshd config, fail2ban absence, QA reference implementation (T-0095 on `pro-data-tech-qa`), SSH access credentials. Two minor items require live capture during execution (live `dpkg -l fail2ban` to confirm absence, mgmt workstation public IP for `ignoreip`), both routine inline checks with well-understood patterns from the QA run.

6. **Workflow-specific rules respected: PASS** — All three infrastructure workflow rules are satisfiable:
   - **Idempotency:** `apt-get install fail2ban` is idempotent. Writing `jail.local` to a new file (fail2ban not yet installed, so no pre-existing file) is idempotent if the plan guards against overwrite. Solution designer must include an explicit idempotency check (e.g. back up any existing `jail.local` before writing, or use a conditional write). Satisfiable.
   - **Backup before destructive changes:** No existing config files will be overwritten — fail2ban is not installed and therefore `/etc/fail2ban/jail.local` does not exist. No destructive operation in scope. Rule satisfied by absence of destructive steps.
   - **Verify in two places:** Host-side verification (`fail2ban-client status sshd`, `fail2ban-client status`, `systemctl is-active fail2ban`) is well-defined. External observable behavior (HTTP/DNS probe) is not applicable for a brute-force daemon; the rule's "wherever applicable" qualifier covers this case. The execution-validator should confirm the systemd unit status as the second verification point.

## Issues / risks

- **jail.local values differ from QA:** T-0104's acceptance criteria (`bantime=1h`, `findtime=10m`, `maxretry=5`) intentionally differ from the QA actual config (`bantime=600s`, `findtime=600s`, `maxretry=3`). Solution designer must document this delta explicitly and the executor must not copy values from the QA landscape file.
- **12 pending apt upgrades on prod:** No blocking impact on this task. The solution designer and executor should note this but need not address it in this run.

## Open questions

none
