---
id: T-0119-capture-mail-tester-score-for-aiqadam-mail
title: Capture a mail-tester.com numeric deliverability score for the new aiqadam.org mail server
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

# Capture a mail-tester.com numeric deliverability score for the new aiqadam.org mail server

## Why

T-0117's own acceptance criteria asked for "mail-tester.com (or equivalent) score captured post-cutover as a deliverability baseline." Quoted from the T-0117 executor's handoff (`runs/2026-07-19-install-mail-server-aiqadam-001/.attempts/step-06-executor-infra-attempt-8.md`):

> "mail-tester.com's own numeric score could NOT be captured. Its unique per-session test address (test-XXXXX@mail-tester.com) is generated client-side via JavaScript on page load; WebFetch against https://www.mail-tester.com/ returned HTTP 403 Forbidden (the site blocks fetch-bot user agents), and a plain curl fetch with a browser user-agent returned the pre-render static HTML shell with no test address embedded... captaindns.com's alternative mail-tester tool has the identical JS-driven-address-generation limitation."

This is a tooling limitation, not a configuration problem — a real, substitute authentication baseline was independently captured instead via Port25 Solutions' `verifier.port25.com` reflector (SPF pass; DKIM inconclusive due to that specific free tool's own documented lack of modern-DKIM-spec/RFC-8463 support, not a configuration fault, independently cross-checked via correct DNS publication). If the user specifically wants the mail-tester.com 1-10 numeric score, it requires either a human to manually visit the site and relay back a live generated test address, or a future attempt with browser-automation tooling available.

## What done looks like

- [ ] A human (or a future agent with headless-browser/browser-automation tooling) visits https://www.mail-tester.com/, notes the generated `test-XXXXX@mail-tester.com` address
- [ ] Send a test message to that address from `test@aiqadam.org` (credentials: `stalwart-mail-test-account-password` in `credentials.md`) via the live submission port (587 or 465) — the mail server side is already fully ready for this
- [ ] Capture the resulting numeric score (1-10) and the report's specific findings
- [ ] Record the score in `landscape/hosts/pro-data-tech-prod.md` as a deliverability baseline

## Result
<empty until closed; then: what actually happened, outcome, links to executing run(s) and commits, any deviations from the plan>

## Notes
- Low blast radius, full reversibility — this is a read-only external test against an already-live, already-tested mail server; no infrastructure change involved.
- Priority set to P2 (default) — a nice-to-have specific number, not a blocker; T-0117 already closed with a real, substitute deliverability baseline captured via Port25.
- Gmail-based interactive send/receive verification (`mcp__claude_ai_Gmail__*`) was also unavailable during T-0117 due to an expired OAuth token requiring user re-authorization — if picking this task up, consider re-authorizing that connection too, since it would let a future attempt confirm Gmail inbox-vs-spam placement directly alongside a mail-tester.com run.

## History
- 2026-07-19: created from 2026-07-19-install-mail-server-aiqadam-001 (landscape-updater, step 08), based on the mail-tester.com JS-rendered-address tooling limitation surfaced during T-0117 Phase 8 testing.
