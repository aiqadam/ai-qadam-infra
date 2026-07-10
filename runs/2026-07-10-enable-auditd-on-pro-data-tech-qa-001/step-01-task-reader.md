---
step: 01
agent: task-reader
run_id: 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
task_id: T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
verdict: PASS
inputs_read:
  - tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md
  - tasks/_index.md
  - runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-qa.md
---

# Step 01 — task-reader

## Task summary

Install and enable `auditd` on `pro-data-tech-qa` (95.46.211.230) — install the Ubuntu 26.04 stock `auditd` package via `apt`, populate `/etc/audit/rules.d/audit.rules` with a project-defined "sane" ruleset (no in-repo precedent; solution-designer must design), enable the `auditd.service` unit at boot, and verify that `ausearch` returns recent events of the expected classes. The original T-0096 was created 2026-07-08 as a deferrable observation citing a T-0088 precedent (kernel 7.x + Ubuntu 26.04 auditd compatibility notes); on 2026-07-10 the user promoted it to execution after T-0099 brought the host onto a stable `7.0.0-27-generic` kernel and removed the deferral rationale. The T-0088 reference in the task body is a dangling link to a file lost in the 2026-07-07 secrets-inventory scrub (per [T-0091](../../tasks/T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md)); the user has explicitly authorized execution, so this is NOT a blocker — recorded as a context note only.

## Acceptance criteria (extracted)

These are the "What done looks like" checkboxes from the task body, translated into inputs the step-07 execution-validator will check:

1. **`auditd` package installed via `apt install auditd`** — Ubuntu 26.04 stock package (not a PPA, not a backport). The installer will pull in `auditd` + `audispd-plugins` (default Depends in Ubuntu) but no audit dispatchers need to be configured for this task.
2. **`/etc/audit/rules.d/audit.rules` populated with the project's "sane ruleset".** No in-repo precedent exists: T-0047 (the same observation on `hetzner-prod`) is itself deferred as an `observation` and has never been promoted. The task body defers to "the project's sane ruleset (sibling of `hetzner-prod` if/when T-0047 lands)" — but T-0047 has NOT landed, so there is no concrete reference. **Solution-designer (step 04) must design a sensible default ruleset from scratch** for this host. Minimum bar (to be formalized in step 04): at least one rule covering each of `USER_LOGIN`, `USER_AUTH`, and `EXECVE` event classes (because the ausearch verification step queries all three); immutable `-e 2` to lock the kernel audit subsystem; reasonable buffer/rotation (`-b 8192`, `-f 1`); `log_file`/`log_format` defaults.
3. **`auditd.service` is `active` AND `enabled`** at boot — both `systemctl is-active auditd` returns `active` and `systemctl is-enabled auditd` returns `enabled`. Survives at least one reboot (the task body does not require a reboot as part of this run; if the ruleset changes are applied before boot, the in-kernel state must also reflect them — `auditctl -l` should list the same rules as the file).
4. **`sudo ausearch -m USER_LOGIN,USER_AUTH,EXECVE` returns a reasonable number of recent events** — sanity check that the audit subsystem is generating records, not just installed. Pass criterion to be defined by validator (suggested: at least one event of each class within the post-install window, i.e., the executor's own `ausearch` run plus any service start / login that occurred since install).
5. **No kernel oops / auditd crashes within 24h of install (T-0088 risk mitigation).** This is a deferred-verification check; within a single run the validator can only confirm `auditd` is running cleanly and `journalctl --boot=-1 --priority=err | grep -iE 'auditd|kernel'` returns no relevant errors. The "24h soak" criterion is structurally not enforceable inside this 8-step run; flagged for either (a) acceptance via "no crashes observed during run window" or (b) a follow-up observation. Recommend (a) for this run.
6. **`landscape/hosts/pro-data-tech-qa.md` updated** — `## Security posture` auditd note removed (replaced with an auditd-present note pointing to T-0096 as `done`); `## What needs to happen` item #6 (auditd entry) marked done; `## Change log` gets a 2026-07-10 entry for T-0096; `## Open tasks affecting this host` updates T-0096's row to `DONE`. This is step 08's job; mentioned here so validator can confirm the landscape diff in its check matrix.

## Preconditions

These must be true before step 06 (executor-infra) starts. All are met as of T-0099 closeout 2026-07-10T06:21:12Z:

- Host `pro-data-tech-qa` is reachable on `root@95.46.211.230` via the management workstation key (`pro-data.tech-qa-instance_rsa.ppk`). `Test-NetConnection -Port 22` and `ssh -o BatchMode=yes root@95.46.211.230 'sudo -n true && echo SUDO_OK'` both succeed.
- Kernel is `7.0.0-27-generic` (post-T-0099 reboot 2026-07-10T06:14:28Z → 06:21:12Z, downtime 6m 44s, all 9 V-checks PASSED). The T-0088 deferral rationale (kernel 7.x compat issues) is no longer applicable; the new kernel is the stable target.
- `/var/run/reboot-required` is **absent** post-reboot — clean boot, no pending reboot.
- `apt` is in a quiescent state except for the 4 phased-rollout packages (`fwupd`, `libfwupd3`, `python3-software-properties`, `software-properties-common`) which are not blocking and not in scope of this run.
- AppArmor baseline MAC remains in place (179 profiles loaded, 103 enforce) — auditd is the kernel-level audit trail, orthogonal to AppArmor.
- `fail2ban` (T-0095) and UFW (T-0094) are active and enabled; sshd (T-0093) is hardened. The auditd install must not perturb any of these.
- `ai-qadam-test-db-1` Docker container is `Up (healthy)` — the auditd install must not perturb Docker / containerd / Compose.
- Pre-reboot `pg_dump` + `etc-snapshot` from T-0099 are preserved at `/var/backups/pre-T0099.20260710T061200Z/` (for any future rollback). No equivalent pre-auditd snapshot is required by the task, but the solution-designer may want to capture `/etc/audit/` and `/etc/audit/rules.d/` state (which is empty/non-existent today since auditd is not installed).

## Out of scope

Explicitly NOT being done in this run (so neither the solution-designer nor the executor proposes them and the validator does not check them):

- **NOT T-0090a** (Phases F–I: nginx + UFW 443/tcp + Cloudflare DNS + public HTTPS for `qadam-test.ai-dala.com`). That is its own deferred task (P2, `kind: observation`).
- **NOT T-0100** (container hardening of `ai-qadam-test-db-1`: User/CapDrop/SecurityOpt/ReadonlyRootfs). Separate observation (P2).
- **NOT T-0099** (kernel upgrade + reboot). Already done 2026-07-10 by run `2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001`. This run depends on T-0099 having landed but does not re-do it.
- **NOT T-0047** (the same observation on `hetzner-prod`). Different host, different deferred task; do NOT install auditd on `hetzner-prod` as part of this run.
- **NOT dispatchers / audisp-remote / ausearch-to-siem** — the task body only requires the local audit trail. No syslog forwarding, no remote log shipping. `audispd-plugins` may be pulled in as a default Depends, but should NOT be configured.
- **NOT CIS-benchmark-complete hardening of audit rules** — the task body calls for a "sane" ruleset, not full CIS / DISA-STIG coverage. The solution-designer's ruleset should be the minimum that exercises the three ausearch event classes in acceptance criterion 4 plus reasonable defaults.
- **NOT AppArmor changes** — AppArmor is already in enforce mode and is the project's MAC baseline; auditd is orthogonal.
- **NOT rotation/triage policy for `/var/log/audit/audit.log`** — Ubuntu's stock `auditd` package ships with `logrotate` integration that is sufficient; no custom rotation policy is in scope.

## Risks

1. **No in-repo ruleset precedent.** T-0047 (`hetzner-prod` auditd install) is itself deferred as an observation and has never landed, so this run will be the **first** auditd install in this project. The solution-designer (step 04) must design the ruleset from scratch — there is no sibling to copy from. Suggested minimum bar for the ruleset: (a) buffer/rotation defaults (`-b 8192`, `-f 1`); (b) immutable at end-of-ruleset (`-e 2`); (c) at least one rule per event class needed by criterion 4 (`USER_LOGIN`, `USER_AUTH`, `EXECVE`); (d) optional but cheap additions that match the project's existing audit signal (auth-related file watches on `/etc/passwd`, `/etc/shadow`, `/etc/sudoers.d/`; privileged command execution on `/usr/bin/sudo`, `/usr/bin/su`).
2. **T-0088 reference is dangling.** The task body cites a T-0088 precedent that no longer exists as a file (lost in the 2026-07-07 secrets-inventory scrub per T-0091). The deferral rationale is therefore **unsupported by a current document** but the user has explicitly authorized execution anyway. Noted for context, not a blocker. The kernel 7.x + Ubuntu 26.04 compat risk is unmeasured; the 24h-no-oops criterion (criterion 5) is the only direct mitigation, and it is structurally limited to the run window.
3. **Audit log file ownership / permissions.** Stock Ubuntu `auditd` package creates `/var/log/audit/audit.log` as root:root mode 0640 (group `adm`). If any post-install tooling tries to read the audit log without group `adm` membership, it will fail. The ausearch verification (criterion 4) uses `sudo ausearch …`, which sidesteps this. If the ruleset adds custom file watches that the project later wants to monitor via a non-root user, that user will need `adm` group membership — out of scope for this run.
4. **`auditd` interacts with `auditctl` reloads.** After the ruleset file is written, the daemon needs a `sudo augenrules --load` (or `sudo service auditd reload`) to pick up the new rules. Solution-designer must specify the exact reload command and the executor must verify `auditctl -l` matches the file's contents.
5. **Reboot interaction (low risk).** The task body does NOT require a reboot. The `auditd.service` should be `active` and `enabled` after `systemctl enable --now auditd` without needing a reboot. The 24h soak (criterion 5) implies at least one reboot in the window — the project does not need to schedule one inside this run; criterion 5 is satisfied by the absence of crashes in the post-install window.
6. **First auditd install on this kernel patch level.** Audit subsystem internals have changed across kernel 7.x patches. There is a non-zero risk of a panic on first service start (the exact T-0088 risk class). Mitigation: the executor should `systemctl start auditd` and immediately check `systemctl status auditd` + `journalctl -u auditd -n 50` for any kernel error before declaring install complete. If a panic occurs, the rollback path is `apt purge auditd` and reboot — and the task should be re-promoted to observation pending a workaround.
7. **No off-site storage / no external audit shipping.** Per project hard rule (README § Backups & storage policy), no external storage will be provisioned. Audit logs stay on local disk (`/var/log/audit/`). No audit log shipping, no SIEM, no cloud-archive. Log retention is whatever the stock logrotate config provides.

## Issues / risks carried forward to step 02 (landscape-reader)

- Landscape `landscape/hosts/pro-data-tech-qa.md` currently describes `auditd` as "NOT installed" with a deferral note. Step 02 should confirm this is still accurate as of run start (it is, per T-0099 closeout 2026-07-10).
- Step 02 should also note that there is no in-repo "sane ruleset" reference — the landscape does not document one, and neither `hetzner-prod` nor `ubuntu-16gb-nbg1-1` has auditd installed.
- The audit log path on this host is **not** mentioned in the current landscape; step 02 may want to flag this as a documentation gap for step 08 to close (it will be filled in by step 08 after the install lands).

## Open questions (optional)

None — the task is unambiguous, the user has explicitly overridden the original T-0088 deferral, and all preconditions are met.