---
run_id: 2026-07-21-harden-stalwart-auto-ban-001
step: "01"
agent: task-reader
verdict: PASS
created: 2026-07-21T00:00:00Z
task_id: T-0121-harden-stalwart-auto-ban-against-bridge-ip
inputs_read:
  - tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader — read pro-data-tech-prod.md and services.md; determine current Stalwart version config, nginx vhost for mail.aiqadam.org, and Docker network topology
---

## Summary

Task T-0121 is clear, in-progress (run already initiated), and maps cleanly to the infrastructure workflow. The goal is to prevent Stalwart's built-in auto-ban from ever again silently banning the Docker bridge gateway IP (`172.19.0.1`), which caused a total external outage of the production mail server on 2026-07-20 without any alerting. Three mitigation tracks are in scope (X-Forwarded-For trust config, allowed-IP list for the bridge gateway, nginx exposure reduction), plus monitoring/alerting, plus incident runbook documentation — executed on the live `pro-data-tech-prod` host.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md` — primary; contains Stalwart deployment details, Docker network topology, nginx config references
  - `landscape/services.md` — secondary; verify Stalwart service registration and known constraints
- **Why (verbatim from task):**
  > On 2026-07-20, `https://mail.aiqadam.org/` (the Stalwart admin UI) started returning `502 Bad Gateway`, and on closer inspection SMTP/IMAPS were also unreachable from outside the container — all while the container itself reported `healthy` via Docker's own healthcheck. Root cause (confirmed via a peer-container packet-level test, then confirmed directly via the JMAP `x:BlockedIp` object): Stalwart's built-in auto-ban feature detected port-scanning traffic and, due to a known upstream bug pattern (malformed scanner requests defeating `X-Forwarded-For` parsing), banned the **Docker bridge gateway IP** (`172.19.0.1`) instead of the real attacker IPs. Because every external connection to this container is NAT'd through Docker's bridge and appears to originate from that one gateway address, the ban silently blocked *all* external traffic — legitimate and malicious alike — while `docker exec`-based healthchecks kept reporting the container healthy. Nothing about this is specific to a one-time misconfiguration — the same scanning traffic pattern that triggered it once will recur.

- **Constraints stated by user:**
  - Mitigations must be implemented in priority order: (1) X-Forwarded-For trust fix, (2) allowed-IP list for bridge gateway, (3) nginx exposure reduction — at least one must be implemented
  - Must not undermine real auto-ban effectiveness against legitimate attacker IPs
  - Monitoring must be external to the container (Docker healthcheck alone is insufficient — it's what masked the outage)
  - Blast radius is MEDIUM; must go through normal plan/approval discipline
  - Fully reversible changes only (per task frontmatter)
  - `x:BlockedIp` JMAP runbook documentation must be added to `landscape/hosts/pro-data-tech-prod.md`

- **Acceptance criteria (from task "What done looks like"):**
  - [ ] At least one mitigation from the ordered list is implemented and active
  - [ ] External monitoring/alerting exists for admin UI + SMTP/IMAPS reachability (or a scoped follow-on task is filed if full monitoring is out of scope)
  - [ ] JMAP `x:BlockedIp` query/delete procedure documented in `landscape/hosts/pro-data-tech-prod.md`
  - [ ] Re-verification confirms admin UI, SMTP, and IMAPS remain reachable after mitigation

- **Information gaps for downstream steps:**
  - Whether Stalwart v0.16.13 exposes a config knob for X-Forwarded-For trust in auto-ban (issue #2121 fix availability) — needs research against upstream docs/changelog
  - Whether Stalwart has an `allowed-ip` / `trusted-ip` config primitive and its exact syntax — needs landscape file + upstream docs cross-check
  - Current nginx config for `mail.aiqadam.org` admin vhost (source path on host, current `allow`/`deny` rules if any) — needs landscape file
  - Current Docker Compose network name and confirmed bridge gateway CIDR for Stalwart on `pro-data-tech-prod` — needs landscape file
  - Available notification channel for new monitoring alerting (email, webhook, etc.) — no existing external-monitoring convention in this repo

## Issues / risks

- **Silent failure mode is severe:** Docker healthcheck reports healthy while all external access is blocked — any monitoring solution that relies solely on the Docker API will have the same blind spot. The external check must originate from outside the host.
- **Allowed-IP semantics ambiguity:** GitHub issue #1383 (referenced in task) suggests `allowed-ip` prevents future bans but does not retroactively remove existing bans, and may be silently overridden by a `blocked-ip` entry added later. The solution-designer must confirm these semantics for v0.16.13 before relying on this mitigation alone.
- **Monitoring scope:** the task says a new minimal mechanism (e.g., cron + notification channel) is acceptable, but no existing monitoring infrastructure exists in this repo — solution-designer must make an explicit scoping decision (implement minimal cron check vs. file a follow-on task).
- **Blast radius MEDIUM:** changes touch a live production mail server actively delivering real mail. Approval gate required before execution.
