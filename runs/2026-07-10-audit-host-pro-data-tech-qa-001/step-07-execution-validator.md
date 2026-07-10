---
run_id: 2026-07-10-audit-host-pro-data-tech-qa-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-10T02:35:00Z
inputs_read:
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-02-landscape-reader.md
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-06-executor-discovery.md
  - workflows/audit-host.md
  - tasks/_index.md
  - tasks/README.md
  - tasks/T-0027-check-kernel-upgrade.md
  - tasks/T-0044-docker-cap-drop-all.md
artifacts_changed: []
next_step_hint: landscape-updater (step 08) should create 2 new observation tasks — (1) kernel/reboot-required drift on pro-data-tech-qa, priority P2; (2) Postgres container hardening gap on pro-data-tech-qa, priority P2, referencing T-0044/T-0045 as precedent pattern. auditd (T-0096), backups (T-0098), and nginx-absent (T-0090a) findings are reconfirmations only — no new tasks, no task file edits needed (their History/Result sections are not touched by an audit re-confirmation per workflow guidance — only landscape last_verified + Change log row are updated). SUID cargo binaries are informational-only (confirmed benign via independent dpkg -S: package is sudo-rs, Ubuntu's official Rust sudo/su, and IS the active /usr/bin/sudo alternative) — do not create a task.
---

## Summary
End state verified: all 15 probes (A–O) ran read-only with no side effects, independent re-probing of the host reproduces the executor's reported output for pre-flight, kernel/reboot-required, SUID cargo binaries, container security flags, fail2ban, UFW, and listening ports; one executor risk framing is corrected (the `/usr/lib/cargo/bin/su`/`sudo` binaries are the distro-packaged `sudo-rs` alternative, confirmed informational-only via `dpkg -S`, not an open question), and one scoping error is caught (T-0027 is hetzner-prod-only and does NOT already-track the kernel/reboot-required drift found here, so that finding needs a new task rather than being folded into an existing one).

## Details

### On-host checks
| Check (from designer/workflow) | Command run | Result | Pass |
|---|---|---|---|
| Probe A returns SUDO_OK + recent date | `ssh root@95.46.211.230 'whoami && id && hostname && sudo -n true && echo SUDO_OK && date -u'` | `root` / `uid=0(root) gid=0(root) groups=0(root),1000(sshusers)` / `drkkrgm-qa-instance` / `SUDO_OK` / `Fri Jul 10 02:18:40 UTC 2026` — matches executor's reported output exactly (same hostname, same group membership; date is current, ~5 min after executor's run) | yes |
| Every probe A–O has an output entry in executor handoff | manual review of `step-06-executor-discovery.md` | All 15 probes A, B, C, D, E, F, G, H, I, J, K, L, M, N, O present with command, exit code, output, and side-effect note each | yes |
| No probe reported a side effect | manual review of each probe's "Side effects observed" line + Issues/risks section | All 15 probes state "none". The one re-run (probe E `grep -a`) is documented as a read-only display-mode correction, not an additional mutating action, and is called out explicitly by the executor | yes |
| Probe B: kernel/reboot-required independently reproduced | `ssh ... 'uname -r; test -f /var/run/reboot-required && cat /var/run/reboot-required /var/run/reboot-required.pkgs'` | `7.0.0-14-generic` running; `*** System restart required ***` with pending pkgs `linux-image-7.0.0-27-generic`, `linux-base` — matches executor exactly | yes |
| Probe B: pending-upgrade count independently reproduced | `sudo apt list --upgradable 2>/dev/null | tail -n +2 | wc -l` | `9` — matches executor's reported 9-package list exactly (same package names/versions) | yes |
| Probe J: SUID cargo binaries independently reproduced + provenance checked | `find /usr/lib/cargo/bin -perm -4000`, `dpkg -S /usr/lib/cargo/bin/su /usr/lib/cargo/bin/sudo`, `file ...`, `readlink -f /usr/bin/sudo` | `su`/`sudo` present, both owned by package **`sudo-rs`** (`ii sudo-rs 0.2.13-0ubuntu1`, "Rust-based sudo and su implementations" — official Ubuntu package). `/usr/bin/sudo` → `/etc/alternatives/sudo` → resolves to the cargo-bin `sudo-rs` binary, i.e. sudo-rs is the **active** system sudo, not a dormant duplicate | yes |
| Probe H: container security flags independently reproduced | `docker inspect --format 'User: ... Privileged: ... CapAdd: ... CapDrop: ... SecurityOpt: ... ReadonlyRoot: ...'` | `User: (empty) Privileged: false CapAdd: [] CapDrop: [] SecurityOpt: [] ReadonlyRoot: false` — matches executor exactly | yes |
| Probe E/G/F: fail2ban, UFW, listening ports independently reproduced | `fail2ban-client status sshd`, `ufw status verbose`, `ss -tlnp` | fail2ban: jail sshd active, total failed 261 (was 260 at executor's run ~20 min earlier — consistent monotonic increment from ongoing background scanning, not a discrepancy), total banned 52, 0 currently banned — matches. UFW: active, default deny incoming, only 22/tcp(+v6) allowed — matches. Listeners: only 22 on 0.0.0.0/::, Postgres/DNS/chrony loopback-only — matches | yes |

### External checks
Not applicable for this run. `audit-host` is a host-internal read-only probe workflow; per `workflows/audit-host.md` there are no external-facing checks defined for this host (probe O's Cloudflare-edge half is explicitly N/A since pro-data.tech has no Cloudflare fronting — confirmed by step 02 landscape-reader and reconfirmed by the executor). The only externally-observable surface for this host is SSH on port 22, which was exercised (successfully, as the transport for every probe above) rather than independently re-probed as a separate "external" check — re-running an unauthenticated external TCP probe against port 22 would add no information beyond what a successful SSH session already demonstrates.

### Resources-changed reconciliation
| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| (none — `artifacts_changed: []` in step-06 frontmatter, consistent with a read-only audit) | No files, configs, or running state changed on the host; independent re-probes show only natural counter drift (fail2ban total-failed 260→261, `Currently failed: 0`→`1`) consistent with continuous unattended internet background scanning, not an audit side effect | yes |

### Findings table

| Probe | Finding | Severity | Action |
|---|---|---|---|
| B | Kernel `7.0.0-14-generic` running while `7.0.0-27-generic` is installed/available and `/var/run/reboot-required` is set; landscape recorded "0 pending upgrades as of 2026-07-07" | **Drift**, severity medium (patch-currency fact, not a security control such as a firewall/sshd setting being violated; not flagged `-security` by apt, and reboot-required has been outstanding only ~3 days, well under the P1 "> 14 days" threshold) | **new-task**, priority P2 (real drift + reboot-required + newer kernel available warrants tracking sooner than P3 backlog, but is not yet urgent). Note: T-0027 (`check-kernel-upgrade`) does NOT already cover this — its `affects:` is `landscape/hosts/hetzner-prod.md` only, a different host. Do not treat as already-tracked. |
| C | sshd hardening (ciphers/KEX/MACs/AllowGroups/PermitRootLogin/etc.) exactly matches landscape and T-0093 | No drift | no-action |
| D | sudoers (4 NOPASSWD identities, mode-0440 drop-ins, visudo-valid) exactly matches landscape and T-0097 | No drift | no-action |
| E | fail2ban active, sshd jail enforcing, counters consistent with landscape | No drift | no-action |
| E | Continuous internet-background SSH brute-force scanning (multiple source IPs, common default usernames), all pre-auth rejections, already mitigated by fail2ban | Informational only (matches policy table's "many Failed password entries from the open internet that fail2ban already handled") | no-action |
| F, G, O | Only port 22/tcp publicly listening and UFW-allowed; all else loopback-only | No drift | no-action |
| G | UFW default-deny-incoming active; iptables/nftables consistent with UFW + Docker's injected chains | No drift | no-action |
| H | Postgres container `ai-qadam-test-db-1` runs with daemon-default apparmor+seccomp only — no container-level `User`, `CapDrop`, `SecurityOpt`, or `ReadonlyRootfs`; not privileged; loopback-only publish | **New risk**, P2 (not privileged/root-with-`Privileged:true`, which would be P1 — this is the "container hardening gap" tier, same class as T-0044/T-0045 on hetzner-prod, which are both P2) | **new-task**, priority P2, referencing [T-0044](../../tasks/T-0044-docker-cap-drop-all.md) and [T-0045](../../tasks/T-0045-docker-no-new-privileges.md) as the established pattern/precedent (their `affects:` is `landscape/services.md` scoped to hetzner-prod Compose files only — they do NOT cover `pro-data-tech-qa`/`ai-qadam-test`, so this is not a duplicate; it is a parallel observation for a different host). |
| I | nginx not installed | Reconfirms already-tracked [T-0090a](../../tasks/T-0090a-prepare-qadam-test-public-https-endpoint.md) | **already-tracked T-0090a** |
| J | No world-writable files on live host paths | No drift | no-action |
| J | SUID binaries include `/usr/lib/cargo/bin/su` and `/usr/lib/cargo/bin/sudo` in addition to standard `/usr/bin/*` set | **Informational only** — independently confirmed via `dpkg -S` that both are owned by the official Ubuntu package `sudo-rs` (0.2.13-0ubuntu1, "Rust-based sudo and su implementations"), and `/usr/bin/sudo` resolves through `/etc/alternatives/sudo` to this same binary — i.e. it is the distro's actively-used sudo implementation, not a rogue/duplicate/rustup artifact. Matches policy table's "SUID binary that's part of the distro" exactly. | no-action |
| J | `/etc/shadow`, `/etc/gshadow`, `/etc/sudoers` correctly permissioned | No drift | no-action |
| K | One `.env` file found, confirmed not world-readable, matches landscape | No drift | no-action |
| K | No stray private keys, no world-readable env files, no secret-pattern hits (no shell histories exist) | No drift | no-action |
| L | No custom cron/timers; reconfirms no app-level backup mechanism | Reconfirms already-tracked [T-0098](../../tasks/T-0098-host-level-backup-strategy-for-pro-data-tech-qa.md) | **already-tracked T-0098** |
| M | All listeners map to expected package-managed binaries; no failed systemd units | No drift | no-action |
| N | auditd not installed | Reconfirms already-tracked [T-0096](../../tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md) | **already-tracked T-0096** |
| N | AppArmor 180/104 vs landscape's 179/103 (2 days prior) | Negligible increment, not material drift | no-action |
| N | No rotated auth.log siblings yet alongside current 8.1MB file | Informational (logrotate.timer active and scheduled; no evidence of rotation failure) | no-action |
| O | Cloudflare cross-check N/A for this host (no Cloudflare fronting); host-only port-exposure matches expected set | No drift | no-action |

## Issues / risks
- None. All checks reproduce independently; no unaccounted side effects; no resources-changed mismatch (empty list, as expected for a read-only run).
- Executor correctly flagged the SUID cargo binaries as "warrants judgment" rather than asserting either verdict — independent `dpkg -S`/`readlink -f` checks now close that open question definitively as benign (sudo-rs, active alternative).
- Executor's `next_step_hint` and "Files this run will propose for landscape update" section left the kernel finding's task-assignment ambiguous ("new observation task... vs. broader state-changing follow-up") and did not check whether T-0027 already covered it. It does not — T-0027's `affects:` is hetzner-prod only. This validator's Findings table above resolves both: assign as a new P2 observation task (not a broader remediation task; the actual apply-and-reboot action is out of scope per the executor's own note, consistent with `audit-host` being read-only), and confirms no duplicate.

## Open questions (optional)
none
