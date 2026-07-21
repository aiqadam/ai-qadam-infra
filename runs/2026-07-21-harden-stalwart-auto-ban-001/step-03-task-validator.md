---
run_id: 2026-07-21-harden-stalwart-auto-ban-001
step: "03"
agent: task-validator
verdict: PASS
created: 2026-07-21T00:00:00Z
task_id: T-0121-harden-stalwart-auto-ban-against-bridge-ip
inputs_read:
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-01-task-reader.md
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-02-landscape-reader.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - workflows/infrastructure.md
  - tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
artifacts_changed: []
next_step_hint: solution-designer — design mitigations for Stalwart bridge-gateway auto-ban; live-discover the 7 landscape gaps via SSH before committing to a specific config change; emit NEEDS_APPROVAL (MEDIUM blast radius)
---

## Summary

Task T-0121 is fully valid: it is well-formed with concrete acceptance criteria, maps cleanly to the infrastructure workflow, targets state not yet in place, conflicts with nothing currently in-flight, and all 7 landscape gaps are resolvable via live discovery during execution. The task may proceed to solution design. The solution-designer **must** emit `NEEDS_APPROVAL` — this task's MEDIUM blast radius (live production mail server actively delivering real mail) makes it non-auto-approvable.

## Details

### Validation results

1. **Well-formed: PASS** — The task names a concrete, verifiable end state across four acceptance criteria (at least one mitigation implemented and active; external monitoring or scoped follow-on filed; JMAP runbook documented in `pro-data-tech-prod.md`; re-verification of admin UI + SMTP + IMAPS). A named workflow (`infrastructure`) is declared in the frontmatter. Blast radius (`medium`) and reversibility (`full`) are both estimated. The "Why" section traces the issue to a confirmed production incident (2026-07-20) with root-cause analysis.

2. **In-scope: PASS** — The infrastructure workflow explicitly covers Docker/Compose changes, nginx config changes, and new tool/service configuration on managed hosts (see `workflows/infrastructure.md` "When this workflow applies"). All three mitigation tracks (Stalwart config, nginx vhost access restriction, allowed-IP list) are infrastructure changes on `pro-data-tech-prod`. Monitoring scope (cron-based external probe or follow-on task) is also infrastructure. No changes outside this repo's managed systems are implied.

3. **Not already done: PASS** — The landscape (step-02 summary and `landscape/hosts/pro-data-tech-prod.md`) explicitly confirms: no Stalwart auto-ban hardening is documented, no X-Forwarded-For trust settings exist, no `allowed-ip`/`trusted-ip` entries are configured, no external monitoring of any kind is in place, and the `x:BlockedIp` runbook documentation does not yet exist in the landscape file. The target state across all four acceptance criteria is entirely absent.

4. **No conflict with current state: PASS** — T-0112 (the task noted as "in-progress" in the run brief) has `status: done`, `closed: 2026-07-17`; it is complete. Its scope was SSH deploy keys for the `deploy` system user — it touches `authorized_keys`, `sshd_config.d/40-ai-dala-infra.conf`, and `AllowGroups`, with no overlap with Stalwart config, nginx admin vhost, or Docker network configuration. No other in-progress task in the workspace touches `pro-data-tech-prod`'s Stalwart deployment or the `stalwart-mail` Compose stack. No conflict exists.

5. **Discoverable scope: PASS** — All 7 landscape gaps can be resolved via SSH and in-container inspection during the executor phase, without external dependencies or user input. Specifically:
   - Gap 1 (Stalwart auto-ban config knobs / X-Forwarded-For trust / issue #2121 fix availability): resolvable by `GET /api/schema` on the live container + upstream docs/changelog research.
   - Gap 2 (exact patch version): `docker exec stalwart-mail-server-1 stalwart --version` or equivalent.
   - Gap 3 (nginx `mail.aiqadam.org` X-Forwarded-For headers): `cat /etc/nginx/sites-available/mail.aiqadam.org` on the host.
   - Gap 4 (current `x:BlockedIp` list): JMAP `x:BlockedIp/query` + `x:BlockedIp/get` via `stalwart-cli` or peer-container `curl`.
   - Gap 5 (container bridge IP on `stalwart-mail_default`): `docker inspect stalwart-mail-server-1` or `docker network inspect stalwart-mail_default`.
   - Gap 6 (Bootstrap config content): `ls /opt/stalwart-mail/etc-stalwart/` + `cat` of relevant files on the host.
   - Gap 7 (notification channel for external monitoring): This is a design-scoping decision, not a discovery blocker. The solution-designer has sufficient latitude to scope a minimal cron-based external probe (e.g., periodic `curl` from the management workstation or a cron job on the host itself) or to file a bounded follow-on task. No hard external dependency.

6. **Workflow-specific rules respected: PASS** — All three infrastructure-workflow-specific rules are satisfiable for this task:
   - Rule 1 (idempotency): Stalwart JMAP set operations and nginx `allow`/`deny` additions are idempotent by nature; a re-run that finds the config already set is a no-op. The designer must call this out per the rule.
   - Rule 2 (backup before destructive changes): nginx vhost modification and Stalwart config store changes are both in-scope for pre-change backup; the executor path (`executor-infra`) is expected to capture these per established host patterns.
   - Rule 3 (verify in two places): the task's own acceptance criteria already require re-verification of admin UI + SMTP + IMAPS after mitigation — this satisfies the "externally-observable behavior" prong. The execution-validator (step 07) will confirm both on-host state and external reachability.

### Approval gate note

This task has `estimated_blast_radius: medium`. Changes touch a live production mail server actively delivering real mail for `aiqadam.org`. A `docker compose restart` (required after any config change to clear Stalwart's in-memory ban state) will cause a brief interruption to SMTP/IMAP/submission service. The solution-designer **must** emit `verdict: NEEDS_APPROVAL` in its handoff — this task is not auto-approvable regardless of how narrow the specific change turns out to be. The approval gate is mandatory before the executor may act.

## Issues / risks

- **`allowed-ip` semantics unconfirmed:** GitHub issue #1383 (referenced in the task) suggests this config primitive prevents future bans but does not retroactively remove existing ones, and may be silently overridden by a later `blocked-ip` entry. The solution-designer must confirm or deny these semantics for `v0.16.x` before relying on this as the sole mitigation.
- **Floating image tag `v0.16`:** The Compose file pins to a minor-version tag that could silently receive patch updates. The solution-designer must resolve the exact running patch version during live discovery before deciding whether a config knob exists for X-Forwarded-For trust in auto-ban.
- **`docker compose restart` service interruption:** Any accepted config change will require a container restart to flush the in-memory ban cache. This is a brief but real interruption to production mail. The designer should flag this and recommend a low-traffic maintenance window.
- **External monitoring scope:** No alerting infrastructure exists in this repo. The solution-designer must make an explicit scoping decision between implementing a minimal cron-based external check (acceptable scope) and filing a bounded follow-on task.
- **Coexistence:** Penpot and AiQadam prod stacks share this host. Any host-level firewall change (e.g., `ufw reload`) must include a no-regression check for those stacks per the established pattern on this host.
