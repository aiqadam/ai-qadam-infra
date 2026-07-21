---
run_id: 2026-07-21-harden-stalwart-auto-ban-001
step: "02"
agent: landscape-reader
verdict: PASS
created: 2026-07-21T00:00:00Z
task_id: T-0121-harden-stalwart-auto-ban-against-bridge-ip
inputs_read:
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-01-task-reader.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/secrets-inventory.md
artifacts_changed: []
next_step_hint: task-validator — validate that T-0121 acceptance criteria are achievable given the landscape gaps documented here; confirm scope of monitoring track (cron-based vs follow-on task)
---

## Summary

The production host `pro-data-tech-prod` (`95.46.211.224`) is active and hardened, running three Docker Compose stacks (Penpot, AiQadam prod, Stalwart mail) coexisting without conflict. Stalwart mail (`stalwartlabs/stalwart:v0.16`, Compose project `stalwart-mail` at `/opt/stalwart-mail/`) publishes SMTP/IMAPS/submission on ports 25/465/587/993 (UFW ALLOW IN) and exposes its admin/JMAP UI exclusively on `127.0.0.1:8080`, reverse-proxied by nginx at `https://mail.aiqadam.org/`. The 2026-07-20 auto-ban incident — where Stalwart permanently banned `172.19.0.1` (the `stalwart-mail_default` bridge gateway) for port-scanning, blocking all external mail access while Docker healthchecks stayed green — is confirmed in the landscape, along with the diagnosis and manual recovery procedure. No Stalwart auto-ban hardening (X-Forwarded-For trust, allowed-IP configuration) is documented, and no external monitoring exists for the mail server. The nginx vhost for `mail.aiqadam.org` is documented as proxying to `http://127.0.0.1:8080` with WebSocket upgrade headers and no IP-based access restrictions, but the exact proxy header set (including whether `X-Forwarded-For` is forwarded today) is not recorded in the landscape and requires live discovery. Relevant secrets are catalogued by name in `secrets-inventory.md`; all stored in `credentials.md` on the management workstation.

## Details

### Relevant facts (sourced from landscape)

#### Host baseline

- **Host:** `pro-data-tech-prod`, IP `95.46.211.224`, Ubuntu 26.04 LTS, kernel `7.0.0-14-generic` (2 minor versions behind QA), `status: hardened`. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **UFW:** ACTIVE, `default deny incoming`, rules ALLOW IN: 22/tcp, 80/tcp, 443/tcp, 25/tcp, 465/tcp, 587/tcp, 993/tcp (v4+v6). No provider-level firewall. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **fail2ban:** ACTIVE, sshd jail only (`bantime=1h`, `findtime=10m`, `maxretry=5`, `ignoreip=127.0.0.1/8 ::1`). No Stalwart-specific jail configured. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Docker:** CE 29.6.1, Compose plugin v5.3.1. UFW coexistence block in `/etc/ufw/after.rules` (DOCKER-USER + MASQUERADE for `172.16.0.0/12`). — _source: `landscape/hosts/pro-data-tech-prod.md`_

#### Running Compose stacks

- **`penpot`** at `/opt/penpot/` — 7 containers (penpot-frontend, penpot-backend, penpot-exporter, penpot-mcp, penpot-postgres, penpot-valkey, penpot-mailcatch). Frontend bound `0.0.0.0:9001`. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **`aiqadam-prod`** at `/opt/apps/aiqadam-prod/deploy/` — 4 containers (postgres-1 on `0.0.0.0:3114` host-net, oidc-stub-1 on `127.0.0.1:9998`, api-1 on `127.0.0.1:3115`, web-next-1). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **`stalwart-mail`** at `/opt/stalwart-mail/` — 1 container (`stalwart-mail-server-1`), `healthy`. — _source: `landscape/hosts/pro-data-tech-prod.md`_

#### Stalwart mail server

- **Image:** `stalwartlabs/stalwart:v0.16` (pinned tag; exact patch version not recorded in landscape). UID 2000. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Ports:** 25/tcp, 465/tcp, 587/tcp, 993/tcp (public, UFW ALLOW IN); `127.0.0.1:8080/tcp` (admin/JMAP UI, loopback-only, reverse-proxied by nginx). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Bind mounts:** `var-lib-stalwart` (RocksDB data + on-disk config store, under `/opt/stalwart-mail/`), `etc-stalwart` (bootstrap config, under `/opt/stalwart-mail/`). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **`stalwart-cli`:** installed at `/home/tvolodi/.cargo/bin/stalwart-cli` (separate from the server image, installed via `cargo install`). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Auto-ban (confirmed incident):** Stalwart has a built-in auto-ban feature. On 2026-07-20, it permanently banned `172.19.0.1` (the `stalwart-mail_default` Docker bridge gateway IP, `reason: portScanning`, `expiresAt: null`) instead of the real scanner IPs. Because all external connections are NAT'd through this one gateway address, the ban silently blocked ALL external traffic while `docker exec`-based healthchecks reported the container healthy. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Auto-ban configuration:** NOT documented in landscape. No X-Forwarded-For trust settings, no `allowed-ip`/`trusted-ip` config knobs are described anywhere in the landscape files. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Allowed-IP list:** NOT documented. No pre-existing `allowed-ip` or equivalent entries confirmed in the landscape. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Docker network:** Compose project `stalwart-mail` → network `stalwart-mail_default`. Bridge gateway confirmed as `172.19.0.1` from the incident record. The container's own bridge IP (needed for peer-container JMAP calls) is not recorded in the landscape. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Current `x:BlockedIp` state:** at the time of manual recovery (2026-07-20), 3 legitimate external-scanner bans were left in place after deleting the `172.19.0.1` bridge-gateway entry. The current live state of this list is unknown and requires live discovery. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **After a ban is deleted, a `docker compose restart` is also required** to clear an in-memory copy Stalwart holds independently of the on-disk config store. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Domain object:** `aiqadam.org` (id `b`), `dnsManagement: Automatic` scoped to `publishRecords: {tlsa:true}` only, `certificateManagement: Automatic` (Let's Encrypt DNS-01, `acmeProviderId: i9noabxeabab`). — _source: `landscape/hosts/pro-data-tech-prod.md`_

#### nginx vhost for `mail.aiqadam.org` (admin UI)

- **Vhost file:** `/etc/nginx/sites-available/mail.aiqadam.org` (symlinked to `sites-enabled/`). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Config (documented):** HTTP→HTTPS redirect on port 80; HTTPS on port 443 proxying `/` → `http://127.0.0.1:8080`; WebSocket upgrade headers present. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **X-Forwarded-For:** NOT documented. The landscape records WebSocket upgrade headers but does not mention `proxy_set_header X-Forwarded-For`, `proxy_set_header X-Real-IP`, or any real-IP passthrough directive. Whether these headers are present today must be confirmed via live discovery. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **IP-based access restrictions:** NOT present. No `allow`/`deny` directives are documented for this vhost. The admin UI is currently accessible from any IP that reaches port 443. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **TLS:** Let's Encrypt cert (ECDSA, expires 2026-10-17), auto-renewing via `certbot.timer`. Independent of Stalwart's own internal-ACME cert used for SMTP/IMAP/submission. — _source: `landscape/hosts/pro-data-tech-prod.md`_

#### Monitoring

- **No external monitoring exists** for the mail server or any other service on this host. The Docker healthcheck (`healthy`) was confirmed to mask the 2026-07-20 total-outage scenario. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **No monitoring infrastructure** exists anywhere in this repo (no cron checks, no alerting channels, no external probes). — _source: `landscape/services.md`_

#### Relevant secrets (names only — no values)

- `stalwart-mail-admin-password` — Admin credential for Stalwart CLI/web UI `admin` account. Stored: `credentials.md`. — _source: `landscape/secrets-inventory.md`_
- `stalwart-mail-domain-admin-password` — Domain-level admin credential for `aiqadam.org` Stalwart `Domain` object. Stored: `credentials.md`. — _source: `landscape/secrets-inventory.md`_
- `stalwart-mail-test-account-password` — Password for `test@aiqadam.org` (id `e`). Stored: `credentials.md`. — _source: `landscape/secrets-inventory.md`_
- `stalwart-mail-postmaster-password` — Password for `postmaster@aiqadam.org` (id `f`). Stored: `credentials.md`. — _source: `landscape/secrets-inventory.md`_
- `cloudflare-ai-qadam-api-token` — Used by Stalwart's `DnsServer` object for its own ACME DNS-01 challenges. Not directly needed for T-0121 mitigations, but noted since Stalwart has standing write access to the Cloudflare zone. Stored: `credentials.md`. — _source: `landscape/secrets-inventory.md`_

### Stale or stub files encountered

- None. All three landscape files are fresh:
  - `landscape/hosts/pro-data-tech-prod.md` — `last_verified: 2026-07-20` (1 day ago), `status: hardened`
  - `landscape/services.md` — `last_verified: 2026-07-19` (2 days ago), `status: populated`
  - `landscape/secrets-inventory.md` — no `last_verified` frontmatter (static inventory, not time-bound)

### Gaps requiring live discovery

1. **Stalwart auto-ban configuration** — No config details are in the landscape: what Stalwart v0.16 config knob (if any) controls X-Forwarded-For trust in auto-ban decisions; whether the fix for GitHub issue #2121 is present in this image tag; whether an `allowed-ip`/`trusted-ip` config primitive exists and its exact JMAP/Bootstrap syntax. Needs: Stalwart upstream docs + changelog for `v0.16` + raw schema inspection on the live container (`GET /api/schema`).
2. **Exact Stalwart patch version** — The image is tagged `stalwartlabs/stalwart:v0.16` (floating minor tag). The exact patch version (`v0.16.x`) running in the container is unknown. Needs: `docker exec stalwart-mail-server-1 stalwart --version` or equivalent.
3. **nginx vhost `mail.aiqadam.org` — X-Forwarded-For header presence** — The landscape does not record whether the vhost passes `X-Forwarded-For` or `X-Real-IP` to the Stalwart backend. This is central to mitigation track 1 (X-Forwarded-For trust fix). Needs: `cat /etc/nginx/sites-available/mail.aiqadam.org` on the host.
4. **Current `x:BlockedIp` list** — 3 legitimate external bans were left in place during the 2026-07-20 recovery; their current state (still present, any new ones added since) is unknown. Needs: JMAP `x:BlockedIp/query` + `x:BlockedIp/get` via `stalwart-cli` or curl.
5. **Stalwart container's bridge IP on `stalwart-mail_default`** — Known: gateway is `172.19.0.1`. The container's own IP on this network is not recorded; needed if a peer-container workaround is required during execution. Needs: `docker inspect stalwart-mail-server-1` or `docker network inspect stalwart-mail_default`.
6. **Stalwart Bootstrap config at `/opt/stalwart-mail/etc-stalwart/`** — The landscape records that bind-mount exists but does not document its current content. Understanding the bootstrap config structure is needed before proposing config-file changes (mitigation track 1/2). Needs: `ls /opt/stalwart-mail/etc-stalwart/` on the host.
7. **Notification channel for external monitoring** — No alerting channel (email, webhook, PagerDuty, etc.) is configured or documented in this repo. The solution-designer must decide whether to implement a minimal cron check (and if so, to what endpoint) or file a follow-on task.

## Issues / risks

- **No external monitoring:** Any monitoring that relies solely on Docker healthchecks or `docker exec` will replicate the exact blind spot that masked the 2026-07-20 outage. The external check must originate from outside the host (e.g., a curl from the management workstation hitting `https://mail.aiqadam.org/` and ports 25/465/587/993).
- **`allowed-ip` semantics uncertainty:** Task step-01 notes (from GitHub issue #1383) that `allowed-ip` may not retroactively remove existing bans and could be silently overridden by a later `blocked-ip` entry. This risk must be confirmed or denied against Stalwart v0.16 before relying on this mitigation alone.
- **Floating image tag `v0.16`:** The Compose file pins to `v0.16`, a minor-version tag that could silently receive patch updates on the next `docker pull` + restart. The exact running patch version is unknown. If the X-Forwarded-For trust bug is only fixed in a specific patch, the executor needs to know the current running version before deciding whether an image upgrade is required.
- **Blast radius MEDIUM:** Changes touch a live production mail server actively delivering real mail for `aiqadam.org`. Approval gate is required before execution.
- **docker compose restart required after config change:** Any config change applied via `stalwart-cli` (Bootstrap update or JMAP set) that modifies auto-ban behavior requires a container restart to take effect — this will cause a brief interruption to mail service (SMTP/IMAP/submission) during the maintenance window.
- **Penpot and AiQadam prod coexistence:** Both stacks are healthy on this host. Any operation that requires host-level firewall changes (e.g., `ufw reload`) must not disrupt their traffic; the executor must include a no-regression check for those stacks per this host's established pattern.
