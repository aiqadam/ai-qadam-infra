---
name: domains
last_verified: 2026-07-13
status: active
last_verified_note: T-0111 done 2026-07-13 — added aiqadam.org apex domain (AiQadam prod app host) and its TLS cert entry; apex A record repointed from a third-party host. Prior note: T-0110 done 2026-07-13 — added qa-uz.aiqadam.org subdomain (AiQadam QA app host) and its TLS cert entry.
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

### TLS certificates

| Domain | Cert path | Issued by | Expires | Auto-renewal | Run |
|---|---|---|---|---|---|
| aiqadam.org | `/etc/letsencrypt/live/aiqadam.org/fullchain.pem` | Let's Encrypt (ECDSA) | 2026-10-11 | `certbot.timer` (active) | T-0111, 2026-07-13 |
| penpot.aiqadam.org | `/etc/letsencrypt/live/penpot.aiqadam.org/fullchain.pem` | Let's Encrypt (CA: `YE1`) | 2026-10-09 | `certbot.timer` (active) | T-0109, 2026-07-11 |
| qa-uz.aiqadam.org | `/etc/letsencrypt/live/qa-uz.aiqadam.org/fullchain.pem` | Let's Encrypt (ECDSA) | 2026-10-11 | `certbot.timer` (active) | T-0110, 2026-07-13 |

## Notes

- The `ai-dala.com` domain is managed by the `ai-dala-infra` repository. Do not manage it here.
- **aiqadam.org apex tenant-routing (T-0111):** unlike the QA subdomain's length-based fallback (below), the apex hostname `aiqadam.org` resolves to the `DEFAULT_TENANT_CODE='uz'` tenant because `aiqadam` (and `www`) are hardcoded into the app's own `NON_TENANT_LABELS` set in `tenant.middleware.ts` — confirmed by reading the source during T-0111, not inferred by analogy. This is an intentional, source-confirmed exemption distinct from the 2-character-label-length check described below.
- **qa-uz.aiqadam.org naming rationale (T-0110):** the app's tenant-resolution middleware (`apps/api/src/modules/tenants/tenant.middleware.ts`) treats a hostname's leftmost label as a candidate tenant code only if it is exactly 2 characters; `qa` (2 chars) was treated as an unregistered tenant code and 400'd, while `qa-uz` (5 chars) fails that length check and falls through to `DEFAULT_TENANT_CODE='uz'`, resolving successfully. This is a working default-tenant-fallback resolution, not genuine subdomain-to-tenant matching — sufficient for this QA health-check slice's scope, but worth knowing if this hostname is ever repurposed for real multi-tenant testing. The original `qa.aiqadam.org` record and cert were both deleted as part of this same run.
