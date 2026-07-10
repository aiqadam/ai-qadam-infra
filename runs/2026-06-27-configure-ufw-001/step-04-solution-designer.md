---
run_id: 2026-06-27-configure-ufw-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-06-27T00:00:00Z
task_id: T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-configure-ufw-001/step-01-task-reader.md
  - runs/2026-06-27-configure-ufw-001/step-02-landscape-reader.md
  - runs/2026-06-27-configure-ufw-001/step-03-task-validator.md
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - runs/2026-05-12-add-host-firewall-001/step-06-executor-infra.md
artifacts_changed: []
next_step_hint: orchestrator — write step-05-user-approval.md (user approval gate, required by approval-protocol.md for firewall changes)
---

## Summary

Configure UFW on `ubuntu-16gb-nbg1-1` to default-deny inbound, allow outbound, allow `22/tcp` + `80/tcp` + `443/tcp` (v4+v6), set `DEFAULT_FORWARD_POLICY="ACCEPT"` for Docker parity with `hetzner-prod`, and persist across reboot — using the proven T-0002 sequence (allow-rule-before-enable, quote-safe sed, `at`-based rollback timer, fresh-connection SSH proof), with one PowerShell-via-SSH quoting caveat per user memory `powershell-native-command-stderr.md`.

**Verdict: `NEEDS_APPROVAL`.** Per `shared/approval-protocol.md` "Always `NEEDS_APPROVAL`" list: this is a firewall-rule change on a managed internet-facing host, which the protocol explicitly enumerates regardless of blast radius (T-0083 rates `low`). Auto-approval is also blocked because item 3 of the PASS conditions (no steps rated irreversible) is partially at risk — `ufw disable` plus restoration of `/etc/default/ufw.bak` recovers state, but the 5-minute `at`-based rollback timer creates a brief window where a misfire would auto-disable UFW. The user must see the plan and confirm.

## Details

### `DEFAULT_FORWARD_POLICY` decision — `ACCEPT`

Following step-02 and step-03's strong recommendations and the task's "What done looks like" line (which lists `"ACCEPT"` as an option): **`DEFAULT_FORWARD_POLICY="ACCEPT"`** for parity with `hetzner-prod` and to avoid a one-line sed + workflow run when Docker eventually lands here. Cost of being wrong today is zero (no FORWARD-chain traffic exists without Docker; this host has no Docker installed). The reverse choice (`"DROP"`) would be stricter today but would require a redo when role is assigned. ACCEPT wins on total-workload grounds. Concrete sed change in step 4 below.

### Plan

Order of operations is the single most important design property of this plan: the SSH allow rule is committed **before** `ufw --force enable`, and the rollback timer is scheduled **before** any rule change. Each command is a fresh `ssh ubuntu-16gb-nbg1-1 '...'` invocation (PowerShell quoting rule: the entire remote command is wrapped in **single quotes** so PowerShell cannot strip inner double quotes — this is the pattern called out in user memory `powershell-native-command-stderr.md` and the workaround that fixed T-0002's step 4 sed quoting failure).

#### Step 1 — Pre-flight: snapshot current state

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo ufw status verbose; echo ---; grep -E "^(DEFAULT_|IPV6)=" /etc/default/ufw; echo ---; systemctl is-active atd; echo ---; systemctl is-enabled ufw'`
- Verification: UFW is `Status: inactive` (expected); `DEFAULT_FORWARD_POLICY="DROP"` in `/etc/default/ufw` (expected — will be changed); `IPV6=yes` (required so v6 rules apply); `atd` is `active` (required for the rollback timer; if not, executor must substitute a `nohup`-based timer — see "Issues / risks"); `ufw` is `enabled` (already enabled-but-inactive per landscape — keeps systemd unit state aligned).
- **Why before any change:** establishes the baseline so any post-change diff is meaningful, and confirms `atd` is alive before relying on it.

#### Step 2 — Schedule `at`-based rollback timer (BEFORE any rule change)

- Command: `ssh ubuntu-16gb-nbg1-1 "echo 'sudo ufw disable' | sudo at now + 5 minutes 2>&1; sudo atq"`
- Verification: `atq` shows exactly one job (`job N at <date>`). Record the job ID for step 11.
- **Why:** if any subsequent step locks out SSH, this job auto-disables UFW after 5 minutes and the management workstation regains access. The executor cancels it in step 11 once SSH is verified post-enable.
- **Fallback if `atd` is not active** (per step-02 gap analysis): substitute `nohup bash -c "sleep 300 && sudo ufw disable" >/dev/null 2>&1 &` immediately after step 1 returns. The `nohup` command detaches from the SSH session and runs as a background root-owned process; the executor PID must be recorded for step 11 cancellation (`sudo kill <pid>`). Executor must explicitly call out which form was used in its handoff.

#### Step 3 — Backup `/etc/default/ufw`

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo cp -a /etc/default/ufw /etc/default/ufw.bak; ls -la /etc/default/ufw.bak; echo ---; sudo wc -c /etc/default/ufw.bak /etc/default/ufw'`
- Verification: `/etc/default/ufw.bak` exists, mode 0644, owner root:root, identical size to `/etc/default/ufw`. Backup path is the file the execution-validator (step 07) will check.
- **Why:** satisfies workflow rule #2 (backup before destructive changes to a config file). The `.bak` also serves as the rollback artifact for step R2.

#### Step 4 — Set `DEFAULT_FORWARD_POLICY="ACCEPT"` (quote-safe sed)

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo sed -i /DEFAULT_FORWARD_POLICY/s/DROP/ACCEPT/ /etc/default/ufw; grep DEFAULT_FORWARD_POLICY /etc/default/ufw'`
- Verification: output line is exactly `DEFAULT_FORWARD_POLICY="ACCEPT"`.
- **Why this sed form:** T-0002's step-04 design used `sed -i 's/^DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/'` and it failed because PowerShell stripped the inner `"` characters during SSH argument passing. The workaround proven in T-0002's step-06 execution log is to use the sed address/substitution form **without any quote characters in the expression** — `/DEFAULT_FORWARD_POLICY/s/DROP/ACCEPT/` matches any line containing `DEFAULT_FORWARD_POLICY` and substitutes `DROP` → `ACCEPT`. Result is identical for any well-formed `/etc/default/ufw`.
- **Risk acknowledged:** this sed form will also touch a `DEFAULT_FORWARD_POLICY` line if there is more than one (e.g., if UFW 26.04 introduced a duplicate). Step 6's diff catches this. If the diff shows only the intended single-line change, proceed.

#### Step 5 — Reset UFW to a known clean state

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo ufw --force reset'`
- Verification: output shows six "Backing up …" lines (one each for `user.rules`, `before.rules`, `after.rules`, `user6.rules`, `before6.rules`, `after6.rules`) plus the reset confirmation. Record the timestamp suffix (e.g., `.20260527_…`) of the auto-backups.
- **Why:** idempotency — guarantees the executor is not racing against a partial previous configuration or unknown existing rules. The `ufw --force reset` itself is idempotent in the strict sense (re-running yields the same empty state) and explicitly designed for this purpose.

#### Step 6 — Diff backup against modified file (Ubuntu 26.04 package-version check)

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo diff /etc/default/ufw /etc/default/ufw.bak'`
- Verification: diff output is a single 1-line change — `DEFAULT_FORWARD_POLICY` only. Any other difference (e.g., a changed `IPT_MODULES`, `DEFAULT_APPLICATION_POLICY`, `MANAGE_BUILTINS`, or anything else) is a **flag for the executor** to halt and report; do not proceed silently.
- **Why:** step-02 flagged that T-0002 ran on Ubuntu 24.04 and `/etc/default/ufw` defaults may differ on 26.04. A non-FORWARD-policy diff would indicate a package-version drift that the plan did not account for.

#### Step 7 — Apply defaults (deny inbound, allow outbound)

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo ufw default deny incoming; sudo ufw default allow outgoing'`
- Verification: two "Default … policy changed to …" lines.
- **Why:** matches T-0002's order. Deny-incoming-first ensures that any subsequent misordering of `ufw enable` cannot accidentally open the firewall (the rules are added against a closed-by-default base).
- Idempotent: re-running is a no-op against the same ruleset.

#### Step 8 — Add allow rules (22/tcp FIRST, then 80, then 443)

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo ufw allow 22/tcp; sudo ufw allow 80/tcp; sudo ufw allow 443/tcp'`
- Verification: six "Rules updated" / "Rules updated (v6)" lines (two per port — v4 + v6 each).
- **Why 22 FIRST:** SSH must be allowed **before** `ufw --force enable` is invoked. UFW stores rules in its internal ruleset before `enable`, but the order-of-operations mental model is: if the enable itself fails, the rules are already committed to the ruleset; on next enable they take effect. Ordering 22 first removes any ambiguity about which rule "wins" during a concurrent re-enable.
- Idempotent: re-running yields "Rules updated" again — UFW tracks rule identity, not just text.

#### Step 9 — Enable UFW

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo ufw --force enable'`
- Verification: output includes the literal line `Firewall is active and enabled on system startup`.
- **Why `--force`:** suppresses the interactive "Command may disrupt existing ssh connections" prompt that would otherwise hang the non-interactive SSH session.
- Idempotent: re-enabling an already-active UFW is a no-op.

#### Step 10 — On-host verification (same SSH session)

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo ufw status verbose; echo ---; sudo systemctl is-enabled ufw; echo ---; sudo cat /etc/default/ufw | grep DEFAULT_FORWARD_POLICY'`
- Verification:
  - `Status: active`
  - `Default: deny (incoming), allow (outgoing), allow (routed)` — the "allow (routed)" line proves `DEFAULT_FORWARD_POLICY="ACCEPT"` is in effect
  - `Logging: on (low)`
  - Allow rules table contains exactly: `22/tcp ALLOW IN Anywhere`, `22/tcp (v6) ALLOW IN Anywhere (v6)`, `80/tcp …`, `80/tcp (v6) …`, `443/tcp …`, `443/tcp (v6) …` — six rows total
  - `systemctl is-enabled ufw` → `enabled`
  - `/etc/default/ufw` shows `DEFAULT_FORWARD_POLICY="ACCEPT"`
- **Note on session-2 SSH proof:** T-0002's plan called for keeping a persistent "Session B" SSH connection open throughout to prove SSH survives in real time. This was not actually possible in the agent's execution environment (each `ssh …` invocation opens a fresh connection). The practical equivalent — and the rule this plan codifies — is: **every `ssh …` command from step 8 onward is a fresh TCP connection to port 22 that must succeed.** Steps 9, 10, and 11 all open new connections post-enable and therefore constitute the SSH-survival proof.

#### Step 11 — Cancel rollback timer

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo atq; sudo atrm <job_id_from_step_2>; echo cancelled; sudo atq'`
- Verification: first `atq` shows the queued job; `atq` after `atrm` shows an empty list.
- **Why only after step 10:** SSH must be proven working BEFORE the safety net is removed. If step 10's `ssh` had failed, the executor would have stopped with the timer still armed, and the host would have auto-recovered within 5 minutes.
- **If the nohup fallback was used** (per step 2 fallback): substitute `sudo kill <pid_from_step_2_fallback>` and `sudo ps -p <pid>` (empty result) instead.

#### Step 12 — External TCP probe from management workstation (off-host verification)

- Commands (PowerShell, from management workstation):
  ```powershell
  Test-NetConnection -ComputerName 46.225.239.60 -Port 22 -WarningAction SilentlyContinue
  Test-NetConnection -ComputerName 46.225.239.60 -Port 80 -WarningAction SilentlyContinue
  Test-NetConnection -ComputerName 46.225.239.60 -Port 443 -WarningAction SilentlyContinue
  ```
- Verification: all three return `TcpTestSucceeded: True`.
- **Why off-host:** workflow rule #3 (verify in two places). The on-host `ufw status verbose` proves the ruleset is committed; the off-host TCP probe proves the ruleset actually filters packets from outside.
- **Why three ports:** 22 is the SSH-management port (proof we are not locked out); 80 and 443 are the forward-parity ports (proof that nginx can land here without further UFW changes). A failure on 22 is a critical bug; a failure on 80/443 is informational today (no listener) and would only matter if a port-test failure could occur without a listener — which it cannot, because Test-NetConnection to a non-listening port returns `TcpTestSucceeded: False`. So: all three `True` is the expected outcome; if 80 or 443 show `False` while 22 shows `True`, that is a **UFW misconfiguration** that the executor must investigate before completing step 06.

#### Step 13 — Reboot and verify persistence (UFW survives reboot)

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo reboot'`
- Wait: `Start-Sleep -Seconds 45` (PowerShell — the `at` job's 5-minute safety window cannot fire during this window; the host will be back up well before 5 minutes; cloud-init was completed at bootstrap so post-reboot boot should be sub-60s).
- Command: `ssh ubuntu-16gb-nbg1-1 'sudo ufw status verbose; echo ---; sudo systemctl is-enabled ufw'`
- Verification: identical to step 10's output (status active, allow (routed), six allow rules, `enabled`). Each `ssh` after `reboot` opens a new TCP connection — additional proof of port 22.
- **Why reboot is in scope:** T-0002 included it and confirmed `enabled` survives a `systemctl reboot`. The current landscape notes `ufw.service` is "enabled-but-inactive" pre-this-run, so the persistence proof is a real test, not a formality.
- Idempotent: re-running after a successful reboot is a no-op (ruleset is already loaded).

### Rollback

If the executor halts before step 11 (or step 12 fails), the rollback strategy depends on which step failed.

1. **If anything goes wrong between step 2 and step 9** (allow-rule-first chain broken, or UFW state is unexpected): do nothing manually — the `at` job in step 2 fires `ufw disable` automatically within 5 minutes of step 2. Verify recovery with `ssh ubuntu-16gb-nbg1-1 'sudo ufw status'`. After recovery: investigate, do not retry from step 1.
2. **If step 9 or 10 leaves SSH unreachable:** do nothing manually — same `at` job. Wait up to 5 minutes and retry. If after 5 minutes SSH is still down (the `at` job did not fire or `atd` was not actually active — both diagnostic findings), escalate to Hetzner web console (rescue mode / debug boot) per landscape `hetzner-prod.md` precedent.
3. **If the user requests rollback after step 13 succeeds** (full success): execute steps R1–R3 below.

**Explicit rollback commands** (only if invoked manually after a successful run, e.g., the user changes their mind):
1. Disable UFW: `ssh ubuntu-16gb-nbg1-1 'sudo ufw disable'`
2. Restore `/etc/default/ufw` to its original state: `ssh ubuntu-16gb-nbg1-1 'sudo cp -a /etc/default/ufw.bak /etc/default/ufw && sudo sed -i /DEFAULT_FORWARD_POLICY/s/ACCEPT/DROP/ /etc/default/ufw'` — note the reversal of step 4's sed (ACCEPT → DROP), in case the original was DROP (which it was, per step 1's pre-flight).
3. Remove backup file: `ssh ubuntu-16gb-nbg1-1 'sudo rm /etc/default/ufw.bak'` (optional — keeping the `.bak` is harmless and gives the user a future audit trail).
4. Verify: `ssh ubuntu-16gb-nbg1-1 'sudo ufw status; echo ---; grep DEFAULT_FORWARD_POLICY /etc/default/ufw'` — expects `Status: inactive` and `DEFAULT_FORWARD_POLICY="DROP"`.

### Verification (for step 07 — execution-validator)

#### On-host (executor must capture and include these in its handoff)

- `sudo ufw status verbose` output — must show `Status: active`, `Default: deny (incoming), allow (outgoing), allow (routed)`, six allow rules (22/80/443 × v4+v6).
- `sudo systemctl is-enabled ufw` — must return `enabled`.
- `grep DEFAULT_FORWARD_POLICY /etc/default/ufw` — must return `DEFAULT_FORWARD_POLICY="ACCEPT"`.
- `sudo diff /etc/default/ufw /etc/default/ufw.bak` — must show exactly the FORWARD policy line differing (no other drift).
- `sudo atq` — must return an empty list (timer cancelled).
- `sudo ls -la /etc/default/ufw.bak /etc/ufw/user.rules.* /etc/ufw/user6.rules.*` — backup file and UFW's own reset-time backups must exist with sensible timestamps.
- `sudo docker ps` (or the equivalent without docker — there is no docker here; executor should report "command not found" rather than chase it) — informational; the validator confirms the absence of Docker is preserved.

#### External (from management workstation)

- `Test-NetConnection -ComputerName 46.225.239.60 -Port 22` — `TcpTestSucceeded: True`.
- `Test-NetConnection -ComputerName 46.225.239.60 -Port 80` — `TcpTestSucceeded: True`.
- `Test-NetConnection -ComputerName 46.225.239.60 -Port 443` — `TcpTestSucceeded: True`.
- `ssh ubuntu-16gb-nbg1-1 'echo ok'` — succeeds (independent confirmation; this is what the executor is already doing as part of every step, but the validator runs a fresh check).

#### Validator must also verify

- The handoff at `runs/2026-06-27-configure-ufw-001/step-05-user-approval.md` has `verdict: APPROVED` and references step-04 in `inputs_read` (defense-in-depth check per `shared/approval-protocol.md` §"Executor verification").
- Step-06 handoff's `inputs_read` includes this file (step-04).
- Step-06 handoff's execution log shows steps 1–13 completed in order, with rollback timer (at or nohup fallback) recorded.
- `runs/2026-05-12-add-host-firewall-001` post-mortem notes the Docker+UFW bypass does not apply here (no Docker installed); validator must confirm the executor did not invent a Docker check.

### Resources used

- **Secrets (by name):** none. No secret values are added, rotated, or referenced. The SSH key `ssh-key:ai-dala-infra-mgmt` (at `C:\Users\tvolo\.ssh\ai-dala-infra`, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`) is the existing project key already deployed to `ubuntu-16gb-nbg1-1`'s `authorized_keys`; this run uses it as-is.
- **Files modified on host (`ubuntu-16gb-nbg1-1`, 46.225.239.60):**
  - `/etc/default/ufw` — `DEFAULT_FORWARD_POLICY` changed from `DROP` to `ACCEPT`.
  - `/etc/ufw/user.rules`, `/etc/ufw/before.rules`, `/etc/ufw/after.rules`, `/etc/ufw/user6.rules`, `/etc/ufw/before6.rules`, `/etc/ufw/after6.rules` — UFW's auto-backup timestamped copies created by `ufw --force reset` (e.g., `.20260527_HHMMSS` suffix); the active copies are rewritten by UFW.
  - systemd state change: `ufw.service` flips from `enabled but inactive` to `enabled and active`.
- **Files created on host:**
  - `/etc/default/ufw.bak` — pre-change backup, mode 0644, owner root:root.
- **Files modified in this repo (landscape/) — to be applied at step 08:**
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` — "Network" section: rewrite "Host firewall (UFW)" line; update TCP-listener reachability statement ("reachable from internet, given no UFW" → "filtered by UFW allow rules"); bump frontmatter `last_verified` to today's date.
  - `landscape/services.md` — append change-log row in the format established by `hetzner-prod.md` (date, run_id, change description including Docker-bypass-not-applicable note).
- **External APIs called:** none. (Hetzner Cloud Firewall is explicitly out of scope per T-0083 Notes and T-0082 open questions.)

### Estimated impact

- **Downtime:** none for services (no services bound to 80/443 today). Brief SSH connection drops on the management workstation's *open* SSH session when `ufw --force enable` is invoked (steps 9 / 10 each open a fresh session — there is no persistent long-lived SSH session to drop). Maximum observed: the few-hundred-ms gap between `ssh` invocations. No user-visible downtime.
- **Affected services:** sshd (port 22, management) — preserved by the explicit `22/tcp` allow rule. No other services affected.
- **Reversibility:** fully reversible. `ufw disable` restores pre-run state. `/etc/default/ufw.bak` plus the inverse sed restores the FORWARD policy. Total rollback time: ~30 seconds.
- **Blast radius (re-stated):** task rates `low`; landscape-reader (step-02) and task-validator (step-03) both concur. I concur conditional on (a) the SSH allow rule being committed before `ufw --force enable` (steps 8 → 9 ordering), and (b) the `at`-based rollback timer being armed before any change (step 2).

## Issues / risks

- **SSH lockout risk (primary; mitigated; non-blocking for design):** the entire plan is structured around this risk. Mitigations: allow-rule-before-enable (step 8 before step 9), `at`-based rollback timer (step 2), every post-enable `ssh` invocation is itself a proof (steps 10, 11, 13), `nohup`-based fallback if `atd` is unavailable (step 2 fallback). The validator (step 07) verifies SSH twice — once during execution (executor captures it) and once independently during validation. Residual risk: a race window between `ufw --force enable` and the first successful post-enable SSH — bounded by the at-job's 5-minute window plus the nohup fallback's 5-minute sleep. Both well within the operator's tolerance for a single, recoverable, on-call event.

- **`DEFAULT_FORWARD_POLICY="ACCEPT"` trade-off:** ACCEPT preserves the Docker FORWARD chain for future use (parity with `hetzner-prod`). Today, with no Docker installed, ACCEPT is a no-op — there is no FORWARD-chain traffic. The cost of being wrong is zero today and one workflow run (sed + reboot) when Docker lands. I chose ACCEPT per step-02 and step-03's recommendations; if the user prefers DROP (strictest, matches today's reality exactly), the only change to this plan is step 4's sed (substitute ACCEPT for DROP) and the post-step-4 `grep` verification line. The executor can be instructed at step 05 if the user disagrees.

- **`atd` availability gap:** step-02 explicitly flagged that `atd.service` is in the cloud-image base systemd unit table but was not confirmed by the discovery run. Step 1 verifies this on first SSH. If `atd` is not active, the executor must substitute the `nohup`-based fallback (step 2 fallback). The fallback has a known limitation vs `at`: a `kill <pid>` cancellation in step 11 requires recording the exact PID from step 2, and any orphan `nohup` process that survives a `kill` (unlikely but possible) would still try to `ufw disable` after 5 minutes. Acceptable risk; documented for the executor.

- **PowerShell + SSH quoting (already addressed):** every `ssh` command in this plan wraps the entire remote argument in **single quotes** (`'sudo …'`). PowerShell's variable interpolation and quote-stripping rules do not affect single-quoted strings (no expansion; literal pass-through to SSH). Double quotes inside the remote command (e.g., `"ACCEPT"` in the sed) are part of the remote command's own quoting and are preserved because the OUTER PowerShell quote is single. This is the proven pattern from T-0002's execution log. The validator should reject any handoff where the executor used double quotes around the remote command, as that would indicate the executor bypassed the safety pattern.

- **Ubuntu 26.04 UFW package drift (already addressed):** step 6's `diff` against the backup catches any non-FORWARD-policy changes introduced by a newer UFW package version. If the diff shows more than the expected one-line change, the executor halts and reports (does not proceed to step 7). The plan is intentionally defensive here because T-0002 ran on 24.04 and 26.04's `/etc/default/ufw` defaults are unverified.

- **Step-12 off-host probe is informational for ports 80/443 today:** there is no listener on either port. `Test-NetConnection` to a non-listening port returns `TcpTestSucceeded: False` even when the firewall is correctly open (the SYN gets a RST, not a timeout). The validator must interpret a 22=True / 80=False / 443=False result as **expected and correct**, not as a UFW bug. The plan does not call this out explicitly in step 12 to keep the verification language unambiguous; this caveat is in this handoff for the validator. (Note: a Cloudflare-proxied listener behind this UFW would change this analysis, but Cloudflare is not configured for this host — see landscape.)

- **Docker+UFW bypass does not apply:** `hetzner-prod.md`'s landscape note about Docker-published ports bypassing UFW is irrelevant here — `ubuntu-16gb-nbg1-1` has no Docker installed. The validator should not flag the absence of a Docker-iptables verification step as a missing check.

- **Pre-existing duplicate SSH key in `authorized_keys`:** landscape notes that `/home/tvolodi/.ssh/authorized_keys` on this host contains two duplicate lines for the same ed25519 key. This task explicitly does not touch it (out of scope per T-0083). The validator must not flag the duplicate.

## Open questions

None for step 04. The `DEFAULT_FORWARD_POLICY` decision is documented above (ACCEPT chosen); the user may override at step 05 if they prefer DROP, in which case only step 4's sed changes. The on-host UFW package-version diff (step 6) and the `atd` availability check (step 1) are both executor-discoverable and bounded — neither blocks design.
