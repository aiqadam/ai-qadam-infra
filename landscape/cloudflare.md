---
name: cloudflare
last_verified: 2026-07-11
status: active
---

# Cloudflare

## Zones managed

### aiqadam.org

- **Zone ID:** `bec8854d698d56ff17cf917367634100` (reference only — value in `landscape/secrets-inventory.md`)
- **Account ID:** see `landscape/secrets-inventory.md`
- **API Token:** see `landscape/secrets-inventory.md` (`cloudflare-ai-qadam-api-token`)
- **DNS records managed by this repo:**

| Name | Type | Value | Proxied | Record ID | Purpose | Task | DNS verified |
|---|---|---|---|---|---|---|---|
| penpot.aiqadam.org | A | 95.46.211.224 | false | fde29338774531998ae38c41cd2e28ad | Penpot design tool | T-0107 | yes (2026-07-11) |

## Notes

- The `aiqadam.org` zone was added 2026-07-11 to support Penpot deployment (T-0108/T-0109). Zone name confirmed `aiqadam.org` (no hyphen) via Cloudflare API.
- Cloudflare proxy (orange cloud) set to OFF initially to allow certbot HTTP-01 challenge. May be switched to ON after cert issuance (set Cloudflare SSL mode to Full (strict) if proxied).
- The `ai-dala.com` zone is managed by the separate `ai-dala-infra` repository — do not manage it here.
