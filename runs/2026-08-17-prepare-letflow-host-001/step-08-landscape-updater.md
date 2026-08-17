---
run_id: 2026-08-17-prepare-letflow-host-001
step: "08"
agent: landscape-updater
verdict: PASS
created: 2026-08-17T07:00:00Z
task_id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
inputs_read:
  - runs/2026-08-17-prepare-letflow-host-001/step-04-solution-designer.md
  - runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md
  - runs/2026-08-17-prepare-letflow-host-001/step-07-execution-validator.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-04-solution-designer-attempt-2.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-06-executor-infra.attempt1.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-06-executor-infra.attempt2.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md
  - tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md
  - tasks/_index.md
  - tasks/_template.md
artifacts_changed:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md
  - tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md
  - tasks/_index.md
next_step_hint: >
  T-0134 closed done/succeeded. T-0135 opened as a new observation task tracking
  the two undocumented 2026-06-27 discoveries (T-0087 sshd/account provisioning;
  Hetzner firewall port-22 widening). Landscape now reflects the verified
  post-run state. No further steps required for this run; T-0135 awaits user
  triage/promotion at their discretion. The commit hash placeholder in T-0134's
  History needs to be filled in by the orchestrator or user at commit time.
---

## Summary
Updated `landscape/hosts/ubuntu-16gb-nbg1-1.md`, `landscape/services.md`, and `landscape/secrets-inventory.md` to reflect T-0134's verified end state; closed task T-0134 as done/succeeded with full multi-attempt History; created new observation task T-0135 for the two undocumented 2026-06-27 discoveries and added it to `tasks/_index.md`.

## Details

### Landscape files updated
| File | Sections changed | last_verified set to |
|---|---|---|
| [landscape/hosts/ubuntu-16gb-nbg1-1.md](../../landscape/hosts/ubuntu-16gb-nbg1-1.md) | frontmatter (`role`, `last_verified`); intro paragraph; Hardware & OS (Hetzner Cloud Firewall summary line); Access (account list, sshd daemon config, sshd drop-in files, `sshusers` group, fail2ban note); What runs here (intro + systemd table: added `docker.service`, updated `ssh.service`); Network (UFW ruleset note, Docker UFW bypass, external probe, TCP listener table); Hetzner Cloud Firewall (full rewrite: 3 rules, world-open port 22 rationale); Backups (no-data-yet note); Open questions (removed resolved Role question); What needs to happen (items 4 and 6 marked done); Open tasks affecting this host (added T-0134, T-0135; corrected T-0082's stale "clean slate" note); Change log (2 new rows: retroactive discovery entry + this run's entry) | 2026-08-17 |
| [landscape/services.md](../../landscape/services.md) | frontmatter (`last_verified`, `last_verified_note`); `## ubuntu-16gb-nbg1-1` section intro; Docker subsection (installed, version, egress test); Native systemd services table (added `docker.service`, updated `ssh.service`) | 2026-08-17 (frontmatter `last_verified` covers the whole file; only the `ubuntu-16gb-nbg1-1` section's content changed) |
| [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) | New section "ai-qadam project — ubuntu-16gb-nbg1-1 (management workstation)" with 2 documentation-only rows (SSH key fingerprint, Hetzner API token path) | n/a (file has no `last_verified` frontmatter field; it is gitignored and untracked by design) |

### Task files updated (state-changing runs)
| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow | in-progress | done | succeeded |

### Task files created (read-only runs surfacing new issues)
| New task ID | kind | priority | affects | source finding |
|---|---|---|---|---|
| T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1 | observation | P2 | landscape/hosts/ubuntu-16gb-nbg1-1.md | Two undocumented 2026-06-27 changes discovered live during T-0134's Phase 0 checks: (1) `T-0087`-labeled sshd hardening + `viktor_d`/`binali_r` account provisioning, no task/run record anywhere, plausible-but-unconfirmed corroboration with T-0105; (2) Hetzner Cloud Firewall port-22 rule widened to `0.0.0.0/0`+`::/0`, no task/run record and no corroborating explanation found |

### tasks/_index.md
- Updated: yes
- Rows changed: 2 (T-0134 moved from the open/in-progress block to the done section, sorted by id within the P1-done group; T-0135 added to the observation block, sorted by id within P2-observation)

### Diff summary

**`landscape/hosts/ubuntu-16gb-nbg1-1.md`** — This was the most substantially revised file, per the plan's explicit instruction to correct a materially false prior claim, not just append. The frontmatter `role` moved from `unassigned` to `letflow-app` and `last_verified` was bumped to today. The intro paragraph, Hardware & OS summary, Network section, and the dedicated "Hetzner Cloud Firewall" section were all rewritten to describe the firewall's new 3-rule state (port 22 reconfirmed world-open by explicit user decision; 80/443 newly opened), replacing the old 1-rule/workstation-IP-only description. The Access section's "clean slate" claim (`root, nobody, tvolodi` only) was corrected to list `viktor_d`/`binali_r` as present but expired+locked, with the reversal path referenced. The sshd daemon config and drop-in file bullets were rewritten to describe the fleet-standard `AllowGroups sshusers` pattern now in effect, explicitly documenting that it replaces an undocumented `T-0087`-labeled hardening pass (with the old drop-in's directives spelled out for the record) rather than silently overwriting history. A new `sshusers` group bullet was added. The Docker install was recorded in "What runs here" and the systemd table. "What needs to happen" items 4 (sshd hardening) and 6 (role assignment) were flipped from pending to done with links back to T-0134. The now-resolved "Role" open question was removed (the question is answered, not merely stale). The "Open tasks affecting this host" list gained T-0134 and T-0135 and had T-0082's stale role-related parenthetical corrected. Two Change log rows were appended: one retroactive entry documenting both undocumented 2026-06-27 discoveries (with an explicit "none — no task/run record found" provenance marker, as instructed), and one for this run's actual changes.

**`landscape/services.md`** — The file-level frontmatter `last_verified` and `last_verified_note` were updated to lead with this run's finding (previous note preserved below it, unbroken, per the file's existing convention of stacking prior notes). Within the `## ubuntu-16gb-nbg1-1` section, the high-level summary line, the Docker subsection, and the Native systemd services table were updated to show Docker installed (Engine 29.7.2, Compose plugin v5.4.0, active/enabled, no application containers yet) and `docker.service` added to the table; the `ssh.service` row was annotated with the 2026-08-17 hardening and a pointer to the host file's Access section rather than duplicating the full detail.

**`landscape/secrets-inventory.md`** — Added exactly the two documentation-only rows the plan specified (SSH key fingerprint and Hetzner API token file path, no values), under a new host-scoped section header, consistent with the file's existing per-service section convention. No existing rows were touched.

**`tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md`** — Transitioned to `status: done`, `outcome: succeeded`, `closed: 2026-08-17`. All 5 "What done looks like" checkboxes marked complete. The "Result" section was filled in with the final end state, links to the executor and validator handoffs, and an explicit "Deviations from the original checklist" subsection covering the three respects in which live reality diverged from the original task's assumptions (undocumented accounts requiring a lock decision; port 22 already widened requiring a preserve-not-narrow decision; sshd hardening starting from an undocumented baseline rather than a clean one). The History section was rewritten from a 2-entry stub into a full account of all 4 executor-infra attempts and 2 designer revisions, including what each of the 3 failed attempts discovered and why each halt was correct rather than a defect, per the instruction to give future readers an accurate multi-round account rather than only the final PASS.

**`tasks/T-0135-investigate-undocumented-2026-06-27-changes-on-ubuntu-16gb-nbg1-1.md`** (new) — Created with `kind: observation`, `status: observation`, `priority: P2`. The "Why" section documents both findings in detail, explicitly separating the plausible-but-unconfirmed T-0105 corroboration for Finding 1 from the complete absence of any corroborating lead for Finding 2, as instructed. "What done looks like" is framed as a process-gap investigation (who/what/why bypassed the workflow, and whether other undocumented changes exist elsewhere) rather than as a remediation checklist, since T-0134 already reconciled the on-host symptoms. Related to T-0105 and T-0134 via the `related:` frontmatter field.

**`tasks/_index.md`** — T-0134's row moved from the open section to the done section (inserted in id order within the P1/done group, after T-0122 and before T-0130 per the existing file's insertion pattern). T-0135's row was added to the observation block in id order after T-0127. Full re-sort was not otherwise needed since no other task's status changed in this run.

### Files intentionally NOT updated
- `landscape/cloudflare.md`, `landscape/domains.md` — T-0134 explicitly scoped these out (host-level readiness only; app-level deploy including Cloudflare DNS is a follow-on task not yet created). Confirmed against the plan's own "Informational" note: "this plan does not touch shared/app-registry.md, Cloudflare DNS, or nginx."
- `shared/app-registry.md` — same reason; no app registered yet.
- `landscape/hosts/pro-data-tech-qa.md`, `landscape/hosts/pro-data-tech-prod.md` — not touched by this run; T-0135's investigation may eventually implicate other hosts but that has not happened yet, so no speculative edits were made there.

## Issues / risks

- None. The validator's PASS verdict and the executor's "Resources changed" section were fully consistent with the plan's "Files modified in this repo" instructions, so no conflict requiring a FAIL verdict was encountered.
- One judgment call: the Hetzner Cloud Firewall's `Labels` field (`purpose=ssh-management-only`) is now stale given the firewall covers 80/443 too, but the executor did not change the label (out of scope for T-0134's plan) — this landscape update noted the staleness inline rather than silently correcting a label the actual system does not have, consistent with "landscape describes state, not aspiration."
