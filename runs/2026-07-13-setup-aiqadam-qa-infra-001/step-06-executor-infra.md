---
run_id: 2026-07-13-setup-aiqadam-qa-infra-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-13T07:05:00Z
task_id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
retry_of: step-06
inputs_read:
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md (rename plan, NEEDS_APPROVAL)
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-05-user-approval.md (APPROVED)
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/.attempts/step-06-executor-infra-attempt-3.md (prior FAIL context — Phases 4-9 confirmed live/healthy)
  - landscape/cloudflare.md
  - landscape/secrets-inventory.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - credentials.md
artifacts_changed:
  - Cloudflare DNS A record qa-uz.aiqadam.org (zone aiqadam.org — new, record ID 53aa89ca061e343291f33bb7b8b3a12e, -> 95.46.211.230, proxied false, ttl 1)
  - Cloudflare DNS A record qa.aiqadam.org (zone aiqadam.org — deleted, was record ID c39c16816fc23946882d9e845f79c6c2)
  - /etc/nginx/sites-available/qa-uz.aiqadam.org (host: pro-data-tech-qa — new, final production vhost with proxy_pass to 127.0.0.1:3113)
  - /etc/nginx/sites-enabled/qa-uz.aiqadam.org (host: pro-data-tech-qa — new symlink)
  - /etc/nginx/sites-available/qa.aiqadam.org.bak.rename.20260713T065654Z (host: pro-data-tech-qa — backup of removed vhost)
  - /etc/nginx/sites-available/qa-uz.aiqadam.org.bak.certbot.20260713T065827Z (host: pro-data-tech-qa — backup of certbot-only-modified vhost, pre-finalization)
  - /etc/nginx/sites-available/qa.aiqadam.org (host: pro-data-tech-qa — removed source file left in place as historical artifact; symlink removed)
  - /etc/nginx/sites-enabled/qa.aiqadam.org (host: pro-data-tech-qa — removed symlink)
  - /etc/letsencrypt/live/qa-uz.aiqadam.org/*, /etc/letsencrypt/renewal/qa-uz.aiqadam.org.conf (host: pro-data-tech-qa — new Let's Encrypt cert, ECDSA, expires 2026-10-11)
  - /etc/letsencrypt/live/qa.aiqadam.org/*, /etc/letsencrypt/renewal/qa.aiqadam.org.conf (host: pro-data-tech-qa — deleted via certbot delete, tar-archived first)
  - /var/backups/letsencrypt-qa.aiqadam.org.pre-delete.20260713T065931Z.tar.gz (host: pro-data-tech-qa — new, cert+renewal-conf backup archive, 930 bytes)
  - /opt/apps/aiqadam-qa/deploy/.env (host: pro-data-tech-qa — WEB_BASE_URL and OIDC_REDIRECT_URI updated to qa-uz.aiqadam.org; backup at .env.bak.rename.20260713T070007Z)
  - aiqadam-qa-api-1 (Docker container, host: pro-data-tech-qa — force-recreated to pick up new .env, healthy, RestartCount=0)
next_step_hint: Route to execution-validator (step 07). All Phases A-F of the approved rename plan completed and independently verified. End state: qa-uz.aiqadam.org is live over HTTPS, proxying correctly to the existing api container, resolving to tenant uz via the documented default-tenant-fallback path. qa.aiqadam.org is fully decommissioned (DNS record deleted, vhost removed, cert deleted, all with backups). One deviation from the plan's literal step-17 expectation is documented below (root-path HEAD returns 404, not 200) — this is app-level routing behavior (no handler for GET /), not an infra defect; the actual acceptance-relevant path (/health) returns exactly the specified 200 + "status":"ok" both on-host and externally. Flag this for the validator's attention so it is not mistaken for a fresh regression.
---

## Summary
Executed all 20 steps of Phases A through F of the approved rename plan without any failure or rollback: created and verified the new `qa-uz.aiqadam.org` Cloudflare A record, deleted the orphaned `qa.aiqadam.org` record, replaced the nginx vhost, issued a new Let's Encrypt certificate and finalized the production proxy config, deleted the orphaned old certificate (backed up first), updated `.env`'s hostname-dependent lines and recreated the `api` container (backed up first), and confirmed the new hostname is fully live and healthy both on-host and externally; the old hostname no longer resolves to this host.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (`runs/2026-07-13-setup-aiqadam-qa-infra-001/step-05-user-approval.md`)
- Design references match: yes — step-05's `inputs_read` lists `runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md`
- step-04 verdict: `NEEDS_APPROVAL` → step-05 required and present → confirmed `verdict: APPROVED`

### Execution log

#### Phase A, Step 1: Confirm containers healthy
- Command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "docker ps --filter name=aiqadam-qa --format '{{.Names}} {{.Status}}'"`
- Exit code: 0
- Output:
  ```
  aiqadam-qa-api-1 Up 2 hours (healthy)
  aiqadam-qa-oidc-stub-1 Up 2 hours (healthy)
  ```
- Result: success

#### Phase A, Step 2: Confirm current cert state
- Command: `ssh ... "sudo certbot certificates 2>&1 | grep -A4 'qa.aiqadam.org'"`
- Exit code: 0
- Output:
  ```
  Certificate Name: qa.aiqadam.org
    Serial Number: 5499a8283f9105f34e6ef2205ad92071f00
    Key Type: ECDSA
    Domains: qa.aiqadam.org
    Expiry Date: 2026-10-11 04:24:39+00:00 (VALID: 89 days)
  ```
- Result: success

#### Phase A, Step 3: Confirm current Cloudflare record
- Command: `curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records/c39c16816fc23946882d9e845f79c6c2" -H "Authorization: Bearer <token>" -H "Content-Type: application/json"`
- Exit code: 0
- Output: `{"result":{"id":"c39c16816fc23946882d9e845f79c6c2","name":"qa.aiqadam.org","type":"A","content":"95.46.211.230","proxiable":true,"proxied":false,"ttl":1,...},"success":true,...}`
- Result: success — exact record body captured for rollback purposes.

#### Phase B, Step 4: Idempotency check before create
- Command: `curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records?type=A&name=qa-uz.aiqadam.org" -H "Authorization: Bearer <token>" -H "Content-Type: application/json"`
- Exit code: 0
- Output: `{"result":[],"success":true,...,"result_info":{...,"count":0,...}}`
- Result: success — `count:0` confirmed, no duplicate risk.

#### Phase B, Step 5: Create new A record
- Command: `curl -s -X POST "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records" -H "Authorization: Bearer <token>" -H "Content-Type: application/json" --data '{"type":"A","name":"qa-uz.aiqadam.org","content":"95.46.211.230","proxied":false,"ttl":1}'`
- Exit code: 0
- Output: `{"result":{"id":"53aa89ca061e343291f33bb7b8b3a12e","name":"qa-uz.aiqadam.org","type":"A","content":"95.46.211.230","proxiable":true,"proxied":false,"ttl":1,...},"success":true,...}`
- Verification GET re-run: `count:1`, fields match exactly.
- Result: success. New record ID (for rollback): `53aa89ca061e343291f33bb7b8b3a12e`.

#### Phase B, Step 6: Delete orphaned old record
- Command: `curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records/c39c16816fc23946882d9e845f79c6c2" -H "Authorization: Bearer <token>"`
- Exit code: 0
- Output: `{"result":{"id":"c39c16816fc23946882d9e845f79c6c2"},"success":true,"errors":[],"messages":[]}`
- Verification: `GET /zones/<zone-id>/dns_records?type=A&name=qa.aiqadam.org` → `count:0`.
- Result: success. Backup: full record body captured in Phase A step 3. No other of the 32 zone records touched (confirmed by name-scoped GET/POST/DELETE targeting only these two exact names).

#### Phase C, Step 7: Back up current vhost
- Command: `ssh ... "sudo cp /etc/nginx/sites-available/qa.aiqadam.org /etc/nginx/sites-available/qa.aiqadam.org.bak.rename.20260713T065654Z"`
- Exit code: 0
- Verification: `sudo test -s /etc/nginx/sites-available/qa.aiqadam.org.bak.rename.20260713T065654Z && echo OK` → `OK` (712 bytes)
- Result: success
- Backup taken: `/etc/nginx/sites-available/qa.aiqadam.org.bak.rename.20260713T065654Z`

#### Phase C, Step 8: Write new HTTP-only vhost
- Method: local scratchpad file + `scp` (avoids nested-heredoc shell-escaping hazard from prior attempts).
- Command: `scp -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes <local-file> tvolodi@95.46.211.230:/tmp/qa-uz.aiqadam.org.http-only` then `ssh ... "sudo cp /tmp/... /etc/nginx/sites-available/qa-uz.aiqadam.org && rm -f /tmp/..."`
- Exit code: 0
- Verification: `cat /etc/nginx/sites-available/qa-uz.aiqadam.org` showed exact content, `$host`/`$request_uri` preserved literally.
- Result: success

#### Phase C, Step 9: Enable new vhost, disable/remove old
- Command: `ssh ... "sudo ln -sf /etc/nginx/sites-available/qa-uz.aiqadam.org /etc/nginx/sites-enabled/qa-uz.aiqadam.org && sudo rm -f /etc/nginx/sites-enabled/qa.aiqadam.org"`
- Exit code: 0
- Verification: `ls -la /etc/nginx/sites-enabled/` → only `qa-uz.aiqadam.org` present, `qa.aiqadam.org` absent.
- Result: success

#### Phase C, Step 10: Test and reload
- Command: `ssh ... "sudo nginx -t && sudo systemctl reload nginx && systemctl is-active nginx"`
- Exit code: 0
- Output: `syntax is ok` / `test is successful` / `active`
- Result: success

#### Phase D, Step 11: Issue new certificate
- Command: `ssh ... "sudo certbot --nginx -d qa-uz.aiqadam.org --non-interactive --agree-tos -m admin@aiqadam.org"`
- Exit code: 0
- Output (trimmed):
  ```
  Successfully received certificate.
  Certificate is saved at: /etc/letsencrypt/live/qa-uz.aiqadam.org/fullchain.pem
  Key is saved at:         /etc/letsencrypt/live/qa-uz.aiqadam.org/privkey.pem
  This certificate expires on 2026-10-11.
  Successfully deployed certificate for qa-uz.aiqadam.org to /etc/nginx/sites-enabled/qa-uz.aiqadam.org
  Congratulations! You have successfully enabled HTTPS on https://qa-uz.aiqadam.org
  ```
- Verification: `sudo certbot certificates` shows `Certificate Name: qa-uz.aiqadam.org`, `Expiry Date: 2026-10-11 05:59:36+00:00 (VALID: 89 days)`.
- Result: success

#### Phase D, Step 12: Post-certbot vhost finalization
- Inspection: certbot merged the redirect into the `location /` block and appended SSL directives (`listen 443 ssl; # managed by Certbot`, cert/key paths, `options-ssl-nginx.conf`, `ssl_dhparam`) but did not add `proxy_pass` — exactly the documented pattern.
- Backup command: `ssh ... "sudo cp /etc/nginx/sites-available/qa-uz.aiqadam.org /etc/nginx/sites-available/qa-uz.aiqadam.org.bak.certbot.20260713T065827Z"` — verified non-empty (787 bytes).
- Final vhost written via local scratchpad + `scp`, matching the confirmed-working `qa.aiqadam.org` production vhost's exact structure (two server blocks: HTTP redirect on 80, HTTPS on 443 with `proxy_set_header Host $http_host`, `X-Real-IP`, `X-Scheme`, `X-Forwarded-Proto`, `X-Forwarded-For`, `proxy_redirect off`, `proxy_pass http://127.0.0.1:3113/`), server_name and cert paths updated to `qa-uz.aiqadam.org`.
- Command: `ssh ... "sudo nginx -t && sudo systemctl reload nginx && systemctl is-active nginx"` → `syntax is ok` / `test is successful` / `active`
- Verification: `ssh ... "curl -s -o /dev/null -w '%{http_code}\n' -k https://127.0.0.1/health -H 'Host: qa-uz.aiqadam.org'"` → `200`
- Result: success

#### Phase D, Step 13: Delete orphaned old cert
- Backup command: `ssh ... "sudo tar czf /var/backups/letsencrypt-qa.aiqadam.org.pre-delete.20260713T065931Z.tar.gz -C /etc/letsencrypt live/qa.aiqadam.org renewal/qa.aiqadam.org.conf"` — verified non-empty (930 bytes) via `sudo test -s ... && echo OK` → `OK`.
- Delete command: `ssh ... "sudo certbot delete --cert-name qa.aiqadam.org --non-interactive"`
- Exit code: 0
- Output: `Deleted all files relating to certificate qa.aiqadam.org.`
- Verification: `sudo certbot certificates` lists only `qa-uz.aiqadam.org` (count of "Certificate Name" lines = 1); `sudo test -d /etc/letsencrypt/live/qa.aiqadam.org` → does not exist (`GONE`).
- Result: success
- Backup taken: `/var/backups/letsencrypt-qa.aiqadam.org.pre-delete.20260713T065931Z.tar.gz`

#### Phase E, Step 14: Update .env
- Command: `ssh ... "cp /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.bak.rename.20260713T070007Z && sed -i -e 's#^WEB_BASE_URL=.*#WEB_BASE_URL=https://qa-uz.aiqadam.org#' -e 's#^OIDC_REDIRECT_URI=.*#OIDC_REDIRECT_URI=https://qa-uz.aiqadam.org/api/v1/auth/callback#' /opt/apps/aiqadam-qa/deploy/.env"`
- Exit code: 0
- Verification: `grep -E '^(WEB_BASE_URL|OIDC_REDIRECT_URI)=' .env` → both show `qa-uz.aiqadam.org`; `wc -l < .env` → `12` (unchanged); backup confirmed non-empty via `test -s`.
- Result: success
- Backup taken: `/opt/apps/aiqadam-qa/deploy/.env.bak.rename.20260713T070007Z`

#### Phase E, Step 15: Recreate api container
- Command: `ssh ... "docker compose -f /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml up -d --force-recreate api"`
- Exit code: 0
- Output: Compose sequencing confirmed `oidc-stub` `Waiting` → `Healthy` before `api` `Starting`/`Started` (dependency ordering preserved on recreate).
- Verification: `docker ps --filter name=aiqadam-qa-api-1` → `Up 6 seconds (healthy)`, `RestartCount=0`; re-checked ~10s later → `Up 23 seconds (healthy)`, `RestartCount=0` (stable, not climbing). Logs: `docker logs aiqadam-qa-api-1 2>&1 | grep -i -A2 -B2 'oidc\|issuer'` shows clean `[OIDCClient] Discovering OIDC issuer at http://127.0.0.1:9999/` immediately followed by `[OIDCClient] Issuer ready: http://127.0.0.1:9999/`, no `ECONNREFUSED`.
- Result: success

#### Phase F, Step 16: On-host confirmation with real Host header
- Command: `ssh ... "curl -s http://127.0.0.1:3113/health -H 'Host: qa-uz.aiqadam.org'"`
- Output: `{"status":"ok","timestamp":"2026-07-13T07:01:33.121Z","service":"api","tenant":{"code":"uz","name":"Uzbekistan"}}`
- Result: success — no `unknown-tenant` error; confirms the default-tenant-fallback path documented in step-04's "Root-cause correction" resolves cleanly.

#### Phase F, Step 17: External HTTPS probe
- Command: `curl -I https://qa-uz.aiqadam.org`
- Output: `HTTP/1.1 404 Not Found`, `Server: nginx/1.28.3 (Ubuntu)`, `X-Powered-By: Express`
- Result: **deviation from plan's literal expectation (`HTTP/2 200`) — investigated and explained, not a failure.** See "Issues / risks" below for full diagnosis: the app has no route handler for `GET /` (Nest/Express returns `{"message":"Cannot GET /","error":"Not Found","statusCode":404}` for the bare root path on-host with the same Host header, both before and independent of this rename), so any HEAD/GET to `https://qa-uz.aiqadam.org/` (root path) legitimately 404s at the app level — nginx and TLS are functioning correctly (the response comes from the proxied app itself, not a connection or TLS failure, and includes the app's own `X-Powered-By: Express` and `ETag` headers). Confirmed identical 404 behavior when curling the app port directly with the same Host header, ruling out any nginx/proxy defect introduced by this rename. `curl -s -o /dev/null -w 'HTTP_CODE=%{http_code}\n' https://qa-uz.aiqadam.org/health` (the actual acceptance-relevant path per step 18) separately confirmed `200`.

#### Phase F, Step 18: External health-body probe
- Command: `curl -s https://qa-uz.aiqadam.org/health`
- Output: `{"status":"ok","timestamp":"2026-07-13T07:01:39.809Z","service":"api","tenant":{"code":"uz","name":"Uzbekistan"}}`
- Result: success — body contains `"status":"ok"` exactly as required.

#### Phase F, Step 19: External DNS resolution check
- Command: `nslookup qa-uz.aiqadam.org 1.1.1.1`
- Output:
  ```
  Non-authoritative answer:
  Name:    qa-uz.aiqadam.org
  Address:  95.46.211.230
  ```
- Result: success — resolves to `95.46.211.230` exactly as required.

#### Phase F, Step 20: Confirm old hostname no longer resolves to this host
- Command: `curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 5 https://qa.aiqadam.org`
- Output: `503`
- Result: success — matches the plan's documented either/or expected outcome (falls through to the shared zone's third-party platform host at `212.20.151.29`, per `landscape/cloudflare.md`'s prior investigation of that IP's 302/503 catch-all behavior). Confirms `qa.aiqadam.org` is no longer pointing at `pro-data-tech-qa`.

### Final verification round (step-07 checklist, all re-confirmed)
- `docker ps --filter name=aiqadam-qa` → both containers `Up ... (healthy)`.
- `sudo certbot certificates` → only `qa-uz.aiqadam.org` listed, `VALID: 89 days`.
- `ls /etc/nginx/sites-enabled/` → only `qa-uz.aiqadam.org`.
- `sudo nginx -t` → passes; `systemctl is-active nginx` → `active`; `systemctl is-active certbot.timer` → `active`.
- `.env` grep → both `WEB_BASE_URL` and `OIDC_REDIRECT_URI` show `qa-uz.aiqadam.org`.
- `/var/backups/` contains `letsencrypt-qa.aiqadam.org.pre-delete.20260713T065931Z.tar.gz`.
- Cloudflare API: `qa.aiqadam.org` → `count:0`; `qa-uz.aiqadam.org` → `count:1`, matches expected fields exactly.

### Rollback executed
Not needed — every step succeeded on first attempt; no partial-failure state was ever reached.

### Resources changed
- **Files on host (pro-data-tech-qa, 95.46.211.230):**
  - `/etc/nginx/sites-available/qa-uz.aiqadam.org` — new (final production vhost)
  - `/etc/nginx/sites-enabled/qa-uz.aiqadam.org` — new symlink
  - `/etc/nginx/sites-available/qa.aiqadam.org.bak.rename.20260713T065654Z` — new (backup)
  - `/etc/nginx/sites-available/qa-uz.aiqadam.org.bak.certbot.20260713T065827Z` — new (backup)
  - `/etc/nginx/sites-enabled/qa.aiqadam.org` — removed
  - `/etc/letsencrypt/live/qa-uz.aiqadam.org/*`, `/etc/letsencrypt/renewal/qa-uz.aiqadam.org.conf` — new (certbot-issued)
  - `/etc/letsencrypt/live/qa.aiqadam.org/*`, `/etc/letsencrypt/renewal/qa.aiqadam.org.conf` — deleted (via `certbot delete`)
  - `/var/backups/letsencrypt-qa.aiqadam.org.pre-delete.20260713T065931Z.tar.gz` — new (930 bytes)
  - `/opt/apps/aiqadam-qa/deploy/.env` — modified (2 lines); backup at `/opt/apps/aiqadam-qa/deploy/.env.bak.rename.20260713T070007Z`
- **Services restarted:** `nginx` (reloaded twice: after initial HTTP-only vhost, after final production vhost). `api` container force-recreated once (Phase E).
- **External resources changed:**
  - Cloudflare: new A record `qa-uz.aiqadam.org` → `95.46.211.230` (proxied false, ttl 1, ID `53aa89ca061e343291f33bb7b8b3a12e`); old A record `qa.aiqadam.org` (ID `c39c16816fc23946882d9e845f79c6c2`) deleted.
  - Let's Encrypt: new certificate issued for `qa-uz.aiqadam.org` (ECDSA, expires 2026-10-11); old certificate for `qa.aiqadam.org` deleted (local files only, not revoked, per plan's explicit design decision).

## Issues / risks

- **Deviation from plan's literal step-17 text, investigated and resolved as non-blocking.** The plan's step 17 verification target (`curl -I https://qa-uz.aiqadam.org` → `HTTP/2 200`) assumed the bare domain root would return 200. In practice it returns `404 Not Found` with body `{"message":"Cannot GET /","error":"Not Found","statusCode":404}` — this is the Nest/Express application's own routing behavior (no handler registered for `GET /`), reproduced identically when hitting the app port directly (`127.0.0.1:3113`) with the same Host header, independent of nginx, TLS, or this rename. It is not a regression: the app never had a root-path route in any prior attempt either (Phase 10 of the prior FAIL attempt only ever exercised `/health`). The actual acceptance-relevant checks — `curl -s https://qa-uz.aiqadam.org/health` (step 18, `"status":"ok"`) and an explicit `HTTP_CODE=200` check on `/health` — both passed cleanly, both on-host and externally. Flagging for the validator so this known, pre-existing, app-level 404-at-root is not mistaken for an infra defect introduced by this run.
- **LOW — carried over, unrelated to this rename.** The `pro-data-tech-qa` SSH alias misconfiguration (points at `User root`) remains open and unfixed; worked around via explicit key/user invocation throughout, per this task's explicit instruction to leave it out of scope.
- **LOW — carried over, unrelated to this rename.** Redis connection-refused log noise (`OutboxRelayService`/`JtiRevocationService`) flagged in the prior FAIL attempt remains present (not re-verified in this run since it was explicitly out of scope and non-blocking); no new instance of it was observed in the OIDC-focused log grep performed in Phase E step 15's verification.
- **LOW — per plan's own explicit design decision, not a defect.** The old `qa.aiqadam.org` certificate was deleted via `certbot delete` (local files only), not revoked via ACME. It remains cryptographically valid until its natural expiry (2026-10-11) if anyone retained the private key — no one outside this host ever would have. This matches the plan's documented rationale exactly (an unrevoked-but-locally-deleted cert for an abandoned name poses negligible risk; revocation would add an extra irreversible ACME-server-side action for no real benefit).
- No off-plan changes were made. `pro-data-tech-prod`, the `aiqadam_test` database, the `aiqadam_qa` database inside `ai-qadam-test-db-1`, the application checkout at `/opt/apps/aiqadam-qa/`, and every other of the 32 Cloudflare zone records were left untouched — confirmed by the Phase B GET-before-POST/DELETE calls each targeting only the two exact record names in scope.

## Open questions
None blocking. This is the final execution for this task — recommend proceeding directly to step 07 (execution-validator) to independently confirm the end state described above, paying particular attention to the step-17 deviation note (app-level 404 at root path, not an infra regression) so it is not mis-flagged as a fresh failure.
