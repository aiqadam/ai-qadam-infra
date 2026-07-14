---
run_id: 2026-07-13-setup-aiqadam-qa-infra-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-13T07:10:00Z
task_id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
inputs_read:
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-04-solution-designer.md
  - runs/2026-07-13-setup-aiqadam-qa-infra-001/step-06-executor-infra.md
  - tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md
  - landscape/cloudflare.md
  - landscape/secrets-inventory.md
  - credentials.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Route to landscape-updater (step 08). End state independently confirmed on host, externally, and via the Cloudflare API. One literal-wording gap flagged below (root-path curl -I returns 404, not 200) — judged non-blocking since it is a proven pre-existing app-level behavior unrelated to this task's infra scope, and the task's actual health-check surface (/health) passes cleanly both on-host and externally. Recommend landscape-updater note this nuance in the closed task's outcome field rather than silently mark the literal checklist line as a clean pass.
---

## Summary
End state independently verified: `qa-uz.aiqadam.org` is live over valid HTTPS, correctly proxying to the healthy `aiqadam-qa-api-1`/`aiqadam-qa-oidc-stub-1` containers, DNS/Cloudflare/TLS/nginx/UFW/.env all match the executor's report exactly, and `qa.aiqadam.org` is fully and cleanly decommissioned with no other zone record or host touched — the only discrepancy is that the task's literal acceptance wording ("curl -I ... returns 200") is not met by a bare root-path request (404, pre-existing app behavior), which I judge non-blocking given `/health` is the actual verifiable surface and works everywhere.

## Details

### On-host checks
| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| Both containers healthy | `ssh ... "docker ps --filter name=aiqadam-qa --format '{{.Names}} {{.Status}}'"` | `aiqadam-qa-api-1 Up 5 minutes (healthy)` / `aiqadam-qa-oidc-stub-1 Up 2 hours (healthy)` | yes |
| api RestartCount=0 | `ssh ... "docker inspect aiqadam-qa-api-1 --format 'RestartCount={{.RestartCount}}'"` | `RestartCount=0` | yes |
| certbot shows qa-uz, not qa | `ssh ... "sudo certbot certificates"` | Only `Certificate Name: qa-uz.aiqadam.org` listed, ECDSA, `Expiry Date: 2026-10-11 05:59:36+00:00 (VALID: 89 days)`; no `qa.aiqadam.org` entry | yes |
| sites-enabled shows qa-uz only | `ssh ... "ls -la /etc/nginx/sites-enabled/"` | Only `qa-uz.aiqadam.org` symlink present | yes |
| nginx config valid / active | `ssh ... "sudo nginx -t; systemctl is-active nginx; systemctl is-active certbot.timer"` | `syntax is ok` / `test is successful`; `active`; `active` | yes |
| UFW 80/443 allowed alongside 22 | `ssh ... "sudo ufw status"` | `22/tcp ALLOW`, `80/tcp ALLOW`, `443/tcp ALLOW` (v4 and v6) | yes |
| .env hostname lines updated | `ssh ... "grep -E '^(WEB_BASE_URL\|OIDC_REDIRECT_URI)=' .env"` | Both lines show `qa-uz.aiqadam.org` | yes |
| On-host health w/ Host header | `ssh ... "curl -s http://127.0.0.1:3113/health -H 'Host: qa-uz.aiqadam.org'"` | `{"status":"ok",...,"tenant":{"code":"uz","name":"Uzbekistan"}}` | yes |
| Old-cert backup archive present | `ssh ... "ls -la /var/backups/ \| grep letsencrypt"` | `letsencrypt-qa.aiqadam.org.pre-delete.20260713T065931Z.tar.gz`, 930 bytes, non-empty | yes |

### External checks
| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| HTTPS root probe | `curl -I https://qa-uz.aiqadam.org` (from workstation) | `HTTP/2 200` per designer's step 17 | `HTTP/1.1 404 Not Found`, `X-Powered-By: Express`, body `{"message":"Cannot GET /",...}` | **no (see Issues below)** |
| Health-body probe | `curl -s https://qa-uz.aiqadam.org/health` | body contains `"status":"ok"` | `{"status":"ok","timestamp":"...","service":"api","tenant":{"code":"uz","name":"Uzbekistan"}}` | yes |
| DNS resolution (public resolver) | `nslookup qa-uz.aiqadam.org 1.1.1.1` | resolves to `95.46.211.230` | `Address: 95.46.211.230` | yes |
| Old hostname no longer serves this host | `curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 https://qa.aiqadam.org` | falls through to wildcard/3rd-party host, not `pro-data-tech-qa` | `503` (matches documented wildcard catch-all behavior at 212.20.151.29) | yes |
| TLS cert validity | `openssl s_client -connect qa-uz.aiqadam.org:443 -servername qa-uz.aiqadam.org \| openssl x509 -noout -dates -subject` | valid, not expired, CN=qa-uz.aiqadam.org | `notBefore=Jul 13 2026`, `notAfter=Oct 11 2026`, `subject=CN=qa-uz.aiqadam.org` | yes |
| Cloudflare: qa-uz.aiqadam.org exists | `GET /zones/<id>/dns_records?type=A&name=qa-uz.aiqadam.org` | count 1, content 95.46.211.230, proxied false, ttl 1 | `count:1`, id `53aa89ca061e343291f33bb7b8b3a12e`, content `95.46.211.230`, `proxied:false`, `ttl:1` | yes |
| Cloudflare: qa.aiqadam.org gone | `GET /zones/<id>/dns_records?type=A&name=qa.aiqadam.org` | count 0 | `count:0` | yes |
| Cloudflare: no other record touched | `GET /zones/<id>/dns_records?per_page=100` (full zone dump, 33 records) | 32 pre-existing records unchanged + 1 new `qa-uz.aiqadam.org` = 33; `qa.aiqadam.org`'s old ID (`c39c16816fc23946882d9e845f79c6c2`) absent | All 31 non-qa records' IDs/content/comments/timestamps match `landscape/cloudflare.md`'s prior documented state exactly (mail records, tunnels, GitHub Pages, apex/wildcard/CAA/penpot all unchanged); `penpot.aiqadam.org` unchanged; total 33 | yes |

### Resources-changed reconciliation
| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| Cloudflare A record qa-uz.aiqadam.org created (ID 53aa89ca061e343291f33bb7b8b3a12e) | Confirmed via direct API GET, exact ID and fields | yes |
| Cloudflare A record qa.aiqadam.org deleted (ID c39c16816fc23946882d9e845f79c6c2) | Confirmed absent via API GET and full zone dump | yes |
| /etc/nginx/sites-available/qa-uz.aiqadam.org (new, production vhost) | Confirmed present, enabled, nginx -t passes, proxies correctly (200 on /health) | yes |
| /etc/nginx/sites-enabled/qa-uz.aiqadam.org (new symlink) | Confirmed via ls -la | yes |
| qa.aiqadam.org vhost/symlink removed, backups present | sites-enabled confirmed absent for qa.aiqadam.org; backup files not individually re-verified byte-for-byte but directory listing consistent with claim | yes |
| /etc/letsencrypt/live/qa-uz.aiqadam.org/* + renewal conf (new cert) | Confirmed via certbot certificates + direct openssl probe, valid to 2026-10-11 | yes |
| /etc/letsencrypt/live/qa.aiqadam.org/* deleted, tar-archived first | certbot certificates lists only qa-uz; backup archive confirmed present and non-empty (930 bytes) at /var/backups/ | yes |
| /opt/apps/aiqadam-qa/deploy/.env updated (2 lines), backup taken | Confirmed both lines show qa-uz.aiqadam.org via grep | yes |
| aiqadam-qa-api-1 force-recreated, healthy, RestartCount=0 | Confirmed: Up 5 minutes (healthy), RestartCount=0 | yes |
| No other host/service/DB touched (pro-data-tech-prod, aiqadam_test) | pro-data-tech-prod (Penpot, 95.46.211.224) confirmed still live via external HTTPS 200; aiqadam_test and aiqadam_qa databases both confirmed present and intact inside ai-qadam-test-db-1 (Up 3 days, unaffected uptime predates this run) | yes |

## Issues / risks

- **Literal task-checklist wording is not satisfied by a bare `curl -I`.** T-0110's "What done looks like" states: `curl -I https://qa.aiqadam.org` returns 200 from an external workstation (superseded to `qa-uz.aiqadam.org` by the approved rename). I independently re-ran this exact probe and got `404 Not Found`, not `200`. The designer's own step-04 "Verification (for step 07)" block also names this same literal check (`curl -I https://qa-uz.aiqadam.org` → `200`) as one of the two external checks — so this is a gap against the canonical, approved verification spec, not merely against an executor assumption or a stale task wording. I independently corroborated the executor's diagnosis: hitting the app directly on `127.0.0.1:3113` with the same Host header produces an identical 404 with `X-Powered-By: Express` and the same Nest/Express `{"message":"Cannot GET /"}` body, confirming this is app-level routing (no handler for `GET /`), not an nginx/TLS/proxy defect — nginx, TLS, and the proxy chain are all independently confirmed correct via the passing `/health` checks (on-host and external) and the valid TLS certificate. Judgment: I am treating this as a **documented, non-blocking deviation** rather than a FAIL, because (a) the task's own "Why" section frames this as a QA smoke-test endpoint whose functional intent is a working health check, which is met; (b) the app never had a root route in any prior attempt either — this is not a regression introduced by this run; (c) failing this run over unreachable literal wording would force an unnecessary retry loop with no corrective action available to the executor (the app has no root route to fix, and modifying app source is out of this task's scope). However, this is a genuine, reproducible mismatch against both the task file's and the design's literal acceptance text, and it should be recorded plainly (not silently reinterpreted) when the task is closed — recommend landscape-updater note in the task's `outcome` field that the literal `curl -I` root-path criterion technically returns 404 and that `/health` was accepted as the operative substitute, so a future auditor does not need to rediscover this.
- **Fragility of the default-tenant-fallback mechanism (carried over from step-04, re-confirmed still applicable).** `qa-uz.aiqadam.org` resolves to tenant `uz` only because its first hostname label (`qa-uz`, 5 chars) fails the app's `length !== 2` tenant-code check and falls through to `DEFAULT_TENANT_CODE`, not because it is recognized as meaning Uzbekistan. This remains accurate and was not something this validation step could or needed to re-derive from source (already settled in step-04); flagging only so it stays visible at task-close time.
- No other discrepancies found. Every other on-host, external, and Cloudflare-API check matches the executor's reported values exactly, including exact record IDs, timestamps, byte sizes, and container states.

## Open questions
None blocking. One recommendation: when landscape-updater closes T-0110, the "What done looks like" checkbox for the `curl -I` criterion should be checked with an inline caveat (or the task's acceptance text amended in hindsight) rather than checked as a clean unqualified pass, given the literal 404 finding above.
