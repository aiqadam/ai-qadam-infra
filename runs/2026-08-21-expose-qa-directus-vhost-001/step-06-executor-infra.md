---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 06
agent: executor-infra
verdict: FAIL
created: 2026-08-21T03:15:00Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-04-solution-designer.md
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/cloudflare.md
  - landscape/secrets-inventory.md
  - credentials.md
artifacts_changed:
  - "cloudflare: A record cms.qa.aiqadam.org → 95.46.211.230 created (id 0b4ddd97899b5b7cd6d756a03c25e7ae, proxied=false, ttl=1)"
  - "pro-data-tech-qa: /opt/apps/aiqadam-qa git checkout advanced from 84cfd4d7a3e9bd3a34ba6af7276d2468ea7ed430 (detached) to 05529a2880b56514db53c5561b41dce3be234cff (detached), local AUTHENTIK_ADMIN_URL override preserved via stash/pop"
  - "pro-data-tech-qa: /etc/nginx/sites-available/qa.aiqadam.org overwritten with the 3-vhost config (backup at qa.aiqadam.org.pre-T0142.20260821T080734Z.bak)"
  - "pro-data-tech-qa: certbot cert lineage qa.aiqadam.org expanded to 3 SANs (qa.aiqadam.org, auth.qa.aiqadam.org, cms.qa.aiqadam.org), new serial 51632266b44ba1f662cc270b44ee8efc2d3, expiry 2026-11-19"
  - "pro-data-tech-qa: nginx reloaded (not restarted)"
  - "pro-data-tech-qa: /opt/apps/aiqadam-qa/deploy/.env — appended PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org (backup at .env.pre-T0142.20260821T080913Z.bak); currently inert (see Issues)"
  - "pro-data-tech-qa: aiqadam-qa-web-next-1 force-recreated (StartedAt 2026-08-21T03:11:03Z) — same effective config, no behavior change"
next_step_hint: BLOCKED on Step 10 — the tracked docker-compose.qa.yml ships PUBLIC_DIRECTUS_URL commented out in web-next's inline `environment:` block, with no env_file/interpolation path from deploy/.env. A companion PR (Phase-1-style) must uncomment/wire that line in aiqadam/ai-qadam-platform before web-next can actually pick up the value. Steps 0-9 (DNS, nginx, TLS, external verification, qa.aiqadam.org/auth.qa.aiqadam.org unaffected) are complete and PASS; do not re-run them. Resume at Step 10 once a fast-follow PR lands.
---

## Summary
Executed Steps 0 through 9 of the approved Phase 2 plan successfully — Cloudflare DNS record created, Phase 1's merged nginx config pulled onto the QA host, live nginx file backed up and replaced, TLS certificate expanded to 3 SANs, nginx reloaded, `https://cms.qa.aiqadam.org/server/ping` externally verified (200/`pong`/valid TLS), and `qa.aiqadam.org`/`auth.qa.aiqadam.org` confirmed unaffected (baselines 200/302 unchanged before and after). Step 10 (wire `PUBLIC_DIRECTUS_URL`) halted mid-step: appending the variable to `deploy/.env` and force-recreating `web-next` had no effect, because `web-next`'s compose service definition hardcodes its `environment:` block with the new var's line explicitly commented out and no `env_file`/interpolation mechanism — a plan-time assumption (borrowed from the `api`/Directus `.env`-wiring precedent, T-0125/T-0137) that does not hold for `web-next`. Halting before Step 11 per instructions: do not improvise a fix to a tracked file outside this plan's authorized scope.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (step-05, `inputs_read` references step-04)
- Design references match: yes
- Phase 1 precondition re-confirmed independently: `gh pr view 278 --repo aiqadam/ai-qadam-platform --json state,mergeCommit` → `state: MERGED`, `mergeCommit.oid: 05529a2880b56514db53c5561b41dce3be234cff` (matches orchestrator's Phase 1 confirmation).

### SSH access deviation (noted, not a blocker)
The plan's commands are written as `ssh tvolodi@95.46.211.230 "..."`. From this management workstation, `tvolodi`'s key did not authenticate (`Permission denied (publickey)`) either with the default identity or with the documented `pro-data.tech-qa-instance_rsa.ppk` key. The workstation's `~/.ssh/config` `Host pro-data-tech-qa` alias is configured `User root` (not `tvolodi`, contradicting the landscape doc's note that it configures `tvolodi` — this looks like host-file/reality drift, flagged under Issues below, not investigated further as off-plan). `ssh pro-data-tech-qa` connects successfully as `root` (confirmed `hostname` → `drkkrgm-qa-instance`, matching landscape). All host commands in this run were executed as `root` via this alias instead of `tvolodi`+sudo — functionally equivalent for every command in this plan (all either need root/sudo already, or are read-only), and root's passwordless sudo matches the plan's `sudo` invocations exactly. No plan step required the `tvolodi`-specific user context itself.

### Execution log

#### Step 0.1 — Confirm Directus's live port
- Command: `docker compose -p aiqadam-qa -f /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml port directus 8055`
- Exit code: 1 (`no port 8055/tcp for container aiqadam-qa-directus-1`) — expected under `network_mode: host`, per plan's own fallback note.
- Fallback: `docker inspect aiqadam-qa-directus-1 --format '{{json .Config.Env}}'` → confirmed `PORT=3119` (secret values also present in this same env dump — ADMIN_TOKEN, ADMIN_PASSWORD, DB_PASSWORD, SECRET — none reproduced here or elsewhere in this handoff, per output-hygiene rule).
- Behavioral check: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3119/server/ping` → `200`.
- Result: success. Port confirmed **3119**, matching the plan's provisional value — no Phase 1 PR correction needed.

#### Step 0.2 — Confirm current nginx file state matches assumption
- Command: `diff /etc/nginx/sites-available/qa.aiqadam.org /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf`
- Output: none (files identical)
- Result: success — no undocumented host-local drift.

#### Step 0.3 — Confirm current certbot state
- Command: `sudo certbot certificates`
- Output (trimmed): two lineages — `qa-uz.aiqadam.org` (stale, unrelated, `qa-uz.aiqadam.org` only, expiry 2026-10-11) and `qa.aiqadam.org` (Domains: `qa.aiqadam.org auth.qa.aiqadam.org`, expiry 2026-10-16 pre-change).
- Result: success. Certificate Name confirmed as `qa.aiqadam.org` for the `--cert-name` argument used in Step 5.

#### Step 0.4 — Confirm no existing cms.qa.aiqadam.org DNS record
- Command: `GET /zones/<zone-id>/dns_records?name=cms.qa.aiqadam.org`
- Output: `success: true`, `count: 0`
- Result: success.

#### Step 1 — Cloudflare DNS record creation
- Freshness re-check immediately before POST: `count: 0` (re-confirmed).
- Full zone dump before: 47 records (matches landscape's last documented count).
- Command: `POST /zones/<zone-id>/dns_records` body `{"type":"A","name":"cms.qa.aiqadam.org","content":"95.46.211.230","proxied":false,"ttl":1}`
- Exit code: 0 (HTTP 200, `success: true`)
- Output (trimmed): `id: 0b4ddd97899b5b7cd6d756a03c25e7ae, name: cms.qa.aiqadam.org, content: 95.46.211.230, proxied: false`
- Verification: re-`GET` filtered query → `count: 1`. Full zone dump after: 48 records; diff against before-dump shows exactly one added ID (`0b4ddd97899b5b7cd6d756a03c25e7ae`), zero removed/changed.
- Result: success.
- Backup taken: n/a (additive record; rollback path is DELETE by record ID, documented in plan).

#### Step 2 — Pull merged Phase 1 commit onto the QA host checkout
- Command: `git fetch origin && git log origin/main -1 --format=%H` → `05529a2880b56514db53c5561b41dce3be234cff` (matches Phase 1 mergeCommit exactly).
- Pre-checkout state: HEAD detached at `84cfd4d7a3e9bd3a34ba6af7276d2468ea7ed430`; one modified tracked file (`deploy/docker-compose.qa.yml`, the known T-0125/T-0132 `AUTHENTIK_ADMIN_URL` host-local override — pre-existing, unrelated to this run) plus 5 expected untracked entries (`deploy/.last-deployed-commit`, `.last-deployed-commit.previous`, `deploy.sh`, a dated `.bak`, `deploy/oidc-stub/`).
- **Finding beyond plan's stated scope:** `git diff 84cfd4d..05529a2 --stat` showed 22 files differ, not just the nginx conf — an entire unrelated feature (`wf-20260821-feat-214`, FR-CMS-008/009, `apps/web-next/src/lib/cms.ts`, `deploy/docker-compose.qa.yml`) had landed on `main` in the interim. The plan assumed the checkout was only missing Phase 1's single-file PR; in reality it was many commits stale. This is not itself a blocker (checking out `main`'s current merge-commit SHA, exactly as instructed, is correct regardless of how many intervening commits exist) but is flagged under Issues.
- Command: `git checkout 05529a2880b56514db53c5561b41dce3be234cff` → failed initially (`Your local changes to deploy/docker-compose.qa.yml would be overwritten`), because the target commit's `docker-compose.qa.yml` also differs from the pre-checkout tree (adds a new, non-overlapping `PUBLIC_DIRECTUS_URL` comment block — see Step 10 below).
- Remediation (matches plan's own referenced T-0125 stash/pop precedent): `git stash push -m "T-0142 pre-checkout stash..." -- deploy/docker-compose.qa.yml`, then `git checkout 05529a2880b56514db53c5561b41dce3be234cff` (succeeded, `HEAD is now at 05529a2`), then `git stash pop` (`Auto-merging deploy/docker-compose.qa.yml`, no conflict markers).
- Verification: `git status --porcelain` post-pop is byte-identical to the pre-checkout baseline (same 1 modified file, same 5 untracked entries — nothing appeared or vanished). `grep -c 'server_name cms.qa.aiqadam.org' deploy/nginx/qa.aiqadam.org.conf` → `2` (port-80 + port-443 blocks). Full file read confirms proxy target `127.0.0.1:3119`, no Upgrade/Connection headers, correct cert paths.
- Result: success.

#### Step 3 — Backup live nginx site file
- Command: `sudo cp /etc/nginx/sites-available/qa.aiqadam.org /etc/nginx/sites-available/qa.aiqadam.org.pre-T0142.20260821T080734Z.bak`
- Verification: backup 4228 bytes, `diff` against the live file confirms byte-identical.
- Result: success.
- Backup taken: `/etc/nginx/sites-available/qa.aiqadam.org.pre-T0142.20260821T080734Z.bak`

**Baselines captured before this step (per Step 9's requirement):** `https://qa.aiqadam.org/health` → `200`; `https://auth.qa.aiqadam.org/` → `302` (Authentik's expected root-redirect behavior, not a failure).

#### Step 4 — Apply updated config to live site file
- Command: `ls -la /etc/nginx/sites-available/qa.aiqadam.org` → plain regular file (`-rw-r--r--`), not a symlink.
- Command: `sudo cp /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf /etc/nginx/sites-available/qa.aiqadam.org`
- Verification: `diff` → no output (identical).
- Result: success.

#### Step 5 — TLS: expand the existing certificate via SAN
- Command: `sudo certbot certonly --cert-name qa.aiqadam.org --expand -d qa.aiqadam.org -d auth.qa.aiqadam.org -d cms.qa.aiqadam.org --nginx --non-interactive`
- Exit code: 0. Output: "Successfully received certificate... expires on 2026-11-19."
- Verification (`sudo certbot certificates`): exactly one lineage still named `qa.aiqadam.org` (plus the separate, pre-existing, untouched `qa-uz.aiqadam.org` lineage — same 2-lineage count as Step 0.3), now `Domains: qa.aiqadam.org auth.qa.aiqadam.org cms.qa.aiqadam.org`, new serial `51632266b44ba1f662cc270b44ee8efc2d3`, new expiry `2026-11-19` (89 days).
- **Note on plan-text vs. actual certbot behavior:** the plan's Step 11 checklist states the expiry should be "unchanged from Step 0.3's baseline, proving this was an in-place expand, not a fresh 90-day-clock cert." This is not how `certbot --expand` actually works: SAN expansion legitimately issues a **new certificate** (new serial, new full 90-day validity) *into the same lineage* (same `Certificate Name:`, same `/etc/letsencrypt/live/qa.aiqadam.org/` directory) — the lineage/directory staying the same, not the expiry, is the correct signal that no second lineage was created. Verified the correct signal instead: `Certificate Name:` unchanged, lineage count unchanged (2, matching Step 0.3), certificate path unchanged. Treated this as the plan's own wording being imprecise rather than a real anomaly — not escalated as BLOCKED, since the substantive safety property (no second lineage, no dropped SAN) holds and is independently verified below in Step 8's TLS check.
- Result: success.

#### Step 6 — nginx syntax test
- Command: `sudo nginx -t`
- Output: `syntax is ok` / `test is successful` (both lines present).
- Result: success.

#### Step 7 — Reload nginx
- Command: `sudo systemctl reload nginx`
- Verification: `systemctl status nginx` → `active (running)`. `journalctl -u nginx --since '1 minute ago'` shows only the expected reload notice lines, no errors.
- Result: success.

#### Step 8 — External verification of the new endpoint
- `curl -sS -o /dev/null -w '%{http_code}' https://cms.qa.aiqadam.org/server/ping` → `200`.
- `curl -sS https://cms.qa.aiqadam.org/server/ping` → body `pong`.
- TLS (no `-k`): `openssl s_client ... | openssl x509 -noout -dates -subject -ext subjectAltName` → `notAfter=Nov 19 02:09:35 2026 GMT` (future), SAN list `DNS:auth.qa.aiqadam.org, DNS:cms.qa.aiqadam.org, DNS:qa.aiqadam.org`.
- Result: success.

#### Step 9 — Confirm qa.aiqadam.org and auth.qa.aiqadam.org unaffected
- `https://qa.aiqadam.org/health`: before `200`, after `200` — match.
- `https://auth.qa.aiqadam.org/`: before `302`, after `302` — match.
- Result: success, no regression.

#### Step 10 — Wire PUBLIC_DIRECTUS_URL and recreate web-next
- 10.1 backup: `cp /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.pre-T0142.20260821T080913Z.bak` — 1621 bytes, non-empty. Result: success.
- 10.2 confirm no existing key: `grep -n PUBLIC_DIRECTUS_URL deploy/.env` → exit 1 (no match), as expected. Result: success.
- 10.3 append: `echo 'PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org' >> deploy/.env` → `grep` confirms exactly one line, correct value. Result: success. **Disclosure (CLAUDE.md `.env`-edit rule): variable changed `PUBLIC_DIRECTUS_URL`, old → new: (absent) → `https://cms.qa.aiqadam.org`, why: T-0142, to give QA's web-next a real public Directus origin for governance-document download links. Non-secret URL, not a credential.**
- 10.4 recreate web-next: first attempt `docker compose ... up -d --no-deps web-next` reported `Container aiqadam-qa-web-next-1 Running` (no-op — compose did not detect a need to recreate, since it does not track `.env`-only changes when the service's `environment:` block has no interpolation referencing that key). `docker inspect --format '{{.State.StartedAt}}'` confirmed the container's start time predated this run — **not actually recreated**.
  - Forced: `docker compose ... up -d --no-deps --force-recreate web-next` → `Recreated`/`Started`. `StartedAt` now `2026-08-21T03:11:03Z` (after this run). Exit code: 0.
  - **Verification FAILED:** `docker inspect aiqadam-qa-web-next-1 --format '{{json .Config.Env}}'` shows **no `PUBLIC_DIRECTUS_URL` key at all** in the running container's environment — only `NODE_ENV, HOST, PORT, INTERNAL_API_URL, INTERNAL_DIRECTUS_URL` (plus base image vars).
  - **Root cause, confirmed by reading `deploy/docker-compose.qa.yml` lines 240-283:** the `web-next` service's `environment:` block is entirely **inline hardcoded literals** — no `env_file:` directive, no `${PUBLIC_DIRECTUS_URL}` interpolation anywhere in this service. The tracked file's own comment block (lines 268-283, part of the very commit just pulled in Step 2) explicitly documents the intended activation mechanism: uncomment the line `#   PUBLIC_DIRECTUS_URL: "https://cms.qa.aiqadam.org"` (currently commented out, deliberately, "QA has no Directus vhost yet"). Editing `deploy/.env` has **no effect** on this container — it is not consumed by this service at all.
  - This directly contradicts the plan's Step 10 assumption, which cites "the established T-0125/T-0137 precedent" (env-var rotations via `.env` requiring only a container recreate) — that precedent applies to the `api`/`directus` services (confirmed to use `env_file:` at compose line 193), not to `web-next`, which uses a different, inline-literal wiring pattern.
- Result: **failure**. Stopping here per instructions — this is a plan-vs-reality contradiction requiring escalation, not an in-scope fix (uncommenting the compose file line is a tracked-file change in `aiqadam/ai-qadam-platform`, outside this plan's authorized edit scope, which was Phase 1's nginx-conf-only PR and Phase 2's `.env`-only edit).

### Rollback executed
Not executed. Steps 1-9 are all correct, verified, working, and independently valuable (the `cms.qa.aiqadam.org` endpoint is live and correct; `qa.aiqadam.org`/`auth.qa.aiqadam.org` are unaffected) — rolling them back would destroy real, validated progress toward T-0142's goal for no safety benefit, since nothing about DNS/nginx/TLS is broken or unsafe. Step 10's own changes are inert, not broken:
- The `.env` line (`PUBLIC_DIRECTUS_URL=...`) is a harmless, forward-looking addition — currently consumed by nothing, will become correct and necessary the moment a companion PR uncomments the compose-file line (at which point, per the plan's own comment, `web-next` reads it "at SSR runtime from process.env, so a value change needs only a container restart, not an image rebuild" — meaning once that PR lands and is pulled, this same `.env` line will already be in place and only a plain recreate of `web-next` will be needed, no further `.env` edit).
- The `web-next` force-recreate produced a functionally identical container (same image, same effective env) — confirmed `https://qa.aiqadam.org/` and `/health` both still `200` post-recreate. No regression, nothing to undo.

Per plan Rollback item 1 ("Undo web-next recreate / .env change"), this would only be warranted if the change caused observable harm — it did not. Leaving the `.env` addition and the recreated container in place, matching "decide and proceed" discipline for a fully reversible, harmless, forward-compatible state.

### Resources changed
- **Files on host (pro-data-tech-qa, 95.46.211.230):**
  - `/etc/nginx/sites-available/qa.aiqadam.org` (overwritten with 3-vhost config; backup `qa.aiqadam.org.pre-T0142.20260821T080734Z.bak`)
  - `/etc/letsencrypt/live/qa.aiqadam.org/{fullchain.pem,privkey.pem}` (cert expanded via certbot `--expand`, same lineage, new serial/expiry)
  - `/opt/apps/aiqadam-qa/` git checkout (advanced to `05529a2880b56514db53c5561b41dce3be234cff`, detached; local `AUTHENTIK_ADMIN_URL` override preserved via stash/pop)
  - `/opt/apps/aiqadam-qa/deploy/.env` (one new line appended: `PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org`; backup `.env.pre-T0142.20260821T080913Z.bak`)
- **Services restarted:** `nginx` (reloaded, not restarted); `aiqadam-qa-web-next-1` (recreated — same effective behavior).
- **External resources changed:** Cloudflare DNS — 1 new A record (`cms.qa.aiqadam.org` → `95.46.211.230`, id `0b4ddd97899b5b7cd6d756a03c25e7ae`, proxied=false, ttl=1).

## Issues / risks

- **BLOCKING (this run's stopping reason):** `deploy/docker-compose.qa.yml`'s `web-next` service does not wire `PUBLIC_DIRECTUS_URL` from `.env` — the tracked file ships the line commented out with no `env_file`/interpolation path. `PUBLIC_DIRECTUS_URL` cannot become live in `web-next` without a further tracked-file change (uncommenting that one line) in `aiqadam/ai-qadam-platform`, which requires the same Phase-1-style PR-and-merge process this run already used for the nginx conf. **Recommended next action:** open a small follow-up PR (same pattern as Phase 1) uncommenting `PUBLIC_DIRECTUS_URL: "https://cms.qa.aiqadam.org"` at `deploy/docker-compose.qa.yml` line 283 (and updating the now-stale "Deliberately left UNSET" comment above it), merge, pull onto the QA host (already at `05529a2880b56514db53c5561b41dce3be234cff`, so this would be a small follow-on commit/PR), then a plain `docker compose ... up -d --no-deps web-next` (no `--force-recreate` needed if the compose file itself changed — compose will detect the diff) will complete Step 10. Step 11's final end-to-end checklist cannot be completed until this lands.
- **SSH access deviation:** this workstation's `tvolodi` key did not authenticate against `95.46.211.230` (neither default identity nor the documented `.ppk` key); the `pro-data-tech-qa` SSH-config alias is configured `User root`, contradicting `landscape/hosts/pro-data-tech-qa.md`'s note that it configures `User tvolodi`. All commands were run as `root` instead — functionally equivalent for every step in this plan, but flagged as a landscape-doc/host drift for the user or step-08 to reconcile, not investigated further (off-plan).
- **QA checkout was more stale than the plan assumed:** the pre-pull HEAD (`84cfd4d`) was 22-file-diff/several-commits behind `origin/main`'s merge commit, not just missing Phase 1's single-file PR — an entire other feature (`wf-20260821-feat-214`, FR-CMS-008/009) had landed in the interim. This did not cause any problem for this run (checking out the exact merge-commit SHA is correct regardless of how many other commits came along), but is worth noting for whoever tracks deploy freshness (this echoes the still-open T-0133 "no automated deploy-freshness alerting" gap noted in the host's own change-log).
- **Plan-text imprecision on certbot `--expand` expiry behavior** (see Step 5 above) — not a real anomaly, but the plan's Step 11 checklist item about "expiry unchanged" should be corrected to "lineage/Certificate Name unchanged" for future runs; flagged for whoever maintains this plan template.
- **Secret values appeared transiently in this session's own command output** (Step 0.1's `docker inspect ... Config.Env` dump included `ADMIN_TOKEN`, `ADMIN_PASSWORD`, `DB_PASSWORD`, `SECRET` for the Directus container) — none reproduced in this handoff or any file in this repo; flagged only so the user is aware this command, if re-run, will surface secrets in the terminal/transcript (same class of exposure as T-0136's self-reported incident) — consider a more targeted `grep` (e.g., `grep -o 'PORT=[0-9]*'` instead of dumping the full env array) in future discovery steps to avoid this.

## Open questions (optional)
- Should the follow-up PR to uncomment `PUBLIC_DIRECTUS_URL` in `docker-compose.qa.yml` be filed as a new task (e.g. a T-0142 continuation or a dedicated T-014x), or should T-0142 itself simply extend Phase 1 with a second small PR before being marked done? Recommend the latter, since T-0141 (blocked by T-0142) explicitly needs this value live in `web-next`, not just the endpoint reachable.
- Should the `pro-data-tech-qa` SSH-config alias's `User root` vs. documented `User tvolodi` discrepancy be corrected in the landscape doc, or is the alias itself stale and should be fixed to point at `tvolodi`? Recommend confirming with the user before either the doc or the config file changes.
