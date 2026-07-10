---
run_id: 2026-07-08-install-ufw-pro-data-tech-qa-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-08T00:00:00Z
task_id: T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-03-task-validator.md
  - tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/hetzner-prod.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: orchestrator — write step-05-user-approval.md (NEEDS_APPROVAL gate per shared/approval-protocol.md; auto-approved via "just go" delegation per user prompt).
---

## Summary

Configure UFW on `pro-data-tech-qa` (95.46.211.230) to default-deny inbound, allow outbound, **default-deny forward** (explicit divergence from T-0083's ACCEPT), IPv6 enabled, and a single `ufw allow 22/tcp` from any source per user decision 2026-07-08 (no source-IP filter — defense-in-depth comes from sshd hardening + operator users + fail2ban). This run follows the proven T-0002/T-0083 sequence (allow-rule-before-enable, fresh-connection SSH proof, `at`-based rollback timer) with the T-0094 user-prompt divergence (forward policy DROP, single 22/tcp rule, full `/etc/ufw/` directory backup at `/tmp/ufw.pre-T0094.<UTC>.bak`).

**Verdict: `NEEDS_APPROVAL`.** Per `shared/approval-protocol.md` "Always `NEEDS_APPROVAL`" list: this is a firewall-rule change on a managed internet-facing host, which the protocol explicitly enumerates regardless of blast radius (T-0094 rates `medium` because pro-data.tech has **no outer cloud firewall** — UFW is the only filter). Auto-approval applies via user delegation "just go" — the orchestrator will write step-05 with `verdict: APPROVED` referencing this plan.

## Details

### `DEFAULT_FORWARD_POLICY` decision — `DROP` (explicit divergence from T-0083)

The T-0094 user prompt explicitly specifies `DEFAULT_FORWARD_POLICY="DROP"`. **This differs from the sibling precedent:**

| Host | Policy | Reason |
|---|---|---|
| `hetzner-prod` (T-0002, 2026-05-12) | `ACCEPT` | Docker installed; FORWARD chain is live |
| `ubuntu-16gb-nbg1-1` (T-0083, 2026-06-27) | `ACCEPT` | Docker pending; preserve for Docker parity |
| `pro-data-tech-qa` (T-0094, this run) | **`DROP`** | Per user decision 2026-07-08; Docker will need UFW adjustments when it lands |

**Why DROP is the user's choice here (and why it's safe):** Docker is NOT installed yet (`landscape/hosts/pro-data-tech-qa.md` "What runs here": "freshly provisioned Ubuntu 26.04 cloud image, no project services, no Docker, no nginx"). When T-0090 lands Docker on this host, the executor will need to revisit UFW and switch FORWARD policy back to ACCEPT (or configure Docker's `daemon.json` with `"iptables": false` and route everything through UFW rules explicitly). For T-0094 specifically, DROP is a strict no-op today (`/proc/sys/net/ipv4/ip_forward=0`) and a tight constraint once Docker lands — the executor of T-0090 will plan around it. Concrete sed change in step 5 below.

> **Note for landscape-updater (step 08):** the `## Network` section should call out this divergence from the sibling pattern explicitly, so the T-0090 executor (Docker install) knows that UFW forward policy is DROP and will need reconfiguration.

### Single allow rule — `22/tcp` from any source (user decision 2026-07-08)

Per T-0094 acceptance criteria + user decision 2026-07-08: **no source restrictions on the 22/tcp allow rule**. This differs from `ubuntu-16gb-nbg1-1` where the Hetzner Cloud Firewall restricts inbound to the management workstation's outbound IP at the cloud layer. pro-data.tech has no such outer filter (and per project policy, paid provider add-ons are out of scope).

**Defense-in-depth model that justifies the no-source-restriction decision:**

1. UFW only opens `22/tcp` (no 80/443 — no nginx yet; no app server; no Docker-published ports).
2. sshd is hardened (T-0093 done 2026-07-08): `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `AllowGroups sshusers`, hardened KEX/Ciphers/MACs (no SHA-1).
3. `sshusers` group has 4 members (root + tvolodi + viktor_d + binali_r); provider key is break-glass for root only.
4. fail2ban sshd jail is **queued** (T-0095, `status: pending`) — NOT installed at run time. This is the residual gap in defense-in-depth; the user accepts it as a temporary state and will run T-0095 as a follow-on.
5. All operator logins are key-only (T-0093 + T-0097); brute-force attempts cannot succeed without a private key.

### Plan

Order of operations is the single most important design property of this plan: the `/etc/ufw` directory backup happens **first** (step 1), the `/etc/default/ufw` backup is paired with that (step 2), the `at`-based rollback timer is armed **before** any rule change (step 4), the SSH allow rule is committed **before** `ufw enable` (step 8), and the rollback timer is cancelled **after** SSH is verified post-enable (step 10).

Each `ssh` command in this plan wraps the entire remote argument in **single quotes** (`'sudo …'`) so PowerShell cannot strip inner double quotes — the proven pattern from T-0002 / T-0083 and called out in user memory `powershell-native-command-stderr.md`.

**SSH user for this run:** `tvolodi@95.46.211.230` via `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 '…'` (ed25519, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`). Post-T-0097 this is the operator SSH path; the provider key (`pro-data.tech-qa-instance_rsa.ppk`) is break-glass only and the executor uses the operator key for everyday commands. The break-glass key is **not** used here.

#### Pre-flight (P01-P03) — run before any state-changing step

##### P01 — UFW package version

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'apt-cache policy ufw'`
- Verification: package is `Installed: <ver>` and `Candidate: <ver>` lines present; status `Candidate` matches `Installed` (no pending upgrade) or is newer (informational). If `Installed` is `(none)` — install via `apt-get install -y ufw` and re-verify. The landscape says `/usr/sbin/ufw` is present (binary installed by cloud-init), so this is expected to confirm a version, not trigger an install.

##### P02 — `/etc/ufw/` directory state

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'ls -la /etc/ufw; echo ---; sudo ls -la /etc/ufw/*.rules* 2>/dev/null | head -20'`
- Verification: `/etc/ufw/` directory exists with the standard UFW files (`user.rules`, `user6.rules`, `before.rules`, `before6.rules`, `after.rules`, `after6.rules` — possibly empty or absent depending on cloud-init). If the directory is empty/missing, `apt-get install -y ufw` populates it. **This is a state-of-the-art check** — the landscape-reader (step-02) flagged `/etc/ufw/` as a live-discovery gap.

##### P03 — Current iptables/ip6tables rules

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo iptables -L -n -v --line-numbers 2>&1 | head -50; echo ---; sudo ip6tables -L -n -v --line-numbers 2>&1 | head -30; echo ---; cat /etc/default/ufw'`
- Verification: all three chains (INPUT, OUTPUT, FORWARD) are at `policy ACCEPT` and there are no UFW-named chains (`ufw-before-input`, `ufw-before-output`, etc.) — confirms clean slate. The `cat /etc/default/ufw` shows the current `/etc/default/ufw` values; capture them so step 5's `diff` is meaningful.
- **Note on clean slate:** the landscape confirms `iptables` and `ip6tables` are at `policy ACCEPT` with no rules. fail2ban (T-0095) is NOT installed yet, so there will be no `f2b-sshd` chain. Docker is NOT installed, so there will be no `DOCKER` chain. If P03 reveals any pre-existing chain named `ufw-*`, `f2b-*`, or `DOCKER` — **halt and report** to the orchestrator (this would mean the host state differs from landscape; the plan needs amendment).

#### Main plan (10 steps)

##### Step 1 — Backup `/etc/ufw/` directory (full snapshot)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 "UTC=\$(date -u +%Y%m%dT%H%M%SZ); sudo cp -a /etc/ufw /tmp/ufw.pre-T0094.\${UTC}.bak; sudo ls -la /tmp/ufw.pre-T0094.*.bak; sudo find /tmp/ufw.pre-T0094.*.bak -type f | head -20"`
- Verification: `/tmp/ufw.pre-T0094.<UTC>.bak/` exists, owned by root:root, mode preserved, containing the same files as `/etc/ufw/`. **This is the primary rollback artifact** — if any later step leaves UFW in an inconsistent state, restoring this directory tree and running `sudo ufw reload` recovers the pre-change ruleset.
- **Why this form (vs `cp -r`):** `cp -a` preserves mode, ownership, timestamps — important because `/etc/ufw/user.rules` etc. are written by ufw at runtime and a permission drift would confuse the validator.
- **Backup location rationale:** the user prompt specifies `/tmp/ufw.pre-T0094.<UTC>.bak`. `/tmp/` is volatile on reboot on most systems; this is acceptable for a one-shot rollback artifact (the run completes within minutes and the validator checks the backup exists before completion). The T-0094 acceptance criterion's `/etc/default/ufw.bak` is a separate, persistent backup (step 2 below).

##### Step 2 — Backup `/etc/default/ufw` (T-0094 acceptance criterion)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo cp -a /etc/default/ufw /etc/default/ufw.bak; sudo ls -la /etc/default/ufw /etc/default/ufw.bak; echo ---; sudo wc -c /etc/default/ufw.bak /etc/default/ufw'`
- Verification: `/etc/default/ufw.bak` exists, mode 0644, owner root:root, identical size to `/etc/default/ufw`. Satisfies the T-0094 acceptance criterion: "Pre-change `/etc/default/ufw` backed up at `/etc/default/ufw.bak` (mode 0644, owner root:root)".
- **Why both backups:** step 1 captures the entire `/etc/ufw/` ruleset directory (rollback target if rules become inconsistent); step 2 captures the single config file separately (per T-0094's explicit acceptance criterion, and as a forensic record).

##### Step 3 — Verify ufw is installed (fallback install if needed)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'which ufw; echo ---; dpkg -l | grep -i "^ii  ufw" || sudo apt-get install -y ufw; echo ---; dpkg -l | grep -i "^ii  ufw"'`
- Verification: `which ufw` returns `/usr/sbin/ufw`; the second `dpkg -l` line confirms the package is installed (status `ii`). If `apt-get install` was needed, the second `dpkg -l` shows the freshly installed version.
- **Why:** P01 captured the available version; this step confirms the installed version and installs the package if cloud-init left it uninstalled (landscape says it's installed; this is a safety net).

##### Step 4 — Schedule `at`-based rollback timer (BEFORE any rule change)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 "echo 'sudo ufw disable' | sudo at now + 5 minutes 2>&1; sudo atq"`
- Verification: `atq` shows exactly one job (`job N at <date>`). Record the job ID for step 10.
- **Why:** if any subsequent step locks out SSH, this job auto-disables UFW after 5 minutes and the management workstation regains access. The executor cancels it in step 10 once SSH is verified post-enable.
- **Fallback if `atd` is not active** (per step-02 gap analysis on `ubuntu-16gb-nbg1-1` precedent): substitute `nohup bash -c "sleep 300 && sudo ufw disable" >/dev/null 2>&1 &` immediately after step 3 returns. The `nohup` command detaches from the SSH session and runs as a background root-owned process; the executor PID must be recorded for step 10 cancellation (`sudo kill <pid>`). Executor must explicitly call out which form was used in its handoff.
- **Verify `atd` is active first:** `ssh ... 'sudo systemctl is-active atd'` — if `inactive` or `unknown`, use the `nohup` fallback.

##### Step 5 — Set defaults in `/etc/default/ufw`

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo sed -i /DEFAULT_INPUT_POLICY/s/=.*/="DROP"/ /etc/default/ufw; sudo sed -i /DEFAULT_OUTPUT_POLICY/s/=.*/="ACCEPT"/ /etc/default/ufw; sudo sed -i /DEFAULT_FORWARD_POLICY/s/=.*/="DROP"/ /etc/default/ufw; sudo sed -i /^IPV6=/s/=.*/=yes/ /etc/default/ufw; grep -E "^(DEFAULT_|IPV6)=" /etc/default/ufw'`
- Verification: output is exactly four lines:
  - `DEFAULT_INPUT_POLICY="DROP"`
  - `DEFAULT_OUTPUT_POLICY="ACCEPT"`
  - `DEFAULT_FORWARD_POLICY="DROP"`
  - `IPV6=yes`
- **Why this sed form:** T-0002's step-04 design used `sed -i 's/^DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/'` and it failed because PowerShell stripped the inner `"` characters during SSH argument passing. The workaround proven in T-0002's step-06 execution log is to use the sed address/substitution form **without any quote characters in the expression** — `/DEFAULT_FORWARD_POLICY/s/=.*/="DROP"/` matches any line containing `DEFAULT_FORWARD_POLICY` and replaces the `=.*` portion (everything after the `=`) with `="DROP"`. Result is identical for any well-formed `/etc/default/ufw`.
- **Why DROP for forward (explicit divergence from T-0083):** see `## Details > DEFAULT_FORWARD_POLICY decision` above. This is the user-decision divergence; the user explicitly chose DROP.
- **Why IPV6=yes:** sibling hosts all have IPv6 enabled; even though the landscape notes "IPv6: not enumerated in the discovery probes; provider may or may not assign one", setting `IPV6=yes` is harmless if no IPv6 link is up (rules apply to a non-existent address family silently). The executor should also capture `ip -6 addr show` output in step 11 as informational (does not block the run).

##### Step 6 — Diff backup against modified file (Ubuntu 26.04 UFW package-version check)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo diff /etc/default/ufw /etc/default/ufw.bak'`
- Verification: diff output is exactly the four policy lines changing (DEFAULT_INPUT_POLICY, DEFAULT_OUTPUT_POLICY, DEFAULT_FORWARD_POLICY, IPV6). **Any other difference is a flag for the executor to halt and report**; do not proceed silently. (For example: UFW 26.04 might have introduced `IPT_MODULES` or `DEFAULT_APPLICATION_POLICY` defaults that differ from the original Ubuntu 26.04 cloud-init values.)
- **Why:** step-02 flagged that the exact `/etc/default/ufw` defaults on Ubuntu 26.04 are not pre-verified. A non-policy-line diff would indicate a package-version drift the plan did not account for.

##### Step 7 — Reset UFW to known clean state

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo ufw --force reset'`
- Verification: output shows six "Backing up …" lines (one each for `user.rules`, `before.rules`, `after.rules`, `user6.rules`, `before6.rules`, `after6.rules`) plus the reset confirmation. Record the timestamp suffix (e.g., `.20260708_HHMMSS`) of the auto-backups (UFW creates its own timestamped backups as part of `--force reset` — these are independent of the step-1 backup and serve as a second forensic trail).
- **Why:** idempotency — guarantees the executor is not racing against a partial previous configuration or unknown existing rules. The `ufw --force reset` is explicitly designed for this purpose and is idempotent in the strict sense (re-running yields the same empty state).

##### Step 8 — Add single allow rule (22/tcp ONLY)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo ufw allow 22/tcp comment "sshd — operator access (T-0094 baseline)"'`
- Verification: output shows two "Rules updated" lines — one for IPv4 and one for IPv6 (because `IPV6=yes` in step 5). **Only one rule pair (two lines) — no 80/tcp, no 443/tcp.** The `comment` field annotates the rule for future audit clarity (shows in `ufw status verbose` output).
- **Why 22/tcp FIRST and ONLY:** T-0094 acceptance criteria: "UFW allow rule for `22/tcp` from **any source**". No 80/443 because pro-data-tech-qa has no nginx yet and no app server; those ports would be deny-by-default. No source restriction per user decision 2026-07-08.
- **Why BEFORE `ufw enable`:** UFW stores rules in its internal ruleset before `enable`, but the order-of-operations mental model is: if the enable itself fails, the rules are already committed to the ruleset; on next enable they take effect. Ordering 22/tcp first removes any ambiguity about which rule "wins" during a concurrent re-enable.
- Idempotent: re-running yields "Rules updated" again — UFW tracks rule identity, not just text.

##### Step 9 — Enable UFW

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo ufw enable'`
- Verification: output includes the literal line `Firewall is active and enabled on system startup`. UFW will warn about disrupting SSH — this warning is expected and informational; the 22/tcp allow rule from step 8 means SSH remains functional, so the warning is benign.
- **Note on `-y`/`--force`:** unlike `ufw --force reset`, `ufw enable` does **not** support `--force`. UFW instead emits an interactive `Command may disrupt existing ssh connections (y|n)` prompt. With single-quoted SSH args + PowerShell, this prompt would hang the SSH session. The workaround is to pre-answer `y` via stdin:
  - `ssh ... 'sudo ufw enable <<< "y"'` — using bash here-string to feed "y" into the prompt. **Use this form**, not bare `sudo ufw enable`.
  - **Alternative if the here-string doesn't work** (e.g., the prompt is from `whiptail`/`dialog` and not stdin): wrap in `echo y |` — `ssh ... 'echo y | sudo ufw enable'`. The executor should capture the actual prompt mechanism in P03 (e.g., `sudo ufw enable 2>&1 </dev/null | head -5` to see if the prompt is stdin-driven) and choose accordingly.
- Idempotent: re-enabling an already-active UFW is a no-op.

##### Step 10 — On-host verification (same SSH session) + cancel rollback timer

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo ufw status verbose; echo ---; sudo systemctl is-enabled ufw; echo ---; sudo atq; sudo atrm <job_id_from_step_4>; sudo atq; echo ---; sudo iptables -L -n -v | head -30; echo ---; sudo ip6tables -L -n -v | head -30'`
- Verification:
  - `Status: active`
  - `Default: deny (incoming), allow (outgoing), deny (routed)` — **note `deny (routed)`**, NOT `allow (routed)` like T-0083 (the explicit DROP divergence)
  - Allow rules table contains exactly: `22/tcp ALLOW IN Anywhere`, `22/tcp (v6) ALLOW IN Anywhere (v6)` — **two rows total** (not six like T-0083)
  - `systemctl is-enabled ufw` → `enabled`
  - `atq` returns an empty list after the `atrm` (timer cancelled)
  - `iptables -L -n -v` shows UFW chains loaded (`ufw-before-input`, `ufw-before-output`, `ufw-before-forward`, `ufw-after-input`, `ufw-after-output`, `ufw-after-forward`, `ufw-reject-input`, etc.)
  - `ip6tables -L -n -v` shows the same UFW chains loaded for IPv6 (because `IPV6=yes` in step 5)
- **Note on SSH-survival proof:** every `ssh …` command from step 8 onward is a fresh TCP connection to port 22 that must succeed. Steps 9, 10, 11, and 12 all open new connections post-enable and therefore constitute the SSH-survival proof. There is no persistent long-lived SSH session to drop.

##### Step 11 — Live SSH-from-workstation confirmation (V06)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'whoami; id; sudo -n true && echo SUDO_OK'`
- Verification: `whoami` → `tvolodi`; `id` shows the four groups (`tvolodi`, `sudo`, `users`, `sshusers`); `sudo -n true` returns `SUDO_OK`. This is the end-to-end operational confirmation that the entire user → sshd → UFW → NIC path is functional.
- **Why a separate step:** step 10's `ssh` is part of the post-enable verification, but step 11 is the explicit acceptance-criterion check (`V06 — Live SSH from workstation succeeds after UFW activation`).

##### Step 12 — External TCP probe from management workstation (off-host verification)

- Commands (PowerShell, from management workstation):
  ```powershell
  Test-NetConnection -ComputerName 95.46.211.230 -Port 22 -WarningAction SilentlyContinue
  Test-NetConnection -ComputerName 95.46.211.230 -Port 80 -WarningAction SilentlyContinue
  Test-NetConnection -ComputerName 95.46.211.230 -Port 443 -WarningAction SilentlyContinue
  ```
- Verification:
  - Port 22 → `TcpTestSucceeded: True` (SSH allowed, sshd listening).
  - Port 80 → `TcpTestSucceeded: False` with **immediate RST or connection refused** (no listener bound; UFW default-deny would also reject but the absence of a listener gives a faster answer).
  - Port 443 → `TcpTestSucceeded: False` with **immediate RST** (same reasoning).
- **Note:** `Test-NetConnection` to a non-listening port returns `TcpTestSucceeded: False` even when the firewall is correctly closed (the SYN gets a RST, not a timeout). The validator must interpret `22=True / 80=False / 443=False` as **expected and correct** — not as a UFW bug. To distinguish "UFW dropped" from "no listener", check the timing: UFW drops cause a timeout (10s wait); no-listener causes immediate RST.
- **Why off-host:** workflow rule #3 (verify in two places). The on-host `ufw status verbose` proves the ruleset is committed; the off-host TCP probe proves the ruleset actually filters packets from outside.

### Pre-flight probes the executor should fold in (from step-02 gap list)

The executor must run these as part of its step-06 handoff for the validator; the landscape-reader flagged them as live-discovery gaps. None of them block the design, but each is a no-cost confirmation:

- `ip -6 addr show | grep -E "inet6|scope"` — confirm IPv6 link state (informational; if no global-scope IPv6, `IPV6=yes` rules will be silently inert).
- `ls -la /etc/netplan/` — capture netplan config files (informational; cloud-init netplan coexists with UFW on Ubuntu).
- `ss -tlnp` / `ss -ulnp` — confirm listening ports match landscape (22 on 0.0.0.0; 127.0.0.53/54 on 127.0.0.1; nothing else).
- `systemctl is-enabled ufw.service` — confirm `ufw.service` enable state (cloud-init may have it masked, disabled, or static). If `masked`, the executor will need to `sudo systemctl unmask ufw.service` before step 9's `sudo ufw enable`.

These probes are run as part of the on-host verification (e.g., step 11 of the executor's run), not as separate steps in the design.

### Rollback

If the executor halts before step 10 (or step 11/12 fails), the rollback strategy depends on which step failed:

1. **If anything goes wrong between step 4 and step 9** (allow-rule-first chain broken, or UFW state is unexpected): do nothing manually — the `at` job in step 4 fires `sudo ufw disable` automatically within 5 minutes of step 4. Verify recovery with `ssh tvolodi@95.46.211.230 'sudo ufw status'`. After recovery: investigate, do not retry from step 1.
2. **If step 9 or step 10 leaves SSH unreachable:** do nothing manually — same `at` job. Wait up to 5 minutes and retry. If after 5 minutes SSH is still down (the `at` job did not fire or `atd` was not actually active — both diagnostic findings), escalate to the pro-data.tech control panel's VNC / web console (per landscape `pro-data-tech-qa.md` "Recovery path" notes — there is no Hetzner Cloud Console analogue; the equivalent is the provider's KVM-over-IP).
3. **If the user requests rollback after step 12 succeeds** (full success): execute steps R1–R4 below.

**Explicit rollback commands** (only if invoked manually after a successful run, e.g., the user changes their mind):

1. Disable UFW: `ssh tvolodi@95.46.211.230 'sudo ufw disable'`
2. Restore `/etc/default/ufw` to its original state: `ssh tvolodi@95.46.211.230 'sudo cp -a /etc/default/ufw.bak /etc/default/ufw'` — restores all four `DEFAULT_*_POLICY` lines and `IPV6=` to the pre-change values. (No sed needed; the .bak is a verbatim copy.)
3. Restore `/etc/ufw/` directory (if rules are corrupt): `ssh tvolodi@95.46.211.230 'sudo rm -rf /etc/ufw && sudo cp -a /tmp/ufw.pre-T0094.<UTC>.bak /etc/ufw && sudo ufw reload'` — wipes the modified `/etc/ufw/` and reinstates the step-1 snapshot, then reloads UFW rules from the restored files.
4. Verify: `ssh tvolodi@95.46.211.230 'sudo ufw status; echo ---; sudo grep -E "^(DEFAULT_|IPV6)=" /etc/default/ufw; echo ---; ls -la /etc/default/ufw.bak /tmp/ufw.pre-T0094.*.bak'` — expects `Status: inactive`, the original pre-change policies, both backup files intact.

Total manual rollback time: ~30 seconds.

### Verification (for step 07 — execution-validator)

#### V01 — `sudo ufw status verbose` shows correct defaults

- Expected: `Status: active` and `Default: deny (incoming), allow (outgoing), deny (routed)`. **Note: `deny (routed)`, not `allow (routed)`** (the explicit DROP divergence from T-0083).

#### V02 — `sudo ufw status numbered` shows the 22/tcp allow rule for v4 AND v6

- Expected: exactly two rules — `22/tcp ALLOW IN Anywhere` (v4) and `22/tcp (v6) ALLOW IN Anywhere (v6)`. No 80, 443, or other ports.

#### V03 — `/etc/default/ufw` shows the four expected settings

- Expected: `DEFAULT_INPUT_POLICY="DROP"`, `DEFAULT_OUTPUT_POLICY="ACCEPT"`, `DEFAULT_FORWARD_POLICY="DROP"`, `IPV6=yes`. (Confirmed by `grep -E "^(DEFAULT_|IPV6)=" /etc/default/ufw`.)

#### V04 — `sudo iptables -L -n -v | head -30` shows UFW chains loaded (v4)

- Expected: UFW-managed chains present (`ufw-before-input`, `ufw-before-output`, `ufw-before-forward`, `ufw-after-input`, `ufw-after-output`, `ufw-after-forward`, `ufw-reject-input`, etc.). INPUT and OUTPUT policies are now `DROP` and `ACCEPT` respectively (not the pre-run `ACCEPT`/`ACCEPT`).

#### V05 — `sudo ip6tables -L -n -v | head -30` shows UFW chains loaded (v6)

- Expected: same UFW chains for IPv6 (because `IPV6=yes`). Confirms IPv6 rules are actively applied, not silently inert.

#### V06 — Live SSH from workstation succeeds after UFW activation

- Expected: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'whoami; id; sudo -n true && echo SUDO_OK'` returns `tvolodi`, the four groups, and `SUDO_OK`. This is the end-to-end lockout prevention check.

#### V07 — `systemctl is-enabled ufw` returns `enabled`

- Expected: literal output `enabled`. If `disabled`, `static`, or `masked`, the executor must investigate (cloud-init's `90-disable-password.conf`-style drop-ins don't apply here; this would be a different systemd state).

#### V08 — External port scan confirms only port 22 open

- Command (optional; if `nmap` is installed on the workstation): `nmap -Pn -p 1-1024 95.46.211.230`
- Expected: `22/tcp open ssh` and all other ports 1–1024 are `closed` or `filtered`. (If no listener is bound on a port, `nmap` reports `closed` if the host responds with RST; if UFW drops, `nmap` reports `filtered`.)
- **If nmap is not installed on the workstation:** the step-12 `Test-NetConnection` probe (22=True, 80=False, 443=False) is the V08 substitute. The validator records which form was used.

#### Additional verification (from the landscape-reader's gap list)

- `ip -6 addr show` output captured (informational; UFW is functional regardless of link state, but the validator wants to know whether the IPv6 chain in V05 is hitting a real link).
- `sudo ls -la /etc/default/ufw.bak /tmp/ufw.pre-T0094.*.bak` — both backup files intact with expected ownership and mode.
- `sudo atq` — returns empty list (rollback timer cancelled in step 10).
- `sudo diff /etc/default/ufw /etc/default/ufw.bak` — shows exactly the four policy-line differences (no other drift).

### Resources used

- **Secrets (by name):** none. No secret values are added, rotated, or referenced. The SSH key `ssh-key:ai-dala-infra-mgmt` (at `C:\Users\tvolo\.ssh\ai-dala-infra`, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`) is the existing project key already deployed to `pro-data-tech-qa` for user `tvolodi` per T-0097; this run uses it as-is. The provider key (`rsa-key-20260707`) at `/root/.ssh/authorized_keys` is the break-glass anchor for root, used only in disaster recovery (rollback via pro-data.tech VNC).
- **Files modified on host (`pro-data-tech-qa`, 95.46.211.230):**
  - `/etc/default/ufw` — `DEFAULT_INPUT_POLICY` set to `DROP`, `DEFAULT_OUTPUT_POLICY` set to `ACCEPT`, `DEFAULT_FORWARD_POLICY` set to `DROP` (explicit divergence from T-0083), `IPV6=yes`.
  - `/etc/ufw/user.rules`, `/etc/ufw/before.rules`, `/etc/ufw/after.rules`, `/etc/ufw/user6.rules`, `/etc/ufw/before6.rules`, `/etc/ufw/after6.rules` — UFW's auto-backup timestamped copies created by `ufw --force reset` (e.g., `.20260708_HHMMSS` suffix); the active copies are rewritten by UFW.
  - systemd state change: `ufw.service` flips from `enabled but inactive` (cloud-init default) to `enabled and active`.
- **Files created on host:**
  - `/etc/default/ufw.bak` — pre-change backup of the single config file, mode 0644, owner root:root (per T-0094 acceptance criterion).
  - `/tmp/ufw.pre-T0094.<UTC>.bak/` — full `/etc/ufw/` directory backup, mode preserved, owner root:root (per T-0094 user-prompt backup path; primary rollback artifact for the ruleset).
- **Files modified in this repo (landscape/) — to be applied at step 08:**
  - [landscape/hosts/pro-data-tech-qa.md](landscape/hosts/pro-data-tech-qa.md) — "Network" section: rewrite "Host firewall (UFW)" line to reflect active state; add UFW ruleset subsection (deny-incoming, allow-outgoing, FORWARD=DROP, IPV6=yes, allow 22/tcp v4+v6); mark "What needs to happen" item #4 done. **Explicitly call out the DEFAULT_FORWARD_POLICY=DROP divergence** so the future T-0090 (Docker install) executor knows it must reconcile UFW FORWARD policy when adding Docker.
  - [landscape/services.md](landscape/services.md) — append change-log row in the format established by `hetzner-prod.md` (date, run_id, change description including "DEFAULT_FORWARD_POLICY=DROP — T-0090 will need to reconcile when adding Docker" note).
  - Bump frontmatter `last_verified` to today (2026-07-08) on both files.
- **External APIs called:** none. (pro-data.tech has no Hetzner Cloud Firewall analogue; this run is host-local only.)

### Estimated impact

- **Downtime:** none for services (no services bound to 80/443 or any other port today). Brief SSH connection drops on the management workstation's *open* SSH session when `ufw enable` is invoked (steps 9 / 10 each open a fresh session — there is no persistent long-lived SSH session to drop). Maximum observed: the few-hundred-ms gap between `ssh` invocations. No user-visible downtime.
- **Affected services:** sshd (port 22, management) — preserved by the explicit `22/tcp` allow rule. No other services affected.
- **Reversibility:** **fully reversible.** `ufw disable` restores pre-run state. `/etc/default/ufw.bak` reinstates the original four policy lines. `/tmp/ufw.pre-T0094.<UTC>.bak/` reinstates the original ruleset files. Total rollback time: ~30 seconds.
- **Blast radius (re-stated):** task rates `medium` because pro-data.tech has **no outer cloud firewall** (unlike `ubuntu-16gb-nbg1-1` where Hetzner Cloud Firewall sits in front of UFW). UFW here is the only packet filter — a misconfiguration would be the only line of defense. Mitigated by (a) the SSH allow rule being committed before `ufw enable` (step 8 before step 9 ordering), (b) the `at`-based rollback timer armed before any change (step 4), and (c) every post-enable `ssh` invocation being a fresh TCP connection that must succeed (steps 10, 11, 12). The validator (step 07) verifies SSH twice — once during execution (executor captures it in V06) and once independently during validation.

## Issues / risks

- **SSH lockout risk (primary; mitigated; non-blocking for design):** the entire plan is structured around this risk. Mitigations: allow-rule-before-enable (step 8 before step 9), `at`-based rollback timer (step 4), every post-enable `ssh` invocation is itself a proof (steps 10, 11, 12), `nohup`-based fallback if `atd` is unavailable (step 4 fallback), T-0093 sshd hardening (key-only auth + AllowGroups sshusers means a lockout is recoverable from any of the three operator accounts), T-0097 operator users (three independent operator workstations with key-only access and NOPASSWD sudo). Residual risk: a race window between `ufw enable` and the first successful post-enable SSH — bounded by the at-job's 5-minute window plus the nohup fallback's 5-minute sleep. If the race fails AND the at-job fails AND the nohup fallback fails, recovery is via the pro-data.tech provider's KVM-over-IP / VNC console (equivalent to the Hetzner web console, but provided by pro-data.tech).

- **`ufw enable` interactive prompt (NEW risk for this plan):** unlike `ufw --force reset` (which accepts `--force`), `sudo ufw enable` does NOT accept `--force` and emits an interactive `Command may disrupt existing ssh connections (y|n)` prompt. With single-quoted SSH args + PowerShell, this prompt would hang the SSH session. The plan addresses this in step 9 with the `<<< "y"` bash here-string form. **Risk acknowledged:** if the prompt is from `whiptail`/`dialog` (not stdin-driven), the here-string approach fails and the executor must fall back to `echo y | sudo ufw enable` or `printf 'y\n' | sudo ufw enable`. The executor must capture the actual prompt mechanism in its step-06 handoff so the validator can verify the correct form was used.

- **`DEFAULT_FORWARD_POLICY="DROP"` divergence from sibling pattern (DESIGN choice; documented):** the user explicitly chose DROP for this host, which differs from `hetzner-prod` (ACCEPT, Docker installed) and `ubuntu-16gb-nbg1-1` (ACCEPT, Docker pending). DROP is correct for the "no Docker yet, deny-by-default strictest" state. When T-0090 lands Docker on this host, the executor will need to either (a) flip the FORWARD policy back to ACCEPT via the same `sed` form as step 5 (reverse), or (b) configure Docker's `daemon.json` with `"iptables": false` and route everything through UFW rules explicitly. The landscape-updater (step 08) will add a "Network" note calling this out so the future T-0090 executor doesn't have to rediscover it.

- **`atd` availability gap (inherited from T-0083):** step-02 flagged that `atd.service` is in the cloud-image base systemd unit table but was not confirmed by the discovery run. Step 4 verifies this on first SSH (`sudo systemctl is-active atd`). If `atd` is not active, the executor must substitute the `nohup`-based fallback. The fallback has a known limitation vs `at`: a `kill <pid>` cancellation in step 10 requires recording the exact PID from step 4, and any orphan `nohup` process that survives a `kill` (unlikely but possible) would still try to `ufw disable` after 5 minutes. Acceptable risk; documented for the executor.

- **PowerShell + SSH quoting (already addressed):** every `ssh` command in this plan wraps the entire remote argument in **single quotes** (`'sudo …'`). PowerShell's variable interpolation and quote-stripping rules do not affect single-quoted strings (no expansion; literal pass-through to SSH). Double quotes inside the remote command (e.g., `"DROP"` in the sed) are part of the remote command's own quoting and are preserved because the OUTER PowerShell quote is single. This is the proven pattern from T-0002 / T-0083. The validator should reject any handoff where the executor used double quotes around the remote command.

- **Ubuntu 26.04 UFW package drift (already addressed):** step 6's `diff` against the backup catches any non-policy-line changes introduced by a newer UFW package version. If the diff shows more than the four expected policy lines differing, the executor halts and reports (does not proceed to step 7). The plan is intentionally defensive here because T-0083 ran on the same Ubuntu 26.04 (kernel 7.0.0-22-generic; this host is 7.0.0-14-generic — slightly older minor) and `/etc/default/ufw` defaults could differ.

- **Pre-existing duplicate SSH key in `tvolodi`'s `authorized_keys`:** landscape does not note a duplicate for this host (unlike `ubuntu-16gb-nbg1-1`). The validator must not invent a duplicate-check step; if the executor's step-11 V06 `id` shows the expected four groups, the SSH path is working regardless of `authorized_keys` content.

- **`fail2ban` not yet installed (RESIDUAL defense-in-depth gap; accepted by user):** the user's defense-in-depth model is UFW + AllowGroups sshusers + fail2ban. T-0095 (fail2ban) is queued but NOT installed at run time. This means the 22/tcp allow rule is exposed to brute-force scanning without brute-force mitigation. The user explicitly accepted this state ("`ufw allow 22/tcp` from any source — defense-in-depth comes from (a) UFW only opening 22/tcp, (b) AllowGroups sshusers from T-0093, (c) fail2ban from T-0095"). The residual risk is brute-force SSH key probing, which is largely mitigated by key-only auth (no passwords to guess) and the small number of operators (only 4 keys accepted). The T-0095 follow-on will close the remaining gap.

- **No source restrictions on 22/tcp (DESIGN choice; documented):** differs from `ubuntu-16gb-nbg1-1` where Hetzner Cloud Firewall restricts inbound at the cloud layer. pro-data.tech has no comparable outer filter. The decision is explicit per user 2026-07-08; the landscape file documents the rationale in the "Open questions" section (now resolved). This is intentional, not an oversight.

## Open questions

None for step 04. The `DEFAULT_FORWARD_POLICY` decision is documented above (DROP chosen per user prompt — explicit divergence from T-0083); the user may override at step 05 if they prefer ACCEPT for Docker parity, in which case only step 5's sed changes. The on-host UFW package-version diff (step 6) and the `atd` availability check (step 4) are both executor-discoverable and bounded — neither blocks design.