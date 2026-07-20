---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-19T05:30:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-04
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-04-solution-designer-attempt-2.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-2.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-05-user-approval-attempt-2.md
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
next_step_hint: step-05 must re-confirm the eleven decisions already approved in attempt 2 (host, software, hostname, DMARC policy, outbound relay, volume layout, internal ACME/DNS-01, reuse of orphaned cert, port 587, MTA-STS/CalDAV/CardDAV/POP3 record deletions, admin UI root path) were not reopened, and only needs fresh sign-off on the new bootstrap mechanism (installing stalwartlabs/cli on-host and driving Domain/DkimSignature/NetworkListener/Account setup via `stalwart-cli describe` + `apply`, replacing the nonexistent-admin-API approach that caused attempt 2 to BLOCK) plus the same named MX-cutover go/no-go gate as before.
---

## Summary
Third-attempt retry: install Stalwart Mail Server v0.16 via Docker Compose on `pro-data-tech-prod` exactly as attempt 2 planned (image, volumes, UID 2000, `STALWART_RECOVERY_ADMIN`, internal ACME/DNS-01, port 587, firewall, DNS cutover, backups all unchanged), but replace the bootstrap/setup mechanism attempt 2 got wrong (a nonexistent ad hoc admin REST/JMAP API) with the real, documented mechanism: install the separate `stalwart-cli` client tool on the host, use its read-only `describe` command to confirm live schema before constructing anything, then apply an idempotent NDJSON plan (`stalwart-cli apply`) to create the `Domain`, `DkimSignature`, and `NetworkListener` objects, and use `stalwart-cli create`/`apply` for the test `Account` — end state is unchanged from attempt 2: a working, repo-owned, TLS-secured, firewalled mail server with the old dead records fully retired.

## Details

### What changed since attempt 2 (root cause: no ad hoc admin REST/JMAP "setup API" exists — bootstrap requires the separate `stalwart-cli` tool)

Attempt 2 failed at Plan step 12 because it assumed the web setup wizard's actions were "themselves exposed via the same admin API the web UI calls," reachable by ad hoc authenticated `curl` calls with payload shapes to be "confirmed against this running v0.16 instance's own API/OpenAPI surface at execution time." The executor's empirical investigation (documented in `.attempts/step-06-executor-infra-attempt-2.md`) proved this false: the server image ships exactly one binary with no subcommands, `/api/schema/<token>` is a UI-form-rendering schema (not a route map), and JMAP `Bootstrap`/`Principal`-based domain creation does not exist as a callable method. Stalwart's own maintainers confirmed (GitHub Discussion #3013) that the CLI is intentionally a **separate repository** (`github.com/stalwartlabs/cli`, distinct from `stalwartlabs/stalwart`), "maintained and compiled separately so it won't be included in Docker images." This is expected packaging, not a defect in the server image — attempt 2's plan defect was assuming a capability that was never meant to ship in that image.

This retry corrects **only** Phase 1's tail end (adding a CLI-install sub-phase), old Phase 3 (admin setup/DKIM), and old Phase 6 (mailbox provisioning). **Every decision from attempt 2 below is preserved verbatim, not re-litigated:**

1. Host placement: `pro-data-tech-prod` (unchanged).
2. Software: Stalwart Mail Server, image `stalwartlabs/stalwart:v0.16`, pinned (unchanged).
3. Mail hostname: reuse `mail.aiqadam.org` (unchanged).
4. DMARC day-one policy: `p=none` with `rua` reporting (unchanged).
5. Outbound relay: direct-send, not SES-relayed (unchanged).
6. Volumes: split `/etc/stalwart` (config) + `/var/lib/stalwart` (data), UID 2000 (unchanged).
7. TLS: Stalwart's internal ACME via DNS-01 against the `cloudflare-ai-qadam-api-token` secret (unchanged).
8. Orphaned attempt-1 certbot cert: reused for the nginx-proxied admin UI on port 443 (unchanged).
9. Port 587 explicitly enabled alongside 465/993 defaults (unchanged).
10. Deletion of MTA-STS/TLS-RPT-pointing records and CalDAV/CardDAV/POP3 SRV records (unchanged, approved at attempt 1's step 05).
11. Admin UI path: proxy bare root, not `/admin` — already empirically confirmed by attempt 2's executor (`302` → `/account`, SPA-routed) (unchanged, now confirmed rather than merely planned).

### New decisions this retry must make (corrected bootstrap mechanism)

**I. Install `stalwart-cli` on `pro-data-tech-prod` via the official shell installer, unpinned ("latest").**
The CLI is a genuinely separate client tool (not the server) that talks to a running Stalwart instance over HTTP — it does not need to run inside the server container. Recommend running it directly on the host (option (a) from the retry brief) against `http://127.0.0.1:8080`, consistent with how certbot and Docker CLI already run directly on this host rather than through a proxy hop.

Pinning exception, stated explicitly: this repo's convention (Penpot `:2.16`, Stalwart server `:v0.16`) is to pin container image tags. The `stalwart-cli` shell installer (`stalwart-cli-installer.sh`) installs whatever is tagged "latest" on its GitHub Releases page; the installer itself does not document a `--version` flag in the material available at design time. This plan accepts installing via the "latest" release as a reasonable, narrow exception to the pinning rule because: (a) the CLI is a stateless client tool, not a long-running service — version drift here does not change what is running in production the way a server image tag would; (b) it only executes at bootstrap/administration time, under human/executor supervision, not unattended; (c) forcing a specific historical CLI release would require either downloading a versioned tarball by hand (undocumented URL pattern, higher risk of guessing wrong) or building from source, both of which add more risk than the "latest client, pinned server" split. If the executor finds the installer does support explicit version pinning (e.g., a documented release-tag URL pattern) at execution time, it should prefer that — this is a genuine "confirm and prefer stricter behavior if available" instruction, not permission to skip the check.

The one thing that IS locked down: the CLI must be pointed at the pinned `v0.16` server only, and the executor must record the exact CLI version string it ends up with (`stalwart-cli --version` or equivalent) in this run's execution log, so a future audit knows precisely what was used even though it wasn't pre-pinned in this plan.

**J. Bootstrap mechanism: `stalwart-cli describe` (read-only) first, then `stalwart-cli apply` against a hand-constructed NDJSON plan file.**
Replaces attempt 2's Decision D (ad hoc admin API calls). Sequence:
1. `stalwart-cli describe Domain`, `describe DkimSignature`, `describe NetworkListener`, `describe Account` — live, read-only schema introspection against the running (still-in-bootstrap) v0.16 instance. Zero risk of mutating state. This confirms the exact current field names and enum values (in particular the `certificateManagement`/`dkimManagement`/`dnsManagement` variants on `Domain`, and whether `DkimSignature.privateKey` truly must be supplied or can be server-generated) **before** the executor writes a single line of the apply-plan JSON.
2. Generate a DKIM keypair locally on the host via `openssl` (this plan does NOT assume Stalwart auto-generates one — see Decision K) unless `describe DkimSignature` output positively confirms an auto-generation path exists, in which case the executor may use that instead and must note which path it took in the execution log.
3. Construct an NDJSON apply-plan file (`/opt/stalwart-mail/bootstrap-plan.ndjson`, on host, not committed to this repo — contains no secret values itself except by reference, but treat as sensitive since it contains the DKIM private key material and domain config; delete after successful apply per Decision L) containing `upsert` operations for: one `Domain` object (`aiqadam.org`), one `DkimSignature` object (selector `mail`, referencing the domain, private key supplied), and `NetworkListener` object(s) confirming/creating the port-587 STARTTLS submission listener.
4. `stalwart-cli apply --file /opt/stalwart-mail/bootstrap-plan.ndjson --url http://127.0.0.1:8080 --user admin --password <STALWART_ADMIN_PASSWORD>` (password supplied via `STALWART_TOKEN`/env-var mechanism the CLI supports, not as a bare CLI arg that would appear in shell history or `ps` output — executor confirms the CLI's actual non-history-leaking auth flag at step 1's `--help` inspection before running this).
5. Verification: `stalwart-cli describe Domain` (or equivalent list/get) re-run post-apply confirms `aiqadam.org` present with the intended management settings; `describe DkimSignature` confirms selector `mail` present and returns a `publicKey` value (captured verbatim for the DNS TXT record); `describe NetworkListener` confirms a listener bound `0.0.0.0:587` with `useTls: true`/`tlsImplicit: false` (STARTTLS) present.

This is `apply`'s documented idempotent IaC-style mode (`upsert` matched on `name`/natural key), so re-running step 4 after a partial failure is safe — this satisfies the workflow's idempotency rule without a separate "detect partial state" branch.

**K. DKIM private key origin: generated explicitly via `openssl`, not assumed auto-generated.**
Per the retry brief and the genuine documentation gap: this plan does not assume Stalwart's CLI/apply path silently generates a DKIM keypair. The executor generates it explicitly:
```
openssl genpkey -algorithm ED25519 -out /opt/stalwart-mail/dkim-mail-selector.pem
```
(Ed25519 preferred per Stalwart's `Dkim1Ed25519Sha256` variant if `describe DkimSignature`'s enum confirms it's supported and the executor judges it appropriate; RSA-2048 via `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048` as the fallback if the live `describe` output indicates only the RSA variant is accepted or if Ed25519 DNS TXT record support is a concern — **executor decides based on the live `describe DkimSignature` enum output, records which variant it used and why in the execution log; this is exactly the kind of live-confirmed decision the retry brief calls for, not a guess**). The private key file permissions are locked to `600`, owned `tvolodi:tvolodi` during construction, and the file is deleted (Decision L) once its contents have been consumed into the apply-plan and applied successfully. The **public** key/DNS-record value is captured from `stalwart-cli describe DkimSignature`'s output post-apply (server-derived, per the retry brief's field list), not computed independently — this ensures the DNS TXT record matches exactly what Stalwart itself will sign with, avoiding any transcription mismatch.

**L. Cleanup of sensitive on-host artifacts after bootstrap.**
The apply-plan NDJSON file and the standalone DKIM private key PEM both contain the DKIM private key in plaintext on host disk during construction. Both are deleted (`shred -u` preferred if available, else `rm -f`) immediately after `stalwart-cli apply` succeeds and post-apply verification confirms the `DkimSignature` object is live inside Stalwart's own config registry (`/var/lib/stalwart`, not a plaintext file this plan writes). This is a new step attempt 2 did not need (it never got far enough to generate key material) — flagged explicitly per the "secrets by name only, never values, in this repo" rule, applied here to the host filesystem too, not just this repo.

**M. Account (test mailbox) creation: `stalwart-cli create Account` (or `apply` with an `Account`/`User` upsert), replacing attempt 2's admin-API assumption.**
Same tool, same session. `emailAddress` is server-derived as `name@domain` per the retry brief's confirmed field list — the executor supplies `name: "test"`, `domainId` referencing the now-created `aiqadam.org` domain, `roles`, and `credentials: [{"@type":"Password","secret":"<generated>"}]`. Verification: `stalwart-cli describe Account` (or `list`) shows `test@aiqadam.org` present.

### Plan

**Phase 0 — Pre-flight discovery (read-only, must run and be recorded before any state change)**

Unchanged in substance from attempt 2; must be re-run fresh (attempt 2's Phase 0 results are one attempt stale):

1. Re-probe the dead host's mail ports live — command: `Test-NetConnection 212.20.151.29 -Port 25` and `Test-NetConnection 212.20.151.29 -Port 993` (PowerShell, management workstation) — verification: both show `TcpTestSucceeded: False`. If either succeeds, STOP and re-escalate to the user.
2. DNSBL check of `95.46.211.224` — command: `nslookup 224.211.46.95.zen.spamhaus.org`, `nslookup 224.211.46.95.bl.spamcop.net`, `nslookup 224.211.46.95.b.barracudacentral.org` — verification: all three `NXDOMAIN`. If any is listed, STOP.
3. Confirm no listener on the mail ports on `pro-data-tech-prod` — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "sudo ss -tlnp | grep -E ':(25|465|587|993|443|8080)\b' || echo NO_MATCHING_LISTENERS"` — verification: only 443/nginx present, nothing on 25/465/587/993/8080 (attempts 1 and 2 both confirmed this cleanly; re-verify, do not assume).
4. Confirm disposition of the orphaned cert — command: `ssh ... tvolodi@95.46.211.224 "sudo certbot certificates -d mail.aiqadam.org"` — verification: cert still present, expiry ~2026-10-17 (attempt 2 confirmed this at 89 days remaining; re-verify current remaining validity is still comfortably positive).

**Phase 1 — Install Stalwart via Docker Compose (isolated project) — unchanged from attempt 2 through step 9, plus a new sub-phase (steps 9a–9d) installing `stalwart-cli`**

5. Create the Compose directory and split data/config directories, owned by UID 2000 — command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /opt/stalwart-mail /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown -R 2000:2000 /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart && sudo chown tvolodi:tvolodi /opt/stalwart-mail"` — verification: `ls -la /opt/stalwart-mail` shows `etc-stalwart`/`var-lib-stalwart` owned `2000:2000`, parent owned `tvolodi:tvolodi`.
6. Generate the admin recovery password and test-account password, store by name only — command: generate locally (e.g. `openssl rand -base64 24`), never echoed to a persisted log; secret names `stalwart-mail-admin-password`, `stalwart-mail-test-account-password`.
7. Write `/opt/stalwart-mail/docker-compose.yml` (project name `stalwart-mail`, explicit `name:` key), identical to attempt 2:

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
8. Bring up the Compose project — command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose up -d"` — verification: `docker compose -p stalwart-mail ps` shows `stalwart-mail-server-1` `Up`/`healthy`; `docker logs stalwart-mail-server-1 --tail 50` shows no fatal errors, no randomly-generated-password banner (confirms `STALWART_RECOVERY_ADMIN` path used, as attempt 2's executor already empirically confirmed works correctly).

   8a. Admin UI path verification — command: `ssh ... tvolodi@95.46.211.224 "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/"` — verification: expect `302` → `/account` (already empirically confirmed by attempt 2's executor); record for Phase 7's nginx vhost.

9. Confirm Penpot and AiQadam-prod unregressed (mandatory no-regression checkpoint, run again as final baseline before Phase 1's CLI sub-phase) — command: `ssh ... tvolodi@95.46.211.224 "docker ps --filter label=com.docker.compose.project=penpot --format '{{.Names}}: {{.Status}}'"` and `"docker ps --filter label=com.docker.compose.project=aiqadam-prod --format '{{.Names}}: {{.Status}}'"` and external `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` / `https://aiqadam.org/health` — verification: compare against this run's own pre-run baseline (captured in Phase 0), not the possibly-stale landscape count (attempt 2's executor already documented a pre-existing 4-vs-3 AiQadam-prod container discrepancy — out of scope, do not investigate, just don't treat it as a new regression).

   9a. **Install `stalwart-cli` on the host (Decision I)** — command: `ssh ... tvolodi@95.46.211.224 "curl --proto '=https' --tlsv1.2 -LsSf https://github.com/stalwartlabs/cli/releases/latest/download/stalwart-cli-installer.sh | sh"` — verification: installer completes exit code 0; installed to the user's local bin path (typically `~/.cargo/bin` or `~/.local/bin` — executor confirms actual install path from the installer's own output).
   9b. Record installed CLI version — command: `ssh ... tvolodi@95.46.211.224 "stalwart-cli --version"` (adjust to installed binary path if not on `$PATH` in the SSH non-interactive shell — executor confirms and uses the full path if needed) — verification: non-empty version string captured verbatim into the execution log for audit (per Decision I, this substitutes for a pre-declared pin).
   9c. Confirm the CLI's auth-flag surface before using it with a password — command: `ssh ... tvolodi@95.46.211.224 "stalwart-cli --help"` and `"stalwart-cli apply --help"` (or equivalent subcommand help) — verification: confirms whether `--password`/`--api-key` accepts an env-var (`STALWART_TOKEN` or similar) rather than requiring a bare CLI argument; executor uses the env-var form for all subsequent calls in Phase 3/6, never a literal password on the command line.
   9d. Smoke-test connectivity, read-only — command: `ssh ... tvolodi@95.46.211.224 "stalwart-cli --url http://127.0.0.1:8080 --user admin describe Domain"` (password supplied via the env-var form confirmed in 9c) — verification: command succeeds (exit 0) and returns schema/output rather than a connection or auth error; this is the first live confirmation that the CLI can actually talk to the bootstrap-mode server before any `describe`/`apply` sequence in Phase 3 begins.

**Phase 2 — Firewall rules (UFW)** — unchanged from attempt 2.

10. Add UFW rules for the 4 new inbound mail ports — command: `ssh ... tvolodi@95.46.211.224 "sudo ufw allow 25/tcp && sudo ufw allow 465/tcp && sudo ufw allow 587/tcp && sudo ufw allow 993/tcp"` — verification: `sudo ufw status verbose` lists all four `ALLOW IN` (v4+v6), plus existing 22/80/443. No other ports added.
11. Confirm JMAP/webadmin (8080) is NOT exposed externally — command (management workstation): `Test-NetConnection 95.46.211.224 -Port 8080` — verification: `TcpTestSucceeded: False`.

**Phase 3 — Domain, DKIM, and submission-listener bootstrap via `stalwart-cli` (corrected — replaces attempt 2's admin-API-based Plan step 12)**

12. Live schema introspection, read-only, no state mutated — command: `ssh ... tvolodi@95.46.211.224 "stalwart-cli --url http://127.0.0.1:8080 --user admin describe Domain"`, then repeat for `DkimSignature`, `NetworkListener` — verification: each returns field/enum definitions; executor records the exact `certificateManagement`/`dkimManagement`/`dnsManagement` enum values seen for `Domain`, the exact `DkimSignature` field set (confirming whether `privateKey` is required and whether `publicKey` is genuinely server-derived-only), and the exact `NetworkListener` field set (`name`/`protocol`/`bind`/`useTls`/`tlsImplicit`) before writing any apply-plan content. **If any of these objects does not exist or its shape materially contradicts what this plan assumes, halt and report — do not improvise a substitute shape.**
13. Also read-only: check for any pre-existing `NetworkListener` objects (default ports) — command: `ssh ... tvolodi@95.46.211.224 "stalwart-cli --url http://127.0.0.1:8080 --user admin list NetworkListener"` (or the `describe`-equivalent listing form confirmed in step 12) — verification: confirms whether port 587 is already present by default (genuinely unconfirmed per research) — if present, Phase 3's apply-plan uses an `update`/`upsert` against the existing named listener rather than creating a duplicate; if absent, the apply-plan creates a new one. **This determination is made from live output, not assumed either way.**
14. Generate the DKIM keypair locally on host (Decision K) — command (variant chosen based on step 12's live enum output — default assumption Ed25519 unless the live schema indicates otherwise): `ssh ... tvolodi@95.46.211.224 "openssl genpkey -algorithm ED25519 -out /opt/stalwart-mail/dkim-mail-selector.pem && chmod 600 /opt/stalwart-mail/dkim-mail-selector.pem"` — verification: file exists, mode 600, non-empty; executor records which algorithm variant was used and why (per step 12's confirmed `DkimSignature` enum).
15. Construct the NDJSON apply-plan file, informed by steps 12–14's live-confirmed shapes — command: author `/opt/stalwart-mail/bootstrap-plan.ndjson` on host (via heredoc over the existing SSH session, not scp'd from a file in this repo, since it will briefly contain the DKIM private key content) containing three `upsert` operations: (a) `Domain` for `aiqadam.org` with management fields set per step 12's confirmed enum (recommend `dkimManagement`/`certificateManagement`/`dnsManagement` values that keep Stalwart from trying to also self-manage DNS/certs it doesn't need to, since this plan handles DNS via Cloudflare API directly and TLS via Stalwart's own ACME config separately — executor picks the value matching "manual DNS, automatic cert via the ACME config already decided in Decision F" once step 12's actual enum names are known, and records the choice made and why); (b) `DkimSignature` for selector `mail`, `domainId` referencing the `Domain` upsert, `privateKey` set to the PEM content from step 14; (c) `NetworkListener` for port 587 (create or update per step 13's finding), `bind: "0.0.0.0:587"`, `useTls: true`, `tlsImplicit: false` (STARTTLS, not implicit TLS — consistent with Decision E's reasoning from attempt 2) — verification: file exists on host, non-empty, valid NDJSON (`ssh ... "cat /opt/stalwart-mail/bootstrap-plan.ndjson | while read -r l; do echo \"$l\" | python3 -m json.tool >/dev/null || echo INVALID; done"` or equivalent line-by-line JSON validation).
16. Apply the plan — command: `ssh ... tvolodi@95.46.211.224 "STALWART_TOKEN=<value via env, not literal arg> stalwart-cli --url http://127.0.0.1:8080 --user admin apply --file /opt/stalwart-mail/bootstrap-plan.ndjson"` (exact env-var name per step 9c's confirmed auth flag) — verification: exit code 0, no per-line error entries in the command's own output.
17. Post-apply verification, read-only — command: `stalwart-cli ... describe Domain` (or `list`/`get` equivalent) confirms `aiqadam.org` present; `describe DkimSignature` (or `get`) confirms selector `mail` present under that domain **and returns a non-empty `publicKey` value** — capture this verbatim, well-formed (`v=DKIM1...`), for Plan step 20's DNS TXT record; `describe NetworkListener` (or `list`) confirms a listener bound `0.0.0.0:587`, `useTls: true`, `tlsImplicit: false` is now live. **If apply's exit code was 0 but any of these three post-checks fails, treat as a partial-failure state — re-run step 16 (idempotent `upsert`, safe to retry) before escalating.**
18. Clean up sensitive on-host artifacts (Decision L) — command: `ssh ... tvolodi@95.46.211.224 "shred -u /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson 2>/dev/null || rm -f /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson"` — verification: `ls /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson` both report "No such file."

**Phase 4 — TLS via internal ACME** — unchanged from attempt 2.

19. Configure Stalwart's internal ACME with DNS-01 challenge against the `aiqadam.org` Cloudflare zone, using the existing `cloudflare-ai-qadam-api-token` secret (no new secret) — this is itself now also expressed as a `stalwart-cli describe`-then-`apply` step rather than an ad hoc admin-API call, for the same reason Phase 3 was corrected: command: `ssh ... tvolodi@95.46.211.224 "stalwart-cli --url http://127.0.0.1:8080 --user admin describe AcmeProvider"` (or the correct object name — confirmed live, same discipline as step 12) first, then construct and `apply` an `upsert` for the ACME provider config (directory: Let's Encrypt production, challenge: dns-01, provider: cloudflare, token supplied via the same `.env`-sourced env var mechanism as Phase 1, e.g. `CF_API_TOKEN`, never written to this repo) — verification: `docker logs stalwart-mail-server-1` shows a successful ACME order/issuance for `mail.aiqadam.org` (or the config API reports a valid cert with ~90-day expiry); no port-80 contention with nginx since DNS-01 does not require inbound HTTP.
20. Confirm TLS actually serves correctly on 465/993 — command: `openssl s_client -connect mail.aiqadam.org:993 -servername mail.aiqadam.org </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer` — verification: subject/SAN includes `mail.aiqadam.org`, issuer Let's Encrypt, not expired. As in attempt 2: DNS-01 issuance does not require the A record to point at the host first, so step 19 may run any time after Phase 3; step 20's most meaningful run is after Phase 5's DNS cutover (also re-checked in Phase 8).

**Phase 5 — DNS cutover (Cloudflare `aiqadam.org` zone — unchanged from attempt 2 except step numbering and the DKIM key source now coming from Plan step 17 instead of an admin-API call; single named-record operations only, freshness-check immediately before each write)**

All Cloudflare API calls use `cloudflare-ai-qadam-api-token` (secrets-inventory name only). Zone ID `bec8854d698d56ff17cf917367634100`. Every step: `GET` the specific record immediately before mutating it to confirm it still matches the value documented in `landscape/cloudflare.md`; abort that step and escalate if it has drifted. **This run halted before reaching Phase 5 last attempt — treat every record in this phase as fully un-touched by any prior attempt; do not skip freshness-checks for any record on the assumption a previous attempt already verified it.**

21. Freshness-check the current `mail.aiqadam.org` A record (`212.20.151.29`, unproxied, TTL 300) via `GET /zones/bec8854d698d56ff17cf917367634100/dns_records?name=mail.aiqadam.org&type=A`, then `PATCH` its `content` to `95.46.211.224` — verification: `GET` confirms `content: 95.46.211.224`, `modified_on` updated.
22. Freshness-check + `PATCH` the `aiqadam.org` MX record (`mail.aiqadam.org`, prio 10) — content unchanged; confirmed no-op via `GET`, skip `PATCH` if truly unchanged. **This is the cutover moment per the task's Notes — flagged for explicit separate confirmation at step 05.**
23. Freshness-check + `PATCH` the apex `aiqadam.org` SPF TXT record (`v=spf1 ip4:212.20.151.29 mx -all` → `v=spf1 ip4:95.46.211.224 mx -all`) — verification: `GET` confirms new content.
24. Freshness-check + `PATCH` the `mail._domainkey.aiqadam.org` TXT record with the new DKIM public key from Plan step 17 — verification: `GET` confirms new content; `dig TXT mail._domainkey.aiqadam.org` from an external resolver returns the new key.
25. Freshness-check + `PATCH` the `_dmarc.aiqadam.org` TXT record: `p=reject` → `p=none` (Decision 4, carried over) — verification: `GET` confirms new content.
26. Freshness-check + `PATCH` the `mail.aiqadam.org` TXT (`v=spf1 a -all`) — no change needed, confirmed via `GET` only.
27. Freshness-check + delete `webmail.aiqadam.org` A record (carried-over decision — no webmail product stood up this pass) — command: `DELETE /zones/.../dns_records/<webmail-record-id>` — verification: `GET` returns 404.
28. Freshness-check + handle the 4 stale CNAMEs (`autoconfig`, `autodiscover`, `mta-sts`, `ua-auto-config`): `autoconfig`/`autodiscover` require no content change — verify Stalwart actually serves valid autoconfig/autodiscover responses post-cutover (Phase 8); if not, follow-on fix. `mta-sts`/`ua-auto-config` CNAMEs plus their corresponding TXT records (`_mta-sts.aiqadam.org`, `_ua-auto-config.aiqadam.org`) — **delete**, carried-over decision. Verification: `GET` on deleted record IDs returns 404; `GET` on `autoconfig`/`autodiscover` confirms unchanged; live HTTP probe to `https://autoconfig.aiqadam.org/mail/config-v1.1.xml` post-cutover.
29. Freshness-check + handle the 6 stale SRV records: `_imaps._tcp`, `_jmap._tcp`, `_submissions._tcp` — no content change needed. `_caldavs._tcp`, `_carddavs._tcp`, `_pop3s._tcp` — **delete**, carried-over decision. Verification: `GET` on deleted record IDs returns 404; `GET` on retained records confirms unchanged.
30. Freshness-check + `_smtp._tls.aiqadam.org` TXT (TLS-RPT) — no change needed, confirmed via `GET` only.
31. **Explicitly out of scope, confirmed unchanged, not touched:** `resend._domainkey.aiqadam.org`, `send.aiqadam.org` MX/TXT (SES), wildcard `*.aiqadam.org`, all 5 tunnel/GitHub-Pages records. Verification: post-cutover full zone dump diffed against pre-run snapshot confirms byte-for-byte unchanged.

**Phase 6 — Mailbox provisioning (corrected — replaces attempt 2's admin-API-based Plan step 27)**

32. Create one test mailbox via `stalwart-cli` — command: `ssh ... tvolodi@95.46.211.224 "stalwart-cli --url http://127.0.0.1:8080 --user admin describe Account"` (read-only schema confirmation, same discipline as Phase 3) — verification: confirms `name`/`domainId`/`roles`/`permissions`/`credentials` field shape live, before constructing the create call.
33. Generate the test account's password (already generated at Plan step 6, secret name `stalwart-mail-test-account-password`) and create the account — command: `ssh ... tvolodi@95.46.211.224 "STALWART_TOKEN=<value via env> stalwart-cli --url http://127.0.0.1:8080 --user admin create Account --name test --domain-id aiqadam.org --credentials-secret <value via stdin/heredoc, not a literal arg>"` (exact flag names per step 32's confirmed CLI help output; if `create` does not support this object type directly, fall back to the same `apply`-with-NDJSON mechanism as Phase 3, one `upsert` for the `Account`/`User` object — executor picks whichever the live CLI actually supports, records which) — verification: a subsequent `stalwart-cli ... describe Account` (or `list`) shows `test@aiqadam.org` present (server-derived `emailAddress` per the confirmed field list).
34. Document the mailbox provisioning mechanism (confirmed `stalwart-cli` command shape) in `landscape/hosts/pro-data-tech-prod.md` at step 08.

**Phase 7 — nginx vhost for Stalwart webadmin** — unchanged from attempt 2.

35. Add nginx vhost proxying `https://mail.aiqadam.org/` (root, per the empirically-confirmed `/account` SPA redirect) to `127.0.0.1:8080`, TLS via the existing certbot pattern, reusing the **orphaned cert from attempt 1** — command: write `/etc/nginx/sites-available/mail.aiqadam.org` (proxy_pass `http://127.0.0.1:8080`, ssl_certificate pointing at `/etc/letsencrypt/live/mail.aiqadam.org/`), symlink to `sites-enabled`, `sudo nginx -t && sudo systemctl reload nginx` — verification: `https://mail.aiqadam.org/` returns Stalwart's login/portal page (200 or 302→/account), external probe from management workstation.

   Note (unchanged from attempt 2): `mail.aiqadam.org` has TLS served two ways for two different purposes — nginx+certbot for the admin UI on 443, Stalwart's own internal ACME cert for SMTP/IMAP TLS on 465/993/587/25. Not a conflict (different ports, different consuming processes); flagged for step 08's landscape documentation.

**Phase 8 — Verification / deliverability testing** — unchanged from attempt 2.

36. Internal SMTP/IMAP/JMAP/submission reachability — command (management workstation): `Test-NetConnection mail.aiqadam.org -Port 25`, `-Port 465`, `-Port 587`, `-Port 993` — verification: all `TcpTestSucceeded: True`.
37. TLS validity (SMTP/IMAP side, internal ACME) — per Plan step 20, re-run now that DNS fully resolves externally.
38. DNS propagation checks — command: `nslookup mail.aiqadam.org 1.1.1.1`, `nslookup -type=MX aiqadam.org 1.1.1.1`, `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1`, `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` — verification: each resolves to the new values externally.
39. External send/receive test: external Gmail (or equivalent) → `test@aiqadam.org`, confirm receipt via IMAP; `test@aiqadam.org` → external address, confirm arrival (inbox or spam, both acceptable per task's Notes).
40. mail-tester.com score captured as deliverability baseline, recorded in `landscape/hosts/pro-data-tech-prod.md` and task close-out notes.

**Phase 9 — Backups** — unchanged from attempt 2.

41. Local-disk-only backup of Stalwart's data directory — command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /var/backups/stalwart-mail && sudo tar czf /var/backups/stalwart-mail/stalwart-data-$(date +%Y%m%dT%H%M%SZ).tar.gz -C /opt/stalwart-mail var-lib-stalwart etc-stalwart"` — verification: `ls -la /var/backups/stalwart-mail/` shows the new tarball, non-zero size. Daily cron/systemd-timer, 14-day local retention — recommended follow-on, not built into this pass.

### Rollback

Rollback remains phase-scoped; DNS and host-install rollback are independent.

1. **Compose install rollback (Phases 0–1, steps 5–9d):** `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose down"` then `sudo rm -rf /opt/stalwart-mail` — fully reversible; no external state touched at this point. This also removes any `stalwart-cli`-created bootstrap state since it lives inside the deleted `var-lib-stalwart` bind mount. The `stalwart-cli` binary itself (installed at step 9a to the host's user-local bin path, not inside `/opt/stalwart-mail`) is left in place on rollback — it is a harmless, inert client tool with no running state and no network exposure; removing it is optional cleanup, not required for a clean rollback (note this explicitly so the executor doesn't treat leaving it as a rollback failure).
2. **UFW rules rollback (Phase 2, step 10):** `ssh ... tvolodi@95.46.211.224 "sudo ufw delete allow 25/tcp && sudo ufw delete allow 465/tcp && sudo ufw delete allow 587/tcp && sudo ufw delete allow 993/tcp"` — fully reversible.
3. **Domain/DKIM/listener/ACME config rollback (Phase 3–4, steps 12–19):** state lives inside `/opt/stalwart-mail/var-lib-stalwart`, deleted wholesale by rollback item 1 — no separate rollback needed. If only a partial rollback is needed (redo bootstrap without reinstalling Compose), re-run `stalwart-cli apply` against a corrected plan file — `upsert` semantics make this safe to redo. The on-host DKIM private key PEM and NDJSON plan file are deleted by Plan step 18 in the normal forward path; if rollback occurs before step 18 ran, the rollback's `rm -rf /opt/stalwart-mail` also removes them (they live under that same directory tree) — no separate secret-cleanup rollback step needed.
4. **DNS rollback (Phase 5, steps 21, 23, 24, 25):** re-`PATCH` each record back to its pre-change documented value (A record → `212.20.151.29`; SPF → `v=spf1 ip4:212.20.151.29 mx -all`; DKIM TXT → prior RSA key value, captured verbatim from `landscape/cloudflare.md` before this run's changes; DMARC → `p=reject`). **Same caveat as attempts 1/2:** clean no-op only before real mail traffic and external SPF-cache pickup occur; once mailboxes are in active use, DNS rollback is an emergency-stop, not a safe revert.
5. **Deleted-record rollback (Phase 5, steps 27, 28, 29 — `webmail`, `mta-sts`/`ua-auto-config`, `_caldavs`/`_carddavs`/`_pop3s`):** re-`CREATE` each deleted record with its exact pre-deletion name/type/content/TTL, captured verbatim from `landscape/cloudflare.md` before this run executes. Record IDs will differ on recreate; update landscape at step 08 regardless.
6. **Mailbox/data rollback (Phase 6):** delete the test account via `stalwart-cli delete Account` (or `apply` with a `delete` op against the same NDJSON convention) — no real user data exists in this plan's scope; also covered wholesale by rollback item 1 if the full Compose project is torn down.
7. **nginx vhost rollback (Phase 7, step 35):** `ssh ... tvolodi@95.46.211.224 "sudo rm /etc/nginx/sites-enabled/mail.aiqadam.org && sudo nginx -t && sudo systemctl reload nginx"` — fully reversible; does not touch the orphaned certbot cert itself.
8. **Orphaned cert:** no rollback action needed either way — remains valid/inert if Phase 7 is rolled back after being reached.
9. **No rollback needed for Phase 8 (verification, read-only) or Phase 9 (backup, additive-only).**

### Verification (for step 07)

- **On-host:**
  - `docker compose -p stalwart-mail ps` → `stalwart-mail-server-1` `Up`/`healthy`.
  - `docker logs stalwart-mail-server-1 --tail 100` → no fatal errors, no crash-loop restarts, no randomly-generated-password banner.
  - `stalwart-cli --version` (or equivalent) → non-empty version string, recorded.
  - `sudo ufw status verbose` → 22/80/443/25/465/587/993 all `ALLOW IN`, no other new rules.
  - `sudo ss -tlnp` → confirms 25/465/587/993 bound `0.0.0.0`, 8080 bound `127.0.0.1` only.
  - `ls -la /opt/stalwart-mail/etc-stalwart /opt/stalwart-mail/var-lib-stalwart` → owned `2000:2000`.
  - `ls /opt/stalwart-mail/dkim-mail-selector.pem /opt/stalwart-mail/bootstrap-plan.ndjson` → both absent (cleaned up per Decision L).
  - Penpot: `docker ps --filter label=com.docker.compose.project=penpot` → all containers `Up` (compare pre/post this run).
  - AiQadam prod: `docker ps --filter label=com.docker.compose.project=aiqadam-prod` → all containers `Up` (same caveat).
  - `stalwart-cli ... describe Domain` → `aiqadam.org` present with the management settings this plan set.
  - `stalwart-cli ... describe DkimSignature` → selector `mail` present, `publicKey` non-empty.
  - `stalwart-cli ... describe NetworkListener` → a listener bound `0.0.0.0:587`, `useTls: true`, `tlsImplicit: false` present.
  - `stalwart-cli ... describe Account` (or `list`) → `test@aiqadam.org` present.
  - `/var/backups/stalwart-mail/` contains at least one non-zero-size tarball.
  - `sudo certbot certificates -d mail.aiqadam.org` → still shows the attempt-1 cert, now referenced by the new nginx vhost, not orphaned anymore.
- **External:**
  - `Test-NetConnection mail.aiqadam.org -Port 25/465/587/993` → all `TcpTestSucceeded: True`.
  - `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` → 200 (no regression).
  - `Invoke-WebRequest https://aiqadam.org/health` → 200 (no regression).
  - `Invoke-WebRequest https://mail.aiqadam.org/` → 200/302, Stalwart portal reachable via nginx proxy.
  - `openssl s_client -connect mail.aiqadam.org:993 ...` → cert subject `mail.aiqadam.org`, Let's Encrypt issuer, not expired (Stalwart's internal-ACME cert).
  - `nslookup mail.aiqadam.org 1.1.1.1` → `95.46.211.224`.
  - `nslookup -type=MX aiqadam.org 1.1.1.1` → `mail.aiqadam.org` prio 10.
  - `nslookup -type=TXT aiqadam.org 1.1.1.1` (SPF) → `v=spf1 ip4:95.46.211.224 mx -all`.
  - `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1` → `v=DMARC1; p=none; rua=mailto:postmaster@aiqadam.org`.
  - `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` → new DKIM key present, matching Plan step 17's captured `publicKey`.
  - External send test to `test@aiqadam.org` from Gmail → delivered (confirm via IMAP fetch).
  - External send test from `test@aiqadam.org` to Gmail → arrives (inbox or spam, record which).
  - mail-tester.com score captured and recorded.
  - Full Cloudflare zone dump (post-cutover) diffed against pre-run snapshot: confirms `resend._domainkey`, `send.aiqadam.org` MX/TXT, wildcard, and all 5 tunnel/pages records byte-for-byte unchanged.

### Resources used
- **Secrets (by name):** `cloudflare-ai-qadam-api-token` (existing, used both for DNS cutover and Stalwart's internal ACME DNS-01 challenge); new entries to be added at step 08: `stalwart-mail-admin-password` (`STALWART_RECOVERY_ADMIN`), `stalwart-mail-dkim-private-key` (generated on-host via `openssl`, consumed into Stalwart's config registry then shredded from disk — the value never persists in this repo; noting the name here documents that DKIM key material exists and is Stalwart-internal, not that a plaintext copy is retained anywhere), `stalwart-mail-test-account-password`.
- **Files modified on host (`pro-data-tech-prod`):** new `/opt/stalwart-mail/docker-compose.yml`, `/opt/stalwart-mail/.env` (mode 600), `/opt/stalwart-mail/etc-stalwart/`, `/opt/stalwart-mail/var-lib-stalwart/`; transient (deleted by Plan step 18) `/opt/stalwart-mail/dkim-mail-selector.pem`, `/opt/stalwart-mail/bootstrap-plan.ndjson`; `stalwart-cli` binary installed to the `tvolodi` user's local bin path; new `/etc/nginx/sites-available/mail.aiqadam.org` (+ symlink), reusing existing `/etc/letsencrypt/live/mail.aiqadam.org/`; UFW rules (4 new `allow` entries); new `/var/backups/stalwart-mail/`.
- **Files modified in this repo (`landscape/`) — to be applied at step 08:**
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) (new Stalwart Mail section — image/volume/config model; new UFW rules; new Compose project; new nginx vhost; `stalwart-cli` noted as an installed host-level admin tool with its confirmed version; note on the previously-orphaned-now-reused cert; note on internal ACME as a second TLS mechanism on this host; mailbox provisioning mechanism documented as `stalwart-cli create`/`apply`)
  - [landscape/services.md](../../landscape/services.md) (new Compose project row under `pro-data-tech-prod`)
  - [landscape/cloudflare.md](../../landscape/cloudflare.md) (A/MX/SPF/DKIM/DMARC record changes, record deletions, reclassify mail records table)
  - [landscape/domains.md](../../landscape/domains.md) (new `mail.aiqadam.org` subdomain + TLS cert entry, noting the dual TLS mechanism)
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) (new mail-related secret names)
  - [shared/app-registry.md](../../shared/app-registry.md) optionally, at designer's discretion
- **External APIs called:** Cloudflare DNS API (`GET`/`PATCH`/`DELETE` on named records only, zone `bec8854d698d56ff17cf917367634100`) — called both directly by the executor for DNS cutover, and indirectly by Stalwart itself for ACME DNS-01 challenges using the same token. `github.com/stalwartlabs/cli` GitHub Releases (fetched once, by the installer script, to install the CLI binary).

### Estimated impact
- **Downtime:** none for Penpot/AiQadam prod (additive changes only, verified unregressed at every checkpoint). For mail itself: none in the outage sense (old service already confirmed dead) — the MX/A-record cutover (Phase 5, steps 21/22) remains the moment mail routing for `aiqadam.org` becomes live on repo-controlled infrastructure for the first time.
- **Affected services:** New: Stalwart mail (SMTP/IMAP/JMAP/submission) on `pro-data-tech-prod`, plus a new nginx vhost for its admin UI, plus a new host-level CLI tool (`stalwart-cli`, not a service — no running process, no listening port). Unaffected (verified at every checkpoint): Penpot, AiQadam prod. Affected indirectly: the shared `aiqadam.org` Cloudflare zone (mail-records partition only).
- **Reversibility:** Host install, UFW rules, nginx vhost, CLI tool — fully reversible, no data loss. DNS changes — technically reversible at the record level, but practically a one-way operational event once real mail traffic begins.

## Issues / risks

- **HIGH — shared-host blast radius (carried over, unchanged from attempts 1/2).** Placing mail on `pro-data-tech-prod` adds spam/abuse exposure and cold-IP reputation risk to the same host serving Penpot and AiQadam prod. Already accepted by the user at step 05 attempts 1/2; re-surfaced here only because this is a fresh NEEDS_APPROVAL gate.
- **HIGH — DNS is shared, partially-owned zone surgery (carried over, unchanged).** Same class of operation as T-0111's apex repoint; multiple record types, several deletions; irreversible-in-practice once mail traffic begins.
- **MEDIUM — `stalwart-cli`'s exact command syntax (subcommand names, flag names for `create`/`apply`/`describe`, exact auth-flag form) is confirmed live at execution time (Plan steps 9c, 12, 13, 32) rather than hand-specified verbatim here, because the tool's CLI surface was not fully enumerable from the research available at design time.** This differs materially from attempt 2's failure mode: attempt 2 assumed a capability (an ad hoc admin REST/JMAP API) that empirically does not exist at all; this plan assumes a capability (`stalwart-cli` with `describe`/`apply`/`create` subcommands operating on `Domain`/`DkimSignature`/`NetworkListener`/`Account` objects) that is confirmed to exist by the tool's own documented purpose and a maintainer's explicit statement about its existence and separate-repo status — only the precise flag spelling is deferred to live `--help`/`describe` output, which is exactly the kind of low-risk, real introspection this retry's design brief asked for. If `stalwart-cli --help` or `describe <Object>` surfaces something that materially contradicts this plan's assumptions about the object model (e.g., `Domain`/`DkimSignature`/`NetworkListener` don't exist under those names, or `apply` doesn't accept NDJSON `upsert` as described), the executor must halt and report as a plan defect, not improvise — same discipline as before, now applied to a real, existing tool instead of a nonexistent one.
- **MEDIUM — DKIM private key material is generated and briefly held in plaintext on host disk (`/opt/stalwart-mail/dkim-mail-selector.pem`) before being consumed into Stalwart's own config registry and shredded (Decision L, Plan step 18).** This is a new handling step neither attempt 1 nor attempt 2 needed (neither got far enough to generate real key material). The window of plaintext exposure is limited to the single execution session between generation (step 14) and shred (step 18), on a host already SSH-key-only and firewalled; flagged as a deliberate, bounded, documented exposure rather than a silent gap.
- **MEDIUM — installing `stalwart-cli` via "latest" rather than a pinned release is a deliberate, narrow exception to this repo's pinning convention (Decision I), justified because it's a stateless client tool used under supervision, not a running service.** If the user disagrees with this exception, an alternative is to have the executor identify and pin a specific release tag from `github.com/stalwartlabs/cli/releases` at execution time before installing — this would require the installer or a manual download step to support an explicit version, which is not confirmed from research available at design time; flagged in Open questions below for the user's explicit call.
- **MEDIUM — dual TLS mechanisms on one host for one hostname (nginx+certbot for the admin UI on 443; Stalwart's internal ACME for SMTP/IMAP/submission on 465/587/993) — carried over, unchanged.** Not a conflict; a documentation/mental-model complexity flagged for step 08.
- **MEDIUM — CalDAV/CardDAV/POP3 and MTA-STS record deletions (carried over, unchanged, already approved).** Re-noted for completeness — functional regression vs. the old dead server's apparent feature set.
- **LOW — Stalwart's internal ACME via DNS-01 depends on the `cloudflare-ai-qadam-api-token` secret's scope permitting TXT record creation/deletion for `_acme-challenge.mail.aiqadam.org`.** Already scoped to Zone.DNS edit on the whole zone; executor confirms the first issuance succeeds rather than assuming silently.
- **LOW — autoconfig/autodiscover records left pointing at `mail.aiqadam.org` on the assumption Stalwart serves valid responses there (carried over, unchanged) — verified post-cutover, not guaranteed by this design.**
- **LOW — resource contention.** Unchanged: mail for dozens of mailboxes is small relative to this host's spare capacity.
- **LOW — version drift risk for the pinned server image (`v0.16`), unchanged from attempt 2's reasoning** — a deliberate future-upgrade task will be needed eventually, acceptable tradeoff.

## Open questions (optional)
None blocking — this retry corrects only the bootstrap/mailbox-provisioning mechanism; the eleven decisions carried forward from attempts 1/2 were already approved and are not reopened here. The following are new, narrower items worth the user's explicit attention at this approval pass:

- Confirm acceptance of installing `stalwart-cli` via the "latest" release rather than a pinned version (Decision I) — this plan argues it's a reasonable, narrow exception to this repo's pinning convention since it's a supervised client tool, not a running service, but it is a real deviation from precedent (Penpot `:2.16`, Stalwart server `:v0.16` are both pinned) and the user may prefer the executor attempt to locate and pin a specific CLI release tag instead, if the installer turns out to support that at execution time.
- Confirm the DKIM algorithm choice is left to the executor's live judgment (Ed25519 preferred, RSA-2048 fallback) based on what `stalwart-cli describe DkimSignature`'s enum actually shows at execution time (Decision K), rather than being pre-decided here — this is a genuine "confirm live, don't guess" item per the retry brief's own instruction, not an unresolved design gap.
