---
run_id: 2026-06-27-install-fail2ban-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-06-27T00:00:00Z
task_id: T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-install-fail2ban-001/step-01-task-reader.md
  - runs/2026-06-27-install-fail2ban-001/step-02-landscape-reader.md
  - runs/2026-06-27-install-fail2ban-001/step-03-task-validator.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/hosts/hetzner-prod.md
  - landscape/secrets-inventory.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md
  - tasks/T-0005-install-fail2ban.md
  - runs/2026-05-12-install-fail2ban-001/step-04-solution-designer.md
  - runs/2026-05-12-install-fail2ban-001/step-06-executor-infra.md
  - runs/2026-06-27-configure-ufw-001/step-04-solution-designer.md
  - runs/2026-06-27-configure-ufw-001/step-06-executor-infra.md
artifacts_changed: []
next_step_hint: orchestrator — write step-05-user-approval.md (REQUIRED; package install on managed host always requires user sign-off per shared/approval-protocol.md "Always NEEDS_APPROVAL" list)
---

## Summary

Install `fail2ban` via apt on `ubuntu-16gb-nbg1-1` (46.225.239.60), write `/etc/fail2ban/jail.d/sshd.local` to enable the `sshd` jail with maxretry=3 / bantime=600s / findtime=600s and the **live-verified** management workstation outbound IP in `ignoreip` (per the explicit task instruction: NEVER hardcode prod's `5.250.151.158`), pick `banaction` from a live iptables-backend probe (default `iptables-multiport`, fallback `nftables-multiport`), enable and start the service, then verify on-host and via a fresh SSH from the management workstation. Mirrors the proven T-0005 design exactly, with the Ubuntu 26.04 caveats called out and the SSH command form `ssh ubuntu-16gb-nbg1-1 '...'` (single-quoted remote command) per the T-0083 UFW run on the same host.

**Verdict: `NEEDS_APPROVAL`.** Per `shared/approval-protocol.md` "Always `NEEDS_APPROVAL`" list — *"Package installs or OS-level changes"* — this verdict is required even though the task is `low` blast radius and `full` reversibility. The user must see and confirm the plan before the executor touches the host.

## Details

### SSH execution convention (binding for all on-host steps)

Every on-host step in this plan uses the form proven in the T-0083 UFW run on this same host today:

```powershell
ssh ubuntu-16gb-nbg1-1 'sudo <command>'
```

- The remote command is wrapped in **single quotes** (no PowerShell variable expansion; literal pass-through to SSH). Inner double quotes inside the remote command (e.g., in heredoc bodies) are part of the remote command's own quoting and survive the SSH hop.
- `ubuntu-16gb-nbg1-1` is the SSH config alias defined in `C:\Users\tvolo\.ssh\config` (per `landscape/hosts/ubuntu-16gb-nbg1-1.md` §"Access"). Resolves to `tvolodi@46.225.239.60`, port 22, identity `~/.ssh/ai-dala-infra`, `IdentitiesOnly yes`.
- `tvolodi` has passwordless sudo via `/etc/sudoers.d/90-tvolodi` (mode 0440, owner root:root, content `tvolodi ALL=(ALL) NOPASSWD:ALL`). Confirmed working 2026-06-27 by the T-0082 discovery run.
- For multi-line remote commands (e.g., the heredoc in step 6), use a `sudo tee /etc/fail2ban/jail.d/sshd.local <<'EOF' ... EOF` form piped in via PowerShell — the heredoc body is a single-quoted local string in PowerShell, and the `<<'EOF'` (with single-quoted delimiter) on the remote side prevents any further shell expansion.

### Plan

#### Step 0 — Pre-flight: confirm management workstation outbound IP (from workstation, BEFORE SSH)

- Command (run locally on management workstation, **PowerShell**):
  ```powershell
  (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
  ```
  (Equivalent: `curl -s https://ifconfig.me` if the workstation is on a Unix-like shell. The task itself names `curl https://ifconfig.me`; the executor may use whichever form is convenient, as long as the output is a single IPv4.)
- **Why this is Step 0, before SSH:** the task (`tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md`, Notes section) and the landscape-reader (step 02, "Gaps requiring live discovery" #3) both explicitly forbid hardcoding prod's `5.250.151.158`. We must know the workstation's current outbound IP before writing the jail file. The IP is substituted into the `ignoreip` line in step 6 below.
- Verification: output is a single dotted-quad IPv4 (e.g., `5.250.151.158` or whatever the workstation currently egresses as). The executor records the exact string in its handoff and uses it verbatim in step 6.
- **If the executor cannot determine the IP** (offline workstation, DNS issue, `ifconfig.me` unreachable, etc.): HALT with `BLOCKED` rather than guessing. Do NOT use `5.250.151.158` as a fallback.

#### Step 1 — SSH into the host (implicit, established by all subsequent commands)

- All steps below are `ssh ubuntu-16gb-nbg1-1 'sudo <command>'`. SSH reachability is implicitly proven by step 0's command chain.
- Verification: each step that follows must complete with exit code 0; any non-zero exit is a hard stop.

#### Step 2 — Confirm fail2ban is not already installed

- Command: `ssh ubuntu-16gb-nbg1-1 'dpkg -l fail2ban 2>/dev/null | grep -E "^ii" || echo NOT_INSTALLED'`
- Verification: output is `NOT_INSTALLED` (or `dpkg` exits 1/returns no match). If `ii  fail2ban` appears, abort with `BLOCKED` — the task is already done, or a previous run completed; surface the finding to the user.
- Why: idempotency + no-op avoidance. Same as T-0005's step 2.

#### Step 3 — Probe the iptables backend (drives banaction choice)

- Command: `ssh ubuntu-16gb-nbg1-1 'iptables -V; echo ===; update-alternatives --list iptables 2>/dev/null || echo "(no alternatives configured)"'`
- Verification: record the iptables backend string. Expected branches:
  - **nf_tables / iptables-nft shim** (Ubuntu 22.04+ default; the most likely outcome on a fresh Ubuntu 26.04 image) → use `banaction = iptables-multiport` in step 6. Same as T-0005's chosen action.
  - **legacy** (unusual on 26.04; would mean `update-alternatives --list iptables` shows `/usr/sbin/iptables-legacy` as the active alternative) → use `banaction = nftables-multiport` in step 6.
  - **No alternatives at all / unknown backend** → halt with `BLOCKED` and surface the probe output to the user; do not guess.
- Why: the task Notes section explicitly require the executor to determine the backend before writing the jail config. fail2ban's `iptables-multiport` action invokes `iptables` (which routes through whatever backend the system has configured via `update-alternatives`); `nftables-multiport` invokes `nft` directly. Mis-picking the action causes the jail to fail to load with an action-related error in `journalctl` (the same failure mode T-0005's "sub-step 7a" fallback was designed to recover from).
- **Sub-step 7a (banaction fallback) is preserved in the plan** — if step 7's `fail2ban-client status sshd` returns an action error, the executor executes the sed swap (see Rollback → Sub-step 7a) and retries step 7.

#### Step 4 — `apt-get update`

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo apt-get update -qq'`
- Verification: exit code 0; no "Failed to fetch" or "Repository does not have a Release file" lines. (Quiet mode `-qq` suppresses the per-repo OK lines; non-zero exit and any unfiltered `W:`/`E:` lines are the signals.)
- Why: ensures the package index is current. Same as T-0005's step 3 / T-0083's step 1.

#### Step 5 — `apt-get install fail2ban`

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban'`
- Verification: exit code 0; `dpkg -l fail2ban 2>/dev/null | grep ^ii` shows `ii  fail2ban  <version>`. T-0005 on Ubuntu 24.04 produced `1.0.2-3ubuntu0.1` from the `noble-updates/universe` pocket; the executor records whatever version apt picks for `resolute` (Ubuntu 26.04 codename) for step 08's landscape change-log entry.
- Expected new packages (Ubuntu 24.04 dependency set; 26.04 should be similar): `fail2ban`, `python3-pyasyncore`, `python3-pyinotify`, `whois`.
- **If apt-get reports "Unable to locate package fail2ban"** (i.e., the `universe` repo is not enabled, or `fail2ban` was dropped from 26.04): halt with `BLOCKED` and surface the apt output to the user. Step 02 flagged this as a possibility; the verdict is `BLOCKED` until the user resolves the package-source question.
- Note: T-0005 noted benign `SyntaxWarning: invalid escape sequence` lines from fail2ban's test files during package setup. If they reappear on 26.04 they are upstream packaging noise, not runtime errors. Do not treat as failure.

#### Step 6 — Write `/etc/fail2ban/jail.d/sshd.local`

- Command (PowerShell, from management workstation):
  ```powershell
  $mgmtIp = '<value-from-step-0>'   # e.g. '5.250.151.158' or whatever step 0 returned
  $banaction = '<iptables-multiport | nftables-multiport>'   # from step 3
  $sshdLocal = @"
  [sshd]
  enabled  = true
  port     = ssh
  filter   = sshd
  maxretry = 3
  bantime  = 600
  findtime = 600
  ignoreip = 127.0.0.1/8 ::1 $mgmtIp
  banaction = $banaction
  "@
  ssh ubuntu-16gb-nbg1-1 "sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<'EOF'
  $sshdLocal
  EOF"
  ssh ubuntu-16gb-nbg1-1 'sudo cat /etc/fail2ban/jail.d/sshd.local'
  ```
- Verification: the final `cat` output reproduces the file contents exactly. `ignoreip` line must contain `127.0.0.1/8 ::1 <step-0-IP>`. `banaction` line must be exactly what step 3 determined.
- Why: this is the jail override. fail2ban best practice is to put jail customizations in `jail.d/*.local`, never to edit `jail.conf` directly. Same approach as T-0005. The Ubuntu-default `/etc/fail2ban/filter.d/sshd.conf` is reused as-is (no copy needed).
- **Backup before destructive change (workflow rule #2):** none required — `/etc/fail2ban/jail.d/sshd.local` does not exist on this host (this is a fresh install, no prior jail config to overwrite). The executor should still run `ls -la /etc/fail2ban/jail.d/` immediately before the `tee` to prove the file's pre-existence is "nothing" — if any `sshd.local` already exists, halt with `BLOCKED` and report (unexpected state; not a destruction risk, but a sanity check).

#### Step 7 — Enable and start the fail2ban service

- Command: `ssh ubuntu-16gb-nbg1-1 'sudo systemctl enable fail2ban && sudo systemctl restart fail2ban'`
- Verification: exit code 0; the second command's output is the standard "DONE" line from systemd's sysv-install compatibility shim. (T-0005 step 7 captured this exact output.)
- Why: `enable` creates the systemd boot-time symlink; `restart` (not `start`) handles both first-install and config-change cases cleanly. `apt install fail2ban` on Ubuntu typically auto-starts the service once at install time, but `restart` after the jail file is written is the explicit, idempotent way to apply the new config.

#### Step 8 — On-host verification (service active + jail loaded)

- Commands (two checks in one `ssh`):
  ```powershell
  ssh ubuntu-16gb-nbg1-1 'sudo systemctl is-active fail2ban; echo ===; sudo systemctl is-enabled fail2ban; echo ===; sudo fail2ban-client status sshd; echo ===; sudo fail2ban-client get sshd ignoreip'
  ```
- Verification:
  - `sudo systemctl is-active fail2ban` → `active` (exit 0).
  - `sudo systemctl is-enabled fail2ban` → `enabled`.
  - `sudo fail2ban-client status sshd` → output contains `Status for the jail: sshd`, `Currently failed:`, `Total failed:`, `Currently banned:`, `Total banned:`, `Banned IP list:`. (T-0005's run on prod picked up 4 already-banned IPs at T+0 from journal history import — same expected behavior on this internet-facing port 22.)
  - `sudo fail2ban-client get sshd ignoreip` → output is a space-separated list that **includes the step-0 IP**. This is the canonical proof that the management workstation IP made it into the running config.
  - Optional extra check (per T-0005's pattern and step 03's "coexistence sanity check" recommendation): `sudo iptables -L -n 2>/dev/null | grep -E "f2b-sshd|f2b-sshd-ddos" || sudo nft list ruleset 2>/dev/null | grep -E "f2b-sshd|set\s+f2b"` — confirms fail2ban's ban chain is present alongside UFW's INPUT rules. If neither form returns any output, fail2ban's ban chain did not get installed and the run should fail (fail2ban is silently no-op'ing).

#### Step 9 — External verification: SSH from the management workstation succeeds post-install

- Command (PowerShell, from management workstation):
  ```powershell
  ssh -o ConnectTimeout=5 -o BatchMode=yes ubuntu-16gb-nbg1-1 'echo ok'
  ```
- Verification: output is `ok` (exit 0). **This is the proof that the management workstation IP is not banned** — a fail2ban ban would manifest as a connection timeout or `Connection closed by remote` error within seconds, not as a successful `echo ok`. This is the "verify in two places" requirement (workflow rule #3): step 8 verifies on-host, step 9 verifies externally.
- Why this matters specifically: if step 6's `ignoreip` line is wrong (tyo, wrong IP recorded, the wrong file edited), fail2ban could ban the workstation itself if any auth attempts fail during the run (none should, but a misconfig + a transient key issue would suffice). The BatchMode SSH forces a no-auth attempt (no password prompt, no interactive key prompt) so the only failure mode is connection-level — i.e., a ban or a network problem.
- **If step 9 fails:** HALT with `BLOCKED`. The workstation may have been banned. Recovery: Hetzner web console rescue mode (out of band; no SSH needed) to either remove the `jail.d/sshd.local` file or add the workstation IP to the `ignoreip` line. This is a worst-case scenario; the design's pre-flight (step 0) and verification (step 8's `get sshd ignoreip`) are designed to prevent it.

### Rollback

If any step from 5 onward fails and the host needs to be restored to pre-run state:

1. **Stop and disable the service.**
   - `ssh ubuntu-16gb-nbg1-1 'sudo systemctl stop fail2ban; sudo systemctl disable fail2ban'`
2. **Remove the jail config file.**
   - `ssh ubuntu-16gb-nbg1-1 'sudo rm -f /etc/fail2ban/jail.d/sshd.local'`
3. **Remove the package (retains no residual config files).**
   - `ssh ubuntu-16gb-nbg1-1 'sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y fail2ban'`
4. **(Optional) Purge the package and its config dirs.**
   - `ssh ubuntu-16gb-nbg1-1 'sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y fail2ban'`
5. **Confirm removal.**
   - `ssh ubuntu-16gb-nbg1-1 'dpkg -l fail2ban 2>/dev/null | grep ^ii || echo REMOVED_CONFIRMED'`
   - Expected: `REMOVED_CONFIRMED` (or dpkg status `rc` / `un` if purge was used).

**Sub-step 7a (banaction fallback, not a full rollback):**
If step 7's `systemctl restart fail2ban` succeeds and the service is `active`, but step 8's `fail2ban-client status sshd` returns an action error (e.g., "Failed to access socket path", "iptables error", "nft error") indicating the chosen banaction does not match the actual backend:

- `ssh ubuntu-16gb-nbg1-1 'sudo sed -i "s/^banaction = iptables-multiport$/banaction = nftables-multiport/" /etc/fail2ban/jail.d/sshd.local; sudo systemctl restart fail2ban; sudo fail2ban-client status sshd'`
- (Or the reverse sed `s/^banaction = nftables-multiport$/banaction = iptables-multiport/` if the original choice was `nftables-multiport` and the failure mode is the opposite.)
- Re-verify per step 8. If the jail still fails to load after one banaction swap, halt with `BLOCKED` and surface the `journalctl -u fail2ban --since "5 minutes ago"` output to the user.

### Verification (for step 07 — execution-validator)

**On-host checks (executor must capture and include in its handoff):**

- `dpkg -l fail2ban 2>/dev/null | grep ^ii` — must show `ii  fail2ban  <version>` (installed, clean).
- `cat /etc/fail2ban/jail.d/sshd.local` — file must exist, must contain `enabled = true`, `maxretry = 3`, `bantime = 600`, `findtime = 600`, and an `ignoreip` line containing the **step-0 IP verbatim** (not `5.250.151.158` unless that is what step 0 returned). `banaction` line must match what step 3 determined.
- `systemctl is-active fail2ban` — must return `active` (exit 0).
- `systemctl is-enabled fail2ban` — must return `enabled`.
- `fail2ban-client status sshd` — must return jail status block with `Status for the jail: sshd`, `Currently failed:`, `Total failed:`, `Currently banned:`, `Total banned:`, `Banned IP list:` fields all present and non-error.
- `fail2ban-client get sshd ignoreip` — output must include the step-0 IP (and `127.0.0.1/8`, `::1`).
- `iptables -L -n 2>/dev/null | grep -E "f2b-sshd|f2b-sshd-ddos" || nft list ruleset 2>/dev/null | grep -E "f2b-sshd|set\s+f2b"` — must return at least one line. **If empty, fail2ban's ban chain is missing and the run must be marked failed.**
- `journalctl -u fail2ban --since "10 minutes ago" | grep -iE "error|fatal" | grep -v SyntaxWarning` — must be empty (or only contain benign warnings). `SyntaxWarning` lines are known noise from fail2ban's test files; ignore them.

**External checks (from management workstation):**

- `ssh -o ConnectTimeout=5 -o BatchMode=yes ubuntu-16gb-nbg1-1 'echo ok'` — must return `ok` with exit 0. This is the canonical "not self-banned" proof.
- Optional additional proof: `Test-NetConnection -ComputerName 46.225.239.60 -Port 22 -WarningAction SilentlyContinue` — must return `TcpTestSucceeded: True`. (UFW was already configured in T-0083, so this should already pass; the fail2ban install should not have affected UFW or sshd.)

**Defense-in-depth checks (validator must verify the run was properly approved and references are correct):**

- `runs/2026-06-27-install-fail2ban-001/step-05-user-approval.md` exists with `verdict: APPROVED` and `inputs_read` includes `runs/2026-06-27-install-fail2ban-001/step-04-solution-designer.md` (per `shared/approval-protocol.md` §"Executor verification" #2).
- Step-06 handoff's `inputs_read` includes both this file (step-04) and the approval file.
- Step-06 handoff's execution log shows steps 0–9 completed in order, with the step-0 IP recorded explicitly.

### Resources used

- **Secrets (by name):** none. The SSH key `ssh-key:ai-dala-infra-mgmt` (at `C:\Users\tvolo\.ssh\ai-dala-infra`, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`) is the existing project key already deployed to `tvolodi@ubuntu-16gb-nbg1-1`. No new keys, no rotations, no value references.
- **Files modified on host (`ubuntu-16gb-nbg1-1`, 46.225.239.60):**
  - `/etc/fail2ban/jail.d/sshd.local` — created (no pre-existing file to back up).
  - `/etc/fail2ban/` and `/usr/share/doc/fail2ban/` package directories — created by apt.
  - `/etc/systemd/system/multi-user.target.wants/fail2ban.service` symlink — created by `systemctl enable`.
  - systemd state: `fail2ban.service` goes from "not present" to "active + enabled".
- **Files modified in this repo (landscape/) — to be applied at step 08 by landscape-updater:**
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` — append fail2ban clause to "SSH hardening tooling on host" sentence; add a change-log row in the format established by the T-0005 row in `landscape/hosts/hetzner-prod.md` (date, run_id, change description, package version, jail parameters, management IP from `ignoreip`, banaction, config path).
  - `landscape/services.md` — add a `fail2ban.service` row to the systemd-units table under the `## ubuntu-16gb-nbg1-1` section; append a change-log row in the same format as the T-0083 UFW row (2026-06-27-…).
- **External APIs called:** none.

### Estimated impact

- **Downtime:** none. fail2ban operates as an independent daemon; it does not interrupt sshd, UFW, or any other service. The only side effect is that future SSH connections that exceed `maxretry=3` failed attempts within `findtime=600s` get banned for `bantime=600s`.
- **Affected services:** sshd (indirectly protected, not interrupted). UFW and all other services are unaffected.
- **Reversibility:** fully reversible. `apt-get remove fail2ban` + `rm /etc/fail2ban/jail.d/sshd.local` + `systemctl stop fail2ban` + `systemctl disable fail2ban` restores the host to its pre-run state. Total rollback time: ~30 seconds.
- **Blast radius (re-stated):** task rates `low`; landscape-reader (step 02) and task-validator (step 03) both concur. I concur.
- **Bounded blast radius check:** the only non-target scope this plan touches is the apt dependency set (`python3-pyasyncore`, `python3-pyinotify`, `whois`) — all standard Ubuntu `universe` packages; no risk of cross-host impact (this is purely a single-host apt install). No DNS, no firewall rules, no secrets, no other managed services affected.

## Issues / risks

- **Ubuntu 26.04 iptables-backend drift (medium, executor-owned):** T-0005 ran on Ubuntu 24.04 with `iptables v1.8.10 (nf_tables)`. Ubuntu 26.04 may ship a different default (newer nf_tables version, or a different `update-alternatives` layout). Step 3 explicitly probes the backend, and step 6 parameterizes the `banaction` based on the result. Sub-step 7a documents the swap path if the first choice is wrong. Risk is fully solvable in executor runbook; not a design blocker.

- **Hardcoded prod workstation IP risk (low, explicitly mitigated by Step 0):** T-0084's Notes section explicitly forbids copying `5.250.151.158` blindly. Step 0 runs `Invoke-WebRequest https://api.ipify.org` (or `curl https://ifconfig.me`) on the management workstation BEFORE the executor writes `ignoreip`, and the recorded IP is substituted into the heredoc in step 6. The execution-validator (step 07) is required to verify the `ignoreip` line in the installed file contains the step-0 IP verbatim, not a different value. If the workstation's outbound IP has silently changed since the last run, the design adapts automatically. If step 0 fails to obtain an IP, the executor halts with `BLOCKED` rather than guessing.

- **`PasswordAuthentication yes` is still enabled on this host (informational, not blocking):** The landscape confirms `PasswordAuthentication yes` (cloud-init default; `50-cloud-init.conf`). This is NOT a fail2ban-installation concern — it is the exact motivation for T-0084. Disabling password auth on this host is a natural follow-on task (parallels T-0007 on prod) but is out of scope for T-0084. The `landscape/hosts/ubuntu-16gb-nbg1-1.md` "What needs to happen" item #4 already tracks this. No action required for this run.

- **UFW + fail2ban coexistence (low, verified in plan):** Step 8 explicitly checks for fail2ban's ban chain in `iptables -L -n` (or `nft list ruleset`). On T-0005, fail2ban inserted its `f2b-sshd` chain above UFW's INPUT rules by fail2ban convention and the two layers coexisted cleanly. The validator (step 07) is required to confirm the chain is present. If absent, fail2ban is silently no-op'ing and the run must be marked failed (sub-step 7a may be relevant if the banaction is wrong).

- **Unattended-upgrades will auto-upgrade fail2ban on the security channel (low, acceptable):** This is intentional for a security tool. The host's `apt posture` section in the landscape confirms `unattended-upgrades` is active and the security channel is included. Any future security patches to `fail2ban` will be auto-applied within the standard unattended-upgrade window.

- **`landscape/secrets-inventory.md` and `landscape/hosts/hetzner-prod.md` are 32 days old (informational, not blocking):** Pre-existing drift, flagged for a future landscape-updater audit. No impact on this run; the SSH key fingerprint in `secrets-inventory.md` is corroborated by the target host's landscape file.

## Open questions

None for step 04. All three live-discovery gaps identified by the landscape-reader (apt availability, iptables backend, management workstation IP) are addressed in the plan: the first is solved by `apt-get install` (which either succeeds or surfaces the error), the second by step 3's probe, and the third by step 0's pre-flight. The user can approve, reject, or request modifications at step 05.
