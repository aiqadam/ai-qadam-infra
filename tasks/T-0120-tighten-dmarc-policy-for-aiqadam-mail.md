---
id: T-0120-tighten-dmarc-policy-for-aiqadam-mail
title: Revisit and tighten aiqadam.org DMARC policy after the mail server soak period
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
  - landscape/cloudflare.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0117]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Revisit and tighten aiqadam.org DMARC policy after the mail server soak period

## Why

T-0117 deliberately set `_dmarc.aiqadam.org` to `p=none` (down from the prior third-party host's `p=reject`) as a soak-period decision, to avoid silently dropping legitimate mail while the new self-hosted Stalwart server's IP reputation warms up on a cold IP. Quoted from the T-0117 solution-designer's plan and carried through to execution: DMARC PATCHed to `v=DMARC1; p=none; rua=mailto:postmaster@aiqadam.org`, confirmed live via external DNS lookup.

The T-0117 executor's own open questions flagged this explicitly (`runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-8.md`):

> "DMARC tightening timeline: per the approved plan, _dmarc.aiqadam.org is now p=none (soak period, matching the plan's decision). No specific date was set for tightening to p=quarantine/p=reject — worth the user deciding a follow-up checkpoint once delivery is confirmed clean (ties into the mail-tester.com / PTR follow-ons above)."

No date or delivery-confirmation trigger was set for revisiting this. Leaving DMARC at `p=none` indefinitely provides only monitoring (via the `rua` reports), not actual anti-spoofing protection for the domain.

## What done looks like

- [ ] User (or a scheduled follow-up) decides a concrete trigger/timeline for revisiting DMARC policy — e.g. "N days after cutover" or "once mail-tester.com score and PTR record are both clean" (ties into T-0118, T-0119)
- [ ] Review `rua` aggregate reports received at `postmaster@aiqadam.org` during the soak period for any legitimate-mail failures
- [ ] If clean, tighten `_dmarc.aiqadam.org` to `p=quarantine` first, confirm no legitimate mail is affected, then `p=reject` to match the original third-party host's policy
- [ ] Update `landscape/cloudflare.md`'s mail-records table to reflect the new policy and the date of the change

## Result
<empty until closed; then: what actually happened, outcome, links to executing run(s) and commits, any deviations from the plan>

## Notes
- Medium blast radius (a stricter DMARC policy can cause legitimate mail to be quarantined/rejected if SPF/DKIM alignment isn't perfect for every sending path) but full reversibility (a single TXT record PATCH, freshness-checked like every other T-0117 DNS change).
- Priority set to P2 (default) — not urgent, but shouldn't be forgotten indefinitely; re-prioritize on promotion if the user wants a hard deadline.
- Natural sequencing: revisit this after T-0118 (PTR) and T-0119 (mail-tester score) give a clearer deliverability picture, though it doesn't strictly depend on either.

## History
- 2026-07-19: created from 2026-07-19-install-mail-server-aiqadam-001 (landscape-updater, step 08), based on the executor's own flagged open question about DMARC tightening timeline.
