---
run_id: 2026-07-24-fix-deploy-qa-permission-001
step: 04
agent: solution-designer
verdict: PASS
created: 2026-07-24T00:00:00Z
task_id: T-0124-fix-deploy-qa-permission-denied
inputs_read:
  - runs/2026-07-24-fix-deploy-qa-permission-001/step-01-task-reader.md
  - runs/2026-07-24-fix-deploy-qa-permission-001/step-02-landscape-reader.md
  - runs/2026-07-24-fix-deploy-qa-permission-001/step-03-task-validator.md
  - workflows/cicd.md
  - shared/approval-protocol.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-qa.md
artifacts_changed: []
next_step_hint: Verdict is PASS — orchestrator skips step 05 and advances directly to executor-cicd (step 06). Executor must run PHASE A discovery first and select the matching PHASE B branch based on live findings; do not skip discovery and jump to a fix. Re-trigger deploy-qa per the Verification section once the fix is applied. Step 08 must also record the qa-uz.aiqadam.org -> qa.aiqadam.org hostname state and the advanced .last-deployed-commit in landscape/hosts/pro-data-tech-qa.md and landscape/services.md.
---

## Summary
Two-phase plan for the `deploy` operator: PHASE A runs six read-only SSH discovery commands against `pro-data-tech-qa` (95.46.211.230) to establish current file ownership, `deploy`'s group membership, git safe.directory state, and the deployed-commit marker; PHASE B is a decision tree that applies the minimal, precedent-consistent fix matching whatever PHASE A actually finds (re-chown to `tvolodi:tvolodi`, and/or re-add `deploy` to the `tvolodi` group, and/or re-add `safe.directory`), after which the plan re-triggers `deploy-qa` and checks five concrete success signals.

## Details

### Plan

**PHASE A — read-only discovery (run first, unconditionally)**

All commands run as an operator with SSH access to the host (`tvolodi`, `viktor_d`, or `binali_r` — each has NOPASSWD sudo per `landscape/hosts/pro-data-tech-qa.md` "Operator users"). Use `ssh tvolodi@95.46.211.230 "<command>"` (or the equivalent `ssh pro-data-tech-qa` alias, noting the landscape's caution that the workstation alias's `User tvolodi` is the intended path post-T-0097).

1. Confirm `deploy`'s current group membership — command: `ssh tvolodi@95.46.211.230 "id deploy"` — verification: capture full group list; compare against the T-0113 baseline (`deploy(999) deploy(981) docker(986) deploybots(982) aiqadam-qa-secrets(980)` plus, if the grant survived, `tvolodi`).
2. Inspect the two files implicated in the failing unlink — command: `ssh tvolodi@95.46.211.230 "ls -la /opt/apps/aiqadam-qa/package.json /opt/apps/aiqadam-qa/pnpm-lock.yaml"` — verification: capture owner, group, and mode bits for both files.
3. Inspect the top-level checkout directory for any other per-file ownership anomalies — command: `ssh tvolodi@95.46.211.230 "ls -la /opt/apps/aiqadam-qa/"` — verification: compare every entry's owner:group against the documented baseline (`tvolodi:tvolodi`, dir mode `775`, file mode `755`); flag any entry that diverges beyond the two named files.
4. Check whether `deploy`'s git safe.directory config persisted — command: `ssh tvolodi@95.46.211.230 "sudo -u deploy git config --get safe.directory"` — verification: expect output `/opt/apps/aiqadam-qa`; empty output or an error means the config was lost.
5. Read the on-host deployed-commit marker — command: `ssh tvolodi@95.46.211.230 "cat /opt/apps/aiqadam-qa/deploy/.last-deployed-commit"` — verification: capture the SHA; this is the "before" value for the Verification section's marker-advance check.
6. Compare the marker against the actual checkout HEAD — command: `ssh tvolodi@95.46.211.230 "git -C /opt/apps/aiqadam-qa log -1 --format=%H"` — verification: this should match step 5's marker if no interrupted/partial checkout occurred; a mismatch is itself a diagnostic signal worth noting (though not, on its own, part of the permission-denied root cause).

**PHASE B — conditional fix, selected from PHASE A's findings**

Apply only the branch(es) whose triggering condition PHASE A actually confirmed. Multiple branches may apply simultaneously (e.g., both the chown and the group re-grant may be needed).

- **Branch B1 — file-level ownership mismatch** (triggers if step A2 shows `package.json` and/or `pnpm-lock.yaml` owned by a user/group other than `tvolodi:tvolodi`, e.g. `root:root` or `deploy:deploy` from a prior manual/partial operation): command — `ssh tvolodi@95.46.211.230 "sudo chown tvolodi:tvolodi /opt/apps/aiqadam-qa/package.json /opt/apps/aiqadam-qa/pnpm-lock.yaml"` (extend the file list to any other anomalous entries step A3 surfaced, applying the same `tvolodi:tvolodi` target ownership) — verification: re-run `ls -la` on the affected files, confirm owner:group now reads `tvolodi:tvolodi`.
- **Branch B2 — group grant reverted** (triggers if step A1's `id deploy` no longer lists `tvolodi` among `deploy`'s groups): command — `ssh tvolodi@95.46.211.230 "sudo usermod -aG tvolodi deploy"` — verification: re-run `id deploy`, confirm `tvolodi` is present in the group list. (Note: group membership changes do not apply to already-open SSH sessions; the next `deploy-qa` invocation opens a fresh SSH session as `deploy`, so no service restart is needed for this to take effect.)
- **Branch B3 — safe.directory config lost** (triggers if step A4 returns empty or errors): command — `ssh tvolodi@95.46.211.230 "sudo -u deploy git config --global --add safe.directory /opt/apps/aiqadam-qa"` — verification: re-run `sudo -u deploy git config --get safe.directory`, confirm it returns `/opt/apps/aiqadam-qa`.
- **Branch B4 — something else entirely** (PHASE A reveals a finding not covered by B1–B3, e.g. a SELinux/AppArmor deny, a filesystem mounted read-only, an ACL entry not on record, or the checkout itself relocated/re-cloned with different ownership scheme): **STOP. Do not improvise a fix.** Re-emit this step's verdict as `BLOCKED` with the specific finding recorded, so a human/orchestrator can decide the mechanism rather than the executor extending this plan unsupervised.

None of B1–B3 introduces a new access-control mechanism — each re-applies exactly the scheme the landscape already documents as the intended (if "unplanned") state from T-0113.

**Not part of this task's action plan (noted for follow-up only):** `sudo -u deploy git config core.sharedRepository group` (or `git config core.sharedRepository group` run once by an owner against the repo) would make all *future* files created by any `tvolodi`-group member group-writable by default, preventing this exact recurrence. This is a real improvement but changes `deploy.sh`'s underlying ownership assumptions more than a minimal fix does, and was not confirmed necessary by PHASE A at design time — captured under "Issues / risks" as a follow-up candidate, not executed here.

### Rollback

1. Undo B1 (if applied) — command: `ssh tvolodi@95.46.211.230 "sudo chown tvolodi:tvolodi /opt/apps/aiqadam-qa/package.json /opt/apps/aiqadam-qa/pnpm-lock.yaml"` — this restores the documented original owner; if B1's chown target was already `tvolodi:tvolodi` (i.e., B1 was a no-op re-application), rollback is simply re-stating the same command, which is idempotent and safe.
2. Undo B2 (if applied) — command: `ssh tvolodi@95.46.211.230 "sudo gpasswd -d deploy tvolodi"` — this is the exact reversal the landscape documents for the original T-0113 grant.
3. Undo B3 (if applied) — command: `ssh tvolodi@95.46.211.230 "sudo -u deploy git config --global --unset safe.directory"` (or edit `/home/deploy/.gitconfig` directly if multiple `safe.directory` entries exist and only this one must be removed) — reverses the config addition.
4. Undo a bad deploy result (if PHASE B's re-trigger deploys broken code, independent of the permission fix itself) — command: `ssh deploy@95.46.211.230 "deploy:$(cat /opt/apps/aiqadam-qa/deploy/.last-deployed-commit.previous)"` — this is `deploy.sh`'s own built-in rollback marker mechanism, unrelated to but compatible with the permission fix.

All four rollback actions are simple, previously-documented, single-command reversals with no data loss risk.

### Verification (for step 07)

- **On-host:**
  - `id deploy` shows `tvolodi` in the group list (post-fix state, if B2 was applied or was already true).
  - `ls -la /opt/apps/aiqadam-qa/package.json /opt/apps/aiqadam-qa/pnpm-lock.yaml` shows `tvolodi:tvolodi` ownership (post-fix state, if B1 was applied or was already true).
  - `sudo -u deploy git config --get safe.directory` returns `/opt/apps/aiqadam-qa` (post-fix state, if B3 was applied or was already true).
  - The re-triggered SSH deploy command (`ssh deploy@95.46.211.230 "deploy:<current main SHA>"`) exits `0`.
  - `cat /opt/apps/aiqadam-qa/deploy/.last-deployed-commit` on the host matches the current `aiqadam/ai-qadam-platform` `main` SHA (proof the checkout actually advanced past `af30beb`).
- **External:**
  - `https://qa.aiqadam.org/health` returns HTTP `200`.
  - `https://qa.aiqadam.org/` returns HTTP `200`.
  - `POST https://qa.aiqadam.org/api/v1/auth/register` with a well-formed body returns `302`, or a clean `400` with a `registration_failed`-shaped body — explicitly NOT a bare `500`.
  - Re-trigger mechanism: either `gh workflow run` / `gh run rerun` against the `deploy-qa` job in `aiqadam/ai-qadam-platform`, or the executor directly running `ssh deploy@95.46.211.230 "deploy:<current main SHA>"` using the aiqadam QA deploy key (named by reference only — see Resources used).

### Resources used

- **Secrets (by name):** none referenced by value. The executor will need SSH access equivalent to what `aiqadam/ai-qadam-platform`'s GitHub Actions uses to reach `deploy@95.46.211.230` — refer to this as "the aiqadam QA deploy key" (landscape name: the CI key `aiqadam-qa-deploy-ci`, GitHub secrets `QA_SSH_DEPLOY_KEY` / `QA_SSH_HOST_KEY`) if a specific credential must be named. No key value appears in this plan or should appear in any handoff file.
- **Files modified on host:** `/opt/apps/aiqadam-qa/package.json` (ownership only, conditionally), `/opt/apps/aiqadam-qa/pnpm-lock.yaml` (ownership only, conditionally), any other file PHASE A step 3 flags (ownership only, conditionally), `deploy`'s group memberships (conditionally, via `usermod`/`gpasswd`), `deploy`'s `~/.gitconfig` (conditionally, `safe.directory` entry).
- **Files modified in this repo (landscape/), to be applied at step 08:**
  - `landscape/hosts/pro-data-tech-qa.md` — record the PHASE A findings and whichever PHASE B branch(es) were applied; append a Change log row.
  - `landscape/services.md` — update the deployed git HEAD to the new post-fix commit and the verified-live hostname.
  - Both files should also reconcile the `qa-uz.aiqadam.org` → `qa.aiqadam.org` hostname state (per step 03's carry-forward note — the orchestrator's live check found `qa.aiqadam.org` responding; this task's own acceptance criteria use `qa.aiqadam.org` throughout) and the deployed-commit value (landscape's stale `dfd2a7c` vs. the task's `af30beb` vs. whatever current `main` actually is at execution time).
- **External APIs called:** GitHub Actions API in `aiqadam/ai-qadam-platform` (to re-trigger `deploy-qa`, if that path is chosen over a direct SSH deploy command).

### Estimated impact

- **Downtime:** none expected from PHASE B's chown/group/gitconfig changes themselves (no service restart, no container recreate). The subsequent re-triggered deploy carries the normal `docker compose up -d --build` deploy downtime already accepted by the existing, working `deploy.sh` flow (typically seconds, per the T-0113 rehearsal precedent) — this is inherent to any deploy-qa run, not an additional risk introduced by this fix.
- **Affected services:** `aiqadam-qa` Compose project (`aiqadam-qa-api-1`, `aiqadam-qa-oidc-stub-1`) on `pro-data-tech-qa` only. No other host, no other Compose project, no prod system touched.
- **Reversibility:** fully reversible. Every PHASE B branch has a documented, single-command, previously-precedented rollback (see Rollback section); none deletes data or rotates credentials.

## Issues / risks

- PHASE A may reveal a combination of B1+B2+B3 simultaneously, or a finding matching none of B1–B3 (Branch B4). The executor must not skip discovery and must not invent a fix outside B1–B3 without escalating — this is deliberate: a genuinely novel finding should not be auto-approved against a plan that didn't anticipate it.
- The landscape (`pro-data-tech-qa.md`) and the task (T-0124) disagree on both the current public hostname (`qa-uz.aiqadam.org` vs. `qa.aiqadam.org`) and the last-known deployed commit (`dfd2a7c` vs. `af30beb`). Per step 03's carry-forward instruction, the orchestrator's own live check already resolved the hostname question in favor of `qa.aiqadam.org` (confirmed responding, with a corroborating runbook note of a 2026-07-18 rename) — this plan uses `qa.aiqadam.org` throughout and defers the landscape correction to step 08, where it belongs. This is not a new open question for step 04; it is a known discrepancy queued for the landscape-updater.
- A more durable alternative — `git config core.sharedRepository group` on the repo, so all future files created by any `tvolodi`-group member are automatically group-writable — would likely prevent this exact class of recurrence. It is deliberately **not** included as part of this task's action plan: it changes `deploy.sh`'s underlying ownership assumptions (a design decision) rather than restoring the already-agreed-upon T-0113 scheme, and PHASE A has not yet confirmed it's necessary. Recommend filing this as a follow-up task once PHASE A's findings are in hand, especially if PHASE A shows the same drift pattern recurring (vs. a one-off).
- No landscape record exists of any deploy attempt between 2026-07-17 and today, so the exact mechanism of drift (manual `pnpm install` as `tvolodi`, a partially-interrupted deploy, or the group grant simply never having been durable across a session/reboot) cannot be determined from files alone — this is exactly why PHASE A must run and be interpreted before PHASE B executes, rather than assuming Branch B1 or B2 in isolation.
- Blast radius is confined to one host's one application directory (`/opt/apps/aiqadam-qa/`), touches no DNS/firewall/secrets/OS packages, and every state-changing action has a same-command rollback already precedented in the landscape. This matches the task file's own declared `estimated_blast_radius: low` / `estimated_reversibility: full`, and no step in this plan is irreversible — supporting the `PASS` verdict below.

## Open questions (optional)
none — verdict is PASS.
