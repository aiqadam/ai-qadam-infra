---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-19T00:00:00Z
task_id: T-0117-install-mail-server-aiqadam
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
artifacts_changed: []
next_step_hint: step-02-landscape-reader should load landscape/hosts/pro-data-tech-prod.md, landscape/hosts/ubuntu-16gb-nbg1-1.md (or equivalent), landscape/services.md, landscape/cloudflare.md, landscape/domains.md, and landscape/secrets-inventory.md
---

## Summary
Install and cut over a new self-hosted mail server (real mailboxes, dozens of users) for `aiqadam.org`, replacing the dead third-party `mail.aiqadam.org` server, on infrastructure this repo owns — covering host selection, mail software install, TLS, DKIM/SPF/DMARC/MTA-STS DNS records, MX cutover, mailbox provisioning, deliverability testing, backups, firewall rules, and landscape documentation.

## Details
- **Workflow:** infrastructure
- **Target scope:**
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md)
  - landscape/hosts/ubuntu-16gb-nbg1-1.md (candidate alternate host — confirm exact filename at step 02)
  - [landscape/services.md](../../landscape/services.md)
  - [landscape/cloudflare.md](../../landscape/cloudflare.md)
  - [landscape/domains.md](../../landscape/domains.md)
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md)
- **Constraints stated by user:**
  - Real, human-readable mailboxes for dozens of community users (not just app-originated transactional mail), read via webmail/mail clients.
  - Must be self-hosted (not a managed provider like Google Workspace/Fastmail) — deliberate cost/control tradeoff, accepting ongoing operational burden.
  - Host must be infrastructure this repo owns/manages (the dead third-party host at `212.20.151.29` is out of scope, unreachable, no credentials exist for it).
  - Host choice is a decision to make and document with reasoning before execution — candidates are `pro-data-tech-prod` (shared with Penpot + AiQadam prod) or `ubuntu-16gb-nbg1-1` (currently blank, isolates IP-reputation exposure). Present the tradeoff explicitly at step-05 approval.
  - Chosen host's public IP must be checked against major DNSBLs/blocklists before committing; flag to user if already listed.
  - Recommended software: Stalwart (matches dead server's record shape); Mailcow acceptable alternative if user prefers. Must run via Docker Compose, isolated from any existing Compose project on the host.
  - SMTP (25, 465/587), IMAP (993), and JMAP (if Stalwart) must be reachable with valid Let's Encrypt TLS for `mail.aiqadam.org` or a new hostname (confirm with user if changing).
  - New DKIM keypair + TXT record; SPF updated to authorize new sending IP; DMARC policy carried over but day-one enforcement level (`p=reject` vs `p=none`/`p=quarantine`) needs user confirmation.
  - MTA-STS/TLS-RPT records updated or explicitly dropped (confirm with user).
  - **MX repoint is the cutover moment and requires explicit separate human approval at step 05**, distinct from general workflow approval — flips live mail routing in a zone shared with third parties.
  - No orphaned DNS records left pointing at the dead `212.20.151.29` host (autoconfig/autodiscover/SRV/old DKIM selectors) — either updated or removed.
  - Mailbox provisioning mechanism (CLI/admin UI/API) must be in place and documented.
  - At least one test mailbox created; inbound and outbound delivery tested against an external address (e.g. Gmail); result recorded even if it lands in spam (expected on a cold IP — not a plan failure).
  - mail-tester.com (or equivalent) score captured post-cutover as deliverability baseline.
  - Backups: local-disk only, per this repo's no-off-site-storage rule; retention approach to be confirmed with user.
  - Firewall (UFW/Hetzner Cloud Firewall) must allow only 25/465/587/993 inbound on the chosen host, no unrelated ports exposed.
  - `landscape/hosts/<chosen-host>.md`, `landscape/services.md`, `landscape/cloudflare.md`, `landscape/domains.md` must be updated to record the new mail service as repo-owned.
  - `landscape/secrets-inventory.md` updated with credential/API-token references (names only, no values) if the software exposes an admin API.
  - Consider relaying outbound mail through the zone's existing SES (`send.aiqadam.org`) integration while keeping inbound self-hosted — raise as an option at solution-design time, not an assumption.
  - This task excludes migrating historical mail data (old server unreachable, nothing to migrate).
  - Freshness-check each DNS record immediately before writing it; no bulk edits; scope each Cloudflare API call to a single named record (per Notes, same class of operation as T-0111's apex repoint).
- **Information gaps for downstream steps:**
  - Final host placement decision (pro-data-tech-prod vs. ubuntu-16gb-nbg1-1) — open question, to be resolved at solution-design time (step 04) and confirmed at approval (step 05).
  - Whether `mail.aiqadam.org` hostname is reused or replaced — recommendation is reuse, pending IP-reputation check outcome.
  - DMARC day-one policy (`p=none`/`p=quarantine` soak period vs. immediate `p=reject`) — needs explicit user confirmation at plan time.
  - Whether MTA-STS/TLS-RPT is implemented in this pass or explicitly deferred.
  - Whether outbound relay via existing SES integration (`send.aiqadam.org`) is adopted instead of/alongside direct-send from the new host's IP.
  - Backup retention policy for mail data (local-disk only).
  - Mailbox provisioning process for actual community members (who requests a mailbox, how addresses/passwords are issued) is explicitly out of scope for this task's technical build — flag as a follow-on admin-process task once the server is live, not something to resolve here.
  - Related task T-0116 (per `related:` field) — its relevance to this task's Redis or other findings should be checked by landscape-reader/task-validator.

## Issues / risks
- Estimated blast radius is HIGH: mutating MX/SPF/DKIM/DMARC in the shared, partially-owned `aiqadam.org` Cloudflare zone risks affecting other parties' records if not scoped precisely.
- Reversibility is FULL only in the narrow technical sense (no live service currently depends on the dead records); once real mailboxes are in use, reverting becomes a real migration, not a no-op — downstream steps should not treat "full reversibility" as low-stakes.
- Deliverability (cold IP reputation) is the dominant risk, not the software installation itself — solution-designer and validator should not treat an initial spam-folder landing as a failure condition.
- MX repoint step carries a distinct, separate approval gate at step 05 beyond the general workflow approval — orchestrator and step-05 agent must not conflate the two.

## Open questions (optional)
none — task is well-formed and unblocked; open questions listed above are for step 04 (solution-designer) and step 05 (approval) to resolve, per the task file's own "Open questions" section, not blockers to starting this run.
