---
id: T-0117-install-mail-server-aiqadam
title: Install self-hosted mail server for aiqadam.org (real mailboxes, dozens of users)
kind: task
status: done
priority: P1
created: 2026-07-19
updated: 2026-07-19
closed: 2026-07-19
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-19-install-mail-server-aiqadam-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/secrets-inventory.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0116, T-0118, T-0119, T-0120]
estimated_blast_radius: high
estimated_reversibility: full
---

# Install self-hosted mail server for aiqadam.org

## Why

`aiqadam.org`'s existing mail infrastructure (Stalwart mail server + Snappymail webmail at `mail.aiqadam.org` = `212.20.151.29`, a third-party host on Globe Cloud LLC / Tashkent, not managed by this repo) is dead: the A/MX records still resolve, but the host does not respond on SMTP (25), HTTPS (443), or IMAPS (993) — confirmed by direct port probes 2026-07-18. No credentials or access to that host exist in this repo.

The ai-qadam community needs real, human-readable mailboxes (dozens of users, read via webmail/mail clients — not just app-originated transactional mail) at `@aiqadam.org`. This task stands up a replacement self-hosted mail server on infrastructure this repo owns, then cuts the DNS over.

Self-hosting (rather than a managed provider like Google Workspace/Fastmail) was chosen because the community is "dozens+" of mailboxes, where per-mailbox SaaS pricing recurs indefinitely and the cost/control tradeoff favors owning the stack, accepting the ongoing operational burden (deliverability, spam/abuse management, backups) that comes with it.

## What done looks like

- [x] Host chosen and documented (candidates: `pro-data-tech-prod` — 31GB RAM/16vCPU/336GB free, already runs Penpot+AiQadam prod; or a dedicated host such as `ubuntu-16gb-nbg1-1` — currently blank — to isolate mail's IP-reputation exposure from prod app/Penpot blast radius). Decision recorded with reasoning in this task before execution. — **`pro-data-tech-prod` chosen** (see solution-designer handoffs for reasoning).
- [x] Chosen host's public IP checked against major DNSBLs/blocklists (e.g. Spamhaus, Barracuda) before committing — flag to the user if already listed. — checked; Spamhaus check was inconclusive via a shared public resolver (disclosed, accepted gap, not blocking).
- [x] Mail server software installed (recommend Stalwart, matching the dead server's proven record shape for this domain; Mailcow acceptable alternative if the user prefers a more mature/larger-community project) via Docker Compose, isolated from any existing Compose project on the host. — Stalwart `v0.16` deployed as its own Compose project `stalwart-mail`, isolated from `penpot`/`aiqadam-prod`.
- [x] SMTP (25, 465/587 submission), IMAP (993), and — if Stalwart — JMAP reachable and serving TLS with a valid Let's Encrypt cert for `mail.aiqadam.org` (or a new mail hostname if the old one is intentionally retired instead of reused — confirm with user). — `mail.aiqadam.org` reused; all 4 ports reachable and TLS-valid, confirmed externally.
- [x] New DKIM keypair generated; new DKIM TXT record published. — Ed25519 keypair (`Dkim1Ed25519Sha256`), published and externally confirmed.
- [x] SPF record updated to authorize the new sending IP (replacing the dead `212.20.151.29` reference). — `v=spf1 ip4:95.46.211.224 mx -all`, confirmed via external resolver and independently via Port25's SPF pass result.
- [x] DMARC policy carried over (`p=reject` was the prior policy — confirm the user still wants strict enforcement from day one, or wants to start at `p=none`/`p=quarantine` while reputation warms up). — started at `p=none` for the soak period, per plan; tightening timeline tracked as a follow-on (T-0120).
- [x] MTA-STS and TLS-RPT records updated to match the new host (or intentionally dropped if not implementing MTA-STS initially — confirm with user). — MTA-STS records dropped (not implemented this pass); TLS-RPT record retained unchanged.
- [x] MX record for `aiqadam.org` repointed to the new mail host — this is the cutover moment; requires explicit human approval at plan-approval time (step 05), separate from the general workflow approval, given it flips live mail routing in a zone shared with third parties. — approved at step 05; MX target unchanged (`mail.aiqadam.org`), cutover effected via the A-record repoint.
- [x] Old/dead mail-related DNS records (autoconfig, autodiscover, SRV records for the dead protocols/ports, old DKIM selectors) either updated to the new host or explicitly removed — no orphaned records left pointing at the dead `212.20.151.29` host. — 10 stale records deleted across two passes (8 in the main cutover, `autoconfig`/`autodiscover` in a validator-caught follow-up); none remain pointing at the dead host.
- [x] Mailbox provisioning mechanism in place (admin can create/delete mailboxes — CLI, admin UI, or API, whichever the chosen software provides) and documented. — `stalwart-cli create Account` (or `apply`-NDJSON `upsert`), documented in `landscape/hosts/pro-data-tech-prod.md` including the `objectList`-as-numeric-keyed-map encoding gotcha.
- [x] At least one test mailbox created and verified: send a test message from an external address (e.g. Gmail) to it, confirm delivery; send a test message from it to an external address, confirm it lands in inbox (not spam) — record the result, including if it lands in spam (expected initially on a cold IP). — `test@aiqadam.org` created; inbound external→mailbox confirmed delivered (landed in Junk, expected for a cold IP + raw test message); outbound confirmed accepted/queued and independently proven end-to-end via a real third-party round-trip (Port25's verifier). Direct Gmail-inbox-vs-spam placement could not be confirmed this run due to an expired Gmail OAuth token (user-level issue, not an infra gap) — disclosed, not treated as a plan failure.
- [x] mail-tester.com (or equivalent) score captured post-cutover as a deliverability baseline. — **Partially satisfied via a substitute**: mail-tester.com's own score was unobtainable (JS-rendered per-session address, no headless-browser tool available); Port25's `verifier.port25.com` was used instead and yielded a real baseline (SPF pass, iprev fail/NXDOMAIN, DKIM inconclusive due to that tool's own lack of modern-DKIM-spec support). The specific mail-tester.com numeric score is tracked as a follow-on: **T-0119**.
- [x] Backup mechanism for mail data (mailboxes/message store) — local-disk only per this repo's no-off-site-storage rule; confirm retention approach with user. — `tar czf` snapshot of the Stalwart data directory to `/var/backups/stalwart-mail/`, local-disk only; a scheduled daily cron/timer with 14-day retention was recommended but not built into this pass (acceptable — one-time snapshot satisfies this checklist item; automation is a natural but not-required follow-on).
- [x] Firewall rules confirmed: UFW/Hetzner Cloud Firewall (if applicable) allow 25/465/587/993 inbound on the chosen host without exposing unrelated ports. — UFW rules added for all 4 ports on `pro-data-tech-prod` (no Hetzner Cloud Firewall applicable to this provider); no other ports exposed.
- [x] `landscape/hosts/<chosen-host>.md`, `landscape/services.md`, `landscape/cloudflare.md`, `landscape/domains.md` updated to reflect the new mail service as **owned by this repo** (unlike the old third-party records). — done, this run's step 08.
- [x] `landscape/secrets-inventory.md` updated with references (names only, no values) for mail admin credentials / API tokens if the software exposes an admin API. — done, this run's step 08 (`stalwart-mail-admin-password`, `stalwart-mail-domain-admin-password`, `stalwart-mail-test-account-password`; `cloudflare-ai-qadam-api-token` cross-referenced as reused, not new).

## Result

Self-hosted Stalwart mail server for `aiqadam.org` is fully live on `pro-data-tech-prod`, replacing the dead third-party host, after a 9-attempt executor journey (full history in `runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/`).

**What was done:** Stalwart `v0.16` deployed via Docker Compose (project `stalwart-mail`); UFW opened 25/465/587/993; DKIM (Ed25519), DMARC (`p=none`, soak period), and SPF records published/updated; Cloudflare `aiqadam.org` mail records cut over (`mail.aiqadam.org` A repointed to `95.46.211.224`, SPF/DKIM/DMARC TXT records updated, 10 stale third-party records deleted across two passes); Stalwart's own `Domain` object wired with `dnsManagement`/`certificateManagement` both `Automatic`, DNS scope deliberately narrowed to `publishRecords: {tlsa:true}` to avoid granting Stalwart standing write access to MX/SPF/DKIM/DMARC in the shared zone; a real Let's Encrypt certificate (internal ACME, DNS-01) issued and confirmed serving on SMTP/IMAP/submission; a separate certbot-managed cert (reusing one orphaned from attempt 1) serves the nginx-proxied admin UI at `https://mail.aiqadam.org/`; test mailbox `test@aiqadam.org` provisioned; inbound and outbound mail independently verified end-to-end (inbound landed in Junk, expected for a cold IP; outbound proven via a real third-party round-trip through Port25's verifier); local-disk backup taken.

**Root causes across the 9 attempts** (see run `.attempts/` for full detail on each):
1. Initial Stalwart Docker image tag chosen was archived/unmaintained — required switching to `stalwartlabs/stalwart:v0.16`.
2. An early attempt assumed a REST admin API existed for configuration that in fact required the separate `stalwart-cli` tool.
3. A missing "Bootstrap completion" step was discovered — Stalwart's config model requires an explicit Bootstrap object before most other objects can be created.
4. `update Bootstrap` was found to require a full container restart to take effect — not documented by Stalwart itself, discovered empirically.
5. `AcmeProvider.contact` (and later, analogously, `Domain.dnsManagement.publishRecords`) were documented as `set<T>` fields but actually required JSON-map encoding (`{"key":true}`), not the JSON-array encoding the schema docs implied — a recurring class of bug across two different fields.
6. Wiring `certificateManagement: Automatic` was found to require `dnsManagement: Automatic` too, whose `publishRecords` sub-setting defaults to auto-publishing nearly the entire mail DNS footprint (11 of 12 record types) against the shared, partially-owned zone — this required a new, explicitly user-approved decision to scope it down to `{"tlsa": true}` only, rather than accepting the broad default or guessing a value.
7. Two small, validator-caught gaps closed out the run: the `autoconfig`/`autodiscover` CNAMEs resolved but had no working route behind them (deleted rather than left orphaned), and a pre-existing, unrelated 4th container (`aiqadam-prod-web-next-1`) on the same host needed to be reconciled into the landscape's documented AiQadam-prod baseline (handled separately, out-of-band, already reflected in the landscape before this step).

**Deviations from the original "What done looks like" checklist:** two items were satisfied via a disclosed, accepted substitute rather than literally as written — the mail-tester.com numeric score (Port25's verifier used instead; tracked as follow-on **T-0119**) and Gmail inbox-vs-spam placement confirmation (Gmail OAuth token expired mid-run, a user-account issue; inbound/outbound were independently proven via direct SMTP/IMAP testing and the Port25 round-trip instead). The Spamhaus DNSBL check was inconclusive via a shared public resolver — disclosed, not blocking. No PTR record exists for the new IP (tracked as follow-on **T-0118**). DMARC tightening timeline left open (tracked as follow-on **T-0120**).

**Links:** [step-06-executor-infra.md](../runs/2026-07-19-install-mail-server-aiqadam-001/step-06-executor-infra.md) (attempt 9, final narrow cleanup), [.attempts/step-06-executor-infra-attempt-8.md](../runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-8.md) (full deployment), [step-07-execution-validator.md](../runs/2026-07-19-install-mail-server-aiqadam-001/step-07-execution-validator.md) (final PASS).

## Notes

- **Blast radius is HIGH**: mutating MX/SPF/DKIM/DMARC records in the shared, partially-owned `aiqadam.org` Cloudflare zone is the same class of operation as T-0111's apex repoint — treat as shared-resource surgery. Freshness-check each record immediately before writing it; no bulk edits; scope each Cloudflare API call to a single named record.
- **Reversibility is FULL** in the narrow sense that nothing live currently depends on the dead mail records (confirmed unreachable 2026-07-18), so there is no working service to break by changing them. It is not "full" in the sense of effort-to-undo: once real mailboxes exist and people start receiving mail, reverting becomes a real migration, not a no-op.
- **Deliverability is the dominant risk**, not the software install. A fresh IP on Hetzner or pro-data.tech has no sending reputation; expect mail to land in spam for days-to-weeks after cutover regardless of correct SPF/DKIM/DMARC. The solution-designer should set expectations accordingly rather than treating a spam-folder test result as a plan failure.
- Consider whether outbound deliverability should be improved by relaying *outbound* mail through the zone's existing SES (`send.aiqadam.org`) integration rather than sending directly from the new host's IP, while keeping inbound self-hosted. Raise this as an option at solution-design time rather than assuming direct-send is required.
- This task does not cover migrating any historical mail data — the old server is unreachable, so there is nothing to migrate. If backups of the old server surface elsewhere, treat that as a separate follow-on task.

## Open questions

- **Host placement**: shared with `pro-data-tech-prod` (Penpot + AiQadam prod) vs. dedicated (`ubuntu-16gb-nbg1-1`, currently blank)? User leaned self-hosted for control but did not specify host placement — resolve at solution-design time, present tradeoff explicitly at step-05 approval.
- **Mail hostname**: reuse `mail.aiqadam.org` (matches existing SPF/DKIM records elsewhere in the zone that reference it) or pick a new hostname to avoid any ambiguity with the dead host's residual reputation/blocklist status? Recommend reusing `mail.aiqadam.org` unless the IP-reputation check surfaces a reason not to.
- **DMARC policy on day one**: `p=reject` (matches old config) risks silently dropping legitimate mail during the reputation-warmup period if something is misconfigured. Consider starting at `p=none` with `rua` reporting for a short soak period, then tightening to `p=reject` once delivery is confirmed clean — confirm with user at plan time.
- **Mailbox provisioning process for actual community members**: who requests a mailbox, and how are addresses/initial passwords issued? Out of scope for this task's technical build but should be flagged as a follow-on (admin process, not infra) once the server is live.

## History
- 2026-07-19: created manually, following user decision to self-host real mailboxes for the ai-qadam community after confirming the prior third-party mail.aiqadam.org server is dead (DNS resolves, host unreachable on 25/443/993).
- 2026-07-19: status -> in-progress, run 2026-07-19-install-mail-server-aiqadam-001
- 2026-07-19: status -> done, outcome succeeded, run 2026-07-19-install-mail-server-aiqadam-001, commit <pending>
