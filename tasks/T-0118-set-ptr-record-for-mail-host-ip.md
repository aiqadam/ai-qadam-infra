---
id: T-0118-set-ptr-record-for-mail-host-ip
title: Set a PTR (reverse-DNS) record for 95.46.211.224 (mail server IP)
kind: observation
status: observation
priority: P2
created: 2026-07-19
updated: 2026-07-19
closed:
outcome:
created_by: 2026-07-19-install-mail-server-aiqadam-001
source_runs: [2026-07-19-install-mail-server-aiqadam-001]
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-prod.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0117]
estimated_blast_radius: low
estimated_reversibility: full
---

# Set a PTR (reverse-DNS) record for 95.46.211.224 (mail server IP)

## Why

During T-0117's Phase 8 deliverability testing, Port25 Solutions' independent SMTP authentication-verifier (`verifier.port25.com`) was used as a substitute for mail-tester.com (which could not be reached — see T-0119). Quoted from the T-0117 executor's handoff (`runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-8.md`):

> "iprev (reverse DNS) check: fail — reverse lookup failed (NXDOMAIN) for 224.211.46.95.in-addr.arpa. No PTR record exists for 95.46.211.224. This is a genuine, newly-surfaced deliverability gap — not addressed by this task's plan (PTR records are typically set via the hosting provider's control panel, not DNS-zone-side)."

This is a real, standard deliverability signal that most receiving mail servers check as part of SPF/DKIM/DMARC-adjacent anti-spoofing heuristics. It was out of scope for T-0117's plan (PTR records are provider-side, not Cloudflare-zone-side) but is directly relevant to the "deliverability is the dominant risk" theme T-0117's own Notes anticipated for a cold-IP mail server.

## What done looks like

- [ ] Confirm whether pro-data.tech's control panel/API exposes a way to set a PTR record for `95.46.211.224`
- [ ] If yes, set the PTR record to `mail.aiqadam.org` (matching the forward A record, the conventional FCrDNS pattern)
- [ ] Re-run Port25's `verifier.port25.com` iprev check (or equivalent) and confirm it now passes
- [ ] Document the PTR record and its management mechanism in `landscape/hosts/pro-data-tech-prod.md`
- [ ] If pro-data.tech does NOT expose PTR management, document that limitation clearly instead, and consider whether it changes the deliverability risk assessment for this mail deployment

## Result
<empty until closed; then: what actually happened, outcome, links to executing run(s) and commits, any deviations from the plan>

## Notes
- Low blast radius, full reversibility — this is an additive, provider-side DNS record; nothing existing is modified.
- Priority set to P2 (default) — a real deliverability lever, not a blocker, since T-0117 already closed with disclosed, accepted gaps around cold-IP reputation warmup.
- Ties into T-0120 (DMARC tightening) — both are part of the same deliverability-hardening arc anticipated by T-0117's own Notes.

## History
- 2026-07-19: created from 2026-07-19-install-mail-server-aiqadam-001 (landscape-updater, step 08), based on Port25's iprev NXDOMAIN finding during T-0117 Phase 8 testing.
