---
run_id: 2026-08-20-rotate-qa-directus-token-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-20T00:00:00Z
task_id: T-0137-rotate-qa-directus-admin-token
inputs_read:
  - runs/2026-08-20-rotate-qa-directus-token-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-06-executor-infra.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-06-executor-cicd.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-01-task-reader.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-02-landscape-reader.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-03-task-validator.md
  - tasks/T-0137-rotate-qa-directus-admin-token.md
  - workflows/infrastructure.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: >-
  Orchestrator must halt and present this plan for user approval (do NOT
  auto-advance to executor). Once approved, route to step 06 executor-infra
  per workflows/infrastructure.md's step binding. This plan supersedes
  attempt 1 entirely: it rotates THREE independent live values
  (DIRECTUS_TOKEN, DIRECTUS_ADMIN_TOKEN, DIRECTUS_ADMIN_PASSWORD) rather
  than treating the first two as one secret under two names. Phase 0 is
  gating and gathers per-token identity (GET /users/me) before Phase 1
  commits to a rotation mechanism per value. Executor must never print
  secret values; every command is written so a literal value cannot
  appear in output even if misused (presence/absence, HTTP status codes,
  exit codes, identity-field-only responses, or -oE key-only patterns
  only).
retry_of: step-04
---

## Summary

Rotate all three values that appeared in T-0136's compromised transcript —
`DIRECTUS_TOKEN`, `DIRECTUS_ADMIN_TOKEN` (now confirmed to be **independent,
currently-different** values, not one secret under two names), and
`DIRECTUS_ADMIN_PASSWORD` — on `pro-data-tech-qa`, via a four-phase plan:
(0) live, read-only discovery of which Directus user (if any) each token
value authenticates as, resolving whether `DIRECTUS_TOKEN` is a live,
independently-meaningful credential or a stale/drifted copy; (1) backup;
(2) generate-and-apply three new values via the mechanism each one's
Phase-0 identity dictates; (3) verify all three old values are dead and
all three new values work, including app-side health. Ends with all three
old values fully revoked and `landscape/secrets-inventory.md` updated with
rotation dates only. **This plan requires human approval before
execution — it is a secret rotation, unconditionally `NEEDS_APPROVAL` per
`shared/approval-protocol.md` regardless of the task's
`estimated_blast_radius: low` / `estimated_reversibility: full`
frontmatter.**

## Details

### What changed since attempt 1, and why

Attempt 1 assumed `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` were the same
secret under two names (per T-0136's step-06 claim) and built a plan around
updating both names to one identical new value. Step 06's Phase 0.1 (the
attempt's own gating check) found `DIFFERENT_VALUE` on live host state and
halted, per the plan's own instruction.

Investigation into *why* they differ, done during this redesign (not
assumed), traces a concrete, documented root cause — this is not a mystery
requiring further live guessing at design time, though Phase 0 below still
verifies it empirically before any write:

- `deploy/docker-compose.qa.yml`'s `directus` service block sets
  `ADMIN_TOKEN: ${DIRECTUS_ADMIN_TOKEN:?...}` — this is Directus's own
  documented admin-bootstrap env var, consumed directly by the Directus
  container at boot.
- The same compose file's `api` service block sets
  `DIRECTUS_TOKEN: ${DIRECTUS_ADMIN_TOKEN:?...}` (added by
  `ISS-INFRA-QA-DIRECTUS-SCHEMA-001` / `wf-20260728-fix-145`, per
  `.copilot/context/workspace-state.md` and
  `.copilot/issues/ISS-INFRA-QA-DIRECTUS-SCHEMA-001.md` in the `aiqadam`
  repo) — i.e., **inside the running `api` container's own process
  environment, `DIRECTUS_TOKEN` is compose-interpolated FROM
  `DIRECTUS_ADMIN_TOKEN`**, not read as a separate `.env` key at that
  layer.
- However, `deploy/.env` on the host ALSO has its own flat, literal
  `DIRECTUS_TOKEN=` line — a distinct, independently-editable key with no
  automatic sync to `DIRECTUS_ADMIN_TOKEN`'s value at the `.env`-file
  level. Per that same issue's Resolution section, this flat `.env` key
  was previously a stale placeholder (`qa-placeholder-token-not-real-...`)
  and was later hand-set by an operator to match `DIRECTUS_ADMIN_TOKEN`'s
  value **at that point in time**, with no enforced ongoing sync
  mechanism. It is plausible (and consistent with T-0137's live Phase 0.1
  finding of `DIFFERENT_VALUE`) that this flat `.env` copy has since
  drifted from `DIRECTUS_ADMIN_TOKEN` — e.g. through an earlier
  provisioning step, a partial edit, or simply never having been the
  literal value actually consumed by any live process (since the `api`
  container's real `DIRECTUS_TOKEN` comes from compose interpolation of
  `DIRECTUS_ADMIN_TOKEN`, not from this flat `.env` key at all).
- This is **not** the `scripts/provision-break-glass.sh` /
  `aiqadam-break-glass@aiqadam.org` break-glass credential pattern from
  the `aiqadam` repo. That pattern is confirmed absent from QA entirely —
  no `BREAKGLASS_DIRECTUS_TOKEN`, `aiqadam-break-glass@aiqadam.org`, or
  `provision-break-glass.sh` reference appears anywhere in
  `deploy/docker-compose.qa.yml`, `landscape/hosts/pro-data-tech-qa.md`,
  or this run's own artifacts. That break-glass mechanism has apparently
  never been provisioned on QA (it is documented as a prod/roadmap
  concept — `docs/01-business/community-platform-roadmap.md` §0.2,
  `docs/04-development/security/runbooks/break-glass.md`). Do not
  conflate `DIRECTUS_TOKEN`'s drift with that unrelated, unprovisioned
  mechanism.

**Working hypothesis (to be empirically confirmed by Phase 0, not
assumed):** `DIRECTUS_ADMIN_TOKEN` is the live, canonical Directus admin
static token — the one Directus's own `directus_users` table actually
honors, and the one the `api` container actually uses via compose
interpolation. The flat `.env` `DIRECTUS_TOKEN=` key is most likely
either (a) unused by anything live (a vestigial key nobody reads anymore
now that the `api` service gets its `DIRECTUS_TOKEN` via compose
interpolation from `DIRECTUS_ADMIN_TOKEN` instead), or (b) still consumed
by something not yet identified (e.g. a manually-invoked script run
directly on-host with `DIRECTUS_TOKEN=$(grep ... .env)`, exactly as
T-0136's own seed script invocation did). Either way, **both are treated
as potentially-exposed and both are rotated** — this plan does not narrow
scope based on the hypothesis. Phase 0 exists to convert this hypothesis
into a confirmed fact per-token (which Directus user, if any, each value
authenticates as) so Phase 2 picks the correct mechanism for each,
without ever assuming the hypothesis is correct before writing anything.

### Why this is a decision plan, not a linear script

Phase 0 below determines, for each of `DIRECTUS_TOKEN` and
`DIRECTUS_ADMIN_TOKEN`, independently:
1. Does it currently authenticate against Directus at all (`GET
   /users/me` → 200 vs 401/403)?
2. If yes, which user/role does it resolve to (email + role name only,
   never the token)?
3. Is that the same user as the other token, a different user, or does
   one/both fail to authenticate at all (evidence of already-stale/dead
   values)?

Phase 2's mechanism per value is picked from Phase 0's findings, not
assumed. This mirrors attempt 1's discipline (single continuous SSH
session per credential's generate-apply-verify sequence, count/status-only
verification, no `grep -B/-A` + `-v` combinations, explicit `BLOCKED` on
any unplanned diagnostic need) and extends it to a two-token-identity
model instead of a one-secret-two-names model.

### Plan

#### Phase 0 — Discovery (read-only; no state changes)

0.1. **Resolve Directus's live port and reachability** (re-derive per-run,
     not assumed from a prior run).
   - Command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-directus-1 printenv PORT"` then `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:\$(docker exec aiqadam-qa-directus-1 printenv PORT)/server/ping"`
   - Verification: second command returns `200`.

0.2. **Confirm the on-host variable set relevant to this rotation, key
     names only** (never values).
   - Command: `ssh pro-data-tech-qa "grep -oE '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN|DIRECTUS_ADMIN_PASSWORD|DIRECTUS_ADMIN_EMAIL|DIRECTUS_SECRET|DIRECTUS_URL)=' /opt/apps/aiqadam-qa/deploy/.env | sort -u"`
   - `-oE` structurally cannot print anything past the matched `KEY=`
     token. Use ONLY this pattern for any on-host var-name inspection in
     this run; never combine `grep -B/-A` context flags with a `-v`
     exclusion filter to "hide" a matched secret line — that exact
     combination is what caused T-0136's exposure.
   - Verification: confirms which of these five keys exist on-host before
     Phase 2 references any of them.

0.3. **Resolve DIRECTUS_ADMIN_TOKEN's identity** — does it authenticate,
     and as whom (email + role only, never the token value)?
   - Command (single SSH session; token substituted entirely inside the
     remote shell, never echoed or passed as a separate local argument):
     ```
     ssh pro-data-tech-qa '
       T=$(grep "^DIRECTUS_ADMIN_TOKEN=" /opt/apps/aiqadam-qa/deploy/.env | cut -d= -f2-)
       PORT=$(docker exec aiqadam-qa-directus-1 printenv PORT)
       CODE=$(curl -s -o /tmp/t137-admintoken-whoami.json -w "%{http_code}" \
         http://127.0.0.1:${PORT}/users/me -H "Authorization: Bearer ${T}")
       echo "HTTP:${CODE}"
       if [ "${CODE}" = "200" ]; then
         python3 -c "import json;d=json.load(open(\"/tmp/t137-admintoken-whoami.json\"))[\"data\"];print(\"email:\"+str(d.get(\"email\")));print(\"role:\"+str(d.get(\"role\")))"
       fi
       rm -f /tmp/t137-admintoken-whoami.json
       unset T
     '
     ```
   - Verification: `HTTP:200` plus an `email:`/`role:` pair identifies
     the live admin user this token belongs to (expected:
     `DIRECTUS_ADMIN_EMAIL`'s value, Administrator role) — OR `HTTP:401`/
     `HTTP:403`, meaning this value is already dead/invalid (a distinct,
     separately-noteworthy finding — see Issues/risks).
   - The temp file is written and removed inside the same remote command
     invocation, never transferred to the workstation, never `cat`'d.

0.4. **Resolve DIRECTUS_TOKEN's identity** — same probe, independently.
   - Command (same pattern, substituting the other variable name):
     ```
     ssh pro-data-tech-qa '
       T=$(grep "^DIRECTUS_TOKEN=" /opt/apps/aiqadam-qa/deploy/.env | cut -d= -f2-)
       PORT=$(docker exec aiqadam-qa-directus-1 printenv PORT)
       CODE=$(curl -s -o /tmp/t137-token-whoami.json -w "%{http_code}" \
         http://127.0.0.1:${PORT}/users/me -H "Authorization: Bearer ${T}")
       echo "HTTP:${CODE}"
       if [ "${CODE}" = "200" ]; then
         python3 -c "import json;d=json.load(open(\"/tmp/t137-token-whoami.json\"))[\"data\"];print(\"email:\"+str(d.get(\"email\")));print(\"role:\"+str(d.get(\"role\")))"
       fi
       rm -f /tmp/t137-token-whoami.json
       unset T
     '
     ```
   - Verification: same three possible outcomes as 0.3, independently.

0.5. **Classify each token from 0.3/0.4's results** into exactly one of:
   - **(a) Live, resolves to the Directus admin user** (email matches
     `DIRECTUS_ADMIN_EMAIL`'s value — check by comparing the printed email
     string to `grep -oE '^DIRECTUS_ADMIN_EMAIL=' deploy/.env` presence,
     not printing the email's own value as a secret since email is not
     secret but is still handled via the same discipline) → rotate via
     `PATCH /users/me` against that live session (Directus 11's static
     tokens and password are DB-row fields read per-request, not
     re-seeded from env on every boot for an existing user — see 0.6 for
     the empirical version/behavior check that confirms this before
     Phase 2 relies on it).
   - **(b) Live, resolves to a DIFFERENT user than (a)** → this is a
     distinct credential with its own identity; rotate it too, via
     `PATCH /users/me` against ITS OWN session (never cross-apply one
     token's new value using another token's identity). Flag this
     prominently to the user in the approval request — an unexpected
     second live admin-capable identity is itself a finding worth
     surfacing, independent of the rotation.
   - **(c) Not live (401/403)** → this value is already dead. No REST
     rotation mechanism applies (there is no live session to PATCH
     against). Record this as "already inert, no action needed beyond
     overwriting the stale `.env` value with fresh random bytes so a
     dead value doesn't linger readable in the file" — this is a
     `.env`-only edit for this key, not a Directus-side change, and
     carries no revocation-verification burden (a dead token needs no
     "confirm it's dead" step; it already is).
   - **Branch:** if 0.3 and 0.4 resolve to the SAME email+role (i.e.
     they currently hold co-incidentally identical values, or Directus
     considers them the same token string), treat this the same as (a)
     applied twice — the second `PATCH /users/me` in Phase 2 with a
     second, independently-generated new value will simply also change
     what the first token now resolves to, since it's the same DB row;
     Phase 2.2/2.3 below sequences this correctly (see note there).

0.6. **Confirm Directus's static-token/password rotation mechanism and
     restart requirement for the pinned image/version actually running**
     (do not assume Directus 11's general architecture applies to this
     exact build without checking).
   - Command: `ssh pro-data-tech-qa "docker inspect aiqadam-qa-directus-1 --format '{{.Image}}'"` then `ssh pro-data-tech-qa "docker exec aiqadam-qa-directus-1 directus --version 2>/dev/null || docker exec aiqadam-qa-directus-1 cat /directus/package.json 2>/dev/null | grep '\"version\"'"`
   - Confirms exact pinned version (the `directus/directus:11` tag is
     floating). Cross-reference against Directus's own documentation for
     that version: `PATCH /users/me` with a `token` field regenerates a
     static token live (no restart); `PATCH /users/me` with a `password`
     field changes the password live (no restart); `ADMIN_TOKEN`/
     `ADMIN_PASSWORD` env vars are first-run bootstrap-only for a
     not-yet-existing admin user, not re-applied to an existing user on
     every subsequent boot.
   - Verification: a definitive statement recorded in the executor's
     handoff of which mechanism applies and whether restart is required.
   - **Branch:** if research is inconclusive or contradicts the
     REST-live-no-restart expectation, do NOT proceed to Phase 2 assuming
     REST-only is sufficient — emit `BLOCKED` and return to
     solution-designer, rather than guessing.

0.7. **Determine which credential `aiqadam-qa-api-1` / `aiqadam-qa-web-next-1`
     actually consume at the container-process level** (not just what
     `deploy/.env` or `docker-compose.qa.yml` textually says — confirm
     the resolved, post-interpolation value each container's own process
     environment holds, by comparing digests, never printing values).
   - Command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-api-1 printenv DIRECTUS_TOKEN | sha256sum"` and `ssh pro-data-tech-qa "grep '^DIRECTUS_ADMIN_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env | cut -d= -f2- | sha256sum"` — compare the two digests (both computed the same way, neither value printed) to confirm empirically (not just by reading the compose YAML) that `api`'s live `DIRECTUS_TOKEN` matches `DIRECTUS_ADMIN_TOKEN`'s current `.env` value, consistent with the compose interpolation `DIRECTUS_TOKEN: ${DIRECTUS_ADMIN_TOKEN:?...}`.
   - Command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-web-next-1 printenv | grep -oE '^DIRECTUS[A-Z_]*='"` — key names only, confirms whether `web-next` references any Directus credential at all (its own compose block was not shown to reference one in the sections reviewed, but this must be confirmed live, not inferred from a partial file read).
   - Verification: digest match/mismatch (not values) plus a key-name list for `web-next`, establishing definitively which running containers need a coordinated restart in Phase 3 once `DIRECTUS_ADMIN_TOKEN` changes.

#### Phase 1 — Backup (before any destructive change)

1.1. **Back up `deploy/.env`** before editing.
   - Command: `ssh pro-data-tech-qa "sudo cp -p /opt/apps/aiqadam-qa/deploy/.env /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.*.bak && sudo chown tvolodi:aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.*.bak"`
   - This backup contains the OLD secret values by design (that's the
     point). It must never be `cat`'d, `grep`'d without `-oE`, or
     displayed at any point in this run.
   - Verification (presence only): `ssh pro-data-tech-qa "ls /opt/apps/aiqadam-qa/deploy/.env.pre-T0137.*.bak >/dev/null 2>&1 && echo BACKUP_EXISTS"`

#### Phase 2 — Generate and apply three new values

Sequencing rationale: rotate `DIRECTUS_ADMIN_TOKEN` first (it is, per the
working hypothesis confirmed by Phase 0, the canonical live admin
credential and the one the `api` container actually depends on), then
`DIRECTUS_ADMIN_PASSWORD` (same admin user, now authenticated via the
already-rotated token), then `DIRECTUS_TOKEN` last (handled per its
Phase-0 classification — either a second live `PATCH /users/me` if it
resolves to a distinct user, or a plain `.env` overwrite with fresh random
bytes if Phase 0 found it already dead).

2.1. **Generate new values on-host**, one continuous SSH session covering
     generation through Phase 2's applies (never round-tripped to the
     workstation).
   - Command (opens the session Phase 2.2–2.4 continues inside):
     `ssh pro-data-tech-qa "NEW_ADMIN_TOKEN=\$(openssl rand -hex 32); NEW_PASSWORD=\$(openssl rand -base64 24); NEW_LEGACY_TOKEN=\$(openssl rand -hex 32); echo \$NEW_ADMIN_TOKEN | wc -c; echo \$NEW_PASSWORD | wc -c; echo \$NEW_LEGACY_TOKEN | wc -c"` — prints only character counts (non-secret sanity check), values live only in shell variables scoped to this one session.
   - **Constraint:** the entire generate→apply→verify sequence for all
     three values happens inside ONE continuous SSH session (one
     multi-command remote script), per the same discipline as attempt 1,
     to prevent any value being re-typed, retransmitted, or appearing in
     this session's own transcript.

2.2. **Apply `DIRECTUS_ADMIN_TOKEN`'s new value via `PATCH /users/me`**,
     authenticated with the OLD `DIRECTUS_ADMIN_TOKEN` value (still valid
     at this point), contingent on Phase 0.5 classifying it as case (a) or
     (b) — i.e., live.
   - Command (same session): `OLD_ADMIN_TOKEN=$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-); curl -s -o /dev/null -w '%{http_code}\n' -X PATCH http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $OLD_ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"token\":\"$NEW_ADMIN_TOKEN\"}"`
   - Verification: HTTP `200`.
   - **If Phase 0.3 found `DIRECTUS_ADMIN_TOKEN` already dead (case c)** —
     not expected, since it's the compose-wired live credential, but if
     Phase 0 surprises us — skip this REST call; there is no live session
     to PATCH. Proceed directly to the `.env`-only overwrite in 2.5.
   - **If Phase 0.6 found REST-live rotation is NOT how this Directus
     version behaves:** branch to the Directus admin UI path — requires a
     human operator, cannot be scripted. Emit `BLOCKED`, report back; do
     not attempt to drive a browser or ask the user for the new value
     out-of-band mid-run.

2.3. **Apply `DIRECTUS_ADMIN_PASSWORD`'s new value via `PATCH /users/me`**,
     now authenticated with the just-rotated `NEW_ADMIN_TOKEN`.
   - Command (same session): `curl -s -o /dev/null -w '%{http_code}\n' -X PATCH http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $NEW_ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"password\":\"$NEW_PASSWORD\"}"`
   - Verification: HTTP `200`.

2.4. **Apply `DIRECTUS_TOKEN`'s new value, per Phase 0.4/0.5's
     classification:**
   - **If Phase 0.4 found `DIRECTUS_TOKEN` live and resolving to the SAME
     user as `DIRECTUS_ADMIN_TOKEN`** (Phase 0.5's same-identity branch):
     this token string, whatever it was, referred to the same DB row
     already rotated in 2.2 — no separate REST call is needed or possible
     (the old value is already dead as a side effect of 2.2's `PATCH`);
     proceed straight to 2.5's `.env` update using `$NEW_ADMIN_TOKEN` for
     BOTH the `DIRECTUS_TOKEN=` and `DIRECTUS_ADMIN_TOKEN=` lines, so
     `.env` stays internally consistent with what Directus's DB now
     actually holds.
   - **If Phase 0.4 found `DIRECTUS_TOKEN` live and resolving to a
     DIFFERENT user** (Phase 0.5 case b): apply `$NEW_LEGACY_TOKEN`
     independently: `curl -s -o /dev/null -w '%{http_code}\n' -X PATCH http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $OLD_LEGACY_TOKEN" -H "Content-Type: application/json" -d "{\"token\":\"$NEW_LEGACY_TOKEN\"}"` (where `$OLD_LEGACY_TOKEN` is read the same way as `$OLD_ADMIN_TOKEN` was, from `deploy/.env`'s `DIRECTUS_TOKEN=` line, inside this same session). Verification: HTTP `200`. Use `$NEW_LEGACY_TOKEN` for the `.env` `DIRECTUS_TOKEN=` line in 2.5; leave `DIRECTUS_ADMIN_TOKEN=` set to `$NEW_ADMIN_TOKEN` — the two remain genuinely independent going forward, consistent with what Phase 0 found on live evidence, rather than being artificially collapsed to one value as attempt 1 wrongly assumed.
   - **If Phase 0.4 found `DIRECTUS_TOKEN` already dead** (case c): no
     REST call applies. Use `$NEW_LEGACY_TOKEN` (freshly generated random
     bytes) directly for the `.env` `DIRECTUS_TOKEN=` line in 2.5 — this
     simply ensures the file no longer contains the exposed dead value in
     plaintext, even though nothing live currently depends on it. Record
     in the handoff that this key's rotation was a plaintext-hygiene-only
     change, not a live-credential revocation (there was nothing live to
     revoke).

2.5. **Update `deploy/.env`** to keep the file consistent with whatever
     Phase 2.2–2.4 actually did (branch-dependent — do not blindly write
     the "both identical" pattern from attempt 1).
   - Command (same session, `sed` using the in-scope shell variables,
     never retyped): `sed -i "s|^DIRECTUS_TOKEN=.*|DIRECTUS_TOKEN=$NEW_TOKEN_FOR_ENV|; s|^DIRECTUS_ADMIN_TOKEN=.*|DIRECTUS_ADMIN_TOKEN=$NEW_ADMIN_TOKEN|; s|^DIRECTUS_ADMIN_PASSWORD=.*|DIRECTUS_ADMIN_PASSWORD=$NEW_PASSWORD|" /opt/apps/aiqadam-qa/deploy/.env` where `$NEW_TOKEN_FOR_ENV` is `$NEW_ADMIN_TOKEN` (same-identity branch) or `$NEW_LEGACY_TOKEN` (distinct-identity or dead-value branch), per 2.4's resolved case.
   - Verification (count only, never value): `grep -c -E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN|DIRECTUS_ADMIN_PASSWORD)=' /opt/apps/aiqadam-qa/deploy/.env` → expect `3`.

2.6. **Restart/recreate `aiqadam-qa-directus-1` only if Phase 0.6
     determined it is required** for durability/consistency, or if the
     REST path was unavailable and env-seeded bootstrap is the only
     mechanism.
   - Command (only if branch requires it): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d --no-deps directus"`
   - Verification: `docker ps --filter name=aiqadam-qa-directus-1 --format '{{.Status}}'` shows `Up ... (healthy)`; `/server/ping` → `200` re-passes.

2.7. **Recreate `aiqadam-qa-api-1`** (and `web-next` only if Phase 0.7
     found it references a Directus credential) — required regardless of
     whether Directus itself needs a restart, because `api`'s
     `DIRECTUS_TOKEN` is populated at container-boot time via compose
     interpolation of `DIRECTUS_ADMIN_TOKEN`'s `.env` value (confirmed
     live by Phase 0.7); Docker/Compose env vars are not hot-reloaded
     into a running container (same T-0125 precedent attempt 1 cited).
   - Command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && docker compose -p aiqadam-qa -f deploy/docker-compose.qa.yml up -d --no-deps api"` (add `web-next` to the service list only if Phase 0.7 implicated it).
   - Verification: `docker ps --filter name=aiqadam-qa-api-1 --format '{{.Status}}'` shows recent `Up` status.

#### Phase 3 — Verification

3.1. **Old `DIRECTUS_ADMIN_TOKEN` confirmed dead.**
   - Command (same session, reusing `$OLD_ADMIN_TOKEN` from 2.2's scope): `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $OLD_ADMIN_TOKEN"`
   - Verification: `401` or `403`.
   - **If `200`:** STOP, do not mark rotation complete, emit `BLOCKED` with
     the observed status code. Do not improvise further diagnosis inline;
     return to solution-designer.

3.2. **Old `DIRECTUS_TOKEN` confirmed dead — only if Phase 0.4 found it
     live** (case a/b; skip if it was already dead per case c, nothing to
     re-confirm).
   - Command: `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $OLD_LEGACY_TOKEN"` (or, in the same-identity branch, this is structurally the same check as 3.1 since it's the same DB row — do not re-run it as if independent; record it as "covered by 3.1").
   - Verification: `401`/`403`.

3.3. **New values confirmed working.**
   - Command: `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $NEW_ADMIN_TOKEN"` → `200`.
   - If the distinct-identity branch was taken: also `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<PORT>/users/me -H "Authorization: Bearer $NEW_LEGACY_TOKEN"` → `200`.
   - Write-permission check against `content_documents` is explicitly OUT
     of scope (T-0136's separately-tracked RBAC gap) — do not attempt it.

3.4. **App-side health.**
   - Command: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` → `200`.
   - A Directus-backed public route (e.g. `/press`) returns non-5xx,
     confirming `api`'s Directus-reading path survived rotation (this
     matters here specifically because Phase 0.7 confirmed `api` DOES
     consume `DIRECTUS_ADMIN_TOKEN`'s value, unlike attempt 1's
     conditional framing — this check is mandatory in this plan, not a
     conditional branch).

3.5. **Clean up in-session shell variables** as the final action before
     disconnecting: `unset OLD_ADMIN_TOKEN OLD_LEGACY_TOKEN NEW_ADMIN_TOKEN NEW_PASSWORD NEW_LEGACY_TOKEN NEW_TOKEN_FOR_ENV`.

### Rollback

1. **If Phase 2 fails partway** (some but not all of the three values
   applied): the `.env` backup (1.1) restores the FILE, but if any REST
   `PATCH` in 2.2/2.3/2.4 already succeeded, restoring `.env` alone
   creates a DB-vs-file mismatch for that specific value. Rule: for any
   value whose REST apply already returned `200`, do NOT revert `.env`'s
   line for that key — instead re-run only 2.5 (the `.env` sync) to catch
   the file up to whatever the DB now holds. Only revert `.env` wholesale
   from the 1.1 backup if NO REST apply succeeded yet.
2. **If Phase 2.6 (Directus restart) fails or comes up unhealthy:**
   re-run `docker compose up -d --no-deps directus`; if still unhealthy
   after one retry, escalate to `BLOCKED` as a service-health incident
   independent of the rotation, not a silent extra retry.
3. **If Phase 2.7 (api/web-next recreate) breaks the app** (`/health`
   stops returning 200): re-run `docker compose up -d --no-deps api
   [web-next]` (picks up the now-corrected `.env`). If still unhealthy,
   this indicates an app-compatibility issue unrelated to file mechanics
   — escalate to `BLOCKED`; do not revert Directus's own credentials back
   to the old (should-be-dead) values as a workaround, since that defeats
   the rotation's purpose. Treat as a fix-forward app bug.
4. **General:** no step deletes data. The `.env` backup (1.1) and
   Directus's own DB-level user record(s) (unmodified except the fields
   being rotated) make every step reversible except "old value confirmed
   dead" (3.1/3.2) — once a value is revoked, restoring the exact old
   value is not possible (Directus generates a fresh random token on
   regeneration, does not support "restore prior value"). This is
   expected and matches the task's intent.

### Verification (for step 07)

- **On-host:**
  - `deploy/.env.pre-T0137.<timestamp>.bak` exists.
  - `deploy/.env` contains exactly 3 matches for
    `-E '^(DIRECTUS_TOKEN|DIRECTUS_ADMIN_TOKEN|DIRECTUS_ADMIN_PASSWORD)='`
    (count-only, no value shown).
  - `aiqadam-qa-directus-1` shows `Up ... (healthy)` if restarted.
  - `aiqadam-qa-api-1` (and `web-next` if implicated) shows a recent `Up`
    status consistent with a just-now recreate.
  - Every command in step-06's handoff matches one of this plan's exact
    command templates (no ad-hoc improvised diagnostics) — validator
    spot-checks by comparing the executor's logged commands against this
    plan's text, not by pattern-matching for secret-shaped strings.
- **External:**
  - `curl https://qa.aiqadam.org/health` → `200`.
  - A Directus-backed public route (`/press` or similar) → non-5xx.
  - Executor's recorded HTTP status codes for: old `DIRECTUS_ADMIN_TOKEN`
    → 401/403; old `DIRECTUS_TOKEN` (if it was live) → 401/403; new
    `DIRECTUS_ADMIN_TOKEN` → 200; new `DIRECTUS_TOKEN` (if it was rotated
    via REST, not just overwritten) → 200. Step 07 confirms these from
    the step-06 handoff's recorded results, not by re-deriving the tokens
    itself (it never holds them).

### Resources used

- Secrets (by name): `DIRECTUS_TOKEN`, `DIRECTUS_ADMIN_TOKEN`,
  `DIRECTUS_ADMIN_PASSWORD` — now treated as up to three independent
  secrets, not one secret under two names. (`landscape/secrets-inventory.md`
  does not exist in this checkout; step 08 creates first-time entries,
  rotation date only, no values.)
- Files modified on host:
  - `/opt/apps/aiqadam-qa/deploy/.env` (in place, backed up first)
  - New file: `/opt/apps/aiqadam-qa/deploy/.env.pre-T0137.<timestamp>.bak`
- Files modified in this repo (landscape/): `landscape/secrets-inventory.md`
  (rotation date entries for all three names, applied at step 08).
  `landscape/hosts/pro-data-tech-qa.md` Change log — should also record
  the corrected understanding that `DIRECTUS_TOKEN` and
  `DIRECTUS_ADMIN_TOKEN` are independent values (not one secret under two
  names) with `DIRECTUS_ADMIN_TOKEN` being the canonical, compose-wired
  credential — so this false premise is not restated by a future task.
- External APIs called: Directus REST API on `pro-data-tech-qa` (`PATCH
  /users/me`, `GET /users/me`) — loopback-internal, not third-party.

### Estimated impact

- **Downtime:** none expected for the Directus credential changes
  themselves (REST-live, no restart, pending Phase 0.6 confirmation);
  **seconds** for the mandatory `api` container recreate in Phase 2.7
  (single-service, `--no-deps`, matches T-0125 precedent) — this recreate
  is mandatory in this plan (not conditional) because Phase 0.7's
  documented finding (compose interpolation `DIRECTUS_TOKEN:
  ${DIRECTUS_ADMIN_TOKEN:?...}` on the `api` service) already establishes
  `api` consumes this credential; **seconds more** if `web-next` is also
  implicated by Phase 0.7's live check.
- **Affected services:** `aiqadam-qa-directus-1` (credential change,
  restart conditional on 0.6); `aiqadam-qa-api-1` (recreate, mandatory per
  above); `aiqadam-qa-web-next-1` (conditional on Phase 0.7's live
  finding).
- **Reversibility:** partially reversible — `.env` and the Directus DB
  records are restorable to a *consistent* state via backup + rollback
  steps, but the OLD secret VALUES are intentionally one-way once
  revoked. This is why the task's frontmatter `estimated_reversibility:
  full` does not override `shared/approval-protocol.md`'s explicit
  "secret rotations always require NEEDS_APPROVAL" rule.

## Issues / risks

- **This plan emits `NEEDS_APPROVAL` unconditionally**, per task Notes
  (stated twice) and `shared/approval-protocol.md`'s explicit "Always
  requires NEEDS_APPROVAL: ... secret rotations" rule — holds regardless
  of the task's own `estimated_blast_radius: low` /
  `estimated_reversibility: full` frontmatter.
- **The premise correction itself is a material finding the user should
  see before approving.** `DIRECTUS_TOKEN` and `DIRECTUS_ADMIN_TOKEN` are
  NOT the same secret under two names, contradicting both the task's
  Notes and T-0136's own step-06 claim. The likely (Phase-0-to-be-
  confirmed) explanation: `DIRECTUS_ADMIN_TOKEN` is the canonical,
  compose-wired live credential (both the `directus` and `api` services
  reference it, the latter via `DIRECTUS_TOKEN:
  ${DIRECTUS_ADMIN_TOKEN:?...}` interpolation, per
  `ISS-INFRA-QA-DIRECTUS-SCHEMA-001`'s fix); `DIRECTUS_TOKEN`'s flat
  `.env` copy is a separate, manually-maintained key with no automatic
  sync, previously set to match by hand and since apparently drifted.
  This is NOT the unrelated `scripts/provision-break-glass.sh` /
  `aiqadam-break-glass@aiqadam.org` mechanism — that pattern is confirmed
  absent from QA entirely (no matching references anywhere in QA's
  compose file or landscape docs).
- **Phase 0.4's outcome materially changes Phase 2's shape** — if
  `DIRECTUS_TOKEN` turns out to be already dead (most likely, per the
  hypothesis above, since nothing live appears to read it directly), its
  "rotation" is a plaintext-hygiene `.env` overwrite, not a credential
  revocation with a negative-test requirement. The plan does not assume
  this outcome — Phase 0.4 checks empirically — but flags it as the most
  probable branch so the user isn't surprised if step-06's handoff
  reports it that way.
- **Phase 0.6's REST-live-no-restart assumption remains the plan's
  largest unverified premise**, carried over from attempt 1, still
  requiring empirical/documentation confirmation during execution before
  Phase 2 relies on it. If contradicted, the plan already specifies the
  correct branch (UI-assisted, human-operator-required path).
- **Phase 2.7's `api` recreate is now MANDATORY, not conditional** — this
  is a deliberate change from attempt 1's branched framing, based on the
  concrete, documented compose-interpolation finding (not a guess). This
  slightly increases the plan's stated blast radius versus attempt 1's
  framing, which is exactly the kind of thing `NEEDS_APPROVAL` exists to
  surface to the user rather than silently absorb.
- **Output hygiene remains the highest-severity operational risk** given
  T-0136's precedent on this exact host/file/credential family. Every
  command avoids `grep -B/-A` + `-v`-exclusion; uses `-oE` key-only
  capture, HTTP-status/exit-code/count-only verification, or
  identity-field-only (email/role, never token) REST responses
  exclusively; mandates a single continuous SSH session for each
  generate→apply→verify sequence. Any deviation from this plan's exact
  command templates must halt the executor into a return to
  solution-designer rather than an improvised live diagnostic.
- **`landscape/secrets-inventory.md` does not exist in this checkout** —
  step 08 creates first-time entries for these three secret names.
- **Sequencing dependency on T-0136's retry** unchanged from attempt 1:
  T-0136's eventual RBAC-gap retry must happen strictly after this
  rotation completes.

## Open questions (optional)

None blocking approval — the plan itself is the resolution mechanism for
the identity questions raised by step-06's `DIFFERENT_VALUE` finding,
structured as Phase 0 discovery with explicit per-token branches. The one
item that could still stop execution mid-run is Phase 2.2's UI-fallback
branch (if REST-live rotation is not supported by the pinned Directus
version) — called out above as a possible return-to-user point, not a
currently-open question requiring resolution before approval.
