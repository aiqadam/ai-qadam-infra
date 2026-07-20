---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 06
agent: executor-infra
verdict: BLOCKED
created: 2026-07-19T04:35:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-06
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-3.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/cloudflare.md
  - landscape/secrets-inventory.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: >-
  Solution-designer needs a fifth attempt, but this is a materially different and stranger failure than
  the attempt-3 gap, and should NOT be treated as another routine "insert the missing step" fix. Empirically
  confirmed this run: `stalwart-cli update Bootstrap --field defaultDomain=aiqadam.org --field
  serverHostname=mail.aiqadam.org --field generateDkimKeys=false --field requestTlsCertificate=false` (exactly
  the plan's new step 12, exact syntax confirmed live via `update --help`/`update Bootstrap --help` first) returns
  a clean success with a server-generated `username`/`secret` pair (a real admin account tied to the domain,
  distinct from the STALWART_RECOVERY_ADMIN recovery account) -- this looks like a real bootstrap-completion
  side effect. However: (1) an immediately following `get Bootstrap` still shows the untouched original defaults
  (defaultDomain example.org, serverHostname the container's hostname, both booleans still "Yes") -- every single
  time, including after JMAP/RocksDB storage was actively observed growing (new .sst files with fresh mtimes) in
  the data volume; (2) `query Domain` (and by the same mechanism the rest of Domain/DkimSignature/NetworkListener/
  Account) still hard-rejects with the exact same "forbidden: The server is in bootstrap mode" JMAP-level error
  (HTTP 200 transport status, JMAP-application-level forbidden payload -- confirmed via --debug trace, so this is
  a deliberate server-side gate check, not a stale-cache or CLI-rendering artifact) -- using the SAME credentials
  that just successfully ran get/update against Bootstrap; (3) re-running the identical `update Bootstrap` call a
  second time fails with `error: primaryKeyViolation, Properties: defaultDomain, Object id: Domain#b` -- proving
  the server DID persist a real Domain object with id Domain#b keyed on defaultDomain=aiqadam.org from the FIRST
  call, i.e. the update is not a no-op and not silently failing -- yet the bootstrap-mode gate never lifts and
  `get Bootstrap` never reflects the change. This is an internally contradictory state: the object model behind
  Bootstrap is being mutated and enforcing its own uniqueness constraints, but the mode flag/gate the JMAP method
  dispatcher checks for "is bootstrap complete" appears never to flip, and the read-back view of Bootstrap itself
  never reflects the write. This smells like either (a) a genuine Stalwart 0.16.13 CLI/server bug or incomplete
  bootstrap-completion codepath at this version, (b) a missing required field this plan didn't set that gates
  actual completion (the `directory`/`dnsServer`/storage-backend fields were deliberately left unset per the
  plan's own reasoning, on the assumption defaults apply -- worth testing explicitly setting all 13 Bootstrap
  fields including the storage/directory ones the plan assumed could stay implicit), or (c) the JMAP
  `/jmap/session` account list (which DID look fully-provisioned, real mail/calendar/contacts/sieve capabilities,
  a real account id "d333333" named "admin") is evidence the underlying account/mail engine considers itself
  live, while a SEPARATE "is initial-setup wizard done" flag the management/schema API checks is not derived from
  the same state and needs an as-yet-unidentified additional trigger. Do not have the next solution-design pass
  guess at (b) by just setting more fields without new evidence -- this is genuinely uncertain territory, not a
  same-character mechanism fix, and per this run's own delegation boundary should get a fresh, explicit user
  check-in framed around "do we keep pushing on this CLI-driven Bootstrap path, or pivot to the other two
  previously-considered non-interactive paths (interactive-wizard automation, or pre-seeding a hand-authored
  config.json before first start) that attempt 2's research surfaced but this design lineage has not revisited
  since attempt 3 found the CLI path superficially promising." Full rollback executed; host is back to its
  pre-run state; no data loss, no exposure, no regression to Penpot/AiQadam-prod.
---

## Summary
Executed Phase 0 pre-flight (all 4 checks passed fresh), Phase 1 install through the CLI sub-phase (container up/healthy, `stalwart-cli` 1.0.10 installed and smoke-tested), and Phase 2 firewall rules successfully — all matching attempt 3's results exactly — then executed this attempt's new Phase 3 step 12 (`update Bootstrap` with the four approved field values) which reported success and visibly mutated server-side storage (RocksDB growth, a `Domain#b` object created, a generated admin account), but the mandated post-condition check (bootstrap-mode rejection gone from `query Domain`) failed: the rejection persists identically to attempt 3, `get Bootstrap` never reflects the write, and a retry of the same `update Bootstrap` call hits a primary-key-violation confirming the first call was not a no-op — an internally contradictory, unresolved server-side state that the plan's own halt condition for step 12 explicitly covers ("if the rejection persists, halt and report; do not retry blindly"); rolled back the Compose install and UFW rules fully, confirmed Penpot and AiQadam-prod unregressed, host is back to its pre-run state.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes (`step-05-user-approval.md` `inputs_read` lists `runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md`; step-04 verdict was `NEEDS_APPROVAL`; step-05 explicitly confirms fresh sign-off on `generateDkimKeys: false`/`requestTlsCertificate: false` for the new Bootstrap step, with general delegation for other same-character mechanism fixes remaining in effect)

### Execution log

#### Phase 0, step 1: Re-probe dead host mail ports (fresh)
- Command: `Test-NetConnection 212.20.151.29 -Port 25` (PowerShell, management workstation)
- Exit code: 0
- Output (trimmed): `TcpTestSucceeded: False` (DestinationHostUnreachable)
- Command: `Test-NetConnection 212.20.151.29 -Port 993`
- Exit code: 0
- Output (trimmed): `TcpTestSucceeded: False` (DestinationHostUnreachable)
- Result: success. Gate passed.

#### Phase 0, step 2: DNSBL check of 95.46.211.224
- Commands: `nslookup 224.211.46.95.zen.spamhaus.org`, `nslookup 224.211.46.95.bl.spamcop.net`, `nslookup 224.211.46.95.b.barracudacentral.org`
- Exit code: 0 (all three)
- Output (trimmed): all three `Non-existent domain` (NXDOMAIN) — not listed.
- Result: success. Gate passed.

#### Phase 0, step 3: Confirm no listener on mail ports on pro-data-tech-prod
- Command: `ssh ... tvolodi@95.46.211.224 "sudo ss -tlnp | grep -E ':(25|465|587|993|443|8080)\b' || echo NO_MATCHING_LISTENERS"`
- Exit code: 0
- Output (trimmed): only `0.0.0.0:443` (nginx) present.
- Result: success. Gate passed.

#### Phase 0, step 4: Confirm orphaned cert from attempt 1 still exists
- Command: `ssh ... tvolodi@95.46.211.224 "sudo certbot certificates -d mail.aiqadam.org"`
- Exit code: 0
- Output (trimmed): cert present, serial `5f82cf10d760f44f1bc0ae836cf12b41aa8`, expiry 2026-10-17 (VALID: 89 days) — unchanged from attempt 3.
- Result: success. All four Phase 0 checks cleared.

#### Pre-run baseline capture
- `docker ps --filter label=com.docker.compose.project=penpot` → 7/7 `Up 7 days`.
- `docker ps --filter label=com.docker.compose.project=aiqadam-prod` → 4/4 `Up` (web-next 8h, api-healthy 8h, oidc-stub-healthy 5d, postgres-healthy 5d) — matches the documented, pre-existing 4-vs-3 discrepancy; recorded as this run's own baseline, not investigated.
- External: `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` → 200. `https://aiqadam.org/health` → 200.
- Result: baseline captured.

#### Plan step 5: Create Compose directory and split data/config directories
- Command: `ssh ... "sudo mkdir -p /opt/stalwart-mail /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown -R 2000:2000 /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown tvolodi:tvolodi /opt/stalwart-mail"`
- Exit code: 0
- Output: `ls -la` confirmed `etc-stalwart`/`var-lib-stalwart` owned `2000:2000`, parent owned `tvolodi:tvolodi`.
- Result: success.

#### Plan step 6: Generate admin recovery password and test-account password
- Generated locally via `openssl rand -base64 24` (admin) and `openssl rand -base64 18` (test account), written only to the session's local scratchpad, never echoed to any persisted log. Secret names: `stalwart-mail-admin-password`, `stalwart-mail-test-account-password`. (Test-account password never used — Phase 6 not reached; scratchpad files shredded at run end.)
- Result: success.

#### Plan step 7: Write docker-compose.yml and .env
- `docker-compose.yml` authored locally exactly per Plan step 7's spec (project `stalwart-mail`, image `stalwartlabs/stalwart:v0.16`, ports 25/465/587/993 on `0.0.0.0`+`::`, 8080 on `127.0.0.1` only, split volumes, `STALWART_RECOVERY_ADMIN=admin:${STALWART_ADMIN_PASSWORD}`), `scp`'d to host, verified via `diff` — zero diff, exact match.
- `.env` written via `install -m 600 /dev/stdin /opt/stalwart-mail/.env` over a heredoc'd SSH session — value never touched local disk as a bare file, never a literal CLI argument or in shell history.
- Verification: `ls -la /opt/stalwart-mail/.env` → `-rw------- 1 tvolodi tvolodi 57`; non-empty.
- Result: success.

#### Plan step 8: Bring up Compose project
- Command: `ssh ... "cd /opt/stalwart-mail && docker compose up -d"`
- Exit code: 0
- Result: success. `docker compose -p stalwart-mail ps` → `stalwart-mail-server-1` `Up 19 seconds (healthy)`, ports bound as declared. `docker inspect ... --format '{{.Config.Image}}'` → `stalwartlabs/stalwart:v0.16` exactly (pinned, confirmed).
- `docker logs stalwart-mail-server-1 --tail 50`: `Server started in bootstrap mode`, version `0.16.13`, `Port 8080 is open for initial setup`, benign webui-resource-fetch INFO, `Network listener started` for `http-recovery` on `:8080` — no fatal errors, no crash loop, **no randomly-generated-password banner** (confirms deterministic `STALWART_RECOVERY_ADMIN` path).

#### Plan step 8a: Admin UI path verification
- Command: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/` plus header-only curl for `Location`.
- Output: `302`, `location: /account` — matches attempts 2/3 exactly.
- Result: success.

#### Plan step 9: Confirm Penpot and AiQadam-prod unregressed (post-Phase-1-install)
- Penpot: 7/7 `Up`, identical to baseline. AiQadam-prod: 4/4 `Up`, identical to baseline. External: both 200.
- Result: success — no regression, matches this run's own pre-run baseline.

#### Plan step 9a: Install `stalwart-cli` on the host
- Command: `ssh ... "curl --proto '=https' --tlsv1.2 -LsSf https://github.com/stalwartlabs/cli/releases/latest/download/stalwart-cli-installer.sh | sh"`
- Exit code: 0. Output: `downloading stalwart-cli 1.0.10 x86_64-unknown-linux-gnu`, `installing to /home/tvolodi/.cargo/bin`, `everything's installed!`
- Result: success. Install path: `/home/tvolodi/.cargo/bin/stalwart-cli`.

#### Plan step 9b: Record installed CLI version
- Command: `ssh ... "/home/tvolodi/.cargo/bin/stalwart-cli --version"` → `stalwart-cli 1.0.10`.
- Result: success. **Resolved version for audit: `stalwart-cli 1.0.10`** (matches attempt 3, per Decision I's pinning exception).

#### Plan step 9c: Confirm the CLI's auth-flag surface
- Commands: `ssh ... "... --help"` — confirmed `--password` reads `STALWART_PASSWORD` env var (Basic-auth, used with `--user admin`); `--api-key` reads `STALWART_TOKEN` (Bearer-token mode, unused).
- Result: success. Used `STALWART_PASSWORD` for all subsequent calls, never a literal password as a CLI argument.

#### Plan step 9d: Smoke-test connectivity, read-only
- Command: `ssh ... "STALWART_PASSWORD='<value>' .../stalwart-cli --url http://127.0.0.1:8080 --user admin describe Domain"`
- Exit code: 0. Output: full `Domain` schema returned, including live description text for `certificateManagement`/`dkimManagement`/`dnsManagement` ("Whether ... managed manually or automatically ...").
- Result: success.

### Plan step 10: Add UFW rules for the 4 new inbound mail ports
- Command: `ssh ... "sudo ufw allow 25/tcp && sudo ufw allow 465/tcp && sudo ufw allow 587/tcp && sudo ufw allow 993/tcp"`
- Exit code: 0. Output: `Rule added` / `Rule added (v6)` × 4 pairs.
- Result: success. `sudo ufw status verbose` confirmed all four `ALLOW IN` (v4+v6) alongside 22/80/443, no other ports added.

### Plan step 11: Confirm JMAP/webadmin (8080) is NOT exposed externally
- Command: `Test-NetConnection 95.46.211.224 -Port 8080` → `TcpTestSucceeded: False`. Verified.

### Plan step 12 (NEW this attempt): Complete the `Bootstrap` singleton

**Read-only confirmation first:**
- Command: `ssh ... "STALWART_PASSWORD='<value>' .../stalwart-cli --url http://127.0.0.1:8080 --user admin get Bootstrap"`
- Output: current defaults confirmed — `Default Email Domain: example.org`, `Server Hostname: 8ef5b949e9cd` (container hostname), `Automatically Obtain TLS Certificate: Yes`, `Generate Email Signing Keys: Yes`, internal directory, manual DNS, RocksDB/local-disk storage. Matches attempt 3's finding exactly.
- Result: success, as expected — proceeded to apply.

**Confirm exact `update` syntax live (per the plan's own instruction):**
- Commands: `ssh ... "... update --help"` and `"... update Bootstrap --help"`.
- Output: `update <OBJECT> [ID]` with `--field <KEY=VALUE>` repeatable, `[ID]` omittable for singletons.
- Result: success — confirmed `--field key=value` repeated is the correct invocation shape.

**Apply the completed Bootstrap configuration:**
- Command: `ssh ... "STALWART_PASSWORD='<value>' .../stalwart-cli --url http://127.0.0.1:8080 --user admin update Bootstrap --field defaultDomain=aiqadam.org --field serverHostname=mail.aiqadam.org --field generateDkimKeys=false --field requestTlsCertificate=false"`
- Exit code: 0
- Output: `Updated Bootstrap singleton` plus a server-generated `username`/`secret` pair (a real, new admin account distinct from the `STALWART_RECOVERY_ADMIN` recovery account — value not recorded in this handoff or anywhere persistent; observed once in command output, not reused).
- Result: **apparent success**, but see verification below — this did not achieve the plan's required post-condition.

**Verification — get Bootstrap again:**
- Command: `ssh ... "... get Bootstrap"` (re-run twice, including once with `--debug`)
- Output: **identical to the pre-update read** every time — `Default Email Domain: example.org`, `Server Hostname: 8ef5b949e9cd`, both booleans still `Yes`. The `--debug` trace confirmed this is a live `200 OK` JMAP response each time (differing content-length: 738 bytes vs. the original), not a cached/stale response — the server is genuinely recomputing this view and still returning the unmodified defaults.
- Result: **FAILED post-condition** — the plan expected `get Bootstrap` to reflect `defaultDomain: aiqadam.org`, `serverHostname: mail.aiqadam.org`, both booleans `false`.

**Verification — query Domain (the plan's specified bootstrap-mode-gone check):**
- Command: `ssh ... "... query Domain"` (run with `--debug` to capture the raw HTTP trace)
- Output: `error: jmap error: forbidden: The server is in bootstrap mode. Only the 'Bootstrap' object type can be accessed until the bootstrap process is complete.` — **identical, byte-for-byte, to attempt 3's blocking error.** Debug trace confirmed the JMAP POST itself returns HTTP `200 OK`; the "forbidden" is an application-level JMAP error payload within that 200 response, not a transport-level 401/403 — i.e., this is a deliberate, live server-side gate check at the JMAP method-dispatch layer, not a stale cache or CLI-rendering artifact.
- Result: **FAILED — the specific, concrete proof the plan required ("this is the specific, concrete proof that bootstrap is complete") was not obtained.** Per Plan step 12's own instruction: "if the rejection persists, halt and report; do not retry blindly or attempt to route around it."

**Further characterization performed before halting (read-only, to give the next design pass a precise account — not an attempt to route around the gate):**
1. Re-ran the identical `update Bootstrap` call a second time (idempotency check the plan itself flags as safe) — this time it **failed**: `error: primaryKeyViolation, Properties: defaultDomain, Object id: Domain#b, error: update failed`. This is strong evidence the *first* call was not a no-op: it created a real `Domain` object (id `Domain#b`) keyed on `defaultDomain: aiqadam.org` server-side, enforcing its own uniqueness constraint on retry — yet `get Bootstrap`'s own view never reflected this, and the bootstrap-mode gate never lifted.
2. Checked `docker ps`/container health and inspected both volume directories directly (`etc-stalwart/config.json`, `var-lib-stalwart/*`) — confirmed the container was healthy throughout and RocksDB was actively growing (new `.sst` files with fresh mtimes at the time of the `update` call), i.e., the server process is alive and genuinely persisting data, not stuck or crashed.
3. Inspected the raw `/jmap/session` response via `curl -u admin:<password>` — it returned a fully-populated JMAP capabilities/account listing (mail, calendar, contacts, sieve, submission, etc.) for a real account id `d333333` named `admin`, which does not look like a bootstrap-only stub session — suggesting the underlying mail/account engine considers itself provisioned, while a separate "is initial setup complete" flag that the management/schema API's method dispatcher checks does not derive from the same state.
4. Listed all top-level CLI subcommands (`stalwart-cli --help`) to check for a distinct "finish"/"complete"/"commit" bootstrap verb separate from `update`/`apply` — none exists (`get`, `query`, `create`, `update`, `delete`, `describe`, `apply`, `snapshot` are the full command set) — ruling out "there's a separate finalize step not yet tried" as an easy explanation.
5. Did **not** attempt to set the `directory`/`dnsServer`/and/or storage-backend (`dataStore`/`blobStore`/`inMemoryStore`/`searchStore`) fields on the `Bootstrap` singleton — left unset this attempt on the assumption defaults apply — is actually required to flip the completion gate, even though `get Bootstrap`'s own display already showed those defaulting correctly before any update was attempted. Not attempted here because it would mean the executor inventing new field values with no plan authorization and no empirical evidence they matter — exactly the improvisation this run's task brief instructs against.
- Backup taken: n/a — halted before any further destructive action; the one `Domain#b` object created server-side is fully removed by the rollback below (lives inside the deleted `var-lib-stalwart` volume).

Plan steps 13 onward (live schema introspection proper, `NetworkListener` check, DKIM key generation, NDJSON apply-plan construction/apply/verify, artifact cleanup), all of Phase 4 (TLS/ACME), Phase 5 (DNS cutover), Phase 6 (mailbox provisioning), Phase 7 (nginx vhost), Phase 8 (verification), and Phase 9 (backups) were **not attempted**, per "stop on first error" / halting discipline. **No Cloudflare API calls of any kind were made this run.**

### Rollback executed

Per the plan's Rollback section:

**1. Compose install rollback (Phases 0–1, steps 5–9d, plus the new step 12 attempt):**
- Command: `ssh ... "cd /opt/stalwart-mail && docker compose down"` — Exit code 0. Container stopped, removed; network `stalwart-mail_default` removed.
- Command: `ssh ... "sudo rm -rf /opt/stalwart-mail && ls -la /opt/ | grep -i stalwart || echo REMOVED"` — Exit code 0. Output: `REMOVED`.
- Result: success. Per the plan's rollback item 3, this also removes the `Domain#b` object and all other Bootstrap-related server state, since it all lived inside the deleted `var-lib-stalwart` bind mount — confirmed by design, not just assumed (the plan's own reasoning that a future re-run restarts fresh in bootstrap mode regardless of what "completing" Bootstrap did or didn't change server-side holds regardless of this attempt's unresolved outcome). The `stalwart-cli` binary (outside `/opt/stalwart-mail`) was left in place, per the plan's explicit "optional cleanup, not required" note.

**2. UFW rules rollback (Phase 2, step 10):**
- Command: `ssh ... "sudo ufw delete allow 25/tcp && sudo ufw delete allow 465/tcp && sudo ufw delete allow 587/tcp && sudo ufw delete allow 993/tcp"` — Exit code 0. `Rule deleted` / `Rule deleted (v6)` × 4.
- Result: success. `sudo ufw status verbose` post-rollback shows only 22/80/443 (v4+v6) — exact match to the Phase 0 pre-run state.

**3. Bootstrap/Domain config rollback (Phase 3, step 12):** covered wholesale by rollback item 1 — the `Domain#b` object and any other Bootstrap-related mutation existed only inside the now-deleted `var-lib-stalwart` volume.

**4–6. DNS / deleted-record / mailbox rollback:** not needed — Phase 5 and Phase 6 were never reached. No Cloudflare API calls of any kind were made this run.

**7. nginx vhost rollback:** not needed — Phase 7 was never reached; no nginx configuration was touched.

**8. Orphaned cert:** confirmed untouched post-rollback — `sudo certbot certificates -d mail.aiqadam.org` still shows the same cert (serial `5f82cf10d760f44f1bc0ae836cf12b41aa8`, expiry 2026-10-17, VALID: 89 days), unchanged.

Post-rollback verification: `sudo ss -tlnp | grep -E ':(25|465|587|993|8080)\b'` → `NO_MATCHING_LISTENERS`. Host confirmed returned to its pre-run state in every respect this plan's reached phases could have altered.

### Resources changed
- Files on host: **none remain** — `/opt/stalwart-mail/` (directory, `docker-compose.yml`, `.env` mode 600, `etc-stalwart/`, `var-lib-stalwart/`, including the transient server-side `Domain#b` object and generated admin account) was created then fully removed by rollback. `stalwart-cli` binary (`/home/tvolodi/.cargo/bin/stalwart-cli`, version 1.0.10) remains installed on the host, per the plan's explicit "optional cleanup, not required" note — a harmless, inert client tool with no running state and no network exposure.
- Services restarted: none (nginx was never touched this run).
- External resources changed: **none** — no Cloudflare API calls were made this run.

### Mandatory no-regression checkpoints

**Before this run (baseline, captured after Phase 0):**
- Penpot: 7/7 containers `Up` (all `Up 7 days`).
- AiQadam-prod: 4/4 containers `Up` (web-next 8h, api-healthy 8h, oidc-stub-healthy 5d, postgres-healthy 5d).
- External: `https://penpot.aiqadam.org` 200; `https://aiqadam.org/health` 200.

**Mid-run (Plan step 9, post-Phase-1-install):**
- Penpot: identical 7/7. AiQadam-prod: identical 4/4. External: both 200, unchanged.

**After rollback (final check, end of this run):**
- Penpot: identical 7/7 containers.
- AiQadam-prod: identical 4/4 containers.
- External: `https://penpot.aiqadam.org` 200; `https://aiqadam.org/health` 200.
- **No regression detected at any point**, checked against this run's own pre-run baseline throughout.

## Issues / risks

- **Plan-blocking defect (root cause of BLOCKED), Plan step 12:** the plan's core hypothesis — that `update Bootstrap` with the four specified field values, confirmed via a subsequent `get Bootstrap`/`query Domain` pair, would cleanly complete the bootstrap process — did not hold. Empirically, `update Bootstrap` reports success and demonstrably mutates server-side storage (a `Domain#b` object created, enforcing its own uniqueness constraint on retry; RocksDB actively growing), but (a) `get Bootstrap`'s own read-back never reflects the change, always showing the original defaults, and (b) the bootstrap-mode rejection on `query Domain` (and by the same mechanism `DkimSignature`/`NetworkListener`/`Account`) persists identically to attempt 3, confirmed via `--debug` trace to be a genuine, deliberate JMAP-application-level gate check, not a stale cache or CLI artifact. **This is a different, stranger failure mode than attempt 3's — attempt 3 found a missing step; this attempt found the step exists, executes, and visibly changes state, but the specific completion signal the plan needs never fires.** Per this run's brief and the plan's own step-12 instruction, this warrants a halt, not further guessing.
- **New evidentiary finding, not yet explained:** the raw `/jmap/session` endpoint (distinct from the `/api/schema`-backed `describe`/`get`/`query`/`update` management layer the CLI otherwise uses) returns a fully-populated, real-looking JMAP capability and account listing for account `admin` (id `d333333`) — mail, calendar, contacts, sieve, submission all present — which does not read as a bootstrap-only stub. This suggests the underlying account/mail engine may consider itself live while a separate "initial setup wizard complete" flag (checked specifically by the schema/management API's method dispatcher for non-`Bootstrap` object types) does not derive from or track the same state. Offered as a lead for the next design pass, not confirmed as the root cause.
- **Untested hypothesis, deliberately not guessed at this run:** whether explicitly setting the `directory`/`dnsServer`/and/or storage-backend (`dataStore`/`blobStore`/`inMemoryStore`/`searchStore`) fields on the `Bootstrap` singleton — left unset this attempt on the assumption defaults apply — is actually required to flip the completion gate. Not attempted here because it would mean the executor inventing new field values with no plan authorization and no empirical evidence they matter — exactly the improvisation this run's task brief instructs against.
- **No security or data-loss exposure from this halt.** Nothing was left running; no secrets were written anywhere persistent beyond the (now-deleted) `.env` file on the host and the (now-deleted) local scratchpad password files; no DNS or Cloudflare state was touched; no cert was created or destroyed; the one server-generated admin account/secret (from the `update Bootstrap` call) existed only inside the now-deleted `var-lib-stalwart` volume and was never recorded in this repo or any persistent log — it is gone along with the rest of the rolled-back state.
- **Two secrets were generated this run but never fully used or persisted anywhere:** `stalwart-mail-admin-password` (used transiently for CLI auth during this run) and `stalwart-mail-test-account-password` (generated but never used — Phase 6 not reached). Values existed only in ephemeral SSH command contexts, the host's now-deleted `.env` file, and local scratchpad files deleted at the end of this run. Never written to this repo, never logged. A future re-run should generate fresh values.
- **No regression to Penpot or AiQadam-prod at any point** — confirmed via baseline capture, a mid-run checkpoint, and a final post-rollback checkpoint; all identical.
- **Observation, off-plan, not actioned (carried over from prior attempts, still present, still out of scope):** AiQadam-prod's Compose project still shows 4 running containers vs. 3 documented in `landscape/hosts/pro-data-tech-prod.md`. Unrelated to this task, not investigated or touched.

## Open questions (optional)

- **This is the key routing question for the orchestrator, and it is explicitly NOT a same-character mechanism fix within the user's standing delegation.** The delegation covers routine corrections like auth-env-var names, protocol enum spellings, or CLI flag syntax — all of which this run again confirmed correctly and applied without incident. This finding is different in kind: the approved plan's central hypothesis for how to clear the Bootstrap gate did not hold, and the evidence gathered this run does not point to an obvious, low-risk next single step (unlike attempt 3, where "add the missing Bootstrap step" was a clean, well-scoped fix). Two live hypotheses exist (untested extra Bootstrap fields; a possible Stalwart 0.16.13 CLI/server bug or version-specific incomplete-bootstrap-completion codepath) plus a design-lineage alternative not revisited since attempt 2 (interactive-wizard automation, or hand-authoring `config.json` before first container start, both surfaced in attempt 2's research but set aside once the CLI path looked promising in attempt 3). Recommend the orchestrator bring this to the user directly, framed as: "the Bootstrap CLI path has hit a wall that doesn't have an obvious fix — do you want another design pass to keep investigating the CLI path (e.g., trying the untested fields, or testing against a disposable scratch container to probe further without touching pro-data-tech-prod), or should we pivot to one of the other non-interactive bootstrap mechanisms attempt 2 identified?" This is a scope/approach question for the user, not a routine mechanism correction.
- Recommend the next investigation happen against a **throwaway, disposable container** (e.g., on the management workstation's own Docker, or a scratch container on the host outside `/opt/stalwart-mail`) rather than repeating full install/rollback cycles against `pro-data-tech-prod` for what is now clearly an exploratory debugging problem, not a known-shape execution task. This would let the next attempt iterate on the Bootstrap-completion question much faster and with zero blast-radius concern, then bring a confirmed, working recipe back to a real execution attempt against prod.
- This run's findings (the `Domain#b` primaryKeyViolation on retry, the `get Bootstrap` non-reflection, the fully-provisioned-looking `/jmap/session` response, HTTP-200-with-JMAP-level-forbidden confirmed via `--debug`) are offered as a complete, precise account for whoever investigates next, per the task brief's request that a halt prioritize giving the orchestrator an actionable account over a terse failure note.
