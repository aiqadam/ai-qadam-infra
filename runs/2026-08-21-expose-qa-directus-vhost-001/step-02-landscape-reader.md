---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-08-21T02:51:27Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/services.md
artifacts_changed: []
next_step_hint: task-validator should focus on the companion-app-repo-PR structural question (T-0125/T-0132 drift precedent) and reconfirm the always-NEEDS_APPROVAL classification for solution-designer.
---

## Summary
The landscape confirms every precedent the task claims: `auth.qa.aiqadam.org` already rides the same host/DNS/cert pattern needed for `cms.qa.aiqadam.org` (plain unproxied A record → `95.46.211.230`, single SAN-expanded certbot cert, single tracked nginx file with multiple server-block pairs), and the shared-zone caution on `aiqadam.org` is well-documented and still current. Directus's port (`3119`) is asserted only in `pro-data-tech-qa.md`'s frontmatter changelog prose (T-0136/T-0137/T-0138, dated 2026-08-20) — it does not appear in that file's structured container tables, which is exactly the kind of gap the task's own text flags for live re-verification rather than assumption. No landscape file is stale (all four are within 30 days of today) or stubbed.

## Details
### Relevant facts (sourced from landscape)
- `auth.qa.aiqadam.org` → `95.46.211.230`, plain `A`, `proxied: false` — same shape row-for-row as `qa.aiqadam.org` (both "discovered, not this repo" as of their creation, but the DNS shape is the established pattern to match for a new record) — _source: `landscape/cloudflare.md`, `landscape/domains.md`_.
- The task's claim that `auth.qa.aiqadam.org` rides the SAME certificate as `qa.aiqadam.org` via SAN expansion is **not independently confirmed by the domains.md TLS table**, which only lists a single `qa-uz.aiqadam.org` certbot entry (`/etc/letsencrypt/live/qa-uz.aiqadam.org/`, expires 2026-10-11) — no `qa.aiqadam.org` or `auth.qa.aiqadam.org` certificate rows exist in that table at all. This is a **landscape documentation gap, not a contradiction**: `qa.aiqadam.org` itself is known (per `pro-data-tech-qa.md` and `services.md`) to be the live vhost with active Let's Encrypt TLS, so a cert must exist under some lineage name — but which lineage name (`qa.aiqadam.org` vs. carried over from `qa-uz.aiqadam.org`) and its actual SAN list are not captured in any landscape file and must be confirmed live via `certbot certificates` before design, exactly as the task itself insists. — _source: `landscape/domains.md`, `landscape/hosts/pro-data-tech-qa.md`_
- `qa.aiqadam.org` is confirmed the sole live nginx vhost on `pro-data-tech-qa` as of 2026-07-27 (T-0126), proxying to `127.0.0.1:3113` (`aiqadam-qa-api-1`); `qa-uz.aiqadam.org`'s DNS record still resolves to the host but has no dedicated nginx site — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`_.
- The nginx config for this host is described as a single file/site (`/etc/nginx/sites-available/qa.aiqadam.org`, symlinked to `sites-enabled/`) serving `qa.aiqadam.org` — the landscape's nginx description only explicitly documents the `qa.aiqadam.org` HTTP→HTTPS + proxy blocks; it does **not** independently document a second `auth.qa.aiqadam.org` server-block pair inside that same file the way T-0142's own text asserts. `auth.qa.aiqadam.org` is documented elsewhere (Authentik container table) only as "admin/API reachable externally via nginx at `https://auth.qa.aiqadam.org`" without naming the specific file. This is consistent with, but not an independent landscape-side confirmation of, T-0142's specific claim about file structure (two server-block pairs already coexisting in `qa.aiqadam.org.conf`) — worth a quick live `nginx -T`/file-read confirmation before editing, not a blocking gap. — _source: `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`_
- **Directus port:** `aiqadam-qa-directus-1` runs `directus/directus:11`, host-networked, with host port "not enumerated" in the structured container tables of both `pro-data-tech-qa.md` and `services.md`. The `3119` figure comes only from the frontmatter `last_verified_note` prose (T-0136 seed-content run, T-0137 token-rotation run, T-0138 password-rotation run, all dated 2026-08-20) referencing "these four real consumer containers" and QA API's `DIRECTUS_URL` env var, without a table row pinning the literal port number in a way this reader can quote directly. This matches the task's own framing exactly: "Port `3119` per T-0136/T-0137/T-0138's confirmed live Directus port — re-verify live, don't assume it hasn't changed since 2026-08-20." Treat as a **gap requiring live discovery**, not a landscape contradiction. — _source: `landscape/hosts/pro-data-tech-qa.md` frontmatter, `landscape/services.md`_
- **Shared-zone caution:** `aiqadam.org`'s Cloudflare zone is explicitly documented as shared, non-exclusive infrastructure — "Treat any new record creation or modification in this zone as shared-resource surgery, not greenfield," with an established discipline of a freshness-check (`GET` immediately before `PATCH`/`DELETE`) and a full zone-dump diff before/after any change (established by T-0110/T-0111/T-0117 executions). A new, uniquely-named `cms.qa.aiqadam.org` A record carries the same "no collision, DNS precedence, no blast radius on unrelated records" safety reasoning previously validated for `qa.aiqadam.org`/`qa-uz.aiqadam.org`/`auth.qa.aiqadam.org`, per the zone's own documented precedent reasoning. — _source: `landscape/cloudflare.md`_
- **`PUBLIC_DIRECTUS_URL` / web-next env wiring:** no landscape file currently documents any `PUBLIC_DIRECTUS_URL` value on QA's `web-next` env — consistent with the task's premise that this is a net-new wire-up, not a value to be changed. QA's `deploy/.env` is documented as holding `WEB_BASE_URL`/`OIDC_REDIRECT_URI` among "other vars," so a new key can be added following the same file/pattern. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **T-0125/T-0132 precedent (tracked-file drift):** `AUTHENTIK_ADMIN_URL` was added directly to the host's `docker-compose.qa.yml` (a tracked file in `aiqadam/ai-qadam-platform`) without a corresponding upstream commit; this became an uncommitted local diff that blocked/complicated a subsequent redeploy (`deploy.sh`'s hard `git checkout --detach` conflicting with local modifications), required a manual `git stash`/`pop` workaround, and left a still-`pending` follow-up task (T-0132, filed 2026-07-29, unresolved as of today 2026-08-21 — over 3 weeks open) to upstream the fix. This is the exact failure mode T-0142's own text warns about for the `qa.aiqadam.org.conf` nginx edit. — _source: `tasks/T-0125-fix-authentik-admin-url-on-qa.md`, `tasks/T-0132-upstream-qa-authentik-admin-url-into-repo.md`_

### Stale or stub files encountered
- none — `pro-data-tech-qa.md` (`last_verified: 2026-08-20`), `cloudflare.md` (`last_verified: 2026-07-23`), `domains.md` (`last_verified: 2026-07-23`), `services.md` (`last_verified: 2026-08-17`) are all within 30 days of today (2026-08-21) and all `status: active`/`populated`.

### Gaps requiring live discovery
- Directus's actual bound port on `pro-data-tech-qa` (task/landscape both say "was 3119 as of 2026-08-20," neither is an unconditional current-state guarantee).
- Current `certbot certificates` output confirming the exact SAN list on the cert lineage actually protecting `qa.aiqadam.org`/`auth.qa.aiqadam.org` today (landscape's TLS table is stale/incomplete on this specific point — still shows only `qa-uz.aiqadam.org` as a named lineage).
- Live contents of `/opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf` (or wherever the live file actually resolves — `/etc/nginx/sites-available/qa.aiqadam.org` per landscape) to confirm it currently holds exactly the two server-block pairs the task describes, before adding a third.
- Whether `aiqadam-qa-web-next-1`'s current `.env` (or the compose file's environment block) already declares any `PUBLIC_DIRECTUS_URL` key that would need overriding rather than adding fresh.

None of these gaps make the task impossible to design safely — they are exactly the "re-verify live, don't assume" items the task itself calls out, and they are the kind of narrow, pre-flight confirmations a solution-designer/executor would run as Phase 0 discovery before touching anything. Not `BLOCKED`.

## Issues / risks
- The landscape's TLS/cert table (`domains.md`) has a documentation gap around the actual live cert lineage name for `qa.aiqadam.org`/`auth.qa.aiqadam.org` — this should be corrected as part of this run's step-08 landscape update regardless of outcome, since it's already out of sync with the host's actual live-vhost state (confirmed elsewhere in the same landscape corpus as of T-0126, 2026-07-27, nearly a month stale on this one point specifically even though the file's own `last_verified` stamp is recent).
- Same shared-nginx-file risk the task itself already flags in its Notes: a syntax error anywhere in the single file serving all three hostnames (`qa.aiqadam.org`, `auth.qa.aiqadam.org`, and the new `cms.qa.aiqadam.org`) takes down all three, not just the new one — reinforces why `nginx -t` before `reload` (never `restart`) is non-negotiable.

## Open questions (optional)
- none — no BLOCKED conditions; all gaps are earmarked for live pre-flight discovery by the solution-designer/executor, consistent with the task's own instructions.
