---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 06
agent: executor-infra
verdict: BLOCKED
created: 2026-07-19T04:15:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-06
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-2.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/cloudflare.md
  - landscape/secrets-inventory.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: >-
  Solution-designer must re-author Phase 3 (and, by the same logic, Phase 6) to insert a genuinely new,
  missing step: completing Stalwart's `Bootstrap` singleton object BEFORE any Domain/DkimSignature/NetworkListener/
  Account object becomes reachable at all. Empirically confirmed and documented in this handoff: `stalwart-cli
  query Domain` (and by direct extension, `apply`/`create`/`get` against Domain/DkimSignature/NetworkListener/
  Account) returns a hard server-side rejection while the instance is in bootstrap mode: "forbidden: The server
  is in bootstrap mode. Only the 'Bootstrap' object type can be accessed until the bootstrap process is complete."
  `describe` (schema introspection) works fine against any object name regardless of bootstrap state -- that part
  of the plan's assumption held -- but `query`/`get`/`create`/`update`/`apply` against anything except `Bootstrap`
  itself does not, contradicting Plan step 13's assumption that `list NetworkListener` and step 16's `apply`
  against Domain/DkimSignature/NetworkListener would work directly. `Bootstrap` is a real, well-formed, describable
  singleton object (`describe Bootstrap`, `get Bootstrap` both succeed) with its own required-field set never
  mentioned anywhere in the current plan: `defaultDomain`, `serverHostname`, `generateDkimKeys`,
  `requestTlsCertificate`, `directory` (object<DirectoryBootstrap>), `dnsServer` (object<DnsServerBootstrap>),
  `dataStore`/`blobStore`/`inMemoryStore`/`searchStore`/`tracer` (all object-typed, currently defaulted to
  RocksDB/local-disk/internal-directory/manual-DNS in the live `get Bootstrap` output). The plan needs a new,
  explicit step -- update/apply against `Bootstrap` (singleton, `ID` omitted or literal "singleton") -- inserted
  before old step 12, with its field values decided at design time (not deferred to the executor), in particular:
  `defaultDomain: aiqadam.org` (currently defaulted to placeholder `example.org`), `serverHostname:
  mail.aiqadam.org`, and explicit calls on `generateDkimKeys` (interacts with Decision K -- if true, Stalwart may
  auto-generate DKIM material during bootstrap itself, which could obsolete or conflict with the plan's own
  on-host `openssl`-generated key + later `DkimSignature.privateKey` upsert approach) and `requestTlsCertificate`
  (interacts with Decision F/internal-ACME -- bootstrap's own ACME request could race or conflict with the
  later, separately-planned `AcmeProvider` apply in old Phase 4). Also confirmed live and worth folding into the
  corrected plan: `NetworkListenerProtocol`'s enum values are `smtp | lmtp | http | imap | pop3 | manageSieve`
  (no distinct "submission" variant -- port 587 would use `protocol: smtp`, consistent with what the plan
  intended but not verbatim what it said); the CLI's real Basic-auth password env var is `STALWART_PASSWORD`
  (not `STALWART_TOKEN`, which the plan named for Phase 3/6 but which the live `--help` shows is reserved for
  `--api-key`/Bearer-token auth, a different, unused auth mode here) -- a narrow, same-character flag-spelling
  correction, already resolved live and not a reason to re-loop on its own. Do not re-attempt Phase 3/6 against
  the current plan unchanged; the missing Bootstrap step is a structural gap, not a flag-naming detail, and
  inventing its field values without design-time sign-off would improvise past what step 04 approved (in
  particular the generateDkimKeys/requestTlsCertificate interaction with already-approved Decisions K and F).
---

## Summary
Executed Phase 0 pre-flight (all 4 checks passed fresh), Phase 1 install through the new step 9a-9d CLI sub-phase (container up/healthy, `stalwart-cli` 1.0.10 installed and smoke-tested successfully against the live instance), and Phase 2 firewall rules successfully, but halted at the start of Phase 3 (step 13, `list`/`query NetworkListener`, immediately after step 12's `describe` calls) when the live server rejected all non-`describe` operations against `Domain`/`DkimSignature`/`NetworkListener`/`Account` with "server is in bootstrap mode, only 'Bootstrap' object type can be accessed" -- a real, un-designed-for object (`Bootstrap`, a required singleton with its own field set) sits between the current state and everything Phase 3/6 assumed was directly reachable; rolled back the Compose install and UFW rules fully, confirmed Penpot and AiQadam-prod unregressed, and the host is back to its pre-run state (the attempt-1/2 orphaned cert remains untouched).

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes (`step-05-user-approval.md` `inputs_read` lists `runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md`; step-04 verdict was `NEEDS_APPROVAL`)

### Execution log

#### Phase 0, step 1: Re-probe dead host mail ports (fresh, not assumed from prior attempts)
- Command: `Test-NetConnection 212.20.151.29 -Port 25` (PowerShell, management workstation)
- Exit code: 0
- Output (trimmed): `TcpTestSucceeded: False` (DestinationHostUnreachable)
- Command: `Test-NetConnection 212.20.151.29 -Port 993`
- Exit code: 0
- Output (trimmed): `TcpTestSucceeded: False` (DestinationHostUnreachable)
- Result: success. Gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 2: DNSBL check of 95.46.211.224
- Commands: `nslookup 224.211.46.95.zen.spamhaus.org`, `nslookup 224.211.46.95.bl.spamcop.net`, `nslookup 224.211.46.95.b.barracudacentral.org`
- Exit code: 0 (all three)
- Output (trimmed): all three `Non-existent domain` (NXDOMAIN) -- not listed on any of the three DNSBLs.
- Result: success. Gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 3: Confirm no listener on mail ports on pro-data-tech-prod
- Command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "sudo ss -tlnp | grep -E ':(25|465|587|993|443|8080)\b' || echo NO_MATCHING_LISTENERS"`
- Exit code: 0
- Output (trimmed): only `0.0.0.0:443` (nginx) present; nothing on 25/465/587/993/8080.
- Result: success. Gate passed.
- Backup taken: n/a (read-only)

#### Phase 0, step 4: Confirm orphaned cert from attempt 1 still exists
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
- Result: success -- cert confirmed present and valid, unchanged serial/expiry from attempt 2's confirmation. Gate passed. All four Phase 0 checks cleared; proceeded to Phase 1.
- Backup taken: n/a (read-only)

#### Pre-run baseline capture (mandatory no-regression checkpoint baseline, this run's own, before any state change)
- Command: `docker ps --filter label=com.docker.compose.project=penpot --format '{{.Names}}: {{.Status}}'`
- Output: 7/7 containers `Up` (backend, frontend, exporter, postgres-healthy, mailcatch, mcp, valkey-healthy) -- all `Up 7 days`.
- Command: `docker ps --filter label=com.docker.compose.project=aiqadam-prod --format '{{.Names}}: {{.Status}}'`
- Output: 4/4 containers `Up` (web-next 8h, api-healthy 8h, oidc-stub-healthy 5d, postgres-healthy 5d) -- matches the pre-existing, previously-noted 4-vs-3-documented discrepancy; recorded as this run's own baseline, not investigated further per plan instruction.
- External: `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` -> 200. `Invoke-WebRequest https://aiqadam.org/health` -> 200, body confirms `{"status":"ok",...,"tenant":{"code":"uz",...}}`.
- Result: baseline captured for later comparison.

#### Plan step 5: Create Compose directory and split data/config directories
- Command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /opt/stalwart-mail /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown -R 2000:2000 /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown tvolodi:tvolodi /opt/stalwart-mail"`
- Exit code: 0
- Output: `ls -la /opt/stalwart-mail` showed `etc-stalwart`/`var-lib-stalwart` owned `2000:2000`; parent owned `tvolodi:tvolodi`.
- Result: success
- Backup taken: n/a (new directories, no prior state)

#### Plan step 6: Generate admin recovery password and test-account password
- Command: `openssl rand -base64 24` (admin), `openssl rand -base64 18` (test account) -- generated locally, values written only to the session's local scratchpad directory (outside this repo), never echoed to any persisted log or this handoff.
- Result: success. Secret names recorded: `stalwart-mail-admin-password`, `stalwart-mail-test-account-password`. (Test-account password generated but never used -- Phase 6 was never reached; both scratchpad files deleted at the end of this run.)
- Backup taken: n/a

#### Plan step 7: Write docker-compose.yml and .env
- Command: authored `docker-compose.yml` locally per Plan step 7's exact spec (project name `stalwart-mail`, image `stalwartlabs/stalwart:v0.16`, ports 25/465/587/993 on `0.0.0.0`+`::`, 8080 on `127.0.0.1` only, volumes `/opt/stalwart-mail/etc-stalwart:/etc/stalwart` + `/opt/stalwart-mail/var-lib-stalwart:/var/lib/stalwart`, `STALWART_RECOVERY_ADMIN=admin:${STALWART_ADMIN_PASSWORD}`), `scp`'d to host, verified via `diff` against the on-host copy -- exact match, zero diff.
- Command: `.env` written via `install -m 600 /dev/stdin /opt/stalwart-mail/.env` piped from a local variable over SSH (value never touched local disk as a bare file, never appeared as a literal CLI argument or in shell history).
- Exit code: 0 (both)
- Output: `ls -la /opt/stalwart-mail/.env` -> `-rw------- 1 tvolodi tvolodi 57`; `test -s` confirmed non-empty.
- Result: success
- Backup taken: n/a (new files, no prior state)

#### Plan step 8: Bring up Compose project
- Command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose up -d"`
- Exit code: 0
- Output (trimmed): network + container created and started; no explicit pull-progress lines this run (image `stalwartlabs/stalwart:v0.16` already cached from a prior attempt's pull) -- confirmed pinned via `docker inspect stalwart-mail-server-1 --format '{{.Config.Image}}'` -> `stalwartlabs/stalwart:v0.16` exactly.
- Result: success
- Verification: `docker compose -p stalwart-mail ps` (after a 15s wait for the health check interval) -> `stalwart-mail-server-1` `Up 26 seconds (healthy)`, ports bound as declared. `docker logs stalwart-mail-server-1 --tail 50` showed `Server started in bootstrap mode`, version `0.16.13`, `Port 8080 is open for initial setup`, a benign webui-resource-fetch INFO line, and `Network listener started` for `http-recovery` on `:8080` -- no fatal errors, no crash loop, **no randomly-generated-password banner** (confirms the deterministic `STALWART_RECOVERY_ADMIN` credential path was used).
- Backup taken: n/a (new container, no prior state)

#### Plan step 8a: Admin UI path verification (Decision H)
- Command: `ssh ... tvolodi@95.46.211.224 "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/"` plus a header-only curl to capture the `Location` value
- Exit code: 0
- Output: `302`, `location: /account`
- Result: success. Matches attempt 2's empirical finding exactly.

#### Plan step 9: Confirm Penpot and AiQadam-prod unregressed (mandatory no-regression checkpoint, post-Phase-1-install)
- Commands: same `docker ps --filter label=...` pair as the pre-run baseline, plus the two external `Invoke-WebRequest` probes.
- Output: Penpot 7/7 `Up`, identical to baseline. AiQadam-prod 4/4 `Up`, identical to baseline. External: both 200.
- Result: success -- no regression detected, matches this run's own pre-run baseline exactly (not the possibly-stale landscape figures).

#### Plan step 9a: Install `stalwart-cli` on the host (Decision I)
- Command: `ssh ... tvolodi@95.46.211.224 "curl --proto '=https' --tlsv1.2 -LsSf https://github.com/stalwartlabs/cli/releases/latest/download/stalwart-cli-installer.sh | sh"`
- Exit code: 0 (clean completion, no error output)
- Output: `downloading stalwart-cli 1.0.10 x86_64-unknown-linux-gnu`, `installing to /home/tvolodi/.cargo/bin`, `stalwart-cli`, `everything's installed!`
- Result: success. Install path confirmed: `/home/tvolodi/.cargo/bin/stalwart-cli` (not yet on `$PATH` in the non-interactive SSH shell -- full path used for all subsequent invocations, per the plan's own contingency).
- Backup taken: n/a (new, independent host-level tool, not part of the Compose install tree)

#### Plan step 9b: Record installed CLI version
- Command: `ssh ... tvolodi@95.46.211.224 "/home/tvolodi/.cargo/bin/stalwart-cli --version"`
- Exit code: 0
- Output: `stalwart-cli 1.0.10`
- Result: success. **Resolved version for audit: `stalwart-cli 1.0.10`** (per Decision I's pinning exception, this substitutes for a pre-declared pin).

#### Plan step 9c: Confirm the CLI's auth-flag surface
- Commands: `ssh ... "/home/tvolodi/.cargo/bin/stalwart-cli --help"` and `"... apply --help"`
- Exit code: 0 (both)
- Output (relevant excerpt, both commands agree):
  ```
  --user <USER>          Basic-auth username [env: STALWART_USER=]
  --password <PASSWORD>  Basic-auth password (prompted if absent and stdin is a TTY) [env: STALWART_PASSWORD]
  --api-key <API_KEY>    Bearer token (mutually exclusive with --user) [env: STALWART_TOKEN]
  ```
- Result: success, with a correction to the plan's assumed env-var name. **The plan's Decision J/Plan step 16 named `STALWART_TOKEN` as the auth env var; the live CLI shows `STALWART_TOKEN` is actually for `--api-key`/Bearer-token auth (an alternate, unused auth mode here) -- the correct env var for the planned `--user admin` / Basic-auth flow is `STALWART_PASSWORD`.** Used `STALWART_PASSWORD` (never a literal password as a CLI argument) for all subsequent calls this run. This is a narrow, same-character flag-spelling correction consistent with what the plan explicitly told the executor to confirm live and does not by itself justify a halt.

#### Plan step 9d: Smoke-test connectivity, read-only
- Command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin describe Domain"`
- Exit code: 0
- Output: full `Domain` object schema returned (fields `aliases`, `allowRelaying`, `catchAllAddress`, `certificateManagement` (`object<CertificateManagement>`), `createdAt`, `description`, `directoryId`, `dkimManagement` (`object<DkimManagement>`), `dnsManagement` (`object<DnsManagement>`), `dnsZoneFile`, `isEnabled`, `logo`, `memberTenantId`, `name`, `reportAddressUri`, `subAddressing`).
- Result: success -- first live confirmation the CLI can talk to the bootstrap-mode server; auth and connectivity both work.

### Plan step 10: Add UFW rules for the 4 new inbound mail ports
- Command: `ssh ... "sudo ufw allow 25/tcp && sudo ufw allow 465/tcp && sudo ufw allow 587/tcp && sudo ufw allow 993/tcp"`
- Exit code: 0
- Output: `Rule added` / `Rule added (v6)` x4 pairs.
- Result: success. Verification: `sudo ufw status verbose` listed all four new ports `ALLOW IN` (v4+v6) alongside existing 22/80/443; no other ports added.
- Backup taken: n/a (additive, cleanly reversible rule set)

### Plan step 11: Confirm JMAP/webadmin (8080) is NOT exposed externally
- Command (management workstation): `Test-NetConnection 95.46.211.224 -Port 8080`
- Result: `TcpTestSucceeded: False`. Verified.

### Plan step 12: Live schema introspection, read-only -- Domain, DkimSignature, NetworkListener
- Command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin describe Domain"` (output captured above at step 9d) -- also re-run standalone with identical result.
- Command: `... describe DkimSignature` -- Exit code 0. Output: full multi-variant schema returned -- **four DKIM variants exist, not two**: `Dkim1Ed25519Sha256`, `Dkim1RsaSha256`, `Dkim2Ed25519Sha256`, `Dkim2RsaSha256` (DKIM1 = classic RFC 6376 selector-based signing; DKIM2 appears to be a newer/alternate signing scheme with a `flags`/`Dkim2Flag` field not present on DKIM1 variants). Both `Dkim1*` variants include `privateKey` (`object<SecretText>`, mutable) and `publicKey` (`string<text>`, **server-set**, "derived from the private key") -- confirms the plan's Decision K assumption that a private key must be supplied and the public key is server-derived, not independently computed. Ed25519 is available under both DKIM1 and DKIM2 naming; RSA under both as well.
- Command: `... describe NetworkListener` -- Exit code 0. Output: fields `bind` (`set<string<socketAddress>>`), `name` (`string<string>`, immutable), `protocol` (`enum (see NetworkListenerProtocol)`), `useTls`/`tlsImplicit` (both `boolean`), plus various socket-tuning fields. Followed up with `describe NetworkListenerProtocol` -- Exit code 0 -- variants: `smtp | lmtp | http | imap | pop3 | manageSieve`. **No distinct "submission" protocol variant** -- port 587 (STARTTLS submission) would use `protocol: smtp` per this enum, consistent with the plan's intent though not verbatim what Plan step 15 said.
- Additional read-only calls made in pursuit of Plan step 15's instruction to resolve the `certificateManagement`/`dkimManagement`/`dnsManagement` enum values before writing the apply-plan: `describe CertificateManagement`, `describe DkimManagement`, `describe DnsManagement` -- **all three returned `error: no object or enum named '<Name>'`** (exit code non-zero). `stalwart-cli describe` (no argument) was then run to list all 117 describable top-level objects/enums -- confirmed `CertificateManagement`, `DkimManagement`, `DnsManagement` are **not** independently describable by name via this CLI version; they exist only as inline `object<...>`-typed field annotations inside `Domain`'s own schema, with no `--json`/verbose flag on `describe` to expand them further.
- Result: **partial success, with an open, unresolved sub-question** (the three inline management-object shapes) that step 13 attempted to resolve empirically and which instead surfaced the actual blocker (see below). Per the plan's own instruction ("if any of these objects does not exist or its shape materially contradicts what this plan assumes, halt"), `Domain`/`DkimSignature`/`NetworkListener` themselves DO exist and DO roughly match the assumed shape -- this alone was not treated as blocking.

### Plan step 13: Check for pre-existing NetworkListener objects (read-only)
- Command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin query Domain"` (run first, against `Domain` rather than `NetworkListener`, as part of investigating the unresolved inline-object-shape question above by attempting the lowest-risk possible read call before committing to any specific `NetworkListener` filter syntax)
- Exit code: non-zero (command returned an error)
- Output (verbatim):
  ```
  error: jmap error: forbidden: The server is in bootstrap mode. Only the 'Bootstrap' object type can be accessed until the bootstrap process is complete.
  ```
- Result: **halted here.** This is a hard, unambiguous, server-enforced rejection -- not a shape mismatch, not a flag-spelling issue, and not something the executor can route around by adjusting field names or trying `list` instead of `query`. It directly contradicts Plan steps 13 and 16-17's assumption that `Domain`/`DkimSignature`/`NetworkListener` (and, by the same mechanism, `Account` in Phase 6) are reachable via `query`/`get`/`create`/`update`/`apply` while the server is still in the bootstrap state the plan's own Phase 1 deliberately leaves it in (per Decision D/the `STALWART_RECOVERY_ADMIN` bootstrap-mode approach, unchanged from attempt 2).
- Follow-up investigation performed (read-only, to characterize the gap precisely before halting, not to route around it):
  1. `describe Bootstrap` -- exit 0. Confirmed `Bootstrap` is a real, singleton, describable object ("Initial setup shown the first time Stalwart starts. Configures the server's identity, storage, user accounts, logging, and DNS management.") with 13 fields: `blobStore`, `dataStore`, `defaultDomain`, `directory` (`object<DirectoryBootstrap>`), `dnsServer` (`object<DnsServerBootstrap>`), `generateDkimKeys` (boolean), `inMemoryStore`, `requestTlsCertificate` (boolean), `searchStore`, `secret` (server-set), `serverHostname`, `tracer`, `username` (server-set).
  2. `get Bootstrap` -- exit 0. Confirmed this singleton is currently populated with server defaults, not yet configured for this deployment: `Default Email Domain: example.org` (placeholder, not `aiqadam.org`), `Server Hostname: dff444414b18` (container hostname, not `mail.aiqadam.org`), `Automatically Obtain TLS Certificate: Yes`, `Generate Email Signing Keys: Yes`, `Directory Type: Use the internal directory`, `DNS Server Type: Manual DNS server management`, storage backends all defaulted to RocksDB/local-disk.
  3. `update --help` -- confirmed `update <OBJECT> [ID]` accepts `[ID]` omitted or the literal string `"singleton"` for singleton objects -- i.e., `update Bootstrap` (or `apply` with a `Bootstrap` upsert) is the real, well-formed command shape that would be needed to complete bootstrap, consistent with attempt 2's research finding that "config.json + recovery-mode + stalwart-cli apply" was one of the two sanctioned non-interactive paths, now confirmed as the *only* non-interactive path since the interactive-wizard-driving option was never adopted by this design.
  4. No `update`/`apply`/`create` call was attempted against `Bootstrap` or any other object -- doing so would mean deciding values for `defaultDomain`, `serverHostname`, `generateDkimKeys`, `requestTlsCertificate`, `directory`, `dnsServer` on the executor's own initiative, none of which the approved plan specifies, and at least two of which (`generateDkimKeys`, `requestTlsCertificate`) directly interact with already-approved Decisions K (on-host `openssl`-generated DKIM key, explicitly not assuming server auto-generation) and F (Stalwart's own internal ACME configured as a separate, later Phase 4 step) in ways the plan never reconciled. This is exactly the kind of new, structural decision my task brief said to halt on rather than improvise.
- Backup taken: n/a -- halted before any destructive or hard-to-reverse action in this phase; no `Bootstrap` field was touched.

Plan steps 14-18 (DKIM key generation, NDJSON apply-plan construction/apply/verify, artifact cleanup), all of Phase 4 (TLS/ACME, steps 19-20), Phase 5 (DNS cutover, steps 21-31), Phase 6 (mailbox provisioning, steps 32-34), Phase 7 (nginx vhost, step 35), Phase 8 (verification, steps 36-40), and Phase 9 (backups, step 41) were **not attempted**, per "stop on first error" / halting discipline. **No Cloudflare API calls of any kind were made this run.**

### Rollback executed

Per the plan's Rollback section:

**1. Compose install rollback (Phases 0-1, steps 5-9d):**
- Command: `ssh ... "cd /opt/stalwart-mail && docker compose down"` -- Exit code 0. Output: container stopped, removed; network `stalwart-mail_default` removed.
- Command: `ssh ... "sudo rm -rf /opt/stalwart-mail && ls -la /opt/ | grep -i stalwart || echo REMOVED"` -- Exit code 0. Output: `REMOVED`.
- Result: success. Per the plan's own note, the `stalwart-cli` binary (installed to `/home/tvolodi/.cargo/bin`, outside `/opt/stalwart-mail`) was left in place, consistent with the plan's explicit instruction that this is optional cleanup, not a rollback requirement.

**2. UFW rules rollback (Phase 2, step 10):**
- Command: `ssh ... "sudo ufw delete allow 25/tcp && sudo ufw delete allow 465/tcp && sudo ufw delete allow 587/tcp && sudo ufw delete allow 993/tcp"` -- Exit code 0. Output: `Rule deleted` / `Rule deleted (v6)` x4.
- Result: success. `sudo ufw status verbose` post-rollback shows only 22/80/443 (v4+v6) -- exact match to the Phase 0 pre-run state.

**3. Domain/DKIM/listener/ACME config rollback (Phase 3-4):** not needed -- no `Domain`, `DkimSignature`, `NetworkListener`, or `Bootstrap` mutation was ever attempted or applied this run (the one mutation-class call made, `query Domain`, was rejected server-side before touching any state). Any transient in-memory bootstrap-mode server state was removed wholesale by rollback item 1 (container destroyed, `var-lib-stalwart` directory removed).

**4-6. DNS / deleted-record / mailbox rollback:** not needed -- Phase 5 and Phase 6 were never reached. No Cloudflare API calls of any kind were made this run.

**7. nginx vhost rollback:** not needed -- Phase 7 was never reached; no nginx configuration was touched this run.

**8. Orphaned cert (Decision G):** confirmed untouched post-rollback -- `sudo certbot certificates -d mail.aiqadam.org` still shows the same cert (serial `5f82cf10d760f44f1bc0ae836cf12b41aa8`, expiry 2026-10-17, VALID: 89 days), unchanged from this run's own Phase 0 step 4 confirmation.

Post-rollback verification: `sudo ss -tlnp | grep -E ':(25|465|587|993|8080)\b'` -> `NO_MATCHING_LISTENERS`. Host confirmed returned to its pre-run state in every respect this plan's reached phases could have altered.

### Resources changed
- Files on host: **none remain** -- `/opt/stalwart-mail/` (directory, `docker-compose.yml`, `.env` mode 600, `etc-stalwart/`, `var-lib-stalwart/`) was created then fully removed by rollback. `stalwart-cli` binary (`/home/tvolodi/.cargo/bin/stalwart-cli`, version 1.0.10) remains installed on the host, per plan's explicit "optional cleanup, not required" note -- a harmless, inert client tool with no running state and no network exposure.
- Services restarted: none (nginx was never touched this run).
- External resources changed: **none** -- no Cloudflare API calls were made this run.

### Mandatory no-regression checkpoints (Plan step 9, and final post-rollback re-check)

**Before this run (baseline, captured after Phase 0, before any state change):**
- Penpot: 7/7 containers `Up` (all `Up 7 days`).
- AiQadam-prod: 4/4 containers `Up` (web-next 8h, api-healthy 8h, oidc-stub-healthy 5d, postgres-healthy 5d).
- External: `https://penpot.aiqadam.org` 200; `https://aiqadam.org/health` 200.

**Mid-run (Plan step 9, post-Phase-1-install, before Phase 2/3):**
- Penpot: identical 7/7, same status strings.
- AiQadam-prod: identical 4/4, same status strings.
- External: both 200, unchanged.

**After rollback (final check, end of this run):**
- Penpot: `docker ps --filter label=com.docker.compose.project=penpot` -> identical 7/7 containers.
- AiQadam-prod: `docker ps --filter label=com.docker.compose.project=aiqadam-prod` -> identical 4/4 containers.
- **No regression detected at any point**, checked against this run's own pre-run baseline throughout, per the task brief's explicit instruction.

## Issues / risks

- **Plan-blocking defect (root cause of BLOCKED), Plan steps 12-13 / Phase 3 generally:** the plan's Decision J assumed `Domain`/`DkimSignature`/`NetworkListener` (and, by the same unaddressed gap, `Account` in Phase 6) are directly reachable via `stalwart-cli query`/`get`/`create`/`update`/`apply` once the server is up in `STALWART_RECOVERY_ADMIN` bootstrap mode. Empirically, they are not: the server enforces "only the 'Bootstrap' object type can be accessed until the bootstrap process is complete" for every non-`describe` operation. `describe` (pure schema introspection) does work regardless of bootstrap state, which is why Plan step 12 partially succeeded before step 13 hit the wall. This is a structural sequencing gap, not a syntax detail -- a new step (completing `Bootstrap`, a singleton with 13 fields, several object-typed and requiring their own sub-decisions) needs explicit design, not executor improvisation, particularly because two of its boolean fields (`generateDkimKeys`, `requestTlsCertificate`) plausibly overlap or conflict with already-approved Decisions K and F.
- **New, narrower, already-resolved-live finding, not blocking on its own:** the plan named `STALWART_TOKEN` as the auth env var for Phase 3/6 CLI calls; live `--help` output shows the correct env var for the planned `--user admin`/Basic-auth flow is `STALWART_PASSWORD` (`STALWART_TOKEN` is for the unused `--api-key`/Bearer-token mode). Already applied correctly for all calls this run; flagged so the next plan revision states the right name rather than re-discovering it.
- **New, narrower, already-resolved-live finding, not blocking on its own:** `NetworkListenerProtocol`'s enum has no distinct "submission" variant; port 587 STARTTLS submission would use `protocol: smtp`. Matches the plan's intent, just not its exact wording -- worth stating explicitly in the corrected plan's Phase 3 apply-plan construction step.
- **Unresolved, deferred by the halt (not independently blocking, but relevant context for the next design pass):** `certificateManagement`, `dkimManagement`, `dnsManagement` -- the three `Domain`-level "management mode" fields Plan step 15 asked the executor to set based on "step 12's confirmed enum" -- are not independently describable via `stalwart-cli describe <Name>` in CLI version 1.0.10; they appear only as inline `object<...>` type annotations with no expansion mechanism found (no `--json`, no verbose flag). Their concrete shape was never determined this run because the halt at step 13 came first. The next design pass will need either a different introspection technique (e.g., inspecting a `create --field` dry-run's own validation error text, or the CLI's `snapshot` subcommand, both untried this run) or to accept setting these via `--field` with a value guessed from context and let a real (non-dry-run) `apply`/`create` call's own validation confirm or reject it -- but only after `Bootstrap` is completed, since nothing in this object family is reachable before that regardless.
- **No security or data-loss exposure from this halt.** Nothing was left running, no secrets were written anywhere persistent beyond the (now-deleted) `.env` file on the host and the (now-deleted) local scratchpad password files, no DNS or Cloudflare state was touched, no cert was created or destroyed this run, and no `Bootstrap`/`Domain`/`DkimSignature`/`NetworkListener` field was ever mutated (the one attempted call was cleanly rejected server-side before any write). The system is in exactly the state Phase 0 found it in.
- **Two secrets were generated this run but never used or persisted anywhere:** `stalwart-mail-admin-password` and `stalwart-mail-test-account-password` values existed only in the ephemeral SSH command contexts, the host's now-deleted `.env` file, and local scratchpad files deleted at the end of this run. Never written to this repo, never logged. A future re-run should generate fresh values.
- **No regression to Penpot or AiQadam-prod at any point** -- confirmed via baseline capture, a mid-run checkpoint, and a final post-rollback checkpoint; all three identical.
- **Observation, off-plan, not actioned (carried over from prior attempts, still present, still out of scope):** AiQadam-prod's Compose project still shows 4 running containers vs. 3 documented in `landscape/hosts/pro-data-tech-prod.md`. Unrelated to this task, not investigated or touched.

## Open questions (optional)
- Should the corrected Phase 3 insert an explicit `Bootstrap` completion step with fully pre-decided field values (`defaultDomain: aiqadam.org`, `serverHostname: mail.aiqadam.org`, and explicit, reasoned calls on `generateDkimKeys` and `requestTlsCertificate` reconciled against Decisions K and F), authored by the solution-designer rather than left to the executor? Given the orchestrator's delegated authority covers same-character mechanism fixes but explicitly does NOT cover silently changing any of the eleven previously-approved substantive decisions, and `generateDkimKeys`/`requestTlsCertificate` genuinely interact with Decisions K/F, this specific sub-decision may warrant the orchestrator's own judgment call (or a fresh, narrow user check-in) rather than being treated as purely mechanical.
- Recommend the next solution-design pass explicitly resolve the `certificateManagement`/`dkimManagement`/`dnsManagement` inline-object shapes before another execution attempt -- e.g., by trying `stalwart-cli create Domain --field certificateManagement={} --dry-run` (or similar exploratory `--field`/`--json` probes) *after* `Bootstrap` is completed in a scratch/throwaway container, so the shape is confirmed in a low-stakes environment rather than deferred to this run's production-adjacent host again.
- This run's findings (`Bootstrap` singleton exists and gates everything; its 13 fields and their current defaults; `STALWART_PASSWORD` is the correct auth env var; `NetworkListenerProtocol` has no distinct submission variant; `DkimSignature` actually has 4 variants not 2, including a `Dkim2*` family with a `flags` field the plan never anticipated) are offered as a complete, precise starting point for the next design pass, per the task brief's request that this halt prioritize giving the orchestrator an actionable account over a terse failure note.
