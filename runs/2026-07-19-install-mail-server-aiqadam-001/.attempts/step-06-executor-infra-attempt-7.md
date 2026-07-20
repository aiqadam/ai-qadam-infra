---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 06
agent: executor-infra
verdict: BLOCKED
created: 2026-07-19T06:30:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-06
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-6.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - landscape/cloudflare.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
artifacts_changed:
  - "Stalwart Domain b: dnsManagement wired Manual->Automatic (dnsServerId i9njy0ssaaqb, publishRecords {tlsa:true}), verified scoped correctly, then rolled back to Manual"
  - "Stalwart Domain b: certificateManagement wired Manual->Automatic (acmeProviderId i9noabxeabab), verified live with real ACME cert issued, then rolled back to Manual"
  - "Cloudflare aiqadam.org zone: 20 new TLSA records created by Stalwart's scoped self-management during the ~2 minutes dnsManagement was Automatic (_25/_443/_465/_993/_995._tcp.{mail,autoconfig,autodiscover,mta-sts,ua-auto-config}.aiqadam.org, 4 records each for 5 names) - NOT deleted, left in place per plan rollback item 8 (self-managed, harmless, no rollback action required)"
  - "Cloudflare aiqadam.org zone: 1 new record _acme-challenge.aiqadam.org TXT created by Stalwart's ACME DNS-01 challenge mechanism during issuance - NOT deleted, left in place per plan rollback item 8"
  - "/tmp/domain-dns-patch.json, /tmp/domain-cert-patch.json, /tmp/domain-rollback-patch.json on pro-data-tech-prod (all created and removed within this attempt, confirmed absent)"
next_step_hint: >-
  Phase 4a's mandatory safety checkpoint did its job exactly as designed: it caught a real
  zone-drift signal before Phase 5 could touch anything. The two-step Domain wiring
  (dnsManagement -> Automatic with publishRecords:{tlsa:true}, then certificateManagement ->
  Automatic) worked EXACTLY as diagnosed by attempt 6/7's scratch investigation -- publishRecords
  rendered as scoped ("Records to Publish: TLSA records" only, not the 11-type default), a real
  Let's Encrypt certificate was issued and confirmed serving on both 993 and 465 within about 2
  minutes (subject CN=*.aiqadam.org, issuer Let's Encrypt CN=YE2, valid through 2026-10-17), and
  the only Cloudflare-zone side effects directly attributable to this mechanism were 20 TLSA
  records (5 hostnames x 4 records, all type TLSA, matching publishRecords' scope exactly) plus 1
  _acme-challenge.aiqadam.org TXT record (the anticipated ACME DNS-01 ephemeral record, albeit
  apex-anchored rather than mail.-subdomain-anchored as the plan's illustrative text guessed --
  same mechanism, same self-managed/harmless character). BUT the mandatory full-zone diff also
  surfaced two records this attempt did NOT create and cannot explain: "qa.aiqadam.org" (A,
  95.46.211.230, comment "pro-data-tech-qa (migrated from qa-uz)") and "auth.qa.aiqadam.org" (A,
  95.46.211.230, comment "pro-data-tech-qa Authentik"), both created 2026-07-18T04:40 UTC -- the
  day BEFORE this run started and hours before Stalwart ever had zone access. Per the landscape's
  own T-0110 record, qa.aiqadam.org was supposed to have been deleted in favor of qa-uz.aiqadam.org
  and auth.qa.aiqadam.org has never been documented anywhere in this repo. This is undocumented
  drift in the shared zone from an unrelated actor/workflow, not a failure of this attempt's
  publishRecords scoping -- but the plan's Phase 4a gate text is explicit and non-negotiable ("If
  ANYTHING beyond a plausible new _acme-challenge TXT record differs... HALT IMMEDIATELY... do not
  proceed to Phase 5"), and does not carve out an exception for "differences independently proven
  unrelated to this attempt's mechanism." This executor halted per that instruction rather than
  reasoning past the gate, then executed the plan's own designated rollback (Domain wiring reverted
  to Manual/Manual, confirmed via get Domain b) since the gate fired. AcmeProvider i9noabxeabab
  remains live/valid/inert (its LE account registration is unaffected by the Domain-level rollback)
  and does not need recreating by the next attempt. Recommend this comes back to the user as a
  genuinely new decision, NOT a routine mechanism retry: (a) the publishRecords:{tlsa:true} scoping
  recipe itself is now confirmed fully correct and safe end-to-end against the real host/zone --
  this part of the investigation is closed and should not be re-litigated; (b) the open question is
  what to do about the pre-existing, out-of-band qa.aiqadam.org/auth.qa.aiqadam.org drift --
  options include (i) treat it as confirmed-benign (evidently a legitimate change from this repo's
  own QA/Authentik work on 2026-07-18, just never reflected in landscape/cloudflare.md) and update
  the Phase 4a snapshot baseline before re-running, or (ii) investigate it properly first (who/what
  created it, is landscape/cloudflare.md simply stale, does any other run need to reconcile it) --
  either way this is a landscape-freshness gap outside T-0117's scope that the user should decide
  how to handle, not something this executor should paper over unilaterally. Whichever is chosen,
  attempt 8 (if any) can resume directly from live state: AcmeProvider i9noabxeabab still correct,
  Domain b back to Manual/Manual, the 21 harmless new Cloudflare records (20 TLSA + 1
  _acme-challenge) can be left as-is or cleaned up at the user's discretion, Phase 5 onward remains
  entirely unexecuted.
---

## Summary
Phase R re-confirmation, the two-step `Domain` wiring (Phase 4), and Phase 4a's mandatory safety checkpoint all executed exactly per plan; the wiring itself succeeded perfectly (scoped `publishRecords:{tlsa:true}` verified correct, real Let's Encrypt certificate issued and confirmed serving within ~2 minutes) — but Phase 4a's full zone-diff surfaced two Cloudflare records (`qa.aiqadam.org`, `auth.qa.aiqadam.org`) not in the documented pre-run snapshot and not attributable to Stalwart's scoped DNS management (both created 2026-07-18, before this run began and before Stalwart had any zone access). Per the plan's explicit, non-negotiable gate instruction, this executor halted immediately, did not proceed to Phase 5, and executed the plan's designated rollback (reverting `Domain.dnsManagement`/`certificateManagement` back to `Manual`/`Manual`, confirmed). No DNS cutover, mailbox provisioning, nginx vhost, verification, or backup phases were attempted. Penpot and AiQadam-prod confirmed unregressed throughout.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes (`step-05-user-approval.md` `inputs_read` lists `runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md`; step-04 verdict `NEEDS_APPROVAL`; step-05 confirms `APPROVED` under the user's standing delegation, contingent on Phase 4a)

### Execution log

#### Instruction 1: Cheap pre-mutation re-confirmation (this is a separate agent invocation from attempt 6)
- Commands: `get Domain b`, `get AcmeProvider i9noabxeabab`
- Exit code: 0 (both)
- Output (trimmed):
  ```
  Domain b: Manual/Manual, unchanged - MATCH
  AcmeProvider i9noabxeabab: accountUri populated (https://.../acme/acct/3547717115) - MATCH
  ```
- Result: success — no drift since attempt 6's halt. Also confirmed no-regression baseline: Penpot 7/7 `Up`, AiQadam-prod 4/4 `Up` (`aiqadam-prod-web-next-1` present as the already-documented 4th container), external `https://penpot.aiqadam.org` → 200, `https://aiqadam.org/health` → 200.
- Backup taken: n/a (read-only)

#### Phase 4, step 1: Wire `Domain.dnsManagement` to `Automatic`, scoped to `{"tlsa":true}`
- Discovery: the plan's illustrative `{"update":{"Domain":{"b":{...}}}}` shape failed CLI parsing (`error: invalid plan NDJSON on line 1: missing field @type`). Used `stalwart-cli snapshot Domain --allow-unresolved DnsServer,AcmeProvider,Directory,Tenant` to discover the CLI's actual expected plan-file shape: a top-level `{"@type":"upsert","object":"Domain","matchOn":["name"],"value":{"domain-b":{...}}}` envelope (matching the convention already used successfully in attempt 5's Bootstrap `apply`). This is a shell/payload-mechanics discovery, not a plan-scope change.
- Command: `ssh ... "STALWART_PASSWORD='<value>' /home/tvolodi/.cargo/bin/stalwart-cli --url http://127.0.0.1:8080 --user admin apply --file /tmp/domain-dns-patch.json --dry-run"` with file content `{"@type":"upsert","object":"Domain","matchOn":["name"],"value":{"domain-b":{"name":"aiqadam.org","dnsManagement":{"@type":"Automatic","dnsServerId":"i9njy0ssaaqb","publishRecords":{"tlsa":true}}}}}`
- Exit code: 0 (dry-run: `Plan: 0 destroy, 0 update, 0 create, 1 upsert (1 objects)`)
- Real apply — Command: same without `--dry-run`. Exit code: 0. Output: `✓ upserted Domain (1)` / `Done: 0 destroyed, 1 updated, 0 created (0 failed)`.
- Result: success
- Backup taken: n/a (config change; rollback = revert to `Manual`, executed later this attempt)

#### Phase 4, step 2: Verify `dnsManagement` applied exactly as scoped
- Command: `get Domain b`
- Exit code: 0
- Output (trimmed):
  ```
  DNS Management:
    Type: Automatic DNS management
    DNS Provider
      DNS Server:  Cloudflare aiqadam.org zone (id: i9njy0ssaaqb)
    Records to Publish
      Record Types: TLSA records
  ```
- Result: **success — scoping confirmed exact.** Not silently reset to the 11-type default. This was the single most important on-host check this attempt introduces, and it passed cleanly.
- Backup taken: n/a

#### Phase 4, step 3: Wire `Domain.certificateManagement` to `Automatic`
- Command: `apply --file /tmp/domain-cert-patch.json --dry-run` then real apply, file content `{"@type":"upsert","object":"Domain","matchOn":["name"],"value":{"domain-b":{"name":"aiqadam.org","certificateManagement":{"@type":"Automatic","acmeProviderId":"i9noabxeabab"}}}}` (`subjectAlternativeNames` omitted entirely per the already-diagnosed pattern)
- Exit code: 0 (dry-run and real apply both). Output: `✓ upserted Domain (1)` / `Done: 0 destroyed, 1 updated, 0 created (0 failed)`. No `invalidPatch`/`invalidProperties` error — the `ACME provider requires automatic DNS management` gate from attempt 6 did not recur, confirming step 1/2 took effect as expected.
- Result: success
- Backup taken: n/a

#### Phase 4, step 4: Post-wiring verification
- Command: `get Domain b`
- Exit code: 0
- Output (trimmed):
  ```
  Certificate Management: ACME TLS certificate management
    ACME Provider: https://acme-v02.api.letsencrypt.org/directory (id: i9noabxeabab)
  DNS Management: Automatic DNS management
    Records to Publish: TLSA records
  ```
- Result: success — both wirings live and correctly scoped simultaneously. (Note: the CLI's "Zone File" preview section at this point also rendered speculative CAA/`_validation-persist` lines — this is Stalwart's locally-computed full zone-file preview for informational display, not evidence of what it actually publishes given the `publishRecords` scope; the real publish behavior was verified externally in Phase 4a below.)
- Backup taken: n/a

#### Phase 4a, step 4a: Bounded poll for ACME issuance completion
- Method: backgrounded poll loop (`docker logs stalwart-mail-server-1 --since Nm | grep -iE 'acme|certificate|...'`) at 30s intervals, cross-checked directly against TLS state on 993/465 via `openssl s_client`.
- Findings: container logs remained empty throughout (consistent with this run's already-documented sparse API-driven-config-change logging — not itself alarming; `docker inspect` confirmed `healthy`, 0 restarts). Direct TLS probe was the definitive signal:
  - Poll 1 (~t+0): `openssl s_client -connect 127.0.0.1:993` → `subject=CN=rcgen self signed cert` (still the internal fallback cert, no issuance yet).
  - Poll 2 (~t+30s): same probe → **`subject=CN=*.aiqadam.org`, `issuer=C=US, O=Let's Encrypt, CN=YE2`, `notBefore=Jul 19 05:24:01 2026 GMT`, `notAfter=Oct 17 05:24:00 2026 GMT`.** Also confirmed identically on port 465.
- Result: **success — real certificate issuance confirmed within ~1 minute, well inside the 5-minute bound.**
- Backup taken: n/a (read-only polling)

#### Phase 4a, step 4b: Full live Cloudflare zone dump
- Command: `GET https://api.cloudflare.com/client/v4/zones/bec8854d698d56ff17cf917367634100/dns_records?per_page=100` using `cloudflare-ai-qadam-api-token`
- Exit code: HTTP 200, `"success":true`
- Output: **56 records** (not the expected 33 + at most 1 new `_acme-challenge` record). Captured to a local scratch file for diffing (not committed to the repo).
- Result: completed; count mismatch triggered the diff analysis in step 4c below.
- Backup taken: n/a (read-only)

#### Phase 4a, step 4c: Diff against the documented pre-run snapshot (`landscape/cloudflare.md`)
- All 33 previously-documented records — `aiqadam.org` apex A/CAA/MX/SPF-TXT, `*.aiqadam.org` wildcard, `penpot.aiqadam.org`, `qa-uz.aiqadam.org`, all 22 mail records (`mail.aiqadam.org` A/TXT, `webmail.aiqadam.org`, `autoconfig`/`autodiscover`/`mta-sts`/`ua-auto-config` CNAMEs, `_dmarc`, `_mta-sts`, `_smtp._tls`, `_ua-auto-config` TXTs, `mail._domainkey`/`resend._domainkey` TXTs, all 6 SRV records, `send.aiqadam.org` MX/TXT), and all 5 tunnel/GitHub-Pages CNAMEs — **confirmed byte-for-byte identical**: same record IDs, same content, same proxied/TTL/priority values. **Nothing in the MX/SPF/DKIM/DMARC/CAA/SRV/MTA-STS/autoconfig/autodiscover category moved.**
- New records found, categorized by `created_on` timestamp:
  1. **20 TLSA records**, all `created_on: 2026-07-19T06:22:3x–06:22:4x` (i.e., created during this attempt's own Phase 4a poll window) — `_25._tcp.mail.aiqadam.org`, `_443._tcp.mail.aiqadam.org`, `_443._tcp.autoconfig.aiqadam.org`, `_443._tcp.autodiscover.aiqadam.org`, `_443._tcp.mta-sts.aiqadam.org`, `_443._tcp.ua-auto-config.aiqadam.org`, `_465._tcp.mail.aiqadam.org`, `_993._tcp.mail.aiqadam.org`, `_995._tcp.mail.aiqadam.org` — 4 records each (matching the 4-certificate-hash TLSA convention). **Type TLSA exclusively, matching `publishRecords:{tlsa:true}`'s scope exactly.** Determination: this is the scoping mechanism working precisely as designed — the anticipated, permitted side effect of Stalwart's self-management, just larger in count (multiple hostnames/ports) than the plan's shorthand phrasing implied, not a scope violation in kind.
  2. **1 TXT record** `_acme-challenge.aiqadam.org`, `created_on: 2026-07-19T06:21:25` — the anticipated ACME DNS-01 ephemeral challenge record. Named at the apex (`_acme-challenge.aiqadam.org`) rather than `_acme-challenge.mail.aiqadam.org` as the plan's illustrative text guessed, but same self-managed, harmless mechanism explicitly anticipated as permissible.
  3. **2 A records NOT attributable to this attempt**: `qa.aiqadam.org` (`95.46.211.230`, comment `"pro-data-tech-qa (migrated from qa-uz)"`) and `auth.qa.aiqadam.org` (`95.46.211.230`, comment `"pro-data-tech-qa Authentik"`), both `created_on: 2026-07-18T04:40:1x/2x` — **the day before this run started**, hours before Stalwart's `dnsManagement` was ever set to `Automatic` (that happened at `2026-07-19T06:2x`). These cannot be a product of this attempt's mechanism. They also contradict the documented landscape: `landscape/cloudflare.md`'s T-0110 outcome states `qa.aiqadam.org` was deleted in favor of `qa-uz.aiqadam.org`, and `auth.qa.aiqadam.org` appears nowhere in any landscape file read this attempt.
- Record-count reconciliation: 33 (documented) + 20 (TLSA, this attempt) + 1 (`_acme-challenge`, this attempt) + 2 (`qa`/`auth.qa`, pre-existing, unrelated) = 56. Matches exactly.
- **Determination per the plan's literal, non-negotiable gate text** ("If ANYTHING beyond a plausible new `_acme-challenge...` TXT record differs... HALT IMMEDIATELY... do not proceed to Phase 5"): the `qa.aiqadam.org`/`auth.qa.aiqadam.org` records are differences beyond the two permitted categories. Despite this executor's own confidence (based on timestamps and record comments) that they are unrelated pre-existing drift from a different, legitimate workflow rather than evidence the `publishRecords` scoping failed, **the gate does not carve out an exception for "differences independently judged unrelated."** Halted here per instruction, did not proceed to Phase 5 or any subsequent phase.
- Result: **HALT triggered.**
- Backup taken: n/a

#### Rollback: revert `Domain` wiring to `Manual`/`Manual`
- Per plan rollback item 1 ("If Phase 4a's zone-diff checkpoint finds unexpected drift, this rollback is the first action to take... before investigating further") and this agent's standing instruction to run rollback for everything already applied before reporting `FAIL`/`BLOCKED`.
- Command: `apply --file /tmp/domain-rollback-patch.json --dry-run` then real apply, file content `{"@type":"upsert","object":"Domain","matchOn":["name"],"value":{"domain-b":{"name":"aiqadam.org","certificateManagement":{"@type":"Manual"},"dnsManagement":{"@type":"Manual"}}}}`
- Exit code: 0 (both). Output: `✓ upserted Domain (1)` / `Done: 0 destroyed, 1 updated, 0 created (0 failed)`.
- Verification: `get Domain b` → `Certificate Management: Manual TLS certificate management`, `DNS Management: Manual DNS management` — confirmed fully reverted, matching the pre-attempt baseline exactly.
- `AcmeProvider i9noabxeabab` re-checked post-rollback: still live, valid, `accountUri` still populated — unaffected by the `Domain`-level rollback (as the plan's rollback item 2 notes, this object does not need deleting for a routine wiring rollback).
- Result: rollback successful.

Phase 5 (DNS cutover), Phase 6 (mailbox provisioning), Phase 7 (nginx vhost), Phase 8 (verification/deliverability), and Phase 9 (backups) were **not attempted**. **No Cloudflare `PATCH`/`DELETE`/`POST` calls were made this attempt** — the only Cloudflare API call was the read-only `GET` zone dump in Phase 4a step 4b. The 20 TLSA records and 1 `_acme-challenge` record created by Stalwart's own scoped self-management during the ~2-minute window `dnsManagement` was `Automatic` were **not deleted** — per plan rollback item 8, they are self-managed, harmless, and require no rollback action; they remain live in the zone.

### Rollback executed
Yes — see "Rollback: revert `Domain` wiring to `Manual`/`Manual`" above. The `Domain` object's `certificateManagement` and `dnsManagement` fields were reverted to `Manual`/`Manual`, confirmed via `get Domain b`. No other rollback was needed: `AcmeProvider i9noabxeabab` required no change (per plan rollback item 2, only needed if abandoning ACME entirely); the 21 new Cloudflare records (20 TLSA + 1 `_acme-challenge`) required no rollback action (per plan rollback item 8); no DNS records from Phase 5 were touched (Phase 5 was never reached); no mailbox, nginx, or backup actions were taken (Phases 6-9 never reached).

### Resources changed
- **Files on host (`pro-data-tech-prod`):** transient patch files created and removed within this attempt: `/tmp/domain-dns-patch.json`, `/tmp/domain-cert-patch.json`, `/tmp/domain-rollback-patch.json` — all confirmed absent by end of attempt. No persistent host files changed.
- **Services restarted:** none. `stalwart-mail-server-1` was not restarted or recreated this attempt; remained `Up`/`healthy` throughout.
- **External resources changed:**
  - Cloudflare `aiqadam.org` zone: 20 new TLSA records + 1 new `_acme-challenge.aiqadam.org` TXT record created by Stalwart's own scoped self-management (not directly by this executor) during the ~2 minutes `dnsManagement` was `Automatic`; left in place per plan rollback guidance. **No records from the documented 33 were modified, deleted, or otherwise touched.** No `PATCH`/`DELETE`/`POST` calls were made by this executor against Cloudflare — the sole Cloudflare API call this executor made directly was the read-only zone-dump `GET` in Phase 4a.
  - No UFW changes. No GitHub API calls.
- **Server-side Stalwart objects modified:** `Domain b` — `dnsManagement` and `certificateManagement` were both set to `Automatic` (with scoped, verified-correct sub-settings), confirmed working end-to-end (real cert issued and serving), then both reverted to `Manual` per the rollback. Net effect at end of attempt: `Domain b` is in the identical state it was in at the start of this attempt. `AcmeProvider i9noabxeabab` unchanged (still live, correct, `accountUri` populated). `DkimSignature i9njnzd3krqa`, `NetworkListener i9njnzefksaa`, `DnsServer i9njy0ssaaqb` — all confirmed unchanged, not touched this attempt.
- **Secrets:** none new. Reused existing `stalwart-mail-admin-password` and `cloudflare-ai-qadam-api-token` (both from `credentials.md`) for CLI/API auth throughout. No secret values printed to any transcript or file in this repo.

### Mandatory no-regression checkpoints
**Start-of-attempt checkpoint:** Penpot 7/7 `Up` (7 days); AiQadam-prod 4/4 `Up` (10hr/10hr/5d/5d, matching the documented 4-container baseline); external `https://penpot.aiqadam.org` → 200; `https://aiqadam.org/health` → 200 `{"status":"ok",...}`.

**End-of-attempt checkpoint (post-rollback, post-halt):** Penpot 7/7 `Up` (unchanged); AiQadam-prod 4/4 `Up` (unchanged); Stalwart mail container `Up`/`healthy` (unchanged, just no longer holding DNS-write authority); external `https://penpot.aiqadam.org` → 200; `https://aiqadam.org/health` → 200. **No regression detected at any point in this attempt.**

## Issues / risks

- **RESOLVED — the `publishRecords:{"tlsa":true}` scoping recipe is now fully confirmed correct and safe end-to-end against the real host and the real shared zone.** `get Domain b` showed exactly `Records to Publish: TLSA records` both times it was checked (immediately after wiring, and after the second wiring step) — never silently reset to the dangerous 11-type default. The real-world side effect (20 TLSA records, all correctly typed, all for hostnames actually in this deployment's footprint) matches the scoping's intent exactly. This part of the investigation carried over from attempts 6/7 should be considered closed and should not need re-verifying in a future attempt.
- **RESOLVED — the `certificateManagement`→`dnsManagement` gate interaction (the original blocker from attempt 6) is now confirmed to work end-to-end against the real host.** No `ACME provider requires automatic DNS management` error recurred once `dnsManagement` was set to `Automatic` first. A real Let's Encrypt certificate was issued for `*.aiqadam.org` and confirmed serving on both 993 and 465 within roughly one minute of wiring.
- **NEW FINDING (this attempt) — Phase 4a's checkpoint caught genuine, material zone drift unrelated to this task.** `qa.aiqadam.org` and `auth.qa.aiqadam.org` (both A records → `95.46.211.230`, i.e. `pro-data-tech-qa`) exist in the live Cloudflare zone, created 2026-07-18 (the day before this run started), and are **not reflected in `landscape/cloudflare.md`**, which still documents `qa.aiqadam.org` as deleted (superseded by `qa-uz.aiqadam.org` per T-0110) and does not mention `auth.qa.aiqadam.org` at all. The records' own Cloudflare `comment` fields (`"pro-data-tech-qa (migrated from qa-uz)"`, `"pro-data-tech-qa Authentik"`) strongly suggest a legitimate, intentional change from separate QA/Authentik-related work, not sabotage or an error — but this executor did not investigate further (out of scope: no off-plan changes, no landscape edits). **This is a landscape-freshness gap that predates and is unrelated to T-0117**, surfaced only because Phase 4a's full-zone-diff checkpoint happened to run at this moment. Flagged as **needing fresh user input** on how to proceed (see Open questions).
- **No security or data-loss exposure from this halt.** `Domain b` ended the attempt in the identical `Manual`/`Manual` state it started in. The 21 new Cloudflare records (20 TLSA + 1 `_acme-challenge`) are additive, harmless, self-explanatory by name/type, and do not affect any existing service's resolution. No mail traffic is live; zero external DNS points at the new mail host yet (Phase 5 never reached, in any attempt across this run's 7-attempt history).
- **No regression to Penpot or AiQadam-prod at any point** — confirmed via start-of-attempt and end-of-attempt checkpoints, both identical.
- **Observation, off-plan, not actioned (carried over from prior attempts, still out of scope):** AiQadam-prod's Compose project composition (`aiqadam-prod-web-next-1` present) — already a documented, accepted deviation, not re-investigated this attempt.

## Open questions (optional)

- **Primary routing question for the orchestrator/user:** how should the `qa.aiqadam.org`/`auth.qa.aiqadam.org` drift be handled before any attempt 8 proceeds to Phase 5? Two paths, neither decidable by this executor unilaterally:
  1. **Treat as confirmed-benign, update the Phase 4a baseline.** The record comments are self-explanatory and consistent with legitimate QA/Authentik work; if the user confirms this is expected (e.g., they know of separate work on `pro-data-tech-qa` from 2026-07-18), the fix is simply to refresh `landscape/cloudflare.md`'s snapshot to include these two records before re-running Phase 4a, so the next attempt's diff has an accurate baseline and doesn't re-trigger on the same, now-understood difference.
  2. **Investigate first.** If the user is not aware of this change, it deserves its own look (was it made through this repo's own workflow via a different run and never landed in landscape/cloudflare.md, or by someone/something outside this repo's control?) before trusting the zone's current state as a diff baseline for anything as consequential as Phase 5's MX/SPF cutover.
- **Note for whichever path is chosen:** this is explicitly the kind of situation Phase 4a's gate was designed to surface and stop on rather than have this executor adjudicate — the plan's approval (step-05) explicitly says "if it ever fires (finds unexpected drift), that is explicitly NOT a routine retry situation and must come back to the user, not be resolved by another same-character design correction."
- **For attempt 8 (if/when authorized):** resume directly from live state — `AcmeProvider i9noabxeabab` still correct and does not need recreating; `Domain b` is back to `Manual`/`Manual` and the exact same two-step wiring (already twice-confirmed working) can be re-applied once the drift question above is resolved; the 20 TLSA + 1 `_acme-challenge` records already in the zone can be left as-is (they'll likely be recreated or left untouched next time `dnsManagement` goes `Automatic` again) or cleaned up first at the user's discretion — neither blocks re-wiring. Phase 5 onward remains entirely unexecuted across all 7 attempts of this run to date.
- **New reusable technique from this attempt:** `stalwart-cli apply --file` expects each plan-file object to be an `{"@type":"upsert"|"create"|"update"|"destroy","object":"<Type>","matchOn":[...],"value":{...}}` envelope (NDJSON, one such envelope per line for multi-object plans), NOT the bare `{"update":{"Type":{"id":{...}}}}` shape shown in the plan's illustrative pseudocode (that shape produces `error: invalid plan NDJSON on line 1: missing field @type`). `stalwart-cli snapshot <Type> --allow-unresolved <ReferencedTypes>` is the reliable way to discover the exact expected envelope shape for any object type — used successfully here to unblock Phase 4 step 1. Worth documenting at step 08 as a Stalwart CLI usage gotcha, alongside the already-known `AcmeProvider.contact`/`publishRecords` map-vs-array quirk.
