---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-20T22:10:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-04-solution-designer-attempt-5.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-infra-attempt-3.md
  - tasks/T-0136-seed-content-documents-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-06-executor-cicd.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-cicd-attempt-1.md
  - .claude/agents/solution-designer.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - workflows/deploy-app.md
retry_of: step-04
next_step_hint: >-
  Verdict NEEDS_APPROVAL — the root cause is now genuinely resolved (missing
  collections, not RBAC), but this plan's Phase 1 runs bootstrap.sh, a
  schema-defining script that touches the FULL ~79-collection surface, not
  just the 2 missing collections T-0136 scoped. That is new blast radius
  relative to every prior attempt today (all of which were read-only or a
  narrowly-scoped REST write), so per solution-designer's own PASS
  conditions ("no doubts about safety," "no high-severity Issues/risks
  item") this must halt for explicit user sign-off before executing,
  even though the *expected* delta is exactly the 2 collections T-0136
  already scoped. If approved, orchestrator writes step-05-user-approval.md
  with verdict APPROVED, then executor-infra proceeds through Phase 1
  (bootstrap.sh), Phase 2 (schema verification), Phase 3 (seed script,
  reusing the exact working invocation pattern from
  step-06-executor-cicd-attempt-1.md: DIRECTUS_URL=http://127.0.0.1:3119
  DIRECTUS_TOKEN=<value of deploy/.env's DIRECTUS_ADMIN_TOKEN key,
  substituted inline via command substitution, never echoed or logged>),
  and Phase 4 (full verification: 5 rows, /rules listing, superseded
  labels, /about /history /partners 200). All facts needed to execute are
  now resolved from live evidence — no further discovery sub-steps
  required. This should be the last solution-designer attempt on this run.
---

## Summary

Run `infrastructure/directus/bootstrap.sh` (idempotent by design) against QA Directus to create the missing `content_pages`/`content_documents` collections — the confirmed actual root cause of every 403 seen today, not an RBAC gap — then run `infrastructure/directus/seed-content-documents.sh` to populate the 5 governance-document rows, and verify end-to-end via REST, `/rules`, and the three FR-CMS-007 static pages. `NEEDS_APPROVAL` because bootstrap.sh's blast radius (full ~79-collection schema surface) exceeds every previously-approved action on this run, even though its expected effective delta is exactly the 2 collections T-0136 already scoped.

## Details

### Root cause recap (not re-derived — given as confirmed input to this step)

`directus_collections` has zero rows for `content_documents`; `\dt` against the `directus` database (Directus's real backend, per `docker-compose.qa.yml`'s `DB_DATABASE: directus`, live-confirmed by executor-infra attempt 3) lists 79 tables with no `content_pages`/`content_documents` among them. Every other bootstrap.sh-created collection exists, confirming bootstrap.sh ran here before but without FR-CMS-007's additions (merged in `aiqadam` PR #272 to `infrastructure/directus/bootstrap.sh`, part of commit `627cd91`, already present in the QA checkout at `/opt/apps/aiqadam-qa/`, HEAD `6e67229`, confirmed `AT_OR_PAST_TARGET` twice today). RBAC is fine: the Administrator role's real policy (`ff5b9067-9577-4d7e-bd1a-4ababce8f65d` — the `directus_access` junction row's actual `policy` column value, not the `5029fc70-...` UUID mistakenly treated as "the policy" by the original T-0136 investigation, which was actually that junction row's own `id`) has `admin_access: true, app_access: true` — genuine bypass-all admin. Directus's own 403 message ("...or it does not exist") was accurate the whole time.

### Resolved facts reused from prior attempts (live evidence, not re-guessed)

- **Checkout path / commit:** `/opt/apps/aiqadam-qa/`, HEAD `6e67229`, confirmed `AT_OR_PAST_TARGET` re: target `627cd91` (executor-cicd attempt 1, Phase 1 step 5) — re-verified in this plan's Phase 0 rather than assumed, since time has passed and other work may have touched the checkout.
- **Directus port:** `3119` (`docker exec aiqadam-qa-directus-1 printenv PORT` → `3119`; `/server/ping` → `200`/`pong`, executor-cicd attempt 1 Phase 1 steps 1–2).
- **Token env var:** the seed script (`infrastructure/directus/seed-content-documents.sh`) hard-requires an env var literally named `DIRECTUS_TOKEN` (`: "${DIRECTUS_TOKEN:?DIRECTUS_TOKEN is required}"`, confirmed by reading the script source in executor-cicd attempt 1). The **value** must come from `deploy/.env`'s `DIRECTUS_ADMIN_TOKEN=` key — per T-0137's rotation (`2026-08-20-rotate-qa-directus-token-001`), `DIRECTUS_ADMIN_TOKEN` is the canonical, compose-wired, currently-live credential; `DIRECTUS_TOKEN` in `deploy/.env` is a separately-rotated, independently-tracked legacy key (the two are **no longer guaranteed identical** post-rotation — rotation attempt 1 initially assumed they were the same secret and was corrected). **This plan uses the value of `DIRECTUS_ADMIN_TOKEN` from `deploy/.env`, assigned to the shell variable `DIRECTUS_TOKEN` when invoking the script**, since that is the current live-admin credential; using the legacy `DIRECTUS_TOKEN` key's own value risks using a stale/different-scoped credential. Same applies for bootstrap.sh, which the task input directs to use "fresh from `.env`" — same source key.
- **Redaction discipline:** every command that touches the token value substitutes it inline via command substitution in the same SSH session (`$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-)`) and is never echoed, logged, or written to any handoff. This is the exact pattern executor-cicd attempt 1 used correctly for the seed script call itself — the only exposure incident today came from a *diagnostic* `grep -B2` context-dump, not from this substitution pattern, which is not repeated here.

### Plan

**Phase 0 — Pre-flight re-verification (read-only)**

0.1. Re-confirm checkout is still at or past target commit — command:
```
ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git fetch origin && git log --oneline -1 && git merge-base --is-ancestor 627cd91 HEAD && echo AT_OR_PAST_TARGET || echo BEHIND_TARGET"
```
— verification: `AT_OR_PAST_TARGET`. If `BEHIND_TARGET`: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git checkout main && git pull origin main"`, then re-check. This is a working-tree update only (no `docker compose up`/rebuild) — `deploy/.env` and `deploy/docker-compose.qa.yml` are untracked and unaffected, per this host's established convention.

0.2. Re-confirm `bootstrap.sh` and `seed-content-documents.sh` are both present — command:
```
ssh pro-data-tech-qa "test -f /opt/apps/aiqadam-qa/infrastructure/directus/bootstrap.sh && test -f /opt/apps/aiqadam-qa/infrastructure/directus/seed-content-documents.sh && echo BOTH_SCRIPTS_PRESENT"
```
— verification: `BOTH_SCRIPTS_PRESENT`.

0.3. Snapshot current collection count and confirm `content_pages`/`content_documents` are still absent, as a pre-change baseline for the rollback/verification story — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -Atc \"SELECT count(*) FROM directus_collections;\" -c \"SELECT collection FROM directus_collections WHERE collection IN ('content_pages','content_documents');\""
```
— verification: record the baseline count (expected ~77 per today's earlier finding); the second query should return zero rows, confirming the gap is still present and this plan has not been overtaken by other work.

**Phase 1 — Run bootstrap.sh (state-changing — the reason this plan is `NEEDS_APPROVAL`)**

1.1. Read the fresh admin token value into a shell variable, then run bootstrap.sh in the same SSH session — command:
```
ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && DIRECTUS_URL=http://127.0.0.1:3119 DIRECTUS_TOKEN=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) bash infrastructure/directus/bootstrap.sh"
```
— verification: exit code 0; output shows a line per collection, the ~77 pre-existing collections printed with an "exists"/"✓ (exists)"-pattern line (per the script's documented idempotent behavior — confirmed by its own header comments and by its original local-verification precedent during FR-CMS-007's development, both cited in this step's input), and **exactly two new creation lines** for `content_pages` and `content_documents` (plus their PUBLIC read-only permission grants, mirroring every other collection bootstrap.sh manages). Capture full stdout/stderr verbatim in the executor's handoff — this is the primary evidence the "idempotent, ~77 no-ops + 2 creates" expectation held and nothing else changed.
  - **If the output shows bootstrap.sh attempting to *modify* (not just no-op-confirm) any of the ~77 pre-existing collections** (e.g. altering fields, changing permissions on collections other than the 2 new ones): **STOP immediately**, do not proceed to Phase 2, emit `BLOCKED`, and report the unexpected diff verbatim — this would contradict the idempotency assumption this plan's approval rests on and needs a fresh assessment, not continued execution.
  - **If bootstrap.sh exits non-zero or partway through**: **STOP**, do not retry blindly, report exact output and which collections show as created vs. not yet reached — go to Rollback.

**Phase 2 — Verify the schema gap is closed (read-only)**

2.1. Confirm both collections now exist in `directus_collections` — command:
```
ssh pro-data-tech-qa "docker exec ai-qadam-test-db-1 psql -U aiqadam -d directus -Atc \"SELECT collection FROM directus_collections WHERE collection IN ('content_pages','content_documents') ORDER BY 1;\""
```
— verification: exactly two rows, `content_documents` and `content_pages`.

2.2. Confirm the REST API now responds without the "does not exist" 403 — command:
```
ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3119/items/content_documents"
```
— verification: HTTP `200` (public read grant, per bootstrap.sh's per-collection PUBLIC read pattern) with an empty `data: []` body (no rows yet — seed step is Phase 3), or at minimum **not** `403`. If still `403` with the same "does not exist" message: **STOP**, emit `BLOCKED` — bootstrap.sh's collection-creation would then not have taken effect despite Phase 1 reporting success, a new and different failure mode requiring fresh investigation rather than a sixth guess.

**Phase 3 — Seed the 5 rows**

3.1. Run the seed script — command:
```
ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && DIRECTUS_URL=http://127.0.0.1:3119 DIRECTUS_TOKEN=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) bash infrastructure/directus/seed-content-documents.sh"
```
— verification: exit code 0; output shows 5 successful upserts (no `✗ ... HTTP 403` lines, the failure signature from the prior blocked attempt). Same redaction discipline as Phase 1.1 — token value substituted inline, never echoed.
  - **If any item fails**: do not retry the whole script blindly more than once. Capture the exact failing item and HTTP status/body, then **STOP** and emit `BLOCKED` for a fresh diagnosis — do not improvise a workaround.

**Phase 4 — Full verification (read-only)**

4.1. REST confirmation of all 5 rows — command:
```
ssh pro-data-tech-qa "curl -s http://127.0.0.1:3119/items/content_documents?fields=slug,title,superseded_by | python3 -m json.tool"
```
(or `jq` if available on host — executor's discretion, functionally equivalent) — verification: exactly 5 items with slugs `manifesto`, `charter-v0-1`, `kazakhstan-mou`, `global-board-polozhenie-v1`, `soglashenie-v1`.

4.2. External `/rules` listing — command:
```
ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/rules"
```
then a body fetch to confirm the page no longer shows "Пока нет опубликованных документов." and instead lists content — verification: HTTP `200`, body contains recognizable document titles (e.g. "Manifesto", "Charter").

4.3. Individual document page — command:
```
ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/rules/charter-v0-1"
```
— verification: HTTP `200`, full content renders (per T-0136's acceptance criteria).

4.4. Superseded-label check — fetch `global-board-polozhenie-v1` and `soglashenie-v1` pages and confirm a "Superseded by Charter v0.1" label is present; fetch `manifesto`, `charter-v0-1`, `kazakhstan-mou` and confirm the label is **absent**. Commands: same pattern as 4.3, five total fetches, grep response bodies for the label text.

4.5. `content_pages` existence does not regress the three FR-CMS-007 static pages — command:
```
ssh pro-data-tech-qa "for p in about history partners; do echo -n \"\$p: \"; curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/\$p; done"
```
— verification: all three return `200`, not `500`. Per FR-CMS-007's own documented scope (task input, and T-0136's task-file Notes), About/History content is hardcoded in the Astro pages (not Directus-driven) and Partners' dynamic fields are an intentional "content-authoring gap, not a blocker" — so a 200 with placeholder/empty dynamic content is the correct expected outcome, not a defect. A `500` here would indicate `content_pages`'s mere existence (with zero rows) broke something that previously degraded gracefully — worth flagging clearly if seen, though not expected.

### Rollback

Phase 0 and Phase 2/4 are pure reads — nothing to roll back.

**Phase 1 (bootstrap.sh) rollback:** bootstrap.sh's own design is additive/idempotent — it is not expected to alter or delete any of the ~77 pre-existing collections (Phase 1.1's STOP condition guards against silent violation of this assumption). If it nonetheless needs to be undone: the two new collections can be dropped via Directus's own schema API (`DELETE /collections/content_pages`, `DELETE /collections/content_documents`) or directly via `DROP TABLE content_pages, content_documents;` plus deleting their `directus_collections`/`directus_fields`/`directus_permissions` rows — this **is** a real, if narrow, rollback path (unlike a git-based rollback, since this is a schema change, not a code deploy). Not automated in this plan; only invoked if Phase 1's STOP condition fires or a later phase reveals the new collections are broken. No rollback is anticipated to be needed given the strong idempotency evidence already cited.

**Phase 3 (seed script) rollback:** the script itself is upsert-by-slug (idempotent) — re-running it after a partial failure is safe and is the natural "rollback" (it doesn't leave duplicate/orphaned rows). If specific bad rows need removing: `DELETE FROM content_documents WHERE slug IN (...)` via psql, scoped to the exact slugs written this run — but this has never been needed in any read of today's history and is not expected to be needed here.

### Verification (for step 07)

- **On-host:**
  - Phase 0.1's `AT_OR_PAST_TARGET` (or successful pull).
  - Phase 0.3's baseline (collection count, confirmed absence of the 2 target collections).
  - Phase 1.1's bootstrap.sh full output — specifically the "exists" pattern for ~77 pre-existing collections and creation lines for exactly the 2 new ones, no unexpected modifications.
  - Phase 2.1's `directus_collections` query showing both new collections present.
  - Phase 2.2's REST 200 (not 403) on `content_documents`.
  - Phase 3.1's seed script output — 5/5 successful upserts, no 403s.
- **External:**
  - Phase 4.1: `GET http://127.0.0.1:3119/items/content_documents` → 200, 5 items, correct slugs.
  - Phase 4.2: `GET https://qa.aiqadam.org/rules` → 200, lists all 5 documents (not the empty-state message).
  - Phase 4.3: `GET https://qa.aiqadam.org/rules/charter-v0-1` → 200, full content.
  - Phase 4.4: superseded label present on exactly `global-board-polozhenie-v1` and `soglashenie-v1`, absent on the other 3.
  - Phase 4.5: `GET https://qa.aiqadam.org/{about,history,partners}` → 200 each (not 500).

### Resources used

- **Secrets (by name):** `DIRECTUS_ADMIN_TOKEN` (from `deploy/.env` on `pro-data-tech-qa`) — read fresh at execution time via inline command substitution in each SSH session, never echoed, logged, or written to any handoff/artifact. No secret value appears anywhere in this plan or is expected to appear in the executor's handoff.
- **Files modified on host:** none directly edited. Directus's own Postgres schema (`directus` database: new tables `content_pages`, `content_documents`, plus their rows in `directus_collections`, `directus_fields`, `directus_permissions`) is modified by bootstrap.sh (Phase 1) and `content_documents`' data rows by the seed script (Phase 3) — both via each script's own REST/DB calls, not manual file edits. No file on the host filesystem itself is modified (scripts are read, not written; `.env` is read, not written).
- **Files modified in this repo (`landscape/`), to be applied at step 08:** `landscape/hosts/pro-data-tech-qa.md` should be updated to record: (a) the confirmed root cause (missing collections, not RBAC — closing out today's investigation thread), (b) that `content_pages`/`content_documents` now exist and are seeded, (c) the corrected understanding that `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` are independently-tracked keys post-T-0137-rotation (not the same secret under two names, superseding any earlier landscape note that assumed otherwise). `shared/app-registry.md`'s stale QA `aiqadam` entry (still describes a 2-container `aiqadam-qa` stack, pre-dating the 7-container/Directus/Authentik reality documented in the host file since T-0126) is a pre-existing gap not caused by this run — flag for a future landscape-only follow-up, out of this plan's scope to fix.
- **External APIs called:** Directus REST API on `pro-data-tech-qa` (`http://127.0.0.1:3119`, loopback-only, reached via SSH) — bootstrap.sh's collection/permission-creation calls, the seed script's upsert calls, and this plan's own verification `curl`s. Public-facing `https://qa.aiqadam.org/*` for Phase 4's external checks.

### Estimated impact

- **Downtime:** none. No container is restarted or recreated at any point in this plan — bootstrap.sh and the seed script both operate purely via Directus's own REST API against the already-running `aiqadam-qa-directus-1` container.
- **Affected services:** QA Directus's schema (2 new collections among ~79) and the `content_documents` table's data (5 new rows). No other collection's data or schema is expected to change (guarded by Phase 1.1's STOP condition). `qa.aiqadam.org`'s `/rules`, `/about`, `/history`, `/partners` pages are the externally-visible surfaces touched (all expected to move from "works but empty/403" to "works and populated," a strict improvement, not a regression).
- **Reversibility:** fully reversible in practice — the 2 new collections can be dropped via Directus's own schema API if needed, and the 5 seeded rows can be deleted by slug; nothing about this plan is a one-way door. Rated **partial** rather than **full** only because unlike every prior attempt today (which were pure reads or a single narrowly-scoped REST write), this plan's Phase 1 step touches Directus's live schema definition tables directly via a general-purpose script rather than a hand-authored, single-purpose command — the rollback exists and is straightforward, but it is not "the write never happened" simple.

## Issues / risks

- **This is the first state-changing, schema-touching step on this run.** Every attempt 1–5 today (and the parallel T-0137/T-0138 rotation work) was either read-only discovery or a single narrowly-scoped REST write that failed cleanly (0 rows) before any data existed. Running bootstrap.sh is qualitatively different: it is a general-purpose script whose *design intent* covers the full ~79-collection schema, even though its *expected effective delta here* is just 2 collections. Per solution-designer's own PASS-vs-NEEDS_APPROVAL rule ("bounded blast radius... call it out"; "any doubt about safety → NEEDS_APPROVAL"), this warrants human sign-off before running, despite the strong idempotency evidence. This is the primary and sufficient reason for this plan's verdict.
- **Idempotency is well-evidenced but not yet independently re-verified in this exact environment.** The evidence cited (script's own header comments, the "✓ collection X (exists)" output pattern, original local verification during FR-CMS-007's development) is strong but was gathered in a different environment (local dev container) or is a design claim, not a live QA-specific dry-run. Phase 1.1's explicit STOP-on-unexpected-modification condition is the safeguard — if the script's behavior against QA's specific (older, possibly slightly different) instance of the ~77 existing collections diverges from the no-op assumption, execution halts immediately rather than pushing through.
- **`DIRECTUS_TOKEN` vs `DIRECTUS_ADMIN_TOKEN` disambiguation matters more now than in the pre-rotation seed attempt.** Post-T-0137, these are confirmed independently-tracked keys, not guaranteed-identical values. This plan is explicit about sourcing the value from `DIRECTUS_ADMIN_TOKEN` (the canonical, currently-live, compose-wired credential) for both bootstrap.sh and the seed script, per this step's own explicit instruction ("fresh DIRECTUS_ADMIN_TOKEN from deploy/.env at execution time").
- **Phase 4.5's About/History/Partners check could reveal an unrelated, previously-masked issue** (e.g. a 500 caused by `content_pages` existing with zero rows, if any app code path assumes at least one row once the collection exists). This is explicitly framed by the task's own source material as expected-to-be-fine (a documented "content-authoring gap, not a blocker"), but is flagged here as the one outcome in this plan genuinely not fully certain in advance — if it fails, treat as a new, separate finding (likely an `aiqadam`-repo app-code issue, not an infra issue) rather than something this plan's rollback addresses.
- No item above is high-severity in the sense of touching prod, DNS, firewall, or an irreversible action — but the blast-radius expansion relative to every prior attempt on this run is real and is exactly what the `NEEDS_APPROVAL` gate exists to surface to the user before proceeding.

## Open questions (optional)

None blocking further design — this plan is complete and ready to execute pending user approval. The only outstanding question is the user's own sign-off on Phase 1 (running bootstrap.sh), which is the explicit purpose of the `NEEDS_APPROVAL` verdict, not a gap in this design.
