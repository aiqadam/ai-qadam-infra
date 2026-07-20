---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-07-19T09:00:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-05
inputs_read:
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
artifacts_changed: []
next_step_hint: proceed to step 06 (executor-infra), attempt 7, resuming from the live state left by attempt 6 (Domain/DkimSignature/NetworkListener/DnsServer/AcmeProvider already live on pro-data-tech-prod). The new Phase 4a zone-diff safety checkpoint is mandatory and must run before Phase 5.
---

## Summary
Orchestrator approved attempt 7's plan, which directly implements the user's explicit choice from the prior check-in ("scope it down first"): a confirmed, safe way to enable Stalwart's automatic TLS renewal without granting it broad auto-publish rights over the shared Cloudflare zone's mail DNS records.

## Details
Following the user's decision to investigate scoping before proceeding, a second isolated scratch-container investigation (fake credentials, no real DNS ever touched) confirmed: `Domain.dnsManagement.publishRecords` can be restricted to a single harmless, unused record type (`{"tlsa": true}`) rather than the dangerous 11-type default (MX/SPF/DKIM/DMARC/CAA/SRV/MTA-STS/autoconfig/autodiscover all auto-true). Critically, the ACME DNS-01 challenge record itself was confirmed — via both live schema inspection and Stalwart's own official documentation — to be a completely separate mechanism, NOT gated by `publishRecords` at all. This directly resolves the concern that prompted the check-in: Stalwart's own certificate renewal works regardless of `publishRecords`'s scope, so scoping it down costs nothing functionally while keeping every consequential DNS record type under Phase 5's existing manual, human-approved control.

**Approved fix:** wire `Domain.dnsManagement` to `Automatic` with `publishRecords: {"tlsa": true}` only, then wire `Domain.certificateManagement` to `Automatic` referencing the already-live `AcmeProvider`.

**Approved mandatory safety checkpoint (Phase 4a), the condition that makes this approvable within standing delegation:** because the `certificateManagement`→`dnsManagement` interaction was not independently re-triggered end-to-end in the scratch investigation (Let's Encrypt staging rejected the scratch environment's test registration before reaching that gate), this production attempt is the first true end-to-end test. Before any of Phase 5's own deliberate DNS cutover work, the plan requires: a bounded wait for ACME issuance, then a full live Cloudflare zone dump (all 33 records) diffed against the documented pre-run snapshot. If anything beyond a plausible new `_acme-challenge.mail.aiqadam.org` TXT record differs — i.e., if any MX/SPF/DKIM/DMARC/CAA/SRV/MTA-STS/autoconfig/autodiscover record has changed — the plan requires an immediate halt and fresh report, not improvisation or a "fix it and continue" response.

All decisions and state from attempts 1-6 remain unchanged and are not reopened. `AcmeProvider i9noabxeabab` (already live with a registered Let's Encrypt account) does not need recreating.

## Issues / risks
This is the first point in the run where software other than the executor itself gets standing write capability toward the shared Cloudflare zone. The Phase 4a checkpoint is the safeguard; if it ever fires (finds unexpected drift), that is explicitly NOT a routine retry situation and must come back to the user, not be resolved by another same-character design correction.

## Open questions
None.
