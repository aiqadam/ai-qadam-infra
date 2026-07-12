---
run_id: 2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-11T00:00:00Z
task_id: T-0109-nginx-letsencrypt-penpot-ai-qadam-org
inputs_read:
  - runs/2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001/step-01-task-reader.md
  - runs/2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001/step-02-landscape-reader.md
  - runs/2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — NEEDS_APPROVAL; present plan to user before executor proceeds
---

## Summary

Install nginx and certbot on `pro-data-tech-prod` (95.46.211.224), issue a Let's Encrypt TLS certificate for `penpot.aiqadam.org` via HTTP-01 challenge, and configure a TLS-terminating reverse proxy vhost that forwards all traffic to Penpot on `localhost:9001` — with WebSocket support for `/ws/notifications` and `/mcp/ws`, and SSE proxying for `/mcp/stream` — leaving the host's end state at a publicly-accessible, HTTPS-only Penpot instance.

## Details

### Plan

**Pre-check (discovery — runs first, not state-changing):**

- Step 0a — Verify port 80 externally reachable from the executor machine before issuing certbot:
  - Command: `curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://95.46.211.224/`
  - Expected: any response (200, 301, or connection refused is fine — what matters is it is NOT a network timeout). If it times out, stop and escalate: provider-level firewall may be blocking port 80.
  - Note: if nginx is not yet installed, a "connection refused" is expected and correct; this check is about network-layer reachability, not an HTTP-OK requirement.

- Step 0b — Check whether nginx or certbot are partially installed from a prior attempt:
  - Command (on host): `apt list --installed 2>/dev/null | grep -E 'nginx|certbot'`
  - Expected: empty or lists installed packages. Document output in execution log.

- Step 0c — Check for existing default nginx site:
  - Command (on host): `ls /etc/nginx/sites-enabled/ 2>/dev/null || echo "nginx-not-installed"`
  - Expected: either "nginx-not-installed" (clean) or a list of enabled sites. Document output.

---

**Step 1 — Install nginx, certbot, python3-certbot-nginx:**

- Command (on host): `apt-get update -q && apt-get install -y nginx certbot python3-certbot-nginx`
- Idempotent: yes — apt-get install is a no-op if packages already present.
- Verification: `nginx -v` and `certbot --version` return version strings without error.
- Rollback: `apt-get purge -y nginx nginx-common certbot python3-certbot-nginx && apt-get autoremove -y`

---

**Step 2 — Disable the default nginx site:**

- Command (on host): `rm -f /etc/nginx/sites-enabled/default`
- Rationale: the default site listens on port 80 and conflicts with the certbot HTTP-01 challenge and our vhost.
- Idempotent: yes (`-f` is silent when the file does not exist).
- Rollback: `ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default` (only if it existed before — step 0c output determines this).

---

**Step 3 — Create initial HTTP-only vhost (for certbot HTTP-01 challenge):**

- Command (on host):
  ```bash
  cat > /etc/nginx/sites-available/penpot.aiqadam.org << 'EOF'
  server {
    listen 80;
    server_name penpot.aiqadam.org;
    location / { return 301 https://$host$request_uri; }
  }
  EOF
  ```
- Note: quoted heredoc (`<< 'EOF'`) prevents shell variable expansion of `$host` and `$request_uri`.
- Idempotent: yes — overwrites if already exists.
- Rollback: `rm -f /etc/nginx/sites-available/penpot.aiqadam.org`

---

**Step 4 — Enable the vhost in sites-enabled:**

- Command (on host): `ln -sf /etc/nginx/sites-available/penpot.aiqadam.org /etc/nginx/sites-enabled/penpot.aiqadam.org`
- Note: `-f` (force) makes this idempotent — replaces existing symlink if present from a prior attempt.
- Rollback: `rm -f /etc/nginx/sites-enabled/penpot.aiqadam.org`

---

**Step 5 — Test nginx config and reload:**

- Command (on host): `nginx -t && systemctl reload nginx`
- Verification: `nginx -t` prints `syntax is ok` and `test is successful`; `systemctl is-active nginx` returns `active`.
- Rollback: `systemctl stop nginx` (only if reload caused a failure — but `nginx -t` guards against that).

---

**Step 6 — Obtain TLS certificate via certbot HTTP-01:**

- Command (on host): `certbot --nginx -d penpot.aiqadam.org --non-interactive --agree-tos -m admin@aiqadam.org`
- Certbot will: (a) place a challenge file under `/var/lib/letsencrypt/`, (b) verify domain ownership via HTTP-01 (port 80 to 95.46.211.224), (c) issue certificate, (d) modify `/etc/nginx/sites-available/penpot.aiqadam.org` to add SSL directives, (e) reload nginx.
- Prereqs at this point: DNS `penpot.aiqadam.org → 95.46.211.224` is live and not Cloudflare-proxied (confirmed step 02); port 80 is open (UFW confirmed); nginx is active and serving `penpot.aiqadam.org`.
- Idempotent: nearly — if cert already exists and is valid, certbot skips re-issuance. If cert expired, it renews.
- Verification: `ls /etc/letsencrypt/live/penpot.aiqadam.org/` returns `cert.pem fullchain.pem chain.pem privkey.pem README`.
- Rollback: `certbot delete --cert-name penpot.aiqadam.org` (removes cert but does not un-modify nginx config; nginx config must also be reverted to step-3 state or removed entirely).

---

**Step 7 — Overwrite vhost with final production config (proxy + WebSocket + SSE):**

- Rationale: certbot only adds SSL directives; the production config requires proxy_pass, WebSocket upgrade headers, and `client_max_body_size`. Overwrite with the complete, authoritative production config.
- Command (on host):
  ```bash
  cat > /etc/nginx/sites-available/penpot.aiqadam.org << 'EOF'
  server {
    listen 80;
    server_name penpot.aiqadam.org;
    return 301 https://$host$request_uri;
  }
  server {
    listen 443 ssl;
    server_name penpot.aiqadam.org;
    client_max_body_size 367001600;
    ssl_certificate /etc/letsencrypt/live/penpot.aiqadam.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/penpot.aiqadam.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    # WebSocket: notifications
    location /ws/notifications {
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_pass http://localhost:9001/ws/notifications;
    }
    # WebSocket: MCP
    location /mcp/ws {
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_pass http://localhost:9001/mcp/ws;
    }
    # MCP SSE/HTTP stream
    location /mcp/stream {
      proxy_set_header Host $http_host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_pass http://localhost:9001/mcp/stream;
    }
    # Everything else
    location / {
      proxy_set_header Host $http_host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Scheme $scheme;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_redirect off;
      proxy_pass http://localhost:9001/;
    }
  }
  EOF
  ```
- Note: quoted heredoc — no shell variable expansion issues.
- Idempotent: yes — overwrites.
- Rollback: revert to certbot-modified config or remove entirely and re-run certbot.

---

**Step 8 — Test final config and reload nginx:**

- Command (on host): `nginx -t && systemctl reload nginx`
- Verification: `nginx -t` returns `syntax is ok` and `test is successful`.
- Rollback: if `nginx -t` fails, restore certbot-modified version (from step 6 output) or `systemctl stop nginx`.

---

**Step 9 — Verify certbot auto-renewal timer:**

- Command (on host): `systemctl is-active certbot.timer`
- Expected output: `active`
- Note: on Ubuntu 26.04, certbot installs a systemd timer (`certbot.timer`) that runs twice daily. This is installed automatically with the `certbot` package.
- Rollback: `systemctl enable --now certbot.timer` if not active.

---

**Step 10 — External HTTPS probe:**

- Command (from executor machine): `curl -I --max-time 10 https://penpot.aiqadam.org`
- Expected: `HTTP/2 200` or `HTTP/2 302` (Penpot may redirect unauthenticated users to `/login`). TLS certificate issuer should be `R10` or `R11` (Let's Encrypt intermediate).
- Secondary probe: `curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://penpot.aiqadam.org/mcp/stream`
- Expected secondary: `401` or `403` (auth-required = proxy is working, Penpot is responding).

---

### Rollback

Full rollback (undo everything, restore pre-T-0109 state):

1. `systemctl stop nginx && apt-get purge -y nginx nginx-common certbot python3-certbot-nginx && apt-get autoremove -y` — removes packages and their default configs.
2. `rm -rf /etc/nginx /etc/letsencrypt/live/penpot.aiqadam.org /etc/letsencrypt/renewal/penpot.aiqadam.org` — removes all generated files.
3. No DNS changes are made by this plan — Cloudflare DNS is left as-is (penpot.aiqadam.org → 95.46.211.224, not proxied).
4. Penpot continues to serve HTTP on `localhost:9001` regardless; it was not touched.
5. **Note:** If the Let's Encrypt certificate was successfully issued before rollback, the cert remains valid in the ACME account but will be cleaned from disk by step 2. This does not affect the host or Penpot.

Partial rollback (nginx removed but cert not yet issued — e.g., step 6 failure):

1. `systemctl stop nginx && apt-get purge -y nginx nginx-common && apt-get autoremove -y`
2. `rm -f /etc/nginx/sites-available/penpot.aiqadam.org`
3. certbot and python3-certbot-nginx can be left installed (no state impact) or also purged.

---

### Verification (for step 07)

**On-host checks:**

1. `nginx -v` — exits 0, prints version string.
2. `certbot --version` — exits 0, prints version string.
3. `systemctl is-active nginx` — returns `active`.
4. `systemctl is-active certbot.timer` — returns `active`.
5. `ls /etc/letsencrypt/live/penpot.aiqadam.org/` — lists `cert.pem`, `fullchain.pem`, `chain.pem`, `privkey.pem`, `README`.
6. `nginx -t` — prints `nginx: the configuration file /etc/nginx/nginx.conf syntax is ok` and `nginx: configuration file /etc/nginx/nginx.conf test is successful`.
7. `ls -la /etc/nginx/sites-enabled/penpot.aiqadam.org` — symlink exists pointing to `/etc/nginx/sites-available/penpot.aiqadam.org`.
8. `ls /etc/nginx/sites-enabled/default` — must NOT exist (file absent).
9. `grep -c "proxy_pass http://localhost:9001" /etc/nginx/sites-available/penpot.aiqadam.org` — returns `4` (four proxy_pass directives for ws/notifications, mcp/ws, mcp/stream, and the default `/`).
10. `grep "client_max_body_size" /etc/nginx/sites-available/penpot.aiqadam.org` — returns `client_max_body_size 367001600`.

**External checks:**

1. `curl -I --max-time 10 https://penpot.aiqadam.org` — HTTP/2 200 or 302; `server: nginx`; `ssl-certificate` CN = `penpot.aiqadam.org`; issuer = Let's Encrypt.
2. `curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://penpot.aiqadam.org/` — returns `301` (HTTP→HTTPS redirect).
3. `curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://penpot.aiqadam.org/mcp/stream` — returns `4xx` (401 or 403 = auth-required = proxy working).

---

### Resources used

- **Secrets (by name):** none. The certbot `-m admin@aiqadam.org` email address is a contact address for expiry notices, not a secret.
- **Files modified on host:**
  - `/etc/nginx/sites-available/penpot.aiqadam.org` — created (new file, no backup needed; none existed before)
  - `/etc/nginx/sites-enabled/penpot.aiqadam.org` — symlink created (new)
  - `/etc/nginx/sites-enabled/default` — removed (symlink deleted; original file `/etc/nginx/sites-available/default` untouched)
  - `/etc/letsencrypt/live/penpot.aiqadam.org/` — created by certbot
  - `/etc/letsencrypt/renewal/penpot.aiqadam.org.conf` — created by certbot
  - `/etc/letsencrypt/options-ssl-nginx.conf` — created by certbot (shared options file)
  - `/etc/letsencrypt/ssl-dhparams.pem` — created by certbot (shared DH params)
- **Packages installed on host:** `nginx`, `nginx-common`, `certbot`, `python3-certbot-nginx` (and their apt dependencies).
- **Files modified in this repo (landscape/):** to be applied at step 08:
  - `landscape/hosts/pro-data-tech-prod.md` — update `last_verified_note`, add nginx/TLS status, add `certbot.timer` active note, update `last_verified` date.
  - `landscape/services.md` — add nginx 443/tcp entry for `pro-data-tech-prod`.
- **External APIs called:** Let's Encrypt ACME API (during certbot HTTP-01 challenge). Read-only DNS lookup only; no Cloudflare API calls.

### Estimated impact

- **Downtime:** ~5–10 seconds per `systemctl reload nginx` (two reloads: steps 5 and 8). Nginx reload is graceful (in-flight connections complete); Penpot on `localhost:9001` is unaffected throughout.
- **Affected services:** `penpot.aiqadam.org` (gains HTTPS; HTTP-01 challenge briefly proxies port 80 through nginx instead of directly to Penpot — but port 9001 Docker bypass means direct port 9001 access still works during the operation).
- **Reversibility:** fully reversible via rollback above. No DNS changes. No Cloudflare config changes. Certificate revocation possible if needed (rare).

---

## Issues / risks

- **Port 9001 still externally reachable via Docker iptables bypass (HIGH pre-existing).** After nginx is in place, external traffic can reach Penpot directly on `:9001` without TLS. This bypasses nginx and defeats the HTTPS-only goal. A follow-on task should restrict Docker's `:9001` binding to `127.0.0.1:9001` in the Compose file, or add an explicit iptables drop rule. Not a blocker for T-0109 but should be tracked.
- **Cloudflare proxy must stay OFF during certbot HTTP-01.** If the user enables Cloudflare orange-cloud between DNS confirmation (T-0107) and step 6 of this plan, the HTTP-01 challenge will fail (Cloudflare will answer the challenge instead of the host). Executor must verify `proxied=false` is still in effect immediately before running certbot.
- **`certbot.timer` activation — Ubuntu 26.04 behavior.** On Ubuntu 26.04 (systemd + socket activation), the certbot timer is installed and enabled by the `certbot` package. If the host is in a non-standard state (e.g., timer masked), step 9 will return `inactive` and the executor must `systemctl enable --now certbot.timer`.
- **Let's Encrypt rate limits.** The HTTP-01 challenge for `penpot.aiqadam.org` counts against the Let's Encrypt rate limit for the domain (5 failed authorizations per account per hostname per hour). Prior failed certbot attempts (if any) could exhaust this. Step 0b discovers prior attempts.
- **Approval required because:** this is a first-time nginx + TLS installation on a production host (`pro-data-tech-prod`), involves a Let's Encrypt certificate issuance against a live DNS-linked domain, and installs OS packages. Per `shared/approval-protocol.md`, first-time prod installs and DNS-linked changes always require `NEEDS_APPROVAL`.
