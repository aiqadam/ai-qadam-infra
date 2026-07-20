---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-07-19T04:20:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-05
inputs_read:
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
artifacts_changed: []
next_step_hint: proceed to step 06 (executor-infra), attempt 2, with the corrected plan exactly as approved — no changes requested.
---

## Summary
User reviewed the corrected (retry) plan from step 04 attempt 2 and approved it as-is. This is the second approval pass for this run: attempt 1 was approved and executed but failed at the Docker image-pull stage (`stalwartlabs/mail-server:latest` archived); the executor rolled back cleanly; step 04 was re-run with corrected Stalwart v0.16 deployment mechanics; this approval covers that correction.

## Details
The orchestrator presented the three genuinely new decisions introduced by the correction (none of which were part of attempt 1's approval, since attempt 1 never reached this part of the plan):

1. **TLS for the mail server switches to Stalwart's internal ACME (DNS-01, via the existing `cloudflare-ai-qadam-api-token`)** instead of externally-managed certbot — because the corrected image's volume layout (`/etc/stalwart` + `/var/lib/stalwart`, UID 2000) makes the certbot-mount pattern from attempt 1 a second instance of the same class of bug that just failed. Result: `mail.aiqadam.org` ends up with two independently-managed TLS certs on the same host for two different purposes (nginx/certbot for the admin UI on 443; Stalwart's own internal ACME cert for SMTP/IMAP/submission on 465/587/993) — not a conflict, but a new pattern.
2. **The orphaned Let's Encrypt cert left behind by attempt 1's failed run is reused** for the nginx-proxied admin UI specifically, rather than left unused or deleted.
3. **Port 587 (STARTTLS submission) is explicitly enabled**, since Stalwart v0.16 does not turn it on by default (only implicit-TLS 465/993 are default-on).

All five decisions from attempt 1's approval (host = `pro-data-tech-prod`, software = Stalwart, hostname = reuse `mail.aiqadam.org`, DMARC `p=none` day-one, direct-send outbound, deletion of MTA-STS/CalDAV/CardDAV/POP3 records) are unchanged and were not re-litigated.

User was offered "approve as-is" or "reject/need changes" and selected **"Approve as-is."**

Execution should proceed exactly as written in [runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md](runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md) (current content, attempt 2), starting from a fresh Phase 0 pre-flight (attempt 1's Phase 0 results are stale and must not be assumed to still hold, per the plan's own instruction).

## Issues / risks
None beyond what step 04 attempt 2 already documented and the user has now accepted (shared-host blast radius, partially-owned zone DNS surgery, functional regressions vs. old server, cold-IP deliverability expectations — all carried over from attempt 1's already-accepted risk profile; plus the three new items above, now also accepted).

## Open questions
None — all step-04 attempt 2 open items were resolved by this approval.
