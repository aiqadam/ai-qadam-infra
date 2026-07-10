---
run_id: 2026-07-10-audit-host-pro-data-tech-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-10T00:00:00Z
inputs_read:
  - runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-01-task-reader.md
  - workflows/audit-host.md
  - landscape/README.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/_index.md
artifacts_changed: []
next_step_hint: task-validator (step 03) can proceed — landscape is fresh (last_verified 2026-07-08, 2 days old) and richly populated. No discovery sub-run needed. Two already-open observation tasks (T-0096, T-0098) must be cross-referenced by step 07 to avoid duplicates; probe findings that reconfirm these should be marked already-tracked, not new.
---

## Summary
`pro-data-tech-qa` (95.46.211.230, pro-data.tech provider, role `ai-qadam-qa`) is a well-documented, actively-hardened host as of 2026-07-08: sshd is hardened (T-0093 done), UFW is active with a permissive 22/tcp-from-any rule (T-0094 done), fail2ban is active on the sshd jail (T-0095 done), three operator users exist with NOPASSWD sudo (T-0097 done), and Docker 29.6.1 runs a single healthy Postgres container (`ai-qadam-test-db-1`, pgvector/pg16, loopback-only 127.0.0.1:3112→5432). Two security gaps are already known and tracked as open observation tasks rather than new findings: auditd is not installed (T-0096, P3, deferrable) and no host-level or application-level backups exist (T-0098, P3, deferred until role stabilizes). nginx, the app container, and any public HTTPS endpoint are explicitly out of scope (deferred to T-0090a) — SSH (port 22) is the only public-internet-exposed service today. The landscape is fresh (2 days old) and gives the audit workflow a strong current-state baseline to check against.

## Details
### Relevant facts (sourced from landscape)

**Access / SSH:**
- sshd hardened 2026-07-08 (T-0093, 21/21 checks PASSED): `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PubkeyAuthentication yes`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`/`ClientAliveCountMax 2`, `AllowGroups sshusers`, `UseDNS no` — _source: `landscape/hosts/pro-data-tech-qa.md`_
- KEX/Ciphers/MACs tightened: no SHA-1 KEX, no 3DES/RC4/CBC ciphers, no hmac-sha1 MACs — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Three sshd drop-ins in `/etc/ssh/sshd_config.d/`: `40-disable-password.conf`, `40-ai-dala-infra.conf` (project-managed, sort first), `60-cloudimg-settings.conf` (stock cloud-init, still contains stale `PasswordAuthentication yes` but is overridden by first-wins semantics) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Root SSH: key-only via provider key (`rsa-key-20260707`, break-glass anchor), not in `sshusers` group, not gated by `AllowGroups` — _source: `landscape/hosts/pro-data-tech-qa.md`_
- `sshusers` group (gid 1000): `root`, `tvolodi` (uid 1001), `viktor_d` (uid 1002), `binali_r` (uid 1003) — all password-locked, key-only, NOPASSWD sudo via `/etc/sudoers.d/90-<user>` (mode 0440) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Sudo: passwordless for root via `/etc/sudoers.d/90-cloud-init-users` (cloud-init default) plus the three operator drop-ins — _source: `landscape/hosts/pro-data-tech-qa.md`_
- No other login-capable users beyond root + 3 operators + `nobody` (nologin) — _source: `landscape/hosts/pro-data-tech-qa.md`_

**Firewall / network:**
- UFW active (T-0094 done, 2026-07-08): `Default: deny (incoming), allow (outgoing), allow (routed)`; only inbound rule is 22/tcp (v4+v6) from any source, no source-IP allowlist (deliberate user decision — no Hetzner-Cloud-Firewall analogue exists on pro-data.tech) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- `DEFAULT_FORWARD_POLICY` flipped `DROP`→`ACCEPT` by T-0090 Phase A2 to allow Docker bridge forwarding (now matches sibling hosts `hetzner-prod`/`ubuntu-16gb-nbg1-1` convention) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- nftables present but empty (UFW uses iptables/ip6tables, not nftables) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Only public listener: 22/tcp (sshd). 127.0.0.1-only listeners: systemd-resolved (53), chronyd (323). No 80/443, no Docker-published ports beyond loopback 3112 — _source: `landscape/hosts/pro-data-tech-qa.md`_
- External TCP probe (2026-07-08) confirmed port 22 reachable, 80/443 closed (host up, no listener, default-deny would drop anyway) — _source: `landscape/hosts/pro-data-tech-qa.md`_

**fail2ban:** active 2026-07-08 (T-0095 done, 7/7 checks PASSED). sshd jail: `banaction=iptables-multiport` (chain `f2b-sshd`), `maxretry=3`, `findtime=600s`, `bantime=600s`, `ignoreip` includes `127.0.0.1/8 ::1` and mgmt workstation IP `178.89.57.135` — _source: `landscape/hosts/pro-data-tech-qa.md`_

**auditd:** **NOT installed.** Tracked as open observation task [T-0096](../../tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md), P3, deferrable per T-0088 precedent (Ubuntu 26.04 / kernel 7.x auditd compatibility issues) — _source: `landscape/hosts/pro-data-tech-qa.md`_

**AppArmor:** loaded, 179 profiles, 103 in enforce mode (stock Ubuntu 26.04 default) — _source: `landscape/hosts/pro-data-tech-qa.md`_

**Backups:** **none configured** — no application-level backup script/timer, no restic/borg/duplicity, no provider snapshots (policy: no paid provider add-ons). Tracked as open observation task [T-0098](../../tasks/T-0098-host-level-backup-strategy-for-pro-data-tech-qa.md), P3, deferred until role stabilizes further — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/README.md`_

**apt / patch posture:** 0 pending upgrades as of 2026-07-07 11:20 UTC (cloud-init bootstrap ran apt upgrade). unattended-upgrades active/enabled, daily cycle, security + ESM origins only — _source: `landscape/hosts/pro-data-tech-qa.md`_

**Docker / containers:**
- Docker 29.6.1 (build `8900f1d`), Compose plugin v5.3.1, containerd runtime — installed 2026-07-08 (T-0090 Phases A–E) — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`_
- Only container: `ai-qadam-test-db-1` (`pgvector/pgvector:pg16`), bound `127.0.0.1:3112`→`5432` (loopback only), healthcheck `pg_isready` (healthy), `unless-stopped`, named volume `ai-qadam-test_ai_qadam_test_pgdata`, db `aiqadam_test` / user `aiqadam`, env file `/var/www/ai-qadam-test/.env` mode 600 owner `tvolodi:tvolodi` — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`_
- App container NOT yet built/started; nginx NOT installed; UFW 443/tcp NOT opened; Cloudflare DNS NOT configured — all deferred to [T-0090a](../../tasks/T-0090a-prepare-qadam-test-public-https-endpoint.md) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Operator users `tvolodi`/`viktor_d`/`binali_r` are in the `docker` group (gid 986) — effectively root-equivalent per Docker's standard security model — _source: `landscape/hosts/pro-data-tech-qa.md`_

**Native systemd units of note:** `ssh`, `chrony`, `unattended-upgrades`, `qemu-guest-agent`, `cloud-init.*`, `snapd`, `apparmor`, `systemd-resolved`, `rsyslog`, `cron`, `polkit`, `dbus`, `multipathd`, `systemd-{journald,logind,networkd,udevd}`, `fwupd`, `udisks2`, `ModemManager`, `networkd-dispatcher`, `ufw` (active), `docker`, `fail2ban` (active). No `certbot`, no `app-backup.timer` — _source: `landscape/services.md`_

**Cron/scheduled tasks:** all per-user crontabs empty (root + 3 operators); only stock `/etc/cron.d/e2scrub_all`; stock daily/weekly cron scripts; ~19 stock systemd timers, no custom timers — _source: `landscape/services.md`_

**Cloudflare / DNS:** N/A for this host — pro-data.tech is not behind Cloudflare; no DNS presence in `landscape/cloudflare.md`/`landscape/domains.md` — _source: `landscape/hosts/pro-data-tech-qa.md`_

### Already-open task IDs affecting this host (for step 07 cross-reference — do NOT duplicate)

| Task | Title | Status | Priority |
|---|---|---|---|
| [T-0090a](../../tasks/T-0090a-prepare-qadam-test-public-https-endpoint.md) | Add nginx + Cloudflare + HTTPS for qadam-test.ai-dala.com (Phases F–I of T-0090) | observation | P2 |
| [T-0096](../../tasks/T-0096-enable-auditd-with-sane-ruleset-on-pro-data-tech-qa.md) | Enable auditd with sane ruleset (deferrable per T-0088) | observation | P3 |
| [T-0098](../../tasks/T-0098-host-level-backup-strategy-for-pro-data-tech-qa.md) | Host-level backup strategy (local-disk only, no off-site) | observation | P3 |

All other tasks referencing this host (T-0090, T-0093, T-0094, T-0095, T-0097) are `done`. If audit probes reconfirm auditd-absent or backups-absent, those findings must reference T-0096/T-0098 respectively — no new task should be created for those specific facts. If probes reconfirm nginx/app-container absence, that maps to T-0090a (already tracked, not a new finding).

### Stale or stub files encountered
None. `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md` both have `last_verified: 2026-07-08` (2 days old, well within the 30-day staleness threshold). Neither is `status: stub`.

### Gaps requiring live discovery
- **`landscape/secrets-inventory.md` does not exist in the working tree.** It is listed as a canonical landscape file in `landscape/README.md` but was scrubbed from git history and is now gitignored per T-0091 (rotate gitea admin pw / scrub secrets-inventory from git history, done 2026-07-08). I could not read it — no token/key names for this host are available from the landscape. This does not block the audit (probe K is a host-side secrets-on-disk scan that doesn't require the inventory file to execute), but the execution-validator will not be able to cross-reference discovered secrets against a "known secret names" list — treat any discovered credential file/env var as freshly assessed on its own merits.
- Provider-level firewall (pro-data.tech control-plane equivalent of Hetzner Cloud Firewall): landscape marks this **unknown** — not enumerable from in-host probes either. Audit probe O (Cloudflare-edge-vs-host sanity) is N/A for provider-firewall cross-check on this host since pro-data.tech has no Cloudflare fronting; this is expected, not a gap requiring escalation.
- Exact current banned-IP list, recent auth.log failure volume, and current `last`/`w` session state are point-in-time and will only be current as of live probe E execution — landscape's session/uptime snapshot (2026-07-08) is 2 days stale by definition for this kind of data, which is expected and not a landscape defect.
- SUID binaries, world-writable files, and secrets-on-disk (probes J/K) have never been enumerated for this host in the landscape — this is expected since `audit-host` (not `discovery-host`) is the first workflow to run these specific vulnerability probes here.

## Issues / risks
- None blocking. The landscape is current and detailed enough to support the audit without a discovery sub-run.
- Minor: the missing `secrets-inventory.md` (noted above) slightly narrows probe K's cross-referencing value but does not block any probe from executing.

## Open questions (optional)
none
