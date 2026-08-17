---
run_id: 2026-07-24-fix-authentik-admin-url-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-07-24T02:40:00Z
task_id: T-0125-fix-authentik-admin-url-on-qa
inputs_read:
  - runs/2026-07-24-fix-authentik-admin-url-001/step-01-task-reader.md
  - runs/2026-07-24-fix-authentik-admin-url-001/step-02-landscape-reader.md
  - runs/2026-07-24-fix-authentik-admin-url-001/step-03-task-validator.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/domains.md
  - landscape/cloudflare.md
  - tasks/T-0125-fix-authentik-admin-url-on-qa.md
artifacts_changed: []
next_step_hint: Orchestrator skips step 05 (verdict PASS, auto-approved) and advances directly to executor-infra (step 06). Executor must fetch the live environment block text first (Phase A) before editing, and must use qa-uz.aiqadam.org (not qa.aiqadam.org) for the external HTTP verification per the naming discrepancy noted in Issues/risks.
---

## Summary

Plan: add `AUTHENTIK_ADMIN_URL: "https://auth.qa.aiqadam.org"` to the `api` service's `environment:` block in `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` on `pro-data-tech-qa`, following the exact comment/quoting style of the 4 existing overrides, then recreate the `api` container via `docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d api` and verify end-to-end via a live registration probe; single-line env-var addition, timestamped backup taken first, trivially reversible.

## Details

### Plan

1. **Discover live environment-block text** — command: `ssh pro-data-tech-qa "cat /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml"` (fall back to `ssh pro-data-tech-qa "grep -n -A25 '^  api:' /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml"` if the full file is large/noisy) — verification: executor obtains the exact current text of the `api` service's `environment:` block, including precise indentation, quoting style, and comment wording used for the existing `PORT`, `REDIS_URL`, `DIRECTUS_URL`, `OIDC_ISSUER_URL` overrides. This is read-only discovery, not yet a state change — it exists so step 2 below can be executed as a precise, minimal diff rather than a guess. (Neither landscape file records this text — confirmed absent by step 02 — so this step is mandatory, not optional.)

2. **Reconfirm the env var is still absent from the running container** — command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-api-1 printenv | grep AUTHENTIK"` — verification: expect either no output (var absent — proceed) or output showing `AUTHENTIK_ADMIN_URL=https://auth.qa.aiqadam.org` already present (task already done — if so, skip to verification step 3 without re-editing, and executor should note this in its handoff rather than treat it as a failure).

3. **Grep for other silent-default code paths (acceptance criterion 4 from step 01)** — command: `ssh pro-data-tech-qa "grep -rn AUTHENTIK_ADMIN_URL /opt/apps/aiqadam-qa/apps/api/src"` — verification: expect exactly one read site (the Zod schema default in `config/env.ts`, consistent with the task's cited `env.ts:151`) and no second, independently-defaulting code path. If a second path is found, executor must stop and report it in the handoff rather than silently proceeding (out-of-scope discovery, not a blocker for this task's own fix, but must be surfaced).

4. **Backup the compose file** — command: `ssh pro-data-tech-qa "cp /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.pre-T0125.$(date -u +%Y%m%dT%H%M%SZ).bak"` — verification: `ssh pro-data-tech-qa "ls -la /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.pre-T0125.*.bak"` shows exactly one new file, matching this host's established naming convention (`.pre-T<NNNN>.<timestamp>.bak`, e.g. `deploy.sh.pre-T0113.20260717T081516Z.bak`, `40-ai-dala-infra.conf.pre-T0112.20260717T063435Z.bak`). This backup file is untracked by git (same as the compose file itself and `deploy.sh`, per the host's established convention that `deploy/` is untracked) and will persist on host per the project's "do not auto-clean operational artifacts" rule.

5. **Edit the `api` service's environment block** — command: no single shell one-liner is prescribed here because the exact insertion point/text depends on step 1's discovery output; the executor must use a precise, minimal edit (e.g. `sed` with an anchor on the `OIDC_ISSUER_URL:` line, or a heredoc-based line-insert, or direct interactive edit via `vi`/`nano` over SSH) that:
   - Inserts exactly one new line: `      AUTHENTIK_ADMIN_URL: "https://auth.qa.aiqadam.org"` (indentation matched to the 4 existing override lines, not assumed — read from step 1's output).
   - Adds a one-line comment immediately above or beside it, in the same style as the existing 4 overrides' comments (e.g. if the existing pattern is `# QA override: <reason>` on the line above each var, mirror that exact prefix/wording pattern; if it is inline `# comment` after the value, mirror that instead — executor decides from the literal text step 1 returned, not from this plan's guess).
   - Changes nothing else in the file (no reordering, no reformatting of unrelated lines, no touching the other 4 overrides).
   — verification: `ssh pro-data-tech-qa "diff /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.pre-T0125.<timestamp>.bak /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml"` shows exactly one line added (plus its comment line, if the comment is a separate line rather than inline) and zero lines removed or changed.

6. **Recreate the `api` container** — command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d api"` — verification: Compose reports `Recreating aiqadam-qa-api-1 ... done` (not `Running` unchanged — a no-op recreate would indicate the edit did not take effect and must be investigated before proceeding). Run as root directly (the task's own framing permits root to edit/act directly, or via `sudo -u deploy`; since `deploy` owns the file but root can act on it directly per the task statement, running as root is simplest and does not require impersonating the `deploy` account's restricted forced-command shell, which is locked to the CI deploy script only and cannot run arbitrary `docker compose` invocations anyway).

7. **On-host post-change check** — command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-api-1 printenv | grep AUTHENTIK_ADMIN_URL && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml ps api"` — verification: `AUTHENTIK_ADMIN_URL=https://auth.qa.aiqadam.org` printed, and `ps api` shows state `Up ... (healthy)` (container's own healthcheck, if defined, passing — if no healthcheck is defined for `api`, `Up` alone is sufficient; executor should note which is the case).

8. **External verification — health endpoint** — command: `curl -s -o /dev/null -w '%{http_code}\n' https://qa-uz.aiqadam.org/health` — verification: `200`. **Use `qa-uz.aiqadam.org`, not `qa.aiqadam.org`** — see Issues/risks below for why.

9. **External verification — live registration probe** — command (plain curl, simplest and sufficient — no need for the Playwright/e2e route): `curl -i -s -X POST https://qa-uz.aiqadam.org/api/v1/auth/register -H 'Content-Type: application/json' -d '{"email":"<fresh-never-used-email>@example.com","password":"<valid-test-password-meeting-policy>", ...other required fields per the endpoint'"'"'s schema}'` — verification: response status line `HTTP/2 302` (or `HTTP/1.1 302`) with a `location:` header of `/v1/auth/login` (or `/auth/login` — executor should just confirm the redirect target matches this task's acceptance criterion and note the exact value seen, since the task file's own quoted expectation is `/v1/auth/login`). Executor must generate a genuinely fresh email (e.g. timestamp-suffixed) to avoid a false-negative `409 already exists` result being mistaken for a fix failure.

### Rollback

1. Restore the compose file from backup — command: `ssh pro-data-tech-qa "cp /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.pre-T0125.<timestamp>.bak /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml"`
2. Recreate the container again to apply the reverted config — command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d api"`
3. Confirm rollback — command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-api-1 printenv | grep AUTHENTIK_ADMIN_URL"` — expect no output (var absent again, matching pre-change state). No data loss risk at any point: this is an environment-variable change only, no volumes, no database rows, no other files touched.

### Verification (for step 07)

- **On-host:**
  - `docker exec aiqadam-qa-api-1 printenv | grep AUTHENTIK_ADMIN_URL` → `AUTHENTIK_ADMIN_URL=https://auth.qa.aiqadam.org`
  - `docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml ps api` → state `Up` (and `(healthy)` if a healthcheck is defined for this service — confirm which)
  - `diff <backup> docker-compose.qa.yml` → exactly one line added (plus its comment), no other changes
  - Backup file present at `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.pre-T0125.<timestamp>.bak`
  - Grep confirms `AUTHENTIK_ADMIN_URL` has exactly one read site in `apps/api/src` (no second silent-default path)
- **External:**
  - `GET https://qa-uz.aiqadam.org/health` → `200`
  - `POST https://qa-uz.aiqadam.org/api/v1/auth/register` (fresh email) → `302` with `Location: /v1/auth/login`

### Resources used

- **Secrets (by name):** none — `auth.qa.aiqadam.org` is a public hostname, not a secret; no entry needed in `landscape/secrets-inventory.md`.
- **Files modified on host:** `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml` (edited); `/opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml.pre-T0125.<timestamp>.bak` (created, backup).
- **Files modified in this repo (landscape/), to be applied at step 08:** `landscape/hosts/pro-data-tech-qa.md` (add `AUTHENTIK_ADMIN_URL` to the documented `api` environment override list in the "AiQadam application stack (aiqadam-qa)" subsection — currently that subsection does not enumerate the compose-level env overrides at all, per step 02's finding; this is an opportunity to document all 5 overrides, not just the new one, since none are currently recorded); `landscape/hosts/pro-data-tech-qa.md`'s Change log table (new row for this run); `landscape/services.md` if its `aiqadam-qa-api-1` row's description is judged stale enough to need the same addition (landscape-updater's call at step 08).
- **External APIs called:** none (Authentik itself is not called directly by this plan — only the `api` container's own runtime behavior against Authentik is being fixed).

### Estimated impact

- **Downtime:** seconds — `docker compose up -d api` recreates a single container; nginx continues serving other paths uninterrupted, and the `api` container's own restart window (image already built, no rebuild needed) is expected to be low single-digit seconds based on the host's own precedent (T-0113's rehearsal recreate).
- **Affected services:** `aiqadam-qa-api-1` only. `aiqadam-qa-oidc-stub-1`, nginx, and the shared `ai-qadam-test-db-1` postgres container are untouched.
- **Reversibility:** fully reversible — restore backup file + recreate container, no data/volume/schema touched at any point.

## Issues / risks

- **Hostname discrepancy in the task's own verification step (flagging, not blocking):** the task file's acceptance criteria and this run's step-specific input both specify verifying against `https://qa.aiqadam.org/api/v1/auth/register`, but `landscape/domains.md` and `landscape/cloudflare.md` are explicit that `qa.aiqadam.org` is a **separate, out-of-band DNS record** "recreated by separate, out-of-band QA/Authentik work, **not this repo's T-0110 record, which was deleted**" — this repo's own, project-owned, project-managed public endpoint for this app is `qa-uz.aiqadam.org` (T-0110; nginx vhost, Let's Encrypt cert, Cloudflare A record all provisioned by this repo under that exact name). Both hostnames currently resolve to the same IP (`95.46.211.230`) per `domains.md`, and (per the task's own prose) `auth.qa.aiqadam.org` is confirmed live and is the same Authentik regardless of which app hostname is used to reach it — so this discrepancy does **not** change the fix itself (the env var value and the compose edit are identical either way) and does not block a `PASS` verdict. However, since `qa.aiqadam.org` is explicitly documented as **not provisioned or maintained by this repo** (unknown nginx config, unknown TLS cert ownership, unknown whether it even proxies to the same `aiqadam-qa-api-1` container on port 3113), I am directing the executor to run the external verification (steps 8–9 above) against **`qa-uz.aiqadam.org`** — the hostname this repo actually owns, documents, and can be confident routes correctly — rather than the task text's literal `qa.aiqadam.org`. If the executor or execution-validator independently confirms `qa.aiqadam.org` also correctly proxies to the same container (e.g., because it turns out to be a CNAME/alias or identically-configured nginx vhost on the same host), verifying against both is harmless and adds confidence; but `qa-uz.aiqadam.org` must be the canonical check either way. This is a data-quality note about the task's own text, not a plan defect — severity: low (does not affect blast radius, reversibility, or correctness of the actual env-var fix).
- **Comment style must be read live, not assumed.** Per step 02's finding, no landscape file records the exact current text of the 4-override block, so this plan intentionally does not prescribe the literal comment wording for the new line — Phase/step 1 (discovery) must supply that text before step 5 (edit) proceeds. This is a discovery-then-edit sequencing requirement, not an open question that blocks design.
- **`AUTHENTIK_ADMIN_URL` env var recreate-vs-restart:** confirmed correctly designed for `up -d api` (recreate), not `restart api` — a plain restart would preserve the old container's already-materialized environment and would not pick up the compose file change. This is called out explicitly in step 6 to prevent the executor from taking the faster-looking but incorrect shortcut.
- No other risks. Blast radius is genuinely low: single env var, single non-prod QA container, existing precedented pattern in the same file/block, timestamped backup with trivial rollback, no other endpoint/service touched.

## Open questions (optional)

- none — all approval-protocol PASS conditions are met: task file declares `estimated_blast_radius: low` and `estimated_reversibility: full` (confirmed by direct read of `tasks/T-0125-fix-authentik-admin-url-on-qa.md` frontmatter); the plan has no irreversible steps (no data deletion, no credential rotation, no DNS changes, no prod changes — this touches only a non-prod QA container's env var); I have no doubts about the plan's correctness or safety; the one Issues/risks item flagged above is explicitly low-severity and does not concern the fix's own correctness, only a pre-existing hostname-documentation inconsistency in the task text that the plan already routes around.
