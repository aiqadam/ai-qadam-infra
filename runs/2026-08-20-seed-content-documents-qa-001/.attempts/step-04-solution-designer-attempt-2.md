---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-08-20T15:10:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-cicd-attempt-1.md
  - tasks/T-0136-seed-content-documents-qa.md
  - runs/2026-08-20-rotate-qa-directus-token-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-qa.md
  - .claude/agents/solution-designer.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - infrastructure/directus/bootstrap.sh (aiqadam repo — grepped for "content_documents")
artifacts_changed: []
next_step_hint: >-
  Verdict PASS — orchestrator skips step 05, advances directly to executor-cicd
  (step 06). New Phase 0 (RBAC diagnosis) runs FIRST, before any Phase 1/2 step
  from attempt 1. Executor MUST re-read DIRECTUS_ADMIN_TOKEN fresh from
  /opt/apps/aiqadam-qa/deploy/.env at execution time — do not reuse any token
  value, port number, or command output text from attempt 1's handoffs; only
  the *shape* of attempt 1's Phase 1/2/3 steps is reusable, re-verified live.
  If Phase 0's diagnosis finds the admin user's role is NOT the true
  bypass-all Administrator (i.e., a custom role masquerading as admin), STOP
  and emit BLOCKED — that finding is a bigger question than this task and
  needs its own scoped task/plan, not a same-run patch.
retry_of: step-04
---

## Summary

Three-phase plan on `pro-data-tech-qa`: a new **Phase 0** performs read-only RBAC diagnosis (confirm whether the QA Directus admin user's role is the built-in bypass-all Administrator or a custom role missing an explicit grant) and, only in the narrow "custom role missing a grant" case, adds one narrowly-scoped permission (`content_documents` create+read+update for that specific role/policy) via Directus REST; **Phase 1** (unchanged in shape from attempt 1) re-discovers port/checkout state live rather than trusting attempt 1's values; **Phase 2** runs the seed script and verifies all 5 rows, `/rules`, and superseded labels, exactly as attempt 1 designed.

## Details

### Why attempt 1 failed and what changed since

Attempt 1's Phase 2 hit HTTP 403 on the very first item: `DIRECTUS_TOKEN` (and identically-valued `DIRECTUS_ADMIN_TOKEN`) authenticates (`/users/me` → 200) but the associated role has no create permission on `content_documents`. Grepping `infrastructure/directus/bootstrap.sh` (aiqadam repo) confirms why this is plausible, not a fluke: the script's only permission grant touching `content_documents` is a **Public-policy read-only** grant scoped to `status = published` (lines 5798–5800, under the `[FR-CMS-007 — public read: content_pages, content_documents]` section). There is no explicit Administrator/admin-role grant anywhere in the script for either new collection — the script's design implicitly assumes Directus's built-in Administrator role/policy bypasses all collection-level permission checks (the normal, documented Directus behavior). If the QA admin user's role is genuinely that built-in bypass-all Administrator, the 403 is unexplained by anything in `bootstrap.sh` and points to a deeper misconfiguration. If it is a *different*, custom role that merely looks like admin (e.g., was never actually attached to the Administrator policy, or Directus's admin_access flag is unset on it), the 403 is fully explained and fixable with one narrow grant.

Since attempt 1, `T-0137` (run `2026-08-20-rotate-qa-directus-token-001`) rotated the admin token after a self-reported transcript-exposure incident during attempt 1's diagnosis. The new `DIRECTUS_ADMIN_TOKEN` is confirmed live, resolves to `admin@aiqadam.org`, role UUID `b3350300-c590-430f-b4ea-c020638bc2d1` (per that run's step-06 handoff, Phase 0.3/0.4 identity checks). **This plan treats that role UUID as a lead to confirm live, not as a substitute for live discovery** — Phase 0 below re-derives it independently via the freshly-read token, and the executor must not paste the UUID string above into any command; it must come from this run's own `/users/me` call.

### Plan

**Phase 0 — RBAC diagnosis (read-only) then narrow fix (state-changing only if needed)**

0.1. **Re-read the admin token fresh from `.env` (do not reuse any attempt-1 value)** — command: `ssh pro-data-tech-qa "grep -oE '^DIRECTUS_ADMIN_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env"` — verification: exactly one match. This confirms the variable name only (never the value) is present; the value itself is fetched inline in each subsequent command via `$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-)` inside a single SSH session, never echoed to a handoff, exactly as attempt 1's step 3/4 pattern (which remains correct and must be followed verbatim — only the resulting value differs post-rotation).

0.2. **Resolve the admin user's identity and role UUID (read-only)** — command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && TOK=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) && curl -s -H \"Authorization: Bearer \$TOK\" http://127.0.0.1:<resolved-port>/users/me?fields=id,email,role.id,role.name,role.admin_access,role.app_access | jq '.data'"` — verification: HTTP 200, JSON body containing `email`, `role.id`, `role.name`, and critically `role.admin_access` (boolean). **This is the load-bearing check.** Directus's actual bypass-all behavior is gated by the role's `admin_access` boolean (Directus 9+ policy/role model), not by the role's display name — a role can be named "Administrator" and still have `admin_access: false`, or vice versa. Do not infer bypass status from the name string alone.

0.3. **Classify the finding:**
   - **Case A — `role.admin_access == true`:** the user's role is the genuine bypass-all admin role. Directus's own documented behavior is that such a role bypasses ALL collection-permission checks unconditionally — a 403 should be structurally impossible for this identity. If Phase 0.2 shows `admin_access: true` and the seed script nonetheless got 403 in attempt 1, this is **not** a simple missing-grant problem; something else is wrong (e.g., a Directus bug, a stale/cached policy, the token resolving to a *different* role than expected at request time, collection-level `_and`/field-preset weirdness). **STOP. Do not attempt any permission-grant fix. Emit `BLOCKED`** with this finding — it needs its own investigation task, not a patch grafted onto a content-seed run. This is exactly the scenario the task's own "What done looks like" checklist flagged as the more significant, non-assumed possibility.
   - **Case B — `role.admin_access == false` (or the field is absent/null, treated the same as false):** the role is a custom role that requires an explicit collection-level grant, matching `bootstrap.sh`'s observed gap exactly (no admin grant was ever created for `content_documents`, only the public-read one). Proceed to 0.4.

0.4. **(Case B only) Add one narrowly-scoped permission for this role — REST, no blanket grant.** First, read-only, list this role's *existing* permissions to confirm none already covers `content_documents` under a different filter (defensive — do not create a duplicate): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && TOK=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) && ROLE_ID=\$(curl -s -H \"Authorization: Bearer \$TOK\" http://127.0.0.1:<port>/users/me?fields=role.id | jq -r '.data.role.id') && curl -s -H \"Authorization: Bearer \$TOK\" \"http://127.0.0.1:<port>/permissions?filter%5Brole%5D%5B_eq%5D=\$ROLE_ID&filter%5Bcollection%5D%5B_eq%5D=content_documents\" | jq '.data'"` — verification: empty array (`[]`) confirms no pre-existing rule to conflict with.

   Then create the grant, scoped to exactly this role and this collection, actions `create` + `read` + `update` (NOT `delete` — the task never deletes rows, and the seed script only creates/updates by slug; omitting delete keeps the grant as narrow as the actual need): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && TOK=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) && ROLE_ID=\$(curl -s -H \"Authorization: Bearer \$TOK\" http://127.0.0.1:<port>/users/me?fields=role.id | jq -r '.data.role.id') && for ACTION in create read update; do curl -s -X POST -H \"Authorization: Bearer \$TOK\" -H 'Content-Type: application/json' http://127.0.0.1:<port>/permissions -d \"{\\\"role\\\":\\\"\$ROLE_ID\\\",\\\"collection\\\":\\\"content_documents\\\",\\\"action\\\":\\\"\$ACTION\\\",\\\"permissions\\\":{},\\\"validation\\\":{},\\\"fields\\\":[\\\"*\\\"]}\" | jq -c '{action: .data.action, id: .data.id}'; done"` — verification: three HTTP 200 responses, each returning a new permission `id` and matching `action` (`create`, `read`, `update`). Executor records the three returned permission `id`s in its handoff (these are the rollback target, see below) — this is metadata, not a secret, safe to record verbatim.

   **This is a role-scoped, collection-scoped, action-scoped grant** — not a blanket "give this role full admin" change, not a change to any other collection, not a change to any other role, not a change to the Public policy's existing read grant (untouched). It is exactly the kind of narrow, additive, fully-reversible-by-deleting-three-rows change the task input asked this design to constrain itself to.

0.5. **Verify the grant closes the gap (read-only smoke test, zero side effects)** — command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && TOK=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) && curl -s -o /dev/null -w '%{http_code}\n' -X POST -H \"Authorization: Bearer \$TOK\" -H 'Content-Type: application/json' http://127.0.0.1:<port>/items/content_documents -d '{}'"` — verification: response is **no longer 403**. An empty-body POST against a collection with fields defined will typically return `400` (validation error on required fields) once permission is granted, not `403` (permission denied) — the transition from 403→400 (or 403→200 if `{}` happens to satisfy required-field defaults) is the signal that the grant worked, not a specific status code. If still 403 after the grant, STOP — do not retry the grant a second time with broader scope; emit `BLOCKED`, since a second 403 after a correctly-applied narrow grant means the diagnosis (0.2/0.3) was incomplete, not that more permissions are needed.

**Phase 1 — Discovery (read-only, no host state change) — re-verified live, not reused from attempt 1**

1.1. **Resolve Directus's host port mapping** — command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-directus-1 printenv PORT"` — verification: non-empty numeric value. (Attempt 1 found `3119` via this exact path; re-run it live rather than hardcoding `3119` into any command — record whatever this run's live output is.)

1.2. **Confirm the resolved port is listening on loopback** — command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<resolved-port>/server/ping"` — verification: `200`.

1.3. **Confirm on-host checkout state and target commit** — command: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git fetch origin && git log --oneline -1 && git merge-base --is-ancestor 627cd91 HEAD && echo AT_OR_PAST_TARGET || echo BEHIND_TARGET"` — verification: `AT_OR_PAST_TARGET` expected (attempt 1 confirmed the checkout was already at `6e67229`, past target, and nothing on this host moves the checkout backward — but re-verify live rather than assume no drift occurred since). If `BEHIND_TARGET`: `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git checkout main && git pull origin main"`, then re-check `test -f infrastructure/directus/seed-content-documents.sh && echo SCRIPT_PRESENT`.

**Phase 2 — Seed operation (state-changing; writes 5 Directus rows via REST API)**

2.1. **Run the seed script** — command (single SSH session, token fetched fresh, never written to disk or logged as a literal value): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && DIRECTUS_URL=http://127.0.0.1:<resolved-port> DIRECTUS_TOKEN=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) bash infrastructure/directus/seed-content-documents.sh"` — verification: exit code 0, stdout shows 5 upserts (`manifesto`, `charter-v0-1`, `kazakhstan-mou`, `global-board-polozhenie-v1`, `soglashenie-v1`). Executor redacts the literal token substitution in its handoff (`DIRECTUS_TOKEN=<redacted>`), per attempt 1's established discipline — do not deviate to a bare `grep VARNAME .env` without `-oE`/inline substitution anywhere a value could leak into a log.

2.2. **On-host confirmation via REST API** — command: `ssh pro-data-tech-qa "curl -s http://127.0.0.1:<resolved-port>/items/content_documents?fields=slug"` — verification: exactly the 5 expected slugs present.

2.3. **External verification — public page** — command: `curl -s https://qa.aiqadam.org/rules` — verification: no longer contains "Пока нет опубликованных документов.", contains all 5 document titles/slugs.

2.4. **External verification — individual document page** — command: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/rules/charter-v0-1` — verification: `200`.

2.5. **Superseded-label spot check** — command: `curl -s https://qa.aiqadam.org/rules/global-board-polozhenie-v1` and `curl -s https://qa.aiqadam.org/rules/soglashenie-v1` — verification: both contain "Superseded by Charter v0.1"; `curl -s https://qa.aiqadam.org/rules/manifesto` must NOT contain that label.

### Rollback

1. **Phase 0.4's permission grant (only if it was created — Case B path):** `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && TOK=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) && for ID in <perm-id-create> <perm-id-read> <perm-id-update>; do curl -s -X DELETE -H \"Authorization: Bearer \$TOK\" http://127.0.0.1:<port>/permissions/\$ID; done"` — deletes exactly the three rows created in 0.4, using their recorded ids. Fully reversible, no other permission touched.
2. **Phase 1's `git pull` (only if it ran, i.e. `BEHIND_TARGET` case):** `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && git checkout <pre-pull-SHA-recorded-in-1.3's-output>"`.
3. **The 5 seeded rows themselves:** not rolled back by this plan (same asymmetry attempt 1 flagged — adding is pre-approved via idempotent upsert-by-slug; removing is a distinct, separately-scoped, not-pre-authorized action requiring its own approval pass if ever needed).

### Verification (for step 07)

- **On-host:**
  - Phase 0.2's `role.admin_access` value recorded verbatim (true/false) — this is the diagnostic finding step 07 should double-check independently if possible (re-run 0.2's `curl` read-only).
  - If Case B: Phase 0.5's 403→non-403 transition on the empty-body POST probe.
  - Phase 1.2's `/server/ping` → `pong`/200.
  - Phase 1.3's `AT_OR_PAST_TARGET` and `SCRIPT_PRESENT`.
  - Phase 2.1's seed script exit code 0 and 5-upsert stdout.
  - Phase 2.2's on-host REST listing → exactly the 5 expected slugs.
- **External:**
  - `GET https://qa.aiqadam.org/rules` → 200, all 5 titles present, empty-state string gone.
  - `GET https://qa.aiqadam.org/rules/charter-v0-1` → 200.
  - `.../rules/global-board-polozhenie-v1` and `.../rules/soglashenie-v1` → both show "Superseded by Charter v0.1"; the other 3 slugs do not.

### Resources used

- **Secrets (by name):** `DIRECTUS_ADMIN_TOKEN` (per `landscape/secrets-inventory.md`, created by T-0137's step 08 — the rotated, current value; executor must read it fresh from `/opt/apps/aiqadam-qa/deploy/.env` at execution time, never from any prior run's handoff text). `DIRECTUS_TOKEN` is a synced-copy of the same value per T-0137's finding but this plan standardizes on `DIRECTUS_ADMIN_TOKEN` as the canonical name throughout, matching the landscape file's own post-rotation framing.
- **Files modified on host:** none in Phase 1 (no-op case expected). In Phase 0, Case B only: 3 new rows in Directus's internal `directus_permissions` table (via REST, not a file). No `.env` file, no compose file, no application file is touched anywhere in this plan.
- **Files modified in this repo (`landscape/`), to be applied at step 08:**
  - `tasks/T-0136-seed-content-documents-qa.md` — check off all "What done looks like" items, including the new RBAC checklist item, with the Phase 0 finding (Case A or B, and if B, the 3 permission ids) recorded.
  - `landscape/hosts/pro-data-tech-qa.md` Change log — new entry for this run recording the RBAC diagnosis outcome and, if Case B, the exact grant added (role UUID, collection, actions — no values).
  - `landscape/services.md` — mirror the resolved Directus port if not already current from T-0137/prior runs.
- **External APIs called:** QA Directus REST API only, all host-local (`http://127.0.0.1:<port>/...`, called from within the SSH session), plus the public `qa.aiqadam.org/rules*` read-only GETs for verification.

### Estimated impact

- **Downtime:** none. No container is restarted or recreated anywhere in this plan (Phase 0's REST permission grant and Phase 2's REST content writes are both live, non-restart-requiring operations, consistent with T-0137's confirmed Directus 11.17.4 behavior that permission/DB-row changes are read live).
- **Affected services:** `aiqadam-qa-directus-1`'s data only — either its `directus_permissions` table (Case B, 3 new rows, additive) and/or its `content_documents` table (5 new/updated rows). No container process, no other collection, no other role, no other policy is touched.
- **Reversibility:** fully reversible. The permission grant (if created) is deleted by its 3 recorded ids; the seed script is idempotent-by-design; the git pull (if it occurs) is a fast-forward with the pre-pull SHA recorded.

## Issues / risks

- **Case A (role.admin_access == true but still got 403) escalates to BLOCKED, not a patched-around fix.** This is the single most important branch in this plan. If diagnosis shows the admin role genuinely has bypass-all rights and a 403 still occurred, granting a narrow permission would likely have no effect (a true bypass-all role doesn't consult collection-level grants at all) and papering over it risks masking a real Directus-level or session-level bug. The task input explicitly asked for this framing ("flag this as a more significant finding requiring the user's attention rather than just patching around it") — Phase 0.3's Case A branch implements exactly that instruction.
- **Whether Phase 0.4 (the permission-grant sub-step) itself needs `NEEDS_APPROVAL` was explicitly considered.** `shared/approval-protocol.md`'s "Always requires NEEDS_APPROVAL" list names prod deployments, DNS/firewall changes, **secret rotations or credential changes**, package installs, and destructive operations — RBAC/permission grants are not literally named, and this grant is neither a secret rotation nor a credential change (no token, password, or user identity changes; only an access-control row is added). It is additive, narrowly scoped to one role/one collection/three actions, trivially reversible by deleting the 3 created rows, and does not touch any other identity's access. Weighed against the task file's `estimated_blast_radius: low` / `estimated_reversibility: full` (unchanged from the original task), I judge this **does not** cross into `NEEDS_APPROVAL` territory — it is closer in kind to "landscape/read-write to system config that only affects this one already-in-scope collection" than to a credential/secret change. **This is a judgment call, flagged explicitly per my role's instruction to call out anything uncertain rather than silently deciding.** If the user disagrees with this framing when reviewing this handoff, the safe correction is to have the orchestrator halt before Phase 0.4 specifically (Phase 0.1–0.3 diagnosis is unambiguously read-only and fine to run either way).
- **Directus role/policy model nuance.** Directus 9+ separates "roles" from "policies" (a role can have zero or more attached policies, and `admin_access`/`app_access` can live on either depending on version). Phase 0.2's query reads `role.admin_access` directly, which is correct for Directus 11.x's role-embedded-policy default configuration (confirmed 11.17.4 by T-0137), but if this host's admin role's `admin_access` flag actually lives on an attached policy rather than the role object itself, 0.2's query may read `null`/absent rather than a definitive `true`/`false`. The plan treats `null`/absent the same as `false` (Case B) per 0.3's explicit instruction — this is a reasonable default (a role that doesn't clearly assert bypass-all should not be assumed to have it) but the executor should note in its handoff if the field came back null/absent rather than a clean boolean, since that's itself informative for whoever reviews the Case A/B classification later.
- **Idempotency of Phase 0.4:** the pre-check in 0.4 (list existing permissions for this role+collection) guards against creating a duplicate grant if this plan is ever re-run after a partial failure — but Directus's `/permissions` endpoint does not itself enforce uniqueness per role+collection+action, so a second run without checking first could create duplicate (harmless but messy) rows. The pre-check step exists specifically to prevent that; executor must not skip it.
- No item above is high-severity in the sense of touching DNS, firewall, OS packages, or an irreversible action — the plan's most consequential branch (Case A) is designed to stop and escalate rather than act, which is the safe default for the genuinely uncertain scenario.

## Open questions (optional)

None — verdict is `PASS`, not `BLOCKED`. All five `shared/approval-protocol.md` PASS conditions are met against the task's unchanged `estimated_blast_radius: low` / `estimated_reversibility: full`: (1)/(2) task frontmatter values confirmed unchanged from attempt 1; (3) no irreversible step — Phase 0.4's grant and Phase 2's seed are both additive/reversible, data-deletion is out of scope as before; (4) no designer doubts remain — the one genuine unknown (which RBAC case applies) is resolved by live diagnosis before any write, with an explicit escalate-to-BLOCKED branch for the case that would otherwise require guessing; (5) no Issues/risks item is high-severity — the approval-boundary judgment call is flagged transparently but assessed as within PASS scope, consistent with the task's own declared blast radius and the narrow, additive, single-collection nature of the one new state-changing action this retry adds.
