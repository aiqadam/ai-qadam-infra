---
name: domains
last_verified: 2026-07-11
status: active
---

# Domains

## aiqadam.org

- **Registrar:** unknown (check provider portal)
- **DNS provider:** Cloudflare (Zone ID: `bec8854d698d56ff17cf917367634100`)
- **Managed by:** this repo (`ai-qadam-infra`)
- **Subdomains in use:**

| Subdomain | A record | CF Record ID | Purpose | Task |
|---|---|---|---|---|
| penpot.aiqadam.org | 95.46.211.224 | fde29338774531998ae38c41cd2e28ad | Penpot design tool | T-0107 |

### TLS certificates

| Domain | Cert path | Issued by | Expires | Auto-renewal | Run |
|---|---|---|---|---|---|
| penpot.aiqadam.org | `/etc/letsencrypt/live/penpot.aiqadam.org/fullchain.pem` | Let's Encrypt (CA: `YE1`) | 2026-10-09 | `certbot.timer` (active) | T-0109, 2026-07-11 |

## Notes

- The `ai-dala.com` domain is managed by the `ai-dala-infra` repository. Do not manage it here.
