---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 06
agent: executor-infra
verdict: FAIL
created: 2026-07-19T03:20:00Z
task_id: T-0117-install-mail-server-aiqadam
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - landscape/cloudflare.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed:
  - "Cloudflare DNS: mail.aiqadam.org A record (bec8854d698d56ff17cf917367634100 / f3a66e5a4a0124793d49f65d36a7061a) — changed 212.20.151.29 -> 95.46.211.224, then rolled back to 212.20.151.29 (net: unchanged)"
  - "/etc/letsencrypt/live/mail.aiqadam.org/ on pro-data-tech-prod — new Let's Encrypt cert obtained (NOT rolled back, orphaned — see Issues/risks)"
next_step_hint: "Solution-designer (or a follow-on step-04 attempt) must correct Plan step 5's image reference before re-execution. stalwartlabs/mail-server is archived on Docker Hub; the maintained successor appears to be stalwartlabs/stalwart (active, last updated 2026-07-12). Re-verify Stalwart's current compose/image documentation (ports, volume paths, config file format may differ from the mail-server image) before re-approving, since this is more than a tag swap — it may be a different image surface entirely. Re-run from Phase 0 (fresh pre-flight) once step-04 is corrected and re-approved."
---

## Summary
Executed pre-flight (Phase 0) and the DNS/cert prerequisite portion of Phase 1 (Phase 3 step 12, Plan step 6/13) successfully, but Plan step 7 (`docker compose up -d`) failed because the compose file's declared image `stalwartlabs/mail-server:latest` does not resolve on Docker Hub (repository archived); rollback was executed for every applied change except the now-orphaned Let's Encrypt certificate, and the system was confirmed returned to its pre-run state with Penpot and AiQadam-prod unregressed throughout.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes (`step-05-user-approval.md` `inputs_read` lists `runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md`; step-04 verdict was `NEEDS_APPROVAL`)

### Execution log

#### Phase 0, step 1: Re-probe dead host mail ports
- Command: `Test-NetConnection 212.20.151.29 -Port 25` (PowerShell, management workstation)
- Exit code: 0
- Output (trimmed):
  ```
  WARNING: TCP connect to (212.20.151.29 : 25) failed
  WARNING: Ping to 212.20.151.29 failed with status: DestinationHostUnreachable
  ComputerName     : 212.20.151.29
  RemotePort       : 25
  TcpTestSucceeded : False
  ```
- Command: `Test-NetConnection 212.20.151.29 -Port 993`
- Exit code: 0
- Output (trimmed):
  ```
  WARNING: TCP connect to (212.20.151.29 : 993) failed
  WARNING: Ping to 212.20.151.29 failed with status: DestinationHostUnreachable
  ComputerName     : 212.20.151.29
  RemotePort       : 993
  TcpTestSucceeded : False
  ```
- Result: success — old host confirmed still dead on both ports, matching task premise. Gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 2: DNSBL check of 95.46.211.224
- Commands: `nslookup 224.211.46.95.zen.spamhaus.org`, `nslookup 224.211.46.95.bl.spamcop.net`, `nslookup 224.211.46.95.b.barracudacentral.org`
- Exit code: 0 (all three)
- Output (trimmed): all three returned `Non-existent domain` (NXDOMAIN) — not listed on any of the three DNSBLs.
- Result: success — gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 3: Confirm no listener on mail ports on pro-data-tech-prod
- Command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "sudo ss -tlnp | grep -E ':(25|465|587|993|443|8080)\b' || echo NO_MATCHING_LISTENERS"`
- Exit code: 0
- Output (trimmed):
  ```
  LISTEN 0 511 0.0.0.0:443 0.0.0.0:* users:(("nginx",...))
  ```
  (only port 443/nginx present, no listeners on 25/465/587/993/8080)
- Result: success — gate passed. All three Phase 0 pre-flight checks cleared; proceeded to Phase 1.
- Backup taken: n/a (read-only)

#### Plan step 4: Create Compose directory
- Command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /opt/stalwart-mail && sudo chown tvolodi:tvolodi /opt/stalwart-mail && ls -la /opt/stalwart-mail"`
- Exit code: 0
- Output: directory listing showed `drwxr-xr-x 2 tvolodi tvolodi ... .` — owned correctly.
- Result: success
- Backup taken: n/a (new directory, no prior state)

#### Plan step 5: Write docker-compose.yml
- Command: authored file locally, `scp -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes <local-file> tvolodi@95.46.211.224:/opt/stalwart-mail/docker-compose.yml`, then `ssh ... "cat /opt/stalwart-mail/docker-compose.yml"` to diff-verify.
- Exit code: 0
- Output: host content matched authored content exactly (project name `stalwart-mail`, image `stalwartlabs/mail-server:latest`, ports 25/465/587/993 on `0.0.0.0`, 8080 on `127.0.0.1` only, volumes `stalwart_data` + Let's Encrypt cert mount).
- Result: success
- Backup taken: n/a (new file, no prior state)

#### Plan steps 12–13 (reordered ahead of step 6 per the plan's explicit sequencing note): DNS A record + certbot

**Freshness-check `mail.aiqadam.org` A record:**
- Command: `GET /zones/bec8854d698d56ff17cf917367634100/dns_records?name=mail.aiqadam.org&type=A`
- Result: record ID `f3a66e5a4a0124793d49f65d36a7061a`, content `212.20.151.29`, proxied `false`, TTL `300` — matched `landscape/cloudflare.md` exactly. No drift. Proceeded.

**PATCH A record:**
- Command: `PATCH /zones/bec8854d698d56ff17cf917367634100/dns_records/f3a66e5a4a0124793d49f65d36a7061a` `{"content":"95.46.211.224"}`
- Exit code: 0 (HTTP 200, `"success":true`)
- Output: `content: 95.46.211.224`, `modified_on: 2026-07-19T03:12:44.06307Z`
- Result: success
- Verification: fresh `GET` confirmed `content: 95.46.211.224`. External `nslookup mail.aiqadam.org 1.1.1.1` confirmed propagation.
- Backup taken: n/a (Cloudflare retains prior state via API; pre-change value captured above and in `landscape/cloudflare.md`)

**Certbot — obtain cert for mail.aiqadam.org:**
- Command: `ssh ... tvolodi@95.46.211.224 "sudo certbot certonly --nginx -d mail.aiqadam.org --non-interactive --agree-tos -m postmaster@aiqadam.org"`
- Exit code: 0
- Output (trimmed):
  ```
  Requesting a certificate for mail.aiqadam.org
  Successfully received certificate.
  Certificate is saved at: /etc/letsencrypt/live/mail.aiqadam.org/fullchain.pem
  Key is saved at:         /etc/letsencrypt/live/mail.aiqadam.org/privkey.pem
  This certificate expires on 2026-10-17.
  ```
- Result: success
- Verification: `sudo certbot certificates -d mail.aiqadam.org` confirmed `VALID: 89 days`, ECDSA; `sudo ls -la /etc/letsencrypt/live/mail.aiqadam.org/` confirmed `fullchain.pem`/`privkey.pem` symlinks present.
- Backup taken: n/a (new cert, no prior state for this hostname)

#### Plan step 7: Bring up Compose project — FAILED
- Command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose up -d"`
- Exit code: 1
- Output (verbatim):
  ```
  Image stalwartlabs/mail-server:latest Pulling
  Image stalwartlabs/mail-server:latest Error failed to resolve reference "docker.io/stalwartlabs/mail-server:latest": docker.io/stalwartlabs/mail-server:latest: not found
  Error response from daemon: failed to resolve reference "docker.io/stalwartlabs/mail-server:latest": docker.io/stalwartlabs/mail-server:latest: not found
  ```
- Result: **failure**. No container was created (failed at image pull, before container creation).
- Investigation (read-only, to characterize the failure before deciding how to respond — not a workaround attempt): queried Docker Hub's public API for the `stalwartlabs` namespace. Confirmed `stalwartlabs/mail-server` exists but `"status":6, "status_description":"archived"` (last updated 2025-04-30). A separate, active repository `stalwartlabs/stalwart` exists (`"status":1, "status_description":"active"`, last updated 2026-07-12) — appears to be the maintained successor image, but this was NOT verified further and NOT substituted, since swapping images is a design decision outside this step's authority (per "do not improvise" and "no off-plan changes" rules) — potentially a different config/volume/port surface than what step-04 approved, not just a tag rename.
- Backup taken: n/a — halted here per "stop on first error."

### Rollback executed

Per the plan's Rollback section, item 1 ("Compose install rollback, Phases 0–1 steps 4–8") and item 3 ("DNS rollback, Phase 3 steps 12/15/16/17" — only step 12 applied here):

**1. Compose install rollback:**
- Command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose down -v"`
- Exit code: 0. No containers/volumes existed to remove (failure occurred at image-pull, before container creation) — command was a clean no-op confirming nothing was left running.
- Command: `ssh ... tvolodi@95.46.211.224 "sudo rm -rf /opt/stalwart-mail && ls -la /opt/ | grep stalwart || echo REMOVED"`
- Exit code: 0. Output: `REMOVED` — directory confirmed gone.
- Result: success.

**2. DNS rollback (A record only — steps 15/16/17 for SPF/DKIM/DMARC were never reached, so no rollback needed for those):**
- Freshness-check: `GET` on record ID `f3a66e5a4a0124793d49f65d36a7061a` confirmed it still held our own change (`95.46.211.224`) — no third-party drift.
- Command: `PATCH /zones/bec8854d698d56ff17cf917367634100/dns_records/f3a66e5a4a0124793d49f65d36a7061a` `{"content":"212.20.151.29"}`
- Exit code: 0 (HTTP 200, `"success":true`). Output: `content: 212.20.151.29`, `modified_on: 2026-07-19T03:14:17.976538Z`.
- Verification: fresh `GET` confirmed reversion.
- Result: success. **Net effect on this record across the run: unchanged** (matches pre-run `landscape/cloudflare.md` documented value).

**Not rolled back — flagged, not actioned unilaterally:**
- The Let's Encrypt certificate obtained for `mail.aiqadam.org` (`/etc/letsencrypt/live/mail.aiqadam.org/` on `pro-data-tech-prod`) was **not** deleted. The plan's Rollback section does not name a certbot-cleanup step, and deleting certificates/revoking them was not something step-04 specified — per "do not improvise," I did not invent a teardown step beyond what the plan documented. The cert is currently orphaned (no service references it; DNS no longer points at this host for `mail.aiqadam.org`) but is otherwise inert and poses no immediate risk. Flagged under Issues/risks for the user/next design pass to decide: reuse it on re-run (likely still valid, ECDSA, expires 2026-10-17) or have it cleaned up.

### Resources changed
- **Files on host (pro-data-tech-prod):** `/etc/letsencrypt/live/mail.aiqadam.org/` (new cert, NOT rolled back — see above). `/opt/stalwart-mail/` was created then fully removed (net: no residual state).
- **Services restarted:** none (nginx was not reloaded/restarted as part of this run; certbot's `--nginx` plugin only used nginx for HTTP-01 validation, no config file changes were made to existing vhosts).
- **External resources changed:** Cloudflare `mail.aiqadam.org` A record (`f3a66e5a4a0124793d49f65d36a7061a`) — changed then reverted; net: unchanged from pre-run state.

## Issues / risks

- **Plan-blocking defect (root cause of FAIL):** Plan step 5's compose file specifies `image: stalwartlabs/mail-server:latest`. This Docker Hub repository is archived and does not resolve for pulls. The plan's own Issues/risks section (step 04) flagged Stalwart's *CLI/API command syntax* (DKIM generation, account creation) as illustrative/needing live confirmation, but did **not** flag the image reference itself as uncertain — this is a genuine plan defect, not an anticipated discovery gap, so per my execution rules I halted rather than substituting a replacement image on my own authority.
- **Orphaned Let's Encrypt certificate.** `/etc/letsencrypt/live/mail.aiqadam.org/` now exists on `pro-data-tech-prod` (ECDSA, expires 2026-10-17) with no consuming service and no corresponding DNS record (DNS was rolled back). Not a security issue (cert is not secret-bearing in a way that matters if unused, and is not exposed), but it is state on the host that a fresh re-run's Phase 0 discovery should account for (the "confirm no listener" check will still pass; a future certbot run may find an existing cert and reuse/renew it rather than error, which is generally fine, but the design should be aware of it rather than be surprised).
- **Candidate replacement image needs its own verification, not a blind swap.** `stalwartlabs/stalwart` (active repo, last updated 2026-07-12) is the likely successor, but the executor did not inspect its documented port layout, config file format/path, or volume conventions — Stalwart's project has historically used different config approaches between major versions (TOML config file vs. env-var-driven), and the archived `mail-server` image's env-var interface (`STALWART_HOSTNAME=...`) used in this plan's compose file may not carry over. This needs to go back through solution-design (or at minimum a scoped re-verification) rather than be patched by the executor.
- **No regression to Penpot or AiQadam-prod at any point** — confirmed via the mandatory checkpoint both before the failure (Penpot 7/7 Up, AiQadam-prod 4/4 containers Up, both external checks 200) and after rollback completed (identical results). See Execution log for full detail.
- **Observation, off-plan, not actioned:** `pro-data-tech-prod`'s AiQadam-prod Compose project currently shows 4 running containers (`aiqadam-prod-web-next-1`, `aiqadam-prod-api-1`, `aiqadam-prod-oidc-stub-1`, `aiqadam-prod-postgres-1`), where `landscape/hosts/pro-data-tech-prod.md` documents only 3 (`postgres`, `oidc-stub`, `api`) as of its last-verified update (2026-07-17). This is unrelated to this task/plan and was not investigated or touched — noting per the "no off-plan changes" rule for the user's awareness; landscape may be stale relative to a deploy that happened after 2026-07-17.

## Open questions (optional)
- Should the corrected step-04 plan target `stalwartlabs/stalwart:latest` (or a pinned version tag, matching this repo's general preference for pinned versions over `:latest` seen elsewhere, e.g. Penpot's `:2.16`)? Recommend the next solution-design pass pin a specific tag rather than `:latest`, both to avoid this exact class of failure recurring on a future silent repo change, and to match this repo's pinning convention for Penpot.
- Should the orphaned `mail.aiqadam.org` Let's Encrypt cert be reused on re-run (saves a certbot call, still has ~89 days validity) or explicitly cleaned up (`certbot delete --cert-name mail.aiqadam.org`) before/during the next attempt? Deferred to the next design/approval pass rather than decided here.
