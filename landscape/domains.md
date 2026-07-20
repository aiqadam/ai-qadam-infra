---
name: domains
last_verified: 2026-07-19
status: active
last_verified_note: 2026-07-19 (T-0117) — added mail.aiqadam.org subdomain (self-hosted Stalwart mail server on pro-data-tech-prod, replacing the dead third-party mail.aiqadam.org host) and its two independent TLS cert entries (certbot-managed for the admin UI, Stalwart's own internal-ACME-managed for SMTP/IMAP/submission). Prior note: 2026-07-19 — added qa.aiqadam.org and auth.qa.aiqadam.org, discovered live (not created by this repo) via a T-0117 pre-cutover Cloudflare zone-diff safety check; both created 2026-07-18 by separate, user-confirmed-expected QA/Authentik work not tracked by any task file here — see cloudflare.md for full detail. Prior note: T-0111 done 2026-07-13 — added aiqadam.org apex domain (AiQadam prod app host) and its TLS cert entry; apex A record repointed from a third-party host. Prior note: T-0110 done 2026-07-13 — added qa-uz.aiqadam.org subdomain (AiQadam QA app host) and its TLS cert entry.
---

# Domains

## aiqadam.org

- **Registrar:** unknown (check provider portal)
- **DNS provider:** Cloudflare (Zone ID: `bec8854d698d56ff17cf917367634100`)
- **Managed by:** this repo (`ai-qadam-infra`)
- **Subdomains in use:**

| Subdomain | A record | CF Record ID | Purpose | Task |
|---|---|---|---|---|
| aiqadam.org (apex) | 95.46.211.224 | bf1113199732117bd147ebd87d6e356d | AiQadam prod app host (proxies to `aiqadam-prod-api-1`, `127.0.0.1:3115`). Repointed from a pre-existing third-party record (`212.20.151.29`) — see [`cloudflare.md`](./cloudflare.md) for full history. Bare apex only, no `www`. | T-0111 |
| penpot.aiqadam.org | 95.46.211.224 | fde29338774531998ae38c41cd2e28ad | Penpot design tool | T-0107 |
| qa-uz.aiqadam.org | 95.46.211.230 | 53aa89ca061e343291f33bb7b8b3a12e | AiQadam QA app host (proxies to `aiqadam-qa-api-1`, `127.0.0.1:3113`). Named `qa-uz` (not the originally-planned `qa`) to route around an app-level tenant-parsing 400 — see Notes below. | T-0110 |
| qa.aiqadam.org | 95.46.211.230 | (not captured by this repo) | Recreated by separate, out-of-band work, unrelated to this repo's original `qa.aiqadam.org` (deleted by T-0110, see Notes below). Discovered 2026-07-19, user-confirmed expected. Purpose/owning task not documented here — see [`cloudflare.md`](./cloudflare.md). | discovered, not this repo |
| auth.qa.aiqadam.org | 95.46.211.230 | (not captured by this repo) | Authentik (or similar) auth service on `pro-data-tech-qa`, per the record's own Cloudflare comment. Discovered 2026-07-19, user-confirmed expected. Not otherwise documented in [`hosts/pro-data-tech-qa.md`](./hosts/pro-data-tech-qa.md) — a host-level discovery task may be warranted to document this service properly. | discovered, not this repo |
| mail.aiqadam.org | 95.46.211.224 | (see [`cloudflare.md`](./cloudflare.md) for record ID) | Self-hosted Stalwart mail server (SMTP/IMAP/JMAP/submission) — replaces the dead third-party `mail.aiqadam.org` (`212.20.151.29`). Admin/JMAP web UI proxied by nginx at `https://mail.aiqadam.org/`; reuses an orphaned certbot cert from executor attempt 1. | T-0117 |

### TLS certificates

| Domain | Cert path | Issued by | Expires | Auto-renewal | Run |
|---|---|---|---|---|---|
| aiqadam.org | `/etc/letsencrypt/live/aiqadam.org/fullchain.pem` | Let's Encrypt (ECDSA) | 2026-10-11 | `certbot.timer` (active) | T-0111, 2026-07-13 |
| penpot.aiqadam.org | `/etc/letsencrypt/live/penpot.aiqadam.org/fullchain.pem` | Let's Encrypt (CA: `YE1`) | 2026-10-09 | `certbot.timer` (active) | T-0109, 2026-07-11 |
| qa-uz.aiqadam.org | `/etc/letsencrypt/live/qa-uz.aiqadam.org/fullchain.pem` | Let's Encrypt (ECDSA) | 2026-10-11 | `certbot.timer` (active) | T-0110, 2026-07-13 |
| mail.aiqadam.org (admin UI, nginx) | `/etc/letsencrypt/live/mail.aiqadam.org/fullchain.pem` | Let's Encrypt (ECDSA) | 2026-10-17 | `certbot.timer` (active) — reused from an orphaned executor-attempt-1 cert | T-0117, 2026-07-19 |
| mail.aiqadam.org (SMTP/IMAP/submission, Stalwart internal ACME) | managed inside Stalwart's own data store, not on the filesystem as a certbot-style path | Let's Encrypt (CN=`*.aiqadam.org`, CA `YE2`, DNS-01 via `AcmeProvider i9noabxeabab`) | 2026-10-17 | Stalwart's own internal ACME renewal (independent of `certbot.timer`) | T-0117, 2026-07-19 |

## Notes

- The `ai-dala.com` domain is managed by the `ai-dala-infra` repository. Do not manage it here.
- **aiqadam.org apex tenant-routing (T-0111):** unlike the QA subdomain's length-based fallback (below), the apex hostname `aiqadam.org` resolves to the `DEFAULT_TENANT_CODE='uz'` tenant because `aiqadam` (and `www`) are hardcoded into the app's own `NON_TENANT_LABELS` set in `tenant.middleware.ts` — confirmed by reading the source during T-0111, not inferred by analogy. This is an intentional, source-confirmed exemption distinct from the 2-character-label-length check described below.
- **qa-uz.aiqadam.org naming rationale (T-0110):** the app's tenant-resolution middleware (`apps/api/src/modules/tenants/tenant.middleware.ts`) treats a hostname's leftmost label as a candidate tenant code only if it is exactly 2 characters; `qa` (2 chars) was treated as an unregistered tenant code and 400'd, while `qa-uz` (5 chars) fails that length check and falls through to `DEFAULT_TENANT_CODE='uz'`, resolving successfully. This is a working default-tenant-fallback resolution, not genuine subdomain-to-tenant matching — sufficient for this QA health-check slice's scope, but worth knowing if this hostname is ever repurposed for real multi-tenant testing. The original `qa.aiqadam.org` record and cert were both deleted as part of this same run.
- **mail.aiqadam.org dual TLS mechanism (T-0117):** this hostname is served over TLS two independent ways for two different purposes — nginx + certbot terminates TLS for the admin/web UI on port 443 (reusing an orphaned cert from executor attempt 1), while Stalwart's own internal ACME (DNS-01 challenge, via the `Domain` object's scoped `dnsManagement`/`certificateManagement: Automatic` wiring) issues and renews a separate certificate used directly by Stalwart for SMTP/IMAP/submission TLS on 25/465/587/993. Not a conflict — both certs currently cover the same name/SAN and auto-renew independently, with no shared renewal hook. See [`hosts/pro-data-tech-prod.md`](./hosts/pro-data-tech-prod.md#stalwart-mail) for the full server-side detail.
