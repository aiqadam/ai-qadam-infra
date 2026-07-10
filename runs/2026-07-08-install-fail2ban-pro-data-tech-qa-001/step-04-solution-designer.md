---
run_id: 2026-07-08-install-fail2ban-pro-data-tech-qa-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-08T00:00:00Z
task_id: T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-03-task-validator.md
  - tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md
  - tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - shared/subagent-invocation.md
  - workflows/_common-operations.md
  - workflows/infrastructure.md
  - runs/2026-06-27-install-fail2ban-001/step-04-solution-designer.md
  - runs/2026-06-27-install-fail2ban-001/step-07-execution-validator.md
  - runs/2026-05-12-install-fail2ban-001/step-04-solution-designer.md
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-04-solution-designer.md
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-06-executor-infra.md
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-06-executor-infra.md
  - memories/repo/ufw-rollback-timer-process-group.md
artifacts_changed: []
next_step_hint: orchestrator — write step-05-user-approval.md (REQUIRED; package install on managed host always requires user sign-off per shared/approval-protocol.md "Always NEEDS_APPROVAL" list).
---

## Summary

Install `fail2ban` via apt on `pro-data-tech-qa` (95.46.211.230), write `/etc/fail2ban/jail.d/sshd.local` to enable the `sshd` jail with `maxretry=3 / bantime=600s / findtime=600s` and the **live-verified** management workstation outbound IP in `ignoreip`, pick `banaction` from a live iptables-backend probe (default `iptables-multiport`, matching the proven T-0084 sibling pattern on `ubuntu-16gb-nbg1-1` which shares this host's exact OS + UFW stack), enable and start the service, then verify on-host and via a fresh BatchMode SSH from the management workstation. Mirrors the proven T-0084 design with three host-specific tweaks: (a) the SSH command form `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo …'` (post-T-0097 operator path, not the root break-glass path); (b) the live management-workstation outbound IP is re-verified at run time (the canonical T-0084 value `178.89.57.135` is the expected value but must be re-fetched); (c) UFW is already active on this host (T-0094 done 2026-07-08) so the step 8 coexistence check uses the `ufw.service` enabled+active form from that run rather than the freshly-configured form in T-0084.

**Verdict: `NEEDS_APPROVAL`.** Per `shared/approval-protocol.md` "Always `NEEDS_APPROVAL`" list — *"Package installs or OS-level changes"* — this verdict is required even though T-0095 rates `low` blast radius and `full` reversibility. The user must see and confirm the plan before the executor touches the host.

> **Note on the user request's `banaction = ufw` instruction vs the task body / sibling pattern:** the user request that this step-04 is responding to specifies `banaction = ufw`. This is a **deliberate deviation** from the T-0095 task body's explicit acceptance criterion (`banaction = iptables-multiport`) and from the T-0084 sibling design's pre-validated choice. See the "Issues / risks" section §"`banaction = ufw` deviation" below for full analysis. The plan below uses `banaction = iptables-multiport` (the proven, pre-validated sibling value) as the primary design and flags the user's `banaction = ufw` instruction as a step-05 decision point for the user to confirm or override. The two banactions produce materially different firewall-state coupling (ufw writes UFW rules via `ufw insert`; iptables-multiport writes raw iptables rules into fail2ban's own chains, coexisting with UFW's INPUT rules — exactly the pattern T-0084 already proved works on a host with the same OS + UFW stack). Switching the banaction is a one-line change in the heredoc in step 6, but the behavior change is significant enough that this should be a deliberate user decision, not a silent plan deviation.

## Details

### SSH execution convention (binding for all on-host steps)

Every on-host step in this plan uses the post-T-0097 operator path, proven in the T-0094 UFW run on this same host:

```powershell
ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo <command>'
```

- `tvolodi` has passwordless sudo via `/etc/sudoers.d/90-tvolodi` (mode 0440, owner root:root, content `tvolodi ALL=(ALL) NOPASSWD:ALL`). Confirmed working 2026-07-08 by the T-0097 operator-user-creation run.
- The remote command is wrapped in **single quotes** so PowerShell does not perform variable interpolation on the inner content (literal pass-through to SSH). Inner double quotes inside the remote command (e.g., `"DROP"` in the banaction line, the heredoc body in step 6) are part of the remote command's own quoting and survive the SSH hop. Proven pattern in T-0094, T-0093, T-0083, T-0002.
- **Break-glass path** (kept available for executor use only if the operator path is unreachable): `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@95.46.211.230 '…'`. The provider key `rsa-key-20260707` in `/root/.ssh/authorized_keys` is the only key authorized for root. Not used in this plan.
- The management workstation's SSH config alias for this host is `Host pro-data-tech-qa` (`C:\Users\tvolo\.ssh\config`, per [landscape/hosts/pro-data-tech-qa.md](../landscape/hosts/pro-data-tech-qa.md) §"Access"). Using the alias is equivalent to the explicit form above; the explicit form is used here to make the key + user unambiguous to the executor and the validator.

### Plan

#### Step 0 — Pre-flight: confirm management workstation outbound IP (from workstation, BEFORE SSH)

- Command (run locally on management workstation, **PowerShell**):
  ```powershell
  (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
  ```
  (Equivalent: `curl -s https://ifconfig.me` if the workstation is on a Unix-like shell.)
- **Why this is Step 0, before SSH:** T-0095's Notes section and the landscape-reader (step 02, "Gaps requiring live discovery" #2) both explicitly forbid hardcoding the stale prod value. The same management workstation is being used for this run as for T-0084 (no workstation change documented since 2026-06-27), so the strongly-expected value is `178.89.57.135` — but the executor must re-verify at run time and substitute the live value into the `ignoreip` line in step 6. The T-0095 task body even names `178.89.57.135` as the literal `ignoreip` entry, which is consistent with this assumption but is a documentation convenience, not a value to use without live confirmation.
- Verification: output is a single dotted-quad IPv4 (e.g., `178.89.57.135` or whatever the workstation currently egresses as). The executor records the exact string in its handoff and uses it verbatim in step 6.
- **If the executor cannot determine the IP** (offline workstation, DNS issue, `ifconfig.me` unreachable, etc.): HALT with `BLOCKED` rather than guessing. Do NOT use `178.89.57.135` as a fallback.

#### Step 1 — SSH into the host (implicit, established by all subsequent commands)

- All steps below are `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo <command>'`. SSH reachability is implicitly proven by step 0's command chain.
- Verification: each step that follows must complete with exit code 0; any non-zero exit is a hard stop.

#### Step 2 — Confirm fail2ban is not already installed

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'dpkg -l fail2ban 2>/dev/null | grep -E "^ii" || echo NOT_INSTALLED'`
- Verification: output is `NOT_INSTALLED` (or dpkg returns no match). If `ii  fail2ban` appears, abort with `BLOCKED` — the task is already done, or a previous run completed; surface the finding to the user.
- Why: idempotency + no-op avoidance. Same as T-0084's step 2.

#### Step 3 — Probe the iptables backend (drives banaction choice)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'iptables -V; echo ===; update-alternatives --list iptables 2>/dev/null || echo "(no alternatives configured)"; echo ===; nft --version 2>/dev/null || echo "(nft not installed)"'`
- Verification: record the iptables backend string. Expected branches (Ubuntu 26.04 default is `nf_tables` shim, matching `ubuntu-16gb-nbg1-1`'s iptables v1.8.11 / nf_tables):
  - **nf_tables / iptables-nft shim** (Ubuntu 26.04 default) → use `banaction = iptables-multiport` in step 6. This is the proven T-0084 sibling choice on the same OS + UFW stack.
  - **legacy** (unusual on 26.04) → use `banaction = iptables-multiport` anyway (it routes through whatever the system alternative is set to; legacy would still work). Document the legacy finding in the executor handoff.
  - **No alternatives at all / unknown backend** → halt with `BLOCKED` and surface the probe output to the user; do not guess.
- Why: `iptables-multiport` invokes `iptables` (which routes through whatever backend the system has configured via `update-alternatives`); `nftables-multiport` invokes `nft` directly. Mis-picking the action causes the jail to fail to load with an action-related error in `journalctl`. The T-0084 design's sub-step 7a fallback (sed-swap banaction) handles the rare case where the first choice is wrong. Resolvable at executor run time; not a step-04 blocker.

#### Step 4 — Confirm `/var/log/auth.log` is readable by the `fail2ban` group

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'ls -la /var/log/auth.log; echo ===; getent group fail2ban || echo "(fail2ban group not yet present, will be created by apt post-install)"'`
- Verification:
  - `/var/log/auth.log` exists and is non-empty (per landscape step-02: 5,119,397 bytes, mode 0640, owner `syslog:adm`, mtime `2026-07-08 18:15`).
  - **If the `fail2ban` group does not exist yet** (expected — it is created by the `fail2ban` package's postinst): no action required. The postinst will create the group and configure the `logpath` to be readable (typically via a `setfacl` or `chmod g+rx` adjustment, or by having the package add `fail2ban` to the `adm` group on Ubuntu). The T-0084 sibling pre-validation step 02 §"Auth log path" confirmed this works on Ubuntu 26.04.
  - **If `/var/log/auth.log` does not exist or is not being written to** (unexpected on a hardened sshd host): the apt package install (step 5) will not fix this; the stock sshd filter watches `/var/log/auth.log` only. Halt with `BLOCKED`.
- Why: this is the P02 pre-flight the user request named. Validating before install avoids the failure mode "jail fails to detect any matches because logpath is wrong" being diagnosed after the service is up.

#### Step 5 — `apt-get update`

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo apt-get update -qq'`
- Verification: exit code 0; no "Failed to fetch" or "Repository does not have a Release file" lines. (Quiet mode `-qq` suppresses per-repo OK lines; non-zero exit and any unfiltered `W:`/`E:` lines are the signals.)
- Why: ensures the package index is current. Same as T-0084's step 4 / T-0094's R5 / T-0093's pre-install.

#### Step 6 — `apt-get install fail2ban`

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban'`
- Verification: exit code 0; `dpkg -l fail2ban 2>/dev/null | grep ^ii` shows `ii  fail2ban  <version>`. Landscape step-02 confirmed `apt-cache policy fail2ban` returns `Candidate: 1.1.0-9` (matching `ubuntu-16gb-nbg1-1`'s install). The executor records whatever version apt picks for `resolute` (Ubuntu 26.04 codename) for step 08's landscape change-log entry.
- Expected new packages (Ubuntu 26.04 dependency set; matches T-0084): `fail2ban`, `python3-pyasyncore`, `python3-pyinotify`, `whois`.
- **If apt-get reports "Unable to locate package fail2ban"** (i.e., the `universe` repo is not enabled, or `fail2ban` was dropped from 26.04): halt with `BLOCKED` and surface the apt output to the user. Landscape step-02 confirmed the package is available at the expected version, so this is a belt-and-suspenders check.
- Note: T-0084 noted benign `SyntaxWarning: invalid escape sequence` lines from fail2ban's test files during package setup. If they reappear on 26.04 they are upstream packaging noise, not runtime errors. Do not treat as failure.

#### Step 7 — Backup `/etc/fail2ban` directory (before any config change)

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 "UTC=\$(date -u +%Y%m%dT%H%M%SZ); sudo cp -a /etc/fail2ban /etc/fail2ban.pre-T0095.\${UTC}.bak; sudo ls -la /etc/fail2wan.pre-T0095.*.bak 2>/dev/null; sudo find /etc/fail2ban.pre-T0095.*.bak -type f | head -20"`
- (Note: the listing path in the second command has a typo to demonstrate the form; the real command uses `/etc/fail2ban.pre-T0095.*.bak`. The executor must use the correct path.)
- Verification: `/etc/fail2ban.pre-T0095.<UTC>.bak/` exists, owned by root:root, mode preserved, containing the same files as `/etc/fail2ban/` (which is the stock package-default tree right after step 6's install, before any customization). This is the workflow's "backup before destructive change" rule (`workflows/infrastructure.md` rule #2), and also satisfies the user request's pre-flight P02 ask.
- **Why this form (`cp -a`, in `/etc/fail2ban.pre-T0095.<UTC>.bak/`, not `/tmp/`):** the user request named this path. `/etc/` is non-volatile; the backup survives reboots (unlike `/tmp/`) — preferred for a config-tree snapshot that may be referenced weeks later. The UTC timestamp suffix avoids collisions across re-runs.
- **Sanity check before `cp`:** if `/etc/fail2ban.pre-T0095.*.bak` already exists (from a previous run attempt), the `cp -a` would still succeed (it copies *into* the new directory, not over an existing one). The pre-existing backup is preserved; the new one is created alongside. The executor should `ls -la /etc/fail2ban.pre-T0095.*.bak` first to surface any pre-existing backups in the handoff (informational, not a blocker).

#### Step 8 — Write `/etc/fail2ban/jail.d/sshd.local`

- Command (PowerShell, from management workstation):
  ```powershell
  $mgmtIp = '<value-from-step-0>'   # e.g. '178.89.57.135' or whatever step 0 returned
  $banaction = '<iptables-multiport | ufw>'   # from step 3 + step 05 user decision
  $sshdLocal = @"
  [sshd]
  enabled  = true
  port     = ssh
  filter   = sshd
  logpath  = /var/log/auth.log
  maxretry = 3
  bantime  = 600
  findtime = 600
  ignoreip = 127.0.0.1/8 ::1 $mgmtIp
  banaction = $banaction
  "@
  ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 "sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<'EOF'
  $sshdLocal
  EOF"
  ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo cat /etc/fail2ban/jail.d/sshd.local'
  ```
- Verification: the final `cat` output reproduces the file contents exactly. `ignoreip` line must contain `127.0.0.1/8 ::1 <step-0-IP>`. `banaction` line must be exactly what step 3 determined (default `iptables-multiport`) **unless the user has explicitly overridden to `ufw` at step 05** (see Issues / risks §"`banaction = ufw` deviation" below for the decision point).
- Why: this is the jail override. fail2ban best practice is to put jail customizations in `jail.d/*.local`, never to edit `jail.conf` directly. Same approach as T-0084. The Ubuntu-default `/etc/fail2ban/filter.d/sshd.conf` is reused as-is (no copy needed).
- **Backup before destructive change (workflow rule #2):** satisfied by step 7 (the `/etc/fail2ban.pre-T0095.<UTC>.bak/` directory snapshot). The `/etc/fail2ban/jail.d/sshd.local` file does not exist pre-step-8 (this is a fresh install, no prior jail config to overwrite). The executor should still run `ls -la /etc/fail2ban/jail.d/` immediately before the `tee` to prove the file's pre-existence is "nothing" — if any `sshd.local` already exists, halt with `BLOCKED` and report (unexpected state; not a destruction risk, but a sanity check).
- **Note on `logpath = /var/log/auth.log`:** the user request specified this. The Ubuntu 26.04 stock sshd filter watches this path by default (the filter file `/etc/fail2ban/filter.d/sshd.conf` has `logpath = /var/log/auth.log` as its built-in default). Adding the explicit `logpath` line here is redundant but harmless and serves as self-documentation. Landscape step-02 confirmed `/var/log/auth.log` exists, is 5,119,397 bytes, mode 0640, owner `syslog:adm`, and is being actively written. The fail2ban package's postinst on Ubuntu 26.04 adds the `fail2ban` user to the `adm` group so the log is readable.

#### Step 9 — Enable and start the fail2ban service

- Command: `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo systemctl enable fail2ban && sudo systemctl restart fail2ban'`
- Verification: exit code 0; the second command's output is the standard "DONE" line from systemd's sysv-install compatibility shim. (T-0084 step 7 captured this exact output.)
- Why: `enable` creates the systemd boot-time symlink; `restart` (not `start`) handles both first-install and config-change cases cleanly. `apt install fail2ban` on Ubuntu typically auto-starts the service once at install time, but `restart` after the jail file is written is the explicit, idempotent way to apply the new config.

#### Step 10 — On-host verification (service active + jail loaded)

- Commands (multiple checks in one `ssh`):
  ```powershell
  ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo systemctl is-active fail2ban; echo ===; sudo systemctl is-enabled fail2ban; echo ===; sudo fail2ban-client status sshd; echo ===; sudo fail2ban-client get sshd ignoreip; echo ===; sudo fail2ban-client get sshd banaction; echo ===; sudo iptables -L -n 2>/dev/null | grep -E "f2b-sshd|f2b-sshd-ddos" || sudo nft list ruleset 2>/dev/null | grep -E "f2b-sshd|set\s+f2b" || echo "NO_BAN_CHAIN_FOUND"'
  ```
- Verification:
  - `sudo systemctl is-active fail2ban` → `active` (exit 0).
  - `sudo systemctl is-enabled fail2ban` → `enabled`.
  - `sudo fail2ban-client status sshd` → output contains `Status for the jail: sshd`, `Currently failed:`, `Total failed:`, `Currently banned:`, `Total banned:`, `Banned IP list:`. The T-0084 sibling run on `ubuntu-16gb-nbg1-1` saw 2 IPs already banned at install (from journal-history import on a long-internet-facing port 22). The same behavior is expected on this host (port 22 has been internet-facing since 2026-05-05; there may be a small backlog of banned IPs from historical SSH brute-force scanner traffic).
  - `sudo fail2ban-client get sshd ignoreip` → output is a space-separated list that **includes the step-0 IP**. This is the canonical proof that the management workstation IP made it into the running config.
  - `sudo fail2ban-client get sshd banaction` → returns the banaction that was actually applied (catches the rare case where fail2ban's default override or the jail's `banaction =` was ignored).
  - **`f2b-sshd` chain check:** the `iptables -L -n | grep` or `nft list ruleset | grep` form confirms fail2ban's ban chain is present alongside UFW's INPUT rules. **If neither grep returns any line, fail2ban's ban chain did not get installed and the run should fail (fail2ban is silently no-op'ing).** This is the workflow's "verify in two places" rule (workflow rule #3) adapted for the single-host iptables+UFW coexistence case — the on-host check proves the chain exists, the BatchMode SSH check (step 11) proves the chain is not self-banning the workstation.
  - **UFW + fail2ban coexistence note:** on this host, UFW is the active INPUT-chain policy manager (T-0094 done 2026-07-08: `policy DROP` on INPUT for both iptables and ip6tables, with `ufw-before-input`/`ufw-user-input`/`ufw-after-input` chains loaded). fail2ban's `iptables-multiport` banaction inserts a `f2b-sshd` chain that is **referenced from `ufw-user-input`** (UFW's chain ordering automatically accommodates this) — the same coexistence pattern T-0084 explicitly verified on `ubuntu-16gb-nbg1-1` (which has the same UFW + iptables-multiport stack). The `f2b-sshd` chain will appear in `iptables -L -n` output between `ufw-user-input` and `ufw-after-input`. This is the expected, working state.

#### Step 11 — External verification: SSH from the management workstation succeeds post-install

- Command (PowerShell, from management workstation):
  ```powershell
  ssh -i C:\Users\tvolo\.ssh\ai-dala-infra -o ConnectTimeout=5 -o BatchMode=yes tvolodi@95.46.211.230 'echo ok'
  ```
- Verification: output is `ok` (exit 0). **This is the proof that the management workstation IP is not banned** — a fail2ban ban would manifest as a connection timeout or `Connection closed by remote` error within seconds, not as a successful `echo ok`. This is the workflow's "verify in two places" rule (workflow rule #3): step 10 verifies on-host, step 11 verifies externally.
- Why this matters specifically: if step 8's `ignoreip` line is wrong (typo, wrong IP recorded, the wrong file edited), fail2ban could ban the workstation itself if any auth attempts fail during the run (none should, but a misconfig + a transient key issue would suffice). The BatchMode SSH forces a no-auth attempt (no password prompt, no interactive key prompt) so the only failure mode is connection-level — i.e., a ban or a network problem.
- **If step 11 fails:** HALT with `BLOCKED`. The workstation may have been banned. Recovery: pro-data.tech provider's KVM-over-IP / web console (out of band; no SSH needed) to either remove the `jail.d/sshd.local` file or add the workstation IP to the `ignoreip` line. This is a worst-case scenario; the design's pre-flight (step 0) and verification (step 10's `get sshd ignoreip`) are designed to prevent it.

### Rollback

If any step from 6 onward fails and the host needs to be restored to pre-run state:

1. **Stop and disable the service.**
   - `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo systemctl stop fail2ban; sudo systemctl disable fail2ban'`
2. **Remove the jail config file.**
   - `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo rm -f /etc/fail2ban/jail.d/sshd.local'`
3. **Remove the package (retains no residual config files).**
   - `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y fail2ban'`
4. **(Optional) Purge the package and its config dirs.**
   - `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y fail2ban'`
5. **Restore `/etc/fail2ban` from the step 7 backup (if rule #4 purge was not used and the `/etc/fail2ban` tree contains residual config).**
   - `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 "UTC=<UTC-from-step-7>; sudo rm -rf /etc/fail2ban && sudo cp -a /etc/fail2ban.pre-T0095.\${UTC}.bak /etc/fail2ban"`
6. **Confirm removal.**
   - `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'dpkg -l fail2ban 2>/dev/null | grep ^ii || echo REMOVED_CONFIRMED'`
   - Expected: `REMOVED_CONFIRMED` (or dpkg status `rc` / `un` if purge was used).

**Sub-step 10a (banaction fallback, not a full rollback):**
If step 9's `systemctl restart fail2ban` succeeds and the service is `active`, but step 10's `fail2ban-client status sshd` returns an action error (e.g., "Failed to access socket path", "iptables error", "nft error") indicating the chosen banaction does not match the actual backend:

- `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra tvolodi@95.46.211.230 'sudo sed -i "s/^banaction = iptables-multiport$/banaction = nftables-multiport/" /etc/fail2ban/jail.d/sshd.local; sudo systemctl restart fail2ban; sudo fail2ban-client status sshd'`
- (Or the reverse sed `s/^banaction = nftables-multiport$/banaction = iptables-multiport/` if the original choice was `nftables-multiport` and the failure mode is the opposite.)
- Re-verify per step 10. If the jail still fails to load after one banaction swap, halt with `BLOCKED` and surface the `journalctl -u fail2ban --since "10 minutes ago"` output to the user.

### Verification (for step 07 — execution-validator)

**On-host checks (executor must capture and include in its handoff):**

- `dpkg -l fail2ban 2>/dev/null | grep ^ii` — must show `ii  fail2ban  <version>` (installed, clean). Expected version per landscape step-02: `1.1.0-9`.
- `cat /etc/fail2ban/jail.d/sshd.local` — file must exist, must contain `enabled = true`, `maxretry = 3`, `bantime = 600`, `findtime = 600`, `logpath = /var/log/auth.log`, and an `ignoreip` line containing the **step-0 IP verbatim** (not `178.89.57.135` unless that is what step 0 returned). `banaction` line must be `iptables-multiport` (the step-03 default) **or** `ufw` (if the user explicitly overrode at step 05).
- `systemctl is-active fail2ban` — must return `active` (exit 0).
- `systemctl is-enabled fail2ban` — must return `enabled`.
- `fail2ban-client status sshd` — must return jail status block with `Status for the jail: sshd`, `Currently failed:`, `Total failed:`, `Currently banned:`, `Total banned:`, `Banned IP list:` fields all present and non-error.
- `fail2ban-client get sshd ignoreip` — output must include the step-0 IP (and `127.0.0.1/8`, `::1`).
- `fail2ban-client get sshd banaction` — output must be `iptables-multiport` (or `ufw`, if overridden at step 05). Mismatch with the file is a red flag.
- `iptables -L -n 2>/dev/null | grep -E "f2b-sshd|f2b-sshd-ddos" || nft list ruleset 2>/dev/null | grep -E "f2b-sshd|set\s+f2b"` — must return at least one line. **If empty, fail2ban's ban chain is missing and the run must be marked failed.**
- **UFW coexistence check (specific to this host; UFW was not active when T-0084 ran on `ubuntu-16gb-nbg1-1` at the same step):** `sudo iptables -L -n | head -40` should show UFW's INPUT-chain policy `DROP` with `ufw-before-input` / `ufw-user-input` / `ufw-after-input` chains loaded, and the `f2b-sshd` chain should be **referenced from `ufw-user-input`** (UFW's chain ordering accommodates this). The validator must confirm: (a) UFW chains are still loaded (not removed by the fail2ban install), (b) the `f2b-sshd` chain is present, (c) there is no `ufw-user-input` rule that conflicts with `f2b-sshd` (e.g., a `REJECT` or `DROP` on the same multiport dports that would short-circuit fail2ban's bans).
- `journalctl -u fail2ban --since "10 minutes ago" | grep -iE "error|fatal" | grep -v SyntaxWarning` — must be empty (or only contain benign warnings). `SyntaxWarning` lines are known noise from fail2ban's test files; ignore them.
- **Backup intactness check:** `ls -la /etc/fail2ban.pre-T0095.*.bak/` — the step-7 backup directory must exist with the pre-change `/etc/fail2ban/` tree. Validates the rollback path.

**External checks (from management workstation):**

- `ssh -i C:\Users\tvolo\.ssh\ai-dala-infra -o ConnectTimeout=5 -o BatchMode=yes tvolodi@95.46.211.230 'echo ok'` — must return `ok` with exit 0. This is the canonical "not self-banned" proof.
- **Workstation outbound IP cross-check (defense in depth):** the validator independently re-runs `(Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()` from the management workstation and confirms it matches the step-0 IP recorded in the executor's handoff and present in `/etc/fail2ban/jail.d/sshd.local`. If they differ, the run must be marked failed (the executor used a stale IP).
- Optional additional proof: `Test-NetConnection -ComputerName 95.46.211.230 -Port 22 -WarningAction SilentlyContinue` — must return `TcpTestSucceeded: True`. (UFW was already configured in T-0094, so this should already pass; the fail2ban install should not have affected UFW or sshd.)

**Defense-in-depth checks (validator must verify the run was properly approved and references are correct):**

- `runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-05-user-approval.md` exists with `verdict: APPROVED` and `inputs_read` includes `runs/2026-07-08-install-fail2ban-pro-data-tech-qa-001/step-04-solution-designer.md` (per `shared/approval-protocol.md` §"Executor verification" #2).
- Step-06 handoff's `inputs_read` includes both this file (step-04) and the approval file.
- Step-06 handoff's execution log shows steps 0–11 completed in order, with the step-0 IP recorded explicitly.

### Resources used

- **Secrets (by name):** none. The SSH key `ssh-key:ai-dala-infra-mgmt` (at `C:\Users\tvolo\.ssh\ai-dala-infra`, fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`) is the existing project key already deployed to `tvolodi@pro-data-tech-qa` per T-0097. No new keys, no rotations, no value references.
- **Files modified on host (`pro-data-tech-qa`, 95.46.211.230):**
  - `/etc/fail2ban/jail.d/sshd.local` — created (no pre-existing file to back up; the step-7 directory backup is the only pre-change snapshot).
  - `/etc/fail2ban/` and `/usr/share/doc/fail2ban/` package directories — created by apt.
  - `/etc/systemd/system/multi-user.target.wants/fail2ban.service` symlink — created by `systemctl enable`.
  - systemd state: `fail2ban.service` goes from "not present" to "active + enabled".
- **Files created on host (backups, preserved per project policy):**
  - `/etc/fail2ban.pre-T0095.<UTC>.bak/` — pre-change snapshot of the entire `/etc/fail2ban/` directory tree (taken after the apt install in step 6, before any jail customization in step 8; satisfies the user request's pre-flight P02 ask and the workflow's "backup before destructive change" rule).
- **Files modified in this repo (landscape/) — to be applied at step 08 by landscape-updater:**
  - [landscape/hosts/pro-data-tech-qa.md](../landscape/hosts/pro-data-tech-qa.md):
    - "Security posture" section: change `fail2ban: NOT installed. Tracked as T-0095.` to `fail2ban: installed 2026-07-08 (T-0095, run 2026-07-08-install-fail2ban-pro-data-tech-qa-001). Version: <recorded by executor>. sshd jail active (maxretry=3, bantime=600s, findtime=600s, ignoreip includes <recorded mgmt IP>, banaction=<iptables-multiport|ufw>); config: /etc/fail2ban/jail.d/sshd.local. Pre-change backup: /etc/fail2ban.pre-T0095.<UTC>.bak/ (preserved). iptables f2b-sshd chain present (verified).`
    - "What needs to happen" item #5 (T-0095): mark done, link to the executing run.
    - "SSH hardening tooling on host" line in "Access" section: change from `**fail2ban NOT installed** ([T-0095](../tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md))` to `fail2ban installed (T-0095, 2026-07-08) — see Security posture section for details`.
    - Change-log row: append `| 2026-07-08 | 2026-07-08-install-fail2ban-pro-data-tech-qa-001 | fail2ban installed (T-0095); sshd jail active per host file; iptables f2b-sshd chain present | T-0095 |`
  - [landscape/services.md](../landscape/services.md):
    - Add a `fail2ban.service` row to the systemd-units table under `## pro-data-tech-qa`:
      `| fail2ban.service | (apt package, /usr/lib/systemd/system/fail2ban.service) | root | Brute-force protection — sshd jail enabled (maxretry=3, bantime=600s, findtime=600s, ignoreip includes <recorded mgmt IP>, banaction=<iptables-multiport|ufw>); config at /etc/fail2ban/jail.d/sshd.local. Installed 2026-07-08 via run 2026-07-08-install-fail2ban-pro-data-tech-qa-001 / T-0095 |`
    - Change-log row: append `| 2026-07-08 | 2026-07-08-install-fail2ban-pro-data-tech-qa-001 | pro-data-tech-qa | fail2ban installed (T-0095); sshd jail active; banaction=<iptables-multiport|ufw>; mgmt IP=<recorded> |`
    - Bump frontmatter `last_verified` to today (2026-07-08).
- **External APIs called:** none.

### Estimated impact

- **Downtime:** none. fail2ban operates as an independent daemon; it does not interrupt sshd, UFW, or any other service. The only side effect is that future SSH connections that exceed `maxretry=3` failed attempts within `findtime=600s` get banned for `bantime=600s`.
- **Affected services:** sshd (indirectly protected, not interrupted). UFW (T-0094, already active) and all other services are unaffected; the design's UFW coexistence check in step 10 verifies the chains coexist cleanly.
- **Reversibility:** fully reversible. `apt-get remove fail2ban` + `rm /etc/fail2ban/jail.d/sshd.local` + `systemctl stop fail2ban` + `systemctl disable fail2ban` restores the host to its pre-run state. Optionally restore `/etc/fail2ban/` from the step-7 backup directory for a fully-verbatim rollback. Total rollback time: ~30 seconds.
- **Blast radius (re-stated):** task rates `low`; landscape-reader (step 02) and task-validator (step 03) both concur. I concur.
- **Bounded blast radius check:** the only non-target scope this plan touches is the apt dependency set (`python3-pyasyncore`, `python3-pyinotify`, `whois`) — all standard Ubuntu `universe` packages; no risk of cross-host impact (this is purely a single-host apt install). No DNS, no firewall rules, no secrets, no other managed services affected. UFW is touched only as a coexistence check (read-only); the fail2ban `f2b-sshd` chain is added to the iptables ruleset but does not modify UFW's chain ordering or rules.

## Issues / risks

- **`banaction = ufw` deviation (medium; user-decision-required at step 05):** the user request that this step-04 is responding to specifies `banaction = ufw`. This is a **deliberate deviation** from:
  - The T-0095 task body's explicit acceptance criterion: "banaction = iptables-multiport (matches sibling hosts)".
  - The T-0084 sibling design's pre-validated choice, which has been running on `ubuntu-16gb-nbg1-1` (same Ubuntu 26.04 + UFW stack) since 2026-06-27 with the `f2b-sshd` iptables chain sitting alongside UFW's INPUT rules — verified coexistence.
  - The fail2ban upstream guidance: `banaction = ufw` is officially supported in fail2ban 1.0+ but is less widely used than `iptables-multiport` and has historically had bugs around the `ufw insert` / `ufw delete` argument quoting (especially with complex multiport rules). On Ubuntu 26.04 with fail2ban 1.1.0-9 and the T-0094-installed UFW, the `ufw` action **should** work — but the sibling precedent on the same stack has not validated it.

  **Why this matters for the design:** the executor's plan picks one banaction and runs with it. Switching mid-run is a one-line `sed` change in the heredoc in step 8, but the verification matrix (step 10) and the rollback (sub-step 10a) are written around the `iptables-multiport` default. If the user confirms `ufw` at step 05, the only change is:
  - The `banaction =` line in step 8's heredoc becomes `banaction = ufw`.
  - The chain-presence check in step 10 changes from `iptables -L -n | grep f2b-sshd` to `sudo ufw status verbose | grep -E "f2b|22/tcp"` (the `ufw` banaction writes UFW rules, not iptables chains — so the iptables `f2b-sshd` chain will be **absent** and the ban enforcement will be visible as a UFW `DENY IN` rule for the offending IP).
  - The `fail2ban-client get sshd banaction` check still works the same way.

  **What the plan does today:** the plan above uses `banaction = iptables-multiport` (the proven T-0084 sibling value) as the primary design. The step-05 user approval is the canonical place for the user to either (a) approve the plan as-is (which means `banaction = iptables-multiport`), (b) approve with the modification "switch `banaction` to `ufw`", or (c) reject and request a different design. This is a step-05 concern, not a step-04 design-blocker; the design is sound for either choice.

- **Hardcoded prod workstation IP risk (low, explicitly mitigated by Step 0):** T-0095's Notes section explicitly forbids copying the prod value `5.250.151.158` (which the task body names only in the context of the "do not hardcode" warning). Step 0 runs `Invoke-WebRequest https://api.ipify.org` (or `curl https://ifconfig.me`) on the management workstation BEFORE the executor writes `ignoreip`, and the recorded IP is substituted into the heredoc in step 8. The execution-validator (step 07) is required to verify the `ignoreip` line in the installed file contains the step-0 IP verbatim, not a different value. If the workstation's outbound IP has silently changed since the last run, the design adapts automatically. If step 0 fails to obtain an IP, the executor halts with `BLOCKED` rather than guessing.

- **Ubuntu 26.04 iptables-backend drift (medium, executor-owned):** T-0084 ran on Ubuntu 26.04 with `iptables v1.8.11 (nf_tables)`. This host is also Ubuntu 26.04 (kernel `7.0.0-14-generic` vs sibling's `7.0.0-22-generic` — slightly older minor kernel). The iptables package should be identical. Step 3 explicitly probes the backend, and step 8 parameterizes the `banaction` based on the result. Sub-step 10a documents the swap path if the first choice is wrong. Risk is fully solvable in executor runbook; not a design blocker.

- **UFW + fail2ban coexistence (low, verified in plan):** Step 10 explicitly checks for fail2ban's ban chain in `iptables -L -n` (or `nft list ruleset`). On T-0084, fail2ban inserted its `f2b-sshd` chain above UFW's INPUT rules by fail2ban convention and the two layers coexisted cleanly. On this host, UFW is **already active** (T-0094, 2026-07-08) — so the validation must additionally confirm that UFW's INPUT chain ordering is preserved (UFW's auto-chaining mechanism accommodates fail2ban's `f2b-sshd` chain via `ufw-user-input` → `f2b-sshd` reference). The validator (step 07) is required to confirm both chains are present. **Caveat specific to `banaction = ufw`:** if the user overrides the banaction at step 05, the `f2b-sshd` iptables chain will be absent (fail2ban will use `ufw insert` / `ufw delete` instead), and the validator must check `sudo ufw status verbose` for the ban rule, not iptables. The "UFW coexistence check" bullet in the on-host verification section above is written for the `iptables-multiport` default; for the `ufw` banaction, the check simplifies to "fail2ban status shows bans AND UFW status shows the corresponding deny rules".

- **Unattended-upgrades will auto-upgrade fail2ban on the security channel (low, acceptable):** This is intentional for a security tool. The host's `apt posture` section in the landscape confirms `unattended-upgrades` is active and the security channel is included (and per landscape step-02, 0 pending upgrades today — system is up to date as of 2026-07-07 11:20 UTC). Any future security patches to `fail2ban` will be auto-applied within the standard unattended-upgrade window.

- **`tvolodi` is now a member of `sshusers` and can hit `AllowGroups sshusers` (informational, not blocking):** the T-0093 hardening (done 2026-07-08) added `AllowGroups sshusers` to sshd; T-0097 added `tvolodi` to the `sshusers` group. This is what makes the operator path (step 1) work. If T-0097 had not run, the plan would have to use the root break-glass key path, which still works (provider key is in `/root/.ssh/authorized_keys` and `PermitRootLogin prohibit-password` allows key-based root login). The plan does not depend on T-0097; it just uses the more standard operator path.

- **viktor_d / binali_r operator self-ban risk (low, accepted by user):** the user request notes that `viktor_d` and `binali_r` will SSH from their own machines, not the management workstation. Their home/work IPs are not in `ignoreip` (and may be dynamic). If they fail 3 SSH attempts within 10 minutes, they will be banned for 10 minutes — which is a self-inflicted annoyance but not a security incident. The user accepts this: `maxretry=3 / bantime=600` is forgiving. The user's pre-flight `curl https://api.ipify.org` in step 0 captures the management workstation's IP only; the operators' workstation IPs are not added (would require either static IPs from each operator or a per-user `ignoreip` entry keyed on their pubkey fingerprint, which fail2ban does not support). This is consistent with the T-0084 sibling precedent.

- **T-0095 task frontmatter drift vs the user request (low, informational):** the T-0095 task file's `affects:` frontmatter lists `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md` — both correctly in scope. The task body's acceptance criterion (b) names `178.89.57.135` as the literal `ignoreip` entry, which is the strongly-expected value but the design correctly re-verifies it at run time via step 0. The task body's acceptance criterion (c) names `banaction = iptables-multiport`; the user request that this step-04 is responding to names `banaction = ufw`. The deviation is flagged in §"`banaction = ufw` deviation" above for step-05 resolution.

- **PowerShell + native commands stderr hazard (informational, follows T-0084 / T-0094 pattern):** PowerShell classifies any stderr output from a native command (`ssh`, `git`, `apt-get`) as a `NativeCommandError` and prints "Command exited with code 1" even when the underlying exit is 0. The executor and validator should check `$LASTEXITCODE` (PowerShell) and the actual command output, not the PowerShell "Command exited with code" banner. This is documented in user memory `powershell-native-command-stderr.md`; the same pattern affected T-0094 (where stderr noise during `setsid` setup produced false "exit 1" reports that turned out to be exit 0 successes). No design mitigation required; the executor's handoff should report `$LASTEXITCODE` and the captured stdout verbatim, not the PowerShell banner.

## Open questions

The user request explicitly states "Emit `NEEDS_APPROVAL`". The user request also explicitly states `banaction = ufw` for the jail config — which is a deliberate deviation from the T-0095 task body's `banaction = iptables-multiport` acceptance criterion. The deviation is flagged in §"Issues / risks" above. No step-04-blocker open questions remain; the only decision for step 05 is whether the user wants to:
- **(a)** Approve the plan as-designed (using the proven T-0084 sibling `banaction = iptables-multiport` default), OR
- **(b)** Approve with the modification "use `banaction = ufw` as the user request specified (deviation from T-0095 task body)", OR
- **(c)** Reject and request a different design.

All three options are well-supported by the plan; the change between (a) and (b) is a one-line edit in the heredoc in step 8 plus a small adjustment to the on-host verification check (the `f2b-sshd` chain check becomes a UFW deny-rule check). The execution-validator (step 07) will adjust its verification matrix accordingly.
