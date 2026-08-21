---
run_id: 2026-08-21-provision-rules-downloads-qa-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-08-21T06:30:00Z
task_id: T-0141-provision-rules-source-file-downloads-qa
inputs_read:
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-01-task-reader.md
  - runs/2026-08-21-provision-rules-downloads-qa-001/step-02-landscape-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - shared/app-registry.md
  - tasks/T-0141-provision-rules-source-file-downloads-qa.md
  - workflows/deploy-app.md
  - workflows/_common-operations.md
artifacts_changed: []
next_step_hint: Validated. The scp prerequisite is in-scope for this task and belongs in the step-04 plan as its own phase. Two items the designer must resolve before planning execution — the public Directus origin (potential scope expansion) and an authored-from-scratch rollback. Expect NEEDS_APPROVAL only if the Directus-origin question turns into an nginx change.
---

## Summary

Validated — the task names a concrete, verifiable end state, fits the `deploy-app` workflow, is confirmed not-already-done, contradicts nothing in the landscape, and its one genuine unknown (whether Directus is publicly reachable) is a design-time discovery item rather than a validation blocker; the `scp` prerequisite is judged **in-scope for this task** and should be planned as its own phase.

## Details

### Bearing of the pre-flight facts on this validation

The orchestrator's live pre-flight supplied five facts that the committed landscape does not contain. Step 02 correctly flagged each of these as a gap and refused to guess. They are treated here as given, and each **closes** a gap that would otherwise have counted against check 5:

| Pre-flight fact | Gap it closes (from step 02) |
|---|---|
| FR-CMS-008 code present on the QA checkout at `/opt/apps/aiqadam-qa/` — 8 `source_file` refs in `bootstrap.sh`, 5 `PUBLIC_ASSET_FOLDER_ID` refs in the seed script; checkout at `84cfd4d` | Gap 5 (checkout freshness) |
| `git merge-base --is-ancestor` against the pre-squash branch SHA gives a **false negative** — that SHA does not exist in `main` after a squash-merge; the grep-for-actual-code check is the reliable one | Methodological — pre-empts a false BLOCKED at execution time |
| `/opt/apps/aiqadam-qa/portal-content/` does not exist on the QA host; the 5 `.docx` are absent; gitignored so never deployed | Gap 4, partially — confirms the target state is *not* already in place |
| User decision: `scp` the 5 files from `c:\Users\tvolo\dev\ai-dala\aiqadam\portal-content\20260819\`; not committing to git, not uploading directly to Directus | Resolves the delivery-method ambiguity that would otherwise be a `BLOCKED`-class user-input question |
| Directus port on QA is **3119**; the `directus` database is a **separate DB** in the `ai-qadam-test-db-1` cluster; `DIRECTUS_ADMIN_TOKEN` in `/opt/apps/aiqadam-qa/deploy/.env`, rotated 2026-08-20 (T-0137) | Gaps 1 and 2 |

Two of step 02's seven gaps remain genuinely open after the pre-flight: **gap 3** (the public Directus origin — the consequential one) and **gap 7** (no Directus rollback precedent). Both are design-time work, not missing user input, which is why this validates `PASS` rather than `BLOCKED`.

Note that `3119` sits at the top of the documented `127.0.0.1:3110-3119` reserved test-app range recorded in `shared/app-registry.md` — the pre-flight value is consistent with the landscape's own port convention, which is a mild independent corroboration.

### Validation results

**1. Well-formed: PASS**

The task names a concrete, machine-verifiable end state rather than an intent. Its eight acceptance criteria are framed as observable outcomes, and — unusually — the task explicitly identifies which criterion is the *real* signal: AC-4's anonymous `GET /assets/<id>?download` returning 200 with `Content-Disposition: attachment` preserving the filename, with the task stating outright that a non-null `source_file` is "not merely" sufficient. It also carries a negative criterion (AC-5: assets outside `public-documents` still 403; anonymous `GET /files` does not enumerate) that guards against passing via an over-broad grant. That is a well-formed specification: it can fail, and it can fail for the right reasons.

The task also states its own STOP condition (any new unexpected modification to a pre-existing collection during `bootstrap.sh`) and its load-bearing ordering constraint (bootstrap before seed, because the reverse produces uploaded-but-unreadable assets). Both are precise enough to be executed against.

**2. In-scope: PASS, with a noted awkwardness**

`deploy-app` is the workflow the task file declares, and it is the correct family — this is an operation against a deployed application environment on a managed host, using scripts that live in the app repo. Step 02 is right that much of the workflow's core machinery is inapplicable: no image is built, no container recreated, no app code moves, and the image-tag rollback model does not fit a schema+content change. Phase 0's local→GitHub→host sync check is a genuine no-op (the code is already on the host at `84cfd4d`).

This does not make the workflow wrong. Its binding requirements — script-first execution, an explicit rollback command in the plan, a step-07 health check, landscape write-back at step 08 — all apply and are all satisfiable. No other workflow fits better: `infrastructure` is for hosts/networking/certs, and the read-only discovery/audit workflows are excluded by `state_changing`. The designer should declare Phase 0 an explicit no-op with its reason, rather than skipping it silently, and should not force-fit image-tag rollback.

One workflow requirement needs care: `deploy-app`'s "App registration requirement" says the task-validator MUST return `BLOCKED` if the app's setup task is not `status: done`. The relevant setup task, T-0110, is `done` (2026-07-13), and the app is listed in `shared/app-registry.md`. That gate is satisfied. Separately, the workflow's "Script-first execution model" directs the designer to the app's `Scripts` table — which does not exist in the registry. As step 02 notes, the *spirit* is satisfied since the operation is driven by two scripts versioned in the app repo; the registry simply fails to record them. That is a registry-completeness defect, not a blocker on this task.

**3. Not already done: PASS**

Confirmed on both halves. The landscape contains **zero** references to `portal-content/`, `public-documents`, `PUBLIC_ASSET_FOLDER_ID`, `source_file`, or any anonymous `directus_files` grant — grep across `landscape/` returns nothing. The pre-flight confirms live that `/opt/apps/aiqadam-qa/portal-content/` does not exist on the host. And the task records the current user-visible state as verified live post-merge on 2026-08-21: `qa.aiqadam.org/rules/manifesto` shows the filename as plain text with no download link.

The partial-overlap case is worth stating precisely, because it shapes the expected delta. T-0136 already ran **both** of these scripts against this instance yesterday, and the 5 `content_documents` rows already exist and render. So this run is not creating those rows — it is adding a `source_file` column, a relation, a folder, a grant, and 5 file attachments *to rows that are already present*. The seed script's row-upsert half should therefore be a near-total no-op, and only its upload-and-attach half should do work. An executor that expects to see 5 rows created is looking for the wrong signal.

**4. No conflict with current state: PASS**

Nothing in the task contradicts an explicit landscape fact about the host. The change is additive (a field, a relation, a folder, a grant, 5 files), touches no credential, requires no container restart, and opens no port — UFW's existing 22/80/443 suffices.

One apparent conflict is real but already adjudicated: `shared/app-registry.md`'s QA row asserts as a "Scope decision" that "Directus-CMS-backed routes are NOT deployed here… non-functional in this environment by design." That would contradict this entire task. But `landscape/hosts/pro-data-tech-qa.md` explicitly supersedes it — "as of 2026-07-27, Directus-CMS-backed routes and Authentik-backed OIDC login are both live in this environment" — and T-0136 proved it empirically by serving `/rules` from Directus yesterday. The host file is the authoritative landscape source and wins; the registry is 35 days stale. Not a conflict with current state, but a conflict *within the documentation*, which is why it is carried in Issues.

The one genuine unknown — whether Directus is publicly reachable — is an absence in the landscape rather than a contradiction of it, so it belongs to check 5.

**5. Discoverable scope: PASS**

Of step 02's seven gaps, five are now closed by the pre-flight (see the table above). The two that remain are both resolvable by the designer at design time using tools available to that step, with no user input required:

- **Gap 3, the public Directus origin.** This is the consequential one. AC-4 and AC-6 require an anonymous *external* 200 on `/assets/<id>`, and the landscape records only one QA vhost (`qa.aiqadam.org` → api on `3113`). The pre-flight's `3119` is a *loopback* port on a host-networked container; a loopback port is not by itself an external route. Whether an nginx vhost fronts Directus is discoverable in one command against `/etc/nginx/sites-enabled/`. The landscape does establish the precedent that this host fronts host-networked containers with additional vhosts the inventory does not fully enumerate — `auth.qa.aiqadam.org` reaches Authentik, which is likewise `network_mode: host` with "no published ports" — so a Directus vhost plausibly exists. But plausible is not confirmed, and this must be settled **before** planning execution, not discovered at execution time. See Open questions for the branch where it becomes a scope change.
- **Gap 7, no Directus rollback precedent.** `deploy-app` requires an exact rollback command in the plan, and the landscape offers nothing to copy. The designer must author one (plausibly: revoke the anonymous grant first, then delete the uploaded files and the `public-documents` folder, then drop the `source_file` field and relation). This is authorship, not discovery — the information needed is entirely in the scripts. Note the security-relevant asymmetry: the *grant* is the half whose reversal matters most, and it should be first to revert.

No critical unknown remains that would require the designer to guess at a fact only the user or the live system can supply. Hence PASS.

**6. Workflow-specific rules respected: PASS**

- *App registration requirement* — satisfied: app listed in `shared/app-registry.md`; setup task T-0110 `status: done`.
- *Task file requirement* (`_common-operations.md`) — satisfied: `T-0141` exists, `status: in-progress`, run appended to `executed_by_runs`, History entry present.
- *Phase 0 (local → GitHub → host)* — satisfiable as a documented no-op: the FR-CMS-008 code is already on the host checkout at `84cfd4d`; nothing needs committing or pushing. The infra repo's own working tree is a separate matter handled at run finalization.
- *Script-first execution* — satisfiable: the operation is exactly the invocation of two versioned scripts in the app repo. The absent registry `Scripts` table is a registry defect to note, not an obstacle.
- *Rollback command required in the plan* — satisfiable, but must be authored from scratch (see check 5).
- *Health check at step 07* — satisfiable, with a correction the validator must carry forward: `deploy-app` instructs step 07 to read the health endpoint from `shared/app-registry.md`, whose value is the **retired** `https://qa-uz.aiqadam.org/health`. The correct current endpoint is `https://qa.aiqadam.org/health` per `landscape/services.md` and the host file. Following the workflow literally here would health-check a dead hostname.
- *Landscape write-back at step 08* — satisfiable; `affects:` names `landscape/hosts/pro-data-tech-qa.md`.

### Scope ruling on the `scp` prerequisite

**Ruling: in-scope for T-0141, to be planned as an explicit first phase of the step-04 plan. It does not need a separate task.**

The question is fair to raise, because the `scp` is a state-changing action on the QA host that is neither of the two scripts the user named, and it writes a new untracked directory into an application checkout. Four reasons it nonetheless belongs here:

1. **The task file already scopes it.** AC-1 is written as a prerequisite acceptance criterion — "**(prerequisite, confirmed missing 2026-08-21)** The 5 source `.docx` files are present at `/opt/apps/aiqadam-qa/portal-content/20260819/`" — and the task body records the delivery decision, its date, and its accepted trade-off. This is not an unplanned discovery being smuggled into execution; it is a criterion the task's author already committed to.
2. **The user has already decided the method.** The alternatives (commit to git; upload directly to Directus) were considered and rejected on the record. Splitting this into its own task would re-litigate a settled decision and add a workflow round-trip for a file copy.
3. **It does not raise the blast radius.** Copying 5 files into a new, untracked, previously-nonexistent directory inside a checkout owned by `tvolodi` overwrites nothing, touches no running container, and is reversed by `rm -rf` of a directory that did not exist before. It is comfortably within the task's declared `low`/`full` envelope — arguably the least risky action in the plan.
4. **The task is incoherent without it.** The seed script skips uploads non-fatally when the source directory is absent. Running T-0141 without the files would produce a green-looking run that achieves nothing. A separate task would leave this one permanently blocked on its own prerequisite.

Four conditions the designer must attach to that phase:

- **Copy exactly the 5 named files, not the directory.** The workstation source holds 15 files plus a `pdf/` subdirectory — PDFs, PPTXs, an HTML, a `.doc`, and a `factsheet` `.docx` that is *not* one of the 5. A recursive copy would push roughly 13 MB of unrelated binaries onto the host. The 5, exactly as the seed script names them: `AI Qadam Manifesto.docx`, `AI Qadam Charter v0 1.docx`, `AI_Qadam_Kazakhstan_MoU-2105 (3).docx`, `AI Qadam Global Board Положение (2).docx`, `AI Qadam Soglashenie v1 (2).docx`.
- **Verify byte-exact filenames after the copy, before running the seed.** Three of the five contain spaces, parentheses, or Cyrillic; the transfer crosses Windows→Linux. Because the seed script skips missing files non-fatally, a mangled name yields a silent partial success. The check must assert 5 files with the expected names (and ideally matching sizes), not merely that the directory exists.
- **Record the non-reproducibility in the landscape at step 08.** After this run, QA's `/rules` downloads depend on host-local files present in no repository. A host rebuild silently regresses the feature. The task itself flags this; step 08 must carry it into `landscape/hosts/pro-data-tech-qa.md` so the dependency is discoverable by someone who was not in this run.
- **Note the `git clean` dependency.** `deploy.sh` never runs `git clean`, which is what lets an untracked `portal-content/` survive future deploys — but per the landscape that guarantee rests on a comment in the script's own header, not a technical control. Worth stating in the plan as a known fragility.

## Issues / risks

- **The public-Directus-origin question is the one thing that could change this task's shape.** If no nginx vhost fronts Directus, AC-4 and AC-6 are unsatisfiable without an nginx change that T-0141 did not scope or blast-radius, and whose `affects:` list does not anticipate. Must be settled at design time. See Open questions.
- **`shared/app-registry.md` is 35 days stale and actively misleading** on three points for this environment: it claims 2 services (there are 7), names the retired `qa-uz.aiqadam.org` health endpoint, and asserts Directus is not deployed here. Since `deploy-app` treats the registry as authoritative for ports/paths/health endpoints, a downstream agent trusting it would design against an environment that no longer exists. The host file supersedes it on every point. Recommend a follow-up task; correcting it is outside T-0141's `affects:` list.
- **Step-07 must not follow `deploy-app`'s health-check rule literally** — the registry endpoint it points to is a dead hostname. Use `https://qa.aiqadam.org/health`.
- **Secret-handling is a hard constraint with two same-week precedents on this exact credential family.** Never combine `grep -B/-A` with `-v` on any file; inline-substitute the token within a single SSH session; verify by status code, count, or digest only. Two additional traps the landscape supplies: a `.env` backup containing the **old** values sits on-host at `deploy/.env.pre-T0137.<timestamp>.bak`, so any glob or directory-wide inspection of `deploy/` risks surfacing it — extract one named key precisely; and **two** admin tokens (`DIRECTUS_ADMIN_TOKEN`, `DIRECTUS_TOKEN`) currently hold identical values, so reading the wrong key authenticates fine today and fails silently after any future desync. Read exactly `DIRECTUS_ADMIN_TOKEN`.
- **A 403 during this run most likely means "does not exist," not "no permission."** T-0136 burned six attempts on this exact instance chasing a phantom RBAC problem; the Administrator policy always had genuine `admin_access: true`. Directus's message reads "...or it does not exist," and the second half was the true one throughout. Check existence before concluding permissions.
- **`bootstrap.sh` carries a full-schema surface with an armed STOP condition.** T-0136 exercised it once here and confirmed no-op across ~77 collections, so the expected delta is genuinely just the FR-CMS-008 additions. The `F-S2.12 operator_invites` field-drop block already applied yesterday and should now be a no-op; if it reappears as an active change, that is a signal worth stopping on, not a repeat of a known-benign event.
- **The seed script's non-fatal skip is the main silent-failure mode in this run.** Combined with the fact that the 5 rows already exist from T-0136, a run can plausibly report success while attaching zero files. The verdict must rest on AC-4's anonymous 200, never on exit codes.
- **Any DB-level verification must use the corrected network method.** A throwaway client on the named bridge `ai-qadam-test_default`, connecting by container name (`-h ai-qadam-test-db-1`). `--network container:ai-qadam-test-db-1` does not work — it shares the target's own namespace and yields "connection refused" rather than an auth result. This exact error was in T-0138's *approved* plan and had to be corrected mid-run. Note also that Directus reaches Postgres over `127.0.0.1:3112` under `trust` in `pg_hba.conf`, so its own connection is not password-authenticated — relevant if any DB-level check is contemplated.
- **The rollback must be authored, not copied**, and the anonymous grant should be the first thing reverted, since an over-broad or orphaned grant is the security-relevant residue.
- **Process precedent worth heeding (T-0140):** the T-0138 executor stalled mid-run after a state-changing action without writing a handoff, leaving a container crash-looping. A clean `BLOCKED` is always preferable to a silent stall after a state change.

## Open questions

- **Is Directus reachable anonymously from outside the host, and at what origin?** The pre-flight's `3119` is a loopback port on a host-networked container, which is not by itself an external route. If a vhost fronts it, this is a plain discovery item and the plan proceeds unchanged. If none exists, AC-4/AC-6 require an nginx vhost + TLS change — a scope expansion beyond T-0141's declared `low` blast radius and its `affects:` list, which should be escalated to the user as a scope decision rather than absorbed into the plan. **The designer must resolve this before planning execution.** If it does become an nginx change, step 04 should emit `NEEDS_APPROVAL` rather than self-approving.
- **Should the stale `shared/app-registry.md` AiQadam QA row be corrected in this run or filed separately?** It contradicts the host file on whether Directus exists in this environment at all. T-0141's `affects:` names only the host file, which argues for a separate follow-up — but leaving a registry that `deploy-app` treats as authoritative asserting "Directus is not deployed here" is a live trap for the next run that touches this host.
