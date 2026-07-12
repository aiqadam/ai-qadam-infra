---
run_id: 2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001
step: "01"
agent: task-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0109-nginx-letsencrypt-penpot-ai-qadam-org
inputs_read:
  - tasks/T-0109-nginx-letsencrypt-penpot-ai-qadam-org.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader (step 02) — read pro-data-tech-prod host file and services.md
---

## Summary

Task T-0109 is `in-progress`, workflow is `infrastructure`. The task is to install nginx + certbot on `pro-data-tech-prod` (95.46.211.224) and configure a TLS-terminating reverse proxy for `penpot.aiqadam.org` pointing to `localhost:9001`, with WebSocket support for `/ws/notifications` and `/mcp/ws`, and SSE proxying for `/mcp/stream`.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md`
  - `landscape/services.md`
  - `landscape/domains.md`

### Why (verbatim from task)
> Penpot requires HTTPS for production use (browser APIs including clipboard don't work over HTTP). nginx will terminate TLS and proxy to Penpot's localhost:9001. Let's Encrypt provides the certificate via certbot.

### Target scope
Install and configure nginx + certbot on `pro-data-tech-prod` (95.46.211.224) such that:
- nginx is installed and serves `penpot.aiqadam.org`
- certbot + `python3-certbot-nginx` are installed
- nginx vhost `/etc/nginx/sites-available/penpot.aiqadam.org` is created with:
  - HTTP (port 80) → HTTPS redirect
  - HTTPS server block with `client_max_body_size 367001600`
  - `/ws/notifications` — WebSocket proxy pass to `localhost:9001`
  - `/mcp/ws` — WebSocket proxy pass to `localhost:9001`
  - `/mcp/stream` — SSE/HTTP proxy pass to `localhost:9001`
  - All other locations proxied to `http://localhost:9001/`
- Symlink created in `sites-enabled`
- `certbot --nginx -d penpot.aiqadam.org` completes successfully (HTTP-01 challenge)
- `nginx -t` passes; nginx reloaded
- `curl -I https://penpot.aiqadam.org` returns HTTP/2 200 or 302
- `curl https://penpot.aiqadam.org/mcp/stream` returns 4xx (auth-required = working proxy)
- `certbot.timer` systemd unit is active

### Constraints stated by user
- Certbot HTTP-01 challenge requires port 80 accessible — UFW already allows it (confirmed T-0103)
- Cloudflare DNS proxy (proxied=false) must remain OFF during cert issuance (confirmed T-0107)
- Penpot is already listening on `localhost:9001` (confirmed T-0108)
- Both `/mcp/ws` (WebSocket) and `/mcp/stream` (SSE) must be proxied

### Information gaps for downstream steps
- Current contents of `/etc/nginx/sites-available/` and `/etc/nginx/sites-enabled/` on host (landscape-reader/executor to check)
- Whether nginx or certbot are already partially installed from any prior run
- Whether a default nginx site exists that would conflict on port 80

## Issues / risks

- If Cloudflare proxy is switched to "proxied=true" after cert issuance, an SSL mode mismatch could cause redirect loops — Cloudflare must be set to "Full (strict)". This is a post-task user decision, not a blocker.
- HTTP-01 challenge will fail if port 80 is blocked at the network layer above UFW (e.g. Hetzner firewall). Executor should verify Hetzner firewall allows TCP/80 before issuing cert.
