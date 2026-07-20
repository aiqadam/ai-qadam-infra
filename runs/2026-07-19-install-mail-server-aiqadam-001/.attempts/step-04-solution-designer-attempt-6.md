---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-19T11:20:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-04
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-04-solution-designer-attempt-5.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-5.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: >-
  Orchestrator: this is a textbook same-character mechanism fix, not a new decision touching approved
  scope — squarely within the user's standing delegation ("All up to you. Call me when everything will
  be ready," extended at attempt-4's approval to remain in effect "for the remainder of this run," and
  implicitly continued through attempt 5's clean, non-decisional restart-timing fix). The only change
  from attempt 5's approved plan is correcting the JSON encoding of one already-approved field
  (`AcmeProvider.contact`: JSON array -> JSON map with `true` values), root-caused and empirically
  confirmed via isolated scratch-container reproduction (unrelated to production), with a working,
  reproduced recipe. No new field values, no new scope, no new judgment call about what Stalwart should
  be configured to do — only how to encode a value already agreed on (`postmaster@aiqadam.org`, already
  used elsewhere in this exact DNS zone for DMARC/TLS-RPT `rua`). Proceed directly: write step-05
  approval under the standing delegation (no fresh user round-trip), then invoke executor-infra for
  attempt 6. Executor MUST start with the live-state re-confirmation step (Plan step 0) and MUST NOT
  repeat Phases 0-3 or the DnsServer creation — those are already live and verified on
  pro-data-tech-prod right now (Domain id `b`, DkimSignature id `i9njnzd3krqa`, NetworkListener id
  `i9njnzefksaa`, DnsServer id `i9njy0ssaaqb`).
---

## Summary
Sixth-attempt retry: identical to attempt 5's approved plan in every respect except one field-encoding correction — `AcmeProvider.contact` must be supplied as a JSON object/map (`{"postmaster@aiqadam.org": true}`), not a JSON array, per empirically-confirmed root-cause analysis of the schema-vs-validator mismatch that blocked attempt 5 — and an explicit instruction to resume from the current live state (Domain, DkimSignature, NetworkListener on 587, and DnsServer are already live on `pro-data-tech-prod`, confirmed by attempt 5's own post-checks) rather than repeating Phases 0-3; end state is unchanged from every prior attempt: a working, repo-owned, TLS-secured, firewalled mail server with the old dead records fully retired.

## Details

### Root cause of attempt 5's blocker (now confirmed, not a guess)

Attempt 5's executor made three independently-reasoned, schema-conformant-looking attempts to set `AcmeProvider.contact` — a bare JSON array of one email (`["postmaster@aiqadam.org"]`), a `mailto:`-prefixed variant of the same array form, and the same bare array via direct `create` instead of the NDJSON `apply` mechanism — all three failed identically with `error: invalidPatch | Invalid value for object property | Properties: contact`, despite `/api/schema` confirming the field's documented type as `set<string<emailAddress>>` with `minItems: 1`, which the array form appears to satisfy exactly.

This was independently reproduced and then fixed in a disposable, fully isolated local scratch container — a separate debugging exercise, unrelated to production, with zero blast radius, using the same technique that successfully diagnosed attempt 4's Bootstrap-restart blocker. Root cause: **Stalwart's `describe`/`/api/schema` output for `AcmeProvider.contact` is simply wrong about the wire encoding.** The type name `set<string<emailAddress>>` naturally suggests a JSON array, but the server's actual patch validator requires the JMAP `Set<T>` idiom — a JSON object/map with each email address as a key and `true` as the value, e.g. `{"postmaster@aiqadam.org": true}`. This is a genuine mismatch between Stalwart's schema documentation and its server-side validator, confirmed at the raw JMAP level in the scratch environment, not a CLI bug or a local misconfiguration.

**Confirmed working recipe** (reproduced end-to-end in the scratch environment, including real Let's Encrypt account registration succeeding with a distinct test object):
```
stalwart-cli create AcmeProvider \
  --field directory=https://acme-v02.api.letsencrypt.org/directory \
  --field challengeType=Dns01 \
  --field 'contact={"postmaster@example.com":true}'
```
Verified via `query AcmeProvider`/`get AcmeProvider <id>` afterward showing `Contact Email: mailto:postmaster@example.com` correctly populated.

**Explains attempt 5's confusing secondary finding**: omitting `contact` entirely produced a DIFFERENT error ("at least one contact email is required") that looked like it got "further" into real ACME logic — this is now explained, not still mysterious. Omitting the field skips patch-layer validation for it entirely (effectively optional at that layer despite `minItems:1` in the schema description), so the object proceeds to actually attempt Let's Encrypt account creation, which then fails for the sane, expected reason. Supplying the field as an array fails EARLIER, at patch validation, due to the array-vs-map encoding mismatch — it never reaches ACME logic at all. Both behaviors are one consistent bug (schema-vs-validator mismatch for `set<...>`-typed fields), not two separate issues.

### Live-state resumption (critical — read before executing)

Attempt 5's executor got through Phase 3 completely and part of Phase 4, and this state was **not rolled back** — it is the actual current state of the running Stalwart instance on `pro-data-tech-prod` right now:

| Object | Value | Confirmed via |
|---|---|---|
| `Domain` | `aiqadam.org`, id `b`, enabled | attempt 5's Plan step 18/12b post-checks |
| `DkimSignature` | selector `mail`, type `Dkim1Ed25519Sha256`, id `i9njnzd3krqa`, public key `ZNYJ+HqL+Ag+30oz7g36DqQ2qNqubS8bW4q7aaUGnk0=` | attempt 5's Plan step 18 |
| `NetworkListener` | name `submission`, port 587, id `i9njnzefksaa`, bound `[::]:587`, `useTls: true`, `tlsImplicit: false` | attempt 5's Plan step 18 |
| `DnsServer` | Cloudflare variant, id `i9njy0ssaaqb`, TTL 5m, timeout 30s | attempt 5's Phase 4 step 20 |
| `AcmeProvider` | does not exist — all three creation attempts failed cleanly, `query AcmeProvider` confirmed empty | attempt 5's halt report |

This retry's plan therefore does **not** repeat Phases 0-2 (pre-flight, install, firewall) or the Bootstrap/DKIM/NetworkListener/DnsServer portions of Phase 3-4. It opens with a fresh, minimal, read-only live-state confirmation, then proceeds straight to creating `AcmeProvider` with the corrected field encoding, then continues through the rest of the plan exactly as previously approved.

### Plan

**Phase R — Resume-from-live-state confirmation (read-only, replaces Phases 0-3 for this attempt)**

0. Confirm the four already-live objects are still present and match attempt 5's captured IDs before making any change — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin query Domain"` then repeat for `DkimSignature`, `NetworkListener`, `DnsServer` — verification: `Domain` shows `aiqadam.org` id `b` enabled; `DkimSignature` shows selector `mail`, id `i9njnzd3krqa`; `NetworkListener` shows the `submission` listener id `i9njnzefksaa` bound `[::]:587`; `DnsServer` shows the Cloudflare object id `i9njy0ssaaqb`. If any object is missing or its id/key fields differ from the table above, HALT and report — do not assume it is safe to proceed past this point, and do not re-run Bootstrap/DKIM/NetworkListener/DnsServer creation as a "fix" without fresh diagnosis (same anti-retry discipline as attempt 5's step 12b guardrail).
0a. Confirm `AcmeProvider` still does not exist (no partial state from attempt 5's three failed attempts) — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin query AcmeProvider"` — verification: empty result, matching attempt 5's own confirmation. If a partial/orphaned `AcmeProvider` object is now present, HALT and report — this would be a genuinely new situation not covered by this plan.
0b. No-regression checkpoint — command: `ssh ... "docker ps --filter label=com.docker.compose.project=penpot --format '{{.Names}}: {{.Status}}'"` and `"docker ps --filter label=com.docker.compose.project=aiqadam-prod --format '{{.Names}}: {{.Status}}'"` and external `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` / `https://aiqadam.org/health` — verification: matches attempt 5's final baseline (Penpot 7/7 `Up`, AiQadam-prod 4/4 `Up`, both external checks 200).

**Phase 4 — TLS via internal ACME (resumed; `DnsServer` already live, only `AcmeProvider` remains)**

1. Create the `AcmeProvider` object with the corrected `contact` field encoding — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin create AcmeProvider --field directory=https://acme-v02.api.letsencrypt.org/directory --field challengeType=Dns01 --field 'contact={\"postmaster@aiqadam.org\":true}'"` — use `postmaster@aiqadam.org` (matches the existing `postmaster@` convention already used in this zone's DMARC and TLS-RPT `rua` records). If the CLI's shell-quoting on the live host requires a different escaping mechanism for the embedded JSON object than assumed here (e.g. a heredoc-based `--file`/`--json` payload instead of an inline `--field` value), the executor should use whichever mechanism it already confirmed works for JSON-valued fields earlier in this run (attempt 5 confirmed `--field KEY={...}` accepts inline JSON when the value starts with `{`) — this is a shell-mechanics detail, not a plan-scope change. — verification: exit code 0, no `invalidPatch` error, output shows the created object's id.
2. Post-create verification, read-only — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin query AcmeProvider"` then `"... get AcmeProvider <id>"` — verification: object present, `Contact Email: mailto:postmaster@aiqadam.org` (or equivalent rendering) populated correctly — matches the scratch-container recipe's confirmed output shape. If this still fails with `invalidPatch` on `contact`, this is now a genuinely new, unexplained situation (the confirmed fix did not transfer) — HALT and report; do not attempt further speculative encodings.
3. Confirm ACME issuance actually completes — command: `ssh ... "docker logs stalwart-mail-server-1 --tail 100"` (or `--since <this-step's-timestamp>`) — verification: log lines or, failing that (per this run's already-observed sparse-logging behavior), `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin get AcmeProvider <id>"` shows a populated `accountUri` and/or non-error certificate status. Stalwart's DNS-01 challenge will create and clean up its own `_acme-challenge.mail.aiqadam.org` TXT record via the Cloudflare API using the already-live `DnsServer` object (id `i9njy0ssaaqb`) — this is Stalwart acting autonomously through its own configured integration, not a direct Cloudflare API call by the executor; do not confuse with Phase 5's DNS cutover. If issuance does not complete within a reasonable wait/poll window, HALT and report rather than guessing at a cause.
4. Confirm TLS actually serves correctly on 465/993 — command: `openssl s_client -connect mail.aiqadam.org:993 -servername mail.aiqadam.org </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer` (run from the management workstation or via SSH loopback if external DNS does not yet point at the host — DNS-01 issuance does not require the A record to point at the host first) — verification: subject/SAN includes `mail.aiqadam.org`, issuer Let's Encrypt, not expired. This step's most meaningful run is after Phase 5's DNS cutover (also re-checked in Phase 8), but a same-host loopback/direct-IP check can confirm the cert itself is issued and bound before DNS is touched.

**Phase 5 — DNS cutover (Cloudflare `aiqadam.org` zone — single named-record operations only, freshness-check immediately before each write)** — unchanged from attempt 5.

All Cloudflare API calls use `cloudflare-ai-qadam-api-token` (secrets-inventory name only). Zone ID `bec8854d698d56ff17cf917367634100`. Every step: `GET` the specific record immediately before mutating it to confirm it still matches the value documented in `landscape/cloudflare.md`; abort that step and escalate if it has drifted. This run has not yet reached Phase 5 in any prior attempt — treat every record in this phase as fully un-touched; do not skip freshness-checks for any record on the assumption a previous attempt already verified it.

5. Freshness-check the current `mail.aiqadam.org` A record (`212.20.151.29`, unproxied, TTL 300) via `GET /zones/bec8854d698d56ff17cf917367634100/dns_records?name=mail.aiqadam.org&type=A`, then `PATCH` its `content` to `95.46.211.224` — verification: `GET` confirms `content: 95.46.211.224`, `modified_on` updated.
6. Freshness-check + `PATCH` the `aiqadam.org` MX record (`mail.aiqadam.org`, prio 10) — content unchanged; confirmed no-op via `GET`, skip `PATCH` if truly unchanged. **This is the cutover moment per the task's Notes — flagged for explicit separate confirmation at step 05.**
7. Freshness-check + `PATCH` the apex `aiqadam.org` SPF TXT record (`v=spf1 ip4:212.20.151.29 mx -all` → `v=spf1 ip4:95.46.211.224 mx -all`) — verification: `GET` confirms new content.
8. Freshness-check + `PATCH` the `mail._domainkey.aiqadam.org` TXT record with the new DKIM public key already captured (`ZNYJ+HqL+Ag+30oz7g36DqQ2qNqubS8bW4q7aaUGnk0=`, Ed25519, formatted `v=DKIM1; k=ed25519; p=ZNYJ+HqL+Ag+30oz7g36DqQ2qNqubS8bW4q7aaUGnk0=`) — verification: `GET` confirms new content; `dig TXT mail._domainkey.aiqadam.org` from an external resolver returns the new key.
9. Freshness-check + `PATCH` the `_dmarc.aiqadam.org` TXT record: `p=reject` → `p=none` (carried over) — verification: `GET` confirms new content.
10. Freshness-check + `PATCH` the `mail.aiqadam.org` TXT (`v=spf1 a -all`) — no change needed, confirmed via `GET` only.
11. Freshness-check + delete `webmail.aiqadam.org` A record (carried-over decision — no webmail product stood up this pass) — command: `DELETE /zones/.../dns_records/<webmail-record-id>` — verification: `GET` returns 404.
12. Freshness-check + handle the 4 stale CNAMEs (`autoconfig`, `autodiscover`, `mta-sts`, `ua-auto-config`): `autoconfig`/`autodiscover` require no content change — verify Stalwart actually serves valid autoconfig/autodiscover responses post-cutover (Phase 8); if not, follow-on fix. `mta-sts`/`ua-auto-config` CNAMEs plus their corresponding TXT records (`_mta-sts.aiqadam.org`, `_ua-auto-config.aiqadam.org`) — **delete**, carried-over decision. Verification: `GET` on deleted record IDs returns 404; `GET` on `autoconfig`/`autodiscover` confirms unchanged; live HTTP probe to `https://autoconfig.aiqadam.org/mail/config-v1.1.xml` post-cutover.
13. Freshness-check + handle the 6 stale SRV records: `_imaps._tcp`, `_jmap._tcp`, `_submissions._tcp` — no content change needed. `_caldavs._tcp`, `_carddavs._tcp`, `_pop3s._tcp` — **delete**, carried-over decision. Verification: `GET` on deleted record IDs returns 404; `GET` on retained records confirms unchanged.
14. Freshness-check + `_smtp._tls.aiqadam.org` TXT (TLS-RPT) — no change needed, confirmed via `GET` only.
15. **Explicitly out of scope, confirmed unchanged, not touched:** `resend._domainkey.aiqadam.org`, `send.aiqadam.org` MX/TXT (SES), wildcard `*.aiqadam.org`, all 5 tunnel/GitHub-Pages records. Verification: post-cutover full zone dump diffed against pre-run snapshot confirms byte-for-byte unchanged.

**Phase 6 — Mailbox provisioning** — unchanged from attempt 5.

16. Create one test mailbox via `stalwart-cli` — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin describe Account"` (read-only schema confirmation) — verification: confirms `name`/`domainId`/`roles`/`permissions`/`credentials` field shape live, before constructing the create call.
17. Generate the test account's password (secret name `stalwart-mail-test-account-password`, already generated and recorded in attempt 5's execution) and create the account — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin create Account --name test --domain-id b --credentials-secret <value via stdin/heredoc, not a literal arg>"` (exact flag names per step 16's confirmed CLI help output; use domain id `b` per the live-confirmed `Domain` id, not the bare domain name, consistent with attempt 5's confirmed `domainId` shape requiring the internal id rather than `domain-<name>`; if `create` does not support this object type directly, fall back to the same `apply`-with-NDJSON mechanism as Phase 4, one `upsert` for the `Account`/`User` object) — verification: a subsequent `... describe Account` (or `list`) shows `test@aiqadam.org` present.
18. Document the mailbox provisioning mechanism (confirmed `stalwart-cli` command shape) in `landscape/hosts/pro-data-tech-prod.md` at step 08.

**Phase 7 — nginx vhost for Stalwart webadmin** — unchanged from attempt 5.

19. Add nginx vhost proxying `https://mail.aiqadam.org/` (root, per the empirically-confirmed `/account` SPA redirect) to `127.0.0.1:8080`, TLS via the existing certbot pattern, reusing the orphaned cert from attempt 1 — command: write `/etc/nginx/sites-available/mail.aiqadam.org` (proxy_pass `http://127.0.0.1:8080`, ssl_certificate pointing at `/etc/letsencrypt/live/mail.aiqadam.org/`), symlink to `sites-enabled`, `sudo nginx -t && sudo systemctl reload nginx` — verification: `https://mail.aiqadam.org/` returns Stalwart's login/portal page (200 or 302→/account), external probe from management workstation.

    Note (unchanged): `mail.aiqadam.org` has TLS served two ways for two different purposes — nginx+certbot for the admin UI on 443, Stalwart's own internal ACME cert for SMTP/IMAP TLS on 465/993/587/25. Not a conflict; flagged for step 08's landscape documentation.

**Phase 8 — Verification / deliverability testing** — unchanged from attempt 5.

20. Internal SMTP/IMAP/JMAP/submission reachability — command (management workstation): `Test-NetConnection mail.aiqadam.org -Port 25`, `-Port 465`, `-Port 587`, `-Port 993` — verification: all `TcpTestSucceeded: True`.
21. TLS validity (SMTP/IMAP side, internal ACME) — per Plan step 4, re-run now that DNS fully resolves externally.
22. DNS propagation checks — command: `nslookup mail.aiqadam.org 1.1.1.1`, `nslookup -type=MX aiqadam.org 1.1.1.1`, `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1`, `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` — verification: each resolves to the new values externally.
23. External send/receive test: external Gmail (or equivalent) → `test@aiqadam.org`, confirm receipt via IMAP; `test@aiqadam.org` → external address, confirm arrival (inbox or spam, both acceptable per task's Notes).
24. mail-tester.com score captured as deliverability baseline, recorded in `landscape/hosts/pro-data-tech-prod.md` and task close-out notes.

**Phase 9 — Backups** — unchanged from attempt 5.

25. Local-disk-only backup of Stalwart's data directory — command: `ssh ... "sudo mkdir -p /var/backups/stalwart-mail && sudo tar czf /var/backups/stalwart-mail/stalwart-data-$(date +%Y%m%dT%H%M%SZ).tar.gz -C /opt/stalwart-mail var-lib-stalwart etc-stalwart"` — verification: `ls -la /var/backups/stalwart-mail/` shows the new tarball, non-zero size. Daily cron/systemd-timer, 14-day local retention — recommended follow-on, not built into this pass.

### Rollback

Rollback remains phase-scoped; DNS and host-install rollback are independent. Phase R (resume-confirmation) is read-only and needs no rollback.

1. **AcmeProvider creation rollback (Phase 4, steps 1-4):** `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin delete AcmeProvider <id>"` — fully reversible, does not touch the already-live Domain/DkimSignature/NetworkListener/DnsServer objects from attempt 5. If the whole Compose project needs teardown for any other reason, `docker compose down` + `sudo rm -rf /opt/stalwart-mail` removes all server-side state at once (same as every prior attempt's rollback item 1) — this also removes the four already-live objects, so prefer the narrower `delete AcmeProvider` rollback unless a full reinstall is genuinely needed.
2. **DNS rollback (Phase 5, steps 5, 7, 8, 9):** re-`PATCH` each record back to its pre-change documented value (A record → `212.20.151.29`; SPF → `v=spf1 ip4:212.20.151.29 mx -all`; DKIM TXT → prior RSA key value, captured verbatim from `landscape/cloudflare.md` before this run's changes; DMARC → `p=reject`). Clean no-op only before real mail traffic and external SPF-cache pickup occur; once mailboxes are in active use, DNS rollback is an emergency-stop, not a safe revert.
3. **Deleted-record rollback (Phase 5, steps 11, 12, 13 — `webmail`, `mta-sts`/`ua-auto-config`, `_caldavs`/`_carddavs`/`_pop3s`):** re-`CREATE` each deleted record with its exact pre-deletion name/type/content/TTL, captured verbatim from `landscape/cloudflare.md` before this run executes. Record IDs will differ on recreate; update landscape at step 08 regardless.
4. **Mailbox/data rollback (Phase 6):** delete the test account via `stalwart-cli delete Account` (or `apply` with a `delete` op against the same NDJSON convention) — no real user data exists in this plan's scope.
5. **nginx vhost rollback (Phase 7, step 19):** `ssh ... "sudo rm /etc/nginx/sites-enabled/mail.aiqadam.org && sudo nginx -t && sudo systemctl reload nginx"` — fully reversible; does not touch the orphaned certbot cert itself.
6. **Orphaned cert:** no rollback action needed either way — remains valid/inert if Phase 7 is rolled back after being reached.
7. **No rollback needed for Phase 8 (verification, read-only) or Phase 9 (backup, additive-only).**

### Verification (for step 07)

- **On-host:**
  - `query Domain`/`DkimSignature`/`NetworkListener`/`DnsServer` (Phase R, step 0) → all four present, matching the ids in the resume table above, before any new state change is made.
  - `query AcmeProvider` (Phase R, step 0a, pre-change) → empty; (Phase 4, step 2, post-change) → one object present, `directory` = Let's Encrypt production, `challengeType: Dns01`, contact email `postmaster@aiqadam.org` correctly populated (not the failed `invalidPatch` state).
  - `docker logs stalwart-mail-server-1` / `get AcmeProvider <id>` (Phase 4, step 3) → evidence of successful ACME issuance (populated `accountUri` and/or non-error cert status).
  - `openssl s_client -connect mail.aiqadam.org:993 ...` (Phase 4, step 4; re-run Phase 8 step 21) → cert subject `mail.aiqadam.org`, Let's Encrypt issuer, not expired.
  - `stalwart-cli ... describe Account` (or `list`) → `test@aiqadam.org` present.
  - `/var/backups/stalwart-mail/` contains at least one non-zero-size tarball.
  - `sudo certbot certificates -d mail.aiqadam.org` → still shows the attempt-1 cert, now referenced by the new nginx vhost.
  - Penpot: `docker ps --filter label=com.docker.compose.project=penpot` → all containers `Up` (compare against attempt 5's final baseline: 7/7).
  - AiQadam prod: `docker ps --filter label=com.docker.compose.project=aiqadam-prod` → all containers `Up` (compare against attempt 5's final baseline: 4/4).
- **External:**
  - `Test-NetConnection mail.aiqadam.org -Port 25/465/587/993` → all `TcpTestSucceeded: True`.
  - `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` → 200 (no regression).
  - `Invoke-WebRequest https://aiqadam.org/health` → 200 (no regression).
  - `Invoke-WebRequest https://mail.aiqadam.org/` → 200/302, Stalwart portal reachable via nginx proxy.
  - `nslookup mail.aiqadam.org 1.1.1.1` → `95.46.211.224`.
  - `nslookup -type=MX aiqadam.org 1.1.1.1` → `mail.aiqadam.org` prio 10.
  - `nslookup -type=TXT aiqadam.org 1.1.1.1` (SPF) → `v=spf1 ip4:95.46.211.224 mx -all`.
  - `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1` → `v=DMARC1; p=none; rua=mailto:postmaster@aiqadam.org`.
  - `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` → new DKIM key present, matching the already-captured public key (`ZNYJ+HqL+Ag+30oz7g36DqQ2qNqubS8bW4q7aaUGnk0=`).
  - External send test to `test@aiqadam.org` from Gmail → delivered (confirm via IMAP fetch).
  - External send test from `test@aiqadam.org` to Gmail → arrives (inbox or spam, record which).
  - mail-tester.com score captured and recorded.
  - Full Cloudflare zone dump (post-cutover) diffed against pre-run snapshot: confirms `resend._domainkey`, `send.aiqadam.org` MX/TXT, wildcard, and all 5 tunnel/pages records byte-for-byte unchanged.

### Resources used
- **Secrets (by name):** `cloudflare-ai-qadam-api-token` (existing, used both for DNS cutover and (indirectly, via the already-configured `DnsServer` object) Stalwart's internal ACME DNS-01 challenge); already-recorded from attempt 5: `stalwart-mail-admin-password`, `stalwart-mail-domain-admin-password`, `stalwart-mail-test-account-password` — no new secrets introduced by this retry's `AcmeProvider` fix.
- **Files modified on host (`pro-data-tech-prod`):** none new beyond what attempt 5 already created (`/opt/stalwart-mail/` tree, UFW rules, `stalwart-cli` binary) — this retry only adds one new Stalwart server-side object (`AcmeProvider`, stored inside the already-existing `/opt/stalwart-mail/var-lib-stalwart/` bind mount) plus, in later phases, the nginx vhost file, backup tarball directory.
- **Files modified in this repo (`landscape/`) — to be applied at step 08:**
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) (new Stalwart Mail section — image/volume/config model; Bootstrap configuration values; the restart-required-for-effect gotcha; the `AcmeProvider.contact` array-vs-map schema/validator mismatch as a second operational gotcha; new UFW rules; new Compose project; new nginx vhost; `stalwart-cli` noted as an installed host-level admin tool with its confirmed version; note on the previously-orphaned-now-reused cert; note on internal ACME as a second TLS mechanism on this host; mailbox provisioning mechanism documented as `stalwart-cli create`/`apply`)
  - [landscape/services.md](../../landscape/services.md) (new Compose project row under `pro-data-tech-prod`)
  - [landscape/cloudflare.md](../../landscape/cloudflare.md) (A/MX/SPF/DKIM/DMARC record changes, record deletions, reclassify mail records table)
  - [landscape/domains.md](../../landscape/domains.md) (new `mail.aiqadam.org` subdomain + TLS cert entry, noting the dual TLS mechanism)
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) (mail-related secret names already established at attempt 5 — no new ones from this fix)
  - [shared/app-registry.md](../../shared/app-registry.md) optionally, at designer's discretion
- **External APIs called:** Cloudflare DNS API (`GET`/`PATCH`/`DELETE` on named records only, zone `bec8854d698d56ff17cf917367634100`) — called both directly by the executor for DNS cutover, and indirectly by Stalwart itself for ACME DNS-01 challenges using the `DnsServer` object already configured with the same token. No GitHub API calls this retry (`stalwart-cli` already installed by attempt 5).

### Estimated impact
- **Downtime:** none for Penpot/AiQadam prod — this retry makes no changes to those Compose projects or containers. For mail itself: none in the outage sense — the mail server has no live traffic yet (DNS not yet cut over). The MX/A-record cutover (Phase 5, steps 5/6) remains the moment mail routing for `aiqadam.org` becomes live on repo-controlled infrastructure for the first time — unchanged from every prior attempt's framing.
- **Affected services:** New: Stalwart mail (SMTP/IMAP/JMAP/submission) on `pro-data-tech-prod`, its `AcmeProvider`/ACME-TLS configuration, plus a new nginx vhost for its admin UI. Unaffected (verified at every checkpoint): Penpot, AiQadam prod. Affected indirectly: the shared `aiqadam.org` Cloudflare zone (mail-records partition only, not reached until Phase 5).
- **Reversibility:** Host install, UFW rules, nginx vhost, CLI tool, Bootstrap/DKIM/NetworkListener/DnsServer/AcmeProvider config — fully reversible, no data loss. DNS changes — technically reversible at the record level, but practically a one-way operational event once real mail traffic begins.

## Issues / risks

- **HIGH — shared-host blast radius (carried over, unchanged from attempts 1-5).** Placing mail on `pro-data-tech-prod` adds spam/abuse exposure and cold-IP reputation risk to the same host serving Penpot and AiQadam prod. Already accepted by the user at step 05 attempts 1-5.
- **HIGH — DNS is shared, partially-owned zone surgery (carried over, unchanged).** Same class of operation as T-0111's apex repoint; multiple record types, several deletions; irreversible-in-practice once mail traffic begins. Not yet reached by any attempt so far — this retry is the first to potentially reach Phase 5, contingent on Phase 4 completing cleanly.
- **LOW — the `AcmeProvider.contact` map-encoding fix is now confirmed via isolated scratch-container reproduction, including a full successful Let's Encrypt account registration on a distinct test object, but this retry's plan is the first time it is exercised against `pro-data-tech-prod` itself.** Residual risk is that some detail of the real host environment (CLI version behavior, shell-quoting of the embedded JSON on the actual SSH session, DNS-01 propagation timing through the live `DnsServer` object) behaves subtly differently than the scratch container — mitigated by Plan step 2's explicit halt-and-report instruction if the fix does not transfer, rather than further speculative guessing.
- **LOW — Stalwart's own schema documentation (`describe`/`/api/schema`) is now confirmed to be actively misleading for at least one `set<...>`-typed field (`AcmeProvider.contact`).** This raises a general caution for any future `set<...>`-typed field this run or a future task encounters — the executor should not assume schema-documented array encoding is correct without a live round-trip check, and should prefer the `snapshot <OBJECT>` technique (discovered in attempt 5) to see a real, already-accepted example where one exists.
- **MEDIUM — `stalwart-cli`'s exact shell-quoting behavior for an embedded JSON object value (`--field 'contact={"...":true}'`) on the live host has not itself been exercised yet** — attempt 5 confirmed `--field KEY={...}` accepts inline JSON in general (used successfully for `privateKey`), but not specifically with this contact-map shape. If quoting proves awkward over the SSH command line, the executor should fall back to the already-proven NDJSON `apply --file` mechanism (used successfully throughout Phase 3/4) rather than fight shell escaping — this is a mechanism choice within the executor's existing discretion, not a plan-scope change.
- **MEDIUM — DKIM private key material handling, dual TLS mechanisms, CalDAV/CardDAV/POP3/MTA-STS record deletions — all carried over unchanged from attempts 1-5, already approved, not reopened here.**
- **LOW — the live-state resume table above is only as fresh as attempt 5's own final checkpoint.** Plan step 0/0a's re-confirmation exists precisely to catch any drift (e.g., an out-of-band container restart, manual intervention) between attempt 5's halt and this attempt's start — the executor must not skip it even though it seems redundant given how recently attempt 5 ran.
- **LOW — resource contention, version drift risk for the pinned server image (`v0.16`) — unchanged, acceptable tradeoffs already noted in every prior attempt.**

## Open questions (optional)

None are BLOCKED-triggering. This retry's single substantive change — correcting the `AcmeProvider.contact` field's JSON encoding from array to map form, using the already-agreed contact address `postmaster@aiqadam.org` — is a confirmed field-encoding correction to an already-approved decision (Decision F, internal ACME via DNS-01), not a new decision touching approved scope. It is the same character as the auth-env-var, protocol-enum, DKIM-variant, and Bootstrap-restart-timing corrections already folded into attempts 4 and 5 without separate re-confirmation, and squarely within the user's standing delegation ("All up to you. Call me when everything will be ready," extended explicitly at attempt 4's approval to remain in effect "for the remainder of this run"). Recommend the orchestrator proceed directly to writing the step-05 approval handoff under that delegation and advance to step 06 (executor-infra, attempt 6), instructing the executor explicitly to resume from live state per Phase R rather than repeating Phases 0-3.
