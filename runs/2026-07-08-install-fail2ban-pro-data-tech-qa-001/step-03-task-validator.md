---
run_id: 2026-07-08-install-fail2ban-pro-data-tech-qa-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-02-landscape-reader.md
  - tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md
  - tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md
  - tasks/_index.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/README.md
  - shared/verdicts.md
  - workflows/infrastructure.md
artifacts_changed: []
next_step_hint: solution-designer
---

## Summary
T-0095 is well-formed, feasible, in-scope, and not in conflict with the current state. The dependency `T-0093` is `done` (verified in `tasks/_index.md`), the target host `pro-data-tech-qa` is reachable and at the expected post-hardening state (UFW active, sshd hardened, auth.log present, fail2ban absent), the `fail2ban` apt package is available at the expected `1.1.0-9` version, and the acceptance criteria are concrete and measurable against the proven T-0084 sibling pattern.

## Details
### Validation results

1. **Well-formed: PASS.** T-0095 names a concrete, verifiable end state with seven bullet-pointed acceptance criteria, all of which are objectively checkable: (a) package installed (verify via `dpkg -l fail2ban`); (b) jail file at `/etc/fail2ban/jail.d/sshd.local` with specific values for `enabled`, `maxretry`, `bantime`, `findtime`, `ignoreip`; (c) `banaction` value pinned; (d) `fail2ban-client status sshd` returns the jail active (specific CLI command); (e) service active+enabled (two `systemctl` queries); (f) brute-force simulation (4 failed attempts → IP banned, with `findtime + bantime` as the upper bound); (g) two specific landscape files updated. The task explicitly references the T-0084 sibling pattern (maxretry=3, bantime=600s, findtime=600s, ignoreip with management IP, banaction=iptables-multiport) — no ambiguity. The "Why" and "Notes" sections explain the rationale and reuse instructions. Not a vague intent.
2. **In-scope: PASS.** Task frontmatter `workflow: infrastructure`. T-0095 modifies a single managed host (installs a package, writes a config file, enables a systemd unit, updates two landscape files) — squarely within the `infrastructure` workflow's surface. Parallel to T-0084 (`ubuntu-16gb-nbg1-1` install) and T-0005 (`hetzner-prod` install), both of which also used the `infrastructure` workflow. No cross-host or CI/CD concerns.
3. **Not already done: PASS.** Live probe on `pro-data-tech-qa` (2026-07-08) confirms: `which fail2ban-server` exits 1 (empty), `ls -la /etc/fail2ban` returns "No such file or directory", `apt-cache policy fail2ban` shows `Installed: (none)`. Landscape file `landscape/hosts/pro-data-tech-qa.md` § Security posture explicitly states "fail2ban: NOT installed. Tracked as T-0095." No prior run has executed T-0095. The target state is not in place.
4. **No conflict with current state: PASS.** T-0093 hardened sshd (`PasswordAuthentication no` + `AllowGroups sshusers` + `PermitRootLogin prohibit-password`) — fail2ban does not conflict; it adds a rate-limit layer on top of the hardened sshd without altering the sshd config. T-0094 activated UFW with default-deny + 22/tcp allow (no source restrictions) — fail2ban coexists with UFW; the T-0084 design step 8 explicitly verified the `f2b-sshd` iptables chain sits alongside UFW's INPUT rules. T-0097 provisioned three operator users in `sshusers` group — fail2ban's `ignoreip` correctly includes `127.0.0.1/8 ::1 <mgmt-IP>` (NOT operator user accounts; the management workstation outbound IP is the right ignoreip, matching the T-0084 precedent and the T-0095 task body which names `178.89.57.135`). No conflict. The one minor note: T-0095's value of 3 failed attempts is more meaningful on a hardened sshd (where most attempts are key-failed noise) than on an unhardened one (where the brute-force is password-auth and would still be banned at the same threshold) — but this does not create a conflict, only a reduced residual value. Informational only.
5. **Discoverable scope: PASS.** All facts required to design the solution either exist in the landscape (T-0093 hardening, T-0094 UFW, T-0097 operator users, T-0095 task body jail config, T-0084 sibling design) or are flagged for executor live discovery (iptables backend, live management-workstation outbound IP). The sibling design `runs/2026-06-27-install-fail2ban-001/step-04-solution-designer.md` explicitly addresses both gaps at the executor layer (step 0 `api.ipify.org` for the IP, step 3 iptables probe for the backend, sub-step 7a sed-swap fallback for the rare backend mismatch). No critical unknowns remain.
6. **Workflow-specific rules respected: PASS.** The selected workflow `infrastructure` (per `workflows/infrastructure.md`) requires: (a) state-changing on a managed host always requires `NEEDS_APPROVAL` per `shared/approval-protocol.md` (this is a step-04/05 concern, not a step-03 concern — T-0095 has been pre-approved by user "just go" delegation per the step-01 handoff); (b) backup before destructive change — N/A; T-0095 creates a new config file (`/etc/fail2ban/jail.d/sshd.local` does not exist pre-install per live probe; nothing to back up); (c) blast radius `low`, reversibility `full` (consistent with T-0084, consistent with `apt install` + single file write); (d) landscape-updater (step 08) required to update `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md` per `landscape/README.md` § Editing rules — both files are listed in T-0095's `affects:` frontmatter. The plan is satisfiable.

## Issues / risks

- **User "just go" delegation is recorded in step-01 handoff but not in the task body.** The step-01 handoff (`runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-01-task-reader.md` Summary section) states: "Auto-approved via 'just go' delegation — no approval gate needed". The T-0095 task body itself does not record this user pre-approval explicitly. The step-05 user-approval agent should treat the run as already-approved (no further prompt) if and only if the orchestrator can cite the "just go" delegation out-of-band; otherwise the standard approval step is required per `shared/approval-protocol.md`'s "Always `NEEDS_APPROVAL` list" (package install on a managed host). This is a step-05 concern, not a step-03 PASS-blocker; flagged here so the orchestrator surfaces the ambiguity before drafting the plan.
- **T-0095 is `pending` but has reduced residual value post-T-0093.** As the step-02 handoff § Issues / risks notes, T-0093 disabled password auth and restricted to `sshusers` group — fail2ban's protection scope is now limited to key-failed attempts. Still worth installing for baseline consistency with `hetzner-prod` and `ubuntu-16gb-nbg1-1`, and as a defense-in-depth layer if sshd is later reconfigured. Informational only; does not change the PASS verdict.
- **Bantime/findtime choice (600s/600s).** Same as T-0084 and T-0005 — a deliberately conservative pair (10 minutes ban after 3 fails in 10 minutes). The user may want longer `bantime` (`-r` recidive jail) in the future, but T-0095 is explicitly scoped to the sshd jail only. Not a PASS-blocker.
- **No "Approval" reference task for fail2ban install on pro-data-tech-qa.** T-0095 task body does not list an approval sub-task. The T-0084 sibling task (`T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md`) similarly has no approval sub-task and ran as a single state-changing run on 2026-06-27 — same pattern is fine here. Informational.

## Open questions
None for step 03. All six validation checks pass. The handoff is ready for the solution-designer (step 04).
