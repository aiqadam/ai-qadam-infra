---
run_id: 2026-07-13-setup-aiqadam-qa-infra-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-13T07:00:00Z
task_id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
retry_of: step-04
inputs_read:
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md (prior version, archived to .attempts/ by orchestrator — the oidc-stub fix)
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-05-user-approval.md
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/.attempts/step-06-executor-infra-attempt-3.md (FAIL — tenant-routing 400 diagnostic)
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/services.md
  - tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - c:\Users\tvolo\dev\ai-dala\aiqadam\apps\api\src\modules\tenants\tenant.middleware.ts
  - c:\Users\tvolo\dev\ai-dala\aiqadam\apps\api\src\modules\tenants\tenant.types.ts
  - c:\Users\tvolo\dev\ai-dala\aiqadam\apps\api\src\modules\tenants\tenants.service.ts
  - c:\Users\tvolo\dev\ai-dala\aiqadam\apps\api\src\db\schema\tenants.ts
artifacts_changed: []
next_step_hint: Route to executor-infra to perform the hostname rename (qa.aiqadam.org -> qa-uz.aiqadam.org) across Cloudflare DNS, nginx vhost, and Let's Encrypt cert. Everything from the prior FAIL attempt (oidc-stub, api container, checkout, database) is reused untouched. NEEDS_APPROVAL again — this is new DNS record creation + a new TLS certificate issuance, both categorically gated per shared/approval-protocol.md regardless of task_id's estimated_blast_radius. IMPORTANT: read the "Root-cause correction" section below carefully before presenting to the user — the naive "qa-uz.aiqadam.org" suggestion from the FAIL handoff's open question works, but only via the app's default-tenant fallback path, not genuine subdomain-tenant matching; this nuance must be surfaced to the user, not silently resolved.
---

## Summary
Renames the public hostname for the already-deployed, already-healthy AiQadam QA stack from `qa.aiqadam.org` to `qa-uz.aiqadam.org` (new Cloudflare A record, new nginx vhost, new Let's Encrypt cert; old DNS record and cert deleted), fixing Phase 10's HTTP 400 by routing around — not through — the app's hostname-based tenant parser; everything already deployed (oidc-stub, api containers, checkout, database, UFW) is reused as-is.

## Details

### Root-cause correction (this revision's required investigation)

The task instructed verifying, via source reading, whether `qa-uz.aiqadam.org` genuinely resolves to tenant `uz`, or whether the tenant parser requires the leftmost label to be *exactly* `uz`. Read the actual tenant-resolution code, not just the FAIL handoff's error-message inference:

**`apps/api/src/modules/tenants/tenant.middleware.ts`** (`tenantFromHost`, lines 33-44):
```ts
export function tenantFromHost(host: string | undefined): string | null {
  if (!host) return null;
  const hostnameOnly = host.split(':')[0]?.toLowerCase().trim();
  if (!hostnameOnly) return null;
  if (/^\d+\.\d+\.\d+\.\d+$/.test(hostnameOnly)) return null;
  const firstLabel = hostnameOnly.split('.')[0] ?? '';
  if (NON_TENANT_LABELS.has(firstLabel)) return null;
  if (firstLabel.length !== 2) return null;   // <-- decisive line
  return firstLabel;
}
```
And the middleware's `use()` (lines 50-53):
```ts
const fromHost = tenantFromHost(req.header('host'));
const fromHeader = req.header(TENANT_HEADER);          // 'x-tenant'
const code = (fromHost ?? fromHeader ?? DEFAULT_TENANT_CODE).toLowerCase().trim();
```
`DEFAULT_TENANT_CODE = 'uz'` (line 17). `countries.code` is `varchar(2)` (`apps/api/src/db/schema/tenants.ts` line 14) — the DB schema itself enforces 2-character codes; only `uz`/`kz`/`tj` rows exist (confirmed by the FAIL handoff's error body).

**This settles the question precisely, and the answer is more subtle than either the naive suggestion or a simple "yes/no":**

- `qa.aiqadam.org` — leftmost label `qa`, length 2, not in `NON_TENANT_LABELS` → treated as a **candidate tenant code** `qa` → not registered → 400. (Confirms the FAIL handoff's own inference: the parser takes the entire leftmost label literally, no substring/prefix matching.)
- `qa-uz.aiqadam.org` — leftmost label `qa-uz`, **length 5, not 2** → `tenantFromHost` returns `null` at the length check, **before ever comparing it to any tenant code**. Falls through to `fromHeader` (`X-Tenant` — absent on a plain external request) → falls through to `DEFAULT_TENANT_CODE = 'uz'` → resolves successfully, HTTP 200, tenant `uz`.
- `qa.uz.aiqadam.org` (dot instead of hyphen) — leftmost label is still `qa` (only the first dot-segment is read) → **same 400 as today.** A naive "just add uz somewhere in the name" fix is not guaranteed to work; only the *specific* pattern `qa-uz` (hyphenated, keeping the whole first label 5 characters) avoids the 2-char branch.
- A hostname whose leftmost label is *genuinely* `uz` (e.g. `uz.aiqadam.org`) would hit the real subdomain-match code path (`fromHost = 'uz'`, registered, returned directly) rather than the default-fallback path. This is the only way to exercise the app's *documented* "subdomain wins" mechanism. It was not chosen here (see below).

**Conclusion: `qa-uz.aiqadam.org` does work, exactly as the user chose — but it works by accident of the length-based fallback, not by "being recognized as the uz tenant."** Concretely: any request to `qa-uz.aiqadam.org` without an explicit `X-Tenant` header resolves to `uz` only because `qa-uz` fails the `length !== 2` test, not because the app parses `qa-uz` as meaning Uzbekistan. If a future app change alters `NON_TENANT_LABELS`, the length check, or the default tenant, this QA hostname's behavior could shift silently. This is a real but low-probability risk (app-source behavior, out of this task's control) and is called out under Issues/risks — not treated as a blocker, since the user already explicitly declined investigating app-source alternatives and explicitly chose this option knowing it reuses the simplest path. No further app-source investigation or app-config change is needed; the hostname `qa-uz.aiqadam.org` is confirmed correct and sufficient for this task's actual acceptance criterion (`curl -I https://<host>` → 200, `/health` → `"status":"ok"`), which does not require genuine subdomain-tenant matching, only a working default-tenant health response — consistent with the already-approved scope (OIDC login and multi-tenant login flows are out of scope for this QA smoke-test slice).

### Old DNS record and cert disposition

Recommend **deleting** both the orphaned `qa.aiqadam.org` Cloudflare A record (ID `c39c16816fc23946882d9e845f79c6c2`) and the orphaned `qa.aiqadam.org` Let's Encrypt certificate, rather than leaving them in place:

- **DNS:** the zone is shared, 32-record, third-party-adjacent infrastructure (`landscape/cloudflare.md`) — leaving a stale `qa.aiqadam.org` record pointing at `95.46.211.230` with no matching nginx vhost (once the vhost is renamed) would make a live host serve nothing for that name (connection succeeds, TLS fails or nginx returns a default/404), which is confusing for any future zone auditor and is exactly the "shared-resource surgery, not greenfield" posture the zone notes warn about. Deleting it removes an orphan cleanly.
- **Cert:** the old cert becomes wrong-name and unrenewable-usefully once the vhost referencing it is gone (certbot's renewal cron would still try to renew a cert for a name whose HTTP-01 challenge path no longer has a matching vhost, and would eventually fail loudly in logs). Deleting it via `certbot delete` keeps the tracked-certificate list accurate.
- **Tradeoff noted:** both deletions are one-way in the sense that undoing them means re-issuing/re-creating (not a data-recovery problem, just re-running Phase 8/9-equivalent steps) — but since this hostname is being abandoned in favor of `qa-uz.aiqadam.org` and nothing else in the zone references it, there is no operational reason to keep either artifact. If the user prefers to keep the old DNS record as a redirect placeholder for some future reuse, that is a valid alternative, but adds no value currently and was not requested.

### Plan

All SSH commands run as `tvolodi@95.46.211.230` using explicit key invocation (the `pro-data-tech-qa` SSH alias misconfiguration remains open/unfixed, per prior attempts' carried-over note):
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "<command>"
```

**Phase A — Pre-flight verification (read-only, confirms starting state matches this design's assumptions)**

1. Confirm current containers still healthy — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "docker ps --filter name=aiqadam-qa --format '{{.Names}} {{.Status}}'"` — verification: both `aiqadam-qa-oidc-stub-1` and `aiqadam-qa-api-1` show `Up ... (healthy)`.
2. Confirm current nginx vhost and cert state — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo certbot certificates 2>&1 | grep -A4 'qa.aiqadam.org'"` — verification: shows `Certificate Name: qa.aiqadam.org`, confirming the cert this plan will delete.
3. Confirm current Cloudflare record — command (from workstation, using secret `cloudflare-ai-qadam-api-token` and `cloudflare-ai-qadam-zone-id` by reference, values from `credentials.md`):
   ```
   curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records/c39c16816fc23946882d9e845f79c6c2" -H "Authorization: Bearer <token>" -H "Content-Type: application/json"
   ```
   — verification: `"success":true`, `"name":"qa.aiqadam.org"`, `"content":"95.46.211.230"` — confirms the exact record ID to delete in step 6.

**Phase B — Cloudflare DNS: create new record, delete old record**

4. Idempotency check before create — command:
   ```
   curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records?type=A&name=qa-uz.aiqadam.org" -H "Authorization: Bearer <token>" -H "Content-Type: application/json"
   ```
   — verification: `"count":0` (no pre-existing record for this exact name; if `count` is already 1, skip step 5 and treat the existing record as this step's output — do not create a duplicate).
5. Create the new A record — command:
   ```
   curl -s -X POST "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records" -H "Authorization: Bearer <token>" -H "Content-Type: application/json" --data '{"type":"A","name":"qa-uz.aiqadam.org","content":"95.46.211.230","proxied":false,"ttl":1}'
   ```
   — verification: response `"success":true`; re-run the step-4 GET, confirm `"count":1` and record fields match exactly. Note the new record's `id` from the response — needed for rollback.
   - **Rollback:** `curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records/<new-record-id>" -H "Authorization: Bearer <token>"`.
6. Delete the orphaned old record — command:
   ```
   curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records/c39c16816fc23946882d9e845f79c6c2" -H "Authorization: Bearer <token>"
   ```
   — verification: response `"success":true`; follow with `GET /zones/<zone-id>/dns_records?type=A&name=qa.aiqadam.org` → `"count":0`.
   - **Backup before destructive change:** the full record body was captured in Phase A step 3 (name, content, proxied, ttl, id) — sufficient to recreate it verbatim if rollback is needed.
   - **Rollback:** re-POST the exact captured body from step 3 (same name/content/proxied/ttl; Cloudflare will assign a new record ID, since the old ID cannot be reused — note this in the rollback record).
   - **Idempotency:** DELETE on an already-absent record ID returns a Cloudflare API error (`"success":false"`, error code 81044 "record does not exist") — safe to treat as already-satisfied if re-run after a successful first attempt; the GET-based verification (not the DELETE call itself) is the source of truth for idempotency checks on retry.

**Phase C — nginx vhost: replace, not rename-in-place**

Decision: **create a new vhost file and remove the old one**, rather than editing the existing `qa.aiqadam.org` file's `server_name` in place. Reason: certbot has already modified `/etc/nginx/sites-available/qa.aiqadam.org` twice (once for the initial HTTP-only vhost, once to inject SSL directives) per the FAIL handoff's Phase 6/9 log — the file's current content is certbot-managed boilerplate mixed with the hand-written proxy block, and its certbot `# managed by Certbot` markers reference the `qa.aiqadam.org` cert paths specifically. A fresh file with the final desired two-server-block content (matching the FAIL handoff's confirmed-working Phase 9 shape: HTTP→HTTPS redirect on 80, HTTPS termination on 443 with `proxy_pass http://127.0.0.1:3113/`) is less error-prone than surgically editing certbot-owned lines and reduces risk of a repeat of the FAIL attempt's nested-heredoc shell-escaping hazard when patching in place. Certbot will populate the new file's SSL directives itself during Phase D's cert issuance (`certbot --nginx` auto-detects the `server_name` and inserts a matching SSL server block), exactly as it did originally.

7. Back up the current vhost files — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo cp /etc/nginx/sites-available/qa.aiqadam.org /etc/nginx/sites-available/qa.aiqadam.org.bak.rename.$(date -u +%Y%m%dT%H%M%SZ)"` — verification: `ssh ... "sudo test -s /etc/nginx/sites-available/qa.aiqadam.org.bak.rename.<timestamp> && echo OK"` → `OK`.
8. Write the new HTTP-only vhost (pre-cert, redirect + ACME challenge path) to `/etc/nginx/sites-available/qa-uz.aiqadam.org` via local scratchpad file + `scp` (avoids the nested-heredoc shell-escaping hazard the FAIL attempt hit and corrected) — content:
   ```nginx
   server {
       listen 80;
       listen [::]:80;
       server_name qa-uz.aiqadam.org;
       location / {
           return 301 https://$host$request_uri;
       }
   }
   ```
   — verification: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "cat /etc/nginx/sites-available/qa-uz.aiqadam.org"` shows the exact content, `$host`/`$request_uri` preserved literally (not shell-expanded).
9. Enable the new vhost, disable and remove the old one — commands:
   ```
   ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo ln -sf /etc/nginx/sites-available/qa-uz.aiqadam.org /etc/nginx/sites-enabled/qa-uz.aiqadam.org && sudo rm -f /etc/nginx/sites-enabled/qa.aiqadam.org"
   ```
   — verification: `ssh ... "ls -la /etc/nginx/sites-enabled/"` shows `qa-uz.aiqadam.org` present, `qa.aiqadam.org` absent.
10. Test and reload — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo nginx -t && sudo systemctl reload nginx"` — verification: `syntax is ok` / `test is successful`; `systemctl is-active nginx` → `active`.
    - **Idempotency:** steps 8-10 are safe to re-run — `scp`/`ln -sf` overwrite deterministically; `nginx -t` gates the reload so a bad config never goes live.
    - **Rollback:** `ssh ... "sudo ln -sf /etc/nginx/sites-available/qa.aiqadam.org.bak.rename.<timestamp> /etc/nginx/sites-enabled/qa.aiqadam.org && sudo rm -f /etc/nginx/sites-enabled/qa-uz.aiqadam.org && sudo nginx -t && sudo systemctl reload nginx"` (restores the old vhost from backup; only valid before step 12 deletes the old cert, since the restored vhost's SSL directives point at that cert's file paths).

**Phase D — TLS: new cert for qa-uz.aiqadam.org, delete old cert**

11. Issue the new certificate — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo certbot --nginx -d qa-uz.aiqadam.org --non-interactive --agree-tos -m admin@aiqadam.org"` — verification: output contains `Successfully received certificate.` and `Congratulations! You have successfully enabled HTTPS on https://qa-uz.aiqadam.org`; `sudo certbot certificates` shows `Certificate Name: qa-uz.aiqadam.org`, non-expired.
    - **Idempotency:** certbot's `--nginx` plugin is safe to re-run — if a cert for this exact name already exists and is valid, certbot reports "Certificate not yet due for renewal" and exits 0 without changes; re-running after a partial failure is safe.
    - **Backup before destructive change:** certbot itself backs up the vhost file it modifies (into `/etc/nginx/sites-available/qa-uz.aiqadam.org` in place, but the pre-certbot version was already captured by virtue of step 8's write being the pre-certbot baseline — no separate backup command needed here since step 8's content is trivially reproducible).
    - **Rollback:** `ssh ... "sudo certbot delete --cert-name qa-uz.aiqadam.org --non-interactive"` followed by restoring the step-8 HTTP-only vhost content and reloading nginx.
12. Post-certbot vhost inspection and finalize proxy config (per the FAIL handoff's documented pattern — certbot only injects SSL directives and merges the redirect, it does not add `proxy_pass`): back up the certbot-modified file, then write the final production vhost (two server blocks: HTTP→HTTPS redirect on 80; HTTPS on 443 with `proxy_pass http://127.0.0.1:3113/` and standard proxy headers) via local scratchpad + `scp`, matching the FAIL attempt's confirmed-working Phase 9 content verbatim except for the `server_name` and cert paths — commands:
    ```
    ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo cp /etc/nginx/sites-available/qa-uz.aiqadam.org /etc/nginx/sites-available/qa-uz.aiqadam.org.bak.certbot.$(date -u +%Y%m%dT%H%M%SZ)"
    ```
    then `scp` the final vhost content to `/etc/nginx/sites-available/qa-uz.aiqadam.org`, then `ssh ... "sudo nginx -t && sudo systemctl reload nginx"`.
    — verification: `curl -s -o /dev/null -w '%{http_code}' -k https://127.0.0.1/health -H 'Host: qa-uz.aiqadam.org'` (run on host) → `200`.
13. Delete the orphaned old cert — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo certbot delete --cert-name qa.aiqadam.org --non-interactive"` — verification: `sudo certbot certificates` no longer lists `qa.aiqadam.org`; `test -d /etc/letsencrypt/live/qa.aiqadam.org` → false (directory removed).
    - **Backup before destructive change:** `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo tar czf /var/backups/letsencrypt-qa.aiqadam.org.pre-delete.$(date -u +%Y%m%dT%H%M%SZ).tar.gz -C /etc/letsencrypt live/qa.aiqadam.org renewal/qa.aiqadam.org.conf"` run immediately before the `certbot delete`, verified non-empty (`sudo test -s <archive-path> && echo OK`) — per the workflow rule "backup before destructive changes," and per this repo's "no off-site storage" rule the archive stays on host disk only, at `/var/backups/`.
    - **Idempotency:** `certbot delete --cert-name` on an already-deleted cert name errors cleanly ("No certificate found with name ...") — safe to treat as already-satisfied on retry (check via `sudo certbot certificates` first, not by re-running blindly).
    - **Rollback:** `ssh ... "sudo tar xzf /var/backups/letsencrypt-qa.aiqadam.org.pre-delete.<timestamp>.tar.gz -C /etc/letsencrypt"` restores the cert files and renewal config verbatim (does not un-expire or re-trust anything Let's Encrypt itself has invalidated server-side, but restores host-local state; a genuinely fresh cert would need re-issuance if the restored one is later rejected by Let's Encrypt's own tracking — low risk, cert is not being revoked, only its local files removed).

**Phase E — .env hostname-dependent lines (WEB_BASE_URL, OIDC_REDIRECT_URI)**

14. Back up and update the two hostname-literal `.env` lines — command:
    ```
    ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "cp /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.bak.rename.$(date -u +%Y%m%dT%H%M%SZ) && sed -i -e 's#^WEB_BASE_URL=.*#WEB_BASE_URL=https://qa-uz.aiqadam.org#' -e 's#^OIDC_REDIRECT_URI=.*#OIDC_REDIRECT_URI=https://qa-uz.aiqadam.org/api/v1/auth/callback#' /opt/apps/aiqadam-qa/deploy/.env"
    ```
    — verification: `ssh ... "grep -E '^(WEB_BASE_URL|OIDC_REDIRECT_URI)=' /opt/apps/aiqadam-qa/deploy/.env"` shows both lines updated to `qa-uz.aiqadam.org`; `wc -l < /opt/apps/aiqadam-qa/deploy/.env` still shows the same line count as before (12), confirming no line was added/removed.
    - **Idempotency:** `sed` substitution is deterministic — safe to re-run; each re-run creates a new timestamped backup (harmless accumulation).
    - **Rollback:** `ssh ... "cp /opt/apps/aiqadam-qa/deploy/.env.bak.rename.<timestamp> /opt/apps/aiqadam-qa/deploy/.env"`.
15. Recreate the `api` container so it picks up the updated `.env` (these two vars are not read at OIDC-discovery boot time in a way that would crash-loop — `WEB_BASE_URL` and `OIDC_REDIRECT_URI` are used only when constructing redirect URLs / CORS origin checks, not during the `Issuer.discover()` boot call — but a container restart is required for the new env values to take effect since Node reads `process.env` once at start) — command:
    ```
    ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "docker compose -f /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml up -d --force-recreate api"
    ```
    — verification: `docker ps --filter name=aiqadam-qa-api-1 --format '{{.Names}} {{.Status}}'` → `Up ... (healthy)`; `docker inspect aiqadam-qa-api-1 --format 'RestartCount={{.RestartCount}}'` stays `0` (re-check twice ~10s apart); `docker logs aiqadam-qa-api-1 --tail 20 | grep -i issuer` shows the clean `Issuer ready` line again (confirms the oidc-stub dependency and healthcheck ordering still hold on recreate, since `oidc-stub` itself is untouched and already healthy).
    - **Idempotency:** `up -d --force-recreate` scoped to one service is safe to re-run.
    - **Rollback:** `ssh ... "cp /opt/apps/aiqadam-qa/deploy/.env.bak.rename.<timestamp> /opt/apps/aiqadam-qa/deploy/.env && docker compose -f /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml up -d --force-recreate api"` (restores old env values and recreates again).

**Phase F — External verification**

16. On-host confirmation with real Host header — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "curl -s http://127.0.0.1:3113/health -H 'Host: qa-uz.aiqadam.org'"` — verification: body is `{"status":"ok",...,"tenant":{"code":"uz","name":"Uzbekistan"}}` — no `unknown-tenant` error, confirming the fallback-to-default-tenant path (documented in "Root-cause correction" above) resolves cleanly for this exact hostname.
17. External HTTPS probe (from the management workstation) — command: `curl -I https://qa-uz.aiqadam.org` — verification: `HTTP/2 200`.
18. External health-body probe — command: `curl -s https://qa-uz.aiqadam.org/health` — verification: body contains `"status":"ok"`.
19. External DNS resolution check — command: `nslookup qa-uz.aiqadam.org 1.1.1.1` — verification: resolves to `95.46.211.230`.
20. Confirm the old hostname no longer resolves to anything meaningful (expected side effect of Phase B step 6 + Phase C step 9) — command: `curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 5 https://qa.aiqadam.org` — verification: either falls through to the shared zone's `*.aiqadam.org` wildcard (whatever the third-party platform host at `212.20.151.29` returns — a 302/503 per `landscape/cloudflare.md`'s investigation notes, not this task's concern) or fails to resolve/connect once DNS propagates the deletion; either outcome confirms `qa.aiqadam.org` is no longer pointing at `pro-data-tech-qa`, which is the intended end state.

### Rollback (full-plan teardown, in reverse order)

1. `.env`: restore from `.env.bak.rename.<timestamp>`, recreate `api` container (Phase E rollback).
2. TLS: delete `qa-uz.aiqadam.org` cert (`certbot delete --cert-name qa-uz.aiqadam.org --non-interactive`); if the old cert's backup archive (Phase D step 13) was restored, its renewal config may need `certbot certificates` re-validation before relying on it for actual renewal.
3. nginx: restore `qa.aiqadam.org` vhost from `.bak.rename.<timestamp>`, remove `qa-uz.aiqadam.org` vhost and sites-enabled symlink, `nginx -t && systemctl reload nginx`.
4. Cloudflare: delete the new `qa-uz.aiqadam.org` record (by its returned ID); re-create `qa.aiqadam.org` → `95.46.211.230` (proxied false) from the Phase A step-3 captured body if full restoration to the pre-rename state is desired.
5. Everything else (oidc-stub, api container internals, checkout, database, UFW) is untouched by this plan and needs no rollback.

Every step remains independently reversible; nothing in this plan is a one-way operation given the backups captured at each destructive step (old DNS record body, old vhost file, old cert archive, old `.env`).

### Verification (for step 07)

- **On-host:**
  - `docker ps --filter name=aiqadam-qa` shows both `oidc-stub` and `api` `Up ... (healthy)`, `RestartCount=0` on `api` (stable, not climbing, after the Phase E recreate).
  - `sudo certbot certificates` shows `qa-uz.aiqadam.org` (valid, non-expired) and does NOT show `qa.aiqadam.org`.
  - `ls /etc/nginx/sites-enabled/` shows `qa-uz.aiqadam.org`, not `qa.aiqadam.org`.
  - `sudo nginx -t` passes; `systemctl is-active nginx` → `active`; `systemctl is-active certbot.timer` → `active`.
  - `grep -E '^(WEB_BASE_URL|OIDC_REDIRECT_URI)=' /opt/apps/aiqadam-qa/deploy/.env` both show `qa-uz.aiqadam.org`.
  - `curl -s http://127.0.0.1:3113/health -H 'Host: qa-uz.aiqadam.org'` → `"status":"ok"`, no `unknown-tenant` error.
  - `test -d /var/backups/letsencrypt-qa.aiqadam.org.pre-delete.*` exists (old cert backup present before deletion).
- **External:**
  - `curl -I https://qa-uz.aiqadam.org` → `200`.
  - `curl -s https://qa-uz.aiqadam.org/health` → body contains `"status":"ok"`.
  - `nslookup qa-uz.aiqadam.org` (external resolver, e.g. `1.1.1.1`) → `95.46.211.230`.
  - `GET /zones/<zone-id>/dns_records?type=A&name=qa.aiqadam.org` (Cloudflare API) → `count:0` (old record gone).
  - `GET /zones/<zone-id>/dns_records?type=A&name=qa-uz.aiqadam.org` → `count:1`, matches expected fields.

### Resources used

- **Secrets (by name):** `cloudflare-ai-qadam-api-token`, `cloudflare-ai-qadam-zone-id` (existing, from `landscape/secrets-inventory.md`). No new secrets introduced.
- **Files modified on host:** `/opt/apps/aiqadam-qa/deploy/.env` (two lines, backed up first); `/etc/nginx/sites-available/qa-uz.aiqadam.org` (new); `/etc/nginx/sites-enabled/qa-uz.aiqadam.org` (new symlink); `/etc/nginx/sites-available/qa.aiqadam.org` and `/etc/nginx/sites-enabled/qa.aiqadam.org` (removed, backed up first); `/etc/letsencrypt/live/qa-uz.aiqadam.org/*`, `/etc/letsencrypt/renewal/qa-uz.aiqadam.org.conf` (new); `/etc/letsencrypt/live/qa.aiqadam.org/*` (deleted, tar-archived first to `/var/backups/`). No changes to `docker-compose.qa.yml`, the oidc-stub artifacts, the checkout, or the database.
- **Files modified in this repo (landscape/):** to be applied at step 08 — `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`, `landscape/cloudflare.md` (replace the `qa.aiqadam.org` row with `qa-uz.aiqadam.org`, record ID updated), `landscape/domains.md` (same rename in the subdomains/TLS tables), `shared/app-registry.md` (QA environment health-endpoint hostname updated to `qa-uz.aiqadam.org`).
- **External APIs called:** Cloudflare DNS API (one create, one delete), Let's Encrypt ACME API (one new-cert issuance via certbot, one cert deletion — no revocation, just local removal since `certbot delete` without `--cert-name`-collision does not revoke by default in this certbot version's non-interactive flow; if strict revocation is desired the executor should add `--delete-after-revoke` or run `certbot revoke` first — not done here since an unrevoked-but-deleted cert for an abandoned name poses negligible risk and revocation adds an extra irreversible ACME-server-side action for no real benefit).

### Estimated impact

- **Downtime:** brief, sub-second-to-a-few-seconds gap for `qa.aiqadam.org` requests during the nginx vhost swap (Phase C step 9) — acceptable since nothing depends on `qa.aiqadam.org` externally yet (Phase 10 never succeeded in any prior attempt, so no real traffic exists on this hostname). No downtime for `qa-uz.aiqadam.org` since it does not exist until this plan creates it. The `api`/`oidc-stub` containers themselves are not stopped except for the one `--force-recreate api` in Phase E (a few seconds, matching the existing healthcheck `start_period`).
- **Affected services:** `pro-data-tech-qa`'s nginx, the `aiqadam-qa-api-1` container (recreated once), Cloudflare DNS zone `aiqadam.org` (one record added, one removed), Let's Encrypt certificate inventory for this host (one cert added, one removed). No other host, service, or Cloudflare record is touched — confirmed no other of the 32 zone records shares any dependency with `qa.aiqadam.org`/`qa-uz.aiqadam.org` per `landscape/cloudflare.md`'s investigation.
- **Reversibility:** fully reversible — every destructive step (DNS delete, vhost removal, cert delete, `.env` overwrite) has a captured backup and a documented rollback command.

## Issues / risks

- **HIGH-SEVERITY (drives `NEEDS_APPROVAL` on its own, same as both prior rounds):** this plan creates a new Cloudflare DNS record, issues a new Let's Encrypt certificate, and deletes both an existing DNS record and an existing certificate in the shared `aiqadam.org` zone. Per `shared/approval-protocol.md`, DNS changes and TLS operations are categorically `NEEDS_APPROVAL` regardless of the task's `estimated_blast_radius` field. This is unchanged in kind from the prior two approval rounds — the user must explicitly approve this specific rename plan (not assume the original DNS/TLS approval carries over, since the hostname itself is changing).
- **MEDIUM-SEVERITY, central to this revision — the `qa-uz.aiqadam.org` fix works via the app's default-tenant fallback, not genuine subdomain-tenant matching.** As detailed in "Root-cause correction" above: `qa-uz`'s leftmost label is 5 characters, which fails the app's `firstLabel.length !== 2` check and falls through to `DEFAULT_TENANT_CODE = 'uz'` — it is not recognized as "the uz tenant" by name, it is recognized as "not a 2-character code, so use the default." This is a correct, verified, working fix for this task's actual scope (a QA health-check smoke test, not a multi-tenant login flow), but it is fragile in a way a genuinely-matching hostname (e.g. `uz.aiqadam.org`) would not be: any future change to `NON_TENANT_LABELS`, the length-based branch, or `DEFAULT_TENANT_CODE` in the app's source could silently change this hostname's behavior without any infra-side change being at fault. This is an accepted tradeoff given the user's explicit choice of the "simplest option," not a defect in this plan, but the user should see this nuance before approving, since it was not disclosed in the original "just rename it" framing.
- **MEDIUM-SEVERITY:** deleting the old `qa.aiqadam.org` DNS record and cert is a deliberate cleanup choice (recommended, not strictly required by the task). If the user prefers to leave the old record/cert in place (e.g., to preserve option value for a future different use of that exact hostname), Phase B step 6 and Phase D step 13 can be skipped — this would leave `qa.aiqadam.org` resolving to `95.46.211.230` with no matching nginx vhost once Phase C completes, meaning nginx would fall through to a default/no-match response for that Host header (behavior depends on whether a default_server catch-all exists — none is configured on this host per the FAIL handoff's Phase 6 log, so nginx would likely serve whichever vhost is marked `default_server`, or the first-defined server block, for unmatched Host headers — worth the executor confirming nginx's actual default-vhost behavior if the user chooses to skip the deletions).
- **LOW-SEVERITY:** Phase D step 13's cert deletion is a local-files-only removal (`certbot delete`), not an ACME revocation. The abandoned cert remains cryptographically valid until its natural expiry (2026-10-11) if anyone retained a copy of the private key, though no one outside this host ever would have. Judged negligible risk, noted for completeness per the "backup before destructive changes" and "bounded blast radius" design rules.
- **LOW-SEVERITY (carried over, unrelated to this revision):** the SSH alias misconfiguration (`pro-data-tech-qa` pointing at `User root`) remains open and unfixed; worked around via explicit key/user invocation, as in both prior attempts. Out of this task's scope to fix.
- **LOW-SEVERITY:** Redis connection-refused log noise (`OutboxRelayService`/`JtiRevocationService`) flagged by the FAIL handoff remains present and unaddressed — unrelated to this hostname rename, not blocking, already flagged as a possible future task in the prior attempt's Open questions.

## Open questions
None blocking this design. One judgment call is flagged above (Issues/risks, second bullet) for the user's awareness before approving: the fix works via default-tenant fallback rather than genuine subdomain matching, which is sufficient for this task's scope but worth knowing. The old-record/old-cert deletion (recommended) is presented as the default in this plan; the user may instead choose to keep them via a `MODIFY` response, per the tradeoff noted under "Old DNS record and cert disposition."
