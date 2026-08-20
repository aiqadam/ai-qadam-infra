---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-08-20T14:05:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/step-01-task-reader.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-02-landscape-reader.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-03-task-validator.md
  - .claude/agents/solution-designer.md
  - workflows/deploy-app.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - tasks/T-0136-seed-content-documents-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/app-registry.md
  - runs/2026-07-24-fix-authentik-admin-url-001/step-04-solution-designer.md
artifacts_changed: []
next_step_hint: verdict PASS — orchestrator skips step 05 and advances directly to executor-cicd (step 06). Executor must run Phase 1 (discovery) first and use its live output (port, token file path/var name) to construct Phase 2's DIRECTUS_URL/DIRECTUS_TOKEN — do not reuse any port/value from this plan's own prose, since none is asserted here. If Phase 1 discovery fails to resolve either fact cleanly, executor must stop and emit BLOCKED rather than guess.
retry_of: null
---

## Summary

Two-phase plan on `pro-data-tech-qa`: Phase 1 is a read-only SSH discovery sub-step that resolves Directus's host port (via `docker port`/`docker inspect` on `aiqadam-qa-directus-1`) and confirms the admin-token's variable name and file location (via a presence-only grep of `/opt/apps/aiqadam-qa/deploy/.env`, never printing the value); Phase 2 uses those two facts to bring the on-host checkout up to date if needed and run `infrastructure/directus/seed-content-documents.sh` against QA's Directus, ending with 5 idempotent-upserted rows in `content_documents` and no other host state changed.

## Details

### Plan

**Phase 1 — Discovery (read-only, no host state change)**

1. **Resolve Directus's host port mapping** — command: `ssh pro-data-tech-qa "docker port aiqadam-qa-directus-1"` — verification: non-empty output. Since the container runs `network_mode: host` (confirmed in `landscape/hosts/pro-data-tech-qa.md`), `docker port` may return nothing (host-mode containers often report no port mapping via this command because there is no NAT to report). If empty, fall back to: `ssh pro-data-tech-qa "docker inspect aiqadam-qa-directus-1 --format '{{json .Config.Env}}' | tr ',' '\n' | grep -i PORT"` (Directus's own `PORT` env var, which is what it actually binds to under host networking) combined with `ssh pro-data-tech-qa "docker exec aiqadam-qa-directus-1 printenv PORT"` as the authoritative source (Directus defaults to `8055` if unset — confirm rather than assume). Executor records the resolved port explicitly in its step-06 handoff.

2. **Confirm the resolved port is actually listening on loopback** — command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<resolved-port>/server/ping"` — verification: Directus's `/server/ping` endpoint returns `pong` with HTTP 200 (public, unauthenticated endpoint — safe to call without a token, confirms the port guess is correct before proceeding). If this fails, executor must not proceed to Phase 2 on a guessed port; try the next candidate from step 1's inspection or stop and emit `BLOCKED`.

3. **Confirm the admin token's variable name and file presence — value never printed** — command: `ssh pro-data-tech-qa "grep -oE '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN|ADMIN_TOKEN)=' /opt/apps/aiqadam-qa/deploy/.env"` — verification: exactly one match, giving the variable name (e.g. `DIRECTUS_TOKEN=`). This command by construction cannot leak the value (only the `-o` matched key= prefix is printed, not the rest of the line — confirm the executor uses `-oE` with a pattern that stops at `=`, exactly as written, not a bare `grep VARNAME` which would print the whole line including the secret). If none of the three candidate names match, fall back to: `ssh pro-data-tech-qa "grep -oE '^[A-Z_]*DIRECTUS[A-Z_]*=' /opt/apps/aiqadam-qa/deploy/.env"` to discover the actual name generically, still without printing values. `tvolodi` is the owning user of this file (mode 640, owner `tvolodi:aiqadam-qa-secrets` per `landscape/hosts/pro-data-tech-qa.md`), so no sudo is required.

4. **Fetch the token value into the executor's live SSH session only (never into any file in this repo or any handoff)** — command: `ssh pro-data-tech-qa "grep '^<VARNAME>=' /opt/apps/aiqadam-qa/deploy/.env"` run interactively by the executor to obtain the value for immediate in-memory use in Phase 2's command invocation — verification: a value is present (non-empty after the `=`). The executor must not echo this value into its own step-06 handoff, into any `runs/` file, or into shell history that gets logged; treat it exactly as an SSH-session-scoped environment variable for the seed script's invocation (see step 7).

5. **Confirm on-host checkout state and target commit** — command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git fetch origin && git log --oneline -1 && git merge-base --is-ancestor 627cd91 HEAD && echo AT_OR_PAST_TARGET || echo BEHIND_TARGET"` — verification: either `AT_OR_PAST_TARGET` (skip step 6) or `BEHIND_TARGET` (proceed to step 6). This directly resolves the open question step 01/02 flagged (whether the checkout already contains `infrastructure/directus/seed-content-documents.sh` from PR #272 / commit `627cd91`).

6. **If behind, update the checkout to the target commit (only if step 5 reported `BEHIND_TARGET`)** — command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git checkout main && git pull origin main"` — verification: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git merge-base --is-ancestor 627cd91 HEAD && echo AT_OR_PAST_TARGET"` now prints `AT_OR_PAST_TARGET`, and `ssh pro-data-tech-qa "test -f /opt/apps/aiqadam-qa/infrastructure/directus/seed-content-documents.sh && echo SCRIPT_PRESENT"` prints `SCRIPT_PRESENT`. This is a working-tree update only — it does **not** trigger `docker compose up`/`--force-recreate`/image rebuild; the running containers (including `aiqadam-qa-api-1`, `aiqadam-qa-web-next-1`) are deliberately left untouched, since the task is explicit that no new app version needs to be deployed. This step only moves the git ref that the `deploy/` scripts and `infrastructure/` scripts are read from; `deploy/.env` and `deploy/docker-compose.qa.yml` are untracked by git per this host's established convention (confirmed in `landscape/hosts/pro-data-tech-qa.md`'s deploy.sh notes — "Never runs `git clean`... the `deploy/` directory... is untracked by git") and are therefore unaffected by this pull.

**Phase 2 — Seed operation (the only state-changing step; writes 5 Directus rows via REST API)**

7. **Run the seed script** — command (single SSH session, token never leaves that session or touches disk in this repo): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && DIRECTUS_URL=http://127.0.0.1:<resolved-port-from-step-2> DIRECTUS_TOKEN=$(grep '^<VARNAME>=' deploy/.env | cut -d= -f2-) bash infrastructure/directus/seed-content-documents.sh"` — verification: script exits 0 and its own stdout reports 5 rows created/updated (upsert-by-slug messages for `manifesto`, `charter-v0-1`, `kazakhstan-mou`, `global-board-polozhenie-v1`, `soglashenie-v1`, per the task's "What done looks like" list). Executor captures the script's stdout in its step-06 handoff but must redact/omit the `DIRECTUS_TOKEN=...` portion of the command line itself if the handoff records the literal invocation (record it as `DIRECTUS_TOKEN=<redacted>` in the handoff, never the resolved value).

8. **On-host confirmation via REST API** — command: `ssh pro-data-tech-qa "curl -s http://127.0.0.1:<resolved-port>/items/content_documents?fields=slug | grep -c slug"` — verification: reports 5 (or more, if pre-existing unrelated rows exist — executor should sanity-check the actual slugs match the 5 expected via `curl -s http://127.0.0.1:<resolved-port>/items/content_documents?fields=slug`, not just a count).

9. **External verification — public page** — command: `curl -s https://qa.aiqadam.org/rules` (no SSH needed, runs from the management workstation) — verification: response body no longer contains "Пока нет опубликованных документов." and instead contains all 5 document titles/slugs.

10. **External verification — individual document page** — command: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/rules/charter-v0-1` — verification: `200`.

11. **Superseded-label spot check** — command: `curl -s https://qa.aiqadam.org/rules/global-board-polozhenie-v1` and `curl -s https://qa.aiqadam.org/rules/soglashenie-v1` — verification: both response bodies contain a "Superseded by Charter v0.1" label (or the app's exact rendered string for it); `curl -s https://qa.aiqadam.org/rules/manifesto` (or another of the other 3 slugs) must NOT contain that label.

### Rollback

The seed script's own upsert-by-slug logic makes re-running it after any partial failure the correct recovery action (idempotent), not a rollback in the traditional sense. There is no destructive step in this plan (no file overwritten without backup, no container recreated, no schema touched) to roll back:

1. If Phase 1's `git pull` (step 6) was performed and any downstream problem is later attributed to the checkout update itself (not to the seed data): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git checkout <pre-pull-SHA-recorded-in-step-5's-output>"` — reverts only the working tree ref; no containers were recreated by this plan, so no running service is affected either way.
2. If the 5 seeded rows themselves need to be removed (only if the user explicitly decides the seed was a mistake — not part of this task's normal completion path): delete via Directus REST API, `DELETE /items/content_documents/<id>` for each of the 5 slugs' ids (ids obtained from step 8's listing). This is a data-deletion action and is **not** pre-authorized by this plan's `PASS` verdict — if it is ever needed, it requires its own task/plan with `NEEDS_APPROVAL` framing, since it is deleting data rather than adding it. Noting this asymmetry explicitly: adding the 5 rows is low-risk/fully-reversible-by-construction (upsert-idempotent, re-running is always safe), but removing them afterward is a distinct, separately-scoped operation this plan does not pre-approve.

### Verification (for step 07)

- **On-host:**
  - Phase 1 step 2's `curl .../server/ping` → `pong`, HTTP 200 (confirms port resolution correct, captured before Phase 2 ran)
  - Phase 1 step 5/6's `git merge-base --is-ancestor 627cd91 HEAD` → `AT_OR_PAST_TARGET`, and `test -f infrastructure/directus/seed-content-documents.sh` → `SCRIPT_PRESENT`
  - Phase 2 step 7's seed script exit code `0` and stdout showing 5 upserts
  - Phase 2 step 8's on-host REST listing → exactly the 5 expected slugs present
- **External:**
  - `GET https://qa.aiqadam.org/rules` → 200, body contains all 5 document titles, no longer the empty-state string
  - `GET https://qa.aiqadam.org/rules/charter-v0-1` → 200, full content rendered
  - `GET https://qa.aiqadam.org/rules/global-board-polozhenie-v1` and `.../soglashenie-v1` → both show "Superseded by Charter v0.1"; the other 3 slugs do not show that label

### Resources used

- **Secrets (by name):** QA Directus admin token — name to be confirmed live in Phase 1 step 3 (candidate: `DIRECTUS_TOKEN`, per the `.env`'s established naming convention for this host's other secrets like `aiqadam-qa-jwt-signing-secret`). Not present in `landscape/secrets-inventory.md` today (confirmed absent by step 02) — landscape-updater (step 08) should add an entry recording the variable name and file location (never the value), closing the gap step 02 flagged.
- **Files modified on host:** none, if Phase 1 step 5 reports `AT_OR_PAST_TARGET` (no-op case). If `BEHIND_TARGET`: the `/opt/apps/aiqadam-qa/` git working tree is fast-forwarded (tracked files only; `deploy/.env` and `deploy/docker-compose.qa.yml` are untracked and unaffected). No files are edited in place — this is a `git pull`, not a manual edit.
- **Files modified in this repo (landscape/), to be applied at step 08:**
  - `landscape/hosts/pro-data-tech-qa.md` — record Directus's resolved host port (closing the "not enumerated" gap from T-0126) and, if the checkout was pulled, the new git HEAD SHA (superseding the stale `dfd2a7c`/`b5250071` references).
  - `landscape/services.md` — same port fact, mirrored into the canonical per-host container table.
  - `landscape/secrets-inventory.md` — add an entry for the QA Directus admin token (name + file location only).
  - `shared/app-registry.md` — flagged separately by step 02 as independently stale (documents only 2 of 7 containers); step 08 should consider a corrective note, but a full resync is out of scope for this task per step 03's finding.
- **External APIs called:** QA Directus REST API (`http://127.0.0.1:<port>/items/content_documents`, called from within the SSH session, i.e. host-local, not public) — the only externally-reachable check is the public `qa.aiqadam.org/rules` page (read-only GET), plus the seed script's own writes which happen host-local against Directus's loopback-bound port.

### Estimated impact

- **Downtime:** none. No container is restarted or recreated in the primary path (Phase 1 step 5 reporting `AT_OR_PAST_TARGET`). Even in the `BEHIND_TARGET` branch, `git pull` alone does not restart any running container — Docker Compose is never invoked with `up`/`--force-recreate` anywhere in this plan.
- **Affected services:** `aiqadam-qa-directus-1`'s data only (5 new/updated rows in its `content_documents` collection). No other container, and no container process itself, is touched.
- **Reversibility:** fully reversible. The seed script is idempotent-by-design (upsert on slug, safe to re-run); the git pull (if it occurs) is a fast-forward with the pre-pull SHA recorded for revert; no destructive action occurs anywhere in this plan.

## Issues / risks

- **Port resolution has two plausible outcomes and the plan does not assume either.** `docker port` frequently returns nothing for `network_mode: host` containers; the fallback (inspecting Directus's own `PORT` env var, then confirming via `/server/ping`) is included specifically so the executor never has to guess a port. This is the single largest source of uncertainty in the plan, but it is fully bounded by a live, verifiable check (step 2) before any write action is attempted — not a doubt about safety, just an acknowledged unknown resolved by discovery rather than assumption, consistent with my role's instruction to design a discovery sub-step rather than fill this gap with an assumption.
- **Token retrieval command must be copied exactly.** Step 3's `grep -oE '...='` pattern is deliberately constructed to make it structurally impossible to leak the secret value into any log/handoff; step 4's interactive fetch and step 7's inline `$(...)` substitution keep the value inside a single SSH session's process environment only. Executor must not deviate to a simpler-looking `cat .env` or `grep VARNAME .env` (without `-o`), which would print the value into terminal output that could be captured in a transcript.
- **Data-deletion rollback (item 2 under Rollback) is explicitly NOT pre-authorized by this PASS verdict** — flagging this asymmetry so no future agent mistakes the presence of a rollback section as blanket permission to delete the seeded rows without a fresh approval pass.
- **`shared/app-registry.md` staleness** (flagged by step 02, reaffirmed by step 03 as non-blocking for this task) is carried forward unchanged to step 08 as a hygiene item — not acted on by this plan.
- No item above is high-severity: none touches DNS, firewall, OS packages, secrets rotation (only secret *read*, not rotation), or prod. All match this task's declared `estimated_blast_radius: low` / `estimated_reversibility: full`.

## Open questions (optional)

None — verdict is `PASS`, not `BLOCKED`. Per `.claude/agents/solution-designer.md`'s explicit guidance for this exact situation ("Make assumptions to fill gaps that step 02 flagged for live discovery — instead, design a discovery sub-step or mark the design BLOCKED"), both of step 02's open gaps (Directus port, admin-token location) are resolved by Phase 1's discovery sub-steps rather than assumed, and the sole state-changing action (Phase 2) is a REST-API-only content write using the source PR's own already-idempotent, already-tested script. All five `PASS` conditions from `shared/approval-protocol.md` / my own agent definition are met: (1) task's `estimated_blast_radius: low`, (2) task's `estimated_reversibility: full`, (3) no irreversible steps in the plan (data deletion is explicitly excluded from this plan's scope, not merely deferred), (4) no designer doubts remain after Phase 1's discovery design, (5) no Issues/risks item above is high-severity. Precedent: `runs/2026-07-24-fix-authentik-admin-url-001/step-04-solution-designer.md` designed an analogous discovery-then-act plan against this same host and was correctly auto-approved as `PASS`.
