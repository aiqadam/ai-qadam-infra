---
id: T-0142-expose-qa-directus-vhost
title: Expose QA Directus publicly at cms.qa.aiqadam.org and wire PUBLIC_DIRECTUS_URL
kind: task
status: done
priority: P2
created: 2026-08-21
updated: 2026-08-21
closed: 2026-08-21
outcome: success
created_by: manual
source_runs: []
executed_by_runs: [2026-08-21-expose-qa-directus-vhost-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/services.md
workflow: infrastructure
blocks: [T-0141-provision-rules-source-file-downloads-qa]
blocked_by: []
related: [T-0141-provision-rules-source-file-downloads-qa]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Expose QA Directus publicly at cms.qa.aiqadam.org and wire PUBLIC_DIRECTUS_URL

## Why

`aiqadam/ai-qadam-platform` FR-CMS-008 (PR #274) added a real download
link for governance documents on `qa.aiqadam.org/rules/<slug>`, pointing
browsers directly at Directus's own `/assets/:id` endpoint. FR-CMS-009
(PR #276) made that browser-facing origin environment-configurable via
`PUBLIC_DIRECTUS_URL` (default: the production host,
`https://cms.aiqadam.org`).

**QA has no public Directus endpoint at all.** Directus on QA
(`aiqadam-qa-directus-1`) is only reachable at `127.0.0.1:3119` — no
nginx vhost, no DNS record, no TLS cert. So even with FR-CMS-009 merged,
QA's download links have nowhere correct to point until this is fixed.

**Explicit user decision (2026-08-21): prepare QA properly** — a real
public Directus endpoint, not a shortcut pointing QA at production
(production is not confirmed working yet, and coupling QA content to
prod would be wrong regardless).

This directly unblocks infra task
[T-0141](T-0141-provision-rules-source-file-downloads-qa.md), which is
`blocked` on exactly this gap.

## Precedent (follow this exactly, don't reinvent)

This host already exposes a second internal-only service
(`auth.qa.aiqadam.org` → Authentik on `127.0.0.1:3117`) via the identical
pattern needed here, tracked in the SAME nginx config file as the main
vhost:

- **DNS:** `qa.aiqadam.org` and `auth.qa.aiqadam.org` are both plain `A`
  records → `95.46.211.230`, `proxied: false` (Cloudflare orange-cloud
  OFF — required for certbot HTTP-01 challenge and because these are
  operator/QA-only surfaces, not public marketing traffic).
- **TLS:** `auth.qa.aiqadam.org` does **NOT** have its own certificate —
  it rides on the SAME cert as `qa.aiqadam.org` via SAN
  (`certbot certificates` confirms `Domains: qa.aiqadam.org
  auth.qa.aiqadam.org` on one cert, `Certificate Name: qa.aiqadam.org`).
  Use `certbot --expand` to add `cms.qa.aiqadam.org` to that SAME
  certificate — do not provision a separate cert.
- **nginx:** the tracked config file is
  `deploy/nginx/qa.aiqadam.org.conf` in the `aiqadam` app repo checkout
  at `/opt/apps/aiqadam-qa/`, symlinked/copied into
  `/etc/nginx/sites-available/qa.aiqadam.org` on the host. It already
  contains TWO `server{}` pairs (port 80 redirect + port 443 TLS) for
  `qa.aiqadam.org` and a second pair for `auth.qa.aiqadam.org`. Add a
  THIRD pair for `cms.qa.aiqadam.org`, same file, same structure:
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
          proxy_pass http://127.0.0.1:3119;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }
  }
  ```
  (Port `3119` per T-0136/T-0137/T-0138's confirmed live Directus port —
  re-verify live, don't assume it hasn't changed since 2026-08-20.)
  No WebSocket upgrade headers needed (unlike `auth.qa`'s Authentik
  flow-UI requirement) — Directus's admin UI/API doesn't need it for
  the read-only public asset/API surface this is exposing.

## What done looks like

- [ ] Cloudflare DNS: new `A` record `cms.qa.aiqadam.org` →
      `95.46.211.230`, `proxied: false` — same shape as the existing
      `qa.aiqadam.org` / `auth.qa.aiqadam.org` records. Confirm via full
      zone dump before/after per this repo's "shared-resource surgery"
      convention (`landscape/cloudflare.md` — this zone is shared,
      not exclusive to this project).
- [ ] nginx: `deploy/nginx/qa.aiqadam.org.conf` (in the `aiqadam` app
      repo, tracked file) updated with the new `cms.qa.aiqadam.org`
      server blocks per the precedent above. Applied to the live host
      config, `nginx -t` passes, `systemctl reload nginx` (not
      `restart` — avoid dropping active connections to the other two
      vhosts sharing this file).
      **This is a tracked file in a different repo** — the change must
      land as a PR against `aiqadam/ai-qadam-platform` (same as how
      `qa.aiqadam.org.conf`'s own header comments describe deploying
      it), not just edited live on the host and left undocumented,
      or it will drift on the next deploy exactly the way T-0132/T-0133
      already documented happening once before for a different config
      line.
- [ ] TLS: `certbot --expand` (or equivalent) adds `cms.qa.aiqadam.org`
      to the existing `qa.aiqadam.org` certificate. `certbot
      certificates` afterward shows `Domains: qa.aiqadam.org
      auth.qa.aiqadam.org cms.qa.aiqadam.org` on the ONE certificate —
      confirm no second certificate was accidentally created.
- [ ] `certbot.timer`'s existing auto-renewal continues to cover the
      expanded cert with no separate renewal job needed (confirm, don't
      assume — a 3-SAN cert renews as one unit, but verify the
      `--expand` flow didn't fork a second lineage).
- [ ] External verification: `https://cms.qa.aiqadam.org/server/ping` →
      `200`, body `pong`, valid TLS chain (no self-signed/expired
      warning). This is the actual acceptance signal — a passing nginx
      config test is necessary but not sufficient.
- [ ] `PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org` set in QA's
      `/opt/apps/aiqadam-qa/deploy/.env`, and `aiqadam-qa-web-next-1`
      recreated to pick it up (env vars are not hot-reloaded — same
      rule as every prior QA rotation this week).
- [ ] Confirm `qa.aiqadam.org` and `auth.qa.aiqadam.org` are unaffected
      — both still return correct responses after the nginx reload
      (this file serves all three hostnames; a syntax slip anywhere in
      it takes down all three, not just the new one).
- [ ] Handoff to T-0141: once this task is done, T-0141 should be
      un-blocked (status → `pending` or resumed directly) and can
      proceed with its own scope (copy the 5 source files, run
      `bootstrap.sh` + `seed-content-documents.sh`, verify the download
      link end-to-end using the now-real `cms.qa.aiqadam.org` origin).

## Result

**DONE.** Executed across two phases and two `aiqadam/ai-qadam-platform`
PRs, both merged, plus one infra run
(`2026-08-21-expose-qa-directus-vhost-001`, steps 00-08 all PASS except
step-06/executor-infra which correctly stopped at Step 10 pending a
follow-up PR — see below):

- **Cloudflare DNS:** `cms.qa.aiqadam.org` A record → `95.46.211.230`,
  proxied:false, record ID `0b4ddd97899b5b7cd6d756a03c25e7ae`. Zone
  confirmed 47→48 records, exactly one added.
- **nginx:** PR #278 added a third server-block pair to
  `deploy/nginx/qa.aiqadam.org.conf`, merged, applied to the live host
  file, `nginx -t` passed, reloaded (not restarted).
- **TLS:** `certbot --expand` added `cms.qa.aiqadam.org` as a third SAN
  on the existing `qa.aiqadam.org` cert lineage — one lineage
  confirmed, not two; new serial, expiry 2026-11-19.
- **External verification:** `https://cms.qa.aiqadam.org/server/ping` →
  200/`pong`, valid TLS chain. `qa.aiqadam.org`/`auth.qa.aiqadam.org`
  confirmed unaffected before/after.
- **`PUBLIC_DIRECTUS_URL`:** the first executor pass found appending it
  to `deploy/.env` had no effect — `web-next`'s compose service uses
  inline hardcoded env literals, not `env_file:` (unlike `api`/
  `directus`). Correctly stopped rather than improvising a live edit to
  a tracked file. **Follow-up PR #279** uncommented the line in
  `docker-compose.qa.yml` itself; merged, pulled onto the host (stash/
  pop preserved the pre-existing `AUTHENTIK_ADMIN_URL` host-local
  override, clean auto-merge), `web-next` recreated,
  `PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org` confirmed live via
  `docker inspect`.
- **Handoff to T-0141:** structurally unblocked. Live verification
  2026-08-21 found `/rules/manifesto` still 404s — `web-next` logs show
  `HTTP 403` on `content_documents.source_file`, confirming QA's
  Directus schema doesn't have FR-CMS-008's field/allowlist addition
  yet (`bootstrap.sh` not re-run against QA since). This is squarely
  T-0141's own remaining scope, not a T-0142 regression — documented in
  T-0141's history.

Full detail: [step-06 executor-infra](../runs/2026-08-21-expose-qa-directus-vhost-001/step-06-executor-infra.md),
[step-07 execution-validator](../runs/2026-08-21-expose-qa-directus-vhost-001/step-07-execution-validator.md),
[step-08 landscape-updater](../runs/2026-08-21-expose-qa-directus-vhost-001/step-08-landscape-updater.md).

## Notes

- **Blast radius is `medium`, not `low`**, unlike T-0141 — this touches
  a shared production Cloudflare zone (DNS) and a live nginx config file
  serving two already-working hostnames (a mistake here could take down
  `qa.aiqadam.org` itself, not just fail to add the new one). Per
  `workflows/infrastructure.md` / `shared/approval-protocol.md`, DNS and
  nginx changes are on the "always requires `NEEDS_APPROVAL`" list —
  expect this regardless of how narrow the actual diff looks.
- **Prod's `cms.aiqadam.org` currently returns 523** (Cloudflare: origin
  unreachable) — confirmed 2026-08-21, unrelated to and not fixed by
  this task. User has explicitly deferred investigating this; do not
  treat it as a precondition or attempt to fix it as part of T-0142.
  Noting only so a future session doesn't conflate the two.
- **Do not point QA at the production CMS host as a shortcut** — this
  was raised and explicitly declined by the user in favor of a real QA
  endpoint, given prod isn't confirmed healthy and coupling environments
  would be the wrong direction long-term regardless.
- Reference precedent for the DNS-record shape: `landscape/cloudflare.md`
  rows for `qa.aiqadam.org` / `auth.qa.aiqadam.org` (both discovered as
  already-created 2026-07-18, but the shape — plain A, unproxied — is
  exactly what a newly-created record here should match).
- Reference precedent for the nginx/TLS shape:
  `landscape/hosts/pro-data-tech-qa.md`'s "AiQadam application stack"
  section, and T-0110's original run
  (`runs/2026-07-13-setup-aiqadam-qa-infra-001/`) for the first-ever
  version of this exact procedure (nginx vhost + certbot + Cloudflare
  A record) on this same host.
- Source context: `aiqadam/ai-qadam-platform` FR-CMS-008 (PR #274),
  FR-CMS-009 (PR #276). Full workflow artifacts in that repo:
  `.copilot/tasks/completed/wf-20260821-feat-213/` and
  `.copilot/tasks/completed/wf-20260821-feat-214/`.

## History
- 2026-08-21: created (manual, to unblock T-0141 — user explicitly chose
  a real QA Directus vhost over pointing QA at production, and confirmed
  prod's 523 is a known, separate, deliberately-deferred issue)
- 2026-08-21: status → `in-progress`, Phase 1 (nginx conf PR #278)
  merged, Phase 2 run `2026-08-21-expose-qa-directus-vhost-001` executed
  Steps 0-9 successfully (DNS, nginx, TLS, external verification) but
  stopped at Step 10 (`PUBLIC_DIRECTUS_URL` wiring) — `web-next`'s
  compose service doesn't read `.env` at all, unlike the plan's assumed
  precedent. Follow-up PR #279 filed and merged to fix the tracked
  compose file directly.
- 2026-08-21: status → `done`. PR #279 pulled onto the QA host,
  `web-next` recreated, `PUBLIC_DIRECTUS_URL` confirmed live via
  `docker inspect`. execution-validator (step-07) and landscape-updater
  (step-08) both PASS. `landscape/cloudflare.md` and
  `landscape/hosts/pro-data-tech-qa.md` updated. T-0141 unblocked
  (`blocked_by` now resolved) — its own remaining scope (re-run
  `bootstrap.sh`/`seed-content-documents.sh` against QA) is unaffected
  and still pending.
