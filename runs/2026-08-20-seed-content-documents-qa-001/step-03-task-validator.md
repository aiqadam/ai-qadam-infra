---
run_id: 2026-08-20-seed-content-documents-qa-001
step: 03
agent: task-validator
verdict: FAIL
created: 2026-08-20T13:45:00Z
task_id: T-0136-seed-content-documents-qa
inputs_read:
  - runs/2026-08-20-seed-content-documents-qa-001/step-01-task-reader.md
  - runs/2026-08-20-seed-content-documents-qa-001/step-02-landscape-reader.md
  - .claude/agents/landscape-reader.md
  - tasks/T-0136-seed-content-documents-qa.md
  - workflows/deploy-app.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Orchestrator should re-invoke landscape-reader as a retry (retry_of step-02) ONLY after either (a) expanding landscape-reader's mandate for this run with an explicit, narrow, user-authorized live-discovery allowance limited to `aiqadam-qa-directus-1`'s port mapping and admin-token file location on pro-data-tech-qa via SSH — overriding its standing "read files only" restriction for this one sub-step — or (b) inserting a distinct scoped discovery action (not full discovery-host.md) that performs the SSH lookup and hands landscape-reader a resolved fact to re-summarize. Do not send landscape-reader back unchanged and expect it to run SSH commands itself; its own agent definition forbids that.
retry_of: null
---

## Summary

Not validated as-is: the task is well-formed, in-scope, not already done, and non-conflicting, but the "discoverable scope" check fails because two facts required for a safe plan (Directus's host port and admin-token location) are absent from every committed landscape file — and `landscape-reader`'s own agent definition explicitly forbids it from running any live command to resolve them ("Do NOT: Run any command against managed hosts. You read files only."), so simply re-running step 02 as written cannot produce a different outcome. This is a `FAIL`, not a `BLOCKED`: the user has already supplied the missing input needed to unblock it (explicit approval for a narrow, scoped live SSH lookup), so the fix is mechanical re-routing, not a further ask to the user.

## Details

### Validation results

1. **Well-formed: PASS** — end state is concrete and verifiable: 5 named rows exist in `content_documents` on QA Directus, confirmed via REST API and via `qa.aiqadam.org/rules` rendering them with correct superseded-labels. Task-reader (step 01) already confirmed this.
2. **In-scope: PASS** — `deploy-app` is a legal, if imperfect, fit per task-reader's step-01 finding: the workflow's own scope note ("Rotating secrets / environment variables for a running deployment") covers this by analogy, and both `workflows/README.md` and `tasks/README.md`'s enum now register `deploy-app` correctly. No dedicated "seed content" workflow exists yet; using the closest match is acceptable and flagged (not blocking) for future consideration.
3. **Not already done: PASS** — landscape and task file agree the seed has never run against QA; `qa.aiqadam.org/rules` currently shows the empty-state message.
4. **No conflict with current state: PASS** — nothing in the landscape contradicts seeding this data; Directus container is confirmed present and healthy.
5. **Discoverable scope: FAIL** — Directus's host port ("not enumerated" per both `landscape/services.md` and `landscape/hosts/pro-data-tech-qa.md`) and its admin-token location (`landscape/secrets-inventory.md` does not exist in this checkout at all) are both unresolved and are not flagged in step 01's scope as "acceptable to leave unresolved" — they are hard requirements for step 04 (solution-designer) to write an executable plan. Per the checklist's own logic ("Any check fails for reasons fixable by re-running step 01 or step 02 → FAIL"), this is fixable by a corrected step 02 — but only if step 02's own constraints change, which requires orchestrator action, not a user ask (see below).
6. **Workflow-specific rules respected: PASS, with a caveat carried forward** — `deploy-app.md`'s "App registration requirement" gates on the *app's setup task* being `status: done` (DNS, nginx vhost, server directories, env file) — that requirement concerns the aiqadam app's QA setup, which is done (the app is live and serving `/rules`), not Directus's own port/token, which is a distinct, narrower data point this task needs. `shared/app-registry.md`'s staleness (documents 2 containers instead of 7, missing Directus, missing a Scripts table) is a real landscape-hygiene problem already flagged by landscape-reader for step 08, but it does not itself block this task's execution path since `landscape/services.md` (the fresher, authoritative source per repo convention) already confirms Directus's existence and health. Not a blocker for this check.

### Why this is FAIL, not BLOCKED

The step-03 verdict logic says: a failed check whose fix requires **user input** → `BLOCKED`; a failed check fixable by **re-running step 01 or step 02** → `FAIL`. Ordinarily, "landscape-reader cannot get live data because it's read-only by design" would be a hard wall requiring a user decision — and step 02 correctly emitted `BLOCKED` for exactly that reason, since at the time it ran, no user authorization for a live lookup existed.

That authorization now exists (per this step's own input): the user has explicitly approved a live discovery lookup against `pro-data-tech-qa` via SSH, explicitly scoped to just the Directus container's port mapping and admin-token file location, and has explicitly rejected running the full `workflows/discovery-host.md` sweep as disproportionate. That is exactly the missing ingredient step 02 lacked. The remaining problem is now purely mechanical: `landscape-reader` (per `.claude/agents/landscape-reader.md`) is permanently scoped to "read landscape/ files only" and has no provision for a scoped exception, even when the orchestrator or user grants one. Re-invoking landscape-reader unchanged, expecting it to suddenly run SSH commands, would violate its own role contract — it would either refuse or (worse) hallucinate values instead of looking them up, which is the one thing task-reader's Notes section and the task file itself explicitly forbid ("Do not put the actual Directus admin token value in this task file or any committed file" — implying real values must come from a real lookup, never invented).

So: this is a **FAIL** at the checklist level (the gap is resolvable without further user input — the user already gave what's needed), but the *mechanism* for step 02's retry cannot be "just run step 02 again." The orchestrator must either:
- (a) treat this single retry as a special, narrowly-scoped exception to landscape-reader's "read only" restriction — explicitly bounded to `docker inspect`/`docker port aiqadam-qa-directus-1` and locating (not printing/exfiltrating) the admin-token's file location in `/opt/apps/aiqadam-qa/deploy/.env`, consistent with what the user actually approved — and pass that scoped authorization into the retry's task framing; or
- (b) insert a minimal, distinct discovery sub-step (not the full `discovery-host.md` workflow — the user explicitly rejected that) that performs the SSH lookup and returns two facts, which landscape-reader then incorporates on re-run.

Either path is an orchestrator decision, not something this step can resolve unilaterally by re-emitting the same instructions to landscape-reader. That's why this handoff routes back with `retry_of: null` at *this* step (task-validator itself isn't retrying) but a `next_step_hint` directing the orchestrator to retry step 02 under expanded, explicit terms.

## Issues / risks

- **Do not let the retried landscape-reader (or any downstream step) invent a plausible-looking port or token.** The task file and repo convention are explicit that secret values never enter committed files; a live lookup is the only legitimate source. If the SSH lookup itself fails or is refused, the correct outcome is `BLOCKED`, not a guessed value.
- The token must not be written into the step-02 (or any) handoff file in the clear — handoffs are typically committed/reviewable artifacts. The retried landscape-reader should record *where* the token lives (e.g., "present in `/opt/apps/aiqadam-qa/deploy/.env` as `DIRECTUS_ADMIN_TOKEN`") and the resolved port/URL, but not paste the token value itself into `runs/`.
- `shared/app-registry.md`'s staleness (flagged by step 02) remains an open, non-blocking hygiene issue for step 08 to address — carried forward, not re-litigated here.
- Once re-run, step 02's retry should re-verify check 5 specifically; the other four checks in this validation are stable and do not need re-derivation unless the retry surfaces a new conflict.

## Open questions (optional)

None from this step — the routing decision is now the orchestrator's to make (choice of mechanism (a) vs (b) above), not a further question back to the user, since the user's prior approval already covers the substance of what's needed.
</content>
