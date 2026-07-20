---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-19T10:05:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-04
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-04-solution-designer-attempt-4.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-4.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-05-user-approval-attempt-3.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-05-user-approval-attempt-4.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/secrets-inventory.md
  - landscape/services.md
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: >-
  Orchestrator: this attempt-5 correction IS covered by the user's standing attempt-3 delegation
  ("All up to you. Call me when everything will be ready") as extended by attempt-4's approval note
  ("the user's attempt-3 delegation of routine mechanism-fix approvals to the orchestrator remains
  in effect for the remainder of this run"). Unlike attempt 4's Bootstrap-flags item (a genuine new
  judgment call about server behavior never previously reasoned about), this fix changes HOW the
  already-approved, already-once-explicitly-confirmed `generateDkimKeys:false`/`requestTlsCertificate:false`
  Bootstrap step actually takes effect (a container restart is required for Stalwart v0.16 to
  re-evaluate bootstrap-mode completion; it does not do so live) — it does not touch what fields are
  set or why. This is the same character as the STALWART_PASSWORD/NetworkListener-protocol/DKIM-variant
  fixes already folded into attempt 4 without separate re-confirmation. Root cause is empirically
  confirmed (isolated scratch-container reproduction, independently corroborated by the running
  server's own web UI bundle string), not a guess. Proceed directly: write step-05 approval under the
  standing delegation (no fresh user round-trip), then invoke executor-infra for attempt 5, starting
  from a fresh Phase 0 pre-flight per this run's established discipline.
---

## Summary
Fifth-attempt retry: identical to attempt 4's approved plan in every respect except one inserted step — a `docker compose restart` (with health-wait) immediately after the already-approved `update Bootstrap` call and before the bootstrap-mode-gone verification, because Stalwart v0.16 only re-evaluates bootstrap-mode completion at process startup, not live — plus capture of the new `admin@aiqadam.org` credential the `update Bootstrap` call generates as a new secret; end state is unchanged from attempt 4: a working, repo-owned, TLS-secured, firewalled mail server with the old dead records fully retired.

## Details

### Root cause of attempt 4's blocker (now confirmed, not a guess)

Attempt 4's executor found an internally contradictory state: `update Bootstrap` (with `defaultDomain: aiqadam.org`, `serverHostname: mail.aiqadam.org`, `generateDkimKeys: false`, `requestTlsCertificate: false` — all four values exactly as approved at attempt 4's step 05) reported success and demonstrably mutated server-side storage (RocksDB growth, a real `Domain#b` object created, enforcing its own uniqueness constraint on retry with `primaryKeyViolation`), yet `get Bootstrap` never reflected the change and `query Domain` (and by the same mechanism `DkimSignature`/`NetworkListener`/`Account`) kept rejecting with the bootstrap-mode error, confirmed via `--debug` trace to be a genuine JMAP-application-level gate check, not a stale cache or CLI artifact.

This was independently reproduced and then fixed in a disposable, fully isolated local scratch container — a separate debugging exercise, unrelated to production, with zero blast radius. Root cause: **Stalwart v0.16 re-evaluates whether bootstrap mode is complete only at process startup.** `update Bootstrap` correctly writes the new configuration to its RocksDB-backed config store, but the running server process does not re-check or re-load that state live. A container restart is required after `update Bootstrap` for the bootstrap-mode gate to actually lift. This is not documented in `stalwart-cli --help` or any `describe` output, but is independently corroborated: the running server's own web UI JavaScript bundle contains the literal string "restart Stalwart for the new configuration to take effect. Once restarted, sign in with the credentials above to continue administering your server." After `docker restart` and waiting for the container to report healthy again, `query Domain` immediately succeeds and returns the configured domain; `get Bootstrap` at that point correctly reports "Bootstrap singleton not found" — proving bootstrap mode is over, not still silently active.

This explains every symptom attempt 4 observed: the `Domain#b` object was real (written to RocksDB immediately), `get Bootstrap` never changed (the running process was still serving its in-memory, startup-time view of Bootstrap state), and `query Domain` kept rejecting (the running process's in-memory "is bootstrap complete" flag never flipped without a restart).

### Additional confirmed findings folded into this retry

1. Each successful `update Bootstrap` call generates a new admin account (`admin@<defaultDomain>`, i.e. `admin@aiqadam.org`) with a freshly generated password, printed in the CLI's own command output (`username`/`secret` fields). This becomes the real day-to-day admin login post-restart. Captured as a new secret, `stalwart-mail-domain-admin-password`, distinct from `STALWART_RECOVERY_ADMIN`.
2. `STALWART_RECOVERY_ADMIN` remains a valid, persistent login even after bootstrap completes (it is not bootstrap-scoped) — both credentials work post-restart. **This plan keeps using `STALWART_RECOVERY_ADMIN`/`STALWART_PASSWORD` for all subsequent CLI calls in Phase 3/6**, rather than switching to the new domain-admin credential, because: (a) it is the credential already wired into every prior step's command form and this repo's `.env`-sourced secret-handling discipline (Decision-consistent, no new plumbing needed); (b) it avoids capturing and briefly handling a second live password mid-run for no operational benefit — the recovery admin already has full privileges; (c) the new domain-admin credential's only necessary use in this plan is to be captured once (from the `update Bootstrap` response, read-only) and stored as a secret for future day-to-day use outside this run, not to replace the recovery admin as this run's own automation credential.
3. Running `update Bootstrap` more than once with the same `defaultDomain` before restarting is destructive-ish: it leaves a permanently-created `Domain` row invisible to `query`/`get` until after a restart. This retry's plan restarts immediately after the single intended `update Bootstrap` call and does **not** retry that call under any circumstances if it appears to "fail silently" — the correct diagnostic on a post-restart verification failure is to inspect via `query Domain`/`get Bootstrap`, never to blindly re-run `update Bootstrap` again (which would only hit `primaryKeyViolation` and fix nothing).
4. `docker logs` produces zero new lines for the `update Bootstrap` HTTP call at INFO level — the plan does not rely on container logs to confirm this step worked; it relies on the `query Domain` check after restart.

**Everything else from attempt 4 carries forward unchanged** — host, image, volumes, TLS approach (Decision F), DNS cutover scope, rollback structure, verification criteria, the `stalwart-cli` "latest" exception (Decision I), the DKIM variant (`Dkim1Ed25519Sha256`), the auth env var (`STALWART_PASSWORD`), the `NetworkListener` protocol (`smtp` for port 587), the safe-discovery-via-validation-error technique for `Domain` management-mode fields (step 15a), and both previously-approved Bootstrap field values (`generateDkimKeys: false`, `requestTlsCertificate: false` — Decisions K and F realized exactly as the user approved at attempt 4's step 05). This is a single, narrow, now-fully-diagnosed mechanism fix: **insert a restart-and-health-wait between the `update Bootstrap` call and its verification.**

### Plan

**Phase 0 — Pre-flight discovery (read-only, must run and be recorded before any state change)** — unchanged from attempt 4; re-run fresh.

1. Re-probe the dead host's mail ports live — command: `Test-NetConnection 212.20.151.29 -Port 25` and `Test-NetConnection 212.20.151.29 -Port 993` (PowerShell, management workstation) — verification: both show `TcpTestSucceeded: False`. If either succeeds, STOP and re-escalate to the user.
2. DNSBL check of `95.46.211.224` — command: `nslookup 224.211.46.95.zen.spamhaus.org`, `nslookup 224.211.46.95.bl.spamcop.net`, `nslookup 224.211.46.95.b.barracudacentral.org` — verification: all three `NXDOMAIN`. If any is listed, STOP.
3. Confirm no listener on the mail ports on `pro-data-tech-prod` — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "sudo ss -tlnp | grep -E ':(25|465|587|993|443|8080)\b' || echo NO_MATCHING_LISTENERS"` — verification: only 443/nginx present, nothing on 25/465/587/993/8080.
4. Confirm disposition of the orphaned cert — command: `ssh ... tvolodi@95.46.211.224 "sudo certbot certificates -d mail.aiqadam.org"` — verification: cert still present, expiry ~2026-10-17; re-verify current remaining validity is still comfortably positive.

**Phase 1 — Install Stalwart via Docker Compose (isolated project), through the `stalwart-cli` install sub-phase** — unchanged from attempt 4.

5. Create the Compose directory and split data/config directories, owned by UID 2000 — command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /opt/stalwart-mail /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown -R 2000:2000 /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown tvolodi:tvolodi /opt/stalwart-mail"` — verification: `ls -la /opt/stalwart-mail` shows `etc-stalwart`/`var-lib-stalwart` owned `2000:2000`, parent owned `tvolodi:tvolodi`.
6. Generate the admin recovery password and test-account password, store by name only — command: generate locally (e.g. `openssl rand -base64 24`), never echoed to a persisted log; secret names `stalwart-mail-admin-password`, `stalwart-mail-test-account-password`.
7. Write `/opt/stalwart-mail/docker-compose.yml` (project name `stalwart-mail`, explicit `name:` key), identical to prior attempts:

   ```yaml
   name: stalwart-mail
   services:
     stalwart:
       image: stalwartlabs/stalwart:v0.16
       container_name: stalwart-mail-server-1
       restart: unless-stopped
       ports:
         - "25:25"
         - "465:465"
         - "587:587"
         - "993:993"
         - "127.0.0.1:8080:8080"
       volumes:
         - /opt/stalwart-mail/etc-stalwart:/etc/stalwart
         - /opt/stalwart-mail/var-lib-stalwart:/var/lib/stalwart
       environment:
         - STALWART_RECOVERY_ADMIN=admin:${STALWART_ADMIN_PASSWORD}
   ```

   `${STALWART_ADMIN_PASSWORD}` supplied via `/opt/stalwart-mail/.env` (mode 600, owned `tvolodi:tvolodi`). Command to write compose file: author locally, `scp` to `/opt/stalwart-mail/docker-compose.yml`; verify via `cat` diff. Command to write `.env`: `ssh ... tvolodi@95.46.211.224 "install -m 600 /dev/stdin /opt/stalwart-mail/.env <<< 'STALWART_ADMIN_PASSWORD=<value>'"` (heredoc, never a literal command-line arg or file in this repo).
8. Bring up the Compose project — command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose up -d"` — verification: `docker compose -p stalwart-mail ps` shows `stalwart-mail-server-1` `Up`/`healthy`; `docker logs stalwart-mail-server-1 --tail 50` shows `Server started in bootstrap mode`, no fatal errors, no crash loop, no randomly-generated-password banner (confirms `STALWART_RECOVERY_ADMIN` path used).

   8a. Admin UI path verification — command: `ssh ... tvolodi@95.46.211.224 "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/"` — verification: expect `302` → `/account`; record for Phase 7's nginx vhost.

9. Confirm Penpot and AiQadam-prod unregressed (mandatory no-regression checkpoint, run again as final baseline before the CLI sub-phase) — command: `ssh ... tvolodi@95.46.211.224 "docker ps --filter label=com.docker.compose.project=penpot --format '{{.Names}}: {{.Status}}'"` and `"docker ps --filter label=com.docker.compose.project=aiqadam-prod --format '{{.Names}}: {{.Status}}'"` and external `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` / `https://aiqadam.org/health` — verification: compare against this run's own pre-run baseline (captured in Phase 0); the pre-existing 4-vs-3 AiQadam-prod container discrepancy is out of scope, not a new regression.

   9a. **Install `stalwart-cli` on the host (Decision I)** — command: `ssh ... tvolodi@95.46.211.224 "curl --proto '=https' --tlsv1.2 -LsSf https://github.com/stalwartlabs/cli/releases/latest/download/stalwart-cli-installer.sh | sh"` — verification: installer completes exit code 0; installed to the user's local bin path (attempts 3–4 confirmed `/home/tvolodi/.cargo/bin/stalwart-cli`, version `1.0.10` — executor re-confirms actual path/version fresh this attempt).
   9b. Record installed CLI version — command: `ssh ... tvolodi@95.46.211.224 "<full-path-to-binary> --version"` — verification: non-empty version string captured verbatim into the execution log for audit.
   9c. Confirm the CLI's auth-flag surface — command: `ssh ... tvolodi@95.46.211.224 "<full-path-to-binary> --help"` and `"... apply --help"` — verification: confirms `--password` reads from env var `STALWART_PASSWORD` (Basic-auth, used with `--user admin`) and `--api-key` reads from `STALWART_TOKEN` (Bearer-token mode, not used by this plan). Executor uses `STALWART_PASSWORD` for all subsequent calls in Phase 3/6, never a literal password on the command line.
   9d. Smoke-test connectivity, read-only — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin describe Domain"` — verification: command succeeds (exit 0) and returns the `Domain` schema — first live confirmation the CLI can talk to the bootstrap-mode server.

**Phase 2 — Firewall rules (UFW)** — unchanged.

10. Add UFW rules for the 4 new inbound mail ports — command: `ssh ... tvolodi@95.46.211.224 "sudo ufw allow 25/tcp && sudo ufw allow 465/tcp && sudo ufw allow 587/tcp && sudo ufw allow 993/tcp"` — verification: `sudo ufw status verbose` lists all four `ALLOW IN` (v4+v6), plus existing 22/80/443. No other ports added.
11. Confirm JMAP/webadmin (8080) is NOT exposed externally — command (management workstation): `Test-NetConnection 95.46.211.224 -Port 8080` — verification: `TcpTestSucceeded: False`.

**Phase 3 — Bootstrap completion, then Domain/DKIM/submission-listener setup via `stalwart-cli`**

12. Complete the `Bootstrap` singleton before touching any other object.
    - Read-only confirmation first — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin get Bootstrap"` — verification: returns the current defaults (`defaultDomain: example.org`, `serverHostname: <container-hostname>`, `generateDkimKeys: true`, `requestTlsCertificate: true`, `directory: internal`, `dnsServer: manual`, RocksDB/local-disk storage backends). Confirms live state before mutating; if this call itself fails with anything other than the expected schema, halt and report.
    - Confirm exact `update` syntax live — command: `ssh ... "<full-path-to-binary> update --help"` and `"... update Bootstrap --help"` — verification: confirms `--field <KEY=VALUE>` repeatable form (attempt 4 confirmed this shape live; re-confirm fresh).
    - Apply the completed Bootstrap configuration — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin update Bootstrap --field defaultDomain=aiqadam.org --field serverHostname=mail.aiqadam.org --field generateDkimKeys=false --field requestTlsCertificate=false"` — leave `directory`, `dnsServer`, and the four storage-backend fields (`dataStore`/`blobStore`/`inMemoryStore`/`searchStore`) unset so they retain Stalwart's own shown defaults. Do not set `secret`/`username` (server-set, read-only). **Capture the command's own output verbatim in the execution log's working memory (not this repo) — it contains a server-generated `username`/`secret` pair for a new domain-admin account (`admin@aiqadam.org`); this is expected and is the source for Plan step 12b below, not an anomaly.**
    - Record the exit code and confirm it is 0 with no error text — verification: `Updated Bootstrap singleton` (or equivalent success message) plus the `username`/`secret` pair present in output.

    12a. **NEW — Restart the container and wait for it to report healthy.** This is the confirmed missing step: Stalwart v0.16 only re-evaluates bootstrap-mode completion at process startup; `update Bootstrap` writes the new config to its RocksDB-backed store but the running process does not re-check that state live. Root cause confirmed via isolated scratch-container reproduction (unrelated to production) and independently corroborated by the running server's own web UI bundle, which contains the literal string "restart Stalwart for the new configuration to take effect."
    - Command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose restart"` (equivalently `docker restart stalwart-mail-server-1`).
    - Wait for health — command: `ssh ... tvolodi@95.46.211.224 "docker compose -p stalwart-mail ps"` (poll, consistent with how Plan step 8 already waits for health after the initial `docker compose up -d`) — verification: `stalwart-mail-server-1` reports `Up`/`healthy` again. If the container does not return to healthy within a reasonable number of polls, halt and report — do not proceed to verification or retry the restart repeatedly without diagnosing why.
    - `docker logs stalwart-mail-server-1 --tail 50` post-restart — verification: clean startup, no crash loop, no fatal errors. (Per the confirmed finding that `update Bootstrap` itself produces zero new INFO-level log lines, this log check is about restart health, not about confirming the update took effect — that is Plan step 12b's job.)

    12b. **Verification — now run AFTER the restart, not before.** This is the specific, concrete proof that bootstrap is complete.
    - Command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin get Bootstrap"` — verification: expect **"Bootstrap singleton not found"** (or equivalent error/empty response) — this is success, not failure: it proves bootstrap mode is over, matching the confirmed scratch-container finding, not the old defaults-unchanged state attempt 4 saw pre-restart.
    - Command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin query Domain"` — verification: the "server is in bootstrap mode" rejection is GONE; the query succeeds and returns the configured `aiqadam.org` domain (created by Plan step 12's `update Bootstrap` call, now visible).
    - **Anti-retry guardrail (mandatory):** if verification still fails after this one restart — i.e., `get Bootstrap` still shows the old defaults, or `query Domain` still rejects with the bootstrap-mode error — this is now a genuinely new, unexplained situation, not the already-diagnosed restart-timing issue. Halt and report. **Do not attempt a second `update Bootstrap` call under any circumstances** — this risks a second, now-truly-orphaned `Domain` object given the `primaryKeyViolation` behavior already observed in attempt 4, and would not fix anything since the object model already has the correct data from the first call. Do not restart a second time as a blind retry either; a single, well-reasoned diagnostic pass (checking container logs, `docker inspect` health status detail, disk space, RocksDB file integrity) is appropriate before any further escalation, but no further mutating Bootstrap calls.

    12c. **NEW — Capture the domain-admin credential as a secret.** The `username`/`secret` pair from Plan step 12's `update Bootstrap` response (`admin@aiqadam.org` plus its generated password) is the real day-to-day admin login going forward. Store it under secret name `stalwart-mail-domain-admin-password` per this repo's name-only-in-repo convention — the value itself goes to external secret storage per `landscape/secrets-inventory.md`, never into any file in this repo. This plan continues using `STALWART_RECOVERY_ADMIN`/`STALWART_PASSWORD` (the existing recovery-admin credential) for all remaining CLI calls in Phase 3/6 — see "Reasoning" in Details above for why no credential switch is needed mid-run.

    - Idempotency note: `update Bootstrap` itself is idempotent-by-value in isolation, but this plan deliberately does NOT re-run it as a recovery mechanism (see 12b's guardrail) because of the confirmed `primaryKeyViolation` side effect on a second call with the same `defaultDomain`. If Phase 3 must be restarted from scratch after a genuine failure, the safe path is the Rollback section's Compose teardown (which destroys the data volume and lets a fresh install start clean), not a second `update Bootstrap` against the same running container.

13. Live schema introspection, read-only, no state mutated — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin describe Domain"`, then repeat for `DkimSignature`, `NetworkListener` — verification: `DkimSignature` has variants `Dkim1Ed25519Sha256`, `Dkim1RsaSha256`, `Dkim2Ed25519Sha256`, `Dkim2RsaSha256`; this plan uses `Dkim1Ed25519Sha256`. `NetworkListener` fields `bind`/`name`/`protocol`/`useTls`/`tlsImplicit`; `NetworkListenerProtocol` enum `smtp | lmtp | http | imap | pop3 | manageSieve` (port 587 uses `protocol: smtp`). If any of these objects' shape now materially contradicts what this plan assumes (beyond the already-known-and-planned-for `certificateManagement`/`dkimManagement`/`dnsManagement` gap), halt and report — do not improvise a substitute shape.
14. Check for pre-existing `NetworkListener` objects, now genuinely reachable post-Bootstrap — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin list NetworkListener"` (or `query NetworkListener` — whichever verb step 12b's verification confirmed works) — verification: confirms whether port 587 is already present by default — if present, the apply-plan uses `update`/`upsert` against the existing named listener rather than creating a duplicate; if absent, creates a new one. This determination is made from live output, not assumed either way.
15. Generate the DKIM keypair locally on host (Decision K; Ed25519) — command: `ssh ... tvolodi@95.46.211.224 "openssl genpkey -algorithm ED25519 -out /opt/stalwart-mail/dkim-mail-selector.pem && chmod 600 /opt/stalwart-mail/dkim-mail-selector.pem"` — verification: file exists, mode 600, non-empty.

    15a. Discover the `Domain`-level management-field shapes safely via a minimal `create` attempt — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin create Domain --field name=aiqadam.org"` — **note: the `aiqadam.org` `Domain` object was already created as a side effect of Plan step 12's `update Bootstrap` call (this is the `Domain#b`-equivalent object confirmed in attempt 4, now correctly visible post-restart per step 12b). This step therefore expects either a `primaryKeyViolation`-style "already exists" response (informative — confirms the domain from bootstrap is the one to update, not create fresh) or, if the CLI's `create` semantics differ from `update`/`upsert` for an existing object, an explicit "already exists" error naming the object.** Apply the safe-discovery distinction: a validation error naming missing/malformed field(s) with an expected-shape hint is useful discovery; an "already exists" response confirms Plan step 16 should `update`/`upsert` the existing `aiqadam.org` Domain object (by name) rather than attempt a fresh `create`; outright success is unexpected given step 12's side effect and should be treated as informative, not alarming; a connection/auth/5xx error, or a repeat of the "bootstrap mode" rejection, is a genuine blocker — halt and report.

16. Construct the NDJSON apply-plan file, informed by steps 13–15a's live-confirmed shapes — command: author `/opt/stalwart-mail/bootstrap-plan.ndjson` on host (via heredoc over the existing SSH session, not scp'd from a file in this repo, since it will briefly contain the DKIM private key content) containing `upsert` operations for: (a) `Domain` for `aiqadam.org` (update/upsert the existing object created by Plan step 12, per step 15a's finding), incorporating whatever `certificateManagement`/`dkimManagement`/`dnsManagement` shape step 15a resolved; (b) `DkimSignature` for selector `mail`, type `Dkim1Ed25519Sha256`, `domainId` referencing the `Domain` upsert, `privateKey` set to the PEM content from step 15; (c) `NetworkListener` for port 587 (create or update per step 14's finding), `protocol: smtp`, `bind: "0.0.0.0:587"`, `useTls: true`, `tlsImplicit: false` — verification: file exists on host, non-empty, valid NDJSON.
17. Apply the plan — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin apply --file /opt/stalwart-mail/bootstrap-plan.ndjson"` — verification: exit code 0, no per-line error entries in the command's own output.
18. Post-apply verification, read-only — command: `<full-path-to-binary> ... describe Domain` (or `list`/`get` equivalent) confirms `aiqadam.org` present; `describe DkimSignature` (or `get`) confirms selector `mail` present under that domain **and returns a non-empty `publicKey` value** — capture this verbatim, well-formed (`v=DKIM1...`), for Plan step 22's DNS TXT record; `describe NetworkListener` (or `list`) confirms a listener bound `0.0.0.0:587`, `protocol: smtp`, `useTls: true`, `tlsImplicit: false` is now live. If apply's exit code was 0 but any of these three post-checks fails, treat as a partial-failure state — re-run step 17 (idempotent `upsert`, safe to retry) before escalating.
19. Clean up sensitive on-host artifacts (Decision L) — command: `ssh ... tvolodi@95.46.211.224 "shred -u /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson 2>/dev/null || rm -f /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson"` — verification: `ls /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson` both report "No such file."

**Phase 4 — TLS via internal ACME** — unchanged, safe to run since `Bootstrap.requestTlsCertificate: false` guarantees no bootstrap-time ACME action already happened.

20. Configure Stalwart's internal ACME with DNS-01 challenge against the `aiqadam.org` Cloudflare zone, using the existing `cloudflare-ai-qadam-api-token` secret (no new secret) — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin describe AcmeProvider"` (or the correct object name — confirmed live) first, then construct and `apply` an `upsert` for the ACME provider config (directory: Let's Encrypt production, challenge: dns-01, provider: cloudflare, token supplied via the same `.env`-sourced env var mechanism as Phase 1, e.g. `CF_API_TOKEN`, never written to this repo) — verification: `docker logs stalwart-mail-server-1` shows a successful ACME order/issuance for `mail.aiqadam.org`; no port-80 contention with nginx since DNS-01 does not require inbound HTTP.
21. Confirm TLS actually serves correctly on 465/993 — command: `openssl s_client -connect mail.aiqadam.org:993 -servername mail.aiqadam.org </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer` — verification: subject/SAN includes `mail.aiqadam.org`, issuer Let's Encrypt, not expired. DNS-01 issuance does not require the A record to point at the host first, so step 20 may run any time after Phase 3; step 21's most meaningful run is after Phase 5's DNS cutover (also re-checked in Phase 8).

**Phase 5 — DNS cutover (Cloudflare `aiqadam.org` zone — single named-record operations only, freshness-check immediately before each write)** — unchanged from attempt 4.

All Cloudflare API calls use `cloudflare-ai-qadam-api-token` (secrets-inventory name only). Zone ID `bec8854d698d56ff17cf917367634100`. Every step: `GET` the specific record immediately before mutating it to confirm it still matches the value documented in `landscape/cloudflare.md`; abort that step and escalate if it has drifted. This run has not yet reached Phase 5 in any prior attempt — treat every record in this phase as fully un-touched; do not skip freshness-checks for any record on the assumption a previous attempt already verified it.

22. Freshness-check the current `mail.aiqadam.org` A record (`212.20.151.29`, unproxied, TTL 300) via `GET /zones/bec8854d698d56ff17cf917367634100/dns_records?name=mail.aiqadam.org&type=A`, then `PATCH` its `content` to `95.46.211.224` — verification: `GET` confirms `content: 95.46.211.224`, `modified_on` updated.
23. Freshness-check + `PATCH` the `aiqadam.org` MX record (`mail.aiqadam.org`, prio 10) — content unchanged; confirmed no-op via `GET`, skip `PATCH` if truly unchanged. **This is the cutover moment per the task's Notes — flagged for explicit separate confirmation at step 05.**
24. Freshness-check + `PATCH` the apex `aiqadam.org` SPF TXT record (`v=spf1 ip4:212.20.151.29 mx -all` → `v=spf1 ip4:95.46.211.224 mx -all`) — verification: `GET` confirms new content.
25. Freshness-check + `PATCH` the `mail._domainkey.aiqadam.org` TXT record with the new DKIM public key from Plan step 18 — verification: `GET` confirms new content; `dig TXT mail._domainkey.aiqadam.org` from an external resolver returns the new key.
26. Freshness-check + `PATCH` the `_dmarc.aiqadam.org` TXT record: `p=reject` → `p=none` (Decision 4, carried over) — verification: `GET` confirms new content.
27. Freshness-check + `PATCH` the `mail.aiqadam.org` TXT (`v=spf1 a -all`) — no change needed, confirmed via `GET` only.
28. Freshness-check + delete `webmail.aiqadam.org` A record (carried-over decision — no webmail product stood up this pass) — command: `DELETE /zones/.../dns_records/<webmail-record-id>` — verification: `GET` returns 404.
29. Freshness-check + handle the 4 stale CNAMEs (`autoconfig`, `autodiscover`, `mta-sts`, `ua-auto-config`): `autoconfig`/`autodiscover` require no content change — verify Stalwart actually serves valid autoconfig/autodiscover responses post-cutover (Phase 8); if not, follow-on fix. `mta-sts`/`ua-auto-config` CNAMEs plus their corresponding TXT records (`_mta-sts.aiqadam.org`, `_ua-auto-config.aiqadam.org`) — **delete**, carried-over decision. Verification: `GET` on deleted record IDs returns 404; `GET` on `autoconfig`/`autodiscover` confirms unchanged; live HTTP probe to `https://autoconfig.aiqadam.org/mail/config-v1.1.xml` post-cutover.
30. Freshness-check + handle the 6 stale SRV records: `_imaps._tcp`, `_jmap._tcp`, `_submissions._tcp` — no content change needed. `_caldavs._tcp`, `_carddavs._tcp`, `_pop3s._tcp` — **delete**, carried-over decision. Verification: `GET` on deleted record IDs returns 404; `GET` on retained records confirms unchanged.
31. Freshness-check + `_smtp._tls.aiqadam.org` TXT (TLS-RPT) — no change needed, confirmed via `GET` only.
32. **Explicitly out of scope, confirmed unchanged, not touched:** `resend._domainkey.aiqadam.org`, `send.aiqadam.org` MX/TXT (SES), wildcard `*.aiqadam.org`, all 5 tunnel/GitHub-Pages records. Verification: post-cutover full zone dump diffed against pre-run snapshot confirms byte-for-byte unchanged.

**Phase 6 — Mailbox provisioning** — unchanged from attempt 4.

33. Create one test mailbox via `stalwart-cli` — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin describe Account"` (read-only schema confirmation) — verification: confirms `name`/`domainId`/`roles`/`permissions`/`credentials` field shape live, before constructing the create call.
34. Generate the test account's password (already generated at Plan step 6, secret name `stalwart-mail-test-account-password`) and create the account — command: `ssh ... tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' <full-path-to-binary> --url http://127.0.0.1:8080 --user admin create Account --name test --domain-id aiqadam.org --credentials-secret <value via stdin/heredoc, not a literal arg>"` (exact flag names per step 33's confirmed CLI help output; if `create` does not support this object type directly, fall back to the same `apply`-with-NDJSON mechanism as Phase 3, one `upsert` for the `Account`/`User` object) — verification: a subsequent `... describe Account` (or `list`) shows `test@aiqadam.org` present.
35. Document the mailbox provisioning mechanism (confirmed `stalwart-cli` command shape) in `landscape/hosts/pro-data-tech-prod.md` at step 08.

**Phase 7 — nginx vhost for Stalwart webadmin** — unchanged from attempt 4.

36. Add nginx vhost proxying `https://mail.aiqadam.org/` (root, per the empirically-confirmed `/account` SPA redirect) to `127.0.0.1:8080`, TLS via the existing certbot pattern, reusing the orphaned cert from attempt 1 — command: write `/etc/nginx/sites-available/mail.aiqadam.org` (proxy_pass `http://127.0.0.1:8080`, ssl_certificate pointing at `/etc/letsencrypt/live/mail.aiqadam.org/`), symlink to `sites-enabled`, `sudo nginx -t && sudo systemctl reload nginx` — verification: `https://mail.aiqadam.org/` returns Stalwart's login/portal page (200 or 302→/account), external probe from management workstation.

    Note (unchanged): `mail.aiqadam.org` has TLS served two ways for two different purposes — nginx+certbot for the admin UI on 443, Stalwart's own internal ACME cert for SMTP/IMAP TLS on 465/993/587/25. Not a conflict; flagged for step 08's landscape documentation.

**Phase 8 — Verification / deliverability testing** — unchanged from attempt 4.

37. Internal SMTP/IMAP/JMAP/submission reachability — command (management workstation): `Test-NetConnection mail.aiqadam.org -Port 25`, `-Port 465`, `-Port 587`, `-Port 993` — verification: all `TcpTestSucceeded: True`.
38. TLS validity (SMTP/IMAP side, internal ACME) — per Plan step 21, re-run now that DNS fully resolves externally.
39. DNS propagation checks — command: `nslookup mail.aiqadam.org 1.1.1.1`, `nslookup -type=MX aiqadam.org 1.1.1.1`, `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1`, `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` — verification: each resolves to the new values externally.
40. External send/receive test: external Gmail (or equivalent) → `test@aiqadam.org`, confirm receipt via IMAP; `test@aiqadam.org` → external address, confirm arrival (inbox or spam, both acceptable per task's Notes).
41. mail-tester.com score captured as deliverability baseline, recorded in `landscape/hosts/pro-data-tech-prod.md` and task close-out notes.

**Phase 9 — Backups** — unchanged from attempt 4.

42. Local-disk-only backup of Stalwart's data directory — command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /var/backups/stalwart-mail && sudo tar czf /var/backups/stalwart-mail/stalwart-data-$(date +%Y%m%dT%H%M%SZ).tar.gz -C /opt/stalwart-mail var-lib-stalwart etc-stalwart"` — verification: `ls -la /var/backups/stalwart-mail/` shows the new tarball, non-zero size. Daily cron/systemd-timer, 14-day local retention — recommended follow-on, not built into this pass.

### Rollback

Rollback remains phase-scoped; DNS and host-install rollback are independent.

1. **Compose install rollback (Phases 0–1, steps 5–9d):** `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose down"` then `sudo rm -rf /opt/stalwart-mail` — fully reversible; no external state touched at this point. This also removes any `stalwart-cli`-created bootstrap/Domain/DKIM/listener state since it all lives inside the deleted `var-lib-stalwart` bind mount. The `stalwart-cli` binary itself (installed at step 9a to the host's user-local bin path, not inside `/opt/stalwart-mail`) is left in place on rollback — harmless, inert, no running state, no network exposure; removing it is optional cleanup, not required for a clean rollback.
2. **UFW rules rollback (Phase 2, step 10):** `ssh ... tvolodi@95.46.211.224 "sudo ufw delete allow 25/tcp && sudo ufw delete allow 465/tcp && sudo ufw delete allow 587/tcp && sudo ufw delete allow 993/tcp"` — fully reversible.
3. **Bootstrap/Domain/DKIM/listener/ACME config rollback (Phase 3–4, steps 12–20), including the new restart step 12a:** state lives inside `/opt/stalwart-mail/var-lib-stalwart`, deleted wholesale by rollback item 1 — no separate rollback needed. **Explicitly confirmed for this retry (per the retry brief's request to state this, not assume it silently): a restart-completed bootstrap is still fully covered by "delete the whole `/opt/stalwart-mail` tree."** The restart at step 12a is a process-level operation (the container process re-reads its own already-persisted RocksDB state on startup) — it creates no new state of its own outside `var-lib-stalwart`/`etc-stalwart`, both already inside the bind-mounted tree that rollback item 1 deletes. Nothing about completing bootstrap via a restart changes where any state lives on disk; the same reasoning attempt 4 already established (a future re-run against a blank volume restarts fresh in bootstrap mode regardless of what "completing" bootstrap did or didn't change server-side) continues to hold unmodified. If only a partial rollback is needed (redo Phase 3 without reinstalling Compose), the safe path per step 12's idempotency note is a full Compose teardown-and-reinstall, not a second `update Bootstrap` against the same running container (see the anti-retry guardrail at step 12b). The on-host DKIM private key PEM and NDJSON plan file are deleted by Plan step 19 in the normal forward path; if rollback occurs before step 19 ran, the rollback's `rm -rf /opt/stalwart-mail` also removes them.
4. **DNS rollback (Phase 5, steps 22, 24, 25, 26):** re-`PATCH` each record back to its pre-change documented value (A record → `212.20.151.29`; SPF → `v=spf1 ip4:212.20.151.29 mx -all`; DKIM TXT → prior RSA key value, captured verbatim from `landscape/cloudflare.md` before this run's changes; DMARC → `p=reject`). Clean no-op only before real mail traffic and external SPF-cache pickup occur; once mailboxes are in active use, DNS rollback is an emergency-stop, not a safe revert.
5. **Deleted-record rollback (Phase 5, steps 28, 29, 30 — `webmail`, `mta-sts`/`ua-auto-config`, `_caldavs`/`_carddavs`/`_pop3s`):** re-`CREATE` each deleted record with its exact pre-deletion name/type/content/TTL, captured verbatim from `landscape/cloudflare.md` before this run executes. Record IDs will differ on recreate; update landscape at step 08 regardless.
6. **Mailbox/data rollback (Phase 6):** delete the test account via `stalwart-cli delete Account` (or `apply` with a `delete` op against the same NDJSON convention) — no real user data exists in this plan's scope; also covered wholesale by rollback item 1 if the full Compose project is torn down.
7. **nginx vhost rollback (Phase 7, step 36):** `ssh ... tvolodi@95.46.211.224 "sudo rm /etc/nginx/sites-enabled/mail.aiqadam.org && sudo nginx -t && sudo systemctl reload nginx"` — fully reversible; does not touch the orphaned certbot cert itself.
8. **Orphaned cert:** no rollback action needed either way — remains valid/inert if Phase 7 is rolled back after being reached.
9. **No rollback needed for Phase 8 (verification, read-only) or Phase 9 (backup, additive-only).**

### Verification (for step 07)

- **On-host:**
  - `docker compose -p stalwart-mail ps` → `stalwart-mail-server-1` `Up`/`healthy` (checked both after initial `up -d` at step 8 and after the restart at step 12a).
  - `docker logs stalwart-mail-server-1 --tail 100` (post-restart) → no fatal errors, no crash-loop restarts, no randomly-generated-password banner.
  - `stalwart-cli --version` → non-empty version string, recorded.
  - `get Bootstrap` (post-restart, step 12b) → **"Bootstrap singleton not found"** (or equivalent) — proves bootstrap mode is over.
  - `query Domain` (post-restart, step 12b) → succeeds, returns `aiqadam.org` — no bootstrap-mode rejection.
  - `sudo ufw status verbose` → 22/80/443/25/465/587/993 all `ALLOW IN`, no other new rules.
  - `sudo ss -tlnp` → confirms 25/465/587/993 bound `0.0.0.0`, 8080 bound `127.0.0.1` only.
  - `ls -la /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart` → owned `2000:2000`.
  - `ls /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson` → both absent (cleaned up per Decision L).
  - Penpot: `docker ps --filter label=com.docker.compose.project=penpot` → all containers `Up` (compare pre/post this run, including across the step 12a restart — Penpot/AiQadam-prod containers are unaffected by a `docker compose restart` scoped to the `stalwart-mail` project only).
  - AiQadam prod: `docker ps --filter label=com.docker.compose.project=aiqadam-prod` → all containers `Up` (same caveat).
  - `stalwart-cli ... describe Domain` / `get Domain` → `aiqadam.org` present with the management settings this plan set.
  - `stalwart-cli ... describe DkimSignature` / `get` → selector `mail`, type `Dkim1Ed25519Sha256`, present, `publicKey` non-empty.
  - `stalwart-cli ... describe NetworkListener` / `list` → a listener bound `0.0.0.0:587`, `protocol: smtp`, `useTls: true`, `tlsImplicit: false` present.
  - `stalwart-cli ... describe Account` (or `list`) → `test@aiqadam.org` present.
  - `/var/backups/stalwart-mail/` contains at least one non-zero-size tarball.
  - `sudo certbot certificates -d mail.aiqadam.org` → still shows the attempt-1 cert, now referenced by the new nginx vhost.
- **External:**
  - `Test-NetConnection mail.aiqadam.org -Port 25/465/587/993` → all `TcpTestSucceeded: True`.
  - `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` → 200 (no regression, including across the step 12a restart).
  - `Invoke-WebRequest https://aiqadam.org/health` → 200 (no regression).
  - `Invoke-WebRequest https://mail.aiqadam.org/` → 200/302, Stalwart portal reachable via nginx proxy.
  - `openssl s_client -connect mail.aiqadam.org:993 ...` → cert subject `mail.aiqadam.org`, Let's Encrypt issuer, not expired.
  - `nslookup mail.aiqadam.org 1.1.1.1` → `95.46.211.224`.
  - `nslookup -type=MX aiqadam.org 1.1.1.1` → `mail.aiqadam.org` prio 10.
  - `nslookup -type=TXT aiqadam.org 1.1.1.1` (SPF) → `v=spf1 ip4:95.46.211.224 mx -all`.
  - `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1` → `v=DMARC1; p=none; rua=mailto:postmaster@aiqadam.org`.
  - `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` → new DKIM key present, matching Plan step 18's captured `publicKey`.
  - External send test to `test@aiqadam.org` from Gmail → delivered (confirm via IMAP fetch).
  - External send test from `test@aiqadam.org` to Gmail → arrives (inbox or spam, record which).
  - mail-tester.com score captured and recorded.
  - Full Cloudflare zone dump (post-cutover) diffed against pre-run snapshot: confirms `resend._domainkey`, `send.aiqadam.org` MX/TXT, wildcard, and all 5 tunnel/pages records byte-for-byte unchanged.

### Resources used
- **Secrets (by name):** `cloudflare-ai-qadam-api-token` (existing, used both for DNS cutover and Stalwart's internal ACME DNS-01 challenge); new entries to be added at step 08: `stalwart-mail-admin-password` (`STALWART_RECOVERY_ADMIN`), `stalwart-mail-domain-admin-password` (new — the `admin@aiqadam.org` credential generated by the `update Bootstrap` call at Plan step 12, captured per step 12c), `stalwart-mail-dkim-private-key` (generated on-host via `openssl`, consumed into Stalwart's config registry then shredded from disk — the value never persists in this repo), `stalwart-mail-test-account-password`.
- **Files modified on host (`pro-data-tech-prod`):** new `/opt/stalwart-mail/docker-compose.yml`, `/opt/stalwart-mail/.env` (mode 600), `/opt/stalwart-mail/etc-stalwart/`, `/opt/stalwart-mail/var-lib-stalwart/`; transient (deleted by Plan step 19) `/opt/stalwart-mail/dkim-mail-selector.pem`, `/opt/stalwart-mail/bootstrap-plan.ndjson`; `stalwart-cli` binary installed to the `tvolodi` user's local bin path; new `/etc/nginx/sites-available/mail.aiqadam.org` (+ symlink), reusing existing `/etc/letsencrypt/live/mail.aiqadam.org/`; UFW rules (4 new `allow` entries); new `/var/backups/stalwart-mail/`.
- **Files modified in this repo (`landscape/`) — to be applied at step 08:**
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) (new Stalwart Mail section — image/volume/config model; Bootstrap configuration values recorded, including the restart-required-for-effect behavior as an operational gotcha; new UFW rules; new Compose project; new nginx vhost; `stalwart-cli` noted as an installed host-level admin tool with its confirmed version; note on the previously-orphaned-now-reused cert; note on internal ACME as a second TLS mechanism on this host; mailbox provisioning mechanism documented as `stalwart-cli create`/`apply`)
  - [landscape/services.md](../../landscape/services.md) (new Compose project row under `pro-data-tech-prod`)
  - [landscape/cloudflare.md](../../landscape/cloudflare.md) (A/MX/SPF/DKIM/DMARC record changes, record deletions, reclassify mail records table)
  - [landscape/domains.md](../../landscape/domains.md) (new `mail.aiqadam.org` subdomain + TLS cert entry, noting the dual TLS mechanism)
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) (new mail-related secret names, including `stalwart-mail-domain-admin-password`)
  - [shared/app-registry.md](../../shared/app-registry.md) optionally, at designer's discretion
- **External APIs called:** Cloudflare DNS API (`GET`/`PATCH`/`DELETE` on named records only, zone `bec8854d698d56ff17cf917367634100`) — called both directly by the executor for DNS cutover, and indirectly by Stalwart itself for ACME DNS-01 challenges using the same token. `github.com/stalwartlabs/cli` GitHub Releases (fetched once, by the installer script, to install the CLI binary).

### Estimated impact
- **Downtime:** none for Penpot/AiQadam prod — the new step 12a restart is scoped to the `stalwart-mail` Compose project only (`docker compose -p stalwart-mail restart` / `docker restart stalwart-mail-server-1`), does not touch the `penpot` or `aiqadam-prod` Compose projects or their containers, and is verified via the same no-regression checkpoints already in the plan. For mail itself: none in the outage sense (old service already confirmed dead, and Stalwart itself has no live traffic yet at the point of this restart — it is still mid-bootstrap). The MX/A-record cutover (Phase 5, steps 22/23) remains the moment mail routing for `aiqadam.org` becomes live on repo-controlled infrastructure for the first time.
- **Affected services:** New: Stalwart mail (SMTP/IMAP/JMAP/submission) on `pro-data-tech-prod`, plus a new nginx vhost for its admin UI, plus a new host-level CLI tool (`stalwart-cli`). Unaffected (verified at every checkpoint, including across the new restart): Penpot, AiQadam prod. Affected indirectly: the shared `aiqadam.org` Cloudflare zone (mail-records partition only, not reached until Phase 5).
- **Reversibility:** Host install, UFW rules, nginx vhost, CLI tool, and the Bootstrap-completion-plus-restart sequence — fully reversible, no data loss (confirmed explicitly in Rollback item 3 above: the restart itself creates no state outside the already-deleted-on-rollback bind-mounted volume tree). DNS changes — technically reversible at the record level, but practically a one-way operational event once real mail traffic begins.

## Issues / risks

- **HIGH — shared-host blast radius (carried over, unchanged from attempts 1–4).** Placing mail on `pro-data-tech-prod` adds spam/abuse exposure and cold-IP reputation risk to the same host serving Penpot and AiQadam prod. Already accepted by the user at step 05 attempts 1–4.
- **HIGH — DNS is shared, partially-owned zone surgery (carried over, unchanged).** Same class of operation as T-0111's apex repoint; multiple record types, several deletions; irreversible-in-practice once mail traffic begins. Not yet reached by any attempt so far.
- **LOW — the restart-required-for-bootstrap-completion behavior is now confirmed, not speculative, but this retry's plan is the first time it is exercised against `pro-data-tech-prod` itself** (the confirming reproduction happened in an isolated scratch container). Residual risk is that some detail of the real host environment (volume permissions, container health-check timing, restart policy interaction) behaves subtly differently than the scratch container — mitigated by the explicit health-wait in step 12a and the anti-retry guardrail in step 12b, which converts any unexpected divergence into a clean halt-and-report rather than a blind retry loop.
- **MEDIUM — `stalwart-cli`'s exact command syntax for `update Bootstrap`, and elsewhere (subcommand/flag names, exact auth-flag form), is confirmed live at execution time rather than hand-specified verbatim, consistent with the discipline already used successfully throughout attempts 3–4.** If live `--help`/`describe` output surfaces something that materially contradicts this plan's assumptions about the object model, the executor must halt and report as a plan defect, not improvise.
- **MEDIUM — DKIM private key material is generated and briefly held in plaintext on host disk (`/opt/stalwart-mail/dkim-mail-selector.pem`) before being consumed into Stalwart's own config registry and shredded (Decision L, Plan step 19).** Unchanged. The window of plaintext exposure is limited to the single execution session, on a host already SSH-key-only and firewalled.
- **MEDIUM — installing `stalwart-cli` via "latest" rather than a pinned release is a deliberate, narrow exception to this repo's pinning convention (Decision I), already approved at attempt 3's step 05.** Not reopened here.
- **MEDIUM — dual TLS mechanisms on one host for one hostname (nginx+certbot for the admin UI on 443; Stalwart's internal ACME for SMTP/IMAP/submission on 465/587/993) — carried over, unchanged.** Not a conflict; a documentation/mental-model complexity flagged for step 08.
- **MEDIUM — CalDAV/CardDAV/POP3 and MTA-STS record deletions (carried over, unchanged, already approved).** Re-noted for completeness — functional regression vs. the old dead server's apparent feature set.
- **LOW — the `certificateManagement`/`dkimManagement`/`dnsManagement` inline-object shapes remain genuinely unresolved until Plan step 15a's live discovery runs** — now complicated slightly by the fact that the `aiqadam.org` Domain object already exists (created as a side effect of step 12's `update Bootstrap` call), so step 15a's `create` attempt is now expected to surface an "already exists" response rather than a fresh-creation validation error; the safe-discovery distinction has been updated accordingly (see step 15a's revised text) — this is a designed-for, reasoned adjustment, not a new gap.
- **LOW — Stalwart's internal ACME via DNS-01 depends on the `cloudflare-ai-qadam-api-token` secret's scope permitting TXT record creation/deletion for `_acme-challenge.mail.aiqadam.org`.** Already scoped to Zone.DNS edit on the whole zone; executor confirms the first issuance succeeds rather than assuming silently.
- **LOW — autoconfig/autodiscover records left pointing at `mail.aiqadam.org` on the assumption Stalwart serves valid responses there (carried over, unchanged) — verified post-cutover, not guaranteed by this design.**
- **LOW — resource contention.** Unchanged: mail for dozens of mailboxes is small relative to this host's spare capacity.
- **LOW — version drift risk for the pinned server image (`v0.16`), unchanged** — a deliberate future-upgrade task will be needed eventually, acceptable tradeoff.

## Open questions (optional)

None are BLOCKED-triggering — the plan is complete and executable, and the one item that required fresh user judgment in this design lineage (the `generateDkimKeys`/`requestTlsCertificate` Bootstrap flag values) was already resolved and explicitly approved at attempt 4's step 05. This retry's single change — inserting a restart-and-health-wait between the already-approved `update Bootstrap` call and its verification, plus capturing the resulting domain-admin credential as a new secret — is a mechanism fix of the same character as the auth-env-var, protocol-enum, and DKIM-variant corrections already folded into attempt 4 without separate re-confirmation, and squarely within the user's standing delegation ("All up to you. Call me when everything will be ready," extended explicitly at attempt 4's approval to remain in effect "for the remainder of this run"). Recommend the orchestrator proceed directly to writing the step-05 approval handoff under that delegation and advance to step 06 (executor-infra, attempt 5), rather than initiating a fresh user round-trip.
