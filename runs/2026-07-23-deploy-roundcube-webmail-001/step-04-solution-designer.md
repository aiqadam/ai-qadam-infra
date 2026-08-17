---
run_id: 2026-07-23-deploy-roundcube-webmail-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-23T00:00:00Z
task_id: T-0122-deploy-roundcube-webmail-pro-data-tech-prod
inputs_read:
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-01-task-reader.md
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-02-landscape-reader.md
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-03-task-validator.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - tasks/T-0122-deploy-roundcube-webmail-pro-data-tech-prod.md
  - credentials.md
artifacts_changed: []
next_step_hint: executor-infra — after user approval (step-05), execute this plan in the order given; confirm loopback port 8888 is free before writing docker-compose.yml; pin the Roundcube image tag at runtime from Docker Hub; verify stalwart-mail_default network exists before starting the container
---

## Summary

Deploy Roundcube webmail as a Docker Compose stack on `pro-data-tech-prod` (95.46.211.224), connected to Stalwart via the shared `stalwart-mail_default` Docker network (IMAP on internal port 143), fronted by a new nginx vhost `webmail.aiqadam.org` with a Let's Encrypt TLS cert, and a new Cloudflare A record → `95.46.211.224` (`proxied: false`); end state: `@aiqadam.org` users can log in and use webmail at `https://webmail.aiqadam.org/`.

## Details

### Design decisions

| Decision | Choice | Rationale |
|---|---|---|
| Docker networking | Join `stalwart-mail_default` (external) | Eliminates cross-bridge forwarding under `DEFAULT_FORWARD_POLICY=DROP`; Roundcube's source IP is `172.19.0.x`, already in Stalwart's `AllowedIp` (`172.19.0.0/16`); no auto-ban risk |
| IMAP connectivity | Port 143 (plain), internal Docker network, host `stalwart-mail-server-1` | No TLS cert mismatch; traffic stays within the Docker bridge (trusted); port 143 is not published to the host but is accessible from containers on the same Docker network |
| SMTP connectivity | Port 587 + STARTTLS, host `mail.aiqadam.org` | Stalwart's TLS cert is issued for `mail.aiqadam.org`, not for `stalwart-mail-server-1`; using the public FQDN avoids TLS hostname verification failure; port 587 is published to `0.0.0.0:587`; from within the container, `mail.aiqadam.org` resolves to `95.46.211.224`, traffic routes via Docker NAT and appears at Stalwart from the bridge gateway IP (`172.19.0.1`) which is in the `AllowedIp` list |
| Roundcube HTTP loopback port | `127.0.0.1:8888` | Not in use: confirmed free per the loopback TCP listener inventory (1080, 8080, 9998, 3115 taken); executor must verify at runtime |
| DNS `proxied` flag | `false` | All comparable this-repo records on this host (`penpot.aiqadam.org`, `mail.aiqadam.org`, `aiqadam.org` apex) use `proxied: false`; **⚠ the task file says "proxied" but the landscape pattern is consistently unproxied** — see Issues / risks; this plan uses `false` and requests confirmation at approval |
| Roundcube DB | SQLite | Per task constraint; eliminates cross-stack PostgreSQL dependency |
| Image tag | `1.6.x-apache` (executor confirms latest stable at runtime) | 1.6 is the current LTS line; the `-apache` variant is the standard full-featured image |

---

### Plan

All SSH commands use: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "sudo <cmd>"`
For multi-line heredocs: open an SSH session and run interactively, or use the SSH stdin patterns shown below.

---

#### Phase 1 — Cloudflare DNS

**Step 1.1** — Pre-flight: verify no existing `webmail.aiqadam.org` A record.

Command (run from management workstation):
```
curl -sf -X GET \
  "https://api.cloudflare.com/client/v4/zones/bec8854d698d56ff17cf917367634100/dns_records?type=A&name=webmail.aiqadam.org" \
  -H "Authorization: Bearer <cloudflare-ai-qadam-api-token, see secrets-inventory.md>" | jq '.result | length'
```
Verification: must return `0`. If non-zero, abort and investigate before proceeding.

Idempotency: safe to re-run; if result is `0`, continue; if result is `1` with `content: "95.46.211.224"` from a prior partial run, retrieve the record ID and skip to step 1.3.

---

**Step 1.2** — Create the A record.

Command (run from management workstation):
```
curl -sf -X POST \
  "https://api.cloudflare.com/client/v4/zones/bec8854d698d56ff17cf917367634100/dns_records" \
  -H "Authorization: Bearer <cloudflare-ai-qadam-api-token, see secrets-inventory.md>" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"webmail.aiqadam.org","content":"95.46.211.224","proxied":false,"ttl":1}'
```

JSON body field reference (Cloudflare Zones/DNS Records API v4):
- `type`: `"A"` — record type
- `name`: `"webmail.aiqadam.org"` — fully-qualified name
- `content`: `"95.46.211.224"` — IPv4 address
- `proxied`: `false` — grey cloud (DNS-only), consistent with all existing this-repo host records
- `ttl`: `1` — auto (must be `1` per Cloudflare requirement when `proxied: false`)

Verification: response must contain `"success": true`. **Capture `result.id` from the response — this is the record ID needed for rollback.** Expected example output:
```json
{"success":true,"result":{"id":"<RECORD_ID>","type":"A","name":"webmail.aiqadam.org","content":"95.46.211.224","proxied":false,...}}
```

Rollback for step 1.2:
```
curl -sf -X DELETE \
  "https://api.cloudflare.com/client/v4/zones/bec8854d698d56ff17cf917367634100/dns_records/<RECORD_ID>" \
  -H "Authorization: Bearer <cloudflare-ai-qadam-api-token, see secrets-inventory.md>"
```

---

**Step 1.3** — Verify A record exists and is correct.

Command (run from management workstation):
```
curl -sf \
  "https://api.cloudflare.com/client/v4/zones/bec8854d698d56ff17cf917367634100/dns_records?type=A&name=webmail.aiqadam.org" \
  -H "Authorization: Bearer <cloudflare-ai-qadam-api-token, see secrets-inventory.md>" \
  | jq '.result[0] | {name, type, content, proxied, ttl}'
```
Expected:
```json
{"name":"webmail.aiqadam.org","type":"A","content":"95.46.211.224","proxied":false,"ttl":1}
```

Supplementary DNS lookup (after propagation, ~60s):
```
nslookup webmail.aiqadam.org 1.1.1.1
```
Expected: `Address: 95.46.211.224`

---

#### Phase 2 — TLS Certificate

**Step 2.1** — Check whether cert already exists (idempotency guard).

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "[ -d /etc/letsencrypt/live/webmail.aiqadam.org ] && echo EXISTS || echo ABSENT"
```
If `EXISTS`: skip steps 2.2 and 2.3; proceed directly to Phase 3.

---

**Step 2.2** — Create a minimal nginx vhost for the ACME HTTP-01 challenge (required before certbot can run).

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "sudo tee /etc/nginx/sites-available/webmail.aiqadam.org > /dev/null" << 'NGINX_EOF'
server {
    listen 80;
    listen [::]:80;
    server_name webmail.aiqadam.org;

    location / {
        return 200 "pre-cert placeholder";
        add_header Content-Type text/plain;
    }
}
NGINX_EOF
```

Then symlink and reload:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo ln -sf /etc/nginx/sites-available/webmail.aiqadam.org /etc/nginx/sites-enabled/webmail.aiqadam.org && sudo nginx -t && sudo nginx -s reload"
```
Verification: `nginx -t` must exit 0. `curl -sf http://webmail.aiqadam.org/` must return `pre-cert placeholder` (or a 301 redirect if Cloudflare forces HTTPS, which is why `proxied: false` is correct here).

Rollback for step 2.2:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo rm -f /etc/nginx/sites-enabled/webmail.aiqadam.org /etc/nginx/sites-available/webmail.aiqadam.org && sudo nginx -s reload"
```

---

**Step 2.3** — Obtain Let's Encrypt certificate via certbot (nginx plugin, HTTP-01).

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo certbot --nginx -d webmail.aiqadam.org --non-interactive --agree-tos -m postmaster@aiqadam.org"
```

Expected output (key lines):
```
Requesting a certificate for webmail.aiqadam.org
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/webmail.aiqadam.org/fullchain.pem
...
Congratulations! You have successfully enabled HTTPS on https://webmail.aiqadam.org
```

Note on HTTP-01 with `proxied: false`: DNS is not proxied through Cloudflare, so the ACME challenge HTTP request goes directly to the origin server's port 80. certbot's nginx plugin adds a `/.well-known/acme-challenge/` location to the running vhost, serves the challenge token, and Let's Encrypt validates it. This is the same mechanism used for `penpot.aiqadam.org` and `mail.aiqadam.org` certs (both `proxied: false`). No issues expected.

Estimated downtime: none — `certbot --nginx` with an existing nginx config uses the plugin to add the challenge location without stopping nginx; it only does a reload.

Verification:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo certbot certificates 2>/dev/null | grep -A4 'webmail.aiqadam.org'"
```
Expected: cert listed, expiry ~90 days out, `Certificate Path: /etc/letsencrypt/live/webmail.aiqadam.org/fullchain.pem`.

Rollback for step 2.3:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo certbot delete --cert-name webmail.aiqadam.org --non-interactive"
```

---

#### Phase 3 — Roundcube Docker Compose

**Step 3.1** — Verify port 8888 is available on the host loopback.

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "sudo ss -tlnp | grep ':8888'"
```
Expected: no output (port free). If port is in use, choose an alternative (8889 or 9090) and substitute that port in all subsequent commands.

---

**Step 3.2** — Verify the `stalwart-mail_default` Docker network exists.

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "docker network inspect stalwart-mail_default --format '{{.Name}}: {{range .IPAM.Config}}{{.Subnet}}{{end}}'"
```
Expected: `stalwart-mail_default: 172.19.0.0/16`

If the network does not exist, abort — Stalwart may be down. Do not proceed until confirmed.

---

**Step 3.3** — Confirm latest stable Roundcube image tag (executor performs at runtime).

Command (from management workstation or the prod host):
```
curl -sf "https://hub.docker.com/v2/repositories/roundcube/roundcubemail/tags?page_size=50&ordering=last_updated" \
  | jq -r '[.results[].name | select(test("^1\\.[0-9]+\\.[0-9]+-apache$"))] | .[0]'
```
This returns the most recently updated stable `1.x.y-apache` tag (expected: `1.6.9-apache` or higher). Substitute the actual tag for `<ROUNDCUBE_TAG>` in step 3.5.

---

**Step 3.4** — Generate the Roundcube cipher key and store in `/opt/roundcube/.env`.

Commands:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "sudo mkdir -p /opt/roundcube && sudo chmod 700 /opt/roundcube"
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "CIPHER_KEY=\$(openssl rand -hex 16); printf 'ROUNDCUBE_CIPHER_KEY=%s\n' \"\$CIPHER_KEY\" | sudo tee /opt/roundcube/.env > /dev/null; sudo chmod 600 /opt/roundcube/.env; echo 'Cipher key written to /opt/roundcube/.env'"
```
Expected: `Cipher key written to /opt/roundcube/.env`

Secret registration: after execution, add `roundcube-cipher-key` to `landscape/secrets-inventory.md` (reference by name only; value stored in `/opt/roundcube/.env` on `pro-data-tech-prod`). This is a landscape-update step (step 08).

---

**Step 3.5** — Write `/opt/roundcube/docker-compose.yml`.

Substitute `<ROUNDCUBE_TAG>` with the tag confirmed in step 3.3 (e.g., `1.6.9-apache`).

Command (run from a local shell and pipe to SSH, or create the file with a heredoc):
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "sudo tee /opt/roundcube/docker-compose.yml > /dev/null" << 'COMPOSE_EOF'
services:
  roundcube:
    image: roundcube/roundcubemail:<ROUNDCUBE_TAG>
    container_name: roundcube-1
    restart: unless-stopped
    ports:
      - "127.0.0.1:8888:80"
    environment:
      ROUNDCUBEMAIL_DEFAULT_HOST: "stalwart-mail-server-1"
      ROUNDCUBEMAIL_DEFAULT_PORT: "143"
      ROUNDCUBEMAIL_SMTP_SERVER: "mail.aiqadam.org"
      ROUNDCUBEMAIL_SMTP_PORT: "587"
      ROUNDCUBEMAIL_DB_TYPE: "sqlite"
      ROUNDCUBEMAIL_DB_DSN: "sqlite:////var/roundcube/db/roundcube.db"
      ROUNDCUBEMAIL_SKIN: "elastic"
      ROUNDCUBEMAIL_PLUGINS: "archive,zipdownload"
      ROUNDCUBEMAIL_CIPHER_KEY: "${ROUNDCUBE_CIPHER_KEY}"
    volumes:
      - roundcube_db:/var/roundcube/db
      - roundcube_config:/var/roundcube/config
      - roundcube_temp:/tmp/roundcube-temp
    networks:
      - stalwart_network

volumes:
  roundcube_db:
  roundcube_config:
  roundcube_temp:

networks:
  stalwart_network:
    external: true
    name: stalwart-mail_default
COMPOSE_EOF
```

Design notes:
- `ROUNDCUBEMAIL_DEFAULT_HOST: stalwart-mail-server-1` with `DEFAULT_PORT: 143` — plain IMAP over the shared Docker bridge; no TLS cert issue; traffic stays on `172.19.0.0/16`.
- `ROUNDCUBEMAIL_SMTP_SERVER: mail.aiqadam.org` — **deliberately uses the public FQDN** (not `stalwart-mail-server-1`) so that STARTTLS on port 587 finds a TLS cert with a matching hostname. If `stalwart-mail-server-1` were used for SMTP, PHP's TLS stream would reject the cert (CN is `mail.aiqadam.org`, not `stalwart-mail-server-1`). Traffic from the container to `mail.aiqadam.org:587` routes to `95.46.211.224:587` via Docker NAT; Stalwart sees the source as the bridge gateway `172.19.0.1` (in the `AllowedIp` list).
- Port `127.0.0.1:8888:80` — loopback-only publish; NOT exposed to `0.0.0.0` (Docker bypasses UFW for `0.0.0.0` binds). Consistent with `aiqadam-prod-api-1` (127.0.0.1:3115) and `aiqadam-prod-oidc-stub-1` (127.0.0.1:9998) patterns.
- `stalwart_network` (external, name `stalwart-mail_default`) — Roundcube is on this network for IMAP. No separate `default` bridge needed because nginx→Roundcube routes via the loopback port (`127.0.0.1:8888`), not via Docker networking.
- `${ROUNDCUBE_CIPHER_KEY}` — resolved from `/opt/roundcube/.env` which Docker Compose auto-reads from the working directory.
- Named volumes `roundcube_db`, `roundcube_config`, `roundcube_temp` — survive container restarts; scoped to the `roundcube` Compose project.

Verification:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo cat /opt/roundcube/docker-compose.yml | head -5"
```
Expected: first lines show `services:` / `roundcube:` / `image: roundcube/roundcubemail:...`.

---

**Step 3.6** — Start the Roundcube container.

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "cd /opt/roundcube && sudo docker compose up -d"
```
Expected output: `Container roundcube-1  Started`

Idempotency: `docker compose up -d` is idempotent; if the container is already running with the same image, it is a no-op.

---

**Step 3.7** — Verify Roundcube container is running and loopback port is bound.

Commands:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo docker compose -f /opt/roundcube/docker-compose.yml ps"
```
Expected: `roundcube-1` with status `running` (Roundcube does not expose a healthcheck by default; `running` is the expected state; allow ~30s for initialization before checking).

```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo ss -tlnp | grep ':8888'"
```
Expected: a LISTEN line on `127.0.0.1:8888` with `docker-proxy` in the process column.

```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "curl -sf -o /dev/null -w '%{http_code}' http://127.0.0.1:8888/"
```
Expected: `200` (Roundcube login page).

Rollback for Phase 3:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo docker compose -f /opt/roundcube/docker-compose.yml down && sudo rm -rf /opt/roundcube"
```
Note: `down` without `-v` preserves named volumes. Use `down -v` only if performing a full rollback (no data to preserve).

---

#### Phase 4 — nginx Vhost (Production Version)

**Step 4.1** — Overwrite the nginx vhost with the production configuration (HTTP redirect + HTTPS proxy_pass).

This step replaces the placeholder created in step 2.2. By this point certbot has already written its SSL directives into the pre-cert file; we overwrite with the clean production version using the known cert paths. Alternatively, if certbot has not yet been run (i.e., step 2.3 was skipped due to idempotency), run `certbot --nginx` before this step.

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 "sudo tee /etc/nginx/sites-available/webmail.aiqadam.org > /dev/null" << 'NGINX_PROD_EOF'
server {
    listen 80;
    listen [::]:80;
    server_name webmail.aiqadam.org;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name webmail.aiqadam.org;

    ssl_certificate /etc/letsencrypt/live/webmail.aiqadam.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/webmail.aiqadam.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 5s;
    }
}
NGINX_PROD_EOF
```

Notes:
- `proxy_read_timeout 300s` — Roundcube uses long-polling for IMAP IDLE; a short timeout would terminate those connections.
- `/.well-known/acme-challenge/` block — required so certbot's renewal cron can serve future HTTP-01 challenges without needing a full nginx stop.
- No `allow`/`deny` directives — this is the public user-facing endpoint (contrast with `mail.aiqadam.org` which has `allow 127.0.0.1; deny all;`).
- The `$host` nginx variables in the heredoc above do NOT need escaping (the heredoc delimiter `'NGINX_PROD_EOF'` in single-quotes prevents shell expansion — they are written literally to the file as `$host`, `$proxy_add_x_forwarded_for`, etc., which is correct for nginx).

**Step 4.2** — Confirm symlink exists (created in step 2.2; verify it is present).

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "ls -la /etc/nginx/sites-enabled/webmail.aiqadam.org"
```
Expected: symlink pointing to `/etc/nginx/sites-available/webmail.aiqadam.org`. If missing, run:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo ln -sf /etc/nginx/sites-available/webmail.aiqadam.org /etc/nginx/sites-enabled/webmail.aiqadam.org"
```

**Step 4.3** — Test and reload nginx.

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo nginx -t && sudo nginx -s reload"
```
Expected: `nginx: the configuration file ... syntax is ok` / `nginx: configuration file ... test is successful` then reload signal sent.

Rollback for Phase 4 (nginx vhost):
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo rm -f /etc/nginx/sites-enabled/webmail.aiqadam.org /etc/nginx/sites-available/webmail.aiqadam.org && sudo nginx -s reload"
```
No rollback needed for `nginx -s reload` itself — it is non-destructive to existing connections.

---

#### Phase 5 — Verification

**Step 5.1** — Loopback HTTPS probe (from the prod host itself).

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "curl -sf https://webmail.aiqadam.org/ -o /dev/null -w '%{http_code}'"
```
Expected: `200`

**Step 5.2** — External HTTPS probe (from management workstation).

Command:
```
curl -sf https://webmail.aiqadam.org/ -o /dev/null -w "%{http_code}"
```
Expected: `200`

Additional check — TLS cert validity:
```
curl -vI https://webmail.aiqadam.org/ 2>&1 | grep -E "subject:|issuer:|expire"
```
Expected: cert issued by Let's Encrypt, CN matches `webmail.aiqadam.org`, not expired.

**Step 5.3** — Check Roundcube container logs for errors.

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo docker compose -f /opt/roundcube/docker-compose.yml logs --tail 30"
```
Expected: Apache startup messages, Roundcube initialization. No `ERROR` or `FATAL` lines. Specifically confirm the line `IMAP connect to stalwart-mail-server-1:143` does NOT appear with a connection refused error (it should not appear at startup — IMAP is only connected at user login).

**Step 5.4** — Live login test (executor performs manually in a browser or via SSH tunnel).

The executor must perform a live browser login to confirm end-to-end IMAP + SMTP functionality:
1. Open `https://webmail.aiqadam.org/` in a browser.
2. Log in with `vladimir.titenko@aiqadam.org` (password from `landscape/secrets-inventory.md` — do NOT log or echo the password in the run file).
3. Verify: the inbox loads with messages (at least the test message sent during T-0117 or T-0121 smoke tests).
4. Compose and send a test message to `postmaster@aiqadam.org`.
5. Verify: no SMTP error banner; the sent message appears in the Sent folder.
6. Log out cleanly.

If the login succeeds but Sent folder is missing: add `ROUNDCUBEMAIL_PLUGINS` to include `sent_folder` (already included via standard Roundcube defaults for the elastic skin).

**Step 5.5** — Confirm mailbox accounts exist in Stalwart (pre-UAT guard).

Command:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo docker exec stalwart-mail-server-1 stalwart-cli account list 2>/dev/null | grep -E 'vladimir|binali|aigerim'"
```
Expected: three accounts listed. If any are missing, the login test for that account will fail — note in the run completion output but do not block task completion if at least `vladimir.titenko` is confirmed.

---

### Rollback sequence (full rollback, if needed after execution)

Perform in this order (reverse of creation):

1. Remove nginx vhost:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo rm -f /etc/nginx/sites-enabled/webmail.aiqadam.org /etc/nginx/sites-available/webmail.aiqadam.org && sudo nginx -s reload"
```

2. Stop and remove Roundcube container (preserve volumes unless full cleanup needed):
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo docker compose -f /opt/roundcube/docker-compose.yml down"
```
Full cleanup (removes volumes too — only if no user data has been created):
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo docker compose -f /opt/roundcube/docker-compose.yml down -v && sudo rm -rf /opt/roundcube"
```

3. Delete TLS cert:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224 \
  "sudo certbot delete --cert-name webmail.aiqadam.org --non-interactive"
```

4. Delete Cloudflare DNS A record (using the record ID captured in step 1.2):
```
curl -sf -X DELETE \
  "https://api.cloudflare.com/client/v4/zones/bec8854d698d56ff17cf917367634100/dns_records/<RECORD_ID>" \
  -H "Authorization: Bearer <cloudflare-ai-qadam-api-token, see secrets-inventory.md>"
```

---

### Verification (for step 07 — execution-validator)

**On-host checks:**
- `docker compose -f /opt/roundcube/docker-compose.yml ps` → `roundcube-1` status `running`
- `ss -tlnp | grep ':8888'` → LISTEN on `127.0.0.1:8888`, process `docker-proxy`
- `ls /etc/nginx/sites-enabled/webmail.aiqadam.org` → symlink exists
- `nginx -t` → exit 0
- `certbot certificates 2>/dev/null | grep -A3 webmail.aiqadam.org` → valid cert, ≥89 days to expiry
- `docker compose -f /opt/roundcube/docker-compose.yml logs --tail 50 2>&1 | grep -i error | wc -l` → `0`
- `curl -sf http://127.0.0.1:8888/ -o /dev/null -w '%{http_code}'` → `200`

**External checks:**
- `curl -sf https://webmail.aiqadam.org/ -o /dev/null -w "%{http_code}"` → `200` (run from management workstation)
- `curl -sI https://webmail.aiqadam.org/ 2>&1 | grep -i "strict-transport"` → HSTS header present (certbot's nginx plugin adds it)
- Cloudflare API: `GET /zones/.../dns_records?type=A&name=webmail.aiqadam.org` → `result[0].content == "95.46.211.224"`, `result[0].proxied == false`
- Live browser login test result (step 5.4) → documented pass/fail by the executor

---

### Resources used

- **Secrets (by name):**
  - `cloudflare-ai-qadam-api-token` (used for DNS record creation — value in `credentials.md` and `landscape/secrets-inventory.md`)
  - `roundcube-cipher-key` (generated at runtime, NEW — to be added to `landscape/secrets-inventory.md`)
  - `stalwart-mail-admin-password` (NOT used by this plan — no Stalwart config changes)
  - `vladimir.titenko@aiqadam.org` mailbox password (used for live login test only — do NOT log; reference `landscape/secrets-inventory.md` for the value at execution time)

- **Files modified on host:**
  - `/opt/roundcube/docker-compose.yml` (new)
  - `/opt/roundcube/.env` (new, chmod 600)
  - `/etc/nginx/sites-available/webmail.aiqadam.org` (new)
  - `/etc/nginx/sites-enabled/webmail.aiqadam.org` (new symlink)
  - `/etc/letsencrypt/live/webmail.aiqadam.org/` (new — certbot-managed)
  - `/etc/letsencrypt/renewal/webmail.aiqadam.org.conf` (new — certbot-managed)
  - Docker named volumes: `roundcube_roundcube_db`, `roundcube_roundcube_config`, `roundcube_roundcube_temp` (new)

- **Files modified in this repo (landscape/) — to be applied at step 08:**
  - `landscape/hosts/pro-data-tech-prod.md` — add Roundcube service entry under Docker stacks; update loopback TCP listener inventory (add `127.0.0.1:8888`); update `last_verified` date
  - `landscape/services.md` — add Roundcube entry
  - `landscape/cloudflare.md` — add `webmail.aiqadam.org` A record to the core web records table; update record count reconciliation; update `last_verified` date
  - `landscape/domains.md` — add `webmail.aiqadam.org` subdomain + TLS cert entry; update `last_verified` date
  - `landscape/secrets-inventory.md` — add `roundcube-cipher-key` entry (name only, value stored in `/opt/roundcube/.env` on `pro-data-tech-prod`)

- **External APIs called:**
  - Cloudflare v4 REST API (GET + POST on `zones/bec8854d698d56ff17cf917367634100/dns_records`)
  - Let's Encrypt ACME v2 (via certbot — HTTP-01 challenge)

---

### Estimated impact

- **Downtime:** none for existing services (`penpot.aiqadam.org`, `aiqadam.org`, `mail.aiqadam.org`). `nginx -s reload` is non-disruptive to established connections. `certbot --nginx` does a reload, not a stop/start (nginx plugin; HTTP-01 challenge only requires adding a location block, not stopping nginx).
- **Affected services:** Roundcube (new), nginx on `pro-data-tech-prod` (reload only). No changes to Stalwart, Penpot, or the AiQadam prod app stack.
- **Reversibility:** fully reversible — stop container, remove vhost, delete DNS record, revoke cert; no changes to existing services.

## Issues / risks

- **⚠ DNS `proxied` flag discrepancy (MEDIUM — requires user confirmation at approval):** The task file says "proxied (orange-cloud)" but ALL comparable this-repo records on this host (`penpot.aiqadam.org`, `mail.aiqadam.org`, `aiqadam.org` apex, `qa-uz.aiqadam.org`) use `proxied: false`. This plan uses `proxied: false` for consistency, simplicity, and to avoid certbot HTTP-01 complications (if Cloudflare's proxy enforces HTTPS-only, the HTTP-01 challenge could be broken). **The user must confirm at approval whether `proxied: false` (recommended, matching existing pattern) or `proxied: true` is intended.** If `proxied: true` is required: the certbot HTTP-01 flow will still work (Cloudflare forwards HTTP requests to the origin when proxying), but the executor must verify that Cloudflare's "Always Use HTTPS" page rule is NOT active for the zone (otherwise HTTP-01 challenge URLs will receive a redirect before reaching the origin).

- **SMTP hostname deviation from user spec (LOW — design necessity):** The user specified `ROUNDCUBEMAIL_SMTP_SERVER=stalwart-mail-server-1`, but this plan uses `ROUNDCUBEMAIL_SMTP_SERVER=mail.aiqadam.org`. Reason: Stalwart's TLS cert is for `mail.aiqadam.org`; PHP's TLS stream library performs hostname verification against the connected hostname, so connecting to `stalwart-mail-server-1:587` with STARTTLS would fail certificate validation. Using `mail.aiqadam.org` as the SMTP hostname resolves to the same host, the cert matches, and the traffic routes correctly. If `stalwart-mail-server-1` is required (e.g., to avoid external DNS lookup), TLS cert verification must be disabled via a custom `config.inc.php` override in the `roundcube_config` volume — the executor can add this if the default does not work. Flag at approval if the deviation is a concern.

- **Port 143 (plain IMAP) not verified as exposed on the Stalwart container's internal network:** The landscape only documents Stalwart's published host ports (993 for IMAP). Port 143 is NOT published to the host. However, Stalwart almost certainly binds 143 internally (standard IMAP daemon behavior), and container-to-container connectivity on the same Docker bridge does not require port publishing. The executor should verify at runtime with: `docker exec stalwart-mail-server-1 ss -tlnp | grep ':143'`. If port 143 is NOT listening inside the Stalwart container, fall back to IMAPS on port 993 with the SMTP hostname approach (`ssl://stalwart-mail-server-1:993` or `ssl://mail.aiqadam.org:993`).

- **Unconfirmed mailbox provisioning (LOW):** The three `@aiqadam.org` mailboxes (`vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva`) are referenced in the task but not confirmed in the landscape. Step 5.5 adds a live check. UAT for the browser login test requires at least one confirmed mailbox; `aigerim.kambetbayeva@aiqadam.org` has a known temp password (`AiQ-temp-2026!`) from the task file — the account owner MUST be notified to change it after first login. This is out of scope for this task but must be in completion notes.

- **Roundcube image `latest` / moving tag (LOW):** This plan uses a pinned `1.6.x-apache` tag confirmed at runtime. Do NOT use `:latest`; use the specific tag for reproducibility and rollback.

- **`aigerim.kambetbayeva@aiqadam.org` temp password in task file:** Value `AiQ-temp-2026!` appears in `tasks/T-0122-...md` and in step-01 handoff. The executor must NOT log, echo, or paste this value in any run file. The live login test (step 5.4) should be performed with `vladimir.titenko@aiqadam.org` for the UAT flow.

## Open questions (optional)

- none — plan is complete; only user confirmation of the `proxied` flag decision is outstanding, which is a pre-execution choice (surfaced at approval).
