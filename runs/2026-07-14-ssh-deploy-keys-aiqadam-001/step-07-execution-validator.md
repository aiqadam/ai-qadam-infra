---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-17T06:45:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
retry_of: null
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-06-executor-infra.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
artifacts_changed: []
next_step_hint: "All step-04 'Verification (for step 07)' checks independently re-run and PASS on both hosts, including the two checks that failed in attempt 3 (Step 13 live SSH forced-command test and its negative control). Resources-changed list from step-06 fully reconciles with observed live state. No .env content was read at any point (metadata-only stat + functional deploy.sh checks only, per the run's standing prohibition). Safe for step 08 (landscape-updater) to proceed with landscape/hosts/pro-data-tech-qa.md, landscape/hosts/pro-data-tech-prod.md, and landscape/secrets-inventory.md updates as described in step-04's 'Resources used' section. Note for step 08: T-0112's task file should NOT be marked fully done yet — the GitHub Actions secrets paste step (QA_SSH_DEPLOY_KEY, PROD_SSH_DEPLOY_KEY, QA_SSH_HOST_KEY, PROD_SSH_HOST_KEY) remains an outstanding manual user action per the task's own 'What done looks like' checklist."
---

## Summary
End state fully verified independently on both hosts — every check in the designer's step-04 verification block passes, including the two checks (Step 13 live SSH forced-command test and its negative control) that failed in attempt 3; no discrepancy found between the executor's claimed resources-changed list and observed live state.

## Details

### On-host checks
| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| `deploybots` group exists (QA) | `getent group deploybots` | `deploybots:x:982:deploy` | yes |
| `deploybots` group exists (prod) | `getent group deploybots` | `deploybots:x:982:deploy` | yes |
| `deploy` user groups incl. deploybots/docker/secrets (QA) | `id deploy` | `uid=999(deploy) gid=981(deploy) groups=981(deploy),986(docker),982(deploybots),980(aiqadam-qa-secrets)` | yes |
| `deploy` user groups incl. deploybots/docker/secrets (prod) | `id deploy` | `uid=999(deploy) gid=981(deploy) groups=981(deploy),986(docker),982(deploybots),980(aiqadam-prod-secrets)` | yes |
| `deploy` shell is `/bin/bash`, not nologin (QA) | `getent passwd deploy` | `deploy:x:999:981::/home/deploy:/bin/bash` | yes |
| `deploy` shell is `/bin/bash`, not nologin (prod) | `getent passwd deploy` | `deploy:x:999:981::/home/deploy:/bin/bash` | yes |
| `AllowGroups sshusers deploybots` (QA) | `sudo grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` | `14:AllowGroups sshusers deploybots` | yes |
| `AllowGroups sshusers deploybots` (prod) | `sudo grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` | `7:AllowGroups sshusers deploybots` | yes |
| `sshd -t` exits 0, ssh.service active (QA) | `sudo sshd -t && echo SSHD_OK; systemctl is-active ssh.service` | `SSHD_OK` / `active` | yes |
| `sshd -t` exits 0, ssh.service active (prod) | `sudo sshd -t && echo SSHD_OK; systemctl is-active ssh.service` | `SSHD_OK` / `active` | yes |
| `authorized_keys` one line, correct command= path, mode 600 (QA) | `sudo cat /home/deploy/.ssh/authorized_keys; sudo stat -c '%U:%G %a' ...` | `command="/opt/apps/aiqadam-qa/deploy/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA...aiqadam-qa-deploy-ci`; `deploy:deploy 600` | yes |
| `authorized_keys` one line, correct command= path, mode 600 (prod) | same | `command="/opt/apps/aiqadam-prod/deploy/deploy.sh",...` `deploy:deploy 600` | yes |
| `deploy.sh` owner/mode 750 (QA) | `stat -c '%U:%G %a' /opt/apps/aiqadam-qa/deploy/deploy.sh` | `deploy:deploy 750` | yes |
| `deploy.sh` owner/mode 750 (prod) | `stat -c '%U:%G %a' /opt/apps/aiqadam-prod/deploy/deploy.sh` | `deploy:deploy 750` | yes |
| `deploy.sh` contains explicit `-p aiqadam-<env>` flag (QA) | `sudo grep -F 'docker compose -p aiqadam-qa' deploy.sh` (required `sudo` — non-sudo `tvolodi` gets Permission denied against a 750 `deploy:deploy` file, consistent with correct mode) | `docker compose -p aiqadam-qa -f docker-compose.qa.yml ps` | yes |
| `deploy.sh` contains explicit `-p aiqadam-<env>` flag (prod) | `sudo grep -F 'docker compose -p aiqadam-prod' deploy.sh` | `docker compose -p aiqadam-prod -f docker-compose.prod.yml ps` | yes |
| `.env` group `aiqadam-<env>-secrets`, mode 640, size/mtime match baseline (QA) | `sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-qa/deploy/.env` | `tvolodi:aiqadam-qa-secrets 640 597 1783926015` (baseline 597/1783926015 — exact match) | yes |
| `.env` group `aiqadam-<env>-secrets`, mode 640, size/mtime match baseline (prod) | `sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-prod/deploy/.env` | `tvolodi:aiqadam-prod-secrets 640 700 1783959940` (baseline 700/1783959940 — exact match) | yes |
| `aiqadam-<env>-secrets` group membership exactly `tvolodi,deploy` (QA) | `getent group aiqadam-qa-secrets` | `aiqadam-qa-secrets:x:980:tvolodi,deploy` | yes |
| `aiqadam-<env>-secrets` group membership exactly `tvolodi,deploy` (prod) | `getent group aiqadam-prod-secrets` | `aiqadam-prod-secrets:x:980:tvolodi,deploy` | yes |
| Functional `deploy.sh` check, exit 0, marker + docker compose ps table (QA) | `sudo -u deploy /opt/apps/aiqadam-qa/deploy/deploy.sh` | exit 0, marker line, 2 data rows (api, oidc-stub, both healthy) | yes |
| Functional `deploy.sh` check, exit 0, marker + docker compose ps table (prod) | `sudo -u deploy /opt/apps/aiqadam-prod/deploy/deploy.sh` | exit 0, marker line, 3 data rows (api, oidc-stub, postgres, all healthy) | yes |
| No `/etc/sudoers.d/90-deploy` (QA) | `test -f /etc/sudoers.d/90-deploy && echo PRESENT \|\| echo ABSENT` | `SUDOERS_ABSENT` | yes |
| No `/etc/sudoers.d/90-deploy` (prod) | same | `SUDOERS_ABSENT` | yes |
| Backup files `...pre-T0112.*.bak` exist (QA) | `ls /etc/ssh/sshd_config.d/ \| grep pre-T0112` | 4 backups present, incl. this attempt's `...20260717T063435Z.bak` (1335 B, matches pre-edit original size) | yes |
| Backup files `...pre-T0112.*.bak` exist (prod) | same | 4 backups present, incl. this attempt's `...20260717T063437Z.bak` (516 B, matches pre-edit original size) | yes |
| No `.env` content read at any point | (self-check across all commands run this step) | Only `stat` (metadata) and `deploy.sh`'s internal `docker compose ps` (functional, non-secret output) were used against `.env` — no `cat`/`head`/`tail`/`grep`-content/`less`/`more`/`od`/`xxd` ever targeted `.env` | yes |

### External checks
| Check | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| Live SSH QA deploy key, forced command fires | `ssh -i aiqadam-qa-deploy-ci -o IdentitiesOnly=yes deploy@95.46.211.230` | marker + docker compose ps table (data rows), exit 0, no "account not available" message | exit 0; marker line; 2 data rows (api, oidc-stub, both healthy); no nologin refusal | yes |
| Live SSH prod deploy key, forced command fires | `ssh -i aiqadam-prod-deploy-ci -o IdentitiesOnly=yes deploy@95.46.211.224` | marker + docker compose ps table (data rows), exit 0, no "account not available" message | exit 0; marker line; 3 data rows (api, oidc-stub, postgres, all healthy); no nologin refusal | yes |
| Negative control QA — injected command blocked | `ssh -i aiqadam-qa-deploy-ci ... deploy@95.46.211.230 "whoami; id; cat /etc/shadow"` | forced command output only; no whoami/id/shadow content | identical output to legitimate run (marker + ps table), exit 0; no injected-command output of any kind | yes |
| Negative control prod — injected command blocked | `ssh -i aiqadam-prod-deploy-ci ... deploy@95.46.211.224 "whoami; id; cat /etc/shadow"` | forced command output only; no whoami/id/shadow content | identical output to legitimate run (marker + ps table), exit 0; no injected-command output of any kind | yes |
| Penpot no-regression — 7 containers Up | `ssh tvolodi@95.46.211.224 "docker ps --filter name=penpot- --format ..."` | all 7 Up | 7/7 Up (postgres, valkey healthy) | yes |
| Penpot external HTTPS | `curl -s -o /dev/null -w '%{http_code}' https://penpot.aiqadam.org` | 200 | `200` | yes |
| AiQadam prod health external HTTPS | `curl -s -o /dev/null -w '%{http_code}' https://aiqadam.org/health` | 200 | `200` | yes |
| `ssh-keyscan` QA host key matches workstation `known_hosts` | `ssh-keyscan -t ed25519 95.46.211.230` vs `ssh-keygen -F 95.46.211.230 -f known_hosts` | fingerprints match | both `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfJ4OplY05m062tG2l6153V6TU6XJInr5Gl14poYJhH` — exact match | yes |
| `ssh-keyscan` prod host key matches workstation `known_hosts` | `ssh-keyscan -t ed25519 95.46.211.224` vs `ssh-keygen -F 95.46.211.224 -f known_hosts` | fingerprints match | both `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9lE6sL+QjaY3JpbH8kUtGuel2Kv4XJdQUtFU7s0Jau` — exact match | yes |
| Local QA keypair fingerprint matches plan | `ssh-keygen -lf aiqadam-qa-deploy-ci.pub` | `SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg` | `256 SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg aiqadam-qa-deploy-ci (ED25519)` — exact match | yes |
| Local prod keypair fingerprint matches plan | `ssh-keygen -lf aiqadam-prod-deploy-ci.pub` | `SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo` | `256 SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo aiqadam-prod-deploy-ci (ED25519)` — exact match | yes |

### Resources-changed reconciliation
| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| QA: `deploybots` group (gid 982) | `deploybots:x:982:deploy` confirmed | yes |
| QA: `deploy` user (uid 999, shell `/bin/bash`, groups deploy/docker/deploybots/aiqadam-qa-secrets) | `id deploy` / `getent passwd deploy` confirmed exactly | yes |
| QA: `/home/deploy/.ssh/authorized_keys` (deploy:deploy 600, one forced-command line) | confirmed exactly, key comment `aiqadam-qa-deploy-ci` matches | yes |
| QA: `aiqadam-qa-secrets` group (gid 980, members tvolodi,deploy) | `getent group aiqadam-qa-secrets` confirmed exactly | yes |
| QA: `.env` group/mode changed to `tvolodi:aiqadam-qa-secrets 640`; size/mtime unchanged (597/1783926015) | confirmed exactly via `stat` | yes |
| QA: `deploy.sh` created (deploy:deploy 750, `-p aiqadam-qa` flag) | confirmed exactly | yes |
| QA: `AllowGroups` edited to `sshusers deploybots`; new backup `...20260717T063435Z.bak` | confirmed; backup present at correct size (1335 B, pre-edit original) | yes |
| Prod: `deploybots` group (gid 982) | confirmed | yes |
| Prod: `deploy` user (uid 999, shell `/bin/bash`, groups deploy/docker/deploybots/aiqadam-prod-secrets) | confirmed exactly | yes |
| Prod: `/home/deploy/.ssh/authorized_keys` (deploy:deploy 600, one forced-command line) | confirmed exactly, key comment `aiqadam-prod-deploy-ci` matches | yes |
| Prod: `aiqadam-prod-secrets` group (gid 980, members tvolodi,deploy) | confirmed exactly | yes |
| Prod: `.env` group/mode changed to `tvolodi:aiqadam-prod-secrets 640`; size/mtime unchanged (700/1783959940) | confirmed exactly via `stat` | yes |
| Prod: `deploy.sh` created (deploy:deploy 750, `-p aiqadam-prod` flag) | confirmed exactly | yes |
| Prod: `AllowGroups` edited to `sshusers deploybots`; new backup `...20260717T063437Z.bak` | confirmed; backup present at correct size (516 B, pre-edit original) | yes |
| Local: two ed25519 keypairs reused, installed, live-verified | both fingerprints confirmed matching, both live SSH sessions succeeded with forced-command output | yes |
| Local: `known_hosts`-cross-checked host key captures | both host keys cross-checked against workstation `known_hosts`, exact match | yes |
| No sudoers grant for `deploy` on either host | `/etc/sudoers.d/90-deploy` confirmed absent on both hosts | yes |
| ssh.service reloaded once per host, no drops, Penpot unregressed | `sshd -t` OK, `ssh.service active` on both; Penpot 7/7 Up, external 200; `aiqadam.org/health` 200 | yes |

## Issues / risks
- None. Both of attempt 3's failure points (Step 13's live SSH forced-command test and its negative control) now independently and genuinely pass — this validator's own live SSH sessions confirm the forced command fires and that command injection via the SSH client argument is blocked, not merely that the executor reported this.
- One immaterial deviation from the designer's literal verification-block wording: the `grep -F "docker compose -p aiqadam-<env>" deploy.sh` check as written did not specify `sudo`, and running it as plain `tvolodi` fails with "Permission denied" because `deploy.sh` is correctly `750 deploy:deploy` and `tvolodi` is not a member of the `deploy` group. This is expected behavior given the intended permissions (not a defect) — re-running with `sudo` (script content is explicitly non-secret per the plan's own scoping) confirmed the flag is present on both hosts. Flagging only so the designer's verification-block wording could be tightened in a future revision; does not affect the verdict.
- No GitHub Actions secrets check was in scope for this step (out of bounds per the plan and the executor's own scoping) — consistent with step-06's `next_step_hint` that this remains a manual user action outstanding before T-0112 can be marked fully done.

## Open questions (optional)
None — every "must pass" check in the designer's step-04 verification block was independently re-observed (not merely trusted from the executor's report) and passed on both hosts.
