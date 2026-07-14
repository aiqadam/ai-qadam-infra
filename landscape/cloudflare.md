---
name: cloudflare
last_verified: 2026-07-13
status: active
last_verified_note: T-0111 done 2026-07-13 — repointed the aiqadam.org apex A record (record ID bf1113199732117bd147ebd87d6e356d, unchanged) from 212.20.151.29 (third-party host) to 95.46.211.224 (pro-data-tech-prod), proxied true→false; zone still 33 records (no records added or removed, only the apex record's content/proxied updated). Prior note: T-0110 done 2026-07-13 — added qa-uz.aiqadam.org A record (record ID 53aa89ca061e343291f33bb7b8b3a12e) for the AiQadam QA host.
---

# Cloudflare

## Zones managed

### aiqadam.org

- **Zone ID:** `bec8854d698d56ff17cf917367634100` (reference only — value in [`secrets-inventory.md`](./secrets-inventory.md))
- **Account ID:** see [`secrets-inventory.md`](./secrets-inventory.md) (`cloudflare-ai-qadam-account-id`)
- **API Token:** see [`secrets-inventory.md`](./secrets-inventory.md) (`cloudflare-ai-qadam-api-token`)
- **Live record count (verified 2026-07-13 via `GET /zones/<zone-id>/dns_records`):** **33 records** (32 confirmed by an earlier mid-run refresh, 1 added the same day by T-0110; T-0111 later the same day updated the pre-existing apex record in place — no change in total count). This zone is **shared, heavily-used infrastructure** — it is not exclusive to this repo's Penpot/AiQadam deployments. Only 3 of the 33 records (`aiqadam.org` apex, `penpot.aiqadam.org`, `qa-uz.aiqadam.org`) are actually managed/owned by this repo as of T-0111; the other 30 belong to an unrelated mail platform, a Coolify-style hosting platform, Cloudflare Tunnels, and GitHub Pages sites, none of which are documented elsewhere in this repo's landscape. Treat any new record creation or modification in this zone as **shared-resource surgery**, not greenfield.

#### Core web records (apex / wildcard / this repo's records)

| Name | Type | Value | Proxied | TTL | Record ID | Purpose | Owner / Task |
|---|---|---|---|---|---|---|---|
| **aiqadam.org** | **A** | **95.46.211.224** | **false** | 1 (auto) | `bf1113199732117bd147ebd87d6e356d` | **Apex domain — AiQadam prod API, owned by this repo (repointed from the third-party host below, T-0111).** Proxies via nginx to `127.0.0.1:3115` (`aiqadam-prod-api-1`) on `pro-data-tech-prod`. | **T-0111 / this repo** |
| `*`.aiqadam.org | A | 212.20.151.29 | true | 1 (auto) | `c13cf65703dd761c6f54437554b84f24` | Wildcard — catches **any** subdomain without its own explicit record; still points at the third-party host (see "212.20.151.29 investigation" below) — unaffected by the apex repoint (distinct record) | **unknown / not this repo** |
| aiqadam.org | CAA | `0 issue "letsencrypt.org"` | false | 1 (auto) | `4d4c6a48ccb1578b8d7f23509945ffd1` | Restricts cert issuance to Let's Encrypt (zone-wide) | shared |
| aiqadam.org | TXT | `v=spf1 ip4:212.20.151.29 mx -all` | false | 300 | `066b056e1fe89b972dca640a1164e64d` | SPF for apex mail sending — unaffected by the apex A record repoint (distinct record) | shared (mail) |
| **penpot.aiqadam.org** | **A** | **95.46.211.224** | **false** | 1 (auto) | `fde29338774531998ae38c41cd2e28ad` | **Penpot design tool — owned by this repo** | **T-0107 / this repo** |
| **qa-uz.aiqadam.org** | **A** | **95.46.211.230** | **false** | 1 (auto) | `53aa89ca061e343291f33bb7b8b3a12e` | **AiQadam QA app host — owned by this repo.** Named `qa-uz` (not `qa`) to route around an app-level tenant-parsing 400 — see [`domains.md`](./domains.md) for detail. | **T-0110 / this repo** |

#### Mail records (Stalwart mail server + Snappymail webmail — NOT managed by this repo)

All point at or reference `mail.aiqadam.org` = `212.20.151.29` (same IP as apex/wildcard — see investigation below).

| Name | Type | Value | Proxied | TTL |
|---|---|---|---|---|
| mail.aiqadam.org | A | 212.20.151.29 | false | 300 |
| webmail.aiqadam.org | A | 212.20.151.29 | true | 1 |
| autoconfig.aiqadam.org | CNAME | mail.aiqadam.org | false | 300 |
| autodiscover.aiqadam.org | CNAME | mail.aiqadam.org | false | 300 |
| mta-sts.aiqadam.org | CNAME | mail.aiqadam.org | false | 300 |
| ua-auto-config.aiqadam.org | CNAME | mail.aiqadam.org | false | 300 |
| aiqadam.org | MX | mail.aiqadam.org (prio 10) | false | 300 |
| send.aiqadam.org | MX | feedback-smtp.ap-northeast-1.amazonses.com (prio 10) | false | 3600 |
| _caldavs._tcp.aiqadam.org | SRV | `1 443 mail.aiqadam.org` | false | 300 |
| _carddavs._tcp.aiqadam.org | SRV | `1 443 mail.aiqadam.org` | false | 300 |
| _imaps._tcp.aiqadam.org | SRV | `1 993 mail.aiqadam.org` | false | 300 |
| _jmap._tcp.aiqadam.org | SRV | `1 443 mail.aiqadam.org` | false | 300 |
| _pop3s._tcp.aiqadam.org | SRV | `1 995 mail.aiqadam.org` | false | 300 |
| _submissions._tcp.aiqadam.org | SRV | `1 465 mail.aiqadam.org` | false | 300 |
| _dmarc.aiqadam.org | TXT | `v=DMARC1; p=reject; rua=mailto:postmaster@aiqadam.org` | false | 300 |
| _mta-sts.aiqadam.org | TXT | `v=STSv1; id=11937098366265790322` | false | 300 |
| _smtp._tls.aiqadam.org | TXT | `v=TLSRPTv1; rua=mailto:postmaster@aiqadam.org` | false | 300 |
| _ua-auto-config.aiqadam.org | TXT | `v=UAAC1; a=sha256; d=...` (truncated) | false | 300 |
| mail.aiqadam.org | TXT | `v=spf1 a -all` | false | 300 |
| mail._domainkey.aiqadam.org | TXT | DKIM public key (RSA) | false | 300 |
| resend._domainkey.aiqadam.org | TXT | DKIM public key (Resend service) | false | 3600 |
| send.aiqadam.org | TXT | `v=spf1 include:amazonses.com ~all` | false | 3600 |

- 22 records total in this category. Confirms a fully operational self-hosted mail stack (Stalwart mail server pattern: JMAP/CalDAV/CardDAV/IMAPS/POP3S/submission SRV records, MTA-STS, TLS-RPT, DKIM/DMARC/SPF) plus at least one transactional-email integration each via Amazon SES (`send.aiqadam.org`) and Resend (`resend._domainkey`).

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

## Investigation: what is 212.20.151.29?

Performed 2026-07-13 as part of this run's landscape-refresh sub-step, triggered by executor-infra (step-06 of run `2026-07-13-setup-aiqadam-qa-infra-001`) halting BLOCKED when a pre-flight idempotency check found `qa.aiqadam.org` unexpectedly resolving.

- **Not pro-data-tech-qa** (`95.46.211.230`) and **not pro-data-tech-prod** (`95.46.211.224`) — confirmed by direct comparison, this is a third, previously-undocumented IP.
- **Reverse DNS:** `212.20.151.29` → `mail.aiqadam.org` (confirmed via `nslookup` against both the local resolver and `1.1.1.1`).
- **ASN / hosting provider:** AS213951, "Globe Cloud LLC", geolocated Tashkent, Uzbekistan (via ipinfo.io, unauthenticated lookup, 2026-07-13). This is a **different hosting provider entirely** from Hetzner (`ubuntu-16gb-nbg1-1`) and pro-data.tech (`pro-data-tech-qa`/`pro-data-tech-prod`).
- **HTTP behavior (direct-IP probe, bypassing Cloudflare proxy, `Host: aiqadam.org`):** returns `302 Found` → `Location: https://global.aiqadam.org/`. `global.aiqadam.org` **is not a DNS record in this zone** — it resolves only through the same proxied wildcard (Cloudflare anycast IPs), and hitting it directly against the origin returns `503 Service Unavailable` with a bare `text/plain` body. This 302-to-undefined-host-then-503 pattern is the classic signature of a **reverse-proxy / PaaS front door with no router match for the requested hostname** (e.g. Traefik/Coolify's catch-all default vhost behavior) — consistent with the aiqadam app's local dev compose file noting "production runs on Coolify on the platform host."
- **TLS certificate on 212.20.151.29:** Let's Encrypt cert, `CN=aiqadam.org`, SAN `DNS:aiqadam.org` only (not a wildcard SAN, not `global.aiqadam.org`) — consistent with a multi-tenant proxy presenting whatever default certificate it has when SNI doesn't match a configured route, rather than a purpose-built single-site host.
- **Conclusion:** 212.20.151.29 is best explained as **a Coolify (or similar PaaS) platform host** serving as the front door for one or more `aiqadam.org`-family deployments (apex site + wildcard catch-all), operated on Globe Cloud LLC infrastructure in Uzbekistan — **entirely separate from and undocumented in** this repo's `hosts/` (which covers only `ubuntu-16gb-nbg1-1`, `pro-data-tech-qa`, `pro-data-tech-prod`). It is **not** managed by this repo and **no host file should be created for it** without a separate, explicitly-scoped discovery task — this refresh is zone-DNS-only, not host discovery, and no credentials or access to that host exist in this repo's secrets inventory. **As of T-0111 (2026-07-13), the apex `aiqadam.org` A record no longer points at this host** (repointed to `95.46.211.224`, see T-0111 outcome below) — the wildcard `*.aiqadam.org` and mail records still point at `212.20.151.29`, so this host remains live and relevant to the zone, just no longer for the apex hostname.
- **mail.aiqadam.org itself resolves to the same IP** (212.20.151.29, unproxied A record) — meaning the Stalwart mail server and the apex/wildcard web front door are the same physical host or at least the same edge IP. This further supports "shared multi-tenant platform host" over "dedicated single-purpose server."

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
