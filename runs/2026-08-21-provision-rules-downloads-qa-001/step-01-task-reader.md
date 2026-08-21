---
run_id: 2026-08-21-provision-rules-downloads-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-08-21T06:10:00Z
task_id: T-0141-provision-rules-source-file-downloads-qa
inputs_read:
  - shared/handoff-format.md
  - shared/verdicts.md
  - tasks/T-0141-provision-rules-source-file-downloads-qa.md
  - tasks/README.md
  - workflows/README.md
  - workflows/_common-operations.md
  - workflows/deploy-app.md
artifacts_changed: []
next_step_hint: landscape-reader must load landscape/hosts/pro-data-tech-qa.md, landscape/services.md, landscape/secrets-inventory.md, shared/app-registry.md — and explicitly report what the landscape does NOT say about QA Directus's port, database, and the FR-CMS-008 folder/grant surface.
---

## Summary

Run `infrastructure/directus/bootstrap.sh` then `infrastructure/directus/seed-content-documents.sh` against the QA Directus instance on `pro-data-tech-qa`, so that the already-merged FR-CMS-008 code on `qa.aiqadam.org/rules/<slug>` renders a working, anonymously-downloadable source-document link instead of an inert filename label.

## Details

- **Workflow:** `deploy-app` (per the task file's `workflow:` field). State-changing; task file `T-0141-provision-rules-source-file-downloads-qa` exists with `status: in-progress` and `executed_by_runs: [2026-08-21-provision-rules-downloads-qa-001]` — both preconditions for a state-changing run are satisfied.

### Why (verbatim from the task file)

> `aiqadam/ai-qadam-platform` PR [#274](https://github.com/aiqadam/ai-qadam-platform/pull/274)
> (merged, `FR-CMS-008`) makes the source-document filename on
> `qa.aiqadam.org/rules/<slug>` a real download link instead of the inert
> citation label FR-CMS-007 originally shipped. The **code** is merged and
> live, but the **data and schema it depends on are not provisioned on QA**
> — exactly the same gap class as T-0136, which is why this is being
> tracked as its own task rather than assumed to happen automatically.
>
> Two scripts must run against QA, in order:
>
> 1. `infrastructure/directus/bootstrap.sh` — creates the new
>    `content_documents.source_file` field, its relation to
>    `directus_files`, the dedicated `public-documents` Directus folder,
>    and the **folder-scoped anonymous read grant** on `directus_files`.
> 2. `infrastructure/directus/seed-content-documents.sh` — uploads the 5
>    governance `.docx` files into that folder and links each to its
>    `content_documents` row.
>
> **Current user-visible state:** `qa.aiqadam.org/rules/manifesto` shows
> `AI Qadam Manifesto.docx` as plain text with no download link (confirmed
> live 2026-08-21, post-merge). Per FR-CMS-008 AC-8 this is the *intended*
> fallback when `source_file` is null, not a defect — but it is also not
> the shipped feature.
>
> **Why the ordering is load-bearing:** without step 1's grant, anonymous
> `GET /assets/:id` returns **403** and every download link is broken even
> though the page renders it. FR-CMS-008's security review established
> this empirically (the prior assumption that Directus serves assets
> without a `directus_files` permission grant was tested against live
> Directus and found false). Running the seed before bootstrap produces
> uploaded-but-unreadable assets.

### Raw user request (verbatim)

> "Run bootstrap.sh and seed-content-documents.sh against QA so the /rules source-document download links actually work — the FR-CMS-008 code is merged but the data/schema it needs isn't provisioned on QA yet."

The raw request and the task file agree on scope; no reconciliation needed.

### Target scope

Landscape files the downstream steps must consult:

- `landscape/hosts/pro-data-tech-qa.md` — the target host (`affects:` names exactly this file)
- `landscape/services.md` — the `aiqadam-qa` Compose project and the `aiqadam-qa-directus-1` container
- `landscape/secrets-inventory.md` — `DIRECTUS_ADMIN_TOKEN` location and rotation date
- `shared/app-registry.md` — per the `deploy-app` workflow's "App registration requirement" and "Script-first execution model"

Systems in scope for the change itself:

- QA Directus (`aiqadam-qa-directus-1`, Compose project `aiqadam-qa`, host `pro-data-tech-qa` / `95.46.211.230`) — schema and content only
- The QA app checkout `/opt/apps/aiqadam-qa/` — read (to invoke the two scripts) plus one new untracked directory `portal-content/20260819/` populated by `scp`
- The management workstation `c:\Users\tvolo\dev\ai-dala\aiqadam\portal-content\20260819\` — read-only source of the 5 `.docx` files

Explicitly **out** of scope: no container rebuild, no `docker compose up`, no app-code deploy, no credential rotation, no nginx/DNS/TLS change.

### Acceptance criteria (translated from "What done looks like")

The step-07 execution-validator will check each of these:

1. **AC-1 (prerequisite):** the 5 source `.docx` files exist at `/opt/apps/aiqadam-qa/portal-content/20260819/` on the QA host. Pre-flight confirmed `portal-content/` does not exist there at all. User decision: deliver via `scp` from the management workstation.
2. **AC-2:** `bootstrap.sh` completes against QA. Expected delta is exactly: `content_documents.source_file` field + its `directus_files` relation, the `public-documents` folder, and the folder-scoped anonymous `directus_files` read grant. **Every other collection reports `✓ exists` / no-op.** Any *new* unexpected modification to a pre-existing collection is a STOP condition, not something to run past. (The dated `F-S2.12 operator_invites` field-drop block is already-integrated and was applied by T-0136 — it should be a no-op this time.)
3. **AC-3:** `seed-content-documents.sh` completes: 5 files uploaded into `public-documents`, each `content_documents` row's `source_file` set. Idempotent — a re-run must not create duplicate `directus_files` rows.
4. **AC-4 (the real acceptance signal):** anonymous, unauthenticated `GET <directus>/assets/<id>?download` returns **200** with `Content-Disposition: attachment` preserving the real filename (e.g. `AI Qadam Manifesto.docx`). Non-null `source_file` alone does not satisfy this.
5. **AC-5 (negative / security):** an asset **outside** `public-documents` still returns **403** anonymously, and anonymous `GET /files` does not enumerate the whole file table. The grant must remain folder-scoped; an over-broad grant is itself a finding.
6. **AC-6:** `https://qa.aiqadam.org/rules/manifesto` renders a working download link whose href resolves to the **public** Directus host, not the internal `directus:8055` docker alias.
7. **AC-7:** the other 4 document pages (`charter-v0-1`, `kazakhstan-mou`, `global-board-polozhenie-v1`, `soglashenie-v1`) each render a working download link.
8. **AC-8 (no regression):** `qa.aiqadam.org/rules` plus `/about`, `/history`, `/partners` still return 200.

### Constraints stated by user / task

- **Ordering is load-bearing and non-negotiable:** `bootstrap.sh` must complete before `seed-content-documents.sh`. Seeding first produces uploaded-but-unreadable (403) assets.
- **File delivery method is decided:** `scp` the 5 `.docx` from `c:\Users\tvolo\dev\ai-dala\aiqadam\portal-content\20260819\` to the QA host. **Not** committing them to git; **not** uploading directly to Directus. Accepted trade-off: the files become host-local and non-reproducible (lost on host rebuild, would need re-copying) in exchange for keeping several MB of binary `.docx` out of git history.
- **Credential:** `DIRECTUS_ADMIN_TOKEN` from `/opt/apps/aiqadam-qa/deploy/.env`, read **fresh at execution time**. It was rotated 2026-08-20 (T-0137) — no value from any earlier run's notes may be reused.
- **Output hygiene (standing rule, two prior incidents on this host/credential family — T-0137, T-0138):** never combine `grep -B/-A` with `-v`, on any file; inline-substitute secrets within a single SSH session; verify via status codes, counts, or digests only. Never echo a token.
- **STOP condition on bootstrap.sh:** any new, unexpected modification to a pre-existing collection halts the run rather than being run past.
- **Blast radius / reversibility declared `low` / `full`:** additive schema + additive content, no credential change, no container restart expected, seed is idempotent.

### Information gaps for downstream steps

For step 02 (landscape-reader) to source or explicitly flag as absent:

- QA Directus's actual connection details as seen from the host — the landscape documents the container (`aiqadam-qa-directus-1`, `directus/directus:11`, pinned 11.17.4, `network_mode: host`) but the container table records its host port as **"not enumerated"**. The scripts need a concrete base URL.
- The name of the Directus **database**. The landscape documents `aiqadam_test` and `aiqadam_qa` inside `ai-qadam-test-db-1`; whether Directus has its own separate DB in that cluster is not recorded in the committed landscape.
- The **public** Directus hostname/origin that FR-CMS-008's rendered download links must resolve to (AC-6) — i.e. whether an nginx vhost fronts Directus, or whether the asset URL is composed from an env var. `landscape/services.md` records only one QA vhost (`qa.aiqadam.org` → `127.0.0.1:3113`, the api) plus an incidentally-referenced `auth.qa.aiqadam.org` for Authentik.
- Whether `shared/app-registry.md` has a **Scripts** table for `aiqadam` (the `deploy-app` workflow's script-first rule requires the designer to check it before hand-rolling a command sequence).
- Whether the landscape records anything about `portal-content/`, the `public-documents` folder, the `PUBLIC_ASSET_FOLDER_ID`, or the anonymous-asset grant — i.e. whether any part of the target state already exists.
- Which SSH identity/path the executor should use for both `ssh` and `scp` to `95.46.211.230`.

For step 03 (task-validator) to rule on:

- The `scp` prerequisite is a **state-changing step on the QA host that is not one of the two named scripts**. Whether it belongs in this task's plan or needs separate treatment is a validation question, not a design one.

## Issues / risks

- **The one known blocker is the missing source files**, and it is already characterized: `/opt/apps/aiqadam-qa/portal-content/` does not exist on the QA host (gitignored, never deployed). The task cannot reach AC-3/AC-4 until the `scp` lands. This is a prerequisite step, not an unknown.
- **The seed script is non-fatal on missing files by design** — it skips uploads rather than erroring. So a partially-successful run could look green while achieving nothing. The validator must assert on the anonymous-200 (AC-4), not on script exit code.
- **`bootstrap.sh` has a full-schema surface.** T-0136 exercised it once against this instance and left the collections current, so the expected delta is genuinely just the FR-CMS-008 additions — but the STOP condition on unexpected pre-existing-collection modification stays armed.
- **Secret-handling history on this exact host and credential family:** two transcript-exposure incidents on 2026-08-20. The output-hygiene constraint above is a hard rule for the designer and executor, not advice.
- **Delivery-method trade-off accepted but worth recording in landscape:** after this run, QA's `/rules` downloads depend on host-local files that exist in no repository. Step 08 should record that dependency so a future host rebuild doesn't silently regress the feature.
- The `deploy-app` workflow's Phase 0 (local → GitHub → Hetzner sync check) is a **no-op for the app repo** here — no app code is being deployed, and the FR-CMS-008 code is already on the QA checkout at commit `84cfd4d`. The designer should note it rather than skip it silently.

## Open questions

none — the task is unambiguous, the workflow is named in the task file, and the single blocker already has a user-decided resolution.
