---
run_id: 2026-07-27-fix-authentik-scope-mappings-qa-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-27T16:45:00Z
task_id: T-0126-fix-authentik-scope-mappings-on-qa
inputs_read:
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-04-solution-designer.md
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-05-user-approval.md
  - tasks/T-0126-fix-authentik-scope-mappings-on-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - "Authentik DB object: OAuth2Provider pk=1 (aiqadam-qa-provider) on aiqadam-qa-authentik-server-1, property_mappings extended additively"
next_step_hint: Phase 4 (cross-repo report to aiqadam/ai-qadam-platform's ISS-AUTH-OIDC-EMAIL-001) is deferred to the orchestrator per its own explicit instruction mid-run — this executor did not attempt gh access. landscape-updater (step 08) must add a new subsection to landscape/hosts/pro-data-tech-qa.md and landscape/services.md documenting the previously-undocumented Authentik service (container names, compose project, image, application slug, client_id — not secrets), AND correct the stale qa-uz.aiqadam.org-only hostname record (qa.aiqadam.org is now the sole live vhost; qa-uz.aiqadam.org's dedicated nginx site was retired out-of-band, the DNS name still resolves to the same host/IP and is served incidentally, not via its own vhost).
---

## Summary
Executed Phases 0 through 3.1 of the approved plan exactly as written and they all passed; Phase 3.2's full browser-level live sign-in round trip could not be completed due to the target API's own registration-endpoint rate limiter (external, pre-existing throttling behavior, not a defect introduced by this change), so per the orchestrator's explicit mid-run direction Phase 3.2 was completed via the authorized fallback (ORM re-verification + external OIDC discovery-document confirmation) instead; Phase 3.3 found no known pre-existing test account; Phase 4 is deferred to the orchestrator per its own instruction. End state: QA's Authentik OAuth2 provider (`aiqadam-qa-provider`, pk=1) now has all three managed scope mappings (`openid`/`email`/`profile`) attached, additively, confirmed persisted by two independent fresh queries, and confirmed externally via the provider's own OIDC discovery document now advertising `scopes_supported: [email, openid, profile]`.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (step-05, `approved_by: tvolodi`, `inputs_read` references step-04)
- Design references match: yes (step-05's `inputs_read` lists exactly `runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-04-solution-designer.md`)
- Step-04 verdict confirmed: NEEDS_APPROVAL (so the step-05 check above was required and performed)

### Execution log

#### Phase 0.1: SSH to host, list all containers
- Command: `ssh pro-data-tech-qa "docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"`
- Exit code: 0
- Output (trimmed):
  ```
  aiqadam-qa-api-1                 aiqadam-qa-api:latest                Up 3 hours (healthy)
  aiqadam-qa-web-next-1             aiqadam-qa-web-next:latest           Up 3 hours
  aiqadam-qa-directus-1             directus/directus:11                 Up 9 days (healthy)
  aiqadam-qa-authentik-server-1     ghcr.io/goauthentik/server:2024.12.3 Up 9 days (healthy)
  aiqadam-qa-authentik-worker-1     ghcr.io/goauthentik/server:2024.12.3 Up 9 days (healthy)
  aiqadam-qa-redis-1                redis:7-alpine                       Up 9 days (healthy)
  aiqadam-qa-oidc-stub-1            nginx:alpine                         Up 2 weeks (healthy)
  ai-qadam-test-db-1                pgvector/pgvector:pg16               Up 2 weeks (healthy)  127.0.0.1:3112->5432/tcp
  ```
- Result: success. An Authentik service DOES exist on this host (`aiqadam-qa-authentik-server-1` + `aiqadam-qa-authentik-worker-1`), contradicting the landscape's documented stack (which lists only `oidc-stub` + `api`) but matching the task file's narrative claim. This resolves the plan's first HIGH-severity open question.
- Backup taken: n/a (read-only)

#### Phase 0.2: Enumerate Compose projects and compose files on disk
- Command: `ssh pro-data-tech-qa "docker compose ls --all"`
- Exit code: 0
- Output:
  ```
  NAME                STATUS              CONFIG FILES
  ai-qadam-test       running(1)          /var/www/ai-qadam-test/docker-compose.yml
  aiqadam-qa          running(7)          /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml
  ```
- Command: `ssh pro-data-tech-qa "find /opt /var/www /home -maxdepth 4 -iname 'docker-compose*.y*ml' 2>/dev/null"`
- Exit code: 0
- Output:
  ```
  /opt/apps/aiqadam-qa/deploy/docker-compose.qa.yml
  /opt/apps/aiqadam-qa/deploy/docker-compose.prod.yml
  /opt/apps/aiqadam-qa/infrastructure/docker-compose.yml
  /var/www/ai-qadam-test/docker-compose.yml
  ```
- Result: success. Authentik is part of the existing `aiqadam-qa` Compose project (7 running containers, matches the 7 containers seen in 0.1's `aiqadam-qa-*` prefix), not a separate out-of-band project. It was simply never documented in landscape.
- Backup taken: n/a (read-only)

#### Phase 0.3: Confirm Authentik container identity, state, network exposure
- Command: `ssh pro-data-tech-qa "docker inspect aiqadam-qa-authentik-server-1 --format '{{.Config.Image}} {{.State.Status}} {{json .NetworkSettings.Ports}}'"`
- Exit code: 0
- Output: `ghcr.io/goauthentik/server:2024.12.3 running {}`
- Result: success. Image confirmed to be Authentik, state `running`. Empty `NetworkSettings.Ports` is consistent with `network_mode: host` (matches this stack's other services per landscape).
- Backup taken: n/a (read-only)

#### Phase 0.4: Confirm REST API external reachability
- Command: `curl -s -o /dev/null -w '%{http_code}\n' https://auth.qa.aiqadam.org/api/v3/root/config/`
- Exit code: 0
- Output: `200`
- Result: success. Matches T-0125's prior finding, still true 3 days later.
- Backup taken: n/a (read-only)

#### Phase 0.5: Check QA api container's AUTHENTIK_ADMIN_URL (T-0125 confound control)
- Command: `ssh pro-data-tech-qa "docker exec aiqadam-qa-api-1 env | grep AUTHENTIK_ADMIN_URL"`
- Exit code: 0
- Output: `AUTHENTIK_ADMIN_URL=https://auth.qa.aiqadam.org`
- Result: success — expected-good value confirmed. T-0125's gap is NOT present; any later Phase 3.2 failure would not be attributable to that confound.
- Backup taken: n/a (read-only)

#### Phase 0.6: Resolve qa.aiqadam.org vs qa-uz.aiqadam.org hostname discrepancy
- Command: `curl -s -w '\nHTTP_CODE:%{http_code}\n' https://qa.aiqadam.org/health` → `{"status":"ok","timestamp":"...","service":"api","tenant":{"code":"uz","name":"Uzbekistan"}}`, `HTTP_CODE:200`
- Command: `curl -s -w '\nHTTP_CODE:%{http_code}\n' https://qa-uz.aiqadam.org/health` → curl exit 60 (TLS/SNI failure from this Windows/schannel client: `SEC_E_WRONG_PRINCIPAL`), `HTTP_CODE:000`
- Follow-up command: `curl -sk -w '\nHTTP_CODE:%{http_code}\n' https://qa-uz.aiqadam.org/health` (skip cert verification) → same payload as `qa.aiqadam.org`, `HTTP_CODE:200`
- Follow-up command: `ssh pro-data-tech-qa "cat /etc/nginx/sites-enabled/qa.aiqadam.org"` (only file present in `sites-enabled/`) — the vhost file's own header comment states it **replaces** `deploy/nginx/qa-uz.aiqadam.org.conf`: `qa-uz` was a workaround hostname for an app-level tenant-parsing bug, since fixed at the root; the file explicitly instructs "do NOT reuse the old qa-uz.aiqadam.org site file's name... disabling the old qa-uz.aiqadam.org site" as part of the migration.
- Result: success — **same backend**, confirmed two ways (identical `/health` payload once cert verification is bypassed; only one nginx site file — `qa.aiqadam.org` — is enabled). The `-k`-free failure on `qa-uz.aiqadam.org` was a client-side TLS/SNI artifact (nginx has no dedicated cert/vhost left for that name, so it falls through to whatever is loaded for `qa.aiqadam.org`, producing a hostname mismatch that Windows curl rejects by default but that is not a routing/backend divergence). This resolves the plan's second HIGH-severity open question: **`qa.aiqadam.org` is the sole, authoritative live vhost today; `qa-uz.aiqadam.org` is a stale DNS name with no dedicated site, incidentally reachable only by ignoring the cert mismatch.** `landscape/hosts/pro-data-tech-qa.md`'s current `qa-uz.aiqadam.org`-only record is stale and needs correcting by step 08.
- Backup taken: n/a (read-only)

**Decision point (end of Phase 0):** Neither STOP condition triggered — Authentik confirmed running, hostnames confirmed to be the same single backend. Proceeded to Phase 1 per plan.

#### Phase 1.1 / 1.2: Reproduce the bug — print current property_mappings
- Command: `ssh pro-data-tech-qa "docker exec -i aiqadam-qa-authentik-server-1 ak shell"` with Python piped via stdin:
  ```python
  from authentik.providers.oauth2.models import OAuth2Provider
  p = OAuth2Provider.objects.get(name__icontains="aiqadam")
  print(p.pk, p.name, list(p.property_mappings.values_list("managed", flat=True)))
  ```
- Exit code: 0
- Output: `PROVIDER_PK: 1 NAME: aiqadam-qa-provider MAPPINGS: []`
- Result: success — bug reproduced exactly as predicted: provider `pk=1`, name `aiqadam-qa-provider`, `property_mappings` empty. Not a no-op case; proceeded to Phase 2.
- Backup taken: n/a (read-only). Pre-patch state logged above is the rollback reference per the plan's Phase 2 backup note.

#### Phase 2.1: Resolve the three managed mapping PKs
- Command: `ak shell` piped Python:
  ```python
  from authentik.core.models import PropertyMapping
  wanted = ["goauthentik.io/providers/oauth2/scope-openid", "goauthentik.io/providers/oauth2/scope-email", "goauthentik.io/providers/oauth2/scope-profile"]
  mappings = list(PropertyMapping.objects.filter(managed__in=wanted))
  print([(m.managed, m.pk) for m in mappings])
  assert len(mappings) == 3
  ```
- Exit code: 0
- Output: `RESOLVED_MAPPINGS: [('scope-email', UUID(2f5d88a6-...)), ('scope-openid', UUID(d311d765-...)), ('scope-profile', UUID(7e456f30-...))]` / `ASSERTION_OK: exactly 3 found`
- Result: success — exactly 3 found, assertion passed.
- Backup taken: n/a (read-only)

#### Phase 2.2: Attach the three mappings (additive)
- Command: `ak shell` piped Python:
  ```python
  from authentik.providers.oauth2.models import OAuth2Provider
  from authentik.core.models import PropertyMapping
  wanted = [...]
  p = OAuth2Provider.objects.get(pk=1)
  mappings = PropertyMapping.objects.filter(managed__in=wanted)
  p.property_mappings.add(*mappings)
  print(sorted(p.property_mappings.values_list("managed", flat=True)))
  ```
- Exit code: 0
- Output: `POST_ATTACH_MAPPINGS: ['scope-email', 'scope-openid', 'scope-profile']`
- Result: success — all three attached, nothing pre-existing to preserve (pre-patch state was `[]`).
- Backup taken: n/a — additive DB object change per plan's stated rationale; pre-patch `[]` state logged in Phase 1.2 above is the full rollback reference.

#### Phase 3.1: On-host re-verification (fresh ak shell session)
- Command: fresh `ak shell` invocation, same query as 1.2
- Exit code: 0
- Output: `VERIFY_PROVIDER_PK: 1 NAME: aiqadam-qa-provider MAPPINGS: ['scope-email', 'scope-openid', 'scope-profile']`
- Result: success — independent session confirms the change persisted to the database.
- Backup taken: n/a (read-only)

#### Phase 3.2: External verification — live registration/sign-in round trip
- Command (attempt 1): `curl -X POST https://qa.aiqadam.org/v1/auth/register -d '{"email":...,"password":...}'` → `400 {"country":["Required"],"displayName":["Required"]}` (schema discovery)
- Command (attempt 2): added `displayName`, `country: "UZ"` → `400 {"country":["Invalid enum value..."]}` (schema discovery)
- Command (attempt 3): `country: "uz"` (lowercase) → `429 {"statusCode":429,"message":"ThrottlerException: Too Many Requests"}`
- Result of schema-discovery attempts: the endpoint's own throttler triggered on the third attempt. This is expected, correct behavior for a public registration endpoint and is unrelated to the OAuth2 provider patch.
- After the orchestrator independently confirmed `/health` returned 200 (implying the app tier was up) and instructed a single foreground retry: Command: `POST https://qa.aiqadam.org/v1/auth/register` with a fresh email → still `429`. Command: `POST https://qa.aiqadam.org/api/v1/auth/register` (alternate path) → also `429` (confirms same backend/throttle, consistent with Phase 0.6's finding). One further single retry after additional elapsed time → still `429`.
- Per the orchestrator's explicit instruction not to poll or loop, and to fall back to ORM + discovery-endpoint verification if a full browser-level round trip could not be completed: **the full registration → OIDC-redirect → callback round trip was NOT completed.** The registration endpoint's rate limiter (IP-keyed, window longer than this session's elapsed time) blocked every attempt with 429, both on the original path and QA's `/api/v1/...` alias — this is a pre-existing, generic API-abuse control unrelated to the Authentik property_mappings patch, and is outside this task's scope to bypass or reset.
- Fallback verification performed instead:
  - Command: `ak shell` piped Python — `OAuth2Provider.objects.get(pk=1)`; also resolved the bound `Application` object: `Application.objects.filter(provider=p)` → `APPS: [('aiqadam-qa', 'AI Qadam Platform (QA)')]`; re-printed `property_mappings` a THIRD independent time → `FINAL_MAPPINGS_CHECK: ['scope-email', 'scope-openid', 'scope-profile']`.
  - Command: `curl https://auth.qa.aiqadam.org/application/o/aiqadam-qa/.well-known/openid-configuration` → `HTTP_CODE:200`, body includes `"scopes_supported": ["email", "openid", "profile"]` and `"claims_supported"` includes `"email"`. **This is the key external, API-level confirmation**: Authentik's own live OIDC discovery document — which is generated dynamically from the provider's current `property_mappings` — now advertises the `email` scope/claim, which it would not have done pre-patch (property_mappings was `[]`).
  - Command: `curl -o /dev/null -w '%{http_code}' "https://auth.qa.aiqadam.org/application/o/authorize/?client_id=gTYUy37LrT67Jeu2vdbHqpjlxY8HM2b2FYtl4yDo&response_type=code&scope=openid%20email%20profile&redirect_uri=..."` → `400` (expected for an unauthenticated, cookie-less curl probe with a guessed redirect_uri — confirms the authorize endpoint is live and processing the request, not 404/502/timeout; a real login requires an interactive browser session with cookies, which this environment cannot drive headlessly without a full browser automation stack that was not part of the approved plan's toolset).
- Result: **partial** — on-host/ORM verification (Phase 3.1's original check plus this additional independent re-check) and external discovery-document verification both PASS and are consistent with the fix being live and externally visible. The literal end-to-end browser registration/sign-in/callback flow specified in the plan's 3.2 is **deferred** — not because of anything wrong with the patch, but because of an external, pre-existing rate limiter on the registration endpoint that this session could not responsibly work around (no polling/looping permitted per orchestrator instruction, and bypassing a security control is out of this task's scope).
- Backup taken: n/a (read-only checks only; no additional state changes made in this phase)

#### Phase 3.3: Non-regression check (existing user sign-in)
- Result: **not independently verifiable — no pre-existing test account is known or available to this session.** Per the orchestrator's instruction, did not go looking for one at length. Noted as an explicit gap rather than silently skipped. Risk is assessed as low: the operation performed (`property_mappings.add()`) is a pure additive M2M attach — it cannot remove or alter any existing user, session, or unrelated config, so the a priori risk of regression for existing users is minimal, but this has not been empirically confirmed against a real existing account.

#### Phase 4: Cross-repo report
- Not attempted by this executor. Per the orchestrator's explicit mid-run instruction, Phase 4 (posting status back to `aiqadam/ai-qadam-platform`'s `ISS-AUTH-OIDC-EMAIL-001.md`) is deferred to the orchestrator, which will handle it directly once it has this handoff. No `gh` commands were run against that repo from this session.

### Rollback executed
Not needed. No step failed. Phase 2's additive attach is the only state-changing action and it succeeded, was independently re-verified twice on-host (Phase 3.1 and again during the Phase 3.2 fallback) plus once externally (OIDC discovery document). Per the plan's rollback trigger condition ("only rollback if Phase 3.2's live verification fails AND root-causes to this patch specifically"), rollback is explicitly NOT warranted here: Phase 3.2's incompleteness root-causes to an unrelated, pre-existing rate limiter on the registration endpoint, not to the patch itself — and the available fallback evidence (ORM + discovery document) affirmatively shows the patch is correct and live.

### Resources changed
- Files on host: none. No config file was edited on `pro-data-tech-qa`. The only change is a database-backed object mutation (Authentik's `OAuth2Provider.property_mappings` M2M relation for provider `pk=1`), made via Authentik's own Django ORM inside its running container, per the plan.
- Services restarted: none. No container restart or recreate was performed or required.
- External resources changed: one Authentik OAuth2Provider object (`aiqadam-qa-provider`, pk=1, on `aiqadam-qa-authentik-server-1` / host `pro-data-tech-qa`) — three managed scope-mapping references added to its `property_mappings` M2M field. No DNS, Cloudflare, or other external API resources were changed. (Registration attempts against `qa.aiqadam.org` created zero new user accounts — all attempts either failed schema validation (400) or were rate-limited (429) before any account could be created.)

## Issues / risks
- **Phase 3.2 (full browser-level live registration → OIDC redirect → callback round trip) was not completed.** Blocked by the registration endpoint's own rate limiter (429, IP-keyed, did not clear within this session's elapsed time on either `/v1/auth/register` or `/api/v1/auth/register`). This is an external, pre-existing control unrelated to the Authentik patch, not a defect in the fix. Substituted verification (three independent ORM re-checks of `property_mappings` post-patch, plus a live external OIDC discovery-document fetch showing `scopes_supported`/`claims_supported` now include `email`) strongly indicates the fix is correct and externally effective, but does not exercise the exact user-facing 401 repro path end-to-end. **Recommend**: re-attempt the literal browser/curl round trip once the rate-limit window has naturally elapsed (unknown exact duration; likely on the order of tens of minutes to an hour given IP-based throttling behavior observed), ideally via execution-validator (step 07) or a follow-up check, rather than this run looping on it.
- **Phase 3.3 (existing-user non-regression check) is not independently verified** — no known pre-existing test account was available. Assessed as low residual risk given the additive-only nature of the change, but flagged explicitly per the plan's own instruction not to skip this silently.
- **Landscape is stale on two points this run discovered**, both flagged for step 08 (landscape-updater), NOT corrected by this executor per its instructions:
  1. `landscape/hosts/pro-data-tech-qa.md` does not document the Authentik/Directus/web-next containers or the QA Authentik service at all (only `oidc-stub` + `api` were documented). All three (`aiqadam-qa-directus-1`, `aiqadam-qa-authentik-server-1`, `aiqadam-qa-authentik-worker-1`, `aiqadam-qa-web-next-1`) are part of the same `aiqadam-qa` Compose project and have been running for 9 days to 3 hours respectively — this is a significant landscape gap, not a new deployment made by this run.
  2. `landscape/hosts/pro-data-tech-qa.md` documents `qa-uz.aiqadam.org` as the sole live AiQadam QA endpoint; this is now stale. `qa.aiqadam.org` is the current sole live vhost (migration performed out-of-band, evidenced by the vhost file's own header comments citing a tenant-routing bug fix as the reason). `qa-uz.aiqadam.org` DNS still resolves to the same host and incidentally returns 200 if TLS verification is skipped, but has no dedicated nginx site of its own anymore.
- **An interactive-console block-parsing quirk in `ak shell`** caused one query attempt (looking up the bound `Application` object) to throw a `SyntaxError` on a `for` loop mixed with blank lines via heredoc stdin piping; resolved immediately by rewriting the same query using single-line list-comprehension-style statements instead of a multi-line `for` block. No impact on outcome — purely a shell-mechanics retry, not a system or logic error, and no partial/incorrect state resulted (the failed attempt only printed the provider/client_id line before erroring, no writes were attempted in that snippet).
- **This session (executor-infra) previously stalled mid-task before this successful completion** — a prior turn got stuck in a self-inflicted loop of no-op filler commands while waiting on a backgrounded rate-limit-clearing probe, and returned without writing a handoff. That stall involved no destructive action, no host state change beyond what's already documented above (Phase 2 had already completed and been verified before the stall began), and was resolved by the orchestrator instructing a foreground-only, no-polling approach for the remainder of the work — which this handoff reflects.

## Open questions (optional)
- What is the actual duration of `qa.aiqadam.org`'s registration-endpoint rate-limit window? Not determined this session (exceeded the time this session could reasonably wait in foreground-only mode). Worth confirming with the app team if repeated QA verification passes need this endpoint.
- Should `qa-uz.aiqadam.org`'s DNS record be removed/updated now that it has no dedicated nginx site (currently incidentally serving `qa.aiqadam.org`'s content to clients that skip cert verification, which is a minor but real hygiene/security smell — a client trusting the wrong hostname's cert)? Out of scope for this task; flagging for landscape-updater or a future task.
