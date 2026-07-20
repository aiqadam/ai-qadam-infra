---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-19T12:40:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-04
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-04-solution-designer-attempt-6.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-6.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: >-
  Orchestrator: this IS within the user's standing delegation, but ONLY because the new
  pre-Phase-5 zone-diff safety checkpoint (Plan Phase 4a below) is included exactly as
  specified — that checkpoint is the safeguard that converts what would otherwise be a new,
  unreviewed risk (Stalwart's Automatic DNS management writing to the shared zone for the
  first time, on a mechanism only validated in a disposable scratch container with a fake
  token) into a same-character continuation of the already-approved Decision F. Do not let a
  future attempt drop Phase 4a as "redundant" the way Phase R's re-confirmation was flagged as
  easy to skip in attempt 6 — it is the one checkpoint this attempt has that no prior attempt
  needed, precisely because this is the first time dnsManagement:Automatic touches the real
  zone. The user should still see this plan before it runs (verdict is NEEDS_APPROVAL, not
  PASS) because the residual uncertainty disclosed below (the certificateManagement gate
  itself was not re-triggered end-to-end in the scratch investigation) means this attempt is
  the first live test of the full mechanism. If approved under the standing delegation, write
  step-05 accordingly and advance to executor-infra for attempt 7, instructing it explicitly:
  resume from live state (AcmeProvider i9noabxeabab already live and correctly configured with
  a real LE account registered — do not recreate), execute the two-step Domain wiring with the
  exact publishRecords map value below, run the mandatory zone-diff checkpoint BEFORE touching
  anything in Phase 5, and halt+report (not improvise) if the diff shows anything beyond a
  plausible new _acme-challenge TXT record.
---

## Summary
Seventh-attempt retry: identical to attempt 6's plan in every respect except the `Domain.dnsManagement`/`certificateManagement` wiring step, which now uses the confirmed-safe recipe (`dnsManagement.publishRecords` scoped to a single harmless record type, `{"tlsa":true}`, rather than left to default to the full 11-type auto-publish set) — plus a new mandatory full-zone-diff safety checkpoint inserted immediately after wiring succeeds and strictly before Phase 5's own deliberate DNS cutover begins; end state is unchanged from every prior attempt: a working, repo-owned, TLS-secured, firewalled mail server with the old dead records fully retired.

## Details

### What changed since attempt 6 (read this before executing)

Attempt 6 got further than any prior attempt: it created `AcmeProvider` (id `i9noabxeabab`) successfully using the already-confirmed map-encoding fix, and it completed a real Let's Encrypt account registration (`accountUri` populated) as a side effect. It then discovered a new, deeper requirement not covered by attempt 6's plan text: wiring `Domain.certificateManagement: Automatic` requires `Domain.dnsManagement: Automatic` too, and that field's `publishRecords` sub-setting defaults to auto-publishing nearly the entire mail DNS footprint (`autoConfig, autoConfigLegacy, autoDiscover, caa, dkim, dmarc, mtaSts, mx, spf, srv, tlsRpt` — 11 of the 12 enum members) directly against the shared, partially-owned `aiqadam.org` Cloudflare zone. Attempt 6's executor correctly halted rather than guess a `publishRecords` value or unilaterally decide how much standing DNS-write authority Stalwart should have in a shared zone — this was a new, consequential decision, not a mechanism fix, and the user was asked how to handle it. The user chose "scope it down first."

A follow-up investigation (disposable scratch container, fake Cloudflare token, no real DNS ever touched — same discipline as the investigation that diagnosed the `AcmeProvider.contact` encoding bug in attempt 5) has now confirmed a working, safe scoping recipe:

- `Domain.dnsManagement.publishRecords` accepts a JSON **map** (not array — same `Set<T>` idiom quirk already seen with `AcmeProvider.contact`), and its `minItems:1` constraint is genuinely enforced (empty map/array both rejected) but is satisfied by a single entry.
- Live schema (`describe DnsRecordType` / raw `/api/schema`) confirms the full `DnsRecordType` enum is exactly 12 members: `dkim, tlsa, spf, mx, dmarc, srv, mtaSts, tlsRpt, caa, autoConfig, autoConfigLegacy, autoDiscover`. **There is no "acmeChallenge"/"challenge" member in this enum at all.**
- The ACME DNS-01 challenge TXT record (`_acme-challenge.mail.aiqadam.org`) is a **completely separate mechanism from `publishRecords`**, not gated by it in any way. Evidence: (a) the enum has no member representing it; (b) live behavior in the scratch container — with `dnsManagement: Automatic` active and various `publishRecords` values tested, the domain's self-computed zone-file preview never included an `_acme-challenge` entry regardless of `publishRecords`'s contents; (c) Stalwart's own official docs (stalw.art/docs/server/tls/acme/challenges/, .../acme/configuration/) state that for DNS-01/DnsPersist01 challenge types, Stalwart "publishes the validation record through a configured DNS provider" using the Domain's `dnsServerId` reference directly — no mention of `publishRecords` as a precondition.
- **Confirmed working recipe**: set `publishRecords` to a single harmless, unused-elsewhere record type — `{"tlsa": true}` (TLSA records are not part of this deployment's DNS plan at all, and are not in the default-11 broad set). Verified via `get Domain` afterward correctly showing "Records to Publish: TLSA records" only, not silently reset to the full default.

**Residual, disclosed uncertainty** (not fully re-verified end-to-end against a real ACME server — the scratch investigation's own `AcmeProvider` creation attempts were rejected by Let's Encrypt STAGING on contact-email format before reaching DNS-01 challenge logic): the `certificateManagement: Automatic` → `dnsManagement: Automatic` gate itself (the original error this whole detour started from) was **not** re-triggered in the scratch environment — this part is inferred from the original production error message and docs, not independently re-confirmed. This means the first live test of "does `publishRecords: {tlsa:true}` actually let real cert issuance complete without also touching MX/SPF/DKIM/DMARC/CAA" will be this next production attempt itself. This is why this plan adds a mandatory safety checkpoint (Phase 4a below) before Phase 5 can proceed — no prior attempt needed this checkpoint because no prior attempt reached live `dnsManagement: Automatic` against the real zone.

### Live-state resumption (current, confirmed by attempt 6's executor)

| Object | Value | Status |
|---|---|---|
| `Domain` | `aiqadam.org`, id `b`, enabled, **certificateManagement: Manual, dnsManagement: Manual** | live, unchanged — this attempt's target |
| `DkimSignature` | selector `mail`, type `Dkim1Ed25519Sha256`, id `i9njnzd3krqa` | live, unchanged |
| `NetworkListener` | name `submission`, port 587, id `i9njnzefksaa` | live, unchanged |
| `DnsServer` | Cloudflare variant, id `i9njy0ssaaqb`, TTL 5m, timeout 30s | live, unchanged |
| `AcmeProvider` | id `i9noabxeabab`, directory Let's Encrypt production, challengeType `Dns01`, contact `mailto:postmaster@aiqadam.org`, **accountUri already populated** (real LE account registered) | live, correctly configured — does NOT need recreating |

This retry does **not** repeat Phases 0-3, does **not** recreate `AcmeProvider`. It opens with a minimal live-state re-confirmation (Phase R, same as attempt 6), then proceeds to the two-step `Domain` wiring, the new mandatory zone-diff checkpoint, and then continues through the rest of the plan exactly as previously approved.

### Plan

**Phase R — Resume-from-live-state confirmation (read-only)** — unchanged from attempt 6.

0. Confirm the five already-live objects (`Domain`, `DkimSignature`, `NetworkListener`, `DnsServer`, `AcmeProvider`) are still present and match the table above — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin query Domain"` then repeat for `DkimSignature`, `NetworkListener`, `DnsServer`, `AcmeProvider` — verification: each matches the table above exactly, including `Domain b` still showing `Manual`/`Manual` (not yet wired) and `AcmeProvider i9noabxeabab` still showing its populated `accountUri`. If any object is missing or its id/key fields differ, HALT and report — do not re-run any earlier-phase creation as a "fix" without fresh diagnosis.
0a. No-regression checkpoint — command: `ssh ... "docker ps --filter label=com.docker.compose.project=penpot --format '{{.Names}}: {{.Status}}'"` and `"docker ps --filter label=com.docker.compose.project=aiqadam-prod --format '{{.Names}}: {{.Status}}'"` and external `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` / `https://aiqadam.org/health` — verification: matches the established baseline (Penpot 7/7 `Up`, AiQadam-prod 4/4 `Up`, both external checks 200).

**Phase 4 — TLS via internal ACME (resumed; `AcmeProvider` already live, only `Domain` wiring remains)**

1. Wire `Domain.dnsManagement` to `Automatic`, scoped to a single harmless record type — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin apply --file -" <<'EOF'
{"update":{"Domain":{"b":{"dnsManagement":{"@type":"Automatic","dnsServerId":"i9njy0ssaaqb","publishRecords":{"tlsa":true}}}}}}
EOF` (or the equivalent NDJSON `apply` mechanism already proven working throughout Phase 3/4 for JSON-object-valued fields — use whichever concrete invocation the executor already confirmed works for embedded JSON on this host; this is a shell-mechanics choice, not a plan-scope change). Do dry-run first if the CLI supports it (as attempt 6's executor did for the `certificateManagement` patch), then apply for real. — verification: exit code 0, no `invalidPatch`/`invalidProperties` error.
2. Verify step 1 applied correctly and was not silently reset to defaults — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin get Domain b"` — verification: output shows `DNS Management: Automatic`, `DNS Server: i9njy0ssaaqb` (or equivalent id rendering), and **"Records to Publish: TLSA records" only** — not the full default set (`autoConfig, autoConfigLegacy, autoDiscover, caa, dkim, dmarc, mtaSts, mx, spf, srv, tlsRpt`). If the output shows any record type other than `tlsa`, or shows the full default set, **HALT immediately and report** — do not proceed to step 3; this would mean the `publishRecords` scoping was not applied as diagnosed and needs fresh investigation before any further change, per the residual uncertainty disclosed above.
3. Wire `Domain.certificateManagement` to `Automatic`, referencing the live `AcmeProvider` — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin apply --file -" <<'EOF'
{"update":{"Domain":{"b":{"certificateManagement":{"@type":"Automatic","acmeProviderId":"i9noabxeabab"}}}}}
EOF` — **omit `subjectAlternativeNames` entirely** (per the already-diagnosed omit-optional-fields pattern that resolved the identical symptom for `AcmeProvider.contact` and was independently re-confirmed by attempt 6's own patch-2 finding). — verification: exit code 0, no `invalidPatch`/`invalidProperties` error. If this fails with `ACME provider requires automatic DNS management` again, step 1/2 did not take effect as expected — HALT and report, do not retry blindly.
4. Post-wiring verification, read-only — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin get Domain b"` — verification: `Certificate Management: Automatic`, `ACME Provider: i9noabxeabab`, `DNS Management: Automatic` with `publishRecords` still showing only `tlsa`. Both wiring steps confirmed live and correctly scoped.

**Phase 4a — MANDATORY safety checkpoint (new this attempt — do not skip, do not treat as redundant with Phase R)**

Runs immediately after step 4 succeeds, strictly before any Phase 5 step. This is the checkpoint that makes granting Stalwart `dnsManagement: Automatic` against the real shared zone safe to do without a fresh separate approval round-trip: it exists specifically because this is the first attempt in this run's history where that mechanism touches the real zone, and the `certificateManagement`→`dnsManagement` gate interaction was not independently re-verified end-to-end in the scratch investigation.

4a. **Poll for ACME issuance completion, bounded wait.** Command: `ssh ... "docker logs stalwart-mail-server-1 --since 2m"` and/or `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin get AcmeProvider i9noabxeabab"` (look for a populated certificate/issuance status beyond the already-populated `accountUri`), repeated at ~30s intervals for up to 5 minutes. — verification: evidence of successful certificate issuance (log line referencing certificate obtained for `mail.aiqadam.org`, or an issuance-status field on the `AcmeProvider`/`Domain` object). **If issuance has not completed within 5 minutes, HALT and report — do not wait indefinitely, do not proceed to 4b or Phase 5.**
4b. **Full live Cloudflare zone dump**, immediately after 4a succeeds — command: `GET /zones/bec8854d698d56ff17cf917367634100/dns_records?per_page=100` using `cloudflare-ai-qadam-api-token` — capture all 33 (or 34, if `_acme-challenge` was created) records.
4c. **Diff the dump against the pre-run documented snapshot in `landscape/cloudflare.md`.** Verification (all must hold, or HALT):
   - The **only** permissible difference is a new `_acme-challenge.mail.aiqadam.org` TXT record (plausible if Stalwart's ACME renewal/challenge already fired during 4a's poll window). If present, note its content but do not act on it further — it is Stalwart's own ephemeral record, self-managed.
   - `aiqadam.org` MX, apex SPF TXT, `mail._domainkey.aiqadam.org` TXT (DKIM), `_dmarc.aiqadam.org` TXT, `_mta-sts.aiqadam.org`/`mta-sts.aiqadam.org`, `_smtp._tls.aiqadam.org` TXT (TLS-RPT), all SRV records (`_caldavs`, `_carddavs`, `_imaps`, `_jmap`, `_pop3s`, `_submissions`), `autoconfig.aiqadam.org`/`autodiscover.aiqadam.org`/`ua-auto-config.aiqadam.org` CNAMEs, `_ua-auto-config.aiqadam.org` TXT, `webmail.aiqadam.org` A, and the zone-wide CAA record (if one exists) — **all must be byte-for-byte identical to their pre-run documented values**, still pointing at the dead `212.20.151.29` third-party host or otherwise unchanged. Phase 5 has not run yet; none of these should have moved.
   - `resend._domainkey.aiqadam.org`, `send.aiqadam.org` MX/TXT (SES), wildcard `*.aiqadam.org`, all 5 tunnel/GitHub-Pages records — untouched, as always.
   - **If ANYTHING beyond a plausible new `_acme-challenge` TXT record differs from the pre-run snapshot, HALT IMMEDIATELY and report. Do not proceed to Phase 5. This would mean the `publishRecords` scoping did not work as diagnosed and is a serious finding requiring fresh user input, not further improvisation** — the same discipline attempt 6's executor already applied when it declined to guess a `publishRecords` value; this checkpoint exists to catch the case where the guess (now a confirmed-in-scratch-only recipe) turns out not to transfer cleanly to the real host/zone.
4d. **Confirm TLS actually serves correctly on 465/993** — command: `openssl s_client -connect mail.aiqadam.org:993 -servername mail.aiqadam.org </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer` (run via SSH loopback/direct-IP since external DNS does not yet point at the host — DNS-01 issuance does not require the A record to point at the host first) — verification: subject/SAN includes `mail.aiqadam.org`, issuer Let's Encrypt, not expired. This step's most meaningful run is after Phase 5's DNS cutover (also re-checked in Phase 8), but this same-host check confirms the cert itself is issued and bound before DNS is touched.

Only after 4a-4d all pass does the plan proceed to Phase 5.

**Phase 5 — DNS cutover (Cloudflare `aiqadam.org` zone — single named-record operations only, freshness-check immediately before each write)** — unchanged from attempt 6.

All Cloudflare API calls use `cloudflare-ai-qadam-api-token` (secrets-inventory name only). Zone ID `bec8854d698d56ff17cf917367634100`. Every step: `GET` the specific record immediately before mutating it to confirm it still matches the value documented in `landscape/cloudflare.md` (as re-confirmed by Phase 4a's zone dump); abort that step and escalate if it has drifted.

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
15. **Explicitly out of scope, confirmed unchanged, not touched:** `resend._domainkey.aiqadam.org`, `send.aiqadam.org` MX/TXT (SES), wildcard `*.aiqadam.org`, all 5 tunnel/GitHub-Pages records. Verification: post-cutover full zone dump diffed against pre-run snapshot confirms byte-for-byte unchanged except the deliberate changes above.

**Phase 6 — Mailbox provisioning** — unchanged from attempt 6.

16. Create one test mailbox via `stalwart-cli` — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin describe Account"` (read-only schema confirmation) — verification: confirms `name`/`domainId`/`roles`/`permissions`/`credentials` field shape live, before constructing the create call.
17. Generate the test account's password (secret name `stalwart-mail-test-account-password`, already generated and recorded in attempt 5's execution) and create the account — command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin create Account --name test --domain-id b --credentials-secret <value via stdin/heredoc, not a literal arg>"` (exact flag names per step 16's confirmed CLI help output; use domain id `b`; if `create` does not support this object type directly, fall back to the same `apply`-with-NDJSON mechanism as Phase 4, one `upsert` for the `Account`/`User` object) — verification: a subsequent `... describe Account` (or `list`) shows `test@aiqadam.org` present.
18. Document the mailbox provisioning mechanism (confirmed `stalwart-cli` command shape) in `landscape/hosts/pro-data-tech-prod.md` at step 08.

**Phase 7 — nginx vhost for Stalwart webadmin** — unchanged from attempt 6.

19. Add nginx vhost proxying `https://mail.aiqadam.org/` (root, per the empirically-confirmed `/account` SPA redirect) to `127.0.0.1:8080`, TLS via the existing certbot pattern, reusing the orphaned cert from attempt 1 — command: write `/etc/nginx/sites-available/mail.aiqadam.org` (proxy_pass `http://127.0.0.1:8080`, ssl_certificate pointing at `/etc/letsencrypt/live/mail.aiqadam.org/`), symlink to `sites-enabled`, `sudo nginx -t && sudo systemctl reload nginx` — verification: `https://mail.aiqadam.org/` returns Stalwart's login/portal page (200 or 302→/account), external probe from management workstation.

    Note (unchanged): `mail.aiqadam.org` has TLS served two ways for two different purposes — nginx+certbot for the admin UI on 443, Stalwart's own internal ACME cert for SMTP/IMAP TLS on 465/993/587/25. Not a conflict; flagged for step 08's landscape documentation.

**Phase 8 — Verification / deliverability testing** — unchanged from attempt 6.

20. Internal SMTP/IMAP/JMAP/submission reachability — command (management workstation): `Test-NetConnection mail.aiqadam.org -Port 25`, `-Port 465`, `-Port 587`, `-Port 993` — verification: all `TcpTestSucceeded: True`.
21. TLS validity (SMTP/IMAP side, internal ACME) — per Phase 4a step 4d, re-run now that DNS fully resolves externally.
22. DNS propagation checks — command: `nslookup mail.aiqadam.org 1.1.1.1`, `nslookup -type=MX aiqadam.org 1.1.1.1`, `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1`, `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` — verification: each resolves to the new values externally.
23. External send/receive test: external Gmail (or equivalent) → `test@aiqadam.org`, confirm receipt via IMAP; `test@aiqadam.org` → external address, confirm arrival (inbox or spam, both acceptable per task's Notes).
24. mail-tester.com score captured as deliverability baseline, recorded in `landscape/hosts/pro-data-tech-prod.md` and task close-out notes.

**Phase 9 — Backups** — unchanged from attempt 6.

25. Local-disk-only backup of Stalwart's data directory — command: `ssh ... "sudo mkdir -p /var/backups/stalwart-mail && sudo tar czf /var/backups/stalwart-mail/stalwart-data-$(date +%Y%m%dT%H%M%SZ).tar.gz -C /opt/stalwart-mail var-lib-stalwart etc-stalwart"` — verification: `ls -la /var/backups/stalwart-mail/` shows the new tarball, non-zero size. Daily cron/systemd-timer, 14-day local retention — recommended follow-on, not built into this pass.

### Rollback

Rollback remains phase-scoped; DNS and host-install rollback are independent. Phase R (resume-confirmation) is read-only and needs no rollback.

1. **`Domain` wiring rollback (Phase 4, steps 1-4):** revert both fields back to `Manual` — command: `ssh ... "... apply --file -" <<'EOF'
{"update":{"Domain":{"b":{"certificateManagement":{"@type":"Manual"},"dnsManagement":{"@type":"Manual"}}}}}
EOF` — fully reversible, does not touch `AcmeProvider i9noabxeabab` itself or any of the other four already-live objects. If Phase 4a's zone-diff checkpoint finds unexpected drift, this rollback is the first action to take (stop Stalwart from further autonomous DNS activity) before investigating further.
2. **`AcmeProvider` rollback (if needed independently):** `ssh ... "... delete AcmeProvider i9noabxeabab"` — only needed if abandoning internal ACME entirely; not needed for a routine rollback of just the wiring.
3. **DNS rollback (Phase 5, steps 5, 7, 8, 9):** re-`PATCH` each record back to its pre-change documented value (A record → `212.20.151.29`; SPF → `v=spf1 ip4:212.20.151.29 mx -all`; DKIM TXT → prior RSA key value, captured verbatim from `landscape/cloudflare.md` before this run's changes; DMARC → `p=reject`). Clean no-op only before real mail traffic and external SPF-cache pickup occur; once mailboxes are in active use, DNS rollback is an emergency-stop, not a safe revert.
4. **Deleted-record rollback (Phase 5, steps 11, 12, 13 — `webmail`, `mta-sts`/`ua-auto-config`, `_caldavs`/`_carddavs`/`_pop3s`):** re-`CREATE` each deleted record with its exact pre-deletion name/type/content/TTL, captured verbatim from `landscape/cloudflare.md` before this run executes. Record IDs will differ on recreate; update landscape at step 08 regardless.
5. **Mailbox/data rollback (Phase 6):** delete the test account via `stalwart-cli delete Account` (or `apply` with a `delete` op against the same NDJSON convention) — no real user data exists in this plan's scope.
6. **nginx vhost rollback (Phase 7, step 19):** `ssh ... "sudo rm /etc/nginx/sites-enabled/mail.aiqadam.org && sudo nginx -t && sudo systemctl reload nginx"` — fully reversible; does not touch the orphaned certbot cert itself.
7. **Orphaned cert:** no rollback action needed either way — remains valid/inert if Phase 7 is rolled back after being reached.
8. **`_acme-challenge` TXT record (if Phase 4a created one):** self-managed by Stalwart; if `dnsManagement` is rolled back to `Manual` (rollback item 1), Stalwart will no longer maintain it — it can be left to expire naturally or deleted manually via `DELETE /zones/.../dns_records/<id>`; harmless either way, not a real record any other party depends on.
9. **No rollback needed for Phase 4a (verification/diff, read-only except the polling wait), Phase 8 (verification, read-only), or Phase 9 (backup, additive-only).**

### Verification (for step 07)

- **On-host:**
  - `query Domain`/`DkimSignature`/`NetworkListener`/`DnsServer`/`AcmeProvider` (Phase R, step 0) → all five present, matching the resume table above, before any new state change is made.
  - `get Domain b` (Phase 4, step 2, after `dnsManagement` wiring) → `DNS Management: Automatic`, `publishRecords` shows **only `tlsa`** — not the 11-type default set. This is the single most important on-host check this attempt introduces.
  - `get Domain b` (Phase 4, step 4, after both wirings) → `Certificate Management: Automatic`, `ACME Provider: i9noabxeabab`, `DNS Management: Automatic` with `publishRecords` still scoped to `tlsa` only.
  - Phase 4a step 4a: evidence of completed ACME issuance within the 5-minute poll window (log line and/or issuance-status field) — bounded wait, not indefinite.
  - Phase 4a step 4d / Phase 8 step 21: `openssl s_client -connect mail.aiqadam.org:993 ...` → cert subject `mail.aiqadam.org`, Let's Encrypt issuer, not expired.
  - `stalwart-cli ... describe Account` (or `list`) → `test@aiqadam.org` present.
  - `/var/backups/stalwart-mail/` contains at least one non-zero-size tarball.
  - `sudo certbot certificates -d mail.aiqadam.org` → still shows the attempt-1 cert, now referenced by the new nginx vhost.
  - Penpot: `docker ps --filter label=com.docker.compose.project=penpot` → all containers `Up` (compare against established baseline: 7/7).
  - AiQadam prod: `docker ps --filter label=com.docker.compose.project=aiqadam-prod` → all containers `Up` (compare against established baseline: 4/4).
- **External:**
  - **Phase 4a step 4b/4c (new, mandatory, before Phase 5): full Cloudflare zone dump, diffed against the pre-run documented snapshot in `landscape/cloudflare.md`** — confirms only a plausible new `_acme-challenge.mail.aiqadam.org` TXT record could have appeared; MX/SPF/DKIM/DMARC/CAA/SRV/MTA-STS/autoconfig/autodiscover records all still exactly their pre-run documented values (still pointing at the dead third-party host). Any other difference is a HALT condition, not a pass/fail note.
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
  - Full Cloudflare zone dump (post-cutover, Phase 5 step 15) diffed against the Phase 4a snapshot: confirms `resend._domainkey`, `send.aiqadam.org` MX/TXT, wildcard, and all 5 tunnel/pages records byte-for-byte unchanged, and only the deliberate Phase 5 changes plus the `_acme-challenge` record differ from the original pre-run snapshot.

### Resources used
- **Secrets (by name):** `cloudflare-ai-qadam-api-token` (existing, used both for the executor's direct DNS cutover in Phase 5/Phase 4a's dump, and indirectly, via the already-configured `DnsServer` object, for Stalwart's own internal ACME DNS-01 challenge and its now-scoped `publishRecords: {tlsa:true}` self-management); already-recorded: `stalwart-mail-admin-password`, `stalwart-mail-domain-admin-password`, `stalwart-mail-test-account-password` — no new secrets introduced by this retry.
- **Files modified on host (`pro-data-tech-prod`):** none new beyond what prior attempts already created (`/opt/stalwart-mail/` tree, UFW rules, `stalwart-cli` binary) — this retry only wires two existing Stalwart server-side objects together (`Domain.dnsManagement`, `Domain.certificateManagement`), stored inside the already-existing `/opt/stalwart-mail/var-lib-stalwart/` bind mount, plus, in later phases, the nginx vhost file, backup tarball directory.
- **Files modified in this repo (`landscape/`) — to be applied at step 08:**
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) (new Stalwart Mail section — image/volume/config model; Bootstrap configuration values; the restart-required-for-effect gotcha; the `AcmeProvider.contact` and `Domain.dnsManagement.publishRecords` array-vs-map schema/validator mismatch as recurring operational gotchas; the `publishRecords` default-broad/opt-out-not-opt-in behavior and the `tlsa`-scoping workaround; new UFW rules; new Compose project; new nginx vhost; `stalwart-cli` noted as an installed host-level admin tool with its confirmed version; note on the previously-orphaned-now-reused cert; note on internal ACME as a second TLS mechanism on this host; mailbox provisioning mechanism documented as `stalwart-cli create`/`apply`)
  - [landscape/services.md](../../landscape/services.md) (new Compose project row under `pro-data-tech-prod`)
  - [landscape/cloudflare.md](../../landscape/cloudflare.md) (A/MX/SPF/DKIM/DMARC record changes, record deletions, new `_acme-challenge` record if present, reclassify mail records table)
  - [landscape/domains.md](../../landscape/domains.md) (new `mail.aiqadam.org` subdomain + TLS cert entry, noting the dual TLS mechanism)
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) (mail-related secret names already established — no new ones from this fix)
  - [shared/app-registry.md](../../shared/app-registry.md) optionally, at designer's discretion
- **External APIs called:** Cloudflare DNS API (`GET`/`PATCH`/`DELETE` on named records only, plus the Phase 4a full-zone `GET` dump, zone `bec8854d698d56ff17cf917367634100`) — called both directly by the executor, and indirectly by Stalwart itself for ACME DNS-01 challenges and its now-scoped TLSA self-management, using the `DnsServer` object already configured with the same token. No GitHub API calls this retry.

### Estimated impact
- **Downtime:** none for Penpot/AiQadam prod — this retry makes no changes to those Compose projects or containers. For mail itself: none in the outage sense — the mail server has no live traffic yet until Phase 5. The MX/A-record cutover (Phase 5, steps 5/6) remains the moment mail routing for `aiqadam.org` becomes live on repo-controlled infrastructure for the first time — unchanged from every prior attempt's framing.
- **Affected services:** New: Stalwart mail (SMTP/IMAP/JMAP/submission) on `pro-data-tech-prod`, its `AcmeProvider`/ACME-TLS configuration now fully wired to the `Domain`, plus a new nginx vhost for its admin UI. Unaffected (verified at every checkpoint): Penpot, AiQadam prod. Affected indirectly and for the first time this attempt: the shared `aiqadam.org` Cloudflare zone gains a second, autonomous writer (Stalwart's own DNS-01 challenge + scoped TLSA self-management) alongside the executor's direct Phase 5 writes — this is exactly the new risk category Phase 4a's checkpoint exists to bound and verify.
- **Reversibility:** Host install, UFW rules, nginx vhost, CLI tool, Bootstrap/DKIM/NetworkListener/DnsServer/AcmeProvider/Domain-wiring config — fully reversible, no data loss. DNS changes — technically reversible at the record level, but practically a one-way operational event once real mail traffic begins.

## Issues / risks

- **HIGH — shared-host blast radius (carried over, unchanged from attempts 1-6).** Placing mail on `pro-data-tech-prod` adds spam/abuse exposure and cold-IP reputation risk to the same host serving Penpot and AiQadam prod. Already accepted by the user across prior approvals.
- **HIGH — DNS is shared, partially-owned zone surgery (carried over, unchanged).** Same class of operation as T-0111's apex repoint; multiple record types, several deletions; irreversible-in-practice once mail traffic begins. Phase 5 has still never been reached by any attempt so far.
- **MEDIUM-HIGH — this is the first attempt in this run's history where Stalwart itself, not just the executor, gets standing write access to the shared Cloudflare zone (via `dnsManagement: Automatic`).** The `publishRecords: {tlsa:true}` scoping recipe is confirmed working in an isolated scratch container against a fake token, including confirming via `get Domain` that it renders correctly and is not silently reset to defaults — but it has never been exercised against the real host/zone. Mitigated specifically by Phase 4a's mandatory full-zone-diff checkpoint, which runs before Phase 5 and is instructed to HALT on any unexpected difference rather than improvise. This checkpoint is the reason this plan can proceed under the standing delegation rather than requiring a fresh separate round-trip — do not drop it in a future attempt.
- **MEDIUM — the `certificateManagement`→`dnsManagement` gate interaction itself (the original error that started this whole detour) was not independently re-triggered end-to-end in the scratch investigation**, because the scratch environment's own `AcmeProvider` creation was rejected by Let's Encrypt STAGING on contact-email format before reaching DNS-01 challenge logic. This means Phase 4 steps 1-4 in production are the first true end-to-end exercise of the full wiring sequence. Mitigated by: step 2's explicit halt-and-report instruction if `publishRecords` doesn't render as scoped; step 3's explicit halt-and-report if the `dnsManagement` gate error recurs; Phase 4a's bounded (5-minute) poll for issuance rather than an indefinite wait, with explicit halt-and-report if issuance doesn't complete in that window.
- **LOW — the `AcmeProvider.contact` map-encoding fix remains confirmed and does not need repeating** — `AcmeProvider i9noabxeabab` is already live and correct on the real host, unchanged by this attempt.
- **LOW — Stalwart's own schema documentation (`describe`/`/api/schema`) is now confirmed to be actively misleading for at least two `set<...>`-typed fields (`AcmeProvider.contact`, `Domain.dnsManagement.publishRecords`).** General caution for any future `set<...>`-typed field this run or a future task encounters.
- **MEDIUM — `stalwart-cli`'s exact shell-quoting behavior for embedded JSON object values on the live host, for this specific field, has not itself been exercised yet** — the executor should fall back to the already-proven NDJSON `apply` mechanism (used successfully throughout Phase 3/4) if inline `--field` quoting proves awkward — a mechanism choice within existing discretion, not a plan-scope change.
- **MEDIUM — DKIM private key material handling, dual TLS mechanisms, CalDAV/CardDAV/POP3/MTA-STS record deletions — all carried over unchanged from attempts 1-6, already approved, not reopened here.**
- **LOW — the live-state resume table above is only as fresh as attempt 6's own final checkpoint.** Plan step 0's re-confirmation exists precisely to catch any drift between attempt 6's halt and this attempt's start — the executor must not skip it.
- **LOW — resource contention, version drift risk for the pinned server image (`v0.16`) — unchanged, acceptable tradeoffs already noted in every prior attempt.**

## Open questions (optional)

None are BLOCKED-triggering. This retry's substantive change — scoping `Domain.dnsManagement.publishRecords` to `{"tlsa":true}` rather than accepting the broad 11-type default, then wiring `certificateManagement: Automatic` — is a confirmed, empirically-tested resolution to the specific new risk attempt 6 correctly escalated rather than guessed at, following the user's explicit direction ("scope it down first"). It is a materially different situation from the routine field-encoding fixes folded into attempts 4-6 under the standing delegation: this is the first time this run grants Stalwart itself standing write access to the shared zone. That is why this handoff carries `verdict: NEEDS_APPROVAL` rather than proceeding silently — **but it is still within the user's standing delegation if and only if Phase 4a's safety checkpoint is included exactly as specified.** The checkpoint is the safeguard that makes this a safe, same-character continuation (verify-before-trust, halt-on-anomaly, same discipline as every DNS-touching step in this plan) rather than a new unbounded risk. Recommend the orchestrator present this plan for approval, noting explicitly that approval is being sought primarily to confirm the user is comfortable with Stalwart holding scoped (`tlsa`-only) autonomous DNS-write capability in the shared zone — not because any individual mechanism step is in doubt.
