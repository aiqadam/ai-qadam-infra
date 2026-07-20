---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 06
agent: executor-infra
verdict: BLOCKED
created: 2026-07-19T03:45:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-06
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-1.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - landscape/cloudflare.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: "Solution-designer must re-author Phase 3 (Plan steps 12-13) and Phase 6 (Plan step 27) before any re-execution. Stalwart v0.16's actual non-interactive-setup mechanism is NOT a REST/JMAP 'setup API' reachable by ad-hoc curl calls against a running bootstrap-mode instance, as Plan step 12 assumed. Empirically confirmed and documented in this handoff: (a) no stalwart-cli binary exists in the stalwartlabs/stalwart:v0.16 image -- only a single stalwart binary with options-only flags (-c/-e/-i/-o/-h/-V), no subcommands; (b) the JMAP endpoint (/jmap/) is live and accepts well-formed requests, but neither a documented 'Bootstrap' JMAP object/method nor a working Principal/set-based domain-creation call could be found -- Bootstrap/get, Bootstrap/set, and Sys/bootstrap all returned clean unknownMethod errors, and Principal/set with {type:domain} returned a notRequest parse rejection even with valid JSON; (c) Stalwart's own official docs (stalw.art/docs/configuration/bootstrap-mode/, .../declarative-deployments, .../recovery-mode) confirm the two sanctioned non-interactive paths are either the interactive setup wizard (explicitly 'the recommended path'), or hand-authoring config.json plus stalwart-cli apply against a JSON plan in recovery mode -- and that CLI binary is not present in this image. Re-design options to consider: (1) use the interactive web setup wizard and have the executor drive it via a scripted browser/HTTP-form-post session (a materially different, more complex execution technique than 'call the admin API', needs explicit design and approval), (2) pre-author config.json directly and start Stalwart with STALWART_RECOVERY_MODE=1 to reach a state where the missing CLI capability isn't needed (needs the exact config.json schema for domains/DKIM researched and specified in the plan, not left as an execution-time detail), (3) investigate whether a stalwart-cli binary can be obtained/installed separately (a new artifact/dependency the current plan does not account for). Do not re-attempt this run's approach unchanged."
---

## Summary
Executed Phase 0 pre-flight (all 4 checks passed, including the new orphaned-cert confirmation) and Phase 1 install through Plan step 7a (container up, healthy, image `stalwartlabs/stalwart:v0.16` pinned and resolved correctly) successfully, but halted before Plan step 9's checkpoint when Plan step 12 (admin setup/domain/DKIM configuration) proved undiscoverable against the live instance after thorough good-faith investigation -- no working non-interactive setup mechanism (CLI or JMAP) could be found matching what the plan assumed exists; rolled back the Compose install fully, confirmed Penpot and AiQadam-prod unregressed, and the host is back to its pre-run state (the attempt-1 orphaned cert remains, untouched, exactly as Phase 0 step 4 found it).

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes (`step-05-user-approval.md` `inputs_read` lists `runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md`; step-04 verdict was `NEEDS_APPROVAL`)

### Execution log

#### Phase 0, step 1: Re-probe dead host mail ports (fresh, not assumed from attempt 1)
- Command: `Test-NetConnection 212.20.151.29 -Port 25` (PowerShell, management workstation)
- Exit code: 0
- Output (trimmed): `TcpTestSucceeded: False` (DestinationHostUnreachable)
- Command: `Test-NetConnection 212.20.151.29 -Port 993`
- Exit code: 0
- Output (trimmed): `TcpTestSucceeded: False` (DestinationHostUnreachable)
- Result: success -- old host confirmed still dead on both ports. Gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 2: DNSBL check of 95.46.211.224
- Commands: `nslookup 224.211.46.95.zen.spamhaus.org`, `nslookup 224.211.46.95.bl.spamcop.net`, `nslookup 224.211.46.95.b.barracudacentral.org`
- Exit code: 0 (all three)
- Output (trimmed): all three `Non-existent domain` (NXDOMAIN) -- not listed on any of the three DNSBLs.
- Result: success -- gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 3: Confirm no listener on mail ports on pro-data-tech-prod
- Command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "sudo ss -tlnp | grep -E ':(25|465|587|993|443|8080)\b' || echo NO_MATCHING_LISTENERS"`
- Exit code: 0
- Output (trimmed): only `0.0.0.0:443` (nginx) present; nothing on 25/465/587/993/8080.
- Result: success -- gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 4 (new this retry): Confirm orphaned cert from attempt 1 still exists
- Command: `ssh ... tvolodi@95.46.211.224 "sudo certbot certificates -d mail.aiqadam.org"`
- Exit code: 0
- Output (trimmed):
  ```
  Certificate Name: mail.aiqadam.org
    Serial Number: 5f82cf10d760f44f1bc0ae836cf12b41aa8
    Key Type: ECDSA
    Domains: mail.aiqadam.org
    Expiry Date: 2026-10-17 02:14:38+00:00 (VALID: 89 days)
  ```
- Result: success -- cert confirmed present and valid as the plan's Decision G assumed. Gate passed. All four Phase 0 checks cleared; proceeded to Phase 1.
- Backup taken: n/a (read-only)

#### Pre-run baseline capture (mandatory no-regression checkpoint baseline, before any state change)
- Command: `docker ps --filter label=com.docker.compose.project=penpot --format '{{.Names}}: {{.Status}}'`
- Output: 7/7 containers `Up` (backend, frontend, exporter, postgres-healthy, mailcatch, mcp, valkey-healthy)
- Command: `docker ps --filter label=com.docker.compose.project=aiqadam-prod --format '{{.Names}}: {{.Status}}'`
- Output: 4/4 containers `Up` (web-next, api-healthy, oidc-stub-healthy, postgres-healthy) -- matches attempt 1's noted pre-existing discrepancy vs. the 3-container landscape documentation; recorded as this run's own baseline per the plan's explicit instruction, not investigated further.
- Result: baseline captured for later comparison.

#### Plan step 5: Create Compose directory and split data/config directories
- Command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /opt/stalwart-mail /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown -R 2000:2000 /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown tvolodi:tvolodi /opt/stalwart-mail"`
- Exit code: 0
- Output: `ls -la /opt/stalwart-mail` showed `etc-stalwart`/`var-lib-stalwart` owned `2000:2000`; parent owned `tvolodi:tvolodi`.
- Result: success
- Backup taken: n/a (new directories, no prior state)

#### Plan step 6: Generate admin recovery password and test-account password
- Command: `openssl rand -base64 24` (admin), `openssl rand -base64 18` (test account) -- generated locally in an ephemeral shell, values not persisted to any file in this repo.
- Result: success. Secret names recorded: `stalwart-mail-admin-password`, `stalwart-mail-test-account-password`. (Test-account password generated but never used -- Phase 6/Plan step 27 was never reached.)
- Backup taken: n/a

#### Plan step 7: Write docker-compose.yml and .env
- Command: authored `docker-compose.yml` locally (exact content from Plan step 7's spec -- project name `stalwart-mail`, image `stalwartlabs/stalwart:v0.16`, ports 25/465/587/993 on `0.0.0.0`, 8080 on `127.0.0.1` only, volumes `/opt/stalwart-mail/etc-stalwart:/etc/stalwart` + `/opt/stalwart-mail/var-lib-stalwart:/var/lib/stalwart`, `STALWART_RECOVERY_ADMIN=admin:${STALWART_ADMIN_PASSWORD}`), `scp`'d to host, verified via `cat` diff -- exact match.
- Command: `.env` written via `install -m 600 /dev/stdin /opt/stalwart-mail/.env` over an SSH heredoc (value never touched local disk or shell history).
- Exit code: 0 (both)
- Output: `ls -la /opt/stalwart-mail/.env` -> `-rw------- 1 tvolodi tvolodi 57` ; non-empty confirmed via `test -s`.
- Result: success
- Backup taken: n/a (new files, no prior state)

#### Plan step 8: Bring up Compose project
- Command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose up -d"`
- Exit code: 0
- Output (trimmed): image `stalwartlabs/stalwart:v0.16` pulled successfully (4 layers, ~90MB total) -- **pinning discipline confirmed intact, no substitution needed, unlike attempt 1's failure class.** Container `stalwart-mail-server-1` created and started.
- Result: success
- Verification: `docker compose -p stalwart-mail ps` -> `stalwart-mail-server-1` `Up 6 seconds (healthy)`, ports bound as declared (25/465/587/993 on 0.0.0.0+::, 8080 on 127.0.0.1 only). `docker logs stalwart-mail-server-1 --tail 50` showed `Server started in bootstrap mode`, version `0.16.13`, `Port 8080 is open for initial setup` -- no fatal errors, no crash loop. Grepped logs for password/recovery/admin: only a benign `http-recovery` listener-start log line, **no randomly-generated-password banner** -- confirms the deterministic `STALWART_RECOVERY_ADMIN` credential path was used, per verification criteria.
- Backup taken: n/a (new container, no prior state)

#### Plan step 7a: Admin UI path verification (Decision H)
- Command: `ssh ... tvolodi@95.46.211.224 "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/"`
- Exit code: 0
- Output: `302` -> `Location: /account`
- Result: success. Resolved path recorded: root (`/`) redirects to `/account`, served by a client-side-routed SPA ("Portal", bundle `index-4bQTQ0fA.js`) that also serves identically at `/admin/`. Confirms Decision H's nginx-proxies-bare-root approach was the correct choice -- there is no separate fixed `/admin` path distinct from the SPA's own client-side routing.

#### Plan step 12: Admin setup -- domain configuration, DKIM enable, 587 listener enable -- HALTED, could not be completed
- **Investigation performed (read-only against the live instance, per the plan's explicit instruction to discover the actual API surface live):**
  1. Checked container binary for a CLI subcommand interface: `docker exec stalwart-mail-server-1 /usr/local/bin/stalwart --help` -> only `-c/-e/-i/-o/-h/-V` flags, no subcommands (e.g., no `apply`, no `account`, no `domain`). Confirmed via `find / -iname "*stalwart*" -type f` inside the container that only one binary (`/usr/local/bin/stalwart`) exists -- **no separate `stalwart-cli` binary is packaged in this image.**
  2. Authenticated to the admin HTTP interface via Basic auth (`admin:<STALWART_ADMIN_PASSWORD>`, header-based, never placed in a URL) -- confirmed working: `GET /api/account` -> `200`, `{"permissions":["sysBootstrapGet","sysBootstrapUpdate"],"edition":"community","locale":"POSIX"}` (confirms the account is in bootstrap-restricted mode, as Stalwart's docs describe for first-boot).
  3. Fetched the UI's internal form/object schema via `/api/schema/<token>` (a real endpoint, found via the webui JS bundle) -- this is a **UI-form-rendering schema** (`objects`/`schemas`/`forms`/`fields`/`lists`/`enums`/`dashboards`/`layouts` keys), not an OpenAPI/REST route map. It does list object type names including `x:Bootstrap`, `x:Domain`, `x:DkimSignature`, `x:DkimManagement`, but does not expose the HTTP method/path bindings needed to actually call them.
  4. Probed the `/jmap/` endpoint directly (discovered via `/.well-known/jmap` session discovery): confirmed live and responsive to well-formed JMAP requests. `Principal/query` succeeded (returned an empty principal list, as expected pre-setup). `Principal/set` with `{"create":{"d1":{"type":"domain","name":"aiqadam.org"}}}` returned `notRequest` (payload/shape rejected) even with clean, file-uploaded JSON (ruled out shell-escaping as the cause). Guessed bootstrap-specific method names `Bootstrap/get`, `Bootstrap/set`, `Sys/bootstrap` all returned clean, well-formed `unknownMethod` JMAP protocol errors -- confirming the server correctly parses JMAP but does not recognize any of these as real methods.
  5. Consulted Stalwart's own official documentation (stalw.art/docs) via web search and fetch: confirmed v0.16 bootstrap mode "serves only the WebUI and the management API, with the JMAP API restricted to a single object type: Bootstrap" and that "the setup wizard is the recommended path for new deployments... it validates every choice interactively." For automation, the docs describe exactly two sanctioned non-interactive paths: (a) the interactive setup wizard itself (not scriptable via simple curl calls -- it's a stateful, form-driven wizard flow), or (b) hand-authoring `config.json` with the datastore config, starting Stalwart with `STALWART_RECOVERY_MODE=1`, then running `stalwart-cli apply < initial-plan.json` against the recovery listener -- a CLI binary **confirmed absent from this image** (see finding 1).
- **Conclusion:** Plan step 12's assumption -- "the setup wizard's actions are themselves exposed via the same admin API the web UI calls" and that the executor could "drive the setup/config API endpoints" via authenticated curl calls with exact payloads "confirmed against this running v0.16 instance's own API/OpenAPI surface at execution time" -- does not hold. There is no discoverable REST/JMAP "setup API" surface distinct from either (a) the stateful interactive wizard, or (b) a CLI tool (`stalwart-cli`) that is not present in the pinned `stalwartlabs/stalwart:v0.16` image. This is a genuine plan defect in Decision D/Plan step 12's mechanism, not a missing execution-time detail the executor could reasonably fill in -- per the plan's own Issues/risks item ("the executor should treat any 404/schema-mismatch on these calls as a signal to halt and report rather than guess further") and my task brief's explicit instruction ("If the admin API genuinely doesn't support something the plan assumes, treat that as a plan defect -- halt and report BLOCKED/FAIL... do not improvise a workaround the plan didn't approve"), I halted here rather than attempting to drive the interactive wizard via a scripted browser session or hand-author a `config.json`/DB schema the plan never specified -- either would be a materially different execution technique than what was approved.
- Result: **halted, not completed.** No domain, DKIM, or listener configuration was applied (bootstrap mode was never exited; no `config.json` was written; the DB-backed config registry remains empty).
- Backup taken: n/a -- halted before any destructive or hard-to-reverse action in this phase.

Plan steps 13 (capture DKIM key), 9 (Penpot/AiQadam-prod mid-run checkpoint -- deferred to post-rollback final checkpoint below instead), and all of Phases 2 through 9 (steps 10-11, 14-35) were **not attempted**, per "stop on first error" / halting discipline.

### Rollback executed

Per the plan's Rollback section, item 1 ("Compose install rollback, Phases 0-1, steps 5-9"):

**1. Compose install rollback:**
- Command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose down"`
- Exit code: 0. Output: container stopped, removed; network `stalwart-mail_default` removed.
- Command: `ssh ... tvolodi@95.46.211.224 "sudo rm -rf /opt/stalwart-mail && ls -la /opt/ | grep -i stalwart || echo REMOVED"`
- Exit code: 0. Output: `REMOVED` -- directory confirmed gone.
- Result: success. Per the plan's own note, `docker compose down -v` was unnecessary (host bind-mounts, not named volumes) -- plain `down` + directory removal is correct and sufficient; matches what was done.

**2. UFW rules rollback:** not needed -- Phase 2 (Plan steps 10-11) was never reached; no UFW rules were added this run.

**3. Admin setup / DKIM / ACME config rollback:** not needed -- Plan steps 12-15 never completed; bootstrap mode was never exited, no persistent config/DB state was created (the entire `/opt/stalwart-mail/var-lib-stalwart` directory, which would have held any such state, was removed wholesale by rollback item 1 above, consistent with the plan's own rollback item 3 reasoning).

**4-6. DNS / deleted-record / mailbox rollback:** not needed -- Phase 5 (DNS cutover) and Phase 6 (mailbox provisioning) were never reached. **No Cloudflare API calls of any kind were made this run** (unlike attempt 1, which did reach and roll back a DNS A-record change) -- this run halted entirely within Phase 1/3, before Phase 4 (TLS/ACME) or Phase 5 (DNS) were reached.

**7. nginx vhost rollback:** not needed -- Phase 7 (Plan step 29) was never reached; no nginx configuration was touched this run.

**8. Orphaned cert (Decision G):** confirmed untouched post-rollback -- `sudo certbot certificates -d mail.aiqadam.org` still shows the same cert (serial `5f82cf10d760f44f1bc0ae836cf12b41aa8`, expiry 2026-10-17, VALID: 89 days), unchanged from the Phase 0 step 4 confirmation at the start of this run.

Post-rollback verification: `sudo ss -tlnp | grep -E ':(25|465|587|993|8080)\b'` -> `NO_MATCHING_LISTENERS`. Host confirmed returned to its pre-run state in every respect this plan's phases could have altered.

### Resources changed
- Files on host: **none remain** -- `/opt/stalwart-mail/` was created (directory, `docker-compose.yml`, `.env` mode 600, `etc-stalwart/`, `var-lib-stalwart/`) then fully removed by rollback. Net: no residual state.
- Services restarted: none (nginx was never touched this run).
- External resources changed: **none** -- no Cloudflare API calls were made this run (this run halted before Phase 5).

### Mandatory no-regression checkpoints (Plan step 9, run both before-state capture and after-rollback final check)

**Before this run (baseline, captured after Phase 0, before any state change):**
- Penpot: 7/7 containers `Up` (backend, frontend, exporter, postgres-healthy, mailcatch, mcp, valkey-healthy) -- `Up 7 days` each.
- AiQadam-prod: 4/4 containers `Up` (web-next, api-healthy, oidc-stub-healthy, postgres-healthy).

**After rollback (final check, end of this run):**
- Penpot: `docker ps --filter label=com.docker.compose.project=penpot` -> identical 7/7 containers, same `Up 7 days` status.
- AiQadam-prod: `docker ps --filter label=com.docker.compose.project=aiqadam-prod` -> identical 4/4 containers, same status.
- External: `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` -> `200`. `Invoke-WebRequest https://aiqadam.org/health -Method Get` -> `200`.
- **No regression detected at any point.** The pre-existing 4-vs-3-documented AiQadam-prod container discrepancy (already noted by attempt 1 as out of scope) is unchanged and was not investigated or touched, consistent with "no off-plan changes."

## Issues / risks

- **Plan-blocking defect (root cause of BLOCKED), Plan step 12 / Decision D:** Stalwart v0.16's non-interactive setup mechanism is not the "call the admin HTTP API directly, confirm the exact shape at execution time" model the plan assumed. Empirically and via official documentation, confirmed to be either (a) the interactive setup wizard (a stateful, multi-step, form-driven flow -- not a small number of scriptable curl calls), or (b) hand-authored `config.json` + `STALWART_RECOVERY_MODE=1` + `stalwart-cli apply` -- and that CLI binary does not exist in the pinned `stalwartlabs/stalwart:v0.16` image. This is a materially different situation from what the plan characterized as a "MEDIUM -- exact endpoint shapes TBD at execution time" risk; the gap is not shape-level, it's mechanism-level. A future design pass needs to pick one of: scripting the interactive wizard (browser automation or reverse-engineered wizard-specific endpoints, which would need their own discovery), authoring `config.json` directly (needs the schema for domains/DKIM researched up front, not deferred), or sourcing a `stalwart-cli` binary from elsewhere (a new dependency, likely a separate package/release artifact from `stalwartlabs/stalwart`'s GitHub releases, not bundled in the server image).
- **No security or data-loss exposure from this halt.** Nothing was left running, no secrets were written anywhere persistent beyond the (now-deleted) `.env` file on the host, no DNS or Cloudflare state was touched, no cert was created or destroyed this run. The system is in exactly the state Phase 0 found it in (mail still dead at the old host, `aiqadam.org` MX/SPF/DKIM/DMARC untouched, orphaned cert from attempt 1 still present and still unused).
- **Two secrets were generated this run but never used or persisted anywhere:** `stalwart-mail-admin-password` and `stalwart-mail-test-account-password` values existed only in ephemeral SSH command contexts and the host's now-deleted `.env` file; they were never written to this repo, never logged, and are now moot (the container that would have used the admin password was destroyed). No action needed, noted for completeness -- a future re-run should generate fresh values rather than assume these are still relevant anywhere.
- **No regression to Penpot or AiQadam-prod at any point** -- confirmed via baseline capture before any state change and final checkpoint after rollback; both identical throughout.
- **Observation, off-plan, not actioned (carried over from attempt 1, still present, still out of scope):** AiQadam-prod's Compose project still shows 4 running containers vs. 3 documented in `landscape/hosts/pro-data-tech-prod.md`. Unrelated to this task, not investigated or touched.

## Open questions (optional)
- Should the next solution-design pass target the interactive setup wizard specifically (treating it as a UI-automation problem -- e.g., a headless-browser-driven flow, or reverse-engineering the wizard's own specific request sequence by watching real browser traffic against a fresh instance) rather than assuming a general-purpose "admin API" exists for bootstrap? This is a different class of execution technique (stateful UI flow vs. stateless API calls) and should be explicitly scoped and approved, not left as an execution-time detail again.
- Alternatively, should the plan pivot to the documented `config.json` + recovery-mode + `stalwart-cli apply` path? If so, the plan needs to (a) specify where a `stalwart-cli` binary would come from (it is not in the server image -- likely a separate release artifact on `stalwartlabs/stalwart`'s GitHub releases, needs verification), and (b) research and specify the exact `config.json`/JSON-plan schema for domains, DKIM, and listener configuration up front, rather than deferring "exact shape" to execution time as this attempt's plan did.
- The empirical findings in this handoff (no CLI in-image, JMAP Bootstrap/domain methods not found by name-guessing, `Principal/set` with `type:domain` rejected) are a starting point for the next design pass's research, not a complete negative proof -- a more exhaustive investigation (e.g., inspecting Stalwart's server source on GitHub for the actual wizard-backing endpoint names, or capturing real browser network traffic against the wizard) could still surface a working non-interactive path. Recommend the next solution-designer pass do that research explicitly rather than re-delegating "confirm at execution time" to the executor again, since this attempt already demonstrated that execution-time discovery alone was insufficient.
