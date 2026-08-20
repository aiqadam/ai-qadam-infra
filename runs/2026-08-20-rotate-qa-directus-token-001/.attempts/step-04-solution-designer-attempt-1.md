---
run_id: 2026-08-20-rotate-qa-directus-token-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-20T00:00:00Z
task_id: T-0137-rotate-qa-directus-admin-token
inputs_read:
  - runs/2026-08-20-rotate-qa-directus-token-001/step-01-task-reader.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-02-landscape-reader.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-03-task-validator.md
  - tasks/T-0137-rotate-qa-directus-admin-token.md
  - workflows/infrastructure.md
  - landscape/hosts/pro-data-tech-qa.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-06-executor-cicd.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: >-
  Orchestrator must halt and present this plan for user approval (do NOT
  auto-advance to executor). Once approved, route to step 06 executor-infra
  per workflows/infrastructure.md's step binding. Executor MUST treat Phase 0
  (discovery) as gating: if Phase 0 finds the app containers consume
  DIRECTUS_TOKEN/DIRECTUS_ADMIN_TOKEN directly, or finds Directus reads the
  static token from directus_users at request time (no restart needed) vs.
  seeds it from env at boot (restart needed), it must adapt Phase 2/3 exactly
  as branched below — this is designed as a decision plan, not a single
  linear command list. Executor must never print secret values; every
  command below is written so a literal value cannot appear in output even
  if misused (presence/absence, HTTP status codes, exit codes, or -oE
  key-only patterns only).
retry_of: null
---

## Summary

Rotate the QA Directus admin token (`DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN`, confirmed-identical-but-reverify) and `DIRECTUS_ADMIN_PASSWORD` on `pro-data-tech-qa`, via a three-phase plan — (0) live discovery of Directus's rotation mechanism, restart requirement, and app-container credential consumption; (1) generate-and-apply the new values at both the Directus admin-user record and `deploy/.env`, with a pre-change backup; (2) verify old value is dead and new value works, including app-side health — ending with the old value fully revoked and `landscape/secrets-inventory.md` updated with rotation date only. **This plan requires human approval before execution — it is a secret rotation, which is unconditionally `NEEDS_APPROVAL` per `shared/approval-protocol.md` regardless of the task's `estimated_blast_radius: low` / `estimated_reversibility: full` frontmatter.**

## Details

### Why this is a decision plan, not a linear script

Step 02 confirmed the landscape has **no documented answer** for:
1. Directus's rotation mechanism (UI vs REST vs CLI/DB).
2. Whether a restart/recreate of `aiqadam-qa-directus-1` is needed for a new token to take effect.
3. Whether `aiqadam-qa-api-1`/`aiqadam-qa-web-next-1` consume this same admin credential or a separate one.

Per this role's "Do NOT" rule ("Make assumptions to fill gaps that step 02 flagged for live discovery — instead, design a discovery sub-step"), Phase 0 below is that discovery sub-step. Phases 1–3 are written with explicit branches keyed to Phase 0's findings, so the executor does not need to improvise once discovery completes — improvisation is exactly what caused the T-0136 exposure (an ad-hoc `grep -B2`/`grep -v` combination not present in that plan's own text).

### Plan

#### Phase 0 — Discovery (read-only; no state changes)

0.1. **Re-verify `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` are the same secret under two names**, without printing either value.
   - Command: `ssh pro-data-tech-qa "diff <(grep '^DIRECTUS_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env | md5sum) <(grep '^DIRECTUS_ADMIN_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env | md5sum) >/dev/null && echo SAME_VALUE || echo DIFFERENT_VALUE"`
   - This compares MD5 digests of the two matched lines (including the `KEY=` prefix, which is identical on both sides only if the values are identical) — the digest, not the value, is what could appear in output, and even that is suppressed by `diff -q`-equivalent exit-code logic; only `SAME_VALUE`/`DIFFERENT_VALUE` is printed.
   - Verification: output is exactly one of the two literal tokens above.
   - **Branch:** if `DIFFERENT_VALUE`, STOP this plan and re-route to step 03 (task-validator) / user — the task's premise (one secret, two names) would be false and the rotation steps below (which assume updating both names to the same new value) would be wrong. Do not proceed past 0.1 on `DIFFERENT_VALUE`.

0.2. **Confirm the on-host variable set adjacent to these tokens**, key names only.
   - Command: `ssh pro-data-tech-qa "grep -oE '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN|DIRECTUS_ADMIN_PASSWORD|DIRECTUS_ADMIN_EMAIL|DIRECTUS_URL)=' /opt/apps/aiqadam-qa/deploy/.env"`
   - `-oE` structurally cannot print anything past the matched `KEY=` token — this is the same pattern T-0136's original plan step 3 used correctly (per the task's own note that the violation was an ad-hoc improvisation, not this pattern). Use ONLY this pattern for any future on-host var inspection in this run; never combine `grep -B/-A` context flags with a `-v` exclusion filter to "hide" a matched secret line — that combination is exactly what failed in T-0136.
   - Verification: confirms which of `DIRECTUS_ADMIN_EMAIL` / `DIRECTUS_URL` also exist so Phase 1/2 REST calls target the right identity and port. (Port `3119` and email are not yet confirmed for this run — see 0.3/0.4.)

0.3. **Determine Directus's admin-user identity for the token/password being rotated.**
   - Command: `ssh pro-data-tech-qa "grep -oE '^DIRECTUS_ADMIN_EMAIL=' /opt/apps/aiqadam-qa/deploy/.env"` (confirms the var name exists; if absent, fall back to `curl -s http://127.0.0.1:3119/users/me -H \"Authorization: Bearer \$(grep '^DIRECTUS_TOKEN=' deploy/.env | cut -d= -f2-)\" | python3 -c \"import sys,json; print(json.load(sys.stdin)['data']['email'])\"` run entirely inside the SSH session so the token substitution never appears in the command's own echoed text or this plan's transcript — only the resulting email address, not a secret, is printed).
   - Verification: an email address string (not a secret) is returned, identifying which Directus user record Phase 1 must update.

0.4. **Confirm Directus's live port and reachability** (re-derive; T-0136's discovery of port `3119` is a same-day, same-host precedent but must be independently reconfirmed, not assumed, since this is a different run).
   - Command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-directus-1 printenv PORT"` then `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:\$(docker exec aiqadam-qa-directus-1 printenv PORT)/server/ping"`
   - Verification: second command returns `200`.

0.5. **Determine Directus's rotation mechanism and restart requirement.** Directus 11 stores static access tokens and the password hash on the `directus_users` table row, read at request time via the `Authorization: Bearer <token>` header (looked up per-request against the DB), not seeded into memory from environment variables at container boot for the *general* token-validation path. However, `DIRECTUS_ADMIN_TOKEN`/`DIRECTUS_ADMIN_PASSWORD`/`DIRECTUS_ADMIN_EMAIL` env vars are ALSO Directus's own documented **bootstrap-admin mechanism**: on container startup, if no admin user exists Directus creates one using these values; on subsequent boots with an existing admin user, current Directus 11 behavior does NOT re-apply `DIRECTUS_ADMIN_PASSWORD`/`DIRECTUS_ADMIN_TOKEN` from env to an already-existing user (they are first-run bootstrap values only, not a synced-on-every-boot source of truth) — but this must be confirmed empirically against this specific image/version rather than assumed, since bootstrap-reapply behavior has changed across Directus major versions historically.
   - Command (empirical test, read-only): `ssh pro-data-tech-qa "docker inspect aiqadam-qa-directus-1 --format '{{.Image}}'"` then `ssh pro-data-tech-qa "docker exec aiqadam-qa-directus-1 directus --version 2>/dev/null || docker exec aiqadam-qa-directus-1 cat /directus/package.json 2>/dev/null | grep '\"version\"'"` to pin the exact Directus version running (image tag `directus/directus:11` is a floating major-version tag, not a pinned version).
   - Command (mechanism confirmation via docs, no live mutation): fetch Directus's own documentation for the pinned version confirming (a) `PATCH /users/me` with a `token` field regenerates a user's static token live, no restart required (Directus token validation reads the DB per-request); (b) password change via `PATCH /users/me` with a `password` field, or `POST /auth/password/request` + `/auth/password/reset` flow, also live, no restart required; (c) whether `DIRECTUS_ADMIN_TOKEN`/`DIRECTUS_ADMIN_PASSWORD` env vars are re-applied on container restart to an existing admin user (this determines whether the `.env` update alone would silently overwrite the REST-applied rotation back to old values on a future unrelated restart, which would be a rollback-relevant hazard to flag, not necessarily to prevent in this run).
   - Verification: a definitive statement in the handoff's Phase 0 results (recorded by the executor) of which mechanism is used, whether restart is required, and whether env-based re-seeding on restart is a live hazard for the future.
   - **Branch:** if research is inconclusive or contradicts the REST-live-no-restart assumption above, do NOT proceed to Phase 1 assuming REST-only is sufficient — escalate by emitting `BLOCKED` from the executor step and returning to solution-designer for a revised plan, rather than guessing.

0.6. **Determine which credential `aiqadam-qa-api-1` / `aiqadam-qa-web-next-1` use for their own Directus reads.**
   - Command: `ssh pro-data-tech-qa "grep -oE '^DIRECTUS[A-Z_]*=' /opt/apps/aiqadam-qa/deploy/.env | sort -u"` to enumerate ALL Directus-prefixed var names in the shared `.env` (key names only) — if this reveals a var distinct from `DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN`/`DIRECTUS_ADMIN_PASSWORD`/`DIRECTUS_ADMIN_EMAIL`/`DIRECTUS_URL` (e.g. a `DIRECTUS_PUBLIC_TOKEN`, `DIRECTUS_READ_TOKEN`, or similar), that is evidence of a separate app-facing credential.
   - Command: `ssh pro-data-tech-qa "docker inspect aiqadam-qa-api-1 --format '{{json .Config.Env}}' | tr ',' '\n' | grep -oE '\"?DIRECTUS[A-Z_]*='"` and the same for `aiqadam-qa-web-next-1` — key names only, `-oE` structurally truncates before any value.
   - Verification: either (a) the app containers reference only `DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN` — same credential, blast radius on the app is real and Phase 3 must include app-side verification and a coordinated restart if Phase 0.5 determined the app caches the token in its own process memory at boot; or (b) the app containers reference a distinct variable name — blast radius on the live app is zero, Phase 3's app-health check becomes a confirmatory sanity check rather than a required coordination point.
   - **Branch recorded here governs Phase 3's scope** — see Phase 3 below.

#### Phase 1 — Backup (before any destructive change)

1.1. **Back up `deploy/.env`** before editing.
   - Command: `ssh pro-data-tech-qa "sudo cp -p /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.*.bak && sudo chown tvolodi:aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.*.bak"`
   - This backup necessarily contains the OLD secret values (that's the point of a backup) — it must never be `cat`'d, `grep`'d without `-oE`, or otherwise displayed by the executor at any point in this run. It exists solely as an on-disk rollback artifact with the same restrictive permissions as the original file (mode 640, group `aiqadam-qa-secrets`).
   - Verification (presence/absence only, no content shown): `ssh pro-data-tech-qa "test -f /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.*.bak && echo BACKUP_EXISTS"` (glob expansion in test needs a wrapping shell — use `ls /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.*.bak >/dev/null 2>&1 && echo BACKUP_EXISTS`).

1.2. **Record old-vs-new differs (without printing either) — the task-validator/workflow's backup-verification requirement.**
   - Before generating the new value, capture a salted hash of the old value for later differs-from-new comparison: `ssh pro-data-tech-qa "grep '^DIRECTUS_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env | sha256sum | cut -d' ' -f1"` → record ONLY the resulting hex digest (a one-way hash, not the value) in the executor's handoff as `old_token_sha256=<digest>`. Repeat for `DIRECTUS_ADMIN_PASSWORD`. A SHA-256 digest of a high-entropy secret does not meaningfully aid reconstruction of the secret and is the standard "confirm without disclosing" pattern; still, the executor should treat even the digest as sensitive-adjacent and avoid pasting it into any external system, keeping it only in the run's own handoff file under this repo's existing threat model (local-only transcripts, not published).

#### Phase 2 — Generate and apply new values

2.1. **Generate new values on-host** (never transmitted back to the workstation in plaintext, never echoed to a terminal that gets logged).
   - Command: `ssh pro-data-tech-qa "NEW_TOKEN=\$(openssl rand -hex 32); NEW_PASSWORD=\$(openssl rand -base64 24); echo \$NEW_TOKEN | wc -c; echo \$NEW_PASSWORD | wc -c"` — deliberately prints only character counts (a non-secret sanity check that generation succeeded and met a minimum length), never the values, and the values live only in shell variables scoped to that single SSH session/subshell, never written to a file or a separate command's argv (which could otherwise appear in `ps` output or shell history on the target host).
   - **Constraint on execution:** the generate-apply-verify sequence for each value must happen inside ONE continuous SSH session (one `ssh ... "multi-command-script"` invocation, or a heredoc script executed remotely) so the generated value is never re-entered, retyped, or round-tripped through the local workstation. Splitting this into multiple separate `ssh` calls that each need the value passed as an argument would risk the value appearing in this session's own tool-call transcript (the exact class of risk this whole task exists to remediate) — the plan explicitly forbids that pattern.

2.2. **Apply the new token via Directus REST (`PATCH /users/me`), contingent on Phase 0.5's confirmed mechanism.**
   - Command (inside the same session as 2.1, reusing `$NEW_TOKEN`): `curl -s -o /dev/null -w '%{http_code}\n' -X PATCH http://127.0.0.1:<PORT_FROM_0.4>/users/me -H "Authorization: Bearer $OLD_TOKEN_STILL_VALID_AT_THIS_POINT" -H "Content-Type: application/json" -d "{\"token\":\"$NEW_TOKEN\"}"` where `$OLD_TOKEN_STILL_VALID_AT_THIS_POINT` is read directly from `.env` inside the same remote session (`OLD_TOKEN=$(grep '^DIRECTUS_TOKEN=' deploy/.env | cut -d= -f2-)`), never surfaced to this plan's own transcript.
   - Verification: HTTP status `200`.
   - **If Phase 0.5 found REST-live rotation is NOT how this Directus version behaves** (e.g. static tokens are only settable at user-creation time, or `PATCH /users/me` rejects a `token` field), branch to the Directus admin UI path instead: this requires a human operator to log into `https://qa.aiqadam.org`'s Directus admin UI (or the equivalent internal URL) interactively — which cannot be scripted by the executor — and this plan's approval request to the user must say so explicitly, asking the user to either perform that UI step themselves during execution or confirm REST is confirmed viable before approving.

2.3. **Apply the new password via Directus REST (`PATCH /users/me`).**
   - Command (same session): `curl -s -o /dev/null -w '%{http_code}\n' -X PATCH http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $NEW_TOKEN" -H "Content-Type: application/json" -d "{\"password\":\"$NEW_PASSWORD\"}"` (uses the just-rotated `$NEW_TOKEN` from 2.2, now that it is confirmed live, rather than the old token — sequencing token-then-password means only one rollback point needs the old token to still work).
   - Verification: HTTP status `200`.

2.4. **Update `deploy/.env`** to keep the file consistent with the live Directus state (both `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` updated to the identical new value per 0.1's confirmation, plus `DIRECTUS_ADMIN_PASSWORD`).
   - Command (same session, using `sed` with the value substituted from the still-in-scope shell variable, never re-typed): `sed -i "s|^DIRECTUS_TOKEN=.*|DIRECTUS_TOKEN=$NEW_TOKEN|; s|^DIRECTUS_ADMIN_TOKEN=.*|DIRECTUS_ADMIN_TOKEN=$NEW_TOKEN|; s|^DIRECTUS_ADMIN_PASSWORD=.*|DIRECTUS_ADMIN_PASSWORD=$NEW_PASSWORD|" /opt/apps/aiqadam-qa/deploy/.env`
   - Verification (presence/absence, not value): `grep -c -E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN|DIRECTUS_ADMIN_PASSWORD)=' /opt/apps/aiqadam-qa/deploy/.env` → expect `3`. Do not use `-A`/`-B` or any pattern that could echo the value; a bare count is sufficient to confirm the lines still exist post-edit.
   - **If Phase 0.5 found Directus re-applies `DIRECTUS_ADMIN_TOKEN`/`DIRECTUS_ADMIN_PASSWORD` from env to an existing user on container restart:** this step's ordering matters — it must happen AFTER 2.2/2.3 succeed (so a stray restart mid-rotation reapplies the *new* value, not stale old text), which the ordering above already satisfies. No restart is triggered by this step itself.

2.5. **Restart/recreate `aiqadam-qa-directus-1` only if Phase 0.5 determined it is required** for the REST-applied change to be considered durable/consistent with `.env`, or if the REST path in 2.2 was unavailable and env-seeded bootstrap is the only mechanism (in which case this step is not optional — it IS the rotation mechanism).
   - Command (only if branch requires it): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d --no-deps directus"` — `--no-deps` and naming the single service scopes the recreate to `aiqadam-qa-directus-1` only, avoiding an unintended recreate of the other 6 containers in this Compose project (matches the T-0125 precedent of `docker compose up -d api` for a single-service env-var pickup).
   - Verification: `docker ps --filter name=aiqadam-qa-directus-1 --format '{{.Status}}'` shows `Up ... (healthy)`, and 0.4's `/server/ping` → `200` check re-passes.

#### Phase 3 — Verification and app-side coordination (branch on Phase 0.6's finding)

3.1. **Old token confirmed dead** (mandatory, per task's own "done looks like" and Notes — "old value must be confirmed dead, not just superseded").
   - Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/users/me -H \"Authorization: Bearer \$(grep '.pre-T0137' deploy/.env.pre-T0137.*.bak... )\""` — **do not** reconstruct the old token this way (it would require reading the backup file's value into a variable, which is safe on-host but the pattern below is cleaner and avoids ever touching the backup file after 1.1): instead, keep `$OLD_TOKEN` from step 2.2's session scope alive through Phase 3 (single continuous session spanning Phases 2–3) and reuse it: `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $OLD_TOKEN"`
   - Verification: HTTP status `401` or `403` (not `200`).
   - **If this check returns `200`** (old token still works): rotation did not actually take effect where it matters (Directus may be validating against a cached token, a read replica, or the REST change didn't persist) — STOP, do not mark rotation complete, escalate to `BLOCKED` and report the specific status code observed. Do not attempt further ad-hoc diagnosis inline; return to solution-designer for a revised plan informed by this concrete failure.

3.2. **New token confirmed working.**
   - Command: `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $NEW_TOKEN"`
   - Verification: HTTP status `200`. (Write-permission check against `content_documents` is explicitly OUT of scope — that's T-0136's separately-tracked RBAC gap, not this task's concern; do not attempt it here.)

3.3. **App-side coordination — branch on Phase 0.6's finding.**
   - **If Phase 0.6 found the app containers use a credential distinct from `DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN`:** no app-container restart is needed for this rotation. Perform a confirmatory (not required-to-pass-before-declaring-done, but required-to-run) health check: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` → expect `200`, matching the pre-rotation baseline.
   - **If Phase 0.6 found the app containers DO reference `DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN` directly:** the app's own process may hold the old token in memory (env vars are read at container boot, not re-read live, per standard Docker/Compose behavior — same mechanic as the T-0125 precedent). This requires:
     a. Recreate `aiqadam-qa-api-1` and `aiqadam-qa-web-next-1` (whichever were confirmed to reference the token) to pick up the new `.env` value: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d --no-deps api web-next"` (name only the containers Phase 0.6 actually implicated; do not blanket-recreate all 7 services).
     b. Verify: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` → `200`, AND a Directus-backed public route (e.g. a `/press` or `/rules` page, per the task's own wording) returns non-error status, confirming the app's Directus-reading path survived the rotation.
   - Either branch's health-check result must be recorded in the executor's handoff as explicit evidence, not inferred.

3.4. **Clean up in-session shell variables.** As the final action inside the Phase 2–3 continuous SSH session, before disconnecting: `unset OLD_TOKEN NEW_TOKEN NEW_PASSWORD` (belt-and-suspenders — session-scoped shell variables do not persist after the SSH connection closes, but explicit unset avoids any risk if the executor's remote script is unexpectedly kept alive or reused).

### Rollback

1. **If Phase 2 fails partway (new token/password not fully applied, or `.env` update failed):** restore `.env` from the Phase 1.1 backup: `ssh pro-data-tech-qa "sudo cp -p /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.<TIMESTAMP>.bak /opt/apps/aiqadam-qa/deploy/.env"`. If Directus's admin-user record was already updated via REST (2.2/2.3 succeeded) but `.env` restore now reverts to the old value, this creates a **mismatch between the Directus DB state (new value) and `.env` (old value)** — in that specific partial-failure case, do NOT restore `.env`; instead re-run 2.4 only (the `.env` update) to catch it up to the DB, since the DB is source-of-truth for what Directus actually accepts. Full-file `.env` restore is only correct when 2.2/2.3 (the REST-level change) did NOT yet succeed.
2. **If Phase 2.5 (Directus restart) fails or the container comes up unhealthy:** `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d --no-deps directus"` (re-run; if still unhealthy, this is a service-health incident independent of the rotation and should be escalated as `BLOCKED`, not silently retried more than twice per the workflow's retry budget).
3. **If Phase 3.3's app-side restart breaks the app** (`/health` stops returning 200 after `api`/`web-next` recreate): the app-side recreate is the only step touching those containers; re-running `docker compose up -d --no-deps api web-next` again (picks up the now-corrected `.env`, which by this point in the sequence already has the new values) is the first recovery attempt. If the app remains unhealthy after that, this indicates the app does NOT tolerate the new credential for a reason unrelated to file mechanics (e.g. a code-level expectation about token format) — escalate to `BLOCKED`, do not attempt to revert Directus's own token back to the old (now-should-be-dead) value as a workaround, since that would defeat the rotation's purpose; instead treat it as an app-compatibility bug to fix forward.
4. **General:** no step in this plan deletes data. The `.env` backup (1.1) and Directus's own DB-level user record (unmodified except the two fields being rotated) mean every step here is reversible except "old token confirmed dead" (3.1) — once the old token is revoked, going back to it is only possible by re-issuing it as a *new* rotation (Directus does not support "restore a specific prior token value" — regenerating produces a fresh random value, not the old one). This is expected and matches the task's explicit intent (a rotation that could be trivially undone back to the exposed value would defeat the purpose).

### Verification (for step 07)

- **On-host:**
  - `deploy/.env.pre-T0137.<timestamp>.bak` exists (backup captured before any edit).
  - `deploy/.env` contains exactly 3 matches for `-E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN|DIRECTUS_ADMIN_PASSWORD)='` (lines still present, count-only check, no value shown).
  - `docker ps --filter name=aiqadam-qa-directus-1 --format '{{.Status}}'` shows `Up ... (healthy)` (if a restart occurred in 2.5).
  - If app-side branch taken: `docker ps --filter name=aiqadam-qa-api-1 --filter name=aiqadam-qa-web-next-1` both show recent `Up` status consistent with a just-now recreate.
  - No command in the executor's own tool-call transcript or this run's handoff files contains a secret value or its raw backup-file contents — spot-checkable by grepping the run's own handoff files for a suspiciously long hex/base64-looking string is NOT to be done by pattern-matching the actual secret (unknown to the validator) but by confirming every command logged in step-06's handoff matches one of the exact command templates in this plan (no ad-hoc improvised diagnostic commands, per the task's explicit constraint).
- **External:**
  - `curl https://qa.aiqadam.org/health` → `200`.
  - `curl http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer <OLD>"` → `401`/`403` (executor must have already run this in 3.1; step 07 cannot independently re-run it without the old value, so step 07 instead confirms the *executor's recorded status code* for this check in the step-06 handoff, since step 07 has no way to hold the old token itself once it's been rotated and the backup deliberately isn't read for this purpose).
  - `curl http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer <NEW>"` → same caveat — step 07 confirms the executor's recorded result rather than re-deriving the new token itself, consistent with never handling secret values outside the single Phase 2–3 session.
  - If app-side branch taken: a Directus-backed public route on `qa.aiqadam.org` (e.g. `/press`) returns a non-5xx status.

### Resources used

- Secrets (by name): `DIRECTUS_TOKEN` / `DIRECTUS_ADMIN_TOKEN` (same secret, two names — pending 0.1 reconfirmation), `DIRECTUS_ADMIN_PASSWORD`. (Per `landscape/secrets-inventory.md` convention — this file does not exist in this checkout yet; step 08 will create the first entry for these names, rotation date only, no value.)
- Files modified on host:
  - `/opt/apps/aiqadam-qa/deploy/.env` (in place, backed up first)
  - New file created: `/opt/apps/aiqadam-qa/deploy/.env.pre-T0137.<timestamp>.bak`
- Files modified in this repo (landscape/): `landscape/secrets-inventory.md` (rotation date entry, to be applied at step 08 — first-time creation per step 02's finding that this file doesn't exist in this checkout). `landscape/hosts/pro-data-tech-qa.md` Change log, if step 08 judges a note warranted (rotation events are typically log-worthy given this host's existing Change-log convention for credential/RBAC changes).
- External APIs called: Directus REST API on `pro-data-tech-qa` (`PATCH /users/me`, `GET /users/me`) — internal to the host (loopback), not a third-party external API.

### Estimated impact

- **Downtime:** none expected if Phase 0.5 confirms REST-live rotation with no restart needed (the common case for Directus 11's static-token model); **seconds** if a Directus container recreate is required (2.5) — a single-service `docker compose up -d --no-deps directus` recreate, consistent with the T-0125 precedent's `api`-only recreate pattern; **seconds, per-container** if the app-side branch (3.3) requires recreating `api`/`web-next` — each such recreate is a brief connection-drop window for that one service, not a full-stack outage (`network_mode: host`, no shared network to disrupt, other 5 containers unaffected).
- **Affected services:** `aiqadam-qa-directus-1` (definite); `aiqadam-qa-api-1` / `aiqadam-qa-web-next-1` (conditional on Phase 0.6's finding — genuinely unknown until discovery runs, this is the core reason this plan cannot claim "zero app blast radius" up front).
- **Reversibility:** partially reversible — `.env` and the Directus DB record are both restorable to a *consistent* state via the backup + rollback steps above, but the OLD secret VALUE itself is intentionally one-way (by design — that's the point of revocation). This is why the task's frontmatter `estimated_reversibility: full` is misleading for this specific operation and is exactly the scenario `shared/approval-protocol.md` names as always requiring `NEEDS_APPROVAL` ("secret rotations" is listed explicitly, with no low-blast-radius exception).

## Issues / risks

- **This plan emits `NEEDS_APPROVAL` unconditionally, per task Notes (stated twice) and `shared/approval-protocol.md`'s explicit "Always requires NEEDS_APPROVAL: ... secret rotations" rule** — this holds regardless of the task's own `estimated_blast_radius: low` / `estimated_reversibility: full` frontmatter, which does not override the protocol's named-category rule. Flagging prominently per this role's own verdict criteria (blast radius/reversibility conditions for `PASS` are necessary but not sufficient — the protocol's explicit "always" list is a hard override).
- **Phase 0.5's REST-live-no-restart assumption is the plan's single largest unverified premise.** It is stated with reasoning (Directus's general architecture) but explicitly flagged for empirical/documentation confirmation during execution, not asserted as fact. If discovery contradicts it, the plan already specifies the correct branch (UI-assisted path, requiring a human operator, or an env-seeded-bootstrap restart path) rather than leaving the executor to guess.
- **Phase 2.2's fallback (Directus admin UI, if REST regeneration isn't supported) cannot be scripted by the executor.** If that branch is hit, the executor must emit `BLOCKED` and report back rather than attempting to drive a browser session or asking the user for the new value out-of-band mid-run (which would risk the same transcript-exposure failure mode this task exists to fix). This is a real possibility the user should know about before approving: **approval of this plan should be understood as approval of the REST path as primary, with a return to the user if the UI-only fallback is required.**
- **App blast radius is genuinely unknown until Phase 0.6 runs.** The plan is deliberately branched rather than assuming either "shared credential, must coordinate" or "separate credential, zero impact" — asserting either without discovery would violate this role's explicit "Do NOT... make assumptions to fill gaps flagged for live discovery" rule.
- **Output hygiene is the highest-severity operational risk given T-0136's precedent on this exact host/file/credential family.** Every command in this plan avoids the `grep -B/-A` + `-v`-exclusion pattern that failed previously, uses `-oE` key-only capture or HTTP-status/exit-code/count-only verification exclusively, and mandates a single continuous SSH session for the generate→apply→verify sequence so no value is re-typed or passed as a separate command's argument. The executor must treat any deviation from this plan's exact command templates (e.g. an "ad-hoc diagnostic command… improvised mid-run," which is how T-0136's exposure actually happened per the task's own framing) as forbidden — if a need for an unplanned diagnostic arises, the executor should stop and return to solution-designer rather than improvise a new grep/sed pattern live.
- **`landscape/secrets-inventory.md` does not exist in this checkout.** Step 08 will be creating the first entry for these secret names, not editing an existing dated one — noted so step 08 doesn't treat its absence as an error.
- **Sequencing dependency on T-0136's retry**, per task Notes: T-0136's eventual RBAC-gap retry must happen strictly after this rotation completes (so it uses the new token, not the compromised one). This plan does not touch T-0136's scope directly but the orchestrator should hold T-0136's retry until this run reaches a terminal PASS state.

## Open questions (optional)

None blocking this design — the plan itself IS the resolution mechanism for the open questions step 01–03 flagged (rotation mechanism, restart requirement, app credential consumer), structured as Phase 0 discovery with explicit branches for every plausible answer. The one item that could still stop execution mid-run is Phase 2.2's UI-fallback branch, which is called out above as a possible return-to-user point, not a currently-open question requiring resolution before approval.
