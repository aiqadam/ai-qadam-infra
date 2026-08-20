---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 06
agent: executor-cicd
verdict: BLOCKED
created: 2026-08-20T16:05:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/step-04-solution-designer.md
  - runs/2026-08-20-seed-content-documents-qa-001/.attempts/step-06-executor-cicd-attempt-1.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/app-registry.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: >-
  Phase 0 RBAC diagnosis surfaced a finding one layer deeper than the plan's
  Case A/Case B split anticipated: the admin role's single attached policy is
  itself unreadable (403) by this same admin token, so admin_access could not
  be confirmed true OR false. Per the plan's explicit instruction (0.3 Case A
  branch and the rollback/verification section), this is treated as an
  escalation, not a guess — no permission grant was attempted. This needs its
  own scoped investigation task (likely involving direct DB inspection of
  directus_policies / directus_permissions, since the REST API itself cannot
  see the policy row from this identity) before any further seed-script retry
  is worthwhile. Recommend the next task investigate via `docker exec
  aiqadam-qa-directus-1` + direct Postgres query against the Directus system
  schema, rather than another REST-API-only diagnosis pass, since REST is
  exactly the layer that's failing.
retry_of: step-06
---

## Summary

Phase 0 diagnosis (read-only) found that the QA Directus admin user's role
("Administrator", `b3350300-c590-430f-b4ea-c020638bc2d1`) has exactly one
attached policy (`5029fc70-bcec-4dc6-a549-ab42b5ac5377`), but **that policy
cannot be read via the REST API using this same admin token** — `GET
/policies/<id>` returns `403 FORBIDDEN`, and a filtered list query for that
exact id returns an empty array. This means `role.admin_access` (the plan's
explicitly load-bearing check, step 0.2) could not be confirmed as either
`true` or `false` — the value is not merely absent/null on a readable object,
the object itself is inaccessible to the identity that's supposedly
Administrator. A token that is genuinely the bypass-all Administrator cannot
be forbidden from reading its own policy; this is not explained by a missing
collection-level grant (Case B) and does not cleanly fit Case A's "admin_access
confirmed true, still 403'd" framing either — it is a third, worse variant:
the diagnosis needed to distinguish Case A from Case B is itself blocked by
the same permission wall. Per the plan's explicit instruction for exactly this
kind of ambiguity, execution **stops here**. No permission grant was created,
no Phase 1.3 git-state check or Phase 2 seed write was attempted. Zero state
changed on the host.

## Details

### Pre-execution checks
- Approval handoff verified: yes (step-04 `verdict: PASS`, auto-approved, no step-05 file present, consistent with `next_step_hint`).
- Approval verdict: PASS (auto-approved).
- Local aiqadam repo state: clean, `git status --short` empty; local HEAD `6e67229eda0a5be91d7697833cc256e89de0426f` == `origin/main` HEAD (identical) — no commit/push needed before proceeding to the host.

### Pre-execution state (for rollback)
| Service | Previous version | Notes |
|---|---|---|
| `aiqadam-qa-directus-1` | unchanged | No container recreated, no image change, no compose change. Only read-only REST calls were made in this attempt (plus one repeat of the same empty-body diagnostic POST attempt 1 already used, which itself writes nothing on 403). |
| `content_documents` collection | 0 rows created by this run | Phase 2 (seed script) was never invoked — execution stopped in Phase 0. |
| `directus_permissions` table | unchanged, 0 new rows | Phase 0.4 (the narrow permission grant) was never reached — diagnosis did not resolve to Case B. |

### Execution log

#### Phase 0.1: confirm admin token variable name present (value never printed)
- Command: `ssh pro-data-tech-qa "grep -oE '^DIRECTUS_ADMIN_TOKEN=' /opt/apps/aiqadam-qa/deploy/.env"`
- Exit code: 0
- Output: `DIRECTUS_ADMIN_TOKEN=` — exactly one match, matching the plan's verification criterion exactly (attempt 1's ambiguity between `DIRECTUS_TOKEN`/`DIRECTUS_ADMIN_TOKEN` does not recur here because this plan's step 0.1 greps only the canonical name).

#### Phase 1.1 (run early, needed as a dependency for Phase 0.2's URL): resolve Directus host port
- Command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-directus-1 printenv PORT"`
- Exit code: 0, output: `3119` — re-derived live, matches attempt 1's value coincidentally (not assumed or reused).

#### Phase 1.2: confirm port listening on loopback
- Command: `ssh pro-data-tech-qa "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3119/server/ping"`
- Exit code: 0, output: `200`. Passed.

#### Phase 0.2: resolve admin user identity and role (read-only) — THE LOAD-BEARING CHECK
- Command (token substituted inline, never echoed): `ssh pro-data-tech-qa "cd /opt/apps/aiqadam-qa && TOK=\$(grep '^DIRECTUS_ADMIN_TOKEN=' deploy/.env | cut -d= -f2-) && curl -s -H \"Authorization: Bearer \$TOK\" 'http://127.0.0.1:3119/users/me?fields=id,email,role.id,role.name,role.admin_access,role.app_access'"`
- Output: `{"data":{"id":"7f8b96c6-e4e1-4ba0-9df4-12c7ef8ba90c"}}` — only `id` returned; the requested `email` and dotted `role.*` deep-fetch fields were silently omitted rather than erroring.
- Follow-up isolation (still read-only, same token): `fields=*` → full user object, `email: "admin@aiqadam.org"`, `role: "b3350300-c590-430f-b4ea-c020638bc2d1"` (plain UUID string, not expanded), **`"policies": []`** on the user object itself.
- Follow-up: `fields=email` alone → resolves fine. `fields=role` alone → resolves to the bare UUID, not an expanded object. So the dotted `role.id,role.name,role.admin_access,role.app_access` deep-fetch syntax specifically fails to expand for this token — this is itself an anomaly (a genuine Administrator token's deep-fetches are not normally restricted), though not yet the core finding.

#### Direct role lookup: `GET /roles/b3350300-c590-430f-b4ea-c020638bc2d1`
- Output: role name `"Administrator"`, `children: []`, `users: ["7f8b96c6-e4e1-4ba0-9df4-12c7ef8ba90c"]` (confirms this is indeed the admin user's role), and **`"policies": ["5029fc70-bcec-4dc6-a549-ab42b5ac5377"]`** — one policy IS attached at the role level, contradicting the `/users/me?fields=*` response's `"policies": []`. (Both are read with the same token in the same session; the discrepancy is between two different endpoints' representations, not a token-identity change.)

#### Direct policy lookup: `GET /policies/5029fc70-bcec-4dc6-a549-ab42b5ac5377` — THE BLOCKING FINDING
- Command: `curl -s -w '\nHTTP_STATUS:%{http_code}\n' -H "Authorization: Bearer $TOK" 'http://127.0.0.1:3119/policies/5029fc70-bcec-4dc6-a549-ab42b5ac5377'`
- Output: `{"errors":[{"message":"You don't have permission to access this.","extensions":{"code":"FORBIDDEN"}}]}`, `HTTP_STATUS:403`.
- Cross-check via filtered list (same token): `GET /policies?filter[id][_eq]=5029fc70-bcec-4dc6-a549-ab42b5ac5377` → `[]` (empty array — the policy is not merely field-restricted, it's invisible to this identity even in a list query).
- **This is the blocking finding.** The one policy attached to the admin user's own role cannot be read by that same user's own token. Directus's documented model gates all bypass-all behavior on the policy's `admin_access` boolean — with the policy itself unreadable, that boolean cannot be confirmed `true` or `false` via REST, by this identity, at all.

#### Confirmation that the original symptom is unchanged with the fresh (rotated) token
- Command: `curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' http://127.0.0.1:3119/items/content_documents -d '{}'`
- Output: `403` — confirms this is not a stale-token artifact from attempt 1; the newly-rotated `DIRECTUS_ADMIN_TOKEN` reproduces the same 403 on `content_documents` create.

**Phases 0.3/0.4/0.5, all of Phase 1.3, and all of Phase 2 were NOT executed.** The plan's 0.3 classification step requires a confirmed `admin_access` boolean to choose between Case A (stop) and Case B (narrow grant, then proceed). That boolean was never obtainable. Per the plan's own framing — Case A itself being "not a simple missing-grant problem; something else is wrong" and its explicit instruction "STOP. Do not attempt any permission-grant fix" — proceeding to 0.4 without a confirmed Case B would mean granting a permission based on a guess, which both this run's task instructions and the plan explicitly forbid.

### Health check
Not applicable — no deploy, no container touched, no state-changing step reached.

### Rollback executed
Not needed. No permission was granted, no row was written, no file or container was touched. The only actions taken this run were `GET`/read-only `POST -d '{}'` probes (all non-mutating on 403) and one previously-used empty-body POST probe pattern, identical to attempt 1's own diagnostic pattern.

## Issues / risks

- **Blocking: admin role's attached policy is unreadable by the admin token itself.** This is a deeper anomaly than either of the plan's two anticipated cases. Two non-exclusive hypotheses, neither confirmed here (both require DB-level inspection the REST API cannot provide from this identity):
  1. The policy row `5029fc70-bcec-4dc6-a549-ab42b5ac5377` may not actually exist in `directus_policies` (the role's `policies` array references an id that was deleted or never created correctly), in which case the role effectively has **zero** working policies attached despite the array listing one — which would mean `admin_access` resolves to `false`/absent by default, structurally explaining every 403 seen across both attempts without any code-level bug.
  2. The policy exists but has its own restrictive `permissions`/`admin_access: false` configuration that (paradoxically) does not grant `/policies` self-read — Directus's `admin_access` is supposed to be all-or-nothing bypass, so a policy that both exists and is attached to Administrator but denies reading itself would be a genuine product-level inconsistency worth flagging to Directus support/docs if confirmed.
  Both are plausible from what was observed; distinguishing them needs direct Postgres access to the Directus system schema (`directus_policies`, `directus_access` join table), not another REST attempt — REST is exactly the layer that's opaque here.
- **The `/users/me?fields=*` vs `/roles/<id>` discrepancy** (`policies: []` on one endpoint, `policies: [<one id>]` on the other, same token, same session) is itself worth the next investigator's attention — it may be an unrelated Directus caching/serialization quirk, or it may be a second symptom of the same underlying inconsistency. Recorded verbatim above rather than reconciled/guessed at.
- **No permission-grant fix was attempted, per explicit task instruction and the plan's Case A branch.** This is the correct, safe outcome for an unresolved diagnosis — not a shortfall in this execution.
- **Secret hygiene:** token value was never printed, echoed, or written to any file this run; all substitutions were inline within a single SSH session per the plan's established pattern. No repeat of attempt 1's `grep -B/-A` exposure incident — this run used only the plan's prescribed `-oE` pattern and inline `$(...)` substitution throughout.
- No destructive action occurred. Blast radius realized is zero.

## Open questions (optional)

- Should a new, narrowly-scoped investigation task be filed to inspect `directus_policies`/`directus_access` directly via `docker exec ... psql` (or Directus's own DB) to determine whether policy `5029fc70-bcec-4dc6-a549-ab42b5ac5377` exists at all, and if so, what its `admin_access` value actually is? This blocks any further retry of T-0136's seed step.
- Is it possible the QA Directus instance's admin identity was left in an inconsistent state by an earlier operation (e.g., partway through a role/policy migration when Directus 9→11's role-policy separation was introduced on this instance, or an artifact of T-0137's token-rotation `PATCH /users/me` call)? T-0137's own handoff (`runs/2026-08-20-rotate-qa-directus-token-001/step-06-executor-infra.md`) should be checked for whether it touched roles/policies at all, or only the user's token/password fields — worth the next investigator ruling out explicitly rather than assumed.
- Should Directus's own container logs (`docker logs aiqadam-qa-directus-1`) be checked for a server-side error at the moment of the `/policies/<id>` 403 — REST returned a clean `FORBIDDEN` envelope, but a DB-level foreign-key or migration inconsistency might log something more diagnostic server-side that never surfaces in the API response.
