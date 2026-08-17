---
run_id: 2026-07-27-fix-authentik-scope-mappings-qa-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-27T15:31:05Z
task_id: T-0126-fix-authentik-scope-mappings-on-qa
inputs_read:
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-01-task-reader.md
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-02-landscape-reader.md
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-03-task-validator.md
  - tasks/T-0126-fix-authentik-scope-mappings-on-qa.md
  - tasks/T-0125-fix-authentik-admin-url-on-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Orchestrator must present this plan to the user for explicit APPROVE/REJECT/MODIFY before invoking executor-infra. Phase 0 (discovery) is read-only and low-risk, but the plan as a whole is gated NEEDS_APPROVAL because Phase 2 (the PATCH) touches a live, undocumented-in-landscape auth provider serving real users, and discovery could legitimately terminate the plan at BLOCKED if Phase 0's findings contradict the task's premise. If the user approves, executor-infra should still treat Phase 0's findings as authoritative over this plan's assumed commands, and MUST halt and report back (not improvise) if Phase 0 contradicts Phase 1/2's assumptions (e.g. different container name, different compose project, mapping identifiers not found).
---

## Summary
Discover whether and how Authentik actually runs on `pro-data-tech-qa` (read-only), then — only if discovery confirms a reachable Authentik instance — resolve the three managed `openid`/`email`/`profile` scope-mapping PKs and PATCH them onto the AI Qadam OAuth2 provider via Authentik's REST API using a short-lived admin token minted in-memory via `docker exec ... ak shell`, and verify the fix with both an API-level check and a live registration/sign-in round trip against QA's public hostname.

## Details

### Preconditions and unresolved naming discrepancy (read before executing)

The task file, T-0125, and DNS/landscape records disagree on QA's public hostname:
- `landscape/hosts/pro-data-tech-qa.md` / `landscape/services.md` (last_verified 2026-07-17/23): the only documented live AiQadam QA endpoint is `https://qa-uz.aiqadam.org` (renamed from `qa.aiqadam.org` during T-0110 specifically to route around an app-level tenant-parsing 400).
- T-0126 (this task)'s acceptance criteria and Why section: refer to `https://qa.aiqadam.org` throughout.
- T-0125 (2026-07-24, unresolved): live-tested against `https://qa.aiqadam.org/api/v1/auth/register` and got real responses (400, then presumably 302 after its own fix) — meaning `qa.aiqadam.org` route was reachable and hitting the real API at that time, in apparent tension with the landscape's `qa-uz.aiqadam.org`-only record.
- `landscape/domains.md`/`cloudflare.md` (per step-02): both `auth.qa.aiqadam.org` and `qa.aiqadam.org` A records exist, created out-of-band 2026-07-18 — i.e. *after* the landscape's `qa-uz.aiqadam.org` rename (2026-07-13) and *before* T-0125's successful live test against `qa.aiqadam.org` (2026-07-24). This is consistent with `qa.aiqadam.org` being a newer, out-of-band-provisioned alias/record sitting in front of the same stack, but this repo has never confirmed that live.

This plan does NOT assume which hostname is authoritative. Phase 0 includes a step to resolve this live before Phase 3's verification runs, so verification targets whichever hostname actually serves the AiQadam QA API today. If both resolve to the same stack, use `https://qa.aiqadam.org` per the task's own acceptance criteria wording (that is what the task asks to be verified against) but cross-check `qa-uz.aiqadam.org` still works too (non-regression).

### Plan

**Phase 0 — Read-only discovery (no state change). Hard gate before Phase 1.**

0.1. SSH to the host as an operator (per landscape: `tvolodi`/`viktor_d`/`binali_r`, all docker-group members, no sudo needed for `docker` commands).
   — command: `ssh pro-data-tech-qa "docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"`
   — verification: output lists all running/stopped containers on the host. Look specifically for any container whose name or image suggests Authentik (`authentik-server`, `authentik-worker`, `goauthentik/server`, etc.).

0.2. Enumerate all Compose projects on the host (not just the two landscape currently documents), in case Authentik was deployed out-of-band as its own project.
   — command: `ssh pro-data-tech-qa "docker compose ls --all"` and `ssh pro-data-tech-qa "find /opt /var/www /home -maxdepth 4 -iname 'docker-compose*.y*ml' 2>/dev/null"`
   — verification: full list of Compose project names + compose file paths on disk, cross-checked against `docker ps` output from 0.1.

0.3. If an Authentik-like container is found, confirm it is actually Authentik and capture its exact name, compose project, and network exposure.
   — command: `ssh pro-data-tech-qa "docker inspect <candidate-container-name> --format '{{.Config.Image}} {{.State.Status}} {{json .NetworkSettings.Ports}}'"`
   — verification: image name contains `authentik`; container state is `running`.

0.4. Confirm REST API reachability from the host's own perspective and externally, independent of `docker exec` working.
   — command (external, from management workstation): `curl -s -o /dev/null -w '%{http_code}\n' https://auth.qa.aiqadam.org/api/v3/root/config/`
   — verification: HTTP 200. (T-0125's own investigation on 2026-07-24 recorded this endpoint returning 200 — this step re-confirms it is still true today, 3 days later, not stale.)

0.5. Check the QA `api` container's `AUTHENTIK_ADMIN_URL` env var live, early, per the T-0125 confound called out in this run's task brief — so a T-0125 regression isn't misattributed to this task's own fix later in Phase 3.
   — command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-api-1 env | grep AUTHENTIK_ADMIN_URL"`
   — verification: record the output verbatim in the execution log. Expected-good value: `AUTHENTIK_ADMIN_URL=https://auth.qa.aiqadam.org`. If the var is absent or still points at `https://auth.aiqadam.org` (prod), this is a **pre-existing, out-of-scope condition** (T-0125's unresolved fix) — do not attempt to fix it under this task's identity. Note it in the final report and flag it explicitly if it later causes Phase 3's live sign-in check to fail, so that failure is not misattributed to this task's own patch.

0.6. Resolve the hostname discrepancy noted above: confirm which of `qa.aiqadam.org` / `qa-uz.aiqadam.org` actually serves the live AiQadam QA API today, and whether they are the same backend.
   — command: `curl -s -o /dev/null -w '%{http_code}\n' https://qa.aiqadam.org/health` and `curl -s -o /dev/null -w '%{http_code}\n' https://qa-uz.aiqadam.org/health`
   — verification: record both response codes/bodies. If both return the same `{"status":"ok",...}` payload, treat them as the same backend (expected: same loopback API container behind two nginx vhosts/DNS names, or one DNS name added later). If they diverge (e.g. one 404s, or bodies show different tenant/service data), STOP and re-route to BLOCKED — this would mean the task's target endpoint is not what the landscape or task file assumes, and needs human clarification before any patch is applied.

**Decision point (end of Phase 0):**
- If 0.1–0.3 find no Authentik-like container/service running anywhere on the host: **STOP. Do not proceed to Phase 1 or 2.** Re-route this run to `BLOCKED`. Recommended next action for the orchestrator: file the host-level Authentik discovery task that `landscape/domains.md` already flagged as missing (per step-02's finding), then re-run T-0126 once that lands. Do not attempt to locate or provision Authentik "somewhere else" (e.g. assume it's centrally hosted for prod+QA) without explicit user direction — that would silently expand this task's scope beyond what was validated.
- If 0.4 fails (REST API unreachable) but 0.1–0.3 found a running container: proceed cautiously to Phase 1 using `docker exec` + `ak shell` only (do not attempt the REST API path); note the discrepancy in the final report.
- If 0.6 finds the two hostnames serve genuinely different backends: STOP, re-route to `BLOCKED`, report the discrepancy to the user rather than guessing which one is "the real QA."
- Otherwise: proceed to Phase 1 using the exact container name, compose project, and hostname(s) confirmed by Phase 0 — not the names assumed in this plan's narrative (`authentik-server` is the task's *hypothesis*, not a confirmed fact; use whatever Phase 0 actually finds).

**Phase 1 — Reproduce the bug (read-only against Authentik; establishes the pre-patch baseline).**

1.1. Mint a short-lived Authentik admin session inside the confirmed Authentik container via `ak shell` (Authentik's Django management shell), matching the technique already verified in `aiqadam/ai-qadam-platform` PR #81 / `07-test-results.md`. Use the container name confirmed in Phase 0 (placeholder `<authentik-container>` below — replace with Phase 0's actual finding before running).
   — command: `ssh pro-data-tech-qa "docker exec -i <authentik-container> ak shell"` (interactive Python/Django shell; the executor pipes a short Python snippet via stdin rather than typing interactively — see 1.2/2.1 for the actual snippets)
   — verification: shell starts without error; Django ORM is importable (`from authentik.providers.oauth2.models import OAuth2Provider` succeeds).

1.2. Inside that shell, locate the AI Qadam OAuth2 provider and print its current `property_mappings`.
   — command (piped via stdin to the `ak shell` invocation from 1.1):
     ```python
     from authentik.providers.oauth2.models import OAuth2Provider
     p = OAuth2Provider.objects.get(name__icontains="aiqadam")  # narrow further by client_id if multiple match
     print(p.pk, p.name, list(p.property_mappings.values_list("managed", flat=True)))
     ```
   — verification: output shows the provider's `pk` and its current mapping list. Per the task's first acceptance criterion, expect this list to be empty `[]` or missing one/more of `goauthentik.io/providers/oauth2/scope-{openid,email,profile}` — this reproduces the bug. **If the provider already has all three attached, STOP — the task is already done; do not re-apply. Report this as a no-op finding, verify live sign-in still works (Phase 3.2), and close the task as already-resolved rather than proceeding to Phase 2.**

**Phase 2 — Attach the mappings (state-changing; additive only, no destructive operation).**

*Backup note (workflow rule "Backup before destructive changes"):* This operation does not overwrite or delete any existing config — it extends a list field (`property_mappings`) by adding entries, and Authentik's own object history (every model change is versioned internally by Authentik, visible via its admin UI "History" tab on the provider object) is the durable record of the pre-change state. Because nothing is destroyed, no separate host-level file backup is required by workflow rule 2 (`workflows/infrastructure.md` — backup is required before changes that *overwrite* config files or *delete* data; this changes API object state additively via a database-backed object, not a file). As an extra safety margin beyond the workflow's minimum, capture Phase 1.2's printed `property_mappings` output in the execution log verbatim before patching — that list is the rollback reference if a revert is ever needed (see Rollback below).

2.1. Resolve the three managed mapping PKs on THIS QA instance (never hardcode PKs — confirmed instance-specific per task body and step-01).
   — command (piped via stdin to `ak shell`, same session pattern as 1.1/1.2, or via a fresh invocation):
     ```python
     from authentik.core.models import PropertyMapping
     wanted = [
         "goauthentik.io/providers/oauth2/scope-openid",
         "goauthentik.io/providers/oauth2/scope-email",
         "goauthentik.io/providers/oauth2/scope-profile",
     ]
     mappings = list(PropertyMapping.objects.filter(managed__in=wanted))
     print([(m.managed, m.pk) for m in mappings])
     assert len(mappings) == 3, f"expected 3 managed mappings, found {len(mappings)}"
     ```
   — verification: prints exactly 3 `(managed, pk)` tuples, one per wanted identifier. If fewer than 3 are found, STOP — do not proceed with a partial set; this would mean QA's Authentik instance is missing built-in mappings entirely (a different, more serious problem than the task assumes) — re-route to BLOCKED and report.

2.2. Attach all three (in addition to whatever the provider already has, if anything) — additive, not a replace-in-place of unrelated mappings.
   — command (piped via stdin to `ak shell`):
     ```python
     from authentik.providers.oauth2.models import OAuth2Provider
     from authentik.core.models import PropertyMapping
     wanted = [
         "goauthentik.io/providers/oauth2/scope-openid",
         "goauthentik.io/providers/oauth2/scope-email",
         "goauthentik.io/providers/oauth2/scope-profile",
     ]
     p = OAuth2Provider.objects.get(pk=<provider-pk-from-1.2>)
     mappings = PropertyMapping.objects.filter(managed__in=wanted)
     p.property_mappings.add(*mappings)  # additive — .add() on M2M does not remove existing entries
     print(sorted(p.property_mappings.values_list("managed", flat=True)))
     ```
   — verification: printed list includes all three `scope-openid`/`scope-email`/`scope-profile` identifiers, plus anything that was already attached (nothing dropped). This is naturally idempotent: `.add()` on a Django M2M is a no-op for entries already present, so re-running Phase 2 after a partial or full prior success cannot create duplicates or a half-configured state.

**Phase 3 — Two-place verification (per workflow rule "Verify in two places").**

3.1. On-host / API-level check: re-query the provider's `property_mappings` in a fresh `ak shell` invocation (not reusing in-memory state from 2.2) to confirm the change persisted to the database, independent of the session that made it.
   — command: same query as 1.2, run fresh.
   — verification: all three managed identifiers present.

3.2. External / user-facing check: a live registration + sign-in round trip against the hostname(s) confirmed reachable in Phase 0.6.
   — command: manual (or scripted) browser/curl-based flow — navigate to `https://qa.aiqadam.org` (and cross-check `https://qa-uz.aiqadam.org` if Phase 0.6 found them to be the same backend), register a new, never-used test account, complete the Authentik OIDC redirect, land back on `/api/v1/auth/callback`.
   — verification: the callback does NOT return `401 {"message":"oidc id_token missing email claim"}`. The redirect completes to a signed-in session (per the task's acceptance criteria — mirrors the GitHub issue #79 repro screenshot). If T-0125's `AUTHENTIK_ADMIN_URL` check in Phase 0.5 showed a bad value, and this step still fails with a *different* error (e.g. a 523/registration_failed rather than the email-claim 401), attribute the failure to T-0125's unresolved gap, not to this task's own fix — do not attempt to fix `AUTHENTIK_ADMIN_URL` under this task's identity; report it as a T-0125 blocker instead.

3.3. Non-regression check: confirm an EXISTING user (one who registered/signed in before this patch, if any test account is available/known) can still sign in after the patch — the task's own acceptance criteria requires this, and it should be a no-op risk since the operation is additive-only.
   — command: same sign-in flow as 3.2, using a pre-existing account if one is available; if no known pre-existing test account exists, note this explicitly as "not independently verifiable — no pre-existing account available for regression test" rather than skipping the requirement silently.
   — verification: sign-in succeeds, no new errors introduced for the existing account.

**Phase 4 — Report back to the app repo (per task's 5th acceptance criterion).**

4.1. Post a status comment or update to `aiqadam/ai-qadam-platform`'s `ISS-AUTH-OIDC-EMAIL-001.md` (or open a follow-up issue there if that file is closed/archived) documenting: QA's provider `pk`, the pre-patch `property_mappings` state, the patch applied, and the live-verification result.
   — command: this is a cross-repo, out-of-band action (GitHub issue comment via `gh issue comment` if `gh` is authenticated against that repo, or a manual note) — executor-infra should perform this only if it has working `gh` access to `aiqadam/ai-qadam-platform`; otherwise defer to landscape-updater (step 08) or the orchestrator to record as a manual follow-up in the task's own `Result` section, which step 08 will write regardless.
   — verification: comment/issue exists and is readable at the URL reported back in this run's step-06/step-08 handoffs.

### Rollback

The overall operation (Phase 2) is additive-only and does not need a destructive-undo path in the normal case — but a rollback is specified per workflow rule 1 (idempotency) and rule 3 (every state-changing step needs a paired rollback or an explicit "no rollback possible" note).

1. Rollback of Phase 2.2 (detach the three added mappings, restoring the exact pre-patch list captured in Phase 1.2's log) — command (piped via stdin to `ak shell`):
   ```python
   from authentik.providers.oauth2.models import OAuth2Provider
   from authentik.core.models import PropertyMapping
   wanted = [
       "goauthentik.io/providers/oauth2/scope-openid",
       "goauthentik.io/providers/oauth2/scope-email",
       "goauthentik.io/providers/oauth2/scope-profile",
   ]
   p = OAuth2Provider.objects.get(pk=<provider-pk-from-1.2>)
   to_remove = PropertyMapping.objects.filter(managed__in=wanted)
   p.property_mappings.remove(*to_remove)  # only removes these 3; anything pre-existing and unrelated is untouched
   print(sorted(p.property_mappings.values_list("managed", flat=True)))
   ```
   This restores the provider to exactly its Phase-1.2-logged state, since `.remove()` is symmetric with `.add()` and Phase 1.2's own log is the audit trail of what was present before.
   **Caveat:** if Phase 1.2 found the provider already had one or two (but not all three) of the mappings pre-attached, the rollback above would incorrectly strip those pre-existing ones too, since it removes all three unconditionally. **Refinement:** only remove mappings that Phase 1.2's log shows were NOT already present pre-patch (i.e. rollback = set-difference between what 2.2 added and what 1.2 already found), not a blind removal of all three. The executor must compute this set difference from the two logged states before running a rollback, rather than assuming a from-scratch empty state.

2. Rollback trigger condition: only rollback if Phase 3.2's live verification fails AND root-causes to this patch specifically (not to the T-0125 `AUTHENTIK_ADMIN_URL` gap or the hostname discrepancy). If Phase 3.2 fails for an unrelated, pre-existing reason (T-0125, hostname confusion), do NOT roll back Phase 2 — the mapping attachment is correct and should stay; escalate the unrelated failure separately.

3. No rollback is needed/possible for Phase 0 (read-only) or Phase 1 (read-only) — nothing changed.

4. Phase 4 (cross-repo report) has no meaningful rollback (a posted comment can be edited/deleted manually if wrong, but this is not state this repo's workflow manages) — noted as "no rollback possible, low-stakes" rather than blocking on it.

### Verification (for step 07)

- **On-host:** `docker exec` into the confirmed Authentik container, fresh `ak shell` session, query `OAuth2Provider.objects.get(pk=<pk>).property_mappings.values_list("managed", flat=True)` — expect all three `scope-openid`/`scope-email`/`scope-profile` identifiers present (Phase 3.1, exact repeat as an independent check).
- **On-host (T-0125 confound control):** `docker exec aiqadam-qa-api-1 env | grep AUTHENTIK_ADMIN_URL` — record value; used to correctly attribute any Phase 3.2 failure, not a pass/fail gate on this task's own patch.
- **External:** `POST https://qa.aiqadam.org/api/v1/auth/register` with a fresh test email, followed by the OIDC sign-in redirect flow, landing on `/api/v1/auth/callback` — expect NOT `401 {"message":"oidc id_token missing email claim"}`; expect a signed-in session. Cross-check `https://qa-uz.aiqadam.org` if Phase 0.6 confirms it's the same backend.
- **External (regression):** existing-user sign-in (if a test account is available) completes without new errors.

### Resources used
- Secrets (by name): none pre-existing used. A short-lived Authentik admin session/token is minted in-process via `docker exec ... ak shell` (Django ORM access as the container's own service account, not a stored credential) — per the task's Notes, this is deliberately NOT added to `landscape/secrets-inventory.md` because it is ephemeral and never persisted to disk. If Phase 0 discovery finds that `ak shell` is not viable on QA's actual deployment (e.g. different Authentik packaging) and a REST API token must be minted and stored instead, the executor must STOP and treat that as a plan deviation requiring a return to solution-designer (not an on-the-fly credential decision) — this would also mean a new secrets-inventory entry is needed, which step 04 has not authorized here.
- Files modified on host: none (no config file is edited — the change is a database-backed object mutation via Authentik's own ORM/API, on whatever host actually runs Authentik).
- Files modified in this repo (landscape/): `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md` — step 08 (landscape-updater) must add a new subsection documenting the discovered Authentik service (container name, compose project, image/version, port bindings, admin-access mechanism) since neither file currently mentions it at all. This is itself a significant landscape gap this run will close as a side effect.
- External APIs called: Authentik's own internal Django ORM (via `ak shell`, not the REST API, per task Notes' stated preference) against whatever Authentik instance Phase 0 confirms; optionally Authentik's REST API if `ak shell` is not viable per Phase 0 findings (with the STOP-and-return caveat above); `gh issue comment` (or equivalent) against `aiqadam/ai-qadam-platform` for Phase 4's cross-repo report.

### Estimated impact
- Downtime: none expected. No container restart or recreate is required — the change is an in-place database object update via Authentik's running process; existing sessions/tokens are unaffected.
- Affected services: QA's Authentik OAuth2/OIDC provider for the AI Qadam application (whatever host/container Phase 0 confirms). Indirectly, the AiQadam QA API's OIDC callback flow (`aiqadam-qa-api-1`) once users complete sign-in through the patched provider.
- Reversibility: fully reversible in the normal case (see Rollback), with one caveat: if the pre-patch state included a partial subset of the three managed mappings (not empty, not all three), rollback requires computing a set-difference rather than a blind full detach — the plan's rollback section accounts for this, but it depends on Phase 1.2's log being captured accurately before any change.

## Issues / risks

- **HIGH — Task premise is unverified against landscape.** Per step-02/step-03, no landscape file documents an Authentik service on `pro-data-tech-qa` at all; the one file that documents this host's OIDC-related surface (`aiqadam-qa-oidc-stub-1`) explicitly says real OIDC is out of scope for this environment. The container name (`authentik-server`), its compose project membership ("part of the `aiqadam-qa` stack"), and its "running unchanged for 9 days" claim are all narrative from the task file, not landscape fact. Phase 0 is designed to resolve this, but there is a real chance Phase 0 terminates the run at BLOCKED rather than reaching Phase 2 — the user should know that going in.
- **HIGH — Hostname discrepancy (`qa.aiqadam.org` vs `qa-uz.aiqadam.org`) is unresolved.** The landscape's only documented live endpoint is `qa-uz.aiqadam.org`; the task's acceptance criteria and T-0125's own successful live test both reference `qa.aiqadam.org`. Phase 0.6 is designed to resolve this before Phase 3 relies on it, but if they turn out to be genuinely different backends, this plan cannot proceed as written and must escalate.
- **MEDIUM — T-0125 confound.** If `AUTHENTIK_ADMIN_URL` on the QA `api` container still points at prod (T-0125 unresolved), Phase 3.2's live-verification step could fail for a reason unrelated to this task's fix, producing a confusing false-negative. Phase 0.5 checks this early specifically to prevent misattribution, but does not fix it — that remains T-0125's own scope.
- **MEDIUM — Credential-minting mechanism is itself somewhat state-changing-adjacent.** `docker exec ... ak shell` opens an interactive/scripted session with full Django ORM access inside the Authentik container — broader than a scoped read-only API token would be. This is the task's own explicitly preferred approach (mirroring PR #81's precedent) and is reasonable given no pre-existing QA Authentik credential exists, but it is a broad-privilege mechanism and the plan bounds its use strictly to the documented read (Phase 1) and additive-write (Phase 2) queries above — the executor must not run other ORM operations in that shell.
- **LOW — Out-of-band service risk.** Whoever set up `auth.qa.aiqadam.org` (2026-07-18, out-of-band, no task file) may have used non-standard conventions this plan's Phase 1/2 Python snippets assume (e.g. a provider name that doesn't contain "aiqadam", multiple OAuth2Provider objects). Phase 1.2's query uses `name__icontains="aiqadam"` as a best-effort filter; if this returns 0 or >1 matches, the executor must stop and report rather than guessing which provider to patch.
- **LOW — Blast radius bounded but touches a live P0 auth surface.** Per task file, `estimated_blast_radius: low` and `estimated_reversibility: full` — and this plan's Phase 2 change is genuinely additive/idempotent as designed. However, this is real QA authentication infrastructure with unresolved discovery gaps (the two HIGH items above), so I am not treating the task file's blast-radius label as sufficient on its own to auto-approve.

## Verdict rationale

This plan is `NEEDS_APPROVAL`, not `PASS`, despite the task file's `estimated_blast_radius: low` / `estimated_reversibility: full` labels, because:

1. Per `shared/approval-protocol.md`, `PASS` requires the designer to have **no doubts or open questions** about the plan. I have two unresolved HIGH-severity open questions baked into Phase 0 (does Authentik exist on this host at all / in what form; which hostname is authoritative) that this plan cannot resolve without live discovery — and per this run's own instructions, "the plan must define what happens if discovery finds no Authentik service at all (this should route to BLOCKED/escalation, not proceed on assumption)," which is itself a tacit acknowledgment that the premise is in doubt.
2. Per `shared/approval-protocol.md`'s explicit rule: "Any operation the designer is uncertain about" always requires `NEEDS_APPROVAL`, and this task's own framing note said to "lean toward requiring approval unless you're confident the plan is fully safe and reversible" — I am not fully confident, specifically because of the unverified-container and hostname-discrepancy issues above.
3. This is explicitly a P0 change to a live, user-facing authentication provider — even though the specific API operation (additive M2M attach) is technically low-risk and reversible, the surrounding uncertainty about what exactly is being changed (unconfirmed container/host detail) crosses the threshold this protocol sets for requiring a human to see the plan before Phase 1/2 run.
4. Phase 0 itself is read-only and could, in principle, be run under a lighter-weight/no-approval discovery pattern — but this workflow's step bindings route this task through `executor-infra` as a single step-06 invocation, and the approval gate sits before step 06 entirely, not between Phase 0 and Phase 1 within step 06. Since the plan as a whole (including the state-changing Phase 2) is what gets approved or not, and Phase 2 is the part that needs a human's eyes given the doubts above, the whole plan is marked `NEEDS_APPROVAL` rather than splitting discovery into its own auto-approved run.

## Open questions (optional)
- Does an Authentik service actually run on `pro-data-tech-qa`, and if so what is its exact container name / compose project / access mechanism? (Answered by Phase 0.1–0.3; if the answer is "no," this plan terminates at BLOCKED rather than reaching Phase 2.)
- Are `qa.aiqadam.org` and `qa-uz.aiqadam.org` the same backend? (Answered by Phase 0.6; if they diverge, this plan cannot proceed as written.)
- Is `AUTHENTIK_ADMIN_URL` on the QA `api` container already correctly pointing at `https://auth.qa.aiqadam.org` (T-0125's fix), or still defaulting to prod? (Answered by Phase 0.5; does not block this task's own Phase 1/2, but affects how Phase 3.2 failures should be interpreted.)
