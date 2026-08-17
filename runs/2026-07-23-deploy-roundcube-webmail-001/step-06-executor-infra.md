---
run_id: 2026-07-23-deploy-roundcube-webmail-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-23T06:45:00Z
task_id: T-0122-deploy-roundcube-webmail-pro-data-tech-prod
inputs_read:
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-04-solution-designer.md
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-05-user-approval.md
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-02-landscape-reader.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - credentials.md
artifacts_changed:
  - "cloudflare: A record webmail.aiqadam.org → 95.46.211.224 (id d44ce1ab6990cf47848148634809463d, proxied=false, ttl=1)"
  - "pro-data-tech-prod: /etc/letsencrypt/live/webmail.aiqadam.org/ (new cert, ECDSA, expires 2026-10-21)"
  - "pro-data-tech-prod: /etc/letsencrypt/renewal/webmail.aiqadam.org.conf (new)"
  - "pro-data-tech-prod: /etc/nginx/sites-available/webmail.aiqadam.org (new)"
  - "pro-data-tech-prod: /etc/nginx/sites-available/webmail.aiqadam.org.pre-prod.bak (backup)"
  - "pro-data-tech-prod: /etc/nginx/sites-enabled/webmail.aiqadam.org (new symlink)"
  - "pro-data-tech-prod: /opt/roundcube/docker-compose.yml (new)"
  - "pro-data-tech-prod: /opt/roundcube/.env (new, chmod 600 — roundcube-cipher-key stored here)"
  - "pro-data-tech-prod: Docker container roundcube-1 (new, image roundcube/roundcubemail:1.6.17-apache)"
  - "pro-data-tech-prod: Docker named volumes roundcube_roundcube_db, roundcube_roundcube_config, roundcube_roundcube_temp (new)"
next_step_hint: execution-validator — verify all artefacts; note IMAP deviation (143→993 IMAPS via mail.aiqadam.org); live browser login test should be performed by the user; then landscape-updater (step 08) to update cloudflare.md, services.md, hosts/pro-data-tech-prod.md, domains.md, secrets-inventory.md
---

## Summary

Executed all 5 phases of the approved plan (20 of 20 steps) against `pro-data-tech-prod` (95.46.211.224). Cloudflare A record created, Let's Encrypt TLS cert obtained (ECDSA, 89 days), Roundcube 1.6.17-apache Docker container started and healthy on loopback port 8888, nginx vhost live. External HTTPS probe from management workstation confirms `https://webmail.aiqadam.org/` returns HTTP 200 with full Roundcube login page. One design deviation applied: Stalwart does not bind port 143 internally (confirmed via `/proc/net/tcp6`), so IMAP falls back to IMAPS on port 993 via `ssl://mail.aiqadam.org` per the solution designer's documented fallback.

## Details

### Pre-execution checks

- Approval handoff verified: yes
- step-04 verdict: `NEEDS_APPROVAL` ✓
- step-05 verdict: `APPROVED` ✓
- step-05 `inputs_read` lists `step-04-solution-designer.md` ✓
- Design references match: yes

---

### Execution log

#### Phase 1 — Cloudflare DNS

##### Step 1.1 — Pre-flight: verify no existing webmail.aiqadam.org A record
- Command: `Invoke-RestMethod GET .../dns_records?type=A&name=webmail.aiqadam.org`
- Exit code: 0
- Output: empty array (no existing record)
- Result: success

##### Step 1.2 — Create Cloudflare A record
- Command: `Invoke-RestMethod POST .../dns_records` with body `{"type":"A","name":"webmail.aiqadam.org","content":"95.46.211.224","proxied":false,"ttl":1}`
- Exit code: 0
- Output (trimmed):
  ```json
  {"result":{"id":"d44ce1ab6990cf47848148634809463d","name":"webmail.aiqadam.org","type":"A","content":"95.46.211.224","proxied":false,"ttl":1,...},"success":true}
  ```
- Result: success
- DNS record ID: `d44ce1ab6990cf47848148634809463d` (retained for rollback if needed)

##### Step 1.3 — Verify A record
- Command: `Invoke-RestMethod GET .../dns_records?type=A&name=webmail.aiqadam.org`
- Exit code: 0
- Output:
  ```json
  {"name":"webmail.aiqadam.org","type":"A","content":"95.46.211.224","proxied":false,"ttl":1}
  ```
- Result: success

---

#### Phase 2 — TLS Certificate

##### Step 2.1 — Check cert existence (idempotency guard)
- Command: `ssh ... "[ -d /etc/letsencrypt/live/webmail.aiqadam.org ] && echo EXISTS || echo ABSENT"`
- Exit code: 0
- Output: `ABSENT`
- Result: cert absent; proceeding with steps 2.2 and 2.3

##### Step 2.2 — Create placeholder nginx vhost for ACME HTTP-01 challenge
- Initial write attempt used `return 200 "string"` syntax — rejected by nginx (invalid number of arguments in "return" directive).
- Fixed by using `root /var/www/html; try_files $uri $uri/ =404;` instead.
- Command (final): heredoc `cat << 'NGINX_EOF' | sudo tee /etc/nginx/sites-available/webmail.aiqadam.org > /dev/null` + `sudo ln -sf ... && sudo nginx -t && sudo nginx -s reload`
- Exit code: 0
- Output:
  ```
  nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
  nginx: configuration file /etc/nginx/nginx.conf test is successful
  [notice] signal process started
  nginx reloaded OK
  ```
- Result: success

##### Step 2.3 — Obtain Let's Encrypt certificate
- Command: `sudo certbot --nginx -d webmail.aiqadam.org --non-interactive --agree-tos -m postmaster@aiqadam.org`
- Exit code: 0
- Output (trimmed):
  ```
  Requesting a certificate for webmail.aiqadam.org
  Successfully received certificate.
  Certificate is saved at: /etc/letsencrypt/live/webmail.aiqadam.org/fullchain.pem
  Key is saved at:         /etc/letsencrypt/live/webmail.aiqadam.org/privkey.pem
  This certificate expires on 2026-10-21.
  Successfully deployed certificate for webmail.aiqadam.org to /etc/nginx/sites-enabled/webmail.aiqadam.org
  Congratulations! You have successfully enabled HTTPS on https://webmail.aiqadam.org
  ```
- Verification: `sudo certbot certificates` →
  ```
  Certificate Name: webmail.aiqadam.org
    Serial Number: 69e579ea101905c88703c92c57263c1ed34
    Key Type: ECDSA
    Domains: webmail.aiqadam.org
    Expiry Date: 2026-10-21 05:32:03+00:00 (VALID: 89 days)
    Certificate Path: /etc/letsencrypt/live/webmail.aiqadam.org/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/webmail.aiqadam.org/privkey.pem
  ```
- Result: success

---

#### Phase 3 — Roundcube Docker Compose

##### Step 3.1 — Verify port 8888 available
- Command: `sudo ss -tlnp | grep ':8888'`
- Output: `PORT FREE` (no output from grep)
- Result: success; port 8888 confirmed available

##### Step 3.2 — Verify stalwart-mail_default network
- Command: `docker network inspect stalwart-mail_default --format '{{.Name}}: ...'`
- Output: `stalwart-mail_default: 172.19.0.0/16`
- Result: success; network confirmed

##### Step 3.3 — IMAP port discovery (critical deviation from plan)
- Command: `sudo docker exec stalwart-mail-server-1 cat /proc/net/tcp6` — decoded listening ports: 25, 443, 465, 587, 993, 995, 4190, 8080
- **Port 143 is NOT bound inside the Stalwart container.**
- Confirmed by `/proc/net/tcp6` (state 0A = LISTEN): none of the hex port values equals `0x8F` (143 decimal).
- Published ports via `sudo docker port stalwart-mail-server-1`: `25, 465, 587, 993, 8080` — no 143.
- **Decision: fall back to IMAPS on port 993 via `ssl://mail.aiqadam.org`** per solution designer's documented fallback (step-04, Issues/risks section, "Port 143 (plain IMAP)...").
- IMAP reachability from Roundcube container verified: `openssl s_client -connect mail.aiqadam.org:993 -brief` from inside container returned `CONNECTION ESTABLISHED / Protocol: TLSv1.3 / Ciphersuite: TLS_AES_256_GCM_SHA384 / Peer certificate: CN=*.aiqadam.org`.

##### Step 3.3 — Latest Roundcube image tag
- Command: Docker Hub API query for `roundcube/roundcubemail` tags matching `^1\.[0-9]+\.[0-9]+-apache$`
- Result: `1.6.17-apache` (most recently updated stable tag)

##### Step 3.4 — Create /opt/roundcube and generate cipher key
- Command: `sudo mkdir -p /opt/roundcube && sudo chmod 755 /opt/roundcube && CIPHER_KEY=$(openssl rand -hex 16); printf 'ROUNDCUBE_CIPHER_KEY=%s\n' "$CIPHER_KEY" | sudo tee /opt/roundcube/.env > /dev/null; sudo chmod 600 /opt/roundcube/.env`
- Exit code: 0
- Output: `Cipher key written to /opt/roundcube/.env`
- Result: success; cipher key (32-char hex, value NOT recorded here) stored in `/opt/roundcube/.env`, mode 600

##### Step 3.5 — Write /opt/roundcube/docker-compose.yml
- Applied IMAP fallback: `ROUNDCUBEMAIL_DEFAULT_HOST: "ssl://mail.aiqadam.org"`, `ROUNDCUBEMAIL_DEFAULT_PORT: "993"` (deviation from plan's 143/stalwart-mail-server-1)
- Image pinned to `roundcube/roundcubemail:1.6.17-apache`
- Container name: `roundcube-1`
- Port: `127.0.0.1:8888:80` (loopback-only, consistent with existing patterns)
- Network: `stalwart_network` (external, name `stalwart-mail_default`) — Roundcube container IP 172.19.0.3, in Stalwart AllowedIp range 172.19.0.0/16 → auto-ban protection active
- Volumes: `roundcube_db`, `roundcube_config`, `roundcube_temp`
- Cipher key: resolved from `/opt/roundcube/.env` via `${ROUNDCUBE_CIPHER_KEY}` (Docker Compose auto-reads .env)
- Exit code: 0; head -5 verified: `services: / roundcube: / image: roundcube/roundcubemail:1.6.17-apache`
- Result: success

##### Step 3.6 — Start container
- Attempted with directory permissions 700 — `cd /opt/roundcube` returned `Permission denied` for non-root user; fixed with `sudo chmod 755 /opt/roundcube`
- Command: `sudo chmod 755 /opt/roundcube && cd /opt/roundcube && sudo docker compose up -d`
- Image pulled from Docker Hub (1.6.17-apache, ~300MB)
- Exit code: 0
- Container status check:
  ```
  NAME         IMAGE                                   COMMAND                STATUS         PORTS
  roundcube-1  roundcube/roundcubemail:1.6.17-apache  "/docker-entrypoint…"  Up 23 seconds  127.0.0.1:8888->80/tcp
  ```
- Result: success

##### Step 3.7 — Verify container and loopback port
- `sudo ss -tlnp | grep ':8888'`: `LISTEN 0 4096 127.0.0.1:8888 0.0.0.0:* users:(("docker-proxy",pid=3668304,fd=8))` ✓
- `curl -sf -o /dev/null -w '%{http_code}' http://127.0.0.1:8888/`: `200` ✓
- Result: success

---

#### Phase 4 — nginx Vhost (Production)

##### Step 4.0 — Backup certbot-modified placeholder
- certbot had modified the placeholder vhost with SSL directives (standard certbot --nginx behavior)
- Command: `sudo cp /etc/nginx/sites-available/webmail.aiqadam.org /etc/nginx/sites-available/webmail.aiqadam.org.pre-prod.bak`
- Exit code: 0
- Backup path: `/etc/nginx/sites-available/webmail.aiqadam.org.pre-prod.bak`
- Result: success

##### Step 4.1 — Write production nginx vhost
- Command: heredoc `cat << 'NGINX_PROD_EOF' | sudo tee /etc/nginx/sites-available/webmail.aiqadam.org > /dev/null`
- Config written:
  - HTTP server: listens 80/[::]:80; `/.well-known/acme-challenge/` → `/var/www/html`; all other paths → 301 HTTPS redirect
  - HTTPS server: listens 443 ssl/[::]:443 ssl; `http2 on`; cert paths from Let's Encrypt; `proxy_pass http://127.0.0.1:8888`; `proxy_read_timeout 300s`
- Exit code: 0; output: `Production vhost written`
- Result: success

##### Step 4.2 — Confirm symlink
- Command: `ls -la /etc/nginx/sites-enabled/webmail.aiqadam.org`
- Output: `lrwxrwxrwx 1 root root 46 Jul 23 06:30 ... -> /etc/nginx/sites-available/webmail.aiqadam.org` ✓
- Result: symlink confirmed present (created by certbot in step 2.3)

##### Step 4.3 — Test and reload nginx
- Command: `sudo nginx -t && sudo nginx -s reload`
- Exit code: 0
- Output:
  ```
  nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
  nginx: configuration file /etc/nginx/nginx.conf test is successful
  [notice] signal process started
  nginx reload OK
  ```
- Result: success

---

#### Phase 5 — Verification

##### Step 5.1 — Loopback HTTPS probe (from prod host)
- Command: `curl -sf https://webmail.aiqadam.org/ -o /dev/null -w 'HTTP:%{http_code}'`
- Output: `HTTP:200` ✓
- Roundcube login page content check: matched `<title>Roundcube Webmail :: Welcome to Roundcube Webmail</title>` ✓
- Result: success

##### Step 5.2 — External HTTPS probe (from management workstation)
- Command: `Invoke-WebRequest -Uri "https://webmail.aiqadam.org/"`
- Output: `HTTP:200`; full Roundcube login page HTML confirmed (title, login form, Elastic skin, rcversion 10617)
- Result: success

##### Step 5.3 — Container logs (no errors)
- Final container log check shows clean startup:
  ```
  Running pre-setup tasks: ... ROUNDCUBEMAIL has been successfully copied
  Write root config to /var/www/html/config/config.inc.php
  Write Docker config to /var/www/html/config/config.docker.inc.php
  Checking for database schema updates...
  Running post-setup tasks:
  AH00558: ... Could not reliably determine FQDN, using 172.19.0.3
  [mpm_prefork:notice] Apache/2.4.68 (Debian) PHP/8.4.23 configured -- resuming normal operations
  ```
  No ERROR or FATAL lines. SQLite DB initialized. HTTP 200 for all probes.
- Container IP: `172.19.0.3` (within 172.19.0.0/16 — Stalwart AllowedIp range) ✓
- Result: success

##### Step 5.4 — IMAP connectivity from container
- IMAP TLS test via `openssl s_client -connect mail.aiqadam.org:993 -brief` from inside `roundcube-1`:
  ```
  Connecting to 95.46.211.224
  CONNECTION ESTABLISHED
  Protocol version: TLSv1.3
  Ciphersuite: TLS_AES_256_GCM_SHA384
  Peer certificate: CN=*.aiqadam.org
  ```
- IMAP CAPABILITY response received successfully: `IMAP4rev2 IMAP4rev1 ENABLE SASL-IR LITERAL+ ID UTF8=ACCEPT AUTH=PLAIN AUTH=OAUTHBEARER AUTH=XOAUTH2`
- Result: IMAP connectivity confirmed

##### Step 5.5 — Live browser login test (manual step)
- Automated IMAP credential test was not run (credentials must not be written to handoff or echoed).
- **This step must be completed manually by the user**: open `https://webmail.aiqadam.org/`, log in with a valid `@aiqadam.org` mailbox, verify inbox loads and SMTP send works.
- Note: `stalwart-cli` binary is not in the Stalwart container's `$PATH` (`/usr/local/bin/stalwart` is the server binary only, not a CLI management tool); account list via REST API returned 404 for queried paths. Suggest verifying account existence via the Stalwart admin web UI at `http://127.0.0.1:8080` (loopback-only, SSH tunnel required).

---

### Rollback executed

Not needed — all steps succeeded.

---

### Resources changed

**Files on host (pro-data-tech-prod, 95.46.211.224):**
- `/opt/roundcube/` (new directory, mode 755)
- `/opt/roundcube/docker-compose.yml` (new)
- `/opt/roundcube/.env` (new, mode 600 — roundcube-cipher-key value stored here)
- `/etc/nginx/sites-available/webmail.aiqadam.org` (new production vhost)
- `/etc/nginx/sites-available/webmail.aiqadam.org.pre-prod.bak` (backup of certbot-modified placeholder)
- `/etc/nginx/sites-enabled/webmail.aiqadam.org` (new symlink → sites-available)
- `/etc/letsencrypt/live/webmail.aiqadam.org/` (new — certbot-managed; fullchain.pem, privkey.pem)
- `/etc/letsencrypt/renewal/webmail.aiqadam.org.conf` (new — certbot-managed)

**Services restarted / signaled:**
- nginx — `nginx -s reload` x3 (placeholder setup, certbot deploy, production vhost)

**Docker resources created:**
- Container: `roundcube-1` (image `roundcube/roundcubemail:1.6.17-apache`, network `stalwart-mail_default`, port `127.0.0.1:8888:80`)
- Named volumes: `roundcube_roundcube_db`, `roundcube_roundcube_config`, `roundcube_roundcube_temp`

**External resources changed:**
- Cloudflare DNS: A record `webmail.aiqadam.org → 95.46.211.224` created (record ID `d44ce1ab6990cf47848148634809463d`, proxied=false, ttl=1)
- Let's Encrypt ACME: TLS certificate issued for `webmail.aiqadam.org` (ECDSA, expires 2026-10-21, serial `69e579ea101905c88703c92c57263c1ed34`)

## Issues / risks

- **IMAP deviation (documented):** Plan used port 143 (plain IMAP, `stalwart-mail-server-1`) but Stalwart does not bind port 143 internally (confirmed via `/proc/net/tcp6`). Applied fallback per solution designer: `ssl://mail.aiqadam.org:993` (IMAPS). Traffic from the Roundcube container at `172.19.0.3` routes via Docker NAT to `95.46.211.224:993`; TLS cert CN=`*.aiqadam.org` matches `mail.aiqadam.org`. This is a working configuration but adds a loopback hop vs. pure Docker-bridge IMAP. No functional impact expected.

- **`AH00558` Apache FQDN warning in container logs:** `apache2: Could not reliably determine the server's fully qualified domain name, using 172.19.0.3`. This is cosmetic — the container's hostname is not set and Apache falls back to its bridge IP. No impact on functionality; Roundcube does not use the Apache ServerName for IMAP/SMTP connections.

- **Live browser login test pending:** Step 5.5 (end-to-end IMAP login via browser) could not be automated in this executor context. The user must complete a manual login test to confirm the full IMAP/SMTP flow works.

- **Roundcube cipher key:** Generated as a random 32-character hex string via `openssl rand -hex 16`. Stored in `/opt/roundcube/.env` (mode 600, owner root) on `pro-data-tech-prod`. Must be added to `landscape/secrets-inventory.md` in step 08 (landscape-updater) by name only.

- **`aigerim.kambetbayeva@aiqadam.org` temp password:** Not logged or echoed anywhere in this run. The account owner must be notified to change their password after first login. This is out of scope for this task.

## Open questions

- Are the three expected `@aiqadam.org` mailboxes (`vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva`) confirmed active in Stalwart? `stalwart-cli` is not in the container's PATH and REST API paths returned 404. Verify via Stalwart admin UI (`http://127.0.0.1:8080`, SSH tunnel required) or by attempting IMAP LOGIN.
- Should `stalwart-mail-server-1` be configured to listen on port 143 internally for future use (would enable plain IMAP without TLS loopback hop)? Out of scope for this task but may be worth a follow-on.
