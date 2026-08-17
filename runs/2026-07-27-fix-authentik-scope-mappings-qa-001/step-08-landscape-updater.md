---
run_id: 2026-07-27-fix-authentik-scope-mappings-qa-001
step: 08
agent: landscape-updater
verdict: PASS
created: 2026-07-27T16:57:38Z
task_id: T-0126-fix-authentik-scope-mappings-on-qa
inputs_read:
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-02-landscape-reader.md
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-04-solution-designer.md
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-06-executor-infra.md
  - runs/2026-07-27-fix-authentik-scope-mappings-qa-001/step-07-execution-validator.md
  - tasks/T-0126-fix-authentik-scope-mappings-on-qa.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/_index.md
  - tasks/_template.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - tasks/T-0126-fix-authentik-scope-mappings-on-qa.md
  - tasks/T-0127-verify-authentik-qa-fix-live-browser-round-trip.md
  - tasks/_index.md
next_step_hint: T-0126 closed done/succeeded with two explicitly disclosed verification gaps (literal browser round trip, existing-user non-regression), both rolled into follow-up observation T-0127. AC5 (cross-repo report to aiqadam/ai-qadam-platform) was deferred by the executor to the orchestrator — this landscape-updater pass has no evidence it was posted; orchestrator/user should confirm and, if needed, do it manually (no new task filed for this — cross-repo, low-stakes, easily checked). Commit hash in T-0126's History entry is still `<pending>` — orchestrator or user should fill it in at run-finalization/commit time.
---

## Summary
Updated `landscape/hosts/pro-data-tech-qa.md` and `landscape/services.md` to document the Authentik scope-mapping fix, the 5 previously-undocumented `aiqadam-qa` containers, and the `qa.aiqadam.org`-supersedes-`qa-uz.aiqadam.org` hostname correction; closed task T-0126 as `done`/`succeeded` with two explicitly disclosed verification gaps; created follow-up observation task T-0127 for the deferred live browser round trip; updated `tasks/_index.md` accordingly.

## Details
### Landscape files updated
| File | Sections changed | last_verified set to |
|---|---|---|
| `landscape/hosts/pro-data-tech-qa.md` | Frontmatter (`last_verified`, `last_verified_note`); "What runs here" summary; "AiQadam application stack (aiqadam-qa)" intro + Compose-file bullet + container table (5 rows added) + Database/Health-endpoint/Known-deviation/Scope/Known-non-blocking-noise bullets (hostname corrected, scope note updated); "Native systemd services of note" nginx/certbot rows (vhost renamed); Change log (1 row appended) | 2026-07-27 |
| `landscape/services.md` | Frontmatter (`last_verified`, `last_verified_note`); `## pro-data-tech-qa` high-level summary; "Running Compose projects" table (container count 2→7); "Running containers" table (5 rows added, table heading date updated); "AiQadam QA application stack" summary bullet; nginx status line (vhost renamed); Change log (1 row appended) | 2026-07-27 |

### Task files updated (state-changing runs)
| Task ID | Old status | New status | Outcome |
|---|---|---|---|
| T-0126-fix-authentik-scope-mappings-on-qa | in-progress | done | succeeded |

### Task files created (read-only runs surfacing new issues)
| New task ID | kind | priority | affects | source finding |
|---|---|---|---|---|
| T-0127-verify-authentik-qa-fix-live-browser-round-trip | observation | P2 | landscape/hosts/pro-data-tech-qa.md | T-0126's Phase 3.2 (literal browser registration→OIDC→callback round trip) and Phase 3.3 (existing-user non-regression) could not be completed — blocked by a pre-existing, external, unrelated registration-endpoint rate limiter (429, still active ~2h post-patch at validator time) |

### tasks/_index.md
- Updated: yes
- Rows changed: 3 (T-0126 status/priority-section move from in-progress to done; new row for T-0127 inserted into the observation block; full table re-sorted per the open-status/priority/id then closed-status/priority/id rule)

### Diff summary
`landscape/hosts/pro-data-tech-qa.md`: the "AiQadam application stack (aiqadam-qa)" section's container table grew from 2 rows to 7, adding `aiqadam-qa-web-next-1`, `aiqadam-qa-directus-1`, `aiqadam-qa-authentik-server-1`, `aiqadam-qa-authentik-worker-1`, and `aiqadam-qa-redis-1` with image, purpose, and (for the two Authentik containers) the scope-mapping fix detail sourced directly from step-06/step-07's verified findings — no speculative facts were added beyond what those two handoffs stated. The public hostname was corrected from `qa-uz.aiqadam.org` to `qa.aiqadam.org` throughout this section and the systemd-services table, with the retirement of the old vhost explained in-line (nginx `sites-enabled/` now contains only the new vhost, whose header comments document the migration). The "Known non-blocking noise" and "Scope" bullets were softened rather than deleted, since the underlying claims (Redis absent, OIDC/Directus out of scope) are now superseded by the discovery — not deleted outright, since I could not independently re-verify whether the noise itself has actually stopped.

`landscape/services.md`: the `pro-data-tech-qa` section's "Running Compose projects" and "Running containers" tables were extended in parallel with the host file, using the same source facts (image tags, uptime buckets, health status from step-06's `docker ps -a` output). Host-port values for the 5 newly-documented containers were left as "not enumerated" rather than guessed, since step-06's `docker ps -a` output (trimmed) did not include port columns for those specific rows and Phase 0.3's `docker inspect` was only run against the Authentik container. The nginx status bullet's vhost path and cert reference were updated to `qa.aiqadam.org`.

`tasks/T-0126-fix-authentik-scope-mappings-on-qa.md`: frontmatter transitioned to `status: done`, `outcome: succeeded`, `closed: 2026-07-27`. The "What done looks like" checklist was annotated in place — AC1 and AC2 checked off with a note on AC2's implementation-mechanism deviation (ORM `.add()` via `ak shell` rather than a literal REST `PATCH`, which the approved plan itself specified as the primary mechanism); AC3, AC4, and AC5 left unchecked with inline notes pointing to the Result section's full explanation. The Result section documents: the fix is verified via 3 independent on-host ORM re-queries plus an external OIDC-discovery-document check; AC3 (browser round trip) and AC4 (non-regression) are explicitly deferred (not silently dropped) due to a pre-existing, external rate limiter, with a follow-up task filed; AC5 (cross-repo report) status is unknown to this landscape-updater pass since the executor deferred it to the orchestrator. History got one new entry recording the closure, referencing both disclosed gaps and the two landscape corrections this run also produced.

`tasks/T-0127-verify-authentik-qa-fix-live-browser-round-trip.md` (new): created via the `_template.md` skeleton, `kind: observation`, `status: observation`, `priority: P2`, `created_by`/`source_runs` set to this run, `affects: [landscape/hosts/pro-data-tech-qa.md]`, `related: [T-0126-...]`. Why section quotes the specific 429 findings from step-06/step-07. What-done-looks-like covers both deferred checks (browser round trip, non-regression) plus recording the actual rate-limit window duration for future reference.

`tasks/_index.md`: T-0126 moved from the `in-progress` block to the `done` block (sorted first among `done` entries since it is the only `P0`, per priority-then-id sort). T-0127 inserted into the `observation` block, sorted after the existing P2 observations by id (T-0120 < T-0127), before the P1 `pending` block begins.

### Files intentionally NOT updated
- `landscape/secrets-inventory.md` — not touched by the executor (no new credential was persisted; the `ak shell` admin session was explicitly ephemeral per the plan) and not listed in either the designer's "Files modified" or the executor's "Resources changed."
- `landscape/domains.md`, `landscape/cloudflare.md` — the DNS records themselves (`auth.qa.aiqadam.org`, `qa.aiqadam.org`, `qa-uz.aiqadam.org`) were not changed by this run; only the *nginx-level* routing/vhost state changed (out-of-band, prior to this run — this run only discovered and documented it). Neither the designer's plan nor the executor's "Resources changed" section listed these files, and the task file's own `affects:` list does not include them either. Re-pointing or removing the `qa-uz.aiqadam.org` DNS record is exactly the kind of follow-up the executor flagged as "out of scope for this task" — left for a future task if the user wants it, not invented here.
- `tasks/T-0124-fix-deploy-qa-permission-denied.md`, `tasks/T-0125-fix-authentik-admin-url-on-qa.md` — both are `related:` to T-0126 and were referenced heavily in step-02's landscape read (as still genuinely `in-progress`, contrary to T-0126's own narrative), and step-06's Phase 0.5 re-confirmed T-0125's `AUTHENTIK_ADMIN_URL` fix is in fact live (`https://auth.qa.aiqadam.org`, correct value) — but this run's task_id is T-0126 only, and neither T-0124 nor T-0125 is in T-0126's own `affects:` list or executed_by_runs. Per the landscape-updater's mandate ("edit only files the executor's Resources changed + the designer's Files modified indicate"), I did not touch either task file, even though Phase 0.5's finding is arguably relevant evidence toward T-0125's own closure. Flagging this for the user/orchestrator: T-0125's `AUTHENTIK_ADMIN_URL` fix now has live corroborating evidence (this run's Phase 0.5) that it is deployed and correct, which may be enough to close T-0125 on its own merits — but that is T-0125's own workflow's decision, not this run's, and I did not act on it unilaterally.

## Issues / risks
- **T-0126's commit hash is `<pending>`** in its own History entry, per protocol (the orchestrator or user fills this in at commit time). Not an error — flagged per the standard convention.
- **AC5 (cross-repo report to `aiqadam/ai-qadam-platform`'s `ISS-AUTH-OIDC-EMAIL-001.md`) status is unconfirmed.** The executor explicitly deferred this to the orchestrator and did not attempt `gh` access. Neither this landscape-updater pass nor any of the four input handoffs contain evidence of whether that report was ultimately posted. T-0126 was still closed `done` despite this, because AC5 is a cross-repo notification action, not a verification of the fix itself, and the task's core purpose (fix QA's Authentik provider) is independently confirmed complete — but the user should verify AC5 was actually done, or do it now, since it is not tracked by a task in this repo.
- **T-0125 (`AUTHENTIK_ADMIN_URL` on QA) now has strong live evidence of being fixed** (this run's Phase 0.5 found the correct value already in place), but T-0125 itself was left untouched per this run's scope boundaries (see "Files intentionally NOT updated" above). Recommend the user/orchestrator run a dedicated (lightweight) closure pass on T-0125 using this run's Phase 0.5 finding as corroborating evidence, rather than leaving it to drift indefinitely as `in-progress`.
- No FAIL-level conflicts were found between the validator's confirmed end state and the pre-existing landscape claims — the two landscape discrepancies (undocumented containers, stale hostname) were gaps/staleness, not contradictions requiring an unresolvable judgment call, so this update proceeded to PASS rather than halting.

## Open questions (optional)
none — all edits map directly to facts stated in step-06/step-07's verified findings; no speculative or unconfirmed facts were added to landscape.
