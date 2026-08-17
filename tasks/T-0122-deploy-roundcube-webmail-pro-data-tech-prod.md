---
id: T-0122-deploy-roundcube-webmail-pro-data-tech-prod
title: Deploy Roundcube webmail on pro-data-tech-prod for @aiqadam.org users
kind: task
status: done
priority: P1
created: 2026-07-23
updated: 2026-07-23
closed: 2026-07-23
outcome: Roundcube 1.6.17 deployed at https://webmail.aiqadam.org/ — Cloudflare DNS (grey-cloud), Let’s Encrypt cert (expires 2026-10-21), Docker Compose stack at /opt/roundcube/ joined to stalwart-mail_default network. IMAPS/993 used (Stalwart does not bind 143 internally). HTTP 200 confirmed externally. Live browser login test pending (user action). Run: 2026-07-23-deploy-roundcube-webmail-001.
created_by: manual
source_runs: []
executed_by_runs: [2026-07-23-deploy-roundcube-webmail-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0117, T-0121]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Deploy Roundcube webmail on pro-data-tech-prod for @aiqadam.org users

## Why

Stalwart provides IMAP/JMAP/SMTP services but no user-facing webmail interface. Users with `@aiqadam.org` mailboxes (`vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva`, and future accounts) currently have no way to read or send email via a browser. The admin UI at `https://mail.aiqadam.org/` is operator-only and loopback-restricted (T-0121). Roundcube is the established standard for self-hosted webmail and works directly over IMAP/SMTP — no changes to Stalwart's configuration are needed.

## What done looks like

- [ ] Roundcube deployed as a Docker container on `pro-data-tech-prod` (alongside the existing `stalwart-mail` and Penpot stacks), connecting to Stalwart's IMAP (port 993 or 143) and SMTP submission (port 587) via the Docker network or `host.docker.internal`/bridge.
- [ ] nginx vhost `webmail.aiqadam.org` configured: HTTPS with Let's Encrypt cert (certbot, reusing existing renewal infrastructure), proxying to the Roundcube container. No access restrictions (this is the public-facing user endpoint).
- [ ] DNS: `webmail.aiqadam.org` A record pointing to `95.46.211.224` created in Cloudflare (proxied, consistent with other records on this host).
- [ ] `@aiqadam.org` users can log in at `https://webmail.aiqadam.org/` with their mailbox credentials and read, compose, reply to, and delete mail.
- [ ] Roundcube config uses `mail.aiqadam.org` as the default host (not configurable by the user — single-tenant deployment).
- [ ] Roundcube session/temp data stored on a named Docker volume (not anonymous, survives container restarts).
- [ ] Landscape files updated: `landscape/hosts/pro-data-tech-prod.md` (new service), `landscape/services.md`, `landscape/cloudflare.md` (new DNS record), `landscape/domains.md` (new subdomain).

## Result

Roundcube 1.6.17-apache deployed on `pro-data-tech-prod` (95.46.211.224) as Docker Compose project `roundcube` at `/opt/roundcube/`, joined to the `stalwart-mail_default` Docker network. Public URL `https://webmail.aiqadam.org/` live with Let’s Encrypt ECDSA cert (expires 2026-10-21). Cloudflare A record `webmail.aiqadam.org` → `95.46.211.224` (proxied=false, record ID `d44ce1ab6990cf47848148634809463d`) created. nginx vhost `/etc/nginx/sites-available/webmail.aiqadam.org` proxying to `http://127.0.0.1:8888`. IMAP deviation: Stalwart does not bind port 143 internally; Roundcube configured to use IMAPS `ssl://mail.aiqadam.org:993` (connection verified from inside the container via `openssl s_client`, `Verify return code: 0 (ok)`). HTTP 200 confirmed from external workstation; Roundcube login page served. SQLite DB on Docker volume `roundcube_roundcube_db`. Penpot, Stalwart mail, and AiQadam prod confirmed unregressed.

- Executor handoff: [runs/2026-07-23-deploy-roundcube-webmail-001/step-06-executor-infra.md](../runs/2026-07-23-deploy-roundcube-webmail-001/step-06-executor-infra.md)
- Validator handoff: [runs/2026-07-23-deploy-roundcube-webmail-001/step-07-execution-validator.md](../runs/2026-07-23-deploy-roundcube-webmail-001/step-07-execution-validator.md)
- One open item: live browser login test with a real `@aiqadam.org` credential — user action, outside automated verification.

## Notes
- **Blast radius: MEDIUM.** New container + nginx vhost + DNS + TLS cert on the live prod host. Fully reversible (stop container, remove vhost, delete DNS record). nginx reload is non-disruptive; any TLS cert acquisition has a brief nginx restart window.
- **No Stalwart changes required.** Roundcube connects to Stalwart over standard IMAP/SMTP. Stalwart's UFW allows ports 143/993/587 from the Docker bridge already; confirm during execution.
- **Roundcube database:** Roundcube requires a small SQL database for sessions, contacts, and settings. Options: (a) use a dedicated SQLite file (simplest, sufficient for this user count), (b) use the existing PostgreSQL container if one is present on this host. Prefer SQLite to avoid cross-stack dependency.
- **User passwords:** The `aigerim.kambetbayeva@aiqadam.org` account was created with a temp password (`AiQ-temp-2026!`). The owner needs to change it. This is outside scope of this task but should be noted in the completion notes.
- Roundcube image: `roundcube/roundcubemail:latest` (or a pinned tag — confirm latest stable at execution time).

## History
- 2026-07-23: created manually following user request during T-0121 session.
- 2026-07-23: status → in-progress — run 2026-07-23-deploy-roundcube-webmail-001 started.
- 2026-07-23: status → done — run 2026-07-23-deploy-roundcube-webmail-001 completed. Roundcube 1.6.17 live at https://webmail.aiqadam.org/. One open item: live browser login test by user.
