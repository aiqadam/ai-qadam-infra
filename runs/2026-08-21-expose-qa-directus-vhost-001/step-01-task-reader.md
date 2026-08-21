---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-08-21T02:51:27Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - tasks/T-0142-expose-qa-directus-vhost.md
artifacts_changed: []
next_step_hint: landscape-reader should confirm the auth.qa.aiqadam.org SAN-cert precedent, the shared-zone caution in landscape/cloudflare.md, and re-verify Directus's live port (task text says 3119 as of 2026-08-20 but explicitly asks for re-verification, not assumption).
---

## Summary
Execute T-0142: give QA a real public Directus endpoint at `cms.qa.aiqadam.org` (DNS + nginx + TLS + `PUBLIC_DIRECTUS_URL` wiring), following the same pattern already used for `auth.qa.aiqadam.org`, explicitly without shortcutting by pointing QA at production.

## Details
### Why
`aiqadam/ai-qadam-platform` FR-CMS-008 (PR #274) added a real download link for governance documents on `qa.aiqadam.org/rules/<slug>`, pointing browsers directly at Directus's own `/assets/:id` endpoint. FR-CMS-009 (PR #276) made that browser-facing origin environment-configurable via `PUBLIC_DIRECTUS_URL` (default: the production host, `https://cms.aiqadam.org`). QA has no public Directus endpoint at all — Directus on QA (`aiqadam-qa-directus-1`) is only reachable at `127.0.0.1:3119`, with no nginx vhost, no DNS record, no TLS cert. Explicit user decision (2026-08-21): prepare QA properly with a real public Directus endpoint, not a shortcut pointing QA at production (production is not confirmed working yet, and coupling QA content to prod would be wrong regardless). This directly unblocks T-0141, which is `blocked` on exactly this gap.

Raw user request (verbatim, as given to this run): "Prepare QA [with a real Directus vhost]. Prod is not working yet [so don't shortcut by pointing QA at production]." This matches the task file's own framing exactly — no discrepancy between the user's raw ask and the task's recorded "Why."

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-qa.md`
  - `landscape/cloudflare.md`
  - `landscape/domains.md`
  - `landscape/services.md`
- **Constraints stated by user:**
  - Must be a real, independent QA Directus public endpoint — explicitly NOT a shortcut pointing QA's `PUBLIC_DIRECTUS_URL` at production's `cms.aiqadam.org`.
  - Production's `cms.aiqadam.org` currently 523s (origin unreachable) — this is known, separately deferred, and out of scope for this task; do not treat as a precondition and do not attempt to fix it here.
  - Follow the existing `auth.qa.aiqadam.org` precedent exactly (same DNS shape, same shared-cert-via-SAN approach, same tracked nginx file) rather than reinventing the pattern.
- **Information gaps for downstream steps:**
  - Directus's live port on `pro-data-tech-qa` — task text asserts `3119` as of 2026-08-20 (T-0136/T-0137/T-0138 era) but explicitly requires live re-verification before use, not assumption of no drift.
  - Whether `deploy/nginx/qa.aiqadam.org.conf` in the `aiqadam/ai-qadam-platform` repo checkout at `/opt/apps/aiqadam-qa/` is still at the same path/shape described in the task (two existing server-block pairs for `qa.aiqadam.org` and `auth.qa.aiqadam.org`) — needs live confirmation, not just trust in the task file's prior description.
  - Current `certbot certificates` state for the `qa.aiqadam.org` cert lineage (confirm still exactly the 2-SAN cert described, before expanding to 3).
  - Whether `aiqadam-qa-web-next-1`'s current `.env` already has any `PUBLIC_DIRECTUS_URL` value set (task assumes none functional yet, given no public endpoint exists).
  - Whether a companion PR against `aiqadam/ai-qadam-platform` for the tracked `deploy/nginx/qa.aiqadam.org.conf` file is being planned as an explicit phase of this run or deferred — flagged for step 03 (task-validator) given the T-0125/T-0132 precedent about host-local-only nginx/compose edits drifting from the tracked repo file.

## Issues / risks
- Task's own "Notes" section already classifies blast radius as `medium` (not `low`, unlike sibling task T-0141) specifically because this touches a shared production Cloudflare zone and a live nginx config file serving two already-working hostnames (`qa.aiqadam.org`, `auth.qa.aiqadam.org`) — a mistake in the shared nginx file could take down all three vhosts, not just fail to add the new one.
- Per `shared/approval-protocol.md`, DNS changes and nginx/firewall changes are unconditionally on the "always requires `NEEDS_APPROVAL`" list — this task cannot receive a solution-designer `PASS`/auto-approve verdict regardless of how narrow the actual diff looks.
- The task's own text flags the exact same drift failure mode previously seen with T-0125/T-0132 (a host-local edit to a tracked config file, never upstreamed, causing a landmine for the next deploy) and states the nginx change "must land as a PR against `aiqadam/ai-qadam-platform` ... not just edited live on the host and left undocumented." This is a structural point for step 03 to validate explicitly: is a companion app-repo PR being treated as a hard, in-scope requirement of this run, or an optional follow-up (as T-0132 currently is, still unresolved 3+ weeks after T-0125 closed)?

## Open questions (optional)
- none — task is well-formed and unambiguous; no BLOCKED conditions apply at this step. Open items above are appropriately deferred to landscape-reader (gaps needing live discovery) and task-validator (the companion-PR structural question).
