---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-21T03:10:00Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-01-task-reader.md
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-02-landscape-reader.md
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-03-task-validator.md
  - tasks/T-0142-expose-qa-directus-vhost.md
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/cloudflare.md
artifacts_changed: []
next_step_hint: Orchestrator halts for user approval per shared/approval-protocol.md. On APPROVED, Phase 1 (app-repo PR) must be opened and MERGED before any Phase 2 (executor-infra) step touches the live host. Do not let the executor skip straight to host edits.
---

## Summary
Add a public HTTPS endpoint for QA's Directus (`cms.qa.aiqadam.org`) by (Phase 1) landing a companion PR against `aiqadam/ai-qadam-platform` that adds a third server-block pair to the tracked `deploy/nginx/qa.aiqadam.org.conf`, merging it, and pulling it onto the QA host checkout; then (Phase 2) creating the Cloudflare DNS record, symlinking the updated config live, expanding the existing `qa.aiqadam.org` certbot certificate via SAN, reloading nginx, and wiring `PUBLIC_DIRECTUS_URL` into QA's `web-next` container — leaving `qa.aiqadam.org` and `auth.qa.aiqadam.org` demonstrably unaffected throughout.

## Details

### Phase 1 — Companion app-repo PR (prerequisite gate; not this repo's approval gate)

This phase is a doc/config change in `aiqadam/ai-qadam-platform`, a different repo. It carries no live blast radius on its own — a bad directive in a tracked file does nothing until it is deployed and reloaded on a host. It does **not** require this repo's `NEEDS_APPROVAL` gate in the same sense Phase 2 does. However: **Phase 1's own merge is a hard prerequisite gate for Phase 2.** No live host nginx file may be touched until this PR is merged into `main` and that commit is the one pulled onto the QA checkout. This is the explicit anti-drift requirement carried forward from step-03's validation (the T-0125/T-0132 precedent).

1. **Branch and edit** — in a checkout of `aiqadam/ai-qadam-platform`, on a new branch (e.g. `infra/T-0142-expose-qa-directus-vhost`), edit `deploy/nginx/qa.aiqadam.org.conf`. Insert a third server-block pair after the existing `auth.qa.aiqadam.org` blocks (after line 103 in the current file), following the exact same structure as the `auth.qa.aiqadam.org` pair (lines 78-103) but as a plain reverse proxy (no `Upgrade`/`Connection` headers — Directus's public asset/API surface being exposed here doesn't need WebSocket upgrade, per the task's own precedent note):

   ```nginx

   server {
       listen 80;
       listen [::]:80;
       server_name cms.qa.aiqadam.org;
       return 301 https://$host$request_uri;
   }

   server {
       listen 443 ssl;
       listen [::]:443 ssl;
       server_name cms.qa.aiqadam.org;

       ssl_certificate     /etc/letsencrypt/live/qa.aiqadam.org/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/qa.aiqadam.org/privkey.pem;

       location / {
           proxy_pass http://127.0.0.1:<DIRECTUS_PORT>;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

   `<DIRECTUS_PORT>` is a placeholder — it MUST be filled in with the value confirmed live by Phase 2 / Step 0 discovery (see below), not blindly copied as `3119` from the task file. If Phase 1 is authored before Phase 2's discovery step runs, use `3119` provisionally (matching the task's own stated last-known value) but the PR description must flag it as "pending live re-verification in the infra half of T-0142" — and if discovery in Phase 2 finds a different port, Phase 1's PR must be amended (a follow-up commit on the same PR/branch, before merge) to match reality before it lands. Do not merge Phase 1 with a port value known to be wrong.

   Also update the file's own header comment (lines 10-24) to mention the third hostname, consistent with how it already documents the first two, e.g. append a short paragraph after line 17:
   ```
   #
   # A third hostname, cms.qa.aiqadam.org, exposes Directus's public
   # asset/API surface (read-only content, no admin UI requirement)
   # directly — no WebSocket upgrade needed, unlike auth.qa's Authentik
   # flow-UI requirement.
   ```
   And update the "Deploying this file" note (lines 19-24) to mention the new site file needs the same copy/symlink + `nginx -t && systemctl reload nginx` treatment.

2. **Open PR** — command: `gh pr create --repo aiqadam/ai-qadam-platform --title "infra(T-0142): add cms.qa.aiqadam.org vhost to qa.aiqadam.org.conf" --body "<summary, links this run's task file, notes port is pending live confirmation if provisional>"` — verification: PR opens against `main`, diff shows only the added server-block pair + header-comment updates to `deploy/nginx/qa.aiqadam.org.conf`, no other file touched.

3. **CI green + merge** — command: `gh pr checks <PR#>` then, once green, `gh pr merge <PR#> --squash` (or per that repo's own merge convention if it differs — check `CONTRIBUTING`/recent merged PRs first) — verification: PR shows `MERGED` state, `main` now contains the new server-block pair.

4. **This phase's own gate:** Phase 2 step 2 (pulling the checkout on the QA host) MUST reference the merged commit SHA. If for any reason the PR cannot be merged (CI red, review blocked, no write access), **stop here** and surface that to the user explicitly — do not fall back to editing the live host file directly and deferring the PR, which is the exact T-0125/T-0132 anti-pattern this run exists to avoid.

### Phase 2 — Infra (live host + DNS + TLS + env) — THIS is what NEEDS_APPROVAL gates

**Precondition check (mandatory, before any Phase 2 step runs):** confirm Phase 1's PR is merged — command: `gh pr view <PR#> --repo aiqadam/ai-qadam-platform --json state,mergeCommit` — must show `"state": "MERGED"` with a non-null `mergeCommit`. If not, halt with `BLOCKED`; do not proceed.

#### Step 0 — Live discovery (no assumptions carried from task text)

0.1. **Confirm Directus's live port** — command (on `pro-data-tech-qa` via `ssh tvolodi@95.46.211.230`): `docker compose -p aiqadam-qa -f /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml port directus 8055` (Directus's own internal port is 8055; this resolves the host-side binding) — if that subcommand doesn't resolve cleanly under `network_mode: host`, fall back to `docker inspect aiqadam-qa-directus-1 --format '{{json .Config.Env}}' | tr ',' '\n' | grep -i PORT` and cross-check against `ss -ltnp | grep docker-proxy` or `ss -ltnp | grep <directus-pid>` for the actual listening socket, and independently confirm with `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3119/server/ping` (expect `200`) as a direct behavioral check rather than trusting config alone. **Verification:** a port number is confirmed both by config inspection AND a live HTTP 200 from `/server/ping` on that port. If the confirmed port differs from `3119`, update the Phase 1 PR (if not yet merged) or file a fast-follow correction PR (if already merged) before proceeding — do not silently proxy to the wrong port.

0.2. **Confirm current nginx file state matches assumption** — command: `ssh tvolodi@95.46.211.230 "diff /etc/nginx/sites-available/qa.aiqadam.org /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf"` (pre-pull, i.e. before Phase 2 Step 2's `git pull`) — expect no output (files identical), confirming the live symlinked/copied file is not already independently drifted from the checkout's pre-Phase-1 state. If `diff` shows unexpected differences, stop and investigate before proceeding (possible undocumented host-local edit, the exact drift class this run is designed to avoid compounding).

0.3. **Confirm current certbot state** — command: `ssh tvolodi@95.46.211.230 "sudo certbot certificates"` — expect a certificate lineage (name to be confirmed — landscape's `domains.md` only names `qa-uz.aiqadam.org` as a lineage, which is stale) covering exactly `qa.aiqadam.org` + `auth.qa.aiqadam.org` as SANs, backing `/etc/letsencrypt/live/qa.aiqadam.org/`. Record the exact `Certificate Name:` value — Phase 2 Step 5's `--expand` command must target this exact name.

0.4. **Confirm no existing `cms.qa.aiqadam.org` DNS record** — command: `curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records?name=cms.qa.aiqadam.org" -H "Authorization: Bearer <cloudflare-ai-qadam-api-token>"` (token by name, from `landscape/secrets-inventory.md`) — expect `"result": []` / `"count": 0`. This is also the mandatory freshness check immediately before the create in Step 1 (per this repo's shared-resource-surgery convention) — do not treat this 0.4 check as satisfying that later freshness requirement; re-run it again immediately before the `POST` in Step 1.

#### Step 1 — Cloudflare DNS record creation

Command:
```
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records" \
  -H "Authorization: Bearer <cloudflare-ai-qadam-api-token>" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"cms.qa.aiqadam.org","content":"95.46.211.230","proxied":false,"ttl":1}'
```
(Zone ID and API token referenced by name only — see `landscape/secrets-inventory.md`: `cloudflare-ai-qadam-account-id` context, zone ID `bec8854d698d56ff17cf917367634100` per `landscape/cloudflare.md` — reference only, not a secret itself.)

**Verification:** response `"success": true`, new `id` returned; immediately re-`GET` the same filtered query from Step 0.4 to confirm exactly one record now exists with `content: "95.46.211.230"`, `proxied: false`. Record the returned record ID for rollback. Per this zone's shared-resource-surgery discipline, also take a full zone dump immediately before and after (`GET /zones/<zone-id>/dns_records` with no filter, save both to a temp file) and diff them — expect exactly one added record (`cms.qa.aiqadam.org`), zero other records touched.

#### Step 2 — Pull merged Phase 1 commit onto the QA host checkout

Command: `ssh tvolodi@95.46.211.230 "cd /opt/apps/aiqadam-qa && git fetch origin && git log origin/main -1 --format=%H"` — confirm this SHA matches the `mergeCommit` from the Phase 1 precondition check. Then: `ssh tvolodi@95.46.211.230 "cd /opt/apps/aiqadam-qa && git checkout main && git pull --ff-only origin main"`.

**Note on idempotency/drift risk:** the checkout is normally in a detached-HEAD state pinned to a deployed SHA (per `deploy.sh`'s own model, `git checkout --detach <ref>`), not tracking `main` directly. Before running `git pull`, first check `git status` and `git branch --show-current` — if detached, use `git fetch origin && git checkout <merged-SHA-or-later>` instead of assuming a `main` branch checkout exists locally. Do **not** use `deploy.sh`'s own `deploy:<sha>` forced-command mechanism for this pull alone (that mechanism also runs `docker compose up -d --build`, which would recreate all 7 containers — out of scope and unnecessary for a config-file-only pull; this task's compose/container recreate is scoped only to `web-next` in Step 8, after the env change). Confirm `deploy/` itself (untracked per `deploy.sh`'s own header-comment rule) is unaffected by the pull — `.env`, `deploy.sh`, and any host-local files must survive; use `git status --porcelain` post-pull to confirm no unexpected local modifications appear or vanish.

**Verification:** `cat /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf` shows the new `cms.qa.aiqadam.org` server-block pair (grep for `server_name cms.qa.aiqadam.org` — expect 2 matches, port-80 and port-443 blocks).

#### Step 3 — Backup live nginx site file before overwriting

Command: `ssh tvolodi@95.46.211.230 "sudo cp /etc/nginx/sites-available/qa.aiqadam.org /etc/nginx/sites-available/qa.aiqadam.org.pre-T0142.$(date -u +%Y%m%dT%H%M%SZ).bak"` — verification: backup file exists, byte-identical to the pre-change live file (`diff` against the file confirmed in Step 0.2).

#### Step 4 — Apply the updated config to the live site file

Determine whether the live file is a copy or a symlink first: `ssh tvolodi@95.46.211.230 "ls -la /etc/nginx/sites-available/qa.aiqadam.org"`.
- If it is a **symlink** to the checkout path already (matching the file header's own "copy/symlink" instruction), no action needed beyond the `git pull` in Step 2 — the live file updates automatically. Confirm with `readlink -f /etc/nginx/sites-available/qa.aiqadam.org` pointing at `/opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf`.
- If it is a **plain copy** (not a symlink), command: `ssh tvolodi@95.46.211.230 "sudo cp /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf /etc/nginx/sites-available/qa.aiqadam.org"`.

**Verification:** `diff /etc/nginx/sites-available/qa.aiqadam.org /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf` — no output (identical).

#### Step 5 — TLS: expand the existing certificate via SAN

Command: `ssh tvolodi@95.46.211.230 "sudo certbot certonly --cert-name <certificate-name-from-0.3> --expand -d qa.aiqadam.org -d auth.qa.aiqadam.org -d cms.qa.aiqadam.org --nginx"` (use the exact existing SAN list plus the new hostname — omitting an existing SAN here would **drop** it from the cert, so all three must be listed explicitly, not just the new one).

**Verification:** command exits 0; `sudo certbot certificates` afterward shows exactly one certificate lineage (same `Certificate Name:` as before) with `Domains: qa.aiqadam.org auth.qa.aiqadam.org cms.qa.aiqadam.org` — confirm no second lineage was accidentally created (`sudo certbot certificates | grep -c "Certificate Name:"` still returns the same count as pre-change, e.g. `1` if that's confirmed in Step 0.3).

#### Step 6 — nginx syntax test (never skip; never `restart`)

Command: `ssh tvolodi@95.46.211.230 "sudo nginx -t"` — verification: output contains `syntax is ok` and `test is successful` for both lines. **Do not proceed to Step 7 if this fails.**

#### Step 7 — Reload nginx (not restart — avoid dropping active connections to the other two vhosts)

Command: `ssh tvolodi@95.46.211.230 "sudo systemctl reload nginx"` — verification: `systemctl status nginx` shows `active (running)`, no new error lines in `sudo journalctl -u nginx --since '1 minute ago'`.

#### Step 8 — External verification of the new endpoint

Command: `curl -sS -o /dev/null -w '%{http_code}\n' https://cms.qa.aiqadam.org/server/ping` — expect `200`. Also: `curl -sS https://cms.qa.aiqadam.org/server/ping` — expect body `pong`. Also verify TLS chain validity (no `-k` flag used — a clean `curl` success without `--insecure` already proves a trusted chain; additionally `echo | openssl s_client -connect cms.qa.aiqadam.org:443 -servername cms.qa.aiqadam.org 2>/dev/null | openssl x509 -noout -dates -subject` to confirm `notAfter` is in the future and the cert covers the expected SAN set via `-ext subjectAltName`).

#### Step 9 — Confirm `qa.aiqadam.org` and `auth.qa.aiqadam.org` unaffected

Commands:
- `curl -sS -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` — expect `200` (matches pre-change baseline; capture this baseline value in a pre-Phase-2 pre-flight run of the same command, before Step 3, for a true before/after comparison).
- `curl -sS -o /dev/null -w '%{http_code}\n' https://auth.qa.aiqadam.org/` (or `/-/health/ready/` if a more specific Authentik health path is preferred) — expect the same status as the pre-change baseline.

Both must be run **before** Step 3 (to capture baseline) and **after** Step 7 (to confirm no regression) — record both values in the execution-validator's step-07 handoff.

#### Step 10 — Wire `PUBLIC_DIRECTUS_URL` and recreate `web-next`

10.1. **Backup `.env`** — command: `ssh tvolodi@95.46.211.230 "cp /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.pre-T0142.$(date -u +%Y%m%dT%H%M%SZ).bak"` — verification: backup file exists, same byte size/content as pre-change `.env`.

10.2. **Confirm no existing `PUBLIC_DIRECTUS_URL` key** — command: `ssh tvolodi@95.46.211.230 "grep -n PUBLIC_DIRECTUS_URL /opt/apps/aiqadam-qa/deploy/.env"` — expect no match (exit code 1), consistent with landscape-reader's finding that no such value is currently documented. If a match IS found unexpectedly, stop and reconcile before proceeding (this would mean the task's premise of "net-new wire-up" is wrong).

10.3. **Append the new line** — command: `ssh tvolodi@95.46.211.230 "echo 'PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org' >> /opt/apps/aiqadam-qa/deploy/.env"` — verification: `grep PUBLIC_DIRECTUS_URL /opt/apps/aiqadam-qa/deploy/.env` shows exactly one line, `PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org`.

   Per this run's non-secret-config-flag classification (a URL, not a credential) and this repo's own `.env` handling precedent for QA (already treated as a routine, backed-up, in-place edit for `DATABASE_URL`/token rotations in T-0137/T-0138), this is a direct edit, stated here per output-hygiene discipline: **variable changed: `PUBLIC_DIRECTUS_URL`, old → new: (absent) → `https://cms.qa.aiqadam.org`, why: T-0142, to give QA's web-next a real public Directus origin for governance-document download links.** No secret value is involved.

10.4. **Recreate only `web-next`** — command: `ssh tvolodi@95.46.211.230 "cd /opt/apps/aiqadam-qa/deploy && docker compose -p aiqadam-qa -f docker-compose.qa.yml up -d --no-deps web-next"` — matches the established T-0125/T-0137 precedent (env vars are not hot-reloaded; recreate the single affected container, not the full stack). **Verification:** `docker inspect aiqadam-qa-web-next-1 --format '{{.State.StartedAt}}'` shows a timestamp after the command ran; `docker inspect aiqadam-qa-web-next-1 --format '{{json .Config.Env}}' | grep -o 'PUBLIC_DIRECTUS_URL=[^,"]*'` shows the new value live inside the container.

#### Step 11 — Final end-to-end verification (matches T-0142's "What done looks like" checklist)

- `https://cms.qa.aiqadam.org/server/ping` → `200`, body `pong`, valid TLS (already checked in Step 8; re-confirm here as the final closing check).
- `sudo certbot certificates` shows one lineage, three SANs (`qa.aiqadam.org auth.qa.aiqadam.org cms.qa.aiqadam.org`).
- `systemctl status certbot.timer` — confirm `active (waiting)`, no separate/second timer or renewal job was created; the existing timer's next-run schedule is unaffected by `--expand` (SAN expansion is understood to be additive to the same lineage/cert file, not a new cert object — confirm via the `certbot certificates` expiry date being unchanged from Step 0.3's baseline, proving this was an in-place expand, not a fresh 90-day-clock cert).
- QA `web-next` container confirmed to carry the new `PUBLIC_DIRECTUS_URL` env value (Step 10.4).
- `qa.aiqadam.org` and `auth.qa.aiqadam.org` both return their pre-change baseline status codes (Step 9), confirmed after all other changes are complete, not just immediately after the nginx reload.
- End-user check (defer full execution to T-0141, but confirm the origin resolves correctly here): a manual `curl` of the pattern `https://cms.qa.aiqadam.org/assets/<any-known-existing-asset-id>` (if any content_documents/content_pages asset ID is already known from T-0136's seeding) returns a real asset, not a 404/502 — optional smoke test, not blocking, since full content verification is explicitly T-0141's scope.
- Task file's own checklist item "Handoff to T-0141": confirm this task transitions to `done` and T-0141's `blocked_by`/`status` is updated to unblock it (landscape-updater / orchestrator responsibility at step 08, not the executor's).

### Rollback

Ordered to reverse in the opposite sequence changes were applied (Step 10 first, back to Step 1 last), so the host is never left in a state where DNS resolves but nginx doesn't have a matching, working config, or vice versa longer than necessary:

1. **Undo `web-next` recreate / `.env` change** — command: `ssh tvolodi@95.46.211.230 "cp /opt/apps/aiqadam-qa/deploy/.env.pre-T0142.<timestamp>.bak /opt/apps/aiqadam-qa/deploy/.env && cd /opt/apps/aiqadam-qa/deploy && docker compose -p aiqadam-qa -f docker-compose.qa.yml up -d --no-deps web-next"` — verification: `PUBLIC_DIRECTUS_URL` absent again from the running container's env (matches pre-change state).

2. **Undo nginx reload** — restore the backed-up site file and reload: `ssh tvolodi@95.46.211.230 "sudo cp /etc/nginx/sites-available/qa.aiqadam.org.pre-T0142.<timestamp>.bak /etc/nginx/sites-available/qa.aiqadam.org && sudo nginx -t && sudo systemctl reload nginx"` — verification: `qa.aiqadam.org`/`auth.qa.aiqadam.org` still 200; `cms.qa.aiqadam.org` now fails to route via nginx (connection succeeds at TLS layer if cert isn't rolled back, but 404/502 at the application layer since no matching `server_name` block exists — acceptable; DNS/cert rollback below is what fully removes the surface).

3. **Cert non-expansion is irreversible-ish, but low-risk (additive SAN, not a replacement) — no rollback action needed by default.** If a genuine rollback of the cert is required (e.g., an unwanted SAN must not remain issued), the correct action is `sudo certbot certonly --cert-name <certificate-name> --expand -d qa.aiqadam.org -d auth.qa.aiqadam.org --nginx` (re-issuing without `cms.qa.aiqadam.org` in the SAN list) — note this still leaves a public CT-log record of the now-revoked SAN having briefly existed (a Certificate Transparency log entry is permanent and public regardless of subsequent reissuance) — this is expected, low-risk, and not itself a secret or credential exposure; do not attempt `certbot revoke`, which is unnecessary here and would affect the shared cert's validity for `qa.aiqadam.org`/`auth.qa.aiqadam.org` too.

4. **Undo checkout pull (Phase 1 sync)** — only if the pulled commit itself is somehow found to be bad beyond the nginx file (unlikely, since Phase 1's PR is scoped to exactly one file): `ssh tvolodi@95.46.211.230 "cd /opt/apps/aiqadam-qa && git checkout <pre-pull-SHA>"` — verification: `git log -1` shows the pre-Phase-2 SHA again, `deploy/nginx/qa.aiqadam.org.conf` back to two server-block pairs.

5. **Undo DNS record creation** — command: `curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records/<record-id-from-step-1>" -H "Authorization: Bearer <cloudflare-ai-qadam-api-token>"` — verification: response `"success": true`; re-`GET` the filtered query confirms `"count": 0` for `cms.qa.aiqadam.org` again. Per shared-resource-surgery discipline, take a fresh zone dump and confirm only this one record is gone versus the post-Step-1 dump — no other record touched by the rollback.

**Phase 1 (companion PR) rollback:** if the PR is merged but the infra half is later fully rolled back (e.g., the feature is abandoned), the tracked nginx file change does not need to be reverted purely because the live site isn't using it — an inert, unused `server{}` block in the tracked file matching a DNS name that doesn't resolve to it is harmless (same reasoning the task itself applies to why Phase 1 alone carries no live risk). Only revert the Phase 1 PR (a new PR reverting the commit) if the user explicitly wants the tracked file to no longer describe a `cms.qa.aiqadam.org` vhost at all.

### Verification (for step 07)

- **On-host:**
  - `sudo nginx -t` passes (both syntax and test lines).
  - `diff /etc/nginx/sites-available/qa.aiqadam.org /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf` — no output.
  - `sudo certbot certificates` — one lineage, three SANs (`qa.aiqadam.org`, `auth.qa.aiqadam.org`, `cms.qa.aiqadam.org`), same `Certificate Name:` as pre-change baseline, unchanged expiry date (proving in-place `--expand`, not a new cert lineage).
  - `systemctl status certbot.timer` — `active (waiting)`, unchanged schedule.
  - `grep PUBLIC_DIRECTUS_URL /opt/apps/aiqadam-qa/deploy/.env` — exactly one line, correct value.
  - `docker inspect aiqadam-qa-web-next-1` — `State.Status: running`, env includes the new `PUBLIC_DIRECTUS_URL`, `StartedAt` after the Step 10.4 recreate command ran.
  - `git -C /opt/apps/aiqadam-qa log -1 --format=%H` matches the Phase 1 PR's merge commit (or a later commit that still contains it).
- **External:**
  - `GET https://cms.qa.aiqadam.org/server/ping` → `200`, body `pong`.
  - TLS chain valid (no `-k`/`--insecure` needed for the `curl` above to succeed; SAN list on the presented cert includes `cms.qa.aiqadam.org`).
  - DNS: `dig +short cms.qa.aiqadam.org` (or `nslookup`) → `95.46.211.230`, matching the `A` record created in Step 1.
  - `GET https://qa.aiqadam.org/health` → `200`, matching the pre-change baseline captured before Step 3.
  - `GET https://auth.qa.aiqadam.org/` (or its health path) → matching the pre-change baseline captured before Step 3.
  - Cloudflare zone dump diff (pre-Step-1 vs. post-Step-1): exactly one record added (`cms.qa.aiqadam.org`), zero other records changed.

### Resources used

- **Secrets (by name):** `cloudflare-ai-qadam-api-token` (DNS record create/delete). No Directus secret (`DIRECTUS_ADMIN_TOKEN` or similar) is used anywhere in this plan — this task performs no Directus API calls, only a reverse-proxy/DNS/TLS/env change in front of it.
- **Files modified on host (`pro-data-tech-qa`, `95.46.211.230`):**
  - `/etc/nginx/sites-available/qa.aiqadam.org` (or confirmed-symlink, no direct edit needed)
  - `/etc/letsencrypt/live/qa.aiqadam.org/` (cert files, via certbot `--expand`)
  - `/opt/apps/aiqadam-qa/` (git checkout, pulled forward to Phase 1's merged commit)
  - `/opt/apps/aiqadam-qa/deploy/.env` (one new line, `PUBLIC_DIRECTUS_URL`)
  - Backups created: `/etc/nginx/sites-available/qa.aiqadam.org.pre-T0142.<ts>.bak`, `/opt/apps/aiqadam-qa/deploy/.env.pre-T0142.<ts>.bak`
- **Files modified in this repo (`landscape/`, to be applied at step 08):**
  - `landscape/cloudflare.md` — new `cms.qa.aiqadam.org` A record row, updated record count, updated `last_verified`/`last_verified_note`.
  - `landscape/domains.md` — new TLS SAN entry for the expanded `qa.aiqadam.org` cert lineage (and, opportunistically, correct the pre-existing documentation gap flagged by step-02: the cert lineage name currently shown as only `qa-uz.aiqadam.org` should be corrected/reconciled with the actual live lineage name confirmed in Phase 2 Step 0.3).
  - `landscape/services.md` — new `cms.qa.aiqadam.org` public endpoint entry for Directus; confirm/record Directus's live port discovered in Step 0.1 (closing the "not enumerated" gap flagged by both task-reader and landscape-reader).
  - `landscape/hosts/pro-data-tech-qa.md` — nginx vhost section updated to describe the third server-block pair; `.env` change log entry for `PUBLIC_DIRECTUS_URL`; Change log / History entry for this run.
- **Files modified in `aiqadam/ai-qadam-platform` (Phase 1, separate repo, via PR):** `deploy/nginx/qa.aiqadam.org.conf` only.
- **External APIs called:** Cloudflare API (`dns_records` GET/POST/DELETE), GitHub API (`gh pr create`/`checks`/`merge`/`view` via `gh` CLI), Let's Encrypt (via `certbot`).

### Estimated impact

- **Downtime:** none expected for `qa.aiqadam.org`/`auth.qa.aiqadam.org` — `systemctl reload nginx` (not `restart`) is designed to gracefully finish in-flight connections and pick up new config with no connection drop. `web-next` recreate (Step 10.4) causes a brief (seconds) interruption to that single container only — acceptable, matches established precedent (T-0125, T-0137, T-0138 all recreated single containers for env changes with no broader downtime).
- **Affected services:** `nginx` (shared config file, reloaded — not restarted), the `qa.aiqadam.org` TLS certificate (SAN-expanded, shared by all three hostnames), Cloudflare DNS zone (`aiqadam.org`, shared/non-exclusive — one new, uniquely-named record added), `aiqadam-qa-web-next-1` (recreated).
- **Reversibility:** fully reversible for DNS (delete), nginx config (restore backup + reload), `.env` (restore backup + recreate). The TLS SAN expansion is reversible via a second `--expand` omitting the new hostname, with the caveat that the Certificate Transparency log entry for the now-removed SAN is permanent and public (low-risk, not a secret, expected/accepted behavior of the public CA ecosystem — not a data or credential exposure).

## Issues / risks

- **Shared blast radius (per task/step-03's own classification):** a syntax error or misconfiguration anywhere in `qa.aiqadam.org.conf` — even in an unrelated block — would take down all three hostnames on `reload`, not just fail to add the new one. Mitigated by the mandatory `nginx -t` gate (Step 6) before any `reload`, and by capturing pre-change baselines for `qa.aiqadam.org`/`auth.qa.aiqadam.org` (Step 9) so a regression is caught immediately, not discovered later.
- **Shared Cloudflare zone:** `aiqadam.org` hosts unrelated third-party mail/tunnel/GitHub-Pages records outside this repo's ownership. The plan scopes every DNS operation to a single, uniquely-named record (`cms.qa.aiqadam.org`) with a freshness check immediately before mutation and a before/after full zone dump diff, per this repo's established shared-resource-surgery discipline (T-0110/T-0111/T-0117 precedent) — no broader zone-wide operation is proposed.
- **Cross-repo sequencing dependency:** Phase 2 cannot safely begin until Phase 1's PR is merged AND that exact commit is confirmed pulled onto the host checkout. The plan makes this an explicit, checked precondition (not an assumption) specifically to avoid repeating the T-0125/T-0132 drift pattern. If PR merge is blocked for reasons outside this run's control (CI, review, access), the correct response is to halt and escalate to the user — not to proceed with a host-local-only edit "temporarily."
- **Directus port not independently confirmed as of this design** — both landscape-reader and task-reader flagged `3119` as unconfirmed-in-structured-data. This plan treats it as a mandatory Step 0.1 live discovery/re-verification, not an assumption, and explicitly requires the Phase 1 PR's proxied port to match whatever Step 0.1 confirms (with a fast-follow correction path if Phase 1 already merged with a since-proven-wrong value).
- **Cert lineage name gap in `landscape/domains.md`** (flagged by step-02: only `qa-uz.aiqadam.org` is documented as a lineage, which is stale) — this plan's Step 0.3 live-discovers the actual current name and uses it directly in the `--expand` command rather than trusting the stale landscape doc; step 08 should also correct this documentation gap regardless of this task's outcome.
- **This is a P2, non-incident task** (unlike T-0125's P0 live-outage context) — there is no urgency justification for accepting a host-first/upstream-later shortcut here, consistent with step-03's reasoning. The two-phase, PR-first sequencing is deliberately the slower, safer path.
- **No Directus API/secret interaction in this plan** — confirmed no `DIRECTUS_ADMIN_TOKEN` or other Directus credential is read, written, or referenced anywhere in Phase 1 or Phase 2; the general no-`grep -B/-A`-plus-`-v` output-hygiene rule from this week's rotations is noted as still applicable to any host file reads in this plan (e.g., `.env` reads/greps in Steps 10.2/10.3), even though no secret value is actually at risk here (`PUBLIC_DIRECTUS_URL` is a public URL, not a credential).
- **Why this plan is `NEEDS_APPROVAL` (per step-03's binding determination, not re-litigated here):** the task file's `estimated_blast_radius: medium` alone disqualifies auto-approval under `shared/approval-protocol.md` condition 1, independent of the DNS/nginx-on-shared-host classification, which independently also disqualifies it. Both conditions hold simultaneously; this design carries that determination forward without modification.
