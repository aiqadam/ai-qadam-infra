---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-14T00:00:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
inputs_read:
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md
  - tasks/T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod.md
  - tasks/_index.md
  - workflows/README.md
artifacts_changed: []
next_step_hint: landscape-reader should load landscape/hosts/pro-data-tech-qa.md, landscape/hosts/pro-data-tech-prod.md, landscape/secrets-inventory.md, and shared/app-registry.md to confirm current deploy-user/directory state on both hosts before design.
---

## Summary
Task T-0112 asks for two dedicated ed25519 SSH deploy keypairs (one for QA, one for prod) to be provisioned so GitHub Actions can SSH into `pro-data-tech-qa` and `pro-data-tech-prod` to run deploy commands, with the private keys stored only as GitHub Actions repository secrets and the key names (not values) recorded in this repo's secrets inventory.

## Details

- **Title:** Provision GitHub Actions SSH deploy keys for aiqadam QA and prod hosts
- **Workflow:** infrastructure (matches [workflows/infrastructure.md](../../workflows/infrastructure.md), confirmed to exist)
- **Why** (quoted verbatim from the task): "GitHub Actions needs to SSH into `pro-data-tech-qa` and `pro-data-tech-prod` to run deploy commands (`git pull`, `docker compose up`). Per the user's decision, this uses a per-host SSH deploy key rather than a self-hosted runner. Keys must be dedicated to CI (not reused from the `tvolodi` management key) so they can be scoped and rotated independently, and restricted to only what the deploy step needs."

- **Full acceptance criteria ("What done looks like"), verbatim:**
  1. One ed25519 keypair generated for QA deploys, one for prod deploys (two separate keypairs — do not reuse across environments)
  2. Public keys installed in `authorized_keys` for a dedicated low-privilege deploy user on each host (recommend a new `deploy` system user scoped to the app directory + docker group, NOT the `tvolodi`/`viktor_d`/`binali_r` operator accounts) — OR, if the user prefers, restricted via `authorized_keys` `command=` forced-command + `no-port-forwarding,no-X11-forwarding,no-agent-forwarding` options limiting the key to the exact deploy script path
  3. Private keys added as GitHub Actions repository secrets in `aiqadam/ai-qadam-platform` (e.g. `QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`) — this repo (`ai-qadam-infra`) never stores the private key value; secret values live in external storage only, referenced by name in `landscape/secrets-inventory.md`
  4. Host public keys (known_hosts entries) recorded as GitHub Actions secrets too (`QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`) so the workflow can pin `known_hosts` instead of disabling strict host key checking
  5. `landscape/secrets-inventory.md` updated with secret NAMES only (never values): `aiqadam-qa-deploy-ssh-key`, `aiqadam-prod-deploy-ssh-key`
  6. Verify from a throwaway local SSH test that each key logs in successfully and can run `docker compose` commands (or the forced-command equivalent) before marking done

- **Affected landscape files (`affects:`):**
  - [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md)
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md)
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md)

- **Blast radius / reversibility (from task frontmatter):** `estimated_blast_radius: medium`, `estimated_reversibility: full`. Adding a new deploy user + authorized_keys entry is additive on both hosts; nothing existing (operator accounts, Penpot on prod, the app stacks from T-0110/T-0111) is modified. Fully reversible by deleting the user/key.

- **Task's own recommendation on the two open design questions** (solution-designer, step 04, must propose these and let the user confirm/override — not decide silently):
  - **Forced-command vs general shell login:** task Notes recommend a forced-command `authorized_keys` restriction (`command="/opt/apps/aiqadam-<env>/deploy/deploy.sh"` plus `no-port-forwarding,no-X11-forwarding,no-agent-forwarding`) over a general-purpose shell login, for defense-in-depth — if the CI key leaks, it can only run the deploy script, not arbitrary commands.
  - **Dedicated `deploy` user vs. reusing an operator account:** task's Open Questions section recommends a dedicated low-privilege `deploy` system user (scoped to the app directory + docker group) rather than reusing `tvolodi`/`viktor_d`/`binali_r` — keeps CI's blast radius separate from human operator accounts and makes revocation trivial (delete the user / remove the key) without touching human access.
  - Prod key should almost certainly NOT have passwordless sudo — the deploy script should only need `docker compose` commands within a directory the deploy user already owns.

- **Checkout paths this task depends on** (populated by the two predecessor tasks, both `status: done`):
  - QA: `/opt/apps/aiqadam-qa/` on `pro-data-tech-qa` (95.46.211.230) — git HEAD `dfd2a7c`, Compose project `aiqadam-qa` (`deploy/docker-compose.qa.yml`), app port `127.0.0.1:3113`.
  - Prod: `/opt/apps/aiqadam-prod/` on `pro-data-tech-prod` (95.46.211.224) — pinned to `dfd2a7c` detached HEAD, Compose project `aiqadam-prod` (`docker-compose.prod.yml`), app port `127.0.0.1:3115`. This host also runs a pre-existing, live Penpot stack under `/opt/penpot/` — any deploy-user/docker-group work here must not touch that.

- **Dependency check:** `blocked_by: [T-0110, T-0111]` — both confirmed `status: done`, `outcome: succeeded` in `tasks/_index.md` and their own files. No blocker remains. `blocks: [T-0113]` (the GitHub Actions workflow file itself, which will consume the secrets this task creates).

- **Task well-formedness confirmed:**
  - Has a non-empty "Why" section. ✓
  - Has a non-empty "What done looks like" checklist (6 items, all currently unchecked `[ ]`). ✓
  - `workflow: infrastructure` matches an existing workflow file at [workflows/infrastructure.md](../../workflows/infrastructure.md). ✓
  - `blocked_by: [T-0110, T-0111]` both `status: done`. ✓
  - `status: in-progress`, `executed_by_runs` already includes `2026-07-14-ssh-deploy-keys-aiqadam-001` (transitioned by orchestrator before this step ran). ✓

## Issues / risks
- The private key material and the GitHub repository secrets step (item 3/4) require GitHub access (`aiqadam/ai-qadam-platform` repo secrets) that is outside this repo's own managed-host tooling — solution-designer/executor will need to confirm how GitHub secret-setting is actually performed (`gh secret set` via CLI, or manual instruction to the user) since this repo's hard rule is that it never stores secret values itself.
- Two open design decisions (forced-command vs shell login; dedicated user vs operator reuse) are flagged by the task itself as needing explicit user confirmation, not silent executor judgment — likely drives a `NEEDS_APPROVAL` verdict at step 04 given medium blast radius and touching two hosts (one of which, prod, already carries a live Penpot workload).
- Task's Notes flag sequencing intent: deploy user/directory must already exist on both hosts before keys pointing at them make sense — confirmed satisfied since T-0110/T-0111 are done.

## Open questions
none — task is clear and unblocked; the two open design questions above are for step 04 (solution-designer) to propose and the user to confirm, not blockers to reading the task.
