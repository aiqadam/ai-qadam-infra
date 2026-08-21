---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-08-21T09:00:00Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-06-executor-infra.md
  - tasks/T-0142-expose-qa-directus-vhost.md
artifacts_changed: []
---

## Summary
Independently re-verified every "What done looks like" item on
T-0142. All items now PASS, across two executor sessions: Phase 2
proper (step-06, this run, Steps 0-9) plus a follow-up PR (#279,
outside this run's own handoff but within this task's scope) that
closed the one gap step-06 stopped on.

## Details

### Checklist re-verification (live, 2026-08-21)

1. **Cloudflare DNS `cms.qa.aiqadam.org` → 95.46.211.230, proxied:false**
   — re-queried via Cloudflare API: record `0b4ddd97899b5b7cd6d756a03c25e7ae`
   present, matches. PASS.
2. **nginx vhost tracked-file PR merged, applied, reload not restart**
   — PR #278 confirmed `MERGED` (merge commit `05529a2880b56514db53c5561b41dce3be234cff`).
   `diff /etc/nginx/sites-available/qa.aiqadam.org
   /opt/apps/aiqadam-qa/deploy/nginx/qa.aiqadam.org.conf` → no output
   (live file matches tracked file exactly). `systemctl status nginx`
   → `active (running)`, no restart in journal since the reload. PASS.
3. **TLS: certbot --expand, one lineage, 3 SANs** — `sudo certbot
   certificates` re-run: `Certificate Name: qa.aiqadam.org`, `Domains:
   qa.aiqadam.org auth.qa.aiqadam.org cms.qa.aiqadam.org`, exactly 2
   lineages total on the host (this one + the separate, untouched
   `qa-uz.aiqadam.org`) — matches step-06's Step 0.3 baseline count.
   No second lineage created. PASS.
4. **certbot.timer covers the expanded cert** — `systemctl status
   certbot.timer` → `active (waiting)`, next trigger scheduled; no
   per-domain renewal jobs exist on this host (confirmed only one
   timer unit), so the 3-SAN cert renews as one unit by construction.
   PASS.
5. **External verification** — `curl -sS -o /dev/null -w '%{http_code}'
   https://cms.qa.aiqadam.org/server/ping` → `200`; body `pong`; TLS
   chain verified without `-k` (no warnings). PASS.
6. **`PUBLIC_DIRECTUS_URL` set and live in `web-next`** — this is the
   item step-06 stopped on (verdict: FAIL, blocked on the tracked
   `docker-compose.qa.yml` shipping the line commented out). Resolved
   by a follow-up PR **outside step-06's own execution but within
   this task's scope**: PR #279 (`aiqadam/ai-qadam-platform`)
   uncommented `PUBLIC_DIRECTUS_URL: "https://cms.qa.aiqadam.org"` in
   `deploy/docker-compose.qa.yml`'s `web-next` service — confirmed
   `MERGED` (merge commit `0cef09eccd835ff883c023dfa4633950e53861a4`).
   Pulled onto the QA host (stash/pop preserved the pre-existing
   `AUTHENTIK_ADMIN_URL` host-local override on the `api` service,
   clean auto-merge, no conflicts). `grep -n
   'PUBLIC_DIRECTUS_URL\|AUTHENTIK_ADMIN_URL' deploy/docker-compose.qa.yml`
   confirms both present. `web-next` recreated
   (`docker compose -p aiqadam-qa ... up -d --no-deps web-next`);
   `docker inspect aiqadam-qa-web-next-1 --format
   '{{json .Config.Env}}'` now shows
   `PUBLIC_DIRECTUS_URL=https://cms.qa.aiqadam.org` live in the running
   container (previously absent per step-06's Step 10 finding). PASS
   — the gap step-06 identified is now closed by PR #279, not by any
   further edit to step-06's own artifacts.
7. **qa.aiqadam.org / auth.qa.aiqadam.org unaffected** — `https://
   qa.aiqadam.org/health` → `200`; `https://qa.aiqadam.org/rules` →
   `200`; `auth.qa.aiqadam.org` unchanged (no further action taken
   against it since step-06's own Step 9 check, which already passed).
   PASS.
8. **Handoff to T-0141** — `blocked_by` structurally clear now that
   this task's own checklist is complete. T-0141's own remaining scope
   (copy files, run `bootstrap.sh` + `seed-content-documents.sh`) is
   unaffected by and not part of this task — confirmed live 2026-08-21
   that `/rules/manifesto` currently 404s with `web-next` logging
   `HTTP 403` on `content_documents.source_file`, which is exactly
   T-0141's own not-yet-executed scope (QA's Directus schema doesn't
   have that field in the public-read allowlist yet) — **not** a
   regression from this task. Documented in T-0141's own history; not
   a T-0142 checklist item and not blocking T-0142's closure.

### Scope note
This task's "Result" (step-06) recorded a FAIL verdict for the run
because the run itself stopped short of Step 11 pending a follow-up PR
outside its authorized edit scope (correct behavior — a tracked-file
edit belongs in a PR, not a live host edit). That follow-up PR (#279)
has since merged and been independently verified above. The task-level
outcome is DONE; the run-level artifact correctly stayed FAIL to
reflect that the run itself didn't complete Step 11 unassisted.

## Issues / risks
Carried forward from step-06, not resolved by this validation pass
(neither in this task's scope nor blocking):
- `pro-data-tech-qa` SSH-config alias uses `User root`; landscape doc
  says `User tvolodi`. Cosmetic/process drift, not investigated
  further here — flagged again for whoever next touches
  `landscape/hosts/pro-data-tech-qa.md`.
- Secret values transiently appeared in step-06's own terminal output
  (Directus container's full env dump) — already flagged there, no
  further action; not reproduced in this file.

## Open questions (optional)
None — both open questions from step-06 are now resolved: the
follow-up PR was filed as part of this same task (not a new task,
matching step-06's own recommendation), and the SSH alias question is
left for the user per step-06's original recommendation.
