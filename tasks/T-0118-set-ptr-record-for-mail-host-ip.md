---
id: T-0118-set-ptr-record-for-mail-host-ip
title: Set a PTR (reverse-DNS) record for 95.46.211.224 (mail server IP)
kind: task
status: pending
priority: P1
created: 2026-07-19
updated: 2026-07-20
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

- [ ] Check pro-data.tech's hosting control panel for a PTR / reverse-DNS management option for `95.46.211.224` (this is typically not exposed as Cloudflare-zone-side DNS — it's a provider-side VPS setting, so the Cloudflare dashboard is not the place to look)
- [ ] If the control panel has no self-service PTR option, open a support ticket/channel with pro-data.tech requesting the PTR record be set — most VPS providers handle this as a manual support request rather than a self-service UI
- [ ] Once set, confirm the PTR record resolves `95.46.211.224` → `mail.aiqadam.org` (matching the forward A record — the conventional FCrDNS pattern that receiving mail servers check)
- [ ] Re-run Port25's `verifier.port25.com` iprev check (or equivalent, e.g. `dig -x 95.46.211.224`) and confirm the reverse lookup now succeeds and matches
- [ ] Document the PTR record and its management mechanism (control panel path or support channel used) in [landscape/hosts/pro-data-tech-prod.md](../landscape/hosts/pro-data-tech-prod.md)
- [ ] If pro-data.tech does NOT offer PTR management at all (neither self-service nor via support), document that limitation clearly instead, and flag it back for a re-assessment of this mail deployment's deliverability risk

## Result
<empty until closed; then: what actually happened, outcome, links to executing run(s) and commits, any deviations from the plan>

## Notes
- Low blast radius, full reversibility — this is an additive, provider-side DNS record; nothing existing is modified.
- Priority raised to P1 on promotion — a real, disclosed deliverability gap for a mail server currently in its cold-IP reputation-warmup period. Not a blocker (T-0117 already closed with this gap disclosed and accepted), but worth doing in the current planning horizon rather than left indefinitely deferred at P2.
- Ties into T-0120 (DMARC tightening) — both are part of the same deliverability-hardening arc anticipated by T-0117's own Notes.
- Likely requires a human to interact with pro-data.tech's control panel/support channel directly (not self-service via Cloudflare or typical VPS web UI) — flagged explicitly in the acceptance criteria.

## History
- 2026-07-19: created from 2026-07-19-install-mail-server-aiqadam-001 (landscape-updater, step 08), based on Port25's iprev NXDOMAIN finding during T-0117 Phase 8 testing.
- 2026-07-20: promoted observation -> task, priority P1, by user. Acceptance criteria refined to call out the pro-data.tech control panel/support-channel check explicitly (PTR management is provider-side, not self-service via Cloudflare).
