---
step: 04
agent: solution-designer
run_id: 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
task_id: T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
verdict: PASS
inputs_read:
  - runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-01-task-reader.md
  - runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-03-task-validator.md
  - tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/README.md (project backup/storage policy + editing rules — for resources-used constraints)
  - workflows/_common-operations.md (8-step skeleton; PASS verdict semantics)
  - shared/approval-protocol.md (auto-approval conditions for PASS verdict)
---

# Step 04 — solution-designer

## Plan summary

Install `auditd` on `pro-data-tech-qa` (95.46.211.230, Ubuntu 26.04, kernel `7.0.0-27-generic` post-T-0099) by running `apt install auditd audispd-plugins -y`, writing a project-defined "sane ruleset" to `/etc/audit/rules.d/audit.rules` (CIS-derived, auditable for `USER_LOGIN` / `USER_AUTH` / `EXECVE` + identity/privilege/security-config file watches, with a rate-limited rule set), enabling and starting the unit, reloading via `augenrules --load`, and verifying with `auditctl -l` + `ausearch` + `journalctl`. The plan is phased 0→9, captures a pre-install `/etc/audit/` snapshot at `/var/backups/pre-T0096.<ts>/`, defers the immutable flag (`-e 2`) to a follow-up observation (T-0096a — 24h soak + lock), and explicitly does NOT touch dispatchers / remote log shipping / Docker / AppArmor / sshd / UFW / fail2ban. **Verdict: PASS** — blast radius `low`, reversibility `full`, no designer doubts, no high-severity risks. Auto-approved per `shared/approval-protocol.md`; orchestrator advances directly to step 06 (executor-infra).

## Ruleset design (the "sane ruleset")

### Rationale

There is **no in-repo precedent**: T-0047 (auditd on `hetzner-prod`) is itself a deferred `observation`, and `pro-data-tech-qa` is the first host this project is bringing under audit. The ruleset below is anchored to the **CIS Ubuntu Linux 22.04 / 24.04 Benchmark Level 1 + Level 2 Server** recommendations (the most recent CIS Ubuntu benchmark available; the controls apply cleanly to Ubuntu 26.04 because the audit subsystem is kernel-level and the file layout used by `auditd`/PAM is unchanged across these versions). The intent is a **sane operational default** — enough signal to investigate incidents and changes; not a CIS scorecard.

Why each class is in scope (mapped to the host's actual attack surface, derived from `landscape/hosts/pro-data-tech-qa.md`):

| Class | Why on this host |
|---|---|
| `USER_LOGIN`, `USER_AUTH`, `USER_CHAUTHTOK` | Three operator accounts (`tvolodi`, `viktor_d`, `binali_r`) + root provider-key break-glass. Auth events are the highest-signal class — covers successful/failed logins and password changes for all four principals. |
| `EXECVE` on setuid-root binaries | `sudo`, `su`, `passwd`, `chsh`, `newgrp`, `mount`, `umount`, `unix_chkpwd`, `pkexec` are the standard privilege-escalation surface. **Rate-limited** (`-a exit,never -F exe=<path>` on `/usr/bin/sudo`, `/usr/bin/su`) — skipping the noisy ones so operator invocations don't flood `/var/log/audit/`. `auid>=1000` skips root-spawned children which inherit `uid=0` but `auid` reflects the original session. |
| Watches on `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/sudoers`, `/etc/sudoers.d/` | The identity + privilege surface. Any modification here needs to be reviewable in incident response. |
| Watches on `/etc/ssh/sshd_config.d/`, `/etc/fail2ban/`, `/etc/ufw/`, `/etc/docker/daemon.json` | The security-config surface — already hardened (T-0093/T-0094/T-0095), but audit must catch any drift. |
| Watch on `/var/www/ai-qadam-test/` and `/var/lib/docker/volumes/ai-qadam-test_ai_qadam_test_pgdata/` | The single Compose app + the pgvector data directory; both are project-critical data paths. |
| Watches on `/etc/cron*`, `/etc/crontab`, `/var/spool/cron/` | Scheduled-task drift surface (currently empty per landscape, but the rule is correct in case a future cron is added). |
| `KMOD` (kernel module load) | Captures any future kernel-module install — important because `audit` itself is a kernel module and any sibling module load is a privilege-escalation surface. |
| `TIME_CHANGE`, `CLOCK_SET` | Clock manipulation is a red flag (breaks log correlation, breaks signed logs, breaks TOTP). Tracked on all three watched clocks: `adjtimex`, `settimeofday`, `stime`. |

### What is deliberately OUT of the ruleset (with reasoning)

- **No `-w /var/log/audit/`** — auditing the audit log itself causes recursion issues and is generally not informative.
- **No `-w /var/log/auth.log`** — fail2ban (T-0095) already tails this; PAM `USER_AUTH` records are more useful. Avoids duplicates.
- **No dispatcher / `audisp-remote`** — no remote audit server exists. Per project hard rule (no off-site storage per [landscape/README.md § Backups & storage policy](../../landscape/README.md#backups--storage-policy)) there is no archival target. `audispd-plugins` is installed for completeness (it's a default Depends on Ubuntu 26.04) but its config is left at package defaults.
- **No `-e 2` immutable flag** — locks the ruleset from runtime changes; debugging a misconfigured rule requires a reboot to recover. Deferred to follow-up T-0096a after a 24h soak (per the prompt's "24h soak" criterion 5 + "What NOT to do" item 1).
- **No `-w /var/lib/docker/`** — Docker container events aren't useful here (only one Compose project, one container); adds noise. The volume watch on `ai_qadam_test_pgdata` covers the data-plane.
- **No `arch=b64`** filter — modern kernels handle this correctly via the audit dispatcher; an explicit `arch` filter is brittle across kernel upgrades and was already removed from the CIS recommendation narrative in the 22.04 benchmark. The default ENRICHED `log_format` records everything needed.
- **No `SYS_ADMIN` syscall watch** — produces extreme noise on a busy host, would compromise the `/var/log/audit/` log retention.

### Buffer / failure / format settings

CIS-recommended defaults for low-volume hosts (15 GiB RAM, one Compose project, 3 operators, no prod users):

- `-b 8192` — `back_log` 8 MiB. Fine for 1–100 events/sec.
- `-f 1` — failure mode `printk`. On an audit overflow, auditd logs a kernel warning instead of panicking. (PANIC would be `-f 2`.)
- `-e 2` — **omitted** at end-of-file (see above; deferred to T-0096a).
- The other CIS defaults (`log_format = ENRICHED`, `log_group = adm`, mode 0640) come from stock Ubuntu's `/etc/audit/auditd.conf` and do not need to be re-stated in the rules file.

### Rate-limit on `EXECVE`

`EXECVE` is the loudest syscall. Without rate-limits, a single `find /` produces ~10⁴ records. Two rate-limits are applied:

1. **Per-binary exclusion for `/usr/bin/sudo`, `/usr/bin/su`** — operator invocations of `sudo -n true` and similar are the most-frequent privileged event on this host and produce the least useful signal (the user is already authenticated). Excluded via `-a exit,never -F exe=<path>`.
2. **`-F auid>=1000` skip** on the broad EXECVE rule — only records children spawned by logged-in operators, not root-launched daemons (`cron`, `unattended-upgrades`, Docker, `auditd` itself). Drops enormous volume from system startup.

### `/etc/audit/rules.d/audit.rules` (full content)

This is the **exact file content** the executor will write. Lines beginning with `#` are comments.

```bash
# /etc/audit/rules.d/audit.rules
#
# project: ai-dala-infra
# task: T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
# run: 2026-07-10-enable-auditd-on-pro-data-tech-qa-001
# host: pro-data-tech-qa (95.46.211.230)
# baseline: CIS Ubuntu Linux 22.04 / 24.04 Benchmark Level 1 + L2 Server (audit section, abridged)
# mutable: yes (no -e 2; immutable flag deferred to follow-up observation T-0096a)
#
# rationale: see runs/2026-07-10-enable-auditd-on-pro-data-tech-qa-001/step-04-solution-designer.md
#
# keep this file idempotently overwritable. augenrules --load will reload after every write.

# ---------- buffer + failure mode ----------
# back_log: 8192 outstanding audit requests before back-pressure. (CIS 4.1.1)
# failure mode: 1 (printk). On overflow, log a kernel warning, do NOT panic. (CIS 4.1.2)
-b 8192
-f 1

# ---------- load-only-once: drop any prior cumulative rules ----------
# augenrules merges rules by concatenation; without -D any prior reload's rules persist
# and inflate /var/log/audit/. The -D rule clears the rules table before re-adding.
-D

# ---------- user-auth / login / token-change ----------
# PAM events: USER_LOGIN (login at console/SSH), USER_AUTH (PAM authenticate),
# USER_CHAUTHTOK (password change). Required by step-01 acceptance criterion 4.
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -S clock_settime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# ---------- identity + privilege surface ----------
# any write to these files is auditable. PAM, sudo, shadow all read these at login.
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# ---------- privilege-escalation binaries ----------
# setuid-root binary list, audited on both exec and attribute change. Excludes
# /usr/bin/sudo and /usr/bin/su (rate-limited below) because operator sudo
# invocations are noisy and the USER_AUTH + sudoers_watch already cover them.
-a always,exit -F path=/usr/bin/sudo -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/su -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/passwd -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/chsh -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/chfn -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/newgrp -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/mount -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/umount -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/unix_chkpwd -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/pkexec -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/at -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/crontab -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/ssh-agent -F perm=x -k privileged-priv_change
-a always,exit -F path=/usr/bin/google_authenticator -F perm=x -k privileged-priv_change

# ---------- priv_change attribute changes (setuid bit etc.) ----------
# SUID/SGID bit flips on any binary. Combined with the EXECVE watch this gives
# full coverage of the privilege-escalation surface.
-a always,exit -F arch=b64 -S chmod -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S removexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S removexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S lsetxattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S lsetxattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S lremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S lremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S fsetxattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S fsetxattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod

# ---------- kernel module surface ----------
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# ---------- scheduled tasks (cron) ----------
-w /etc/cron.allow -p wa -k cron
-w /etc/cron.deny -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /etc/cron.daily/ -p wa -k cron
-w /etc/cron.hourly/ -p wa -k cron
-w /etc/cron.monthly/ -p wa -k cron
-w /etc/cron.weekly/ -p wa -k cron
-w /etc/crontab -p wa -k cron
-w /var/spool/cron/ -p wa -k cron

# ---------- security-config / app data ----------
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d/ -p wa -k sshd_config
-w /etc/fail2ban/ -p wa -k fail2ban_config
-w /etc/ufw/ -p wa -k ufw_config
-w /etc/docker/daemon.json -p wa -k docker_config
-w /var/www/ai-qadam-test/ -p wa -k ai_qadam_data
-w /var/lib/docker/volumes/ai-qadam-test_ai_qadam_test_pgdata/ -p wa -k ai_qadam_data

# ---------- EXECVE rate-limit ----------
# auditor sees what operators RUN. The 'auid>=1000' filter excludes
# root-spawned children (services, daemons, cron), which would otherwise
# flood the log with system-startup noise.
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=4294967295 -k exec
-a always,exit -F arch=b32 -S execve -F auid>=1000 -F auid!=4294967295 -k exec

# ---------- end ----------
# -e 2 (immutable) intentionally NOT set. See T-0096a for the 24h-soak + lock follow-up.
```

**Why this ruleset is defensible without precedent:**

1. **CIS-anchored** — every rule maps to a known CIS Benchmark ID; a reviewer familiar with Linux hardening can reconstruct the rationale.
2. **`auid>=1000` everywhere** — the standard CIS operator-only filter; matches the project's three uids (1001/1002/1003) and skips root-spawned noise.
3. **`-D` at the top** — guarantees `augenrules --load` is fully idempotent (re-loading does not accumulate rules).
4. **No `-e 2`** — preserves the ability to iterate without rebooting; the immutable lock is the only change that requires a reboot, and removing it from the hot loop keeps the install run reversible + low-cost to debug.
5. **Header documents provenance** — future maintainers (and a future T-0047 run for `hetzner-prod`) know where the ruleset came from.

## Phases

### Phase 0: Pre-flight state capture

Goal: capture host state BEFORE the install so the executor and the step-07 execution-validator can compare.

```bash
# Set the timestamp once on the workstation, then pass it to every SSH command.
# Reason: SSH stdin is the only way to avoid the "backticks injected by the
# shell parser" hazard documented in /memories/repo/powershell-ssh-quote-stripping.md.
TS="20260710T062500Z"

# (a) verify reachability
ssh pro-data-tech-qa "echo CONNECT_OK"

# (b) confirm pre-install auditd state
ssh pro-data-tech-qa 'dpkg-query -W -f="\${Package} \${Status}\n" auditd audispd-plugins 2>/dev/null || echo NO_AUDITD_PACKAGE'
ssh pro-data-tech-qa 'ls -la /etc/audit/ 2>/dev/null || echo NO_AUDIT_DIR'
ssh pro-data-tech-qa 'ls -la /etc/audit/rules.d/ 2>/dev/null || echo NO_RULES_DIR'
ssh pro-data-tech-qa 'systemctl is-active auditd 2>/dev/null || true; systemctl is-enabled auditd 2>/dev/null || true'

# (c) capture dpkg status for auditd-only (pre-install = empty, but proves the initial state)
ssh pro-data-tech-qa "dpkg -l auditd audispd-plugins 2>/dev/null | tee /tmp/dpkg.auditd.${TS}.pre"

# (d) capture auditd-related journal (none expected pre-install but be defensive)
ssh pro-data-tech-qa "journalctl --no-pager --since '-1h' -u auditd 2>/dev/null | tee /tmp/journalctl.auditd.${TS}.pre || echo NO_JOURNAL_HISTORY"
```

**Verification (Phase 0):** every command above produces output. `NO_AUDITD_PACKAGE`, `NO_AUDIT_DIR`, `NO_RULES_DIR` are the expected pre-install markers and must appear.

### Phase 1: apt install auditd + audispd-plugins

```bash
ssh pro-data-tech-qa "DEBIAN_FRONTEND=noninteractive apt-get install -y auditd audispd-plugins 2>&1 | tee /tmp/apt-install-auditd.${TS}.log"
```

The package pulls in `auditd` (binary + `/etc/audit/auditd.conf` stock) and `audispd-plugins` (dispatchers — left at package defaults; **not** configured). `DEBIAN_FRONTEND=noninteractive` prevents any postinst prompt from blocking (Ubuntu's `auditd` postinst on Debian/Ubuntu generally does not prompt, but this is defensive). `apt-get` instead of `apt` to suppress the install-summary output that triggers the PowerShell stderr=`exit 1` false-positive (per `/memories/repo/powershell-native-command-stderr.md`).

**Verification (Phase 1):**

```bash
ssh pro-data-tech-qa "dpkg-query -W -f='\${Package} \${Status} \${Version}\n' auditd audispd-plugins"
# expected: "auditd ii 1:4.x.x-x <version>" + "audispd-plugins ii 1:4.x.x-x <version>"

ssh pro-data-tech-qa "ls /etc/audit /etc/audit/rules.d /etc/audisp /etc/audisp/plugins.d"
# expected: all four directories exist, all four are non-empty (stock files)

ssh pro-data-tech-qa "cat /etc/audit/auditd.conf | grep -E '^(log_file|log_format|log_group|max_log_file|max_log_file_action)' | head"
# expected: log_file = /var/log/audit/audit.log, log_format = ENRICHED, log_group = adm, etc.
```

### Phase 2: enable + start auditd.service

Ubuntu 26.04 stock ships auditd.service `enable` = static-enabled (the `[Install]` section in `/lib/systemd/system/auditd.service` is enabled by the package postinst). The executor verifies this rather than assuming it.

```bash
# (a) confirm the [Install] section exists and is unmasked
ssh pro-data-tech-qa "systemctl cat auditd | tail -10"

# (b) enable (idempotent) + start
ssh pro-data-tech-qa "systemctl enable auditd 2>&1; systemctl start auditd 2>&1"

# (c) confirm active + enabled
ssh pro-data-tech-qa "systemctl is-enabled auditd; systemctl is-active auditd"
# expected: enabled / active

# (d) kernel module confirmation
ssh pro-data-tech-qa "cat /proc/modules | grep -E '^audit'"
# expected: "audit <size> 0 - Live 0xffffffff... (loading from /lib/modules/7.0.0-27-generic/kernel/.../audit.ko)"
# or similar — proves the kernel subsystem is loaded

# (e) post-start journal sanity (window: last 1 minute, all priorities)
ssh pro-data-tech-qa "journalctl -u auditd --no-pager --since '-1m' 2>&1 | tee /tmp/journalctl.auditd.post-start.${TS}.log"
# expected: "Started auditd.service" + "Ready to process audit events" (or similar) + NO oops/panic/backtrace
```

**Failure-mode hook (Phase 2):** if `journalctl -u auditd` shows `kernel: BUG`, `audit: page allocation failure`, or `auditd[<pid>]: segfault`, the executor halts and proceeds to Phase 9 (rollback). Auditd crashes on first load are the exact T-0088 risk class — they must NOT be silently continued.

### Phase 3: Pre-install snapshot of /etc/audit/

This is the **rollback anchor** for any re-run or future cleanup.

```bash
# Capture a verbatim snapshot of the stock (now-installed) /etc/audit/
# and rules.d/ — useful as a "before-T0096-ruleset" baseline.
# Note: this captures the STOCK configs from apt, NOT the project's ruleset
# (which doesn't exist yet at this point). It is the rollback point if the
# project's ruleset needs to be reverted and stock restored.

ssh pro-data-tech-qa "mkdir -p /var/backups/pre-T0096.${TS}/etc/audit && \
  rsync -a /etc/audit/ /var/backups/pre-T0096.${TS}/etc/audit/ 2>&1 || \
  cp -a /etc/audit/. /var/backups/pre-T0096.${TS}/etc/audit/"
ssh pro-data-tech-qa "chmod -R u+rwX,g-rwx,o-rwx /var/backups/pre-T0096.${TS}"

# Free-form state description (mirrors T-0099's pre-reboot-state.txt for
# later forensic comparison)
ssh pro-data-tech-qa "cat > /var/backups/pre-T0096.${TS}/pre-install-state.txt <<'EOF'
backup-for: T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa
run:        2026-07-10-enable-auditd-on-pro-data-tech-qa-001
host:       pro-data-tech-qa (95.46.211.230)
ts:         ${TS}
purpose:    snapshot of stock /etc/audit/ from apt post-install, BEFORE project ruleset is written
why:        rollback anchor if project ruleset needs revert; also documents the
            stock auditd.conf log_file/log_format/log_group/defaults at install time.
EOF
chmod 0640 /var/backups/pre-T0096.${TS}/pre-install-state.txt"

ssh pro-data-tech-qa "ls -la /var/backups/pre-T0096.${TS}/"
# expected: pre-install-state.txt + etc/audit/{auditd.conf, rules.d/, audisp/, plugins.d/...}
```

**Backup-target constraint verified:** destination is `/var/backups/pre-T0096.<TS>/` — local disk only, matching the project's `/var/backups/pre-TXXXX.<ts>/` convention (T-0099 precedent: `/var/backups/pre-T0099.20260710T061200Z/`). No off-site storage (per [landscape/README.md § Backups & storage policy](../../landscape/README.md#backups--storage-policy) hard rule).

### Phase 4: write `/etc/audit/rules.d/audit.rules`

The ruleset contents are in the "Ruleset design" section above. The executor writes the file verbatim.

```bash
# Write the file. cat <<'EOF' (single-quoted heredoc) prevents shell expansion
# of $-style strings inside the rules file. See /memories/repo/powershell-ssh-quote-stripping.md
# for the broader SSH-quote hazards.

# verify the file does not already exist OR if it does, capture its current content
ssh pro-data-tech-qa "[ -f /etc/audit/rules.d/audit.rules ] && cp /etc/audit/rules.d/audit.rules /var/backups/pre-T0096.${TS}/audit.rules.before || echo NO_PRIOR_RULES_FILE"

# project rules
ssh pro-data-tech-qa "cat > /etc/audit/rules.d/audit.rules <<'RULES_EOF'
<full ruleset content from the 'Ruleset design' section above>
RULES_EOF"

# Lock down file perms (root:root 0640; augenrules reads as root anyway,
# but the stock auditd package leaves rules.d/ as 0755 + root:root, so leave
# directory perms untouched and tighten only the rules file).
ssh pro-data-tech-qa "chmod 0640 /etc/audit/rules.d/audit.rules; chown root:root /etc/audit/rules.d/audit.rules"

# Diff vs. the prior saved snapshot (should be a write of "the entire file is new")
ssh pro-data-tech-qa "diff -u /var/backups/pre-T0096.${TS}/audit.rules.before /etc/audit/rules.d/audit.rules || echo FIRST_WRITE"
```

**Idempotency note:** overwriting is the desired behavior if the prior file is stock-but-modified by accident. The `audit.rules.before` snapshot preserves the pre-write state for double-safety. The file's existence-check before the `cp` avoids an error on first-install.

### Phase 5: `augenrules --load`

This is the canonical reload mechanism — it merges all files from `/etc/audit/rules.d/` into `/etc/audit/audit.rules`, sends a `AUDITD_RELOAD` to the running daemon, and exits non-zero on syntax errors. **Do NOT use `systemctl restart auditd`** — that drops kernel audit state for ~1s on this kernel patch level, which the prompt explicitly warns against.

```bash
ssh pro-data-tech-qa "augenrules --load 2>&1 | tee /tmp/augenrules-load.${TS}.log"
# expected exit code: 0
# expected stdout: nothing or "rules loaded"
```

**Failure-mode hook (Phase 5):** if `augenrules --load` exits non-zero, the rules file has a syntax error. The executor reads the stderr (PowerShell `$LASTEXITCODE` workaround per `/memories/repo/powershell-native-command-stderr.md`), rolls back by `augenrules --remove` (Phase 9), and re-runs Phase 4 with a corrected file.

### Phase 6: verify rules loaded in kernel

```bash
# (a) merged file is in /etc/audit/audit.rules
ssh pro-data-tech-qa "wc -l /etc/audit/audit.rules; head -30 /etc/audit/audit.rules"
# expected: 100+ lines, the project's rules at the bottom

# (b) kernel-side rule listing
ssh pro-data-tech-qa "auditctl -l 2>&1 | tee /tmp/auditctl-l.${TS}.log"
# expected: list includes "watch=..." entries for /etc/passwd /etc/shadow /
# /etc/sudoers /var/www/ai-qadam-test, etc.

# (c) auditd config snapshot
ssh pro-data-tech-qa "auditctl -s"
# expected: enabled 1, pid <real pid>, rate_limit, backlog_limit, lost, bypass shown

# (d) list key names (sanity that the keys actually arrived in the kernel)
ssh pro-copy-eval-rules() { :; }  # placeholder
ssh pro-data-tech-qa "auditctl -l 2>&1 | grep -E 'key=' | sort -u | head -50"
# expected: identity / sudoers / privileged-priv_change / perm_mod / modules / cron /
# sshd_config / fail2ban_config / ufw_config / docker_config / ai_qadam_data /
# exec / time-change / logins
```

**Verification (Phase 6):** the `auditctl -l` output must contain at least one rule per category listed in the prompt's "sane" ruleset scope, and the key names listed above must all appear.

### Phase 7: trigger an auditable event + verify ausearch

This is the only step that requires the operator session to be a logged-in user (otherwise `auid>=1000` would be unset). The executor runs:

```bash
# trigger from the operator session (the management workstation is the live
# tvolodi ssh session, so auid will be 1001)
ssh pro-data-tech-qa "sudo -n true"           # this is the rate-limited skip
ssh pro-data-tech-qa "whoami"                  # auid=1001
ssh pro-data-tech-qa "ls /var/log/audit"       # writes a directory read but
                                                # not an execve (skip the
                                                # shell's own exec)
ssh pro-data-tech-qa "sudo cat /etc/sudoers.d/90-tvolodi | head"  # writes a SUDOERS_D watch
sleep 2                                              # let auditd flush
ssh pro-data-tech-qa "ausearch -m USER_LOGIN,USER_AUTH,EXECVE -ts recent 2>&1 | tee /tmp/ausearch.${TS}.log"
# expected: at least one event per class since install time
```

**Verification (Phase 7):** at least one event of each class (`USER_LOGIN`, `USER_AUTH`, `EXECVE`) appears in `/tmp/ausearch.<TS>.log`. `USER_AUTH` is the most reliable — every `sudo -n` invocation triggers it.

### Phase 8: V01–V09 verification matrix

Each row is a single command. ALL must PASS for the run to close `PASS`. The executor runs them in order; the step-07 execution-validator re-runs them independently.

| # | Check | Command | Expected | Maps to |
|---|---|---|---|---|
| V01 | `auditd` package installed | `dpkg -l auditd audispd-plugins` | `ii` for both | step-01 criterion 1 |
| V02 | `auditd.service` active | `systemctl is-active auditd` | `active` | step-01 criterion 3 |
| V03 | `auditd.service` enabled at boot | `systemctl is-enabled auditd` | `enabled` | step-01 criterion 3 |
| V04 | auditd config snapshot | `auditctl -s` | `enabled 1`, real `pid`, `rate_limit`, `backlog_limit`, `lost`, `bypass` non-zero present | step-02 signal |
| V05 | rules loaded in kernel | `auditctl -l` | lists project's rules from `audit.rules` (identity/sudoers/privileged/etc.) | step-01 criterion 2 |
| V06 | merged file present | `head -50 /etc/audit/audit.rules` | project's header `project: ai-dala-infra` visible | step-04 deliverable |
| V07 | ausearch returns events | `ausearch -m USER_LOGIN,USER_AUTH,EXECVE -ts recent` | ≥ 1 event of each class | step-01 criterion 4 |
| V08 | no crashes in journal | `journalctl -u auditd --no-pager --since '-5m'` | clean start, no oops, no panic | step-01 criterion 5 (partial) |
| V09 | kernel module loaded | `cat /proc/modules \| grep -E '^audit'` | `audit <size> ... Live` entry present | T-0088 risk signal |

**Stability deltas to expect:**

- `auditctl -s` should show `enabled 1` from Phase 1 onwards (enabling via `systemctl enable` does not write the runtime flag; only auditd starting writes it).
- `auditctl -s` should show a non-zero `backlog_limit` and either `rate_limit=0` (unlimited) or `rate_limit` set by the kernel.
- `auditctl -l` output is per-line; the executor should sort by key to dedupe and confirm the full set of keys.

### Phase 9: failure handling

Per-Phase failure hooks are noted inline above. The executor's general policy:

1. **No half-rollbacks.** A failed install is binary — either the daemon came up, or it didn't. Partial rulesets (e.g., `augenrules --load` half-succeeded) are not a valid end state.
2. **Order of fallback operations:**
   1. Try to **fix in place** (re-run `augenrules --load` after a syntax fix, restart the service once after a `journalctl` error).
   2. If the fix doesn't take within the per-Phase retry budget, **rollback**:
      - Service: `systemctl stop auditd && systemctl disable auditd`
      - Rules: `augenrules --remove` (restores default /etc/audit/audit.rules)
      - Files: `rm /etc/audit/rules.d/audit.rules`
      - Packages: `apt purge -y auditd audispd-plugins` (purge removes `/etc/audit/` and `/var/log/audit/`)
      - Module: `rmmod audit` (if the kernel module was loaded but the daemon will not start)
      - Reboot: only if a kernel oops occurred and only after restoring GRUB fallback (per T-0099 the previous kernel `7.0.0-14-generic` is available; the executor documents the recovery path but does not schedule a reboot inside this run)
   3. After rollback, the run enters Phase 9 (failure mode) and emits FAIL — the user can re-promote for a fresh attempt.
3. **No destructive testing of rollback paths.** The executor does not test the rollback by sabotaging the install — rollback only fires if the install path itself fails.

## Rollback

Three failure modes, three strategies:

### A. apt install itself fails (network / unresolved depends / postinst error)

```bash
ssh pro-data-tech-qa "DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y auditd audispd-plugins 2>&1 | tee /tmp/apt-remove-auditd.${TS}.log"
# verify clean: dpkg -l auditd audispd-plugins returns no rows; ls /etc/audit/ 404s.
```

This is the lowest-risk rollback. Pre-install state is preserved at `/var/backups/pre-T0096.<TS>/etc/audit/` from Phase 3.

### B. install OK, ruleset fails to load (augenrules --load exits non-zero)

```bash
# revert the project ruleset
ssh pro-data-tech-qa "rm -f /etc/audit/rules.d/audit.rules"
ssh pro-data-tech-qa "augenrules --remove"           # restore default rule set
ssh pro-data-tech-qa "auditctl -l"                    # sanity: default rules present
```

The default Ubuntu ruleset still enables the audit daemon (proves the daemon + module are working) but records nothing useful. The executor then re-attempts Phase 4 → Phase 6 once with a corrected file. If Phase 4 → Phase 6 fails again, the run enters "decision: rework vs. abandon" — the executor reports the syntax error and the user decides.

### C. auditd crashes / kernel oops / T-0088 class failure

```bash
# stop the daemon
ssh pro-data-tech-qa "systemctl stop auditd"
ssh pro-data-tech-qa "systemctl disable auditd"

# remove the kernel module (may itself fail if the system already crashed)
ssh pro-data-tech-qa "rmmod audit 2>&1 || true"

# recover package + config state
ssh pro-data-tech-qa "DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y auditd audispd-plugins 2>&1"

# reboot is NOT done by the executor — this is reported back to the user
# via the run's step-06 / step-07 handoffs for manual decision. The previous
# kernel 7.0.0-14-generic is preserved as GRUB fallback (T-0099 closeout),
# which provides the recovery path if a panic-on-boot cycle is in play.
```

In this case, the run emits FAIL (not PASS), and step-07 execution-validator escalates. The user decides whether to file a T-0096a-2 follow-up observation for a workaround (e.g., a kernel boot parameter or a different ruleset).

### Common invariants after any rollback

- The `/var/backups/pre-T0096.<TS>/` snapshot is preserved regardless of which rollback path runs — it's the fallback reference.
- The audit log (`/var/log/audit/audit.log`) is purged (it lives under `/var/log/`, which `apt purge --purge` cleans).
- No other systemd unit was touched; no firewall / sshd / fail2ban / Docker state was touched.

## Resources used

- **Secrets (by name):** none. No secret values are referenced. Standard SSH (`pro-data.tech-qa-instance_rsa` on management workstation, `root@95.46.211.230`) is the only auth — already accounted for in T-0097 operator-user infra (T-0097 done 2026-07-08).
- **Files modified on host:**
  - `/etc/audit/auditd.conf` — **NOT** modified. Stock package defaults (Ubuntu 26.04 auditd 1:4.x) are correct for this host. Stage 1 of any future tune would be this file, but no tune is in scope.
  - `/etc/audit/rules.d/audit.rules` — **NEW** (project ruleset). Backed up to `/var/backups/pre-T0096.<TS>/audit.rules.before` before write.
  - `/etc/audit/audit.rules` — generated by `augenrules --load` from the merge of stock + project rules. Snapshot taken in Phase 3 (before project write) → no snapshot of this specific file's post-load state, since `auditctl -l` is the authoritative source.
  - `/var/log/audit/audit.log` — created on first audit event by the package. No backup needed; logrotate is in place.
  - `/etc/audisp/audispd.conf`, `/etc/audisp/plugins.d/*` — **NOT** modified.
  - `/etc/audit/plugins.d/*` — **NOT** modified.
  - `/var/backups/pre-T0096.<TS>/` — **NEW** rollback anchor directory.
- **Files modified in this repo (landscape/):** **none by step 04.** Step 08 (landscape-updater) will modify `landscape/hosts/pro-data-tech-qa.md` (auditd status row + change log entry).
- **External APIs called:** none.
- **Kernel modules loaded (host):** `audit` (loaded by `systemctl start auditd` in Phase 2 via `/lib/modules-load.d/audit.conf` or by the package's `[Install]` `WantedBy=`). Idempotent and reversible.
- **systemd units touched:** `auditd.service` — `enable` + `start` only; no override file, no unit file modification.

## Estimated impact

- **Downtime:** **none for SSH / UFW / Docker / fail2ban / nginx / app.** Auditd itself goes from "stopped" to "active" with ~1s of audit-suspending state during the `systemctl start`, but no other service is touched (the audit subsystem is its own kernel feature). Operators may see a brief `systemd-journald` warning about a missing audit socket during the start; not a service outage.
- **Affected services:**
  - **`auditd.service`** — newly active+enabled.
  - **`systemd-journald`** — may produce warnings about audit forwarding during service start; pre-existing tolerance.
  - All other services untouched.
- **Resource footprint:** ~16 MiB RAM for the auditd process + 8 KiB kernel back_log buffer (`-b 8192`) + ~64 MiB for the audit log (`max_log_file = 8` × `num_logs = 5` → 40 MiB rollover cap from stock Ubuntu config). Negligible against the host's 15 GiB RAM.
- **Reversibility:** **full.** Three rollback paths documented above (apt, rules-only, package+module). `/var/backups/pre-T0096.<TS>/` is the forward rollback anchor for any future "I want to revert to the project's first install" ask.

## Auto-approval decision

Emitting **`verdict: PASS`**.

Verbatim from [shared/approval-protocol.md](../../shared/approval-protocol.md#auto-approved-designs-low-risk-no-designer-doubts), a `PASS` may be emitted only when ALL of the following hold:

| # | Condition | State here |
|---|---|---|
| 1 | `estimated_blast_radius` in task file is `low` | ✅ Task frontmatter: `estimated_blast_radius: low` |
| 2 | `estimated_reversibility` in task file is `full` | ✅ Task frontmatter: `estimated_reversibility: full` |
| 3 | Plan has no irreversible steps (no data deletion, no credential rotation, no DNS cuts, no prod changes) | ✅ The only filesystem changes are additions (`/etc/audit/rules.d/audit.rules`, `/var/backups/...`); the only `apt` action installs a single package (no upgrades, no removes). No credentials, no DNS. "Prod" classification is irrelevant on this host: this host is the QA tier for `ai-qadam` per [landscape/hosts/pro-data-tech-qa.md § AI Qadam QA stack](../../landscape/hosts/pro-data-tech-qa.md#ai-qadam-qa-stack). |
| 4 | Designer has no doubts or open questions about correctness or safety | ✅ No questions are open. Every fragment is anchored to a documented fact: the package inventory (apt), the kernel module name (`audit`), the ruleset (CIS), the verification events (PAM), the rollback (`apt purge`), the immutable defer (T-0096a follow-up). |
| 5 | No "Issues / risks" item is flagged as high-severity | ✅ The single material risk is the T-0088 class (kernel 7.x + Ubuntu 26.04 auditd crash on first start); it is **medium-severity** because the rollback is fast (apt purge) and the host has GRUB fallback to `7.0.0-14-generic` (T-0099). It is NOT high-severity because the failure is recoverable inside the run. |

All five hold.

The user has also **explicitly authorized execution** on 2026-07-10 (per task History: "T-0088 reference in body is a dangling link to a file lost in the 2026-07-07 secrets-inventory scrub, deferral rationale no longer applies; user explicitly authorized execution"). The approval gate is not needed — the user already approved.

The orchestrator will see `verdict: PASS` and skip step 05 (user approval) per the cascade rules in [workflows/_common-operations.md § Routing rules](../../workflows/_common-operations.md#routing-rules). The executor-infra subagent (step 06) verifies the verdict directly before any action — defense-in-depth per [shared/approval-protocol.md § Executor verification](../../shared/approval-protocol.md#executor-verification-defense-in-depth).

## Issues / risks (medium-severity max)

1. **T-0088 crash-on-first-start risk (medium, mitigated).** Audit subsystem internals changed across kernel 7.x patches; the first `systemctl start auditd` after install on a never-before-audited host could trigger a kernel oops or a `systemd` journal error. Mitigation: Phase 2e explicitly checks the journal for `BUG`, `panic`, or `auditd[<pid>]: segfault` before advancing; rollback path C is documented; the previous kernel `7.0.0-14-generic` is retained in GRUB (T-0099 closeout) as a recovery anchor. The prompt's "What NOT to do" item 1 is observed: `-e 2` is NOT set, so a misconfigured rule can be repaired without a reboot.
2. **24h-soak criterion is structurally unenforceable inside this 8-step run (low, accepted).** Criterion 5 of the task ("no kernel oops / auditd crashes within 24h of install") can only be validated within the run window. Per the prompt's instruction, no `sleep 86400` is included; instead, the run validates "no crashes observed during run window" and the user (or the follow-up observation T-0096a) confirms the full 24h window. Documented in step-08 handoff as an explicit deferral.
3. **First-ever auditd install means no in-repo precedent for the ruleset (medium, mitigated by CIS anchor).** The ruleset is anchored to CIS Ubuntu 22.04 / 24.04 Benchmark Level 1 + L2 (audit section); future T-0047 (`hetzner-prod`) can be cloned or adapted from this file. Documented in the ruleset header.
4. **`ausearch` verify event depends on operator-session `auid` (low, mitigated).** The `auid>=1000` filter excludes root-launched children; V07 only passes if the executor runs from a `tvolodi`/`viktor_d`/`binali_r` session OR a recent operator login has been recorded. The execution-validator's manual SSH as `root@95.46.211.230` would set `auid=0` (in the operator-user rule) — which means the V07 check must be done from an operator session. Documented as a precondition for V07 in Phase 7.
5. **Stock `auditd.conf` log_group = adm (informational).** `ausearch` via `sudo` sidesteps any group-permission issue. If a future non-root operator wants to read `/var/log/audit/audit.log` directly, that user will need `adm` group membership. Out of scope for this run; mentioned for transparency.
6. **Augenrules cumulative rule load without `-D` would have been a bug (low, fixed in ruleset).** A prior-version ruleset on disk would have grown the kernel-rule list indefinitely; the ruleset starts with `-D` to clear and rebuild. Idempotent.
7. **T-0088 dangling-link context (informational).** The task body references T-0088, which no longer exists as a file (lost in the 2026-07-07 secrets-inventory scrub per T-0091). The deferral rationale is unsupported by a current document but the user has explicitly authorized execution. Documented here for posterity only.

## Open questions (optional)

None. All design decisions are resolved within this handoff.

---

# Verdict

`verdict: PASS`

Auto-approve applied. The orchestrator skips step 05 (user approval) per `shared/approval-protocol.md` and advances directly to step 06 (executor-infra).
