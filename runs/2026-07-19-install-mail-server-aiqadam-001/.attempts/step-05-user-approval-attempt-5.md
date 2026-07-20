---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-07-19T07:00:00Z
task_id: T-0117-install-mail-server-aiqadam
retry_of: step-05
inputs_read:
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md
artifacts_changed: []
next_step_hint: proceed to step 06 (executor-infra), attempt 5, with the corrected plan exactly as approved.
---

## Summary
Orchestrator approved attempt 5's plan under the user's standing delegation from attempt 3's approval ("All up to you. Call me when everything will be ready"), without a fresh user round-trip, per that delegation's own stated scope: routine, same-character mechanism fixes that do not change any previously-approved substantive decision.

## Details
This fix is narrower and more mechanical than the Bootstrap-flags item that DID warrant a fresh check-in at attempt 4: it does not change what is configured (host, image, DKIM handling, TLS approach, DNS scope, or the already-approved `generateDkimKeys: false`/`requestTlsCertificate: false` values) — it only adds one missing operational step (a container restart) required for Stalwart v0.16's already-approved configuration to actually take effect.

**Root cause, now empirically confirmed** (not a guess): via a fully isolated, disposable local scratch container — unrelated to and never connected to any production system — it was confirmed that Stalwart v0.16 only re-evaluates whether bootstrap setup is complete at process startup. The `update Bootstrap` call correctly writes the new config to its data store (confirmed independently: RocksDB grows, a real `Domain` object is created, a repeat call hits a uniqueness violation on that object), but the running process doesn't pick up the change until restarted. This exactly reproduces attempt 4's empirical findings and was independently corroborated by literal text in Stalwart's own web UI bundle ("restart Stalwart for the new configuration to take effect").

**Fix approved:** insert a `docker compose restart` (+ health-wait) immediately after `update Bootstrap`, move the bootstrap-mode-gone verification to run after that restart, and add a guardrail: if verification still fails after the one restart, halt and report rather than ever re-running `update Bootstrap` a second time (which would hit a real, orphaned uniqueness conflict on the domain object already silently created by the first call).

Also approved as routine, already-covered corrections: capturing the new `admin@aiqadam.org` credential generated as a side effect of bootstrap completion (new secret `stalwart-mail-domain-admin-password`), and the adjusted expected response for the domain-already-exists case in the later `create Domain` discovery step.

All decisions from attempts 1-4 (host = `pro-data-tech-prod`, Stalwart v0.16, hostname reuse, DMARC `p=none`, direct-send outbound, split volumes/UID 2000, `STALWART_RECOVERY_ADMIN`, internal ACME/DNS-01, orphaned-cert reuse, port 587, MTA-STS/CalDAV/CardDAV/POP3 deletions, `stalwart-cli` "latest" install, `Dkim1Ed25519Sha256`, `STALWART_PASSWORD` auth, `NetworkListener protocol: smtp`, and the attempt-4 `generateDkimKeys: false`/`requestTlsCertificate: false` Bootstrap flags) remain unchanged and are not reopened.

Execution should proceed exactly as written in [runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md](runs/2026-07-19-install-mail-server-aiqadam-001/step-04-solution-designer.md) (current content, attempt 5), starting from a fresh Phase 0 pre-flight.

## Issues / risks
None beyond what step 04 attempt 5 already documented. The user's delegation remains in effect for further same-character mechanism fixes; any future item touching a previously-approved substantive decision should still be surfaced for fresh sign-off, per the standard already applied at attempt 4.

## Open questions
None.
