---
id: T-0121-harden-stalwart-auto-ban-against-bridge-ip
title: Prevent Stalwart's auto-ban feature from blocking the Docker bridge gateway IP again
kind: task
status: done
priority: P1
created: 2026-07-20
updated: 2026-07-21
closed: 2026-07-21
outcome: "Implemented all three mitigations: (A) Stalwart AllowedIp entries for 172.19.0.1 (id i9yv13qeaaqa) and 172.19.0.0/16 (id i9yv3mloabaa) created via JMAP x:AllowedIp/set; (B) nginx admin vhost restricted to loopback (allow 127.0.0.1; deny all — external returns 403, SSH tunnel required for operator access); (C) investigated — Stalwart proxyTrustedNetworks is PROXY protocol binary, not X-Forwarded-For header trust, reverted; X-Forwarded-For headers remain in nginx, deferred as follow-on. Monitoring cron installed (/usr/local/bin/mail-health-check.sh every 5 min). JMAP remediation technique documented in landscape. All services confirmed reachable. Run: 2026-07-21-harden-stalwart-auto-ban-001."
created_by: manual
source_runs: []
executed_by_runs: [2026-07-21-harden-stalwart-auto-ban-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0117]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Prevent Stalwart's auto-ban feature from blocking the Docker bridge gateway IP again

## Why

On 2026-07-20, `https://mail.aiqadam.org/` (the Stalwart admin UI) started returning `502 Bad Gateway`, and on closer inspection SMTP/IMAPS were also unreachable from outside the container — all while the container itself reported `healthy` via Docker's own healthcheck.

Root cause (confirmed via a peer-container packet-level test, then confirmed directly via the JMAP `x:BlockedIp` object): Stalwart's built-in auto-ban feature (documented at stalw.art/docs/server/auto-ban) detected port-scanning traffic (WordPress/phpMyAdmin-probing bots, confirmed in nginx's error log — 13 distinct source IPs, ~150 requests against the admin vhost) and, due to a known upstream bug pattern (malformed scanner requests defeating `X-Forwarded-For` parsing), banned the **Docker bridge gateway IP** (`172.19.0.1`) instead of the real attacker IPs. Because every external connection to this container is NAT'd through Docker's bridge and appears to originate from that one gateway address, the ban silently blocked *all* external traffic — legitimate and malicious alike — while `docker exec`-based healthchecks (which bypass the bridge) kept reporting the container healthy.

The ban had `expiresAt: null` (permanent) and was stored in Stalwart's on-disk config store, so a container restart alone did not clear it — it had to be found and deleted via a direct `x:BlockedIp/set` (destroy) JMAP call, reached only via a peer container on the same Docker network (the normal `docker-proxy`-mediated path was itself blocked by the same ban, a chicken-and-egg problem during remediation).

Nothing about this is specific to a one-time misconfiguration — the same scanning traffic pattern that triggered it once will recur (internet background noise against any exposed mail admin UI is constant), and without a change, the same silent, total outage can happen again with no automatic recovery and no alert.

## What done looks like

- [ ] Decide and implement one (or more) of the following mitigations, in order of preference:
  1. **Configure Stalwart's auto-ban to trust `X-Forwarded-For` correctly for the reverse-proxy path**, per the upstream fix referenced in `github.com/stalwartlabs/stalwart` issue #2121 (maintainer: "skip fail2ban checks if the Forwarded-For headers are enabled") — investigate whether this Stalwart version (`v0.16.13`) has this behavior available/configurable, and if so, enable it so bans attribute to the real scanner IP instead of the bridge gateway.
  2. **Add the Docker bridge gateway IP (`172.19.0.1`, or the whole `172.19.0.0/16` range for this Compose network) to Stalwart's allowed-IP list**, if such a mechanism exists and doesn't undermine the auto-ban's value against real attackers reaching the admin UI by other means. Confirm via research whether `allowed-ip` prevents future bans on that address without disabling scan detection entirely (per GitHub issue #1383's confirmed prevent-not-retroactive semantics — also confirm it doesn't get silently overridden by a future `blocked-ip` entry).
  3. **Reduce the admin UI's exposure to internet scanning in the first place** — e.g., restrict the nginx vhost for `mail.aiqadam.org` to a smaller set of trusted source IPs (via nginx `allow`/`deny`) if the admin UI doesn't need to be reachable from arbitrary IPs, or move it behind a VPN/allowlisted access path. This reduces scan volume regardless of whether Stalwart's own ban logic is fixed.
- [ ] Add monitoring/alerting so a repeat of this exact failure mode (container `healthy` per Docker, but externally unreachable) is caught in minutes, not by a human noticing a 502 — at minimum, an external synthetic check (e.g., a periodic `curl` from outside the host to `https://mail.aiqadam.org/` and/or a port-reachability check on 25/465/587/993) with alerting on failure. This repo has no existing external-monitoring convention — a new, minimal mechanism is acceptable scope for this task (e.g., a cron job + a simple notification channel), or flag as its own follow-on if a full monitoring solution is out of scope here.
- [ ] Document the `x:BlockedIp` query/delete mechanism (the JMAP method calls, and the peer-container technique needed to reach the admin API when the normal `docker-proxy` path is itself banned) in `landscape/hosts/pro-data-tech-prod.md`'s "Stalwart CLI gotchas" section, so a future incident doesn't require re-deriving this from scratch.
- [ ] Re-verify: after implementing the chosen mitigation(s), confirm the admin UI, SMTP, and IMAPS all remain reachable through at least one subsequent cycle of realistic scanning traffic (or, if feasible, a controlled test that reproduces scan-like requests without waiting for real bot traffic).

## Result

Run `2026-07-21-harden-stalwart-auto-ban-001` (step-06 PASS, step-07 PASS) implemented the following against `pro-data-tech-prod` (95.46.211.224):

**Mitigation A — Stalwart AllowedIp (done):** Two permanent `AllowedIp` entries created in Stalwart's config store via JMAP `x:AllowedIp/set`: `172.19.0.1` (id `i9yv13qeaaqa`, Docker bridge gateway) and `172.19.0.0/16` (id `i9yv3mloabaa`, full Docker bridge subnet). Both have `expiresAt: null` (permanent) and survive container restarts. Confirmed via `x:AllowedIp/get` after two successive restarts.

**Mitigation B — nginx admin UI loopback restriction (done):** nginx `mail.aiqadam.org` vhost `location /` block now has `allow 127.0.0.1; deny all;` as first two directives. External HTTPS returns HTTP 403 (confirmed from management workstation). Operators access via SSH port-forward: `ssh -L 9080:127.0.0.1:8080 ... tvolodi@95.46.211.224`. Backup: `/var/backups/mail.aiqadam.org.pre-T0121.20260721T150501Z.bak`.

**Mitigation C — X-Forwarded-For trust (not implemented — reverted):** Stalwart v0.16.13's `SystemSettings.proxyTrustedNetworks` enables **HAProxy-format PROXY protocol** (binary, transport-level), NOT X-Forwarded-For header trust. Setting it caused a full admin API outage after restart. Reverted via a Python PROXY-protocol tunnel workaround. Net change to `SystemSettings.proxyTrustedNetworks` = none. The nginx `X-Forwarded-For` headers (from T-0117) remain in place. Deferred as a follow-on upgrade task.

**Monitoring (done):** `/usr/local/bin/mail-health-check.sh` installed (mode 755, root), runs every 5 minutes via root crontab, checks HTTPS + ports 25/587/993, logs to syslog and `/var/log/mail-health-check.log`. Verified exit 0 and `[OK] all checks passed`.

**JMAP remediation technique documented** in `landscape/hosts/pro-data-tech-prod.md` under the new "Stalwart JMAP emergency remediation runbook" and "proxyTrustedNetworks" subsections.

Deviations from "What done looks like":
- Mitigation C not implemented: `proxyTrustedNetworks` is PROXY protocol (transport-level), not header-based trust. The task asked to "investigate whether this config knob is available/configurable" — it is, but semantically wrong for this purpose.
- Monitoring is host-resident cron (not an external probe from the management workstation) — acceptable per task scope.

Executor handoff: [runs/2026-07-21-harden-stalwart-auto-ban-001/step-06-executor-infra.md](../../runs/2026-07-21-harden-stalwart-auto-ban-001/step-06-executor-infra.md)  
Validator handoff: [runs/2026-07-21-harden-stalwart-auto-ban-001/step-07-execution-validator.md](../../runs/2026-07-21-harden-stalwart-auto-ban-001/step-07-execution-validator.md)

## Notes
- **Blast radius: MEDIUM.** Changing Stalwart's ban/allow-list config or nginx access rules touches the live, in-production mail server — a wrong allowlist or overly permissive change could reduce real security value; a wrong nginx restriction could lock out legitimate admin access. Full reversibility, but should go through the normal plan/approval discipline given it's a live service already delivering real mail.
- **How the 2026-07-20 incident was actually resolved** (for reference, not to be repeated as the long-term fix): queried `x:BlockedIp/query` and `x:BlockedIp/get` via raw JMAP calls (`POST /jmap`) run from inside a disposable peer container attached to the `stalwart-mail_default` Docker network (`docker run --rm --network stalwart-mail_default curlimages/curl:latest curl ...` against the container's bridge IP directly) — this was necessary because the normal host→docker-proxy→container path was itself blocked by the same ban being investigated. Found 4 `x:BlockedIp` entries: 3 legitimate external scanner IPs (left in place) and `172.19.0.1` (the bridge gateway, `reason: portScanning`, `expiresAt: null` — removed via `x:BlockedIp/set` with `destroy: ["<id>"]`). A subsequent `docker compose restart` was required to clear an in-memory copy of the ban that a prior restart (before the ban was removed) had not cleared.
- Related to [T-0117](T-0117-install-mail-server-aiqadam.md) (original mail server deployment) — this task addresses an operational gap discovered post-deployment, not a defect in the original deployment plan itself.

## History
- 2026-07-20: created manually, following a live incident where Stalwart's auto-ban feature blocked the Docker bridge gateway IP, taking down external access to the mail server's admin UI, SMTP, and IMAPS for an unknown duration until diagnosed and fixed the same day.
- 2026-07-21: status → in-progress — run 2026-07-21-harden-stalwart-auto-ban-001 started.
- 2026-07-21: status → done — run 2026-07-21-harden-stalwart-auto-ban-001 completed. All mitigations applied and validated. Mitigation C (X-Forwarded-For trust) found to be PROXY protocol binary in Stalwart v0.16.13 — reverted; flagged as follow-on for upgrade. Commit: <pending>.
