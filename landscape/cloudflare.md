---
name: cloudflare
last_verified: 2026-07-19
status: active
last_verified_note: 2026-07-19 (T-0117) — self-hosted Stalwart mail server deployed for aiqadam.org; mail-records section reclassified from "NOT managed by this repo" to "managed by this repo" (A/MX/SPF/DKIM/DMARC repointed to 95.46.211.224; 10 stale third-party records deleted across two executor passes: webmail A, mta-sts CNAME+TXT, ua-auto-config CNAME+TXT, caldavs/carddavs/pop3s SRV, then autoconfig/autodiscover CNAMEs in a follow-up validator-caught cleanup); 20 new self-managed TLSA records + 1 `_acme-challenge` TXT record now present, maintained on an ongoing basis by Stalwart's own scoped `dnsManagement: Automatic` (publishRecords: {tlsa:true}). Zone now 46 records. Prior note: 2026-07-19 — discovered via a T-0117 pre-cutover zone-diff safety check that 2 new records exist that predate and are unrelated to T-0117 — qa.aiqadam.org (A, 95.46.211.230, "migrated from qa-uz") and auth.qa.aiqadam.org (A, 95.46.211.230, "pro-data-tech-qa Authentik") — both created 2026-07-18T04:40 UTC by separate, user-confirmed-expected QA/Authentik work not tracked by any task file in this repo. Prior note: T-0111 done 2026-07-13 — repointed the aiqadam.org apex A record (record ID bf1113199732117bd147ebd87d6e356d, unchanged) from 212.20.151.29 (third-party host) to 95.46.211.224 (pro-data-tech-prod), proxied true→false. Prior note: T-0110 done 2026-07-13 — added qa-uz.aiqadam.org A record (record ID 53aa89ca061e343291f33bb7b8b3a12e) for the AiQadam QA host.
---

# Cloudflare

## Zones managed

### aiqadam.org

- **Zone ID:** `bec8854d698d56ff17cf917367634100` (reference only — value in [`secrets-inventory.md`](./secrets-inventory.md))
- **Account ID:** see [`secrets-inventory.md`](./secrets-inventory.md) (`cloudflare-ai-qadam-account-id`)
- **API Token:** see [`secrets-inventory.md`](./secrets-inventory.md) (`cloudflare-ai-qadam-api-token`)
- **Live record count (verified 2026-07-19 via `GET /zones/<zone-id>/dns_records`):** **46 records** (35 documented pre-T-0117 baseline [33 original + `qa.aiqadam.org` + `auth.qa.aiqadam.org`, discovered 2026-07-19] − 10 stale mail records deleted by T-0117 + 20 new self-managed TLSA records + 1 new self-managed `_acme-challenge.aiqadam.org` TXT record — see "Record count reconciliation" below). This zone is **shared, heavily-used infrastructure** — it is not exclusive to this repo's Penpot/AiQadam deployments. As of T-0117, **4** of the 46 records (`aiqadam.org` apex, `penpot.aiqadam.org`, `qa-uz.aiqadam.org`, plus the now-repo-owned mail records described below) are actually managed/owned by this repo; the remaining records belong to an unrelated Coolify-style hosting platform, Cloudflare Tunnels, GitHub Pages sites, and the separately-discovered QA/Authentik records, none of which are documented elsewhere in this repo's landscape except where noted. Treat any new record creation or modification in this zone as **shared-resource surgery**, not greenfield.

#### Core web records (apex / wildcard / this repo's records)

| Name | Type | Value | Proxied | TTL | Record ID | Purpose | Owner / Task |
|---|---|---|---|---|---|---|---|
| **aiqadam.org** | **A** | **95.46.211.224** | **false** | 1 (auto) | `bf1113199732117bd147ebd87d6e356d` | **Apex domain — AiQadam prod API, owned by this repo (repointed from the third-party host below, T-0111).** Proxies via nginx to `127.0.0.1:3115` (`aiqadam-prod-api-1`) on `pro-data-tech-prod`. | **T-0111 / this repo** |
| `*`.aiqadam.org | A | 212.20.151.29 | true | 1 (auto) | `c13cf65703dd761c6f54437554b84f24` | Wildcard — catches **any** subdomain without its own explicit record; still points at the third-party host (see "212.20.151.29 investigation" below) — unaffected by the apex repoint (distinct record) | **unknown / not this repo** |
| aiqadam.org | CAA | `0 issue "letsencrypt.org"` | false | 1 (auto) | `4d4c6a48ccb1578b8d7f23509945ffd1` | Restricts cert issuance to Let's Encrypt (zone-wide) | shared |
| aiqadam.org | TXT | `v=spf1 ip4:95.46.211.224 mx -all` | false | 300 | `066b056e1fe89b972dca640a1164e64d` | SPF for apex mail sending — repointed T-0117 (2026-07-19) from the dead third-party host (`212.20.151.29`) to authorize the new Stalwart mail server's sending IP | **T-0117 / this repo** |
| **penpot.aiqadam.org** | **A** | **95.46.211.224** | **false** | 1 (auto) | `fde29338774531998ae38c41cd2e28ad` | **Penpot design tool — owned by this repo** | **T-0107 / this repo** |
| **qa-uz.aiqadam.org** | **A** | **95.46.211.230** | **false** | 1 (auto) | `53aa89ca061e343291f33bb7b8b3a12e` | **AiQadam QA app host — owned by this repo.** Named `qa-uz` (not `qa`) to route around an app-level tenant-parsing 400 — see [`domains.md`](./domains.md) for detail. | **T-0110 / this repo** |
| qa.aiqadam.org | A | 95.46.211.230 | false | 1 (auto) | (not captured — discovered, not created, by this repo) | **Recreated by separate, out-of-band QA/Authentik work (not this repo's T-0110 record, which was deleted).** Comment on record: "migrated from qa-uz". Discovered 2026-07-19 via a T-0117 pre-cutover zone-diff safety check, created 2026-07-18T04:40 UTC. User-confirmed expected 2026-07-19; not tracked by any task file in this repo. | discovered, not this repo |
| auth.qa.aiqadam.org | A | 95.46.211.230 | false | 1 (auto) | (not captured — discovered, not created, by this repo) | **Authentik (or similar) auth service on pro-data-tech-qa.** Comment on record: "pro-data-tech-qa Authentik". Discovered 2026-07-19 via a T-0117 pre-cutover zone-diff safety check, created 2026-07-18T04:40 UTC. User-confirmed expected 2026-07-19; not tracked by any task file or documented as a service in this repo. | discovered, not this repo |

#### Mail records (Stalwart mail server — managed by this repo, T-0117, 2026-07-19)

The prior third-party mail platform (`mail.aiqadam.org` = `212.20.151.29`, Globe Cloud LLC/Uzbekistan, unreachable on 25/443/993) is retired. `aiqadam.org` mail now routes to the self-hosted Stalwart server on `pro-data-tech-prod` (`95.46.211.224`) — see [`hosts/pro-data-tech-prod.md`](hosts/pro-data-tech-prod.md#stalwart-mail) for the full server-side configuration.

| Name | Type | Value | Proxied | TTL | Owner / Task |
|---|---|---|---|---|---|
| mail.aiqadam.org | A | **95.46.211.224** | false | 300 | **T-0117 / this repo** (repointed from `212.20.151.29`) |
| aiqadam.org | MX | mail.aiqadam.org (prio 10) | false | 300 | **T-0117 / this repo** (target unchanged; now resolves to the new host via the A-record repoint) |
| send.aiqadam.org | MX | feedback-smtp.ap-northeast-1.amazonses.com (prio 10) | false | 3600 | shared (SES, untouched) |
| _imaps._tcp.aiqadam.org | SRV | `1 993 mail.aiqadam.org` | false | 300 | **T-0117 / this repo** (retained, target now resolves correctly) |
| _jmap._tcp.aiqadam.org | SRV | `1 443 mail.aiqadam.org` | false | 300 | **T-0117 / this repo** (retained) |
| _submissions._tcp.aiqadam.org | SRV | `1 465 mail.aiqadam.org` | false | 300 | **T-0117 / this repo** (retained) |
| _dmarc.aiqadam.org | TXT | `v=DMARC1; p=none; rua=mailto:postmaster@aiqadam.org` | false | 300 | **T-0117 / this repo** (changed from `p=reject`; soak-period decision, see Notes) |
| _smtp._tls.aiqadam.org | TXT | `v=TLSRPTv1; rua=mailto:postmaster@aiqadam.org` | false | 300 | **T-0117 / this repo** (retained, unchanged) |
| mail.aiqadam.org | TXT | `v=spf1 a -all` | false | 300 | **T-0117 / this repo** (retained, unchanged) |
| mail._domainkey.aiqadam.org | TXT | `v=DKIM1; k=ed25519; p=ZNYJ+HqL+Ag+30oz7g36DqQ2qNqubS8bW4q7aaUGnk0=` | false | 300 | **T-0117 / this repo** (new Ed25519 keypair, replacing the old RSA key) |
| resend._domainkey.aiqadam.org | TXT | DKIM public key (Resend service) | false | 3600 | shared (Resend, untouched) |
| send.aiqadam.org | TXT | `v=spf1 include:amazonses.com ~all` | false | 3600 | shared (SES, untouched) |

**Deleted stale records (10 total, dead third-party host cleanup):**

| Name | Type | Deleted | Notes |
|---|---|---|---|
| webmail.aiqadam.org | A | T-0117, 2026-07-19 | pointed at the dead host; no webmail product stood up this pass |
| mta-sts.aiqadam.org | CNAME | T-0117, 2026-07-19 | MTA-STS not implemented in this deployment |
| ua-auto-config.aiqadam.org | CNAME | T-0117, 2026-07-19 | |
| _mta-sts.aiqadam.org | TXT | T-0117, 2026-07-19 | paired with the CNAME above |
| _ua-auto-config.aiqadam.org | TXT | T-0117, 2026-07-19 | paired with the CNAME above |
| _caldavs._tcp.aiqadam.org | SRV | T-0117, 2026-07-19 | CalDAV not served by this deployment |
| _carddavs._tcp.aiqadam.org | SRV | T-0117, 2026-07-19 | CardDAV not served by this deployment |
| _pop3s._tcp.aiqadam.org | SRV | T-0117, 2026-07-19 | POP3S not served by this deployment |
| autoconfig.aiqadam.org | CNAME | T-0117, 2026-07-19 (follow-up cleanup pass, after validator review) | had no working nginx/Stalwart route behind it; deleted rather than left orphaned |
| autodiscover.aiqadam.org | CNAME | T-0117, 2026-07-19 (follow-up cleanup pass, after validator review) | same reason as `autoconfig` above |

**Self-managed, ongoing records (not one-time facts — expected to churn):**

Stalwart's `Domain` object holds `dnsManagement: Automatic`, scoped via `publishRecords: {"tlsa": true}` (see [`hosts/pro-data-tech-prod.md`](hosts/pro-data-tech-prod.md#stalwart-mail) for the full reasoning behind this scoping decision — it was a deliberate choice to avoid granting Stalwart standing write access to MX/SPF/DKIM/DMARC/etc.). As a result, the zone contains:

- **20 TLSA records** (roughly 4 per mail-related hostname), self-published and self-renewed by Stalwart as part of its internal-ACME TLS lifecycle.
- **1 `_acme-challenge.aiqadam.org` TXT record**, Stalwart's own ephemeral ACME DNS-01 challenge record, published/rotated automatically during certificate renewal.

These are **ongoing, self-managed churn** — their exact count/content may fluctuate slightly across renewal cycles and this is expected, not drift to investigate. They are not individually itemized in the tables above; treat "20 TLSA + 1 `_acme-challenge`" as the standing expected footprint contributed by Stalwart's own DNS automation, separate from the explicit executor-managed records listed above.

- **12 records total in the explicit (non-self-managed) mail-records category above** (11 retained/changed + 0 net-new beyond the DKIM/DMARC/SPF/A/MX changes — deletions listed separately). Confirms a fully operational self-hosted mail stack (Stalwart mail server: SMTP/IMAP/submission, DKIM/DMARC/SPF) plus the pre-existing, untouched transactional-email integrations via Amazon SES (`send.aiqadam.org`) and Resend (`resend._domainkey`).

#### Tunnel / static-site records (not managed by this repo)

| Name | Type | Value | Proxied | Purpose |
|---|---|---|---|---|
| blaster.aiqadam.org | CNAME | `89c00d9b-f39c-48b1-9e0e-57206ac047d9.cfargotunnel.com` | true | Cloudflare Tunnel (cloudflared) — live, HTTP 302 confirmed 2026-07-13 |
| events-test.aiqadam.org | CNAME | `8f11816f-f756-4056-99d5-4a998641c588.cfargotunnel.com` | true | Cloudflare Tunnel (cloudflared) — live, HTTP 200 confirmed 2026-07-13 |
| brand.aiqadam.org | CNAME | aiqadam.github.io | false | GitHub Pages — live, HTTP 200 confirmed 2026-07-13 |
| build.aiqadam.org | CNAME | aiqadam.github.io | false | GitHub Pages — live, HTTP 200 confirmed 2026-07-13 |
| flow.aiqadam.org | CNAME | aiqadam.github.io | false | GitHub Pages — live, HTTP 200 confirmed 2026-07-13 |

- These 5 records are all independently live and in active use (verified by direct HTTPS probe 2026-07-13). None reference any host in this repo's scope (`pro-data-tech-qa`, `pro-data-tech-prod`, `ubuntu-16gb-nbg1-1`).

### Record count reconciliation

22 (mail) + 5 (tunnel/pages) + 6 (core web: apex A, wildcard A, CAA, apex SPF TXT, penpot A, qa-uz A) = **33**. Matches the live API `count`/`total_count` as of 2026-07-13 post-T-0110 (independently reconfirmed by [step-07 execution-validator](../runs/2026-07-13-setup-aiqadam-qa-infra-001/step-07-execution-validator.md) via a full 33-record zone dump: 31 pre-existing non-`qa`-named records unchanged + `qa-uz.aiqadam.org` added + the old `qa.aiqadam.org` record — created and deleted within the same run — confirmed absent). **T-0111 (2026-07-13, later the same day) updated the pre-existing apex `aiqadam.org` A record in place (content + proxied only, same record ID) — total count remains 33; the other 32 records (including `qa-uz.aiqadam.org` and the wildcard) confirmed byte-for-byte unchanged by [step-07 execution-validator](../runs/2026-07-13-setup-aiqadam-prod-infra-001/step-07-execution-validator.md) via a full zone dump.**

**2026-07-19 pre-cutover update:** 33 (as above) + 2 (`qa.aiqadam.org`, `auth.qa.aiqadam.org` — separate, out-of-band, user-confirmed-expected QA/Authentik work, created 2026-07-18, not tracked by any task file in this repo) = **35**. Discovered via a full zone dump run as a pre-cutover safety check for T-0117 (install-mail-server); all 33 previously-documented records confirmed byte-for-byte unchanged at that time.

**2026-07-19 post-T-0117 update (final):** 35 (pre-cutover baseline) − 8 (first deletion pass: `webmail.aiqadam.org` A, `mta-sts.aiqadam.org` CNAME, `ua-auto-config.aiqadam.org` CNAME, `_mta-sts.aiqadam.org` TXT, `_ua-auto-config.aiqadam.org` TXT, `_caldavs._tcp` SRV, `_carddavs._tcp` SRV, `_pop3s._tcp` SRV) + 20 (self-managed TLSA records, Stalwart's `publishRecords: {tlsa:true}` scope) + 1 (self-managed `_acme-challenge.aiqadam.org` TXT) = 48 → − 2 (second deletion pass: `autoconfig.aiqadam.org` CNAME, `autodiscover.aiqadam.org` CNAME, deleted in a follow-up executor attempt after the validator flagged them as orphaned) = **46 records**. Confirmed via a full zone dump (`count:46, total_count:46`) both by the executor (before/after diff showing zero mismatches among the 46 common records) and independently re-confirmed by [step-07 execution-validator](../runs/2026-07-19-install-mail-server-aiqadam-001/step-07-execution-validator.md), which additionally confirmed via `modified_on` timestamp sort that no record in the zone outside T-0117's own deliberate changes was touched. The A/MX/SPF/DKIM/DMARC content changes and record deletions/additions above are the only differences from the 2026-07-19 pre-cutover 35-record baseline; `resend._domainkey`, `send.aiqadam.org` MX/TXT (SES), the wildcard, and all 5 tunnel/GitHub-Pages records remain byte-for-byte unchanged throughout.

## Investigation: what is 212.20.151.29?

Performed 2026-07-13 as part of this run's landscape-refresh sub-step, triggered by executor-infra (step-06 of run `2026-07-13-setup-aiqadam-qa-infra-001`) halting BLOCKED when a pre-flight idempotency check found `qa.aiqadam.org` unexpectedly resolving.

- **Not pro-data-tech-qa** (`95.46.211.230`) and **not pro-data-tech-prod** (`95.46.211.224`) — confirmed by direct comparison, this is a third, previously-undocumented IP.
- **Reverse DNS:** `212.20.151.29` → `mail.aiqadam.org` (confirmed via `nslookup` against both the local resolver and `1.1.1.1`).
- **ASN / hosting provider:** AS213951, "Globe Cloud LLC", geolocated Tashkent, Uzbekistan (via ipinfo.io, unauthenticated lookup, 2026-07-13). This is a **different hosting provider entirely** from Hetzner (`ubuntu-16gb-nbg1-1`) and pro-data.tech (`pro-data-tech-qa`/`pro-data-tech-prod`).
- **HTTP behavior (direct-IP probe, bypassing Cloudflare proxy, `Host: aiqadam.org`):** returns `302 Found` → `Location: https://global.aiqadam.org/`. `global.aiqadam.org` **is not a DNS record in this zone** — it resolves only through the same proxied wildcard (Cloudflare anycast IPs), and hitting it directly against the origin returns `503 Service Unavailable` with a bare `text/plain` body. This 302-to-undefined-host-then-503 pattern is the classic signature of a **reverse-proxy / PaaS front door with no router match for the requested hostname** (e.g. Traefik/Coolify's catch-all default vhost behavior) — consistent with the aiqadam app's local dev compose file noting "production runs on Coolify on the platform host."
- **TLS certificate on 212.20.151.29:** Let's Encrypt cert, `CN=aiqadam.org`, SAN `DNS:aiqadam.org` only (not a wildcard SAN, not `global.aiqadam.org`) — consistent with a multi-tenant proxy presenting whatever default certificate it has when SNI doesn't match a configured route, rather than a purpose-built single-site host.
- **Conclusion:** 212.20.151.29 is best explained as **a Coolify (or similar PaaS) platform host** serving as the front door for one or more `aiqadam.org`-family deployments (apex site + wildcard catch-all), operated on Globe Cloud LLC infrastructure in Uzbekistan — **entirely separate from and undocumented in** this repo's `hosts/` (which covers only `ubuntu-16gb-nbg1-1`, `pro-data-tech-qa`, `pro-data-tech-prod`). It is **not** managed by this repo and **no host file should be created for it** without a separate, explicitly-scoped discovery task — this refresh is zone-DNS-only, not host discovery, and no credentials or access to that host exist in this repo's secrets inventory. **As of T-0111 (2026-07-13), the apex `aiqadam.org` A record no longer points at this host** (repointed to `95.46.211.224`, see T-0111 outcome below) — the wildcard `*.aiqadam.org` and mail records still point at `212.20.151.29`, so this host remains live and relevant to the zone, just no longer for the apex hostname.
- **Historical note (superseded by T-0117, 2026-07-19):** `mail.aiqadam.org` used to resolve to this same IP (212.20.151.29, unproxied A record), meaning the old (now-dead, third-party) mail server and the apex/wildcard web front door were the same physical host or at least the same edge IP. As of T-0117, `mail.aiqadam.org` has been repointed to `95.46.211.224` (the self-hosted Stalwart server on `pro-data-tech-prod`) — this host (`212.20.151.29`) remains live only for the wildcard `*.aiqadam.org` catch-all; it no longer serves any record this repo depends on for mail.

## Notes

- The `aiqadam.org` zone was added 2026-07-11 to support Penpot deployment (T-0107/T-0108/T-0109). Zone name confirmed `aiqadam.org` (no hyphen) via Cloudflare API.
- **This zone is not exclusive to Penpot or to this repo.** As of 2026-07-13 it hosts a full mail platform, a wildcard-catching web front door of unknown/third-party origin, two Cloudflare Tunnels, and three GitHub Pages sites, none of which predate this repo's involvement in the zone and none of which are otherwise documented in `landscape/domains.md`, `landscape/services.md`, or `landscape/hosts/`. Whoever administers the mail platform and the Coolify-like host likely manages this zone from outside this repo's workflow — **coordinate before assuming exclusive control of the zone.**
- Cloudflare proxy (orange cloud) for `penpot.aiqadam.org` set to OFF to allow certbot HTTP-01. May be switched to ON after cert issuance (set Cloudflare SSL mode to Full (strict) if proxied).
- **DNS specific-record-beats-wildcard:** per standard DNS resolution rules, an explicit `qa.aiqadam.org` A record (once created) takes precedence over the `*.aiqadam.org` wildcard for exact-name lookups. Creating a dedicated record does not require or imply any change to the wildcard or to any other record in this zone.
- The `ai-dala.com` zone is managed by the separate `ai-dala-infra` repository — do not manage it here.

## T-0110 outcome (closed 2026-07-13)

The pre-execution recommendation below (originally written mid-run, before the hostname rename) is preserved for its DNS-precedence and shared-zone reasoning, which held throughout. Final outcome: `qa.aiqadam.org` was created, then — later in the same run, after an app-level tenant-parsing 400 was diagnosed — deleted, and replaced by `qa-uz.aiqadam.org` (record ID `53aa89ca061e343291f33bb7b8b3a12e`, same target `95.46.211.230`, same `proxied: false`). Both the create and the delete were single, uniquely-named-record operations; no other of the 33 (formerly 32) zone records was touched at any point, confirmed by the step-07 execution-validator's full zone dump. See [`domains.md`](./domains.md) and [`hosts/pro-data-tech-qa.md`](./hosts/pro-data-tech-qa.md) for the application-level reason behind the `qa` → `qa-uz` rename.

### Original recommendation for T-0110 (qa.aiqadam.org A record) — historical, superseded by the rename above

**Creating a dedicated `qa.aiqadam.org` A record → `95.46.211.230`, proxied: false, remains safe and correct**, with the following reasoning now made explicit (which step-04's original plan could not do, since it believed the zone held only 1 record):

1. **No name collision.** No record named exactly `qa.aiqadam.org` exists among the 32 live records. The earlier resolution to Cloudflare anycast IPs was entirely the `*.aiqadam.org` wildcard acting on an unclaimed name — not a pre-existing, intentionally-provisioned `qa` service.
2. **DNS precedence guarantees correct takeover.** Once `qa.aiqadam.org` exists as an explicit A record, it will resolve to `95.46.211.230` directly and will no longer fall through to the wildcard (specific record beats wildcard, universally, in DNS resolution — not Cloudflare-specific behavior).
3. **No blast radius on unrelated infrastructure.** The wildcard, apex, mail records, tunnels, and GitHub Pages CNAMEs are all independent record objects. Adding one new, uniquely-named A record cannot alter, shadow, or break any of them — DNS records for distinct names do not interact.
4. **Proxied: false is still correct and now better-justified.** `penpot.aiqadam.org` already establishes the working pattern of an unproxied record for certbot HTTP-01 in this exact zone. Unlike the wildcard/apex (proxied: true, served by the Uzbekistan-hosted platform), a new unproxied `qa.aiqadam.org` record will route HTTP-01 validation traffic directly to `95.46.211.230`, exactly as `penpot.aiqadam.org` does to `95.46.211.224` today.
5. **One residual caution, not a blocker:** the zone is shared with an active, unrelated mail/hosting operation on infrastructure this repo does not own or document. This does not affect the safety of adding `qa.aiqadam.org`, but it does mean future zone-wide changes (e.g., changing SSL/TLS mode, CAA records, or any operation broader than a single named record) should not be undertaken without first confirming who else depends on this zone. Scope any future Cloudflare work in this zone to single, explicitly-named record operations unless a human confirms broader changes are safe.

**This same reasoning applied identically to the final `qa-uz.aiqadam.org` record** — the only difference is the exact name string; the safety analysis (no collision, DNS precedence, no blast radius, proxied:false correctness, shared-zone caution) carries over unchanged.

## T-0111 outcome (closed 2026-07-13)

The apex `aiqadam.org` A record (record ID `bf1113199732117bd147ebd87d6e356d`) was **repointed, not created** — `content` changed `212.20.151.29` → `95.46.211.224`, `proxied` flipped `true` → `false`. A freshness re-check immediately before the `PATCH` confirmed the record still matched the documented pre-change value; a post-`PATCH` `GET` confirmed the change was durable (`modified_on: 2026-07-13T16:32:00.521637Z`). The full 33-record zone was independently re-dumped by the execution-validator and diffed against the pre-run landscape snapshot: all 32 non-apex records — including `qa-uz.aiqadam.org`, the wildcard, and all mail/tunnel/pages records — were confirmed byte-for-byte unchanged; only the intended apex record differs. This was the highest-severity single step in T-0111 (a live, shared, third-party-owned record was mutated), explicitly approved by the user at plan-approval time (step-05) before execution. See [`hosts/pro-data-tech-prod.md`](./hosts/pro-data-tech-prod.md#aiqadam-prod) and [`domains.md`](./domains.md) for the application-level detail.

## T-0117 outcome (closed 2026-07-19)

The mail-records section of this zone was cut over from the dead third-party host to the self-hosted Stalwart server on `pro-data-tech-prod`, across two executor passes (the second a narrow, validator-caught follow-up):

- **Repointed (PATCH):** `mail.aiqadam.org` A (`212.20.151.29` → `95.46.211.224`), apex `aiqadam.org` SPF TXT (`v=spf1 ip4:212.20.151.29 mx -all` → `v=spf1 ip4:95.46.211.224 mx -all`), `mail._domainkey.aiqadam.org` TXT (old RSA DKIM key → new Ed25519 key), `_dmarc.aiqadam.org` TXT (`p=reject` → `p=none`, soak-period decision). `aiqadam.org` MX confirmed no-op (target `mail.aiqadam.org` unchanged; the A-record repoint above is what actually redirects mail routing).
- **Deleted (first pass, Phase 5 of the approved plan):** `webmail.aiqadam.org` A, `mta-sts.aiqadam.org` CNAME + `_mta-sts.aiqadam.org` TXT, `ua-auto-config.aiqadam.org` CNAME + `_ua-auto-config.aiqadam.org` TXT, `_caldavs._tcp`/`_carddavs._tcp`/`_pop3s._tcp` SRV — 8 records total, all freshness-checked immediately before deletion.
- **Deleted (second pass, follow-up cleanup after step-07 validator review):** `autoconfig.aiqadam.org` CNAME, `autodiscover.aiqadam.org` CNAME — both had no working nginx/Stalwart route behind them, so were removed rather than left orphaned pointing at a now-working-but-unrouted hostname.
- **New, self-managed (Stalwart's own `dnsManagement: Automatic`, scoped `publishRecords: {tlsa:true}`):** 20 TLSA records + 1 `_acme-challenge.aiqadam.org` TXT record — ongoing, auto-renewed churn, not one-time facts (see the mail-records section above).
- **Explicitly untouched throughout, independently re-confirmed via full zone dump:** `resend._domainkey.aiqadam.org`, `send.aiqadam.org` MX/TXT (SES), the wildcard `*.aiqadam.org`, all 5 tunnel/GitHub-Pages records, `qa.aiqadam.org`, `auth.qa.aiqadam.org`.

Every mutation was freshness-checked (GET immediately before PATCH/DELETE) against the documented pre-change value, per this zone's established shared-resource-surgery discipline (same class of operation as T-0110/T-0111). A mandatory zone-diff safety checkpoint was run after wiring Stalwart's own DNS automation and before the deliberate DNS cutover, specifically to catch any unexpected drift from granting Stalwart standing (scoped) write access to the zone — it passed cleanly. Final state independently re-confirmed by [step-07 execution-validator](../runs/2026-07-19-install-mail-server-aiqadam-001/step-07-execution-validator.md) via direct Cloudflare API checks, a full 46-record zone dump, and a `modified_on` timestamp sort proving no record outside T-0117's own deliberate changes was touched. See [`hosts/pro-data-tech-prod.md`](./hosts/pro-data-tech-prod.md#stalwart-mail) and [`domains.md`](./domains.md) for the server-side and TLS detail, and [`tasks/T-0117-install-mail-server-aiqadam.md`](../tasks/T-0117-install-mail-server-aiqadam.md) for the full 9-attempt journey.
