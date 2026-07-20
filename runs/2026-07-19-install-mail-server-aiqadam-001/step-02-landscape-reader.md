---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-19T00:06:20Z
task_id: T-0117-install-mail-server-aiqadam
inputs_read:
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-01-task-reader.md
  - landscape/README.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/secrets-inventory.md
artifacts_changed: []
next_step_hint: step-03-task-validator should confirm the host-placement tradeoff (pro-data-tech-prod vs ubuntu-16gb-nbg1-1) is well-posed given the landscape facts below; step-04-solution-designer needs live DNSBL lookups and live port reachability probes before finalizing host choice — these are not in the landscape.
---

## Summary
Two viable host candidates exist for the new mail server, both currently clean of any mail workload: `pro-data-tech-prod` (95.46.211.224, 16 vCPU/31 GiB/336 GB free, hardened, already runs Penpot + AiQadam prod via Docker Compose, UFW allows only 22/80/443 today) and `ubuntu-16gb-nbg1-1` (46.225.239.60, 8 vCPU/~15 GiB/143 GB free, `role: unassigned`, sshd NOT hardened, no Docker/nginx installed, but sits behind an additional Hetzner Cloud Firewall currently scoped to SSH-only from the management workstation). `pro-data-tech-qa` (95.46.211.230) is ruled out — it's an active QA/test environment (AiQadam QA app + shared postgres), not a spare host, and was never proposed as a mail candidate. The `aiqadam.org` Cloudflare zone (33 records, shared/partially-owned) contains 22 dead mail-related records — A/CNAME/MX/SRV/TXT all pointing at or referencing `mail.aiqadam.org` = `212.20.151.29`, a third-party Uzbekistan-hosted platform host with no credentials in this repo — matching the task's Why section exactly. SPF (`v=spf1 ip4:212.20.151.29 mx -all`), DKIM (`mail._domainkey`), DMARC (`p=reject`), MTA-STS, and TLS-RPT records all currently reference the dead host/IP and will need updating or removal. No firewall rule anywhere in the landscape currently permits inbound 25/465/587/993 on either host candidate — those ports must be opened fresh regardless of which host is chosen.

## Details
### Relevant facts (sourced from landscape)

**Host candidate: pro-data-tech-prod (95.46.211.224)**
- 16 vCPU, ~31 GiB RAM (28 GiB free, no swap), 339 GB disk (336 GB free) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Hardened: sshd key-only, UFW active, fail2ban active, operator users provisioned; auditd NOT installed (gap #4); 12 pending package upgrades (gap #5) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Docker CE 29.6.1 + Compose v5.3.1 installed and active — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Two existing Compose projects: `penpot` (7 containers: frontend `0.0.0.0:9001`, postgres, valkey, exporter, mcp, mailcatch `127.0.0.1:1080`) and `aiqadam-prod` (3 containers: postgres `0.0.0.0:3114`/`[::]:3114` under `network_mode: host`, oidc-stub `127.0.0.1:9998`, api `127.0.0.1:3115`) — _source: `landscape/hosts/pro-data-tech-prod.md`, `landscape/services.md`_
- **UFW rules today: only 22/tcp, 80/tcp, 443/tcp ALLOW IN (v4+v6).** No provider-level (Hetzner-style) cloud firewall exists — pro-data.tech is a different provider with no Cloud Firewall analogue; UFW is the only network filter — _source: `landscape/hosts/pro-data-tech-prod.md`_
- nginx 1.28.3 active with two vhosts: `penpot.aiqadam.org` (port 9001 backend) and `aiqadam.org` (port 3115 backend, bare apex only) — both TLS via Let's Encrypt/certbot, auto-renewing — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Port 9001 (Penpot frontend) is bound to `0.0.0.0` via Docker's iptables bypass — externally reachable even though no explicit UFW rule allows it; note this precedent (Docker can bypass UFW's default-deny) is relevant when planning firewall isolation for a new mail Compose project on this same host — _source: `landscape/hosts/pro-data-tech-prod.md`_
- No mailcatch or any existing mail-related service beyond Penpot's internal dev/test mailcatcher (loopback-only, unrelated to production mail) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- No backups configured (no restic/borg/duplicity, no provider snapshots) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- `deploy` CI user exists (uid 999) for GitHub Actions deploys of the `aiqadam-prod` app — unrelated to mail, no action needed — _source: `landscape/hosts/pro-data-tech-prod.md`_

**Host candidate: ubuntu-16gb-nbg1-1 (46.225.239.60)**
- 8 vCPU, ~15 GiB RAM, 150 GB disk (143 GB free) — smaller than pro-data-tech-prod — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- `role: unassigned` — currently blank: no Docker, no nginx, no Compose projects, no application data — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- sshd is **NOT hardened**: `PermitRootLogin yes`, `PasswordAuthentication yes` (cloud-init defaults), no `AllowGroups` filter — hardening (T-0083 sibling) is an open follow-on, not yet a filed task — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- UFW active: deny-incoming default, allow 22/80/443 (v4+v6) — but 80/443 have no listener bound today (nothing served) — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- **Additional protection layer pro-data-tech-prod lacks:** Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`) applied at the cloud/network layer — currently a single rule, TCP 22 from the management workstation IP (`178.89.57.135/32`) only; all other inbound is dropped before reaching the host. This firewall would need new rules added (25/465/587/993 from `0.0.0.0/0`, or as broad as mail requires) if this host is chosen — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- fail2ban installed and active (sshd jail); auditd NOT installed — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- No DNS/Cloudflare presence for this host currently — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- No backups configured — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- Server protection flags enabled (`protection.delete=true`, `protection.rebuild=true`); no Hetzner Backups product enabled (project policy: local-disk only) — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_

**Host ruled out: pro-data-tech-qa (95.46.211.230)**
- Actively running the AiQadam QA app stack (`qa-uz.aiqadam.org`) plus the shared `ai-qadam-test-db-1` postgres (serves both `aiqadam_test` and `aiqadam_qa` databases) — this is a live test/staging environment for a different product, not a spare host, and was not raised as a mail candidate by the task or step 01 — _source: `landscape/hosts/pro-data-tech-qa.md`_
- UFW allows only 22/80/443; sshd hardened; no mail-related infrastructure present — confirms it is simply not in scope as a candidate, ruling it out on relevance grounds (wrong role, already committed to QA duty) rather than any technical blocker — _source: `landscape/hosts/pro-data-tech-qa.md`_

**Cloudflare `aiqadam.org` zone — DNS record inventory (33 records total, verified 2026-07-13)**
- Zone is shared/partially-owned: only 3 of 33 records are owned by this repo (`aiqadam.org` apex → `95.46.211.224`, `penpot.aiqadam.org` → `95.46.211.224`, `qa-uz.aiqadam.org` → `95.46.211.230`); the other 30 belong to an unrelated mail platform, a Coolify-style PaaS, Cloudflare Tunnels, and GitHub Pages — _source: `landscape/cloudflare.md`_
- **22 mail-related records, all confirmed stale/dead** (matches task's Why section):
  - `mail.aiqadam.org` A → `212.20.151.29` (unproxied)
  - `webmail.aiqadam.org` A → `212.20.151.29` (proxied)
  - `autoconfig.aiqadam.org`, `autodiscover.aiqadam.org`, `mta-sts.aiqadam.org`, `ua-auto-config.aiqadam.org` — CNAME → `mail.aiqadam.org`
  - `aiqadam.org` MX → `mail.aiqadam.org` (prio 10)
  - `send.aiqadam.org` MX → `feedback-smtp.ap-northeast-1.amazonses.com` (prio 10) — **this is the existing SES outbound integration** the task's Notes suggest considering for relay
  - SRV records: `_caldavs._tcp`, `_carddavs._tcp`, `_imaps._tcp` (port 993), `_jmap._tcp`, `_pop3s._tcp` (995), `_submissions._tcp` (465) — all target `mail.aiqadam.org`
  - TXT: `_dmarc.aiqadam.org` = `v=DMARC1; p=reject; rua=mailto:postmaster@aiqadam.org`; `_mta-sts.aiqadam.org` = `v=STSv1; id=...`; `_smtp._tls.aiqadam.org` = `v=TLSRPTv1; rua=mailto:postmaster@aiqadam.org`; `_ua-auto-config.aiqadam.org` = `v=UAAC1;...`; `mail.aiqadam.org` = `v=spf1 a -all`; `mail._domainkey.aiqadam.org` = DKIM RSA public key; `resend._domainkey.aiqadam.org` = DKIM key (Resend service, separate transactional integration); `send.aiqadam.org` = `v=spf1 include:amazonses.com ~all`
  - Also relevant but NOT in the mail-records table: the **apex SPF record** `aiqadam.org` TXT = `v=spf1 ip4:212.20.151.29 mx -all` (in the "core web" table, separate from the 22) — this is the record that must be updated to authorize the new mail host's sending IP
  - _source: `landscape/cloudflare.md`_
- **212.20.151.29 investigation (already done, 2026-07-13):** reverse DNS → `mail.aiqadam.org`; ASN AS213951 "Globe Cloud LLC", Tashkent, Uzbekistan; HTTP probe returns 302→`global.aiqadam.org` (undefined) then 503 — classic PaaS catch-all signature (Coolify-like); TLS cert `CN=aiqadam.org` only. Confirmed **not** `pro-data-tech-qa` or `pro-data-tech-prod` — an undocumented third-party host, no credentials exist in this repo. This matches and independently corroborates the task's claim that the old server is dead/unreachable — _source: `landscape/cloudflare.md`_
- Wildcard `*.aiqadam.org` A → `212.20.151.29` (proxied) is a **separate record** from the mail records and is NOT owned by this repo — untouched by any mail cutover plan; do not confuse with the mail A/MX records — _source: `landscape/cloudflare.md`_
- Zone editing precedent from T-0110/T-0111 (same class of operation the task's Notes reference): freshness-check immediately before each PATCH/POST/DELETE, scope every API call to one named record, full zone dump diff after to confirm no other record changed — _source: `landscape/cloudflare.md`_

**domains.md**
- `aiqadam.org` is `Managed by: this repo`; 3 subdomains currently documented (apex, penpot, qa-uz) with their TLS cert paths/expiries. No mail-related domain entries exist yet — mail.aiqadam.org (or a replacement hostname) and its cert will be new entries here — _source: `landscape/domains.md`_
- Notable app-level gotcha already documented: the app's tenant-routing middleware treats any exactly-2-character leftmost hostname label as a tenant code lookup and 400s if unregistered (caused the `qa` → `qa-uz` rename). Not directly relevant to a mail server (Stalwart/Mailcow, not the AiQadam app, will serve `mail.aiqadam.org`), but worth flagging in case `mail` or a candidate replacement hostname ever gets proxied through the same app — it does not, so this is very unlikely to bite, noted only for completeness — _source: `landscape/domains.md`_

**secrets-inventory.md**
- Existing secret-reference pattern to follow: name + description + storage location, no values. Cloudflare API token already exists (`cloudflare-ai-qadam-api-token`, Zone.DNS edit scope) and covers the `aiqadam.org` zone — no new Cloudflare credential needed for the DNS cutover portion of this task — _source: `landscape/secrets-inventory.md`_
- No mail-related secrets exist yet (DKIM private key, admin API token/password for Stalwart/Mailcow, etc.) — all will be new entries — _source: `landscape/secrets-inventory.md`_

### Stale or stub files encountered
None. All files read have `last_verified` dates between 2026-06-27 and 2026-07-17, all within 30 days of today (2026-07-19). None carry `status: stub` — `cloudflare.md` and `domains.md` are marked stub only in the (outdated) `landscape/README.md` index description; their own frontmatter shows `status: active` and both are fully populated with current data (verified 2026-07-13, well within freshness window). This is a drift between `README.md`'s file-index blurb and the actual file status — worth a note for landscape-updater at step 08, not a blocker here.

### Gaps requiring live discovery
- **DNSBL/blocklist status of both candidate IPs** (`95.46.211.224` and `46.225.239.60`) against Spamhaus, Barracuda, etc. — not in the landscape, must be checked live before host selection is finalized (task requirement).
- **Live reachability confirmation of the dead mail host** — the landscape's cloudflare.md investigation (2026-07-13) already probed `212.20.151.29` on HTTP; the task's Why section additionally cites 25/443/993 probes from 2026-07-18 (one day before this run) that are not recorded in any landscape file verbatim — the task file's own claim is the source of record here, landscape does not independently confirm the SMTP/IMAP port-level dead state, only the HTTP 302→503 behavior and DNS resolution.
- **Exact current package/version availability for Stalwart vs. Mailcow** and their Docker Compose resource footprints — not landscape data, needed at solution-design time.
- **pro-data.tech provider console details** (server type/plan tier, cost, exact datacenter location) remain "unknown" in both pro-data-tech host files — not needed for mail host placement decision but flagged as a standing gap in the landscape itself.
- **Whether any other party actively depends on the 22 dead mail records right now** (e.g., someone still polling IMAP from an old client) — landscape confirms the host is unreachable but cannot confirm zero external dependents; this is inherently a live/social question, not a file-discoverable one.
- **Current SES (`send.aiqadam.org`) integration's operational details** (is it actively used today for any transactional mail, what IAM/API credentials back it) beyond the DNS records themselves — the MX/SPF/DKIM records confirm the record shape exists, but no landscape file documents the SES integration's live usage or credentials, since it predates this repo's involvement in the zone.

## Issues / risks
- Both host candidates currently have zero firewall allowance for any mail port (25/465/587/993) — this is expected (mail was never planned for either host before) but confirms the executor will need to add UFW rules (and, if `ubuntu-16gb-nbg1-1` is chosen, Hetzner Cloud Firewall rules too — a second control plane the executor must not forget, since `pro-data-tech-prod`/`pro-data-tech-qa` have no such second layer).
- `pro-data-tech-prod`'s existing UFW rules are permissive-by-port, not source-restricted (22/80/443 ALLOW IN from Anywhere) — consistent with adding 25/465/587/993 the same way, but note Docker's demonstrated ability to bind `0.0.0.0` and bypass UFW's chain (seen with Penpot's port 9001 and aiqadam-prod's postgres 3114) — the solution-designer must ensure the new mail Compose project's ports are deliberately bound/published in a way that matches the intended UFW posture, not accidentally exposed beyond it.
- `ubuntu-16gb-nbg1-1` is unhardened (password auth still enabled, no AllowGroups) — if chosen, this task's blast radius arguably should include at least baseline sshd hardening before exposing it to internet-facing mail ports, since it would go from "isolated, SSH-only-from-one-IP" to "internet-facing on 4 new ports" in one step. This is a solution-design decision, not resolved here.
- The apex SPF TXT record (`v=spf1 ip4:212.20.151.29 mx -all`) is a single shared record separate from the 22-record mail block; it must also be updated as part of the cutover (task's "SPF updated to authorize new sending IP" requirement) — easy to miss since it lives in the "core web records" table in cloudflare.md, not the "mail records" table.
- `resend._domainkey.aiqadam.org` exists as a DKIM record for a service called "Resend" — a second transactional-email integration beyond SES, not mentioned in the task file. Its relevance (still in use? by whom?) is unknown from the landscape and should not be touched without understanding it; flagging so solution-designer doesn't assume the only non-Stalwart mail integration is SES.

## Open questions (optional)
none — landscape is current and sufficiently populated for the task-validator and solution-designer to proceed; live-discovery gaps above are normal for a design/build task and do not block progress, they are inputs the solution-designer and executor must gather at their own steps.
