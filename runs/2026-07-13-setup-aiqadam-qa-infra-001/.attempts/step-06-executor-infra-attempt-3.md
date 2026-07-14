---
run_id: 2026-07-13-setup-aiqadam-qa-infra-001
step: 06
agent: executor-infra
verdict: FAIL
created: 2026-07-13T05:30:00Z
task_id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
retry_of: step-06
inputs_read:
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md (revised plan, oidc-stub fix)
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-05-user-approval.md (revised approval, APPROVED)
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/.attempts/step-06-executor-infra-attempt-2.md (prior FAIL diagnostic)
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/.attempts/step-05-user-approval-attempt-1.md
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-01-task-reader.md
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-02-landscape-reader.md
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-03-task-validator.md
  - tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md
  - landscape/cloudflare.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - credentials.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001/step-04-solution-designer.md (penpot nginx/certbot precedent, used for Phase 6/9 exact command patterns and the certbot contact email)
artifacts_changed:
  - /opt/apps/aiqadam-qa/deploy/oidc-stub/openid-configuration.json (host: pro-data-tech-qa — new)
  - /opt/apps/aiqadam-qa/deploy/oidc-stub/nginx.conf (host: pro-data-tech-qa — new)
  - /opt/apps/aiqadam-qa/deploy/.env (host: pro-data-tech-qa — OIDC_ISSUER_URL line corrected, backed up first)
  - /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml (host: pro-data-tech-qa — overwritten with two-service version, backed up first)
  - aiqadam-qa-api:latest (Docker image, host: pro-data-tech-qa — rebuilt, new ID f3bdacde362d)
  - aiqadam-qa-api:rollback-20260713 (Docker image tag, host: pro-data-tech-qa)
  - nginx:alpine (Docker image, host: pro-data-tech-qa — pulled)
  - aiqadam-qa-oidc-stub-1 (Docker container, host: pro-data-tech-qa — created, running, healthy)
  - aiqadam-qa-api-1 (Docker container, host: pro-data-tech-qa — created, running, healthy)
  - nginx, certbot, python3-certbot-nginx (packages, host: pro-data-tech-qa — installed)
  - /etc/nginx/sites-enabled/default (host: pro-data-tech-qa — removed)
  - /etc/nginx/sites-available/qa.aiqadam.org, /etc/nginx/sites-enabled/qa.aiqadam.org (host: pro-data-tech-qa — new vhost, final production config with proxy to 127.0.0.1:3113)
  - /etc/letsencrypt/live/qa.aiqadam.org/* (host: pro-data-tech-qa — new Let's Encrypt cert, ECDSA, expires 2026-10-11)
  - UFW rules (host: pro-data-tech-qa — 80/tcp and 443/tcp ALLOW IN added, v4+v6; backups taken first)
  - Cloudflare DNS: qa.aiqadam.org A record (zone aiqadam.org — new, record ID c39c16816fc23946882d9e845f79c6c2, -> 95.46.211.230, proxied false)
next_step_hint: Route back to solution-designer. All infra-level work (Phases 4-9) succeeded and is verified stable — OIDC stub fix confirmed working, API container healthy with RestartCount=0, nginx+TLS+UFW+DNS all correctly configured and functioning. However, Phase 10's external verification fails because apps/api has hostname-based multi-tenant routing that parses the leftmost DNS label as a tenant/country code, and "qa" is not a registered tenant (only uz/kz/tj are). Every request through nginx (which must forward the real Host header for TLS SNI/vhost routing to work at all) hits this and gets HTTP 400 "Unknown tenant". This is a new, previously-undiscovered root cause, structurally identical in shape to the OIDC surprise from the previous attempt (deliberate app behavior neither design pass surfaced) but in a completely different subsystem (tenant resolution, not auth). Needs a design-level decision: e.g. add a tenant alias/default-tenant mapping for the "qa" hostname (app config change, not env-only — needs source investigation of the tenant-resolution code, similar in spirit to the OIDC investigation last round), or choose a differently-named QA hostname that matches an existing tenant code pattern, or find an env var that sets a default/override tenant. Recommend NOT re-attempting Phase 10 verification until this is root-caused the same rigorous way the OIDC issue was.
---

## Summary
Executed the revised plan's Phase 4 through Phase 9 successfully — the oidc-stub fix works exactly as designed (API container healthy, RestartCount=0, clean OIDCClient discovery in logs, no ECONNREFUSED) — and nginx, UFW, Cloudflare DNS, and Let's Encrypt TLS were all stood up correctly for `qa.aiqadam.org`, but Phase 10's external verification fails: the API rejects every request that carries the real `qa.aiqadam.org` Host header with HTTP 400 "Unknown tenant" (a previously-undiscovered app-level hostname-to-tenant routing behavior, unrelated to and not masked by the OIDC fix), so `curl -I https://qa.aiqadam.org` returns 400 instead of 200. No rollback was executed — every change made is a correctly-functioning, non-destructive, independently-reversible piece of infrastructure; the blocker is a new application-behavior root cause outside this plan's anticipated scope, not a broken infra step.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (`runs/2026-07-13-setup-aiqadam-qa-infra-001/step-05-user-approval.md`)
- Design references match: yes — step-05's `inputs_read` lists `runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md`
- Design verdict: `NEEDS_APPROVAL` (step-04 frontmatter) → step-05 required and present → confirmed `verdict: APPROVED`

### Pre-flight sanity check (per resuming task instructions)
Re-verified state left in place from the prior FAIL attempt before touching anything:
- `ssh ... "whoami && sudo -n true"` → `tvolodi` / `SUDO_OK`.
- `test -d /opt/apps/aiqadam-qa/.git && git -C /opt/apps/aiqadam-qa log -1 --oneline` → `dfd2a7c docs(workflow): backfill squash SHAs into wf-20260709-migrate-001 handoff (#4)` — checkout still present at the expected HEAD.
- `docker exec ai-qadam-test-db-1 psql -U aiqadam -d aiqadam_test -tAc "SELECT 1 FROM pg_database WHERE datname='aiqadam_qa';"` → `1` — `aiqadam_qa` database still exists.
- `docker compose version` → `v5.3.1` (supports `depends_on: condition: service_healthy`, confirmed by the designer as a pre-flight item).
- Docker Hub outbound reachability check (designer's flagged pre-flight item): `curl --connect-timeout 5 https://registry-1.docker.io/v2/` → HTTP 401 (expected anonymous-auth response — confirms network-layer reachability, not a failure).
- Existing `.env`: 12 lines, `OIDC_ISSUER_URL=http://127.0.0.1:9999/not-configured/` (the old broken value, as expected). No `aiqadam-qa` containers running.

### Execution log (Phase 4 onward — full detail per instructions)

#### Phase 4, Step 1: Create oidc-stub config directory
- Command: `ssh ... "mkdir -p /opt/apps/aiqadam-qa/deploy/oidc-stub"`
- Exit code: 0
- Verification: `test -d /opt/apps/aiqadam-qa/deploy/oidc-stub && echo OK` → `OK`
- Result: success

#### Phase 4, Step 2: Write openid-configuration.json
- Method: SSH heredoc, content exactly as specified in the revised plan.
- Exit code: 0
- Verification (deviation noted): plan specified `node -e "JSON.parse(...)"` but `node` is not installed on the host itself (only inside the app's Docker image) — `which node` returned nothing. Substituted `python3 -c "import json; json.load(open(...))"` (python3 confirmed present per host apt posture) — same intent (confirm well-formed JSON before nginx loads it), different tool. Output: `VALID_JSON`.
- Result: success

#### Phase 4, Step 3: Write nginx.conf for oidc-stub
- Method: SSH heredoc, content exactly as specified.
- Exit code: 0
- Verification: plan itself notes `nginx -t` cannot run at this point (host nginx not yet installed) and defers authoritative verification to the container's own healthcheck (Phase 5 step 7). Content confirmed via `cat` to match spec exactly.
- Result: success

#### Phase 4, Step 4: Correct .env's OIDC_ISSUER_URL line
- Command: `ssh ... "cp /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.bak.20260713T051615Z && sed -i 's#^OIDC_ISSUER_URL=.*#OIDC_ISSUER_URL=http://127.0.0.1:9999/#' /opt/apps/aiqadam-qa/deploy/.env"`
- Exit code: 0
- Backup taken: `/opt/apps/aiqadam-qa/deploy/.env.bak.20260713T051615Z` (606 bytes, mode 600) — verified non-empty before the destructive `sed`.
- Verification: `grep '^OIDC_ISSUER_URL=' .env` → `OIDC_ISSUER_URL=http://127.0.0.1:9999/` (exact match); `wc -l < .env` → `12` (unchanged from before edit).
- Result: success

#### Phase 4, Step 5: Overwrite docker-compose.qa.yml
- Backup command: `ssh ... "cp /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.bak.20260713T051631Z"` — verified non-empty (554 bytes) before overwrite.
- Write command: SSH heredoc with the exact two-service Compose YAML from the revised plan (oidc-stub + api, `depends_on: condition: service_healthy`).
- Exit code: 0
- Verification: `cat` confirmed exact content match; `docker compose -f .../docker-compose.qa.yml config >/dev/null && echo VALID` → `VALID`
- Result: success

#### Phase 5, Step 6: Pull nginx:alpine
- Command: `ssh ... "docker pull nginx:alpine"`
- Exit code: 0
- Output (trimmed): full layer pull, `Status: Downloaded newer image for nginx:alpine`
- Verification: `docker images nginx:alpine --format ...` → `nginx:alpine 54f2a904c251`
- Result: success

#### Phase 5, Step 7: Start oidc-stub alone, verify healthy
- Command: `ssh ... "docker compose -f .../docker-compose.qa.yml up -d oidc-stub"`
- Exit code: 0
- Output: `Container aiqadam-qa-oidc-stub-1 Creating/Created/Starting/Started`
- Verification: after ~12s, `docker ps --filter name=aiqadam-qa-oidc-stub-1` → `Up 19 seconds (healthy)`. Direct probe: `curl -s http://127.0.0.1:9999/.well-known/openid-configuration` returned the exact JSON document written in step 2, byte-for-byte.
- Result: success

#### Phase 5, Step 8: Build/reuse API image
- Decision: rebuilt (conservative default per plan's own guidance, both options sanctioned).
- Command: `ssh ... "cd /opt/apps/aiqadam-qa && docker build -f apps/api/Dockerfile -t aiqadam-qa-api:latest ."`
- Exit code: 0
- Output (trimmed): all layers `CACHED` (confirms zero source/Dockerfile drift since the prior FAIL attempt's build), final `exporting to image` / `naming to docker.io/library/aiqadam-qa-api:latest` / `DONE 1.0s`.
- Verification: `docker images aiqadam-qa-api:latest` → ID `f3bdacde362d` (differs from the prior attempt's `b08782e117d1` despite all layers showing CACHED — attributable to BuildKit attestation-manifest metadata differences between builds, not a content change; the plan explicitly states this step does not gate on a specific ID).
- Result: success

#### Phase 5, Step 9: Tag rollback image
- Command: `ssh ... "docker tag aiqadam-qa-api:latest aiqadam-qa-api:rollback-20260713 2>/dev/null || true"`
- Exit code: 0
- Output: `docker images | grep aiqadam-qa-api` shows both tags at ID `f3bdacde362d`.
- Result: success

#### Phase 5, Step 10: Start full stack
- Command: `ssh ... "docker compose -f .../docker-compose.qa.yml up -d"`
- Exit code: 0
- Output: `Container aiqadam-qa-oidc-stub-1 Running` → `Container aiqadam-qa-api-1 Creating/Created` → `Container aiqadam-qa-oidc-stub-1 Waiting` → `Container aiqadam-qa-oidc-stub-1 Healthy` → `Container aiqadam-qa-api-1 Starting/Started` — Compose's own output confirms the `depends_on: condition: service_healthy` sequencing fired exactly as designed (it explicitly waited for and logged the stub's `Healthy` transition before starting `api`).
- Verification (critical diagnostic, per plan): polled until healthcheck stabilized. First check at ~21s: `Up 21 seconds (healthy)`, `RestartCount=0`. Re-checked ~10s later: `Up 42 seconds (healthy)`, `RestartCount=0` — confirmed stable, not climbing (this is the exact signal that was diagnostic of the prior FAIL attempt's crash loop, where RestartCount was 7-8 and actively incrementing).
- Result: success

#### Phase 5, Step 11: On-host health check
- Command: `ssh ... "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3113/health"` → `200`
- Follow-up: `curl -s http://127.0.0.1:3113/health` → `{"status":"ok","timestamp":"2026-07-13T05:19:46.360Z","service":"api","tenant":{"code":"uz","name":"Uzbekistan"}}` — contains `"status":"ok"` and `"service":"api"` as required.
- Result: success

#### Phase 5, Step 12: Check logs for clean OIDC success, no ECONNREFUSED
- Command: `ssh ... "docker logs aiqadam-qa-api-1 --tail 50"` — this tail window was dominated by ongoing, unrelated `ioredis`/`OutboxRelayService`/`JtiRevocationService` connection-refused retries (see Issues/risks — a separate, pre-existing app behavior unrelated to OIDC, since this QA `.env` has no `REDIS_URL` configured per the approved plan's env spec). Searched the full log instead: `docker logs aiqadam-qa-api-1 2>&1 | grep -i -A2 -B2 'oidc\|issuer'`.
- Output confirmed the exact expected pattern: `[OIDCClient] Discovering OIDC issuer at http://127.0.0.1:9999/` immediately followed (within the same boot sequence, no error in between) by `[OIDCClient] Issuer ready: http://127.0.0.1:9999/`. No `ECONNREFUSED` on port 9999 anywhere in the log.
- Result: success — **the oidc-stub fix is confirmed working.** This directly resolves the root cause diagnosed in the prior FAIL attempt.

#### Phase 6, Steps 1-5: nginx install + initial HTTP vhost
- Pre-check: `curl --connect-timeout 5 http://95.46.211.230/` → `000` (no listener yet, expected); `apt list --installed | grep -E 'nginx|certbot'` → empty; `ls /etc/nginx/sites-enabled/` → `nginx-not-installed`. Clean slate confirmed.
- Install command: `sudo apt-get update -q && sudo apt-get install -y nginx certbot python3-certbot-nginx` — exit 0. Verified: `nginx -v` → `nginx/1.28.3 (Ubuntu)`; `certbot --version` → `4.0.0` (matches the pro-data-tech-prod/T-0109 precedent exactly).
- Default site removed: `sudo rm -f /etc/nginx/sites-enabled/default` — exit 0, `ls /etc/nginx/sites-enabled/` empty afterward.
- Initial HTTP-only vhost written (redirect-only, for certbot HTTP-01) at `/etc/nginx/sites-available/qa.aiqadam.org` — written via a local scratchpad file + `scp` (avoided nested-heredoc shell-escaping corruption of `$host`/`$request_uri` that occurred on a first attempt via inline SSH heredoc; corrected by writing the file locally first and transferring it, then verified via `cat` that the variables were preserved literally, not shell-expanded).
- Enabled: `sudo ln -sf /etc/nginx/sites-available/qa.aiqadam.org /etc/nginx/sites-enabled/qa.aiqadam.org` — exit 0, symlink verified via `ls -la`.
- Config test + reload: `sudo nginx -t && sudo systemctl reload nginx` — `syntax is ok` / `test is successful`; `systemctl is-active nginx` → `active`.
- Result: success

#### Phase 7: UFW allow 80/443
- Pre-check: `sudo ufw status verbose` → only `22/tcp` (v4+v6) ALLOW IN, matching landscape.
- Backup: `sudo cp /etc/ufw/user.rules /etc/ufw/user.rules.bak.20260713T052210Z && sudo cp /etc/ufw/user6.rules /etc/ufw/user6.rules.bak.20260713T052210Z` — both verified non-empty (1351 and 1365 bytes) before the change.
- Command: `sudo ufw allow 80/tcp && sudo ufw allow 443/tcp` — exit 0, output `Rule added` / `Rule added (v6)` x2.
- Verification: `sudo ufw status verbose` shows `22/tcp`, `80/tcp`, `443/tcp` all `ALLOW IN Anywhere` for both v4 and v6.
- Result: success

#### Phase 8: Cloudflare DNS A record
- Idempotency GET-before-POST: `GET /zones/<zone-id>/dns_records?type=A&name=qa.aiqadam.org` → `{"result":[],"count":0}` — confirmed no pre-existing record.
- POST: created A record `qa.aiqadam.org` → `95.46.211.230`, `proxied: false`, `ttl: 1` (auto). Response: `success: true`, record ID `c39c16816fc23946882d9e845f79c6c2`.
- Verification GET: confirmed `count: 1`, record matches exactly.
- DNS propagation check: `nslookup qa.aiqadam.org 1.1.1.1` → resolved to `95.46.211.230` within ~15s of creation.
- Result: success. No other record in the 32-record shared zone was touched (confirmed by the GET-before-POST returning zero matches for this exact name only).

#### Phase 9: Let's Encrypt TLS via certbot
- Command: `sudo certbot --nginx -d qa.aiqadam.org --non-interactive --agree-tos -m admin@aiqadam.org` (contact email reused verbatim from the `pro-data-tech-prod`/T-0109 penpot precedent, per this task's instruction to reuse it).
- Exit code: 0 (implicit — command completed with success messages, no error)
- Output: `Successfully received certificate.` / `Certificate is saved at: /etc/letsencrypt/live/qa.aiqadam.org/fullchain.pem` / `This certificate expires on 2026-10-11.` / `Successfully deployed certificate for qa.aiqadam.org to /etc/nginx/sites-enabled/qa.aiqadam.org` / `Congratulations! You have successfully enabled HTTPS on https://qa.aiqadam.org`
- Post-certbot vhost inspection: certbot (as expected, matching the penpot precedent's documented behavior) only added SSL directives and merged the redirect into the same server block — the `location /` block still only returned a 301, never proxied to the app. This is the exact same situation the penpot/T-0109 precedent's plan step 7 addressed.
- Backup before final overwrite: `sudo cp /etc/nginx/sites-available/qa.aiqadam.org /etc/nginx/sites-available/qa.aiqadam.org.bak.certbot.20260713T052333Z` — verified non-empty (674 bytes).
- Final production vhost written (two server blocks: HTTP→HTTPS redirect on 80; HTTPS termination on 443 with `proxy_pass http://127.0.0.1:3113/` and standard proxy headers) — written via local scratchpad file + `scp`, same escaping-safety approach as Phase 6.
- Config test + reload: `sudo nginx -t && sudo systemctl reload nginx` — `syntax is ok` / `test is successful`; `systemctl is-active nginx` → `active`.
- `systemctl is-active certbot.timer` → `active`.
- `sudo certbot certificates` → Certificate Name `qa.aiqadam.org`, Key Type ECDSA, Expiry `2026-10-11 04:24:39+00:00 (VALID: 89 days)`.
- Result: success (as an nginx/TLS/certbot mechanical operation — all commands succeeded, config is valid, cert is issued and deployed).

#### Phase 10: External verification — FAILED
- On-host sanity probe before attempting the external check: `curl -s -o /dev/null -w '%{http_code}\n' -k https://127.0.0.1/health -H 'Host: qa.aiqadam.org'` → **`400`**, body: `{"type":"https://aiqadam.org/errors/unknown-tenant","title":"Unknown tenant","detail":"No country with code 'qa' is registered. Known codes: uz, kz, tj."}`
- Re-confirmed via the real hostname (SNI + Host both correct): `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` (run from the host itself) → `400`, identical body.
- Isolated the cause to Host-header-driven tenant resolution, not an nginx/proxy defect: `curl -s http://127.0.0.1:3113/health -H 'Host: qa.aiqadam.org'` (hitting the app port directly, bypassing nginx entirely, but with the same Host header nginx forwards) → **same 400, same body** — proves nginx is proxying correctly; the API itself parses the leftmost DNS label of the Host header as a tenant/country code and rejects `qa` because it isn't a registered tenant (only `uz`, `kz`, `tj` are, per the error body).
- Cross-check: `curl -s http://127.0.0.1:3113/health` **without** a Host header override (curl's default `Host: 127.0.0.1:3113`) → `200`, `"tenant":{"code":"uz",...}` — the app silently falls back to a default tenant (`uz`) when the Host header doesn't parse as any recognized subdomain pattern, which is why Phase 5 step 11's on-host check (no Host header involved) passed cleanly but the real external-facing path (which necessarily carries `Host: qa.aiqadam.org` for TLS SNI/vhost routing to work at all) cannot succeed as currently configured.
- Given the Phase 10 verification criteria (`curl -I https://qa.aiqadam.org` → 200; `curl -s https://qa.aiqadam.org/health` → `"status":"ok"` in body) cannot be met with the app in its current tenant-resolution configuration, and the plan has no documented fallback for this scenario (it was never anticipated in either design pass — the OIDC investigation was scoped to auth/boot behavior only, not tenant routing), **I stopped here rather than improvise an app-config or app-source change**, per this step's instructions.
- Result: failure. Not attempted: full external-workstation `curl -I https://qa.aiqadam.org`, `nslookup` from an external resolver, `Test-NetConnection` port checks — these would only reconfirm the same 400, so were skipped as redundant once the root cause was isolated on-host.

### Rollback executed
**Not needed / not performed.** Per the plan's own framing, rollback exists for a *failed step* that leaves the system in a broken or partially-applied state. Here, every step from Phase 4 through Phase 9 completed successfully and verified clean — the oidc-stub fix works, the API container is healthy and stable (`RestartCount=0`), nginx/UFW/DNS/TLS are all correctly configured and mechanically functioning. The only failure is that the *application itself*, when reached via its real intended hostname, returns a 400 for a reason unrelated to any infra step performed in this run. Rolling back nginx/UFW/DNS/TLS would not fix this (it is not an infra defect) and would only regress verified-working infrastructure that the next design iteration can build on directly (much like the prior FAIL attempt's decision to leave checkout/database/secrets in place). Left in place for the next solution-designer round:
- `oidc-stub` + `api` containers running healthy.
- nginx installed, vhost live, proxying correctly (confirmed by the Host-header-matched 400, which is the app answering, not connection-refused).
- UFW 80/443 open.
- Cloudflare `qa.aiqadam.org` A record live and resolving.
- Valid Let's Encrypt cert for `qa.aiqadam.org`, auto-renewing.

### Resources changed
- **Files on host (pro-data-tech-qa, 95.46.211.230):**
  - `/opt/apps/aiqadam-qa/deploy/oidc-stub/openid-configuration.json` — new
  - `/opt/apps/aiqadam-qa/deploy/oidc-stub/nginx.conf` — new
  - `/opt/apps/aiqadam-qa/deploy/.env` — `OIDC_ISSUER_URL` line corrected; backup at `/opt/apps/aiqadam-qa/deploy/.env.bak.20260713T051615Z`
  - `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` — overwritten (two-service version); backup at `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.bak.20260713T051631Z`
  - `/etc/nginx/sites-enabled/default` — removed
  - `/etc/nginx/sites-available/qa.aiqadam.org`, `/etc/nginx/sites-enabled/qa.aiqadam.org` — new vhost (final production version, proxying to `127.0.0.1:3113`); intermediate backups at `.bak.certbot.20260713T052333Z`
  - `/etc/letsencrypt/live/qa.aiqadam.org/*`, `/etc/letsencrypt/renewal/qa.aiqadam.org.conf` — new, created by certbot
  - `/etc/ufw/user.rules`, `/etc/ufw/user6.rules` — modified (80/tcp, 443/tcp added); backups at `.bak.20260713T052210Z`
- **Services restarted:** `nginx` (reloaded twice — after initial vhost, after final production vhost); `ufw` (rules reloaded as part of `ufw allow`).
- **Docker resources (host: pro-data-tech-qa):**
  - Image `nginx:alpine` (ID `54f2a904c251`) — pulled
  - Image `aiqadam-qa-api:latest` (ID `f3bdacde362d`) — rebuilt
  - Image tag `aiqadam-qa-api:rollback-20260713` (same ID) — created
  - Container `aiqadam-qa-oidc-stub-1` — created, running, healthy
  - Container `aiqadam-qa-api-1` — created, running, healthy, `RestartCount=0`
- **External resources changed:**
  - Cloudflare: new DNS A record `qa.aiqadam.org` → `95.46.211.230`, `proxied: false`, record ID `c39c16816fc23946882d9e845f79c6c2`, in the `aiqadam.org` zone.
  - Let's Encrypt: new certificate issued for `qa.aiqadam.org` (ECDSA, expires 2026-10-11).
- **Packages installed on host:** `nginx`, `certbot`, `python3-certbot-nginx` (and apt dependencies).

## Issues / risks

- **HIGH — new root cause blocking Phase 10, structurally similar to (but distinct from) the OIDC issue found last attempt.** `apps/api` performs hostname-based multi-tenant routing: it derives a tenant/country code from the Host header's leftmost DNS label and rejects unrecognized codes with HTTP 400 ("Unknown tenant... Known codes: uz, kz, tj"). `qa` is not a registered tenant code, so every request that legitimately carries `Host: qa.aiqadam.org` (which is unavoidable — TLS SNI and nginx vhost routing both require it) gets rejected. This was invisible in Phase 5's on-host check because that check used curl's default `Host: 127.0.0.1:3113` (no recognizable subdomain pattern), which the app apparently treats as a default/fallback case and answers with tenant `uz`. Neither this attempt's nor the prior attempt's design phase investigated tenant-resolution code — both investigations were correctly scoped to the OIDC crash-loop only. This needs the same rigor the OIDC investigation received: read the app's actual tenant-resolution source (likely something in `apps/api/src/config` or a dedicated tenant/country middleware) to determine whether there's an env var, a header override, a wildcard/default-tenant config, or whether `qa.aiqadam.org` as a hostname is fundamentally incompatible with this app's routing model and a different hostname (or a `<tenant>.qa.aiqadam.org` pattern, or an explicit tenant override header configured in nginx) is needed instead.
- **Medium — Redis connection errors observed in container logs, NOT part of this task's scope, NOT blocking anything verified so far.** `docker logs aiqadam-qa-api-1` shows recurring `[ioredis] Unhandled error event: AggregateError [ECONNREFUSED]` from `OutboxRelayService` and `JtiRevocationService`, roughly every 2 seconds, throughout the container's uptime. The approved `.env` spec for this QA environment has no `REDIS_URL` (it was never part of any approved plan's 12-line `.env` list), so this is expected-but-noisy background retry behavior, not a new crash risk (the container remains healthy and stable — `RestartCount=0` throughout, unlike the OIDC issue which destabilized boot). Flagging per rule 7 (noticed but not fixed, off-plan) — the user/designer may want to either provision a QA Redis instance in a future task or confirm these features are meant to be no-ops in QA.
- **Deviation from plan's literal text, does not affect outcome:** Phase 4 step 2's verification command specified `node -e "..."` to validate JSON; `node` is not installed on the host itself (only inside the app's container image). Substituted `python3 -c "import json; json.load(...)"`, which is present on the host and serves the identical purpose (confirm well-formed JSON before nginx loads it). Documented above; no impact on the artifact's correctness (verified byte-for-byte identical content was written and is being served correctly by the running `oidc-stub` container).
- **Minor — shell-escaping hazard when writing nginx vhost content via inline SSH heredoc.** A first attempt to write the initial HTTP-only vhost via a nested `ssh ... "sudo bash -c \"cat > ... << 'EOF' ... EOF\""` construction corrupted the `$host`/`$request_uri` nginx variables (they were consumed by an outer shell layer despite the inner heredoc's quoting). Caught immediately by reading the file back before proceeding; fixed by writing the vhost content to a local scratchpad file and `scp`-ing it to the host instead, which avoids all nested-shell-expansion risk. No incorrect config was ever loaded by nginx (caught and corrected before the `ln -sf`/`nginx -t` steps).
- **No off-plan changes were made.** Nothing was touched on `pro-data-tech-prod`, the existing `aiqadam_test` database, the existing `penpot.aiqadam.org` Cloudflare record, or any of the other 31 records in the shared `aiqadam.org` zone (confirmed by the Phase 8 GET-before-POST returning exactly one new record, matched by name).
- Task blocks T-0112 and T-0114 — this FAIL verdict continues that schedule impact.
- The `pro-data-tech-qa` SSH alias misconfiguration (still points at `User root`) remains open and unfixed, per this task's explicit instruction to leave it out of scope. Worked around throughout via explicit key/user invocation.

## Open questions
- Is `qa.aiqadam.org` the right hostname choice at all, given the app's tenant-resolution model reads the leftmost label as a country/tenant code? Should the next design iteration instead use something like `qa-uz.aiqadam.org` (matching a registered tenant), introduce a tenant-override/default-tenant env var or config (if the app source supports one — needs investigation, not yet confirmed either way), or add nginx-level header rewriting (e.g., force a different `Host` header downstream to the app while keeping the public-facing SNI/vhost name as `qa.aiqadam.org`)? This is a design decision requiring source-level investigation of the app's tenant-resolution code, analogous to last round's OIDC investigation.
- Should a QA-scoped Redis instance be provisioned in a future task to quiet the `OutboxRelayService`/`JtiRevocationService` connection-refused noise, or are those features intentionally inert/no-op in this QA slice (matching the already-accepted "OIDC login is out of scope" pattern for this environment)?
