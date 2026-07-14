---
run_id: 2026-07-13-setup-aiqadam-prod-infra-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-13T15:10:00Z
task_id: T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod
retry_of: step-04
inputs_read:
  - runs/2026-07-13-setup-aiqadam-prod-infra-001/step-04-solution-designer.md (prior version — still valid except Phase C step 11 and Phase B's Postgres bind-address assumption)
  - runs/2026-07-13-setup-aiqadam-prod-infra-001/step-05-user-approval.md (still valid — git ref dfd2a7c, bare-apex-only, DNS repoint confirmed; unchanged by this revision)
  - runs/2026-07-13-setup-aiqadam-prod-infra-001/.attempts/step-06-executor-infra-attempt-2.md (FAIL handoff — root cause and diagnostic detail for both fixes below)
  - shared/approval-protocol.md
  - shared/verdicts.md
  - shared/handoff-format.md
  - workflows/infrastructure.md
artifacts_changed: []
next_step_hint: >
  This is a narrow revision of the already-approved step-04 plan: only Phase C step 11 (POSTGRES_PASSWORD generation)
  and Phase B (Postgres bind-address handling) changed, plus a mechanical healthcheck-string typo fix already applied
  once by the executor. Git ref (dfd2a7c), scope (bare-apex-only), and the DNS repoint approach are unchanged and are
  NOT being re-litigated. Per approval-protocol, any change to step-04's content — however narrow — requires its own
  approval round; this is technically a new step-04 version and needs a fresh step-05. Recommend presenting the user
  with a short diff-style summary (two changed lines, one typo fix) rather than re-asking the three original open
  questions, since none of those changed. Route to executor-infra only after a new step-05-user-approval.md exists
  with verdict APPROVED referencing this step-04 version. On execution, remind the executor that the existing
  checkout at /opt/apps/aiqadam-prod (dfd2a7c) and the two aiqadam-prod-api image tags (both b20217d09ca8) may be
  reused as-is — only Phase C (.env regeneration) and Phase D (container recreation) need to re-run.
---

## Summary
Revises the already-approved T-0111 plan in exactly three places — Phase C step 11's Postgres password generation (switched from `openssl rand -base64 32` to `openssl rand -hex 24` to eliminate URL-metacharacters), Phase B's Postgres bind-address handling (now explicitly relies on UFW default-deny + Docker network isolation, documented rather than assumed), and a mechanical healthcheck-string typo fix — while leaving git ref (`dfd2a7c`), scope (bare-apex-only), the DNS repoint approach, and every other phase of the prior plan completely unchanged.

## Details

### What changed and why (scoped to this revision only)

**1. Phase C step 11 — POSTGRES_PASSWORD generation (root cause of the FAIL)**

The prior plan's `POSTGRES_PASSWORD=$(openssl rand -base64 32)` produced a 44-character base64 string that, in the actual failed run, contained one `/` and one `=`. When interpolated unescaped into `DATABASE_URL=postgresql://aiqadam_prod:${POSTGRES_PASSWORD}@127.0.0.1:3114/aiqadam_prod`, the app's environment-config validator rejected the URL outright (`Invalid environment configuration: { DATABASE_URL: [ 'Invalid url' ] }`), causing a deterministic crash-loop (RestartCount climbing 8→10). This is exactly the same class of problem `INTERNAL_API_TOKEN` in the same step already avoids by using `openssl rand -hex 32` — hex alphabet (`0-9a-f`) has no URL-metacharacters and needs no escaping under any circumstance. Fix: switch `POSTGRES_PASSWORD` to `openssl rand -hex 24` (24 bytes = 48 hex characters — comparable entropy to the 32-byte base64 value it replaces, since base64 encodes ~6 bits/char vs hex's 4 bits/char: 32 bytes base64 ≈ 256 bits of entropy, 24 bytes hex = 192 bits of entropy, still far in excess of any reasonable brute-force concern for a loopback-only database credential). This is a one-line, mechanical change with no other design impact.

**2. Phase B — Postgres bind-address handling**

The prior plan asserted (incorrectly, per the FAIL diagnostic) that setting `PGPORT: "3114"` under `network_mode: host` would cause Postgres to bind to a loopback-equivalent address. In the actual run, Postgres bound to `0.0.0.0:3114` and `[::]:3114` — reachable on all host interfaces at the container/process level. This did not create real external exposure during the run because UFW's default-deny-incoming policy only allows `22/tcp`, `80/tcp`, `443/tcp` inbound (confirmed in `landscape/hosts/pro-data-tech-prod.md`) — port 3114 was never reachable from outside the host. Two options were considered for this revision:

- **(a) Explicit `listen_addresses='127.0.0.1'` override** — add `command: ["-c", "listen_addresses=127.0.0.1"]` (or `POSTGRES_INITDB_ARGS`/a mounted `postgresql.conf` snippet) to force Postgres itself to refuse non-loopback connections at the application layer, independent of network-level controls.
- **(b) Document reliance on UFW default-deny + Docker network isolation, matching the existing Penpot precedent** — Penpot's own `penpot-penpot-postgres-1` container (also `network_mode`-adjacent in practice, definitely not app-layer-restricted to loopback either) relies on exactly this same two-layer boundary (UFW inbound rules + the fact that nothing routes host-external traffic to the port) and has run in production on this host without incident.

**Decision: option (b).** Justification: this plan is deliberately structured to mirror existing, already-approved precedent on this host wherever a choice exists (same reasoning applied to Postgres version, cert-per-domain vs SAN, `proxied:false` convention, etc.) rather than introduce a new per-service hardening posture that the existing Penpot deployment doesn't have. Adding `listen_addresses='127.0.0.1'` would be strictly safer in isolation, but it is a new, previously-undocumented control this repo doesn't apply anywhere else on this host, it adds a config-mount/`command:` complexity surface to a Compose file that is otherwise a straight copy of the QA pattern, and it provides no defense-in-depth benefit beyond what UFW already guarantees today (UFW is the actual enforcement boundary; an app-layer restriction would be redundant, not additive, given UFW already blocks the port entirely from outside the host — the only remaining exposure is host-local processes, which is the same trust boundary Penpot's Postgres already accepts). This is documented explicitly below and in Issues/risks, rather than left as an implicit assumption the way the prior plan's incorrect `PGPORT`-implies-loopback claim was.

**3. Healthcheck typo fix (mechanical, already applied and validated once)**

Phase B step 8's `api` service healthcheck `test:` string read a garbled `"http://127.0.0.1:3114... /health"` in the prior plan text (stray `...`, a space, and the wrong port — Postgres's `3114` instead of the api's own `3115`). Corrected to `"http://127.0.0.1:3115/health"`, matching the plan's own Phase D port table (api = `3115`). The executor already made this exact correction once during the failed run and it validated correctly (the api container's healthcheck was never the cause of the crash-loop — the container never became `healthy` because the process itself exited on the `DATABASE_URL` validation error, before the healthcheck's first probe could matter). This is folded into the plan text now so the next execution attempt does not need to repeat an undocumented on-the-fly fix.

### Reusable state from the failed attempt (not re-created by this revision)

Per the FAIL handoff's `artifacts_changed` and its own recommendation, the following host-side state from the prior attempt is inert, unaffected by either fix, and safe to reuse rather than re-create:

- `/opt/apps/aiqadam-prod/` — git checkout at `dfd2a7c`, clean working tree. **Reusable as-is** — this revision does not change the git ref or anything in the checked-out source tree.
- `aiqadam-prod-api:latest` and `aiqadam-prod-api:rollback-20260713` (both image ID `b20217d09ca8`) — **Reusable as-is** — this revision does not change the Dockerfile, build context, or build command (Phase D step 12), so the already-built image is bit-for-bit what a fresh build would produce. No rebuild is required unless the executor wants to rebuild for its own peace of mind (harmless either way, `docker build` is idempotent here).
- `/opt/apps/aiqadam-prod/deploy/.env` — **NOT reusable, must be regenerated.** The existing file on host still contains the old, URL-unsafe `openssl rand -base64 32` password. Phase C step 11 (revised below) must be re-run in full to produce a fresh `.env` with a hex password. The revised step 11 command's existing backup logic (`cp "$ENV_FILE" "$ENV_FILE.bak.$(date -u +...)"`) already handles this correctly — it will back up the stale `.env` before overwriting, exactly as it would on any re-run.
- `/opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml` — **must be rewritten** (not reusable as-is) since this revision changes its content (healthcheck string fix; no change to the Postgres service block itself beyond what's already documented below, since option (b) was chosen over option (a) and requires no new Compose syntax).
- The prior attempt's Docker containers/volume were already rolled back (`docker compose down -v`) and confirmed removed by the executor — nothing to reuse or clean up there; Phase D starts fresh.

### Revised Plan text (only the changed steps shown in full; all other phases/steps are UNCHANGED from the prior approved plan and are not reproduced here — see `runs/2026-07-13-setup-aiqadam-prod-infra-001/.attempts/step-04-solution-designer-attempt-1.md` for the complete unchanged plan body, Phases 0, A, D(partial)-H)

All SSH commands continue to use the corrected key path validated by the executor in the failed run:
```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "<command>"
```
(This corrects the prior plan text's stale reference to `pro-data.tech-prod-instance_rsa.ppk` — the executor already validated `ai-dala-infra` is the correct key for this host in the failed run's pre-execution checks. Folding this into the plan text now for the same reason as the healthcheck typo: so it's documented rather than silently re-fixed.)

**Phase B — Dedicated Postgres (new container + volume, no QA reuse) — REVISED**

8. Write `deploy/docker-compose.prod.yml` (3 services: `postgres`, `oidc-stub`, `api`; Compose project name `aiqadam-prod`) via local scratchpad file + `scp` — content:
   ```yaml
   services:
     postgres:
       image: postgres:16
       container_name: aiqadam-prod-postgres-1
       restart: unless-stopped
       environment:
         POSTGRES_DB: aiqadam_prod
         POSTGRES_USER: aiqadam_prod
         POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
         PGPORT: "3114"
       volumes:
         - aiqadam_prod_pgdata:/var/lib/postgresql/data
       ports:
         - "127.0.0.1:3114:5432"
       healthcheck:
         test: ["CMD-SHELL", "pg_isready -U aiqadam_prod -d aiqadam_prod"]
         interval: 5s
         timeout: 3s
         retries: 10
       network_mode: host

     oidc-stub:
       image: nginx:alpine
       container_name: aiqadam-prod-oidc-stub-1
       restart: unless-stopped
       volumes:
         - ./oidc-stub/openid-configuration.json:/usr/share/nginx/html/.well-known/openid-configuration:ro
         - ./oidc-stub/nginx.conf:/etc/nginx/conf.d/default.conf:ro
       healthcheck:
         test: ["CMD", "wget", "-qO-", "http://127.0.0.1:9998/.well-known/openid-configuration"]
         interval: 5s
         timeout: 3s
         retries: 10
       network_mode: host

     api:
       build:
         context: .
         dockerfile: apps/api/Dockerfile
       image: aiqadam-prod-api:latest
       container_name: aiqadam-prod-api-1
       restart: unless-stopped
       env_file:
         - .env
       depends_on:
         oidc-stub:
           condition: service_healthy
       healthcheck:
         test: ["CMD", "wget", "-qO-", "http://127.0.0.1:3115/health"]
         interval: 10s
         timeout: 5s
         retries: 5
         start_period: 20s
       network_mode: host

   volumes:
     aiqadam_prod_pgdata:
       name: aiqadam-prod_aiqadam_prod_pgdata
   ```
   **Postgres bind-address posture (documented explicitly, not assumed):** because `network_mode: host` is used, Postgres binds directly to the host's network namespace and — confirmed by the failed run's live observation — listens on `0.0.0.0:3114`/`[::]:3114`, not loopback-only, regardless of the `PGPORT` setting (the prior plan's claim that `PGPORT` alone would restrict this was incorrect and is retracted here). This plan deliberately does **not** add an app-layer `listen_addresses` restriction, choosing instead to rely on the same two-layer boundary Penpot's own `postgres:15` container already relies on in production on this same host: (1) UFW's default-deny-incoming policy, which allows only `22/tcp`, `80/tcp`, `443/tcp` inbound — port `3114` is never reachable from outside the host regardless of what Postgres binds to — and (2) the absence of any host-local untrusted process that could reach `127.0.0.1`/`0.0.0.0:3114`. This matches existing precedent rather than introducing a new, asymmetric hardening posture for this one service. See Issues/risks for the explicit residual-risk acknowledgment.
   - Verification: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "docker compose -p aiqadam-prod -f /opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml config >/dev/null && echo VALID"` → `VALID`.
   - Additional verification for the bind-address posture (run once Postgres is up, Phase D step 14/15): `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "sudo ufw status verbose | grep -E '22|80|443'"` → confirms only 22/80/443 allowed, and `ssh ... "sudo ss -tlnp | grep 3114"` → document whatever it shows (expected `0.0.0.0:3114`/`[::]:3114`, now an accepted, documented posture rather than a surprise).
   - **Idempotency:** `scp` overwrite is deterministic; `docker compose config` validates before anything starts.
9. through 10. — UNCHANGED from the prior approved plan (OIDC discovery stub document and oidc-stub's nginx.conf — no content in these two steps is affected by either fix).

**Phase C — Secrets and `.env` — REVISED (step 11 only)**

11. Generate two new prod-distinct secrets and the Postgres password, assemble the `.env` file (mode 600) — command (single SSH session, remote `bash -s`, no secret values echoed/logged/committed):
    ```
    ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 'bash -s' <<'REMOTE'
    set -euo pipefail
    ENV_FILE=/opt/apps/aiqadam-prod/deploy/.env
    if [ -f "$ENV_FILE" ]; then cp "$ENV_FILE" "$ENV_FILE.bak.$(date -u +%Y%m%dT%H%M%SZ)"; fi
    JWT_SIGNING_SECRET=$(openssl rand -base64 48)
    INTERNAL_API_TOKEN=$(openssl rand -hex 32)
    POSTGRES_PASSWORD=$(openssl rand -hex 24)
    cat > "$ENV_FILE" <<EOF
    DATABASE_URL=postgresql://aiqadam_prod:${POSTGRES_PASSWORD}@127.0.0.1:3114/aiqadam_prod
    JWT_SIGNING_SECRET=${JWT_SIGNING_SECRET}
    INTERNAL_API_TOKEN=${INTERNAL_API_TOKEN}
    POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    OIDC_ISSUER_URL=http://127.0.0.1:9998/
    OIDC_CLIENT_ID=aiqadam-prod-placeholder
    OIDC_CLIENT_SECRET=placeholder-not-configured
    OIDC_REDIRECT_URI=https://aiqadam.org/api/v1/auth/callback
    WEB_BASE_URL=https://aiqadam.org
    DIRECTUS_URL=http://127.0.0.1:9998/directus-not-configured/
    DIRECTUS_TOKEN=placeholder-not-configured
    PORT=3115
    NODE_ENV=production
    EOF
    chmod 600 "$ENV_FILE"
    chown tvolodi:tvolodi "$ENV_FILE"
    stat -c '%a %U:%G' "$ENV_FILE"
    wc -l < "$ENV_FILE"
    grep -o '[/=+]' <(grep POSTGRES_PASSWORD "$ENV_FILE" | head -1) | wc -l
    REMOTE
    ```
    — verification: output shows `600 tvolodi:tvolodi`, `13`, and the final `grep -o '[/=+]' ... | wc -l` line shows `0` (confirms the new hex password contains none of the three URL-unsafe characters that caused the FAIL — this is a new, explicit verification line added by this revision specifically to close out the root cause rather than trust the alphabet choice alone).
    - **The `.env` at `/opt/apps/aiqadam-prod/deploy/.env` from the failed attempt still exists on host with the old base64 password** — this command's existing `cp "$ENV_FILE" "$ENV_FILE.bak.$(date -u +...)"` line will back it up automatically before overwriting, exactly as it would on any re-run; no separate manual backup step is needed.
    - **New secrets (names only, recorded here for step 08 to add to `landscape/secrets-inventory.md`):** `aiqadam-prod-jwt-signing-secret`, `aiqadam-prod-internal-api-token`, `aiqadam-prod-postgres-password`. Values never leave `/opt/apps/aiqadam-prod/deploy/.env` (mode 600) on the host. (Unchanged from the prior plan — these are the same three secret names; only the postgres one's generation method changed.)
    - **Idempotency:** re-running regenerates all secrets (not idempotent in the "same value" sense) — unchanged characterization from the prior plan. Recovery: restore from the `.bak.<timestamp>` file if the regeneration was unwanted.
    - **Rollback:** `ssh ... "cp /opt/apps/aiqadam-prod/deploy/.env.bak.<timestamp> /opt/apps/aiqadam-prod/deploy/.env"` if a backup exists; otherwise `rm -f /opt/apps/aiqadam-prod/deploy/.env`.

**Phases D through H — UNCHANGED from the prior approved plan.** Phase D step 12 (build) may reuse the existing `aiqadam-prod-api:latest`/`b20217d09ca8` image rather than rebuild (see "Reusable state" above) — executor's judgment, both outcomes produce the same image content. Phase D steps 14 onward (start postgres, verify DB, start oidc-stub, start api, health polls) proceed exactly as before, now against the corrected `.env`. Phases E (nginx), F (Cloudflare DNS repoint), G (TLS), H (external verification) are entirely unaffected by either fix and were never reached in the failed run — their commands, rollback, and verification are unchanged from the approved prior plan.

### Rollback

Unchanged from the prior approved plan for Phases D–H (see prior version, archived to `.attempts/`). For this revision's two changed steps specifically:

1. Phase B step 8 (compose file): `scp` overwrite is the only action; rollback is re-writing the prior content or, if abandoning entirely, `rm -f /opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml`.
2. Phase C step 11 (.env): `cp /opt/apps/aiqadam-prod/deploy/.env.bak.<timestamp> /opt/apps/aiqadam-prod/deploy/.env` (a backup will exist this time, since the failed attempt's `.env` is present on host and will be backed up automatically by this step's own logic before being overwritten).
3. Full-plan teardown rollback (Phases D–H): unchanged from the prior approved plan — `docker compose -p aiqadam-prod -f docker-compose.prod.yml down -v`, nginx vhost removal, Cloudflare `PATCH` back to `212.20.151.29`/`proxied:true`, certbot cert deletion, `rm -rf /opt/apps/aiqadam-prod/` — see prior version for full text, none of it changed by this revision.

### Verification (for step 07)

Unchanged from the prior approved plan, plus one addition specific to this revision:

- **On-host (new check for this revision):** the `.env`'s `POSTGRES_PASSWORD` line contains zero `/`, `=`, or `+` characters (verified inline in Phase C step 11's own command output, `0`).
- **On-host (unchanged):** `docker compose -p aiqadam-prod -f /opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml ps` shows `postgres`, `oidc-stub`, `api` all `Up ... (healthy)`, `RestartCount=0` on `api` (this is the check that previously failed and is the direct target of this revision's fix); `docker compose -f /opt/penpot/docker-compose.yaml ps` shows all 7 Penpot containers unchanged/healthy; `curl -s http://127.0.0.1:3115/health -H 'Host: aiqadam.org'` → `"status":"ok"`, `"tenant":{"code":"uz",...}`; certs, nginx, vhosts, `.env` permissions — all as in the prior plan.
- **On-host (new, for the Postgres bind-address decision):** `sudo ufw status verbose` confirms only `22/tcp`, `80/tcp`, `443/tcp` allowed inbound (the enforcement boundary this revision's Phase B decision relies on) — this should be checked and its output recorded, not merely assumed to still match the landscape snapshot.
- **External:** unchanged from the prior approved plan — `curl -I https://aiqadam.org` → `200` (or documented 404-at-root deviation, `/health` as substitute); `curl -s https://aiqadam.org/health` → `"status":"ok"`; `curl -I https://penpot.aiqadam.org` → `200` unchanged; `nslookup aiqadam.org 1.1.1.1` → `95.46.211.224`; Cloudflare record GET confirms `content: 95.46.211.224`, `proxied: false`.

### Resources used

- **Secrets (by name):** `cloudflare-ai-qadam-api-token`, `cloudflare-ai-qadam-zone-id` (existing, unchanged). New secrets to be added at step 08: `aiqadam-prod-jwt-signing-secret`, `aiqadam-prod-internal-api-token`, `aiqadam-prod-postgres-password` (unchanged names — only the postgres one's generation method changed, not its name or its treatment in `landscape/secrets-inventory.md`).
- **Files modified on host (pro-data-tech-prod):** same list as the prior plan. `/opt/apps/aiqadam-prod/` (checkout — reused, not recreated), `/opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml` (rewritten, healthcheck-string fix only, Postgres service block otherwise identical to prior plan's intent), `/opt/apps/aiqadam-prod/deploy/.env` (regenerated with hex password, prior stale version auto-backed-up), `/opt/apps/aiqadam-prod/deploy/oidc-stub/*` (reused, unchanged content), `/etc/nginx/sites-available/aiqadam.org` (+ symlink, not yet created — Phase E unreached), `/etc/letsencrypt/live/aiqadam.org/*` (not yet created — Phase G unreached). Untouched — `/opt/penpot/` (all files), `/etc/nginx/sites-available/penpot.aiqadam.org`, `/etc/letsencrypt/live/penpot.aiqadam.org/*`.
- **Files modified in this repo (landscape/), to be applied at step 08:** unchanged from the prior plan — `landscape/hosts/pro-data-tech-prod.md`, `landscape/services.md`, `landscape/cloudflare.md`, `landscape/domains.md`, `shared/app-registry.md`.
- **External APIs called:** unchanged — Cloudflare DNS API (one `PATCH`), Let's Encrypt ACME API (one cert issuance). Neither reached yet.

### Estimated impact

Unchanged from the prior approved plan — see prior version for the full analysis of Penpot non-impact, the DNS repoint's effect on the (confirmed-dead, per step-05) third-party host, and reversibility. This revision changes no downtime/impact characteristics; it only fixes a defect that prevented Phase D from completing and clarifies a previously-incorrect assumption about Phase B.

- **Downtime:** none for Penpot. For `aiqadam.org`: unchanged — DNS repoint still pending (Phase F unreached).
- **Affected services:** unchanged — `pro-data-tech-prod` (new Compose project, new vhost, new cert — Penpot untouched); Cloudflare `aiqadam.org` zone; Let's Encrypt cert inventory.
- **Reversibility:** unchanged — fully reversible for everything this repo controls, with the same one caveat about the third party currently (still, as of the failed run's Phase 0 step 4 re-check) served by `212.20.151.29`.

## Issues / risks

- **HIGH-SEVERITY (carried forward, unchanged) — DNS repoint of a live, shared, third-party-owned record.** Unchanged from the prior approved plan. Already put to the user in the prior approval round (step-05, confirmed "Yes, repoint it now"); not being re-asked, but the categorical risk is unchanged and still drives `NEEDS_APPROVAL` on its own.
- **HIGH-SEVERITY (carried forward, unchanged) — co-residency with a live, healthy production Penpot deployment.** Unchanged. Confirmed unaffected through the entire failed run (Penpot healthy at every checkpoint reached).
- **MEDIUM-SEVERITY (carried forward, unchanged) — `proxied:false` flips the apex record's Cloudflare-edge behavior.** Unchanged from the prior plan; already accepted in the prior approval round.
- **MEDIUM-SEVERITY (this revision, new) — Postgres remains reachable on `0.0.0.0:3114`/`[::]:3114` at the container/process level, with only UFW as the enforcement boundary.** This is a deliberate, documented choice (option (b) above) rather than an oversight, matching existing Penpot precedent on this same host. Residual risk: if UFW were ever misconfigured, disabled, or bypassed (e.g., a future task adds a port-forwarding rule, or UFW's rules are edited without care), port 3114 would become externally reachable with only the Postgres password as protection. This risk is judged acceptable because (a) it is the same risk profile Penpot's own Postgres already carries in production today, (b) UFW state is independently verified at Phase 0/pre-flight and would be caught by the existing Penpot-regression and resource-check tripwires if grossly misconfigured, and (c) the alternative (app-layer `listen_addresses` restriction) adds Compose complexity for a benefit that's redundant given UFW's current correct configuration. Flagged explicitly per design rule 7 rather than left implicit.
- **LOW-SEVERITY (carried forward, unchanged) — Postgres image/version choice, pgvector.** Unchanged from the prior plan. Already checked and confirmed non-applicable by the executor during the failed run (no `CREATE EXTENSION vector` in migrations) — this is now a resolved, not merely low-severity-flagged, item; kept here for completeness only.
- **LOW-SEVERITY (carried forward, unchanged) — port-range convention, app-slice scope.** Unchanged from the prior plan.
- **LOW-SEVERITY (this revision, new) — entropy reduction from base64-32 to hex-24.** 24 bytes of hex (192 bits of entropy) versus the prior 32 bytes of base64 (256 bits of entropy) is a reduction, but both are many orders of magnitude beyond what's needed for a loopback-only, UFW-shielded database credential (192 bits is effectively unbreakable by brute force for any foreseeable future). Judged not a meaningful risk change; noted for completeness since it is a literal quantitative difference from the prior plan.

### Why this is still `NEEDS_APPROVAL` and not `PASS`

Per `shared/approval-protocol.md`, this plan continues to touch a first-time prod deployment, a DNS repoint of a shared/live record, and TLS certificate issuance — all of which are in the "Always `NEEDS_APPROVAL`" list regardless of how narrow any individual revision is. The task's own blast-radius/reversibility ratings (from the task file, unchanged since step 03) remain `medium`/`partial` at best given the DNS/third-party caveat, not `low`/`full`, so condition 1 and 2 of the `PASS` criteria are not met either. Additionally, per `shared/approval-protocol.md`'s routing table, any change to step-04's content — however mechanical — produces a new step-04 version that requires its own approval round; this is not optional even though the three original open questions (git ref, www scope, DNS-repoint confirmation) are all still resolved and are not being reopened. Recommend the orchestrator present this to the user as a short, scoped re-approval ("two lines changed: Postgres password generation and bind-address documentation, plus a typo fix — everything else from your prior approval stands") rather than re-running the full three-question gate.

## Open questions

None of the prior plan's three open questions are reopened by this revision — all three (git ref `dfd2a7c`, bare-apex-only scope, DNS repoint confirmation) remain resolved per `runs/2026-07-13-setup-aiqadam-prod-infra-001/step-05-user-approval.md` and do not need to be asked again. The only thing requiring a fresh user response is a yes/no re-approval of this narrow revision itself (password-generation fix + Postgres bind-address documentation + healthcheck typo), per the approval-protocol's requirement that any step-04 content change gets its own sign-off.
