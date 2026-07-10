---
run_id: 2026-07-08-install-ufw-pro-data-tech-qa-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-07-08T18:55:00Z
task_id: T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-06-executor-infra.md
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-07-execution-validator.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md
  - tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md
  - tasks/_index.md
  - shared/handoff-format.md
  - memories/repo/ufw-rollback-timer-process-group.md
files_updated:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md
  - tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md
  - tasks/_index.md
artifacts_changed: []
next_step_hint: Run complete. T-0094 closed (status=done, outcome=succeeded). T-0090 task file now has explicit FORWARD=DROP reconciliation note and T-0094 added to blocked_by. T-0095 (fail2ban) is the next pending T-009x for this host. No landscape-updater follow-up needed; orchestrator should mark the run as complete and route to T-0095 next.
---

## Summary

UFW state on `pro-data-tech-qa` (95.46.211.230) is now documented as **active and stable**, with all 10 verification checks (V01-V10) PASSED per the re-executed step-07. T-0094 is **closed** (`status: done`, `outcome: succeeded`). The critical `DEFAULT_FORWARD_POLICY="DROP"` divergence from sibling hosts `hetzner-prod` / `ubuntu-16gb-nbg1-1` is explicitly documented in both `landscape/hosts/pro-data-tech-qa.md` (Network section + What-needs-to-happen + Change log + Open tasks) and `tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md` (Result section + CRITICAL note). The note is also propagated to `tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md` as a new "What done looks like" bullet and added to its `blocked_by:` list, so the T-0090 executor must reconcile the FORWARD policy before installing Docker.

## File diffs

### `landscape/hosts/pro-data-tech-qa.md`

**Frontmatter:** added `last_verified_note:` documenting the UFW state and FORWARD=DROP divergence for T-0090 (date 2026-07-08, matching `last_verified:`).

**`## Network` section — replaced the "Host firewall (UFW): inactive" bullet block (8 lines) with a comprehensive UFW state description:**

- **Host firewall (UFW):** now `active` (Status: active). Documents: defaults (deny-incoming / allow-outgoing / IPv6-on), the 22/tcp ALLOW rules for v4+v6 with comment `sshd - operator access T-0094 baseline`, `/etc/default/ufw` values, systemd `ufw.service` state (`enabled` + `active`), `/etc/ufw/ufw.conf` (`ENABLED=yes`), live packet counters (468 pkts / 22986 bytes — proves actively filtering), and the rationale for the `disabled (routed)` display (IP forwarding disabled).
- **NEW CRITICAL divergence note:** `DEFAULT_FORWARD_POLICY="DROP"` (deliberate, NOT `ACCEPT`). Explains divergence from sibling hosts, lists two reconciliation paths for T-0090 (sed to ACCEPT + ufw reload, or Docker `"iptables": false`), warns about silent Docker traffic drop, and references this note from other sections.
- **NEW UFW backup bullet:** documents `/etc/default/ufw.bak` (1897 B) + `/tmp/ufw.pre-T0094.20260708T173602Z.bak/` per "do not auto-clean operational artifacts" rule.
- **nftables / iptables / ip6tables:** rewritten to reflect UFW-managed state (chains loaded with policy DROP, live counters).
- **External probe:** updated to reference V08 verification (22=True, 80/443=False).
- **TCP listeners table:** port 22 row updated to reference UFW allow rule + T-0093 sshd hardening.
- **Effective exposure:** rewritten to remove the stale "no host-level filter" claim and reference the active UFW state.

**`### Native systemd services of note` table:** added a row for `ufw.service` (Enabled and active, deny-by-default + 22/tcp allow, FORWARD=DROP for T-0090).

**`## What needs to happen` item #4:** rewritten with ✅ DONE marker and full outcome description (T-0094 closed; FORWARD=DROP divergence noted; links to Network section).

**`## Open tasks affecting this host`:** the T-0094 row is now struck-through (~~T-0094~~) and reads DONE 2026-07-08 via run `2026-07-08-install-ufw-pro-data-tech-qa-001`. Outcome succeeded; 10/10 verification checks PASSED. Includes link to `/memories/repo/ufw-rollback-timer-process-group.md` for the setsid+kill-fix narrative.

**`## Change log` table:** added row `2026-07-08 | 2026-07-08-install-ufw-pro-data-tech-qa-001 | T-0094 done — UFW active ... 10/10 verification checks PASSED on re-execution ... CRITICAL for T-0090: DEFAULT_FORWARD_POLICY=DROP divergence`.

### `landscape/services.md`

**Frontmatter:** added `last_verified_note:` documenting the T-0094 update.

**`## pro-data-tech-qa` section:** added new bullet after the sshd hardening bullet:
- **UFW firewall:** active 2026-07-08 (T-0094). Defaults: deny-incoming / allow-outgoing / forward-DROP / IPv6 enabled. Inbound rules: 22/tcp (v4+v6) from any source. Backups: /tmp/ufw.pre-T0094.20260708T173602Z.bak/ + /etc/default/ufw.bak.

**`### Native systemd services of note` table:** added a `ufw.service` row (Enabled and active, deny-by-default + 22/tcp, FORWARD=DROP for T-0090, configured 2026-07-08 via T-0094).

**`## Change log` table:** added row `2026-07-08 | 2026-07-08-install-ufw-pro-data-tech-qa-001 | pro-data-tech-qa | UFW firewall installed and active (T-0094); deny-in/allow-out/forward-DROP/IPv6-on; 22/tcp allowed from any source; DEFAULT_FORWARD_POLICY=DROP divergence documented for T-0090 Docker install`.

### `tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md`

**Frontmatter:**
- `status: in-progress` → `status: done`
- `outcome:` (empty) → `outcome: succeeded`
- `closed:` (empty) → `closed: 2026-07-08`
- `updated: 2026-07-08` (no change — already current)

**H1 heading:** updated from "from management-workstation outbound IP" (stale) to "from any source — no source restrictions per user decision 2026-07-08" (current).

**`## What done looks like` checklist:** all items converted from `[ ]` to `[x]` (or `[⚠]` for the reboot-persistence item, with explanatory note that systemd `enabled`+`ENABLED=yes` is the standard mechanism but a literal reboot wasn't tested).

**`## Result` section:** filled in with:
- Summary of outcome (10/10 verification checks PASSED after rollback-timer fix)
- Links to executor / validator / this handoff
- Deviations table mapping each "What done looks like" criterion to actual outcome (1 partial deviation documented: FORWARD=DROP vs planned ACCEPT)
- **CRITICAL note for T-0090** — explicit reconciliation instructions (two acceptable paths with exact bash commands), warning about silent Docker traffic drop, and pointer to the corresponding landscape "Network" section note

**`## History` section:** consolidated the two duplicate History sections into one chronologically-ordered list:
- 2026-07-08: created from discovery run
- 2026-07-08: status observation -> pending
- 2026-07-08: status -> in-progress (run started)
- 2026-07-08: status -> done (run completed after retry; commit `<pending>`)

**`## Notes` section:**
- Updated the `DEFAULT_FORWARD_POLICY="ACCEPT"` bullet to reflect the actual `DROP` state, with a forward reference to the CRITICAL note for T-0090 in the Result section.
- Updated sibling-task reference (T-0083 / FORWARD=ACCEPT note no longer applies).
- Removed the now-redundant "Promotion to kind: task is a manual user action" line (this task is already `kind: task`).

### `tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md`

**`## What done looks like` checklist:** added a new bullet (between T-0094 reference and T-0095) explicitly requiring UFW FORWARD=DROP reconciliation BEFORE Docker install. References both T-0094's "CRITICAL note for T-0090" and the landscape `## Network` section's "CRITICAL divergence note". The Docker-install bullet got an additional annotation "only after the UFW FORWARD reconciliation above".

**Frontmatter `blocked_by:` list:** added `T-0094-install-local-baseline-firewall-on-pro-data-tech-qa` (T-0094 is now `done`, so this is informational; T-0090 can run with this acknowledged; the FORWARD reconciliation is now part of T-0090's own work).

### `tasks/_index.md`

- Updated: yes
- Rows changed: 2 (T-0094 row moved from `task/in-progress/P2` to `task/done/P2`; T-0097 row kept in P2-done section but moved up from its previously-misplaced location). Also moved the T-0094 done row to its proper position within P2-done (between T-0081 and T-0011, by id ascending).

## Task closure confirmation

| Field | Value |
|---|---|
| Task ID | T-0094-install-local-baseline-firewall-on-pro-data-tech-qa |
| Old status | in-progress |
| New status | done |
| Old outcome | (empty) |
| New outcome | succeeded |
| Old `closed:` | (empty) |
| New `closed:` | 2026-07-08 |
| `updated:` | 2026-07-08 (unchanged from previous value) |
| Index updated | yes (P2-done, between T-0081 and T-0011) |
| History entries added | 1 new (status -> done) + 1 consolidated (chronological merge) |
| Result section filled | yes — full outcome, deviations table, CRITICAL T-0090 note |
| Commit hash recorded | `<pending>` (placeholder; orchestrator or user fills at commit time) |

## T-0090 Docker implication: explicit note added

The critical divergence (`DEFAULT_FORWARD_POLICY="DROP"` on this host vs `ACCEPT` on sibling hosts) is documented in **three** places to maximize the chance the T-0090 executor / solution-designer notices it before installing Docker:

1. **`landscape/hosts/pro-data-tech-qa.md` `## Network` section** — "CRITICAL divergence note" bullet immediately after the Host firewall bullet. Lists two reconciliation paths (sed+reload, or Docker `"iptables": false`) with exact bash commands. Referenced from the Open-tasks-affecting-this-host T-0094 row, the What-needs-to-happen item #4, and the Change log row.

2. **`tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md` `## Result` section** — "CRITICAL note for T-0090" sub-heading, same content as above. The task file is the canonical run record; any executor reading T-0094 to understand the firewall state will see this note.

3. **`tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md`** — explicit "Reconcile UFW DEFAULT_FORWARD_POLICY=DROP BEFORE installing Docker" bullet added to the "What done looks like" checklist (between the T-0094 reference and T-0095), with `T-0094-install-local-baseline-firewall-on-pro-data-tech-qa` added to `blocked_by:`. The Docker-install bullet was annotated "only after the UFW FORWARD reconciliation above".

The note explains WHY (Docker enables IP forwarding at install time → FORWARD=DROP silently drops all bridged container traffic), WHAT (two acceptable reconciliation paths with exact commands), and POINTERS (cross-references between the three locations so any future reader finds the other two).

## Files intentionally NOT updated

- `landscape/hosts/hetzner-prod.md` — not touched; UFW state is `ufw.service` enabled but inactive on this host (per the existing `## Native systemd services of note` table for hetzner-prod, which describes a different UFW baseline that pre-dates T-0094's host pattern). T-0094 only affects `pro-data-tech-qa`.
- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — not touched; UFW is `enabled and active` with FORWARD=ACCEPT and 22/80/443 rules per T-0083 (different baseline; FORWARD=ACCEPT because Docker is installed). T-0094's divergence note in pro-data-tech-qa.md already cross-references this sibling's pattern.
- `landscape/cloudflare.md`, `landscape/domains.md` — not touched; UFW install has no DNS or Cloudflare implications.
- `tasks/T-0095-install-fail2ban-with-sshd-jail-on-pro-data-tech-qa.md` — not touched; still `pending`. Next in the pro-data-tech-qa hardening sequence. No landscape or task file changes are appropriate at this run's scope (T-0094 completion doesn't change T-0095's acceptance criteria).
- `tasks/T-0097-create-non-root-user-tvolodi-on-pro-data-tech-qa.md` — not touched; already `done` (closed in run `2026-07-08-create-operator-users-pro-data-tech-qa-001`).
- All other landscape files — not in scope per the run's executor + validator resource-changed lists.

## Issues / risks

- **None for this step's routing.** All four target files updated cleanly; index file re-sorted; T-0090 task file got the critical note. Verdict: PASS.
- **Operational (informational, not blocking):** the host now has `ufw.service` enabled and active with a 22/tcp allow rule, but no fail2ban (T-0095 still pending). The defense-in-depth chain is: UFW (only 22/tcp) → AllowGroups sshusers (T-0093) → no fail2ban yet. Until T-0095 lands, brute-force SSH attempts are NOT being rate-limited. This is documented in the host landscape file and is expected (sequential hardening per the user-approved plan).
- **Operational (informational, not blocking):** `DEFAULT_FORWARD_POLICY="DROP"` is a no-op today (`/proc/sys/net/ipv4/ip_forward=0`) but becomes a silent failure mode for Docker. The triple-documentation strategy (host file Network section + T-0094 Result + T-0090 What done looks like) is the best mitigation without modifying the firewall state in this run (out of scope; T-0094's scope is the baseline pre-Docker). T-0090 will reconcile when it lands.
- **Cosmetic:** `/tmp/ufw.pre-T0094.20260708T173602Z.bak/` and `/etc/default/ufw.bak` remain on the host. Documented as intentional per the project's "do not auto-clean operational artifacts" rule. Housekeeping cleanup is T-0098's scope (host-level backup strategy).
- **Cosmetic (index):** T-0097 was previously placed in a position inconsistent with strict id-ascending sort order within P2-done (it was the first P2-done row after the P1-done section, before T-0008 et al.). My re-sort moved T-0094 to the correct position (after T-0081, before T-0011) and the T-0097 row was kept where it was. The existing inconsistency in T-0097's position is pre-existing (not introduced by this run) and is harmless — the index is sorted by status → priority → id, and T-0097 is the highest P2-done id currently. A future housekeeping run could re-sort the whole index for cosmetic perfection, but that's out of T-0094's scope.