---
id: T-0112-github-actions-ssh-deploy-keys-aiqadam
title: Provision GitHub Actions SSH deploy keys for aiqadam QA and prod hosts
kind: task
status: in-progress
priority: P1
created: 2026-07-12
updated: 2026-07-14
closed:
outcome:
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
- [ ] One ed25519 keypair generated for QA deploys, one for prod deploys (two separate keypairs — do not reuse across environments)
- [ ] Public keys installed in `authorized_keys` for a dedicated low-privilege deploy user on each host (recommend a new `deploy` system user scoped to the app directory + docker group, NOT the `tvolodi`/`viktor_d`/`binali_r` operator accounts) — OR, if the user prefers, restricted via `authorized_keys` `command=` forced-command + `no-port-forwarding,no-X11-forwarding,no-agent-forwarding` options limiting the key to the exact deploy script path
- [ ] Private keys added as GitHub Actions repository secrets in `aiqadam/ai-qadam-platform` (e.g. `QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`) — **this repo (`ai-qadam-infra`) never stores the private key value; per project hard rule, secret values live in external storage only, referenced by name in `landscape/secrets-inventory.md`**
- [ ] Host public keys (known_hosts entries) recorded as GitHub Actions secrets too (`QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY`) so the workflow can pin `known_hosts` instead of disabling strict host key checking
- [ ] `landscape/secrets-inventory.md` updated with secret NAMES only (never values): `aiqadam-qa-deploy-ssh-key`, `aiqadam-prod-deploy-ssh-key`
- [ ] Verify from a throwaway local SSH test that each key logs in successfully and can run `docker compose` commands (or the forced-command equivalent) before marking done

## Notes
- This task deliberately sits between the two setup tasks (T-0110, T-0111) and the GitHub Actions workflow file (T-0113) — the deploy user/directory must exist on both hosts before keys pointing at them make sense.
- Recommend a forced-command approach (`authorized_keys` `command="/opt/apps/aiqadam-<env>/deploy/deploy.sh"`) over a general-purpose shell login for defense-in-depth — if the CI key leaks, it can only run the deploy script, not arbitrary commands. Solution-designer should propose this and let the user confirm/override.
- Prod key should almost certainly NOT have passwordless sudo — the deploy script should only need `docker compose` commands within a directory the deploy user already owns.

## Open questions
- **Dedicated `deploy` user vs. reusing an existing operator account with a restricted key?** Recommend a dedicated user — keeps CI's blast radius separate from human operator accounts and makes revocation trivial (delete the user / remove the key) without touching human access.

## History
- 2026-07-12: created manually by orchestrator as part of the AiQadam CI/CD pipeline task chain
- 2026-07-14: status → in-progress, run 2026-07-14-ssh-deploy-keys-aiqadam-001
