---
run_id: 2026-08-21-expose-qa-directus-vhost-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-08-21T02:51:27Z
task_id: T-0142-expose-qa-directus-vhost
inputs_read:
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-01-task-reader.md
  - runs/2026-08-21-expose-qa-directus-vhost-001/step-02-landscape-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - shared/approval-protocol.md
  - tasks/T-0125-fix-authentik-admin-url-on-qa.md
  - tasks/T-0132-upstream-qa-authentik-admin-url-into-repo.md
artifacts_changed: []
next_step_hint: solution-designer must plan the companion aiqadam-platform PR for deploy/nginx/qa.aiqadam.org.conf as an explicit, in-scope phase of this run (not an optional follow-up), and must emit verdict NEEDS_APPROVAL — auto-approval is structurally unavailable for this task.
---

## Summary
T-0142 validates cleanly on all six checklist items (well-formed, in-scope, not already done, no conflict with current state, discoverable scope, workflow rules satisfiable) and is cleared to proceed to solution-designer; the one structural point requiring explicit resolution — whether the tracked-file (`deploy/nginx/qa.aiqadam.org.conf` in `aiqadam/ai-qadam-platform`) update should be a required, explicit phase of this run rather than an optional follow-up — is resolved here as **(a): require it as an explicit phase, not an optional follow-up**, given this repo's own T-0125/T-0132 history shows that exact "optional follow-up" pattern producing a real, still-open landmine three weeks later; and the solution-designer's auto-approval eligibility is confirmed **structurally locked to `NEEDS_APPROVAL`** per `shared/approval-protocol.md`'s explicit, unconditional listing of DNS changes and nginx changes on a shared host, independent of how narrow the actual diff turns out to be.

## Details
### Validation results
1. Well-formed: PASS — the task names a concrete, externally-verifiable end state: `https://cms.qa.aiqadam.org/server/ping` → `200`/`pong` with valid TLS, `PUBLIC_DIRECTUS_URL` set and picked up by a recreated `web-next` container, and `qa.aiqadam.org`/`auth.qa.aiqadam.org` confirmed unaffected. Not a vague intent.
2. In-scope: PASS — DNS record creation, nginx vhost addition, certbot `--expand`, and env-var wiring are all squarely within the `infrastructure` workflow's declared scope (nginx config changes, Cloudflare DNS, TLS certificate operations, per `workflows/infrastructure.md` "When this workflow applies").
3. Not already done: PASS — landscape-reader's step-02 confirms no `cms.qa.aiqadam.org` DNS record, no matching nginx server block, and no cert SAN entry exist anywhere in `landscape/cloudflare.md`, `landscape/domains.md`, or `landscape/hosts/pro-data-tech-qa.md`. Directus remains loopback-only (`127.0.0.1:3119` per task assertion, pending live re-verification) with no public path.
4. No conflict with current state: PASS — the task does not contradict any explicit landscape fact. It extends the same shared nginx file and shared Cloudflare zone that already host two other project-owned hostnames on this host, using the identical pattern already proven safe for `auth.qa.aiqadam.org`. No landscape fact says "do not expose Directus" or similar.
5. Discoverable scope: PASS — the two open unknowns (Directus's current port, the live nginx file's exact current contents/cert-lineage name) are both explicitly called out by the task itself as "re-verify live, don't assume," and landscape-reader's step-02 confirms these are narrow, live-discoverable pre-flight checks, not unresolvable unknowns. No critical unknown blocks a safe design from being drafted (with pre-flight verification steps built in).
6. Workflow-specific rules respected: PASS, contingent on the structural point below. `workflows/infrastructure.md`'s idempotency and backup-before-destructive-changes rules are straightforwardly satisfiable (nginx config is additive — a new server-block pair — and a config backup before edit is trivial; DNS record creation is additive and uniquely-named per the zone's own established "no collision" reasoning; certbot `--expand` is designed to be idempotent/additive by Let's Encrypt's own tooling contract). The "verify in two places" rule (host-side + externally-observable) is explicitly built into the task's own acceptance criteria (`nginx -t` + live HTTPS probe). The one rule this check had to specifically interrogate — whether the task can satisfy this repo's own established discipline around tracked-file drift (see below) — resolves PASS once the companion-PR requirement is made explicit and mandatory in the design, which this validator is directing step 04 to do.

### The structural question: (a) companion app-repo PR as an explicit phase, vs (b) host edit + follow-up task

This task is unusual among the six checklist items in that it names, in its own body, a specific historical failure mode (T-0125/T-0132) and asks the executing agent not to repeat it — that is itself worth taking at face value rather than treating as boilerplate.

**Recommendation: (a).** The companion PR against `aiqadam/ai-qadam-platform` for `deploy/nginx/qa.aiqadam.org.conf` must be planned as an explicit, named phase of this task's execution — not left as an optional, separately-filed follow-up task the way T-0132 currently sits.

Reasoning:

- **T-0132 is the load-bearing precedent, and it is unresolved.** T-0125 (closed 2026-07-29, `outcome: succeeded`) made exactly the "(b)" choice this task is asking us to reconsider: it edited the host's tracked `docker-compose.qa.yml` directly, closed the task as `done` with the drift risk explicitly named in its own Result section, and spun off T-0132 to upstream the fix "later." T-0132 was filed the same day (2026-07-29) at `priority: P2`, `status: pending` — and as of today (2026-08-21), 23 days later, it is **still `pending`**, never picked up. The predicted landmine already partially detonated once in the interim: T-0125's own Result section documents that a routine redeploy on 2026-07-29 was blocked by exactly this uncommitted local diff, and was only rescued by a manual `git stash`/`git checkout`/`git stash pop` dance that "nothing forces a future deploy (especially an automated CI/CD run with no human watching) to perform correctly." This is not a hypothetical risk being newly speculated about — it is a documented, already-realized failure mode from the closest analogous precedent in this exact repo, with its designated cleanup task sitting unaddressed for over three weeks.
- **The task's own body already argues for (a), forcefully.** Its "What done looks like" section states the nginx change "must land as a PR against `aiqadam/ai-qadam-platform` ... not just edited live on the host and left undocumented, or it will drift on the next deploy exactly the way T-0132/T-0133 already documented happening once before." That is not phrased as an optional nice-to-have; it is phrased as a hard requirement with a named consequence, and this validator's job is to hold that language to account rather than let it soften into "note it as a follow-up" during design/execution.
- **The two situations are not symmetric in a way that would excuse (b) this time.** T-0125 was a P0 live-incident fix (523 blocking user registration) where speed against an active production-facing outage plausibly justified a host-first, upstream-later sequencing. T-0142 is `priority: P2`, not an active incident — prod's unrelated 523 is explicitly deferred and not a precondition. There is no urgency asymmetry here that would justify accepting the same drift risk a second time; if anything the P2 priority makes it easier to hold the line and do it right the first time.
- **Practical shape for step 04:** the solution-designer should plan this as (at minimum) two coordinated phases within the same run/plan — Phase 1: open the PR against `aiqadam/ai-qadam-platform` adding the third `server{}` pair to the tracked `deploy/nginx/qa.aiqadam.org.conf`, matching what will be applied live; Phase 2: apply the equivalent change to the live host file, confirm `nginx -t`, `reload`. The two do not strictly have to land in the same commit-instant (the live host can be updated first if that unblocks verification faster, mirroring T-0125's actual sequencing), but the PR must be a required, tracked deliverable of *this* task's own closure — this task's "Result" section should not be able to say "done" without a link to that PR, merged or at least opened, the way T-0125's Result section left T-0132 as a dangling loose end. Recommend the solution-designer/executor treat "PR opened and merged" (not just "opened") as part of this task's own acceptance criteria, closing the loop T-0132 left open, rather than spawning a third dangling task.
- Note for completeness: this is a nginx config change, not a `.env` change, so `.claude/CLAUDE.md`'s dev/test `.env`-edit exception (which covers only non-secret config flags in local dev/test `.env` files) does not apply here and was not considered as a basis for skipping the tracked-file discipline.

### Auto-approval / `NEEDS_APPROVAL` classification — reconfirmed

Per `shared/approval-protocol.md` §"What does and does not need approval," the following are unconditionally listed under **"Always `NEEDS_APPROVAL`"**, with no carve-out for narrow diffs or high confidence:
- "DNS changes, Cloudflare rule changes, firewall changes."
- (nginx vhost/config changes fall under the workflow's own general infra-change scope, and this same shared nginx file already houses two other live, project-critical hostnames — squarely the kind of "any operation the designer is uncertain about" / shared-blast-radius case this list exists to catch, independent of nginx not being separately named verbatim in the bullet list.)

Additionally, the auto-approval path (`PASS` from solution-designer) requires ALL of: `estimated_blast_radius: low` in the task file, `estimated_reversibility: full`, no irreversible steps, no designer doubts, no high-severity risk flags. The task file's own frontmatter sets `estimated_blast_radius: medium` (explicitly, and explicitly contrasted against sibling task T-0141's `low` in the task's own Notes section) — this alone is sufficient to disqualify `PASS` under approval-protocol's own condition #1, before even reaching the DNS/nginx bullet-list question. **This task cannot be a PASS/auto-approve candidate under any circumstances current facts support; solution-designer (step 04) must emit `NEEDS_APPROVAL`, and the orchestrator must halt for explicit human sign-off before any executor-infra action.**

## Issues / risks
- The companion-PR requirement (recommendation (a) above) adds cross-repo coordination overhead to what could otherwise look like a narrow, single-host infra task — this is a deliberate, reasoned tradeoff given the T-0125/T-0132 precedent, not an oversight, but it does mean step 04's plan and step 05's user-approval request should surface this explicitly so the user is approving the full two-repo scope, not just the host-side nginx edit.
- If a companion PR turns out to be genuinely infeasible within this run's scope (e.g., no write access to `aiqadam/ai-qadam-platform` from this session), the correct fallback is NOT silently reverting to pattern (b) — it is surfacing that constraint explicitly to the user at the approval gate and letting them decide, rather than the executor deciding unilaterally to defer it the way T-0125 did.
- Landscape's TLS/cert table gap (noted in step-02) means the solution-designer should build a live `certbot certificates` pre-flight check into Phase 0 of the plan rather than assuming the SAN-expansion story is exactly as described.

## Open questions (optional)
- none — no BLOCKED conditions. The one substantive judgment call (structural question (a) vs (b)) is resolved above with a clear recommendation for step 04 to carry forward, not left open for the user to adjudicate at this stage (though the user will still see and can override it at the NEEDS_APPROVAL gate in step 05).
