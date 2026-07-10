---
step: 04
agent: solution-designer
run_id: 2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001
task_id: T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa
verdict: NEEDS_APPROVAL
inputs_read:
  - runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-10-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa-001/step-03-task-validator.md
  - tasks/T-0099-apply-pending-kernel-upgrade-reboot-pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-06-executor-discovery.md
  - /memories/repo/ufw-rollback-timer-process-group.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
---

# Step 04 — solution-designer

## Plan summary

Apply 9 pending `-updates` apt upgrades (kernel + meta-packages) on `pro-data-tech-qa` (95.46.211.230) and reboot the host into the new kernel `7.0.0-27-generic`. The plan captures a Postgres `pg_dump` snapshot first, runs `apt full-upgrade -y`, then triggers a `setsid`-detached `systemctl reboot` so the reboot survives the SSH session closing. A workstation-side PowerShell polling loop waits up to 300 s for SSH to return, then verifies on-host (kernel, services, container health) and externally (TCP probe + interactive SSH). The plan is **safe to re-run from Phase 0** (idempotent pre-flight + pg_dump are read-only / additive-only; `apt full-upgrade` is naturally idempotent on already-applied packages).

**Verdict rationale (`NEEDS_APPROVAL`):** Task's `estimated_blast_radius: medium` and `estimated_reversibility: partial` are correct — kernel upgrades are effectively one-way (the new kernel boots; rolling back requires manual GRUB selection via the pro-data.tech KVM console if anything goes wrong). The plan itself is sound and the designer has no doubts about correctness, but `shared/approval-protocol.md` is explicit: "Any plan the designer is uncertain about" and "OS-level changes" both trigger `NEEDS_APPROVAL`. Rebooting a remote host with live state is exactly the action the human gate is designed for.

## Phases

### Phase 0 — Pre-flight state capture (idempotent, read-only)

All commands run via `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" tvolodi@95.46.211.230 '...'`. `tvolodi` is the preferred everyday operator post-T-0097 (alias `pro-data-tech-qa` in `~/.ssh/config` defaults to `User tvolodi`); root operations use `sudo -n`. If `tvolodi` SSH ever fails, fall back to `ssh -i ... root@95.46.211.230`.

```bash
# 0.1 Sanity
ssh pro-data-tech-qa 'whoami && id && hostname && sudo -n true && echo SUDO_OK && uptime && date -u'

# 0.2 Capture current kernel + reboot-required marker
ssh pro-data-tech-qa 'uname -r; sudo cat /var/run/reboot-required 2>&1 || echo NO_REBOOT_REQUIRED'

# 0.3 Re-snapshot pending upgrades (audit data is from 2026-07-10 02:13 UTC; refresh now)
ssh pro-data-tech-qa 'apt list --upgradable 2>/dev/null'

# 0.4 Confirm /boot has room for the new kernel image (~80–100 MB each)
ssh pro-data-tech-qa 'df -h /boot'

# 0.5 Confirm previous kernel is still installed (rollback anchor)
ssh pro-data-tech-qa 'dpkg -l | grep -E "^ii\s+linux-image-(7\.0\.0-14|7\.0\.0-27)-generic"'

# 0.6 Confirm Postgres volume exists and check its size for backup-sizing
ssh pro-data-tech-qa 'sudo docker volume inspect ai-qadam-test_ai_qadam_test_pgdata --format "{{ .Mountpoint }}" && sudo du -sh /var/lib/docker/volumes/ai-qadam-test_ai_qadam_test_pgdata/_data 2>/dev/null'

# 0.7 Confirm fail2ban ignoreip includes workstation (178.89.57.135) to avoid post-reboot bans
ssh pro-data-tech-qa 'sudo fail2ban-client get sshd ignoreip'

# 0.8 Confirm docker.service + containerd.service are enabled (auto-start on boot)
ssh pro-data-tech-qa 'systemctl is-enabled docker containerd && sudo docker ps --filter name=ai-qadam-test-db-1 --format "{{.Status}}"'

# 0.9 Capture public outbound IP for fail2ban ignoreip self-check (workstation side)
curl -s https://ifconfig.me; echo
```

**Verification (Phase 0):** `SUDO_OK`, kernel `7.0.0-14-generic` confirmed, `/var/run/reboot-required` exists with `linux-image-7.0.0-27-generic` listed, ≥80 MB free on `/boot`, BOTH `linux-image-7.0.0-14-generic` AND `linux-image-7.0.0-27-generic` present in `dpkg -l` (the `-27` may be in "half-installed" state before apt full-upgrade; that's fine — it'll complete), Postgres volume present, container currently `(healthy)`, ignoreip contains `178.89.57.135`. **If any check fails, HALT and report.**

---

### Phase 1 — Postgres pg_dump (data snapshot, optional but recommended)

The Postgres volume has no automated backup (T-0098 still open). Take a `pg_dump` to `/var/backups/` before the upgrade. This is **the only data-level rollback point** for this run.

```bash
# 1.1 Create timestamped backup directory
ssh pro-data-tech-qa 'sudo mkdir -p /var/backups/pre-T0099.20260710T$(date -u +%H%M%S)Z'

# 1.2 Read POSTGRES_PASSWORD from .env (root needed for /var/www read; mode 600)
ssh pro-data-tech-qa 'sudo bash -c "set -a; source /var/www/ai-qadam-test/.env; set +a; docker exec -e PGPASSWORD=\"\$POSTGRES_PASSWORD\" ai-qadam-test-db-1 pg_dump -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Fc --no-owner --no-acl | gzip > /var/backups/pre-T0099.\$(date -u +%Y%m%dT%H%M%SZ)/ai-qadam-test.dump.gz"'

# 1.3 Verify the dump is non-empty and pg_restore-readable
ssh pro-data-tech-qa 'ls -lh /var/backups/pre-T0099.*/ai-qadam-test.dump.gz && sudo bash -c "gunzip -c /var/backups/pre-T0099.*/ai-qadam-test.dump.gz | pg_restore -l 2>&1 | head -10" || echo "pg_restore not on host (acceptable; dump is still valid)"
```

**Verification (Phase 1):** `/var/backups/pre-T0099.<ts>/ai-qadam-test.dump.gz` exists, size > 0 (the test DB is small — expect <10 MB), `pg_restore -l` (if available on host) lists TOC entries without errors. **If size is 0 or pg_dump failed: HALT — do NOT proceed to Phase 2 without a data snapshot.**

**Backup location:** `/var/backups/pre-T0099.<ts>/ai-qadam-test.dump.gz` (local disk only, per project hard rule "no off-site/external storage"). 142 GB free on `/`, ample for a multi-MB dump.

---

### Phase 2 — apt full-upgrade

Belt-and-braces: stop unattended-upgrades timers first so they don't fire mid-upgrade (apt's own lock would normally block this, but belt-and-braces for clarity).

```bash
# 2.1 Stop unattended-upgrades timers for the upgrade window
ssh pro-data-tech-qa 'sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer && sudo systemctl is-active apt-daily.timer apt-daily-upgrade.timer || echo TIMERS_STOPPED'

# 2.2 Refresh package lists
ssh pro-data-tech-qa 'sudo apt update'

# 2.3 Run full-upgrade (NOT `apt upgrade` — full-upgrade allows the kernel meta-package to install / pull in the new image)
ssh pro-data-tech-qa 'sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y'

# 2.4 Verify the new kernel image is installed
ssh pro-data-tech-qa 'dpkg -l | grep -E "^ii\s+linux-image-(7\.0\.0-14|7\.0\.0-27)-generic" && echo "---"; ls -1 /boot/vmlinuz-* 2>/dev/null'

# 2.5 Re-enable unattended-upgrades timers (will pick up security/ESM only — won't re-touch -updates)
ssh pro-data-tech-qa 'sudo systemctl start apt-daily.timer apt-daily-upgrade.timer && sudo systemctl is-active apt-daily.timer apt-daily-upgrade.timer'
```

**Verification (Phase 2):** exit code 0 from `apt full-upgrade` (stdout captured in the SSH transcript), `linux-image-7.0.0-27-generic` now in `dpkg -l` as `ii` (installed), `linux-image-7.0.0-14-generic` still present (used as GRUB fallback), both `vmlinuz-7.0.0-14-generic` and `vmlinuz-7.0.0-27-generic` present in `/boot/`, timers re-started. **If `apt full-upgrade` exit code ≠ 0: HALT — do NOT proceed to reboot.**

---

### Phase 3 — Pre-reboot housekeeping (autoremove dry-run)

The audit didn't confirm whether `Remove-Unused-Dependencies` is set in `/etc/apt/apt.conf.d/50unattended-upgrades`. Run `autoremove --dry-run` first to see what would be removed; only if the new kernel is fully installed and we want to clear old kernels do we run it for real.

```bash
# 3.1 Dry-run autoremove to see what would be removed (do NOT execute yet)
ssh pro-data-tech-qa 'sudo apt autoremove --dry-run'

# 3.2 Inspect /boot space AFTER the upgrade (should now have BOTH 7.0.0-14 and 7.0.0-27 kernel images)
ssh pro-data-tech-qa 'df -h /boot && ls -1 /boot/vmlinuz-* /boot/initrd.img-* 2>/dev/null'

# 3.3 Manual judgment: if /boot is < 50 MB free, autoremove for real (purge old kernels); else skip
# If autoremove is needed:
ssh pro-data-tech-qa 'sudo apt autoremove --purge -y'
```

**Verification (Phase 3):** `/boot` has ≥ 50 MB free after the upgrade; both kernel images present. `autoremove` only run if needed (typically not — 989 MB `/boot` at 17% used comfortably holds two kernels).

---

### Phase 4 — Pre-reboot snapshot (config + state)

Capture rollback anchors before the reboot.

```bash
# 4.1 Create timestamped snapshot dir
ssh pro-data-tech-qa 'sudo mkdir -p /var/backups/pre-T0099.20260710T$(date -u +%H%M%S)Z'

# 4.2 Capture /proc/version, uname, dpkg kernel selections
ssh pro-data-tech-qa 'sudo bash -c "
  {
    echo \"=== uname -a ===\"; uname -a
    echo \"=== /proc/version ===\"; cat /proc/version
    echo \"=== dpkg linux-image / linux-headers selections ===\"; dpkg --get-selections | grep -E \"linux-(image|headers|modules)-\"
    echo \"=== current default kernel (GRUB) ===\"; grub-editenv list 2>/dev/null || echo \"grub-editenv unavailable\"
    echo \"=== GRUB menu entries ===\"; grep -E \"^menuentry\" /boot/grub/grub.cfg 2>/dev/null | head -10
    echo \"=== /var/run/reboot-required ===\"; cat /var/run/reboot-required 2>/dev/null || echo \"no reboot-required marker\"
    echo \"=== apt upgradable (post-upgrade) ===\"; apt list --upgradable 2>/dev/null
    echo \"=== docker ps pre-reboot ===\"; docker ps
    echo \"=== /etc/sudoers.d list ===\"; ls -la /etc/sudoers.d/
    echo \"=== sshd drop-in list ===\"; ls -la /etc/ssh/sshd_config.d/
    echo \"=== fail2ban jail list ===\"; fail2ban-client status
    echo \"=== ufw status ===\"; ufw status verbose
    echo \"=== fail2ban sshd ignoreip ===\"; fail2ban-client get sshd ignoreip
    echo \"=== cron/timers ===\"; systemctl list-timers --all | head -30
  } > /var/backups/pre-T0099.\$(date -u +%Y%m%dT%H%M%SZ)/pre-reboot-state.txt
  chmod 0640 /var/backups/pre-T0099.\$(date -u +%Y%m%dT%H%M%SZ)/pre-reboot-state.txt
"'

# 4.3 Capture /etc snapshot for full config rollback
ssh pro-data-tech-qa 'sudo tar -czf /var/backups/pre-T0099.$(date -u +%Y%m%dT%H%M%SZ)/etc-snapshot.tar.gz /etc/ssh /etc/sudoers.d /etc/fail2ban /etc/ufw /etc/default/ufw /etc/apt /etc/systemd 2>/dev/null'

# 4.4 List and verify the snapshot
ssh pro-data-tech-qa 'sudo ls -la /var/backups/pre-T0099.*/ && sudo cat /var/backups/pre-T0099.*/pre-reboot-state.txt | head -30'
```

**Verification (Phase 4):** `/var/backups/pre-T0099.<ts>/pre-reboot-state.txt` non-empty; `/var/backups/pre-T0099.<ts>/etc-snapshot.tar.gz` non-empty; snapshot captures current kernel, both old + new kernel in `dpkg --get-selections`, current GRUB default.

---

### Phase 5 — Backgrounded reboot (`setsid` + group-detach)

The standard `nohup systemctl reboot &` is **insufficient** — when the SSH session terminates, the kernel sends SIGHUP to the foreground process group, but `nohup` ignores SIGHUP. The deeper issue is whether the SIGTERM that sshd sends to the session-leader before close propagates to the systemctl child. Using `setsid` puts `systemctl reboot` in its own session + process group, fully detached from the SSH session.

```bash
# 5.1 Initiate backgrounded, setsid-detached reboot
ssh pro-data-tech-qa 'sudo setsid systemctl reboot </dev/null >/dev/null 2>&1 & disown; echo "reboot_kicked_off_at_$(date -u +%H:%M:%SZ)_pid=$!"'

# 5.2 The SSH session will drop within ~2–10 seconds. Do NOT wait for it; let it close.
# Capture the local-side timestamp before kicking off so we can measure outage window.
date -u +"%Y-%m-%dT%H:%M:%SZ"  # record kickoff time
```

**Verification (Phase 5):** The `setsid` invocation returned with a PID (typically 1–4 digits); the SSH session drops within seconds (this is expected, not a failure). Polling starts in Phase 6 from the workstation side.

---

### Phase 6 — Workstation-side polling for SSH return (300 s budget)

The polling loop runs in PowerShell on the management workstation (`C:\Users\tvolo\dev\ai-dala\ai-dala-infra` workflow root). Per `/memories/repo/ufw-rollback-timer-process-group.md` and `ufw-atd-fallback-nohup.md`, **never** run the polling loop on the remote host — it dies with the SSH connection.

```powershell
# Workstation-side PowerShell (verbatim — orchestrator/executor runs this in the same PS session that issued Phase 5)

$startTime = Get-Date
$timeoutSec = 300
$pollIntervalSec = 5
$host = "95.46.211.230"
$port = 22

Write-Host "Waiting for $host`:$port to come back online after reboot..."
$elapsed = 0
$connected = $false
while ($elapsed -lt $timeoutSec) {
    $test = Test-NetConnection -ComputerName $host -Port $port -WarningAction SilentlyContinue
    if ($test.TcpTestSucceeded) {
        # Port is reachable, but sshd may not be ready yet — verify with an SSH probe
        $sshReady = $false
        try {
            $sshOut = ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@$host "echo SSH_OK && uname -r" 2>&1
            if ($LASTEXITCODE -eq 0 -and $sshOut -match "SSH_OK") {
                $sshReady = $true
                Write-Host "SSH ready after $elapsed seconds. uname -r output: $($sshOut | Select-Object -Last 1)"
            }
        } catch {
            # ssh not ready yet, keep polling
        }
        if ($sshReady) {
            $connected = $true
            break
        }
    }
    Start-Sleep -Seconds $pollIntervalSec
    $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
    if ($elapsed % 15 -eq 0) {
        Write-Host "  elapsed: $elapsed s / $timeoutSec s..."
    }
}

if (-not $connected) {
    Write-Host "TIMEOUT: host did not come back within $timeoutSec seconds." -ForegroundColor Red
    Write-Host "ACTION REQUIRED: Check pro-data.tech KVM console for boot state."
    Write-Host "If stuck, manual recovery: select 'Advanced options for Ubuntu' > '7.0.0-14-generic' in GRUB."
    exit 1
} else {
    Write-Host "Host reachable. Beginning Phase 7 verification." -ForegroundColor Green
}
```

**Verification (Phase 6):** PowerShell loop exits with `$connected = $true` within 300 s; `uname -r` reported on stdout (could be either the new `7.0.0-27-generic` if the new kernel booted, or `7.0.0-14-generic` if the host fell back to the previous kernel — either is acceptable; we just need sshd up).

---

### Phase 7 — Post-reboot verification (V01–V10)

All on-host checks run via the SSH session that's now restored. External check is the workstation TCP probe (already done in Phase 6 but reconfirmed).

```bash
# V01 — apt list upgradable should be empty (or only new security pulls since audit)
ssh pro-data-tech-qa 'apt list --upgradable 2>/dev/null'

# V02 — uname shows the new kernel
ssh pro-data-tech-qa 'uname -r'
# Expected: "7.0.0-27-generic" (or newer, if a further update has landed by execution time)

# V03 — /var/run/reboot-required does NOT exist
ssh pro-data-tech-qa 'test ! -f /var/run/reboot-required && echo V03_OK || echo V03_FAIL_still_present'
# Note: may still exist briefly if a sub-package set it; if V03 fails, check `cat /var/run/reboot-required` and judge.

# V04 — Postgres container is Up + healthy
ssh pro-data-tech-qa 'sudo docker ps --filter name=ai-qadam-test-db-1 --format "{{.Status}}"'
# Expected: contains "(healthy)"

# V05 — pg_isready from inside the container
ssh pro-data-tech-qa 'sudo docker exec ai-qadam-test-db-1 pg_isready -U aiqadam -d aiqadam_test'
# Expected: "127.0.0.1:5432 - accepting connections"

# V06 — core services active
ssh pro-data-tech-qa 'for s in ssh ufw fail2ban docker apparmor; do printf "%-12s " "$s"; systemctl is-active "$s"; done'

# V07 — workstation TCP probe (already done in Phase 6, but re-state)
Test-NetConnection -ComputerName 95.46.211.230 -Port 22 -WarningAction SilentlyContinue
# Expected: TcpTestSucceeded: True

# V08 — interactive SSH + sudo round-trip
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" root@95.46.211.230 'sudo -n true && echo SUDO_OK'
# Expected: SUDO_OK

# V09 — no error-grade lines about auditd/dhclient/networkd/snapd in the previous boot journal
ssh pro-data-tech-qa 'sudo journalctl --boot=-1 --priority=err --no-pager 2>&1 | grep -iE "auditd|dhclient|networkd|snapd" || echo V09_OK_no_known_issues'
# Expected: V09_OK_no_known_issues

# V10 — landscape frontmatter `kernel:` field updated
# This is a repo-side file change; the executor writes it to landscape/hosts/pro-data-tech-qa.md.
# (Reported back in the step-06 / step-07 handoff; applied at step-08.)
```

**Verification (Phase 7):** V01 returns empty (or only freshly-emerged `-security` entries since the last unattended-upgrades run). V02 = `7.0.0-27-generic` (or newer). V03 marker absent. V04 = `(healthy)`. V05 = `accepting connections`. V06: all six services `active`. V07: `TcpTestSucceeded: True`. V08: `SUDO_OK`. V09: no known-bad errors. V10: landscape file `kernel:` updated at step-08.

---

### Phase 8 — Failure handling

If V01–V06 fail: HALT and report. Do NOT auto-retry. Specifically:

- **V01 fails (`apt list --upgradable` shows packages):** Usually means a `-security` update landed during the upgrade window. Not a failure — log and re-run `apt full-upgrade -y` once. If still failing after one re-run, HALT.
- **V02 fails (`uname -r` shows old kernel):** GRUB fell back to the previous kernel. Investigate `/var/log/boot.log` and `journalctl -b` for boot errors. HALT.
- **V03 fails (`/var/run/reboot-required` still present):** A sub-package marked a reboot-required. Not catastrophic — the kernel DID upgrade (V02 confirms); the marker is for the next round. Log and continue.
- **V04 fails (container not `(healthy)`):** Wait up to 120 s more (Compose `unless-stopped` + Docker bring-up can lag). If still not healthy: `sudo docker logs ai-qadam-test-db-1 --tail 50` and `sudo docker inspect ai-qadam-test-db-1 --format '{{.State.Status}} {{.State.Health.Status}}'`. If the container is `Up` but health is `starting`: wait more. If `restarting` or `exited`: HALT and report.
- **V05 fails (pg_isready fails):** Same as V04 — Postgres may still be initializing (first boot after a kernel upgrade can trigger Postgres's `crash recovery`/`WAL replay`). Wait 60 s and retry once.
- **V06 fails (any service not active):** `systemctl status <service>` to diagnose. UFW and fail2ban reload fast; Docker usually self-recovers. sshd not active = HALT — host is now unreachable.
- **V07/V08 fail (network unreachable):** HALT. The 300-s polling budget is exhausted; ask user to check pro-data.tech KVM console.
- **V09 fails (errors in journal):** Investigate; not gating unless errors mention `auditd` kernel-module-load issues (would block T-0096).

If the host is reachable but the kernel did NOT switch to 7.0.0-27: the GRUB default may be stuck on the previous entry. Manual recovery: `ssh pro-data-tech-qa 'sudo grub-set-default "gnulinux-advanced-<UUID>>gnulinux-7.0.0-14-generic-advanced-<UUID>"' && sudo update-grub && sudo systemctl reboot`. Document and re-run Phase 5–7.

---

## Rollback

Apt full-upgrade + reboot is **partially reversible** for both code and data, with the following rollback paths:

### Rollback (A): Kernel — boot previous kernel via GRUB

If `7.0.0-27-generic` panics or fails to come back, the previous kernel `7.0.0-14-generic` remains installed (apt autoremove does NOT purge it during `full-upgrade`). Recovery path:

1. **Via GRUB menu** (pro-data.tech KVM console access required):
   - Connect to the KVM console at pro-data.tech control panel
   - Hold Shift / press ESC during boot to enter GRUB menu
   - Select **"Advanced options for Ubuntu" → "Ubuntu, with Linux 7.0.0-14-generic"**
   - Boot. sshd will start; host is once again reachable.
2. **Or via GRUB env (after sshd is reachable):**
   ```bash
   ssh pro-data-tech-qa 'sudo grub-set-default "Advanced options for Ubuntu>Ubuntu, with Linux 7.0.0-14-generic (recovery mode)" 2>/dev/null || sudo grub-set-default "1>2"  # depends on menu numbering; verify with grub-editenv list'
   ssh pro-data-tech-qa 'sudo update-grub && sudo systemctl reboot'
   ```
3. **Permanently revert** (if you decide to stay on the old kernel):
   ```bash
   ssh pro-data-tech-qa 'sudo apt-mark hold linux-image-generic linux-image-7.0.0-27-generic linux-base && sudo update-grub && sudo systemctl reboot'
   ```

### Rollback (B): Postgres data — restore from pg_dump

If `ai-qadam-test-db-1` is corrupted post-upgrade (extremely unlikely for a kernel upgrade alone, but the question is documented):

```bash
ssh pro-data-tech-qa 'sudo bash -c "
  set -a; source /var/www/ai-qadam-test/.env; set +a
  cd /tmp
  gunzip -c /var/backups/pre-T0099.*/ai-qadam-test.dump.gz > restore.dump
  docker exec -i -e PGPASSWORD=\"\$POSTGRES_PASSWORD\" ai-qadam-test-db-1 pg_restore -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" --clean --if-exists --no-owner --no-acl < restore.dump
  rm -f restore.dump
"'
```

### Rollback (C): Config files — restore from etc-snapshot

If `/etc/ssh`, `/etc/sudoers.d`, `/etc/fail2ban`, `/etc/ufw`, `/etc/default/ufw`, or `/etc/apt` regressed unexpectedly (also unlikely from an apt upgrade, but the snapshot is cheap insurance):

```bash
ssh pro-data-tech-qa 'sudo tar -xzf /var/backups/pre-T0099.*/etc-snapshot.tar.gz -C / && sudo systemctl reload ssh ufw fail2ban docker'
```

**No rollback possible for:** the `apt full-upgrade` itself (the new package versions are now on disk; reverting requires `apt install <pkg>=<old-version>` per package, which is non-trivial and not a single-command rollback). For an Ubuntu `-updates`-pocket meta-package set, this is acceptable — these are point-release fixes, not major-version changes.

---

## Verification (for step 07 — execution-validator)

### On-host (run via SSH after reboot)
- `apt list --upgradable` empty (or only `-security` items that emerged during the upgrade window — log these, do not retry) — V01
- `uname -r` shows `7.0.0-27-generic` (or newer) — V02
- `test ! -f /var/run/reboot-required` returns 0 — V03
- `docker ps --filter name=ai-qadam-test-db-1 --format '{{.Status}}'` includes `(healthy)` — V04
- `docker exec ai-qadam-test-db-1 pg_isready -U aiqadam -d aiqadam_test` returns `accepting connections` — V05
- `systemctl is-active ssh ufw fail2ban docker apparmor` all return `active` — V06
- `journalctl --boot=-1 --priority=err` has no error-grade lines about `auditd|dhclient|networkd|snapd` (regression check; we want a clean boot) — V09

### External (workstation side)
- `Test-NetConnection -ComputerName 95.46.211.230 -Port 22` → `TcpTestSucceeded: True` — V07
- `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" root@95.46.211.230 'sudo -n true && echo SUDO_OK'` → `SUDO_OK` — V08
- `landscape/hosts/pro-data-tech-qa.md` frontmatter `kernel:` field updated to `7.0.0-27-generic` (V10 — applied by step-08 landscape-updater, not here)

---

## Resources used

- **Secrets (by name):** none referenced directly. The plan reads `POSTGRES_PASSWORD` from `/var/www/ai-qadam-test/.env` (file mode 600) but never echoes or persists the value. The `pro-data.tech-qa-instance_rsa.ppk` key is referenced by path only (workstation-side SSH config) and never read.
- **Files modified on host:**
  - `/var/backups/pre-T0099.<ts>/ai-qadam-test.dump.gz` — created (pg_dump snapshot)
  - `/var/backups/pre-T0099.<ts>/pre-reboot-state.txt` — created (state capture)
  - `/var/backups/pre-T0099.<ts>/etc-snapshot.tar.gz` — created (config snapshot)
  - apt package database (state change: kernel + 8 other packages upgraded)
  - `/boot/vmlinuz-7.0.0-27-generic` and `/boot/initrd.img-7.0.0-27-generic` — created by apt
  - `/var/run/reboot-required` — created by apt, will be cleared after reboot into new kernel
- **Files modified in this repo (landscape/):** none by step-04 itself. Step-08 (landscape-updater) will update `landscape/hosts/pro-data-tech-qa.md` frontmatter `kernel:` field to `7.0.0-27-generic` and bump `last_verified:` to 2026-07-10.
- **External APIs called:** none (all host-local).

---

## Estimated impact

- **Downtime:** seconds-to-minutes. Specifically: SSH unreachable during reboot (typically 30–90 s on Ubuntu 26.04 cloud-image; budget 300 s in polling loop). Postgres container unreachable during the same window plus Docker bring-up (~5–15 s after sshd is up).
- **Affected services:** SSH (host management only, no public app behind it), Postgres `ai-qadam-test-db-1` (loopback-only, no external users depend on it today), Docker/containerd auto-restart, unattended-upgrades timers (stopped + restarted in Phase 2, brief gap of seconds).
- **Reversibility:** **partially reversible** (matches task's `estimated_reversibility: partial`). Apt package versions cannot be cleanly rolled back without per-package version pinning. The kernel can be rolled back via GRUB if `7.0.0-27` proves unstable. Postgres data is fully rollback-able via the `pg_dump` snapshot. Config files are fully rollback-able via the `etc-snapshot.tar.gz`.

---

## Issues / risks

- **Kernel boot failure on 7.0.0-27:** Low probability (Ubuntu LTS `-updates` pocket kernel is well-tested), but a hard failure would require KVM console access via pro-data.tech. Mitigated by: the previous kernel (7.0.0-14) remains installed as a GRUB fallback; pre-reboot state captured for diagnosis.
- **Container restart ordering:** Docker/containerd systemd dependencies should bring `ai-qadam-test-db-1` back automatically. If not, manual recovery: `sudo docker compose -f /var/www/ai-qadam-test/docker-compose.yml up -d`. pg_dump is the data safety net if the volume is corrupted (extremely unlikely from a kernel upgrade alone).
- **fail2ban `ignoreip` drift:** Workstation outbound IP is `178.89.57.135` per landscape; if changed since 2026-07-08, post-reboot SSH retries could trigger a brief ban. Phase 0 step 0.7 verifies this; if ignoreip is stale, Phase 7 step V06 fail2ban status will show 0 currently banned (acceptable).
- **unattended-upgrades race:** Stopped in Phase 2 step 2.1, restarted in step 2.5. Belt-and-braces — apt's own lock would block a true race anyway.
- **PowerShell `git push` false-negative:** Not applicable here — no git operations in this plan.
- **PowerShell `Test-NetConnection` quirks:** This plan's Phase 6 polling uses `Test-NetConnection` + `-WarningAction SilentlyContinue` to avoid spurious warnings; tested pattern from prior runs.
- **Polling-budget exhaustion:** 300 s may not be enough on a slow pro-data.tech control plane. If Phase 6 times out, the user must check the KVM console manually — the plan does NOT auto-recover from this state.
- **V10 (landscape file update) is a step-08 action:** Step-04 does NOT touch `landscape/`. This is correct per workflow routing; step-08 will apply the kernel field update after the executor's step-06 and validator's step-07 both pass.
- **Minor citation in T-0099 `Why` section:** attributes the ">14 days → P1" rule to `tasks/README.md`; correct source is `workflows/audit-host.md:323`. Cosmetic, not a blocker. Step-08 may fix this while editing the task to `done`.

---

## Open questions for user

None. The plan is concrete and the executor can proceed mechanically once approved. If the user wishes to override any of:

1. **Skip the `pg_dump`** (Phase 1) — acceptable per task file (not a hard acceptance criterion), but the data safety net is the only difference between "partial" and "one-way" for this run. Recommended to keep.
2. **Run `autoremove --purge` proactively in Phase 3** — landscape doesn't confirm `Remove-Unused-Dependencies: true`; manual autoremove in Phase 3.3 is conservative.
3. **Use the `tvolodi` operator path exclusively** (no `root@...` fallback) — feasible since T-0097 verified `tvolodi` has NOPASSWD sudo. The plan already uses `tvolodi` as the primary SSH user; `root@...` is only for V08 verification (workstation-side) to test the break-glass path.

…reply `MODIFY <changes>` along with the approval response.