---
id: T-0112-github-actions-ssh-deploy-keys-aiqadam
title: Provision GitHub Actions SSH deploy keys for aiqadam QA and prod hosts
kind: task
status: done
priority: P1
created: 2026-07-12
updated: 2026-07-17
closed: 2026-07-17
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-14-ssh-deploy-keys-aiqadam-001]
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
workflow: infrastructure
blocks: [T-0113]
blocked_by: [T-0110, T-0111]
related: []
estimated_blast_radius: medium
estimated_reversibility: full
---

# Provision GitHub Actions SSH deploy keys for aiqadam QA and prod hosts

## Why
GitHub Actions needs to SSH into `pro-data-tech-qa` and `pro-data-tech-prod` to run deploy commands (`git pull`, `docker compose up`). Per the user's decision, this uses a per-host SSH deploy key rather than a self-hosted runner. Keys must be dedicated to CI (not reused from the `tvolodi` management key) so they can be scoped and rotated independently, and restricted to only what the deploy step needs.

## What done looks like
- [x] One ed25519 keypair generated for QA deploys, one for prod deploys (two separate keypairs — do not reuse across environments)
- [x] Public keys installed in `authorized_keys` for a dedicated low-privilege deploy user on each host (recommend a new `deploy` system user scoped to the app directory + docker group, NOT the `tvolodi`/`viktor_d`/`binali_r` operator accounts) — OR, if the user prefers, restricted via `authorized_keys` `command=` forced-command + `no-port-forwarding,no-X11-forwarding,no-agent-forwarding` options limiting the key to the exact deploy script path
- [x] Private keys added as GitHub Actions repository secrets in `aiqadam/ai-qadam-platform` (`QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`) — **this repo (`ai-qadam-infra`) never stores the private key value; per project hard rule, secret values live in external storage only, referenced by name in `landscape/secrets-inventory.md`** — set via `gh secret set` 2026-07-17, confirmed present via `gh secret list` (names/timestamps only)
- [x] Host public keys (known_hosts entries) recorded as GitHub Actions secrets too (`QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`) so the workflow can pin `known_hosts` instead of disabling strict host key checking — set via `gh secret set` 2026-07-17, confirmed present via `gh secret list`
- [x] `landscape/secrets-inventory.md` updated with secret NAMES only (never values): `aiqadam-qa-deploy-ssh-key`, `aiqadam-prod-deploy-ssh-key`
- [x] Verify from a throwaway local SSH test that each key logs in successfully and can run `docker compose` commands (or the forced-command equivalent) before marking done — live end-to-end SSH test + negative control both PASS on both hosts (run 2026-07-14-ssh-deploy-keys-aiqadam-001, step-07 execution-validator, independently re-verified)

## Notes
- This task deliberately sits between the two setup tasks (T-0110, T-0111) and the GitHub Actions workflow file (T-0113) — the deploy user/directory must exist on both hosts before keys pointing at them make sense.
- Recommend a forced-command approach (`authorized_keys` `command="/opt/apps/aiqadam-<env>/deploy/deploy.sh"`) over a general-purpose shell login for defense-in-depth — if the CI key leaks, it can only run the deploy script, not arbitrary commands. Solution-designer should propose this and let the user confirm/override.
- Prod key should almost certainly NOT have passwordless sudo — the deploy script should only need `docker compose` commands within a directory the deploy user already owns.

## Open questions
- **Dedicated `deploy` user vs. reusing an existing operator account with a restricted key?** Recommend a dedicated user — keeps CI's blast radius separate from human operator accounts and makes revocation trivial (delete the user / remove the key) without touching human access.

## Result
On-host provisioning: dedicated `deploy` system user (uid 999, shell `/bin/bash`, locked down entirely via SSH forced-command — `command=`,`no-pty`,`no-port-forwarding`,`no-X11-forwarding`,`no-agent-forwarding` in `authorized_keys`, not by shell restriction) created on both `pro-data-tech-qa` and `pro-data-tech-prod`. Two dedicated ed25519 keypairs generated, installed, and live end-to-end SSH tested (including a genuine negative-control proof that arbitrary command injection is blocked). `deploy` granted read access to each host's `deploy/.env` via a dedicated per-environment secrets group (permission bits only; content never read, written, or logged at any point). GitHub Actions repository secrets (`QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`) set in `aiqadam/ai-qadam-platform` via `gh secret set`, confirmed present via `gh secret list`.

Took 4 execution attempts (see `runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/` for the 3 failed/rolled-back attempts): attempt 1 failed cleanly on a `.env` permission gap; attempt 2's own verification command produced a false negative and an off-plan diagnostic briefly exposed the QA Postgres password in the session transcript (user decided not to rotate; fully disclosed, fully rolled back); attempt 3 got through all but the final live-SSH step, blocked by an incompatible `nologin` shell choice; attempt 4 passed cleanly end-to-end on both hosts with no rollback needed. Deviations from the original plan: the `deploy` user's shell was changed from the originally-designed `/usr/sbin/nologin` to `/bin/bash` (nologin is incompatible with SSH forced-command execution on this host's sshd/PAM build; `authorized_keys`' `command=`/`no-pty` restrictions are the actual and sufficient lockdown).

Handoffs: [step-06-executor-infra.md](../runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-06-executor-infra.md) (4th attempt, PASS) · [step-07-execution-validator.md](../runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-07-execution-validator.md) (independent PASS) · [step-08-landscape-updater.md](../runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-08-landscape-updater.md)

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain
- 2026-07-14: status → in-progress, run 2026-07-14-ssh-deploy-keys-aiqadam-001
- 2026-07-17: on-host provisioning complete and verified (run 2026-07-14-ssh-deploy-keys-aiqadam-001, 4th execution attempt after 3 failed/rolled-back attempts documented in `.attempts/`) — `deploy` user, `deploybots` group, `aiqadam-<env>-secrets` groups, forced-command SSH keys, and placeholder `deploy.sh` live and verified on both pro-data-tech-qa and pro-data-tech-prod (step-07 execution-validator PASS, independently re-verified). status remained in-progress: remaining blocker was the manual GitHub Actions repository secrets paste, outside this repo's tooling scope.
- 2026-07-17: status → done, outcome succeeded. All four secrets (`QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`) set in `aiqadam/ai-qadam-platform` via `gh secret set` at the user's explicit request, reading directly from local key files (no value passed through chat). Confirmed present via `gh secret list`. T-0113 (author the CI/CD workflow file) is now unblocked.
