---
id: T-0109-nginx-letsencrypt-penpot-ai-qadam-org
title: Configure nginx reverse proxy + Let's Encrypt TLS for penpot.aiqadam.org
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/domains.md
workflow: infrastructure
blocks: []
blocked_by: [T-0107, T-0108]
related: []
estimated_blast_radius: medium
estimated_reversibility: full
---

# Configure nginx reverse proxy + Let's Encrypt TLS for penpot.aiqadam.org

## Why
Penpot requires HTTPS for production use (browser APIs including clipboard don't work over HTTP). nginx will terminate TLS and proxy to Penpot's localhost:9001. Let's Encrypt provides the certificate via certbot.

## What done looks like
- [ ] nginx installed (`apt install nginx`)
- [ ] certbot + nginx plugin installed (`apt install certbot python3-certbot-nginx`)
- [ ] nginx vhost `/etc/nginx/sites-available/penpot.aiqadam.org` created with:
  - HTTP → HTTPS redirect (port 80)
  - HTTPS server block with `client_max_body_size 367001600`
  - `/ws/notifications` websocket proxy pass to `localhost:9001`
  - `/mcp/ws` websocket proxy pass to `localhost:9001` (MCP websocket)
  - `/mcp/stream` proxy pass to `localhost:9001` (MCP SSE/HTTP)
  - All other locations proxied to `http://localhost:9001/`
- [ ] Symlink to sites-enabled created
- [ ] `certbot --nginx -d penpot.aiqadam.org` succeeds (HTTP-01 challenge via Cloudflare DNS non-proxied)
- [ ] nginx config test passes (`nginx -t`)
- [ ] nginx reload successful
- [ ] HTTPS: `curl -I https://penpot.aiqadam.org` returns HTTP/2 200 (or 302)
- [ ] MCP endpoint reachable: `curl https://penpot.aiqadam.org/mcp/stream` returns 4xx (auth required = working)
- [ ] Certbot auto-renewal timer active (`systemctl is-active certbot.timer`)
- [ ] UFW 80/443 already open (confirmed T-0103)

## Result

All 10 acceptance criteria met. Executed by run `2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001`.

- nginx 1.28.3 (`1.28.3-2ubuntu1.6`) installed from Ubuntu apt; `nginx.service` active and enabled.
- certbot 4.0.0 + python3-certbot-nginx 4.0.0 installed.
- Vhost `/etc/nginx/sites-available/penpot.aiqadam.org` created with full config: HTTP→HTTPS redirect, HTTPS on 443 with `client_max_body_size 367001600`, WebSocket proxy for `/ws/notifications` and `/mcp/ws`, SSE proxy for `/mcp/stream`, general proxy for `/` → `http://localhost:9001/`. Symlink to `sites-enabled` created.
- `certbot --nginx -d penpot.aiqadam.org --non-interactive --agree-tos -m admin@aiqadam.org` succeeded; cert at `/etc/letsencrypt/live/penpot.aiqadam.org/` (ECDSA, expires 2026-10-09, intermediate CA `YE1`/Let's Encrypt).
- `nginx -t` passed; nginx reloaded successfully.
- `https://penpot.aiqadam.org` returns HTTP 200; TLS cert subject `CN=penpot.aiqadam.org`, issuer `CN=YE1, O=Let's Encrypt, C=US`, expiry `09.10.2026 14:05:49` — all confirmed from management workstation.
- `certbot.timer` active and enabled (auto-renewal configured).
- UFW 80/tcp and 443/tcp were already open from T-0103.
- Executor handoff: `runs/2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001/step-06-executor-infra.md` (verdict PASS).
- Validator handoff: `runs/2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001/step-07-execution-validator.md` (verdict PASS).
- No deviations from the acceptance checklist. Note: TLS intermediate CA is `YE1` (not `R10`/`R11` as estimated in design); this is a valid Let's Encrypt intermediate and the certificate chain is fully trusted.

## Notes
- nginx config based on official Penpot nginx example from docs
- MCP uses `/mcp/ws` (WebSocket) and `/mcp/stream` (SSE) — both must be proxied with websocket upgrade headers
- Cloudflare proxy (orange cloud) should remain OFF during cert issuance; can be turned ON afterward for CDN/WAF (optional — user decision)
- certbot renewal cron/timer configures itself automatically post-install
- If Cloudflare proxy is enabled after cert issuance, set SSL mode to "Full (strict)" in Cloudflare dashboard to avoid redirect loops

## History
- 2026-07-11: created manually by orchestrator
- 2026-07-11: domain corrected to aiqadam.org per T-0107 finding
- 2026-07-11: status → in-progress — run 2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001 started
- 2026-07-11: status → done, outcome succeeded, run 2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001, commit <pending>
