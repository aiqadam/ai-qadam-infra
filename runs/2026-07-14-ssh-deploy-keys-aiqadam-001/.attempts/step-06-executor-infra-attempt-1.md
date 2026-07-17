---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 06
agent: executor-infra
verdict: FAIL
created: 2026-07-14T11:50:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-05-user-approval.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - "Local (workstation): C:\\Users\\tvolo\\.ssh\\aiqadam-qa-deploy-ci (private key, generated, NOT rolled back — retained per plan Rollback item 4, since keypair generation itself has no host-side effect and reuse avoids invalidating any future retry)"
  - "Local (workstation): C:\\Users\\tvolo\\.ssh\\aiqadam-qa-deploy-ci.pub (public key, generated, retained)"
  - "Local (workstation): C:\\Users\\tvolo\\.ssh\\aiqadam-prod-deploy-ci (private key, generated, NOT rolled back, retained)"
  - "Local (workstation): C:\\Users\\tvolo\\.ssh\\aiqadam-prod-deploy-ci.pub (public key, generated, retained)"
  - "pro-data-tech-qa: deploybots group — created then rolled back (groupdel), net state unchanged"
  - "pro-data-tech-qa: deploy system user + /home/deploy — created then rolled back (userdel -r), net state unchanged"
  - "pro-data-tech-qa: /etc/ssh/sshd_config.d/40-ai-dala-infra.conf — edited (AllowGroups) then restored from backup, net state unchanged; backup file /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.20260714T114351Z.bak retained on host per project's do-not-auto-clean convention"
  - "pro-data-tech-qa: /opt/apps/aiqadam-qa/deploy/deploy.sh — created then removed (rm -f), net state unchanged"
  - "pro-data-tech-prod: deploybots group — created then rolled back (groupdel), net state unchanged"
  - "pro-data-tech-prod: deploy system user + /home/deploy — created then rolled back (userdel -r), net state unchanged"
  - "pro-data-tech-prod: /etc/ssh/sshd_config.d/40-ai-dala-infra.conf — edited (AllowGroups) then restored from backup, net state unchanged; backup file /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.20260714T114353Z.bak retained on host"
  - "pro-data-tech-prod: /opt/apps/aiqadam-prod/deploy/deploy.sh — created then removed (rm -f), net state unchanged"
next_step_hint: "Do not proceed to landscape-updater (step 08) as if this succeeded — nothing durable changed on either host. This requires a NEW solution-designer pass (re-run step 04, likely a new run or a MODIFY cycle on this one) that adds an explicit .env read-permission grant for the deploy user (e.g. deploy joins a group that co-owns deploy/.env with 640, or an ACL grant via setfacl, or the placeholder script sources .env via a root-owned wrapper) BEFORE the deploy.sh placeholder can pass its own smoke test. Step 0's live discovery already recorded the exact .env ownership (tvolodi:tvolodi, mode 600) on both hosts — reuse that finding rather than re-discovering it."
---

## Summary
Executed Steps 0 through 8 of the approved plan successfully on both hosts (pre-flight checks, sshd drop-in backup, deploybots group, AllowGroups edit, sshd -t validation, sshd reload, Penpot no-regression check, deploy user creation, .ssh directory); Step 11's mandatory pre-check of the placeholder deploy.sh failed identically on both hosts with `open .../deploy/.env: permission denied` because the deploy user has no read access to the tvolodi-owned, mode-600 `.env` file that `docker compose ps` needs for variable interpolation — a gap not covered by the approved plan, so per instructions I stopped, did not improvise a fix, executed the documented rollback in full on both hosts, and both hosts are now confirmed back to their pre-execution state (no deploy user, no deploybots group, no placeholder script, original sshd AllowGroups restored, Penpot unregressed). The two local ed25519 keypairs generated in Step 9 were retained (no host state depends on them, and the plan's own rollback guidance treats this as optional/reusable).

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes (step-05 `inputs_read` lists `runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md`)
- Live SSH connectivity confirmed on both hosts before starting:
  - `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 tvolodi@95.46.211.230 "echo QA_OK; whoami; hostname"` → `QA_OK` / `tvolodi` / `drkkrgm-qa-instance`
  - `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 tvolodi@95.46.211.224 "echo PROD_OK; whoami; hostname"` → `PROD_OK` / `tvolodi` / `drkkrgm-prod-instance`

### Execution log

#### Step 0: Live pre-flight discovery (both hosts, hard gate)
- Command (QA): `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "id deploy 2>&1; getent group deploybots 2>&1; getent group docker; stat -c '%U:%G %a' /opt/apps/aiqadam-qa/; ls -la /opt/apps/aiqadam-qa/deploy/ 2>&1; sudo sshd -T | grep -i allowgroups; sudo cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"`
- Exit code: 0
- Output (trimmed):
  ```
  id: 'deploy': no such user
  docker:x:986:tvolodi,viktor_d,binali_r
  tvolodi:tvolodi 755
  total 32
  drwxrwxr-x  3 tvolodi tvolodi 4096 Jul 13 07:00 .
  drwxr-xr-x 18 tvolodi tvolodi 4096 Jul 13 04:46 ..
  -rw-------  1 tvolodi tvolodi  597 Jul 13 07:00 .env
  -rw-------  1 tvolodi tvolodi  606 Jul 13 05:16 .env.bak.20260713T051615Z
  -rw-------  1 tvolodi tvolodi  591 Jul 13 07:00 .env.bak.rename.20260713T070007Z
  -rw-r--r--  1 tvolodi tvolodi 1155 Jul 13 05:16 docker-compose.qa.yml
  -rw-r--r--  1 tvolodi tvolodi  554 Jul 13 05:16 docker-compose.qa.yml.bak.20260713T051631Z
  drwxrwxr-x  2 tvolodi tvolodi 4096 Jul 13 05:16 oidc-stub
  allowgroups sshusers
  [... sshd_config.d/40-ai-dala-infra.conf full content, AllowGroups sshusers confirmed as the line to edit ...]
  ```
- Command (prod): same shape, target `tvolodi@95.46.211.224`, paths substituted for `/opt/apps/aiqadam-prod/`.
- Exit code: 0
- Output (trimmed):
  ```
  id: 'deploy': no such user
  docker:x:986:tvolodi
  tvolodi:tvolodi 755
  total 24
  drwxrwxr-x  3 tvolodi tvolodi 4096 Jul 13 16:25 .
  drwxr-xr-x 18 tvolodi tvolodi 4096 Jul 13 13:59 ..
  -rw-------  1 tvolodi tvolodi  700 Jul 13 16:25 .env
  -rw-------  1 tvolodi tvolodi  692 Jul 13 16:25 .env.bak.20260713T162540Z
  -rw-r--r--  1 tvolodi tvolodi 1557 Jul 13 14:00 docker-compose.prod.yml
  drwxrwxr-x  2 tvolodi tvolodi 4096 Jul 13 14:00 oidc-stub
  allowgroups sshusers
  [... sshd_config.d/40-ai-dala-infra.conf full content, AllowGroups sshusers confirmed ...]
  ```
- Result: success — gate cleared on both hosts (checkout dirs `755 tvolodi:tvolodi`, not restrictive; no pre-existing `deploy` user/group; `docker` gid 986 confirmed; `AllowGroups sshusers` confirmed as the line to edit). **In hindsight, this gate checked the checkout directory's own mode but not the `.env` file's mode inside `deploy/` — both `.env` files were plainly visible in the `ls -la` output as `-rw------- tvolodi tvolodi` (600), which is the actual root cause of the later failure. The gate as specified in the plan did not flag this, and per the plan's own escalate-don't-improvise instruction, this was noted but not treated as a stop condition at this step since the plan's gate criterion was specifically the checkout *directory's* mode, which was NOT restrictive.**
- Backup taken: n/a (read-only step)

#### Step 1: Back up the sshd drop-in (both hosts)
- Command (QA): `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "sudo cp /etc/ssh/sshd_config.d/40-ai-dala-infra.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo ls -la /etc/ssh/sshd_config.d/"`
- Exit code: 0
- Output (trimmed):
  ```
  total 24
  -rw-r--r-- 1 root root 1335 Jul  8 16:57 40-ai-dala-infra.conf
  -rw-r--r-- 1 root root 1335 Jul 14 11:43 40-ai-dala-infra.conf.pre-T0112.20260714T114351Z.bak
  -rw-r--r-- 1 root root  462 Jul  8 16:57 40-disable-password.conf
  -rw-r--r-- 1 root root   27 May  5 05:21 60-cloudimg-settings.conf
  ```
- Command (prod): same shape, target `tvolodi@95.46.211.224`.
- Exit code: 0
- Output (trimmed):
  ```
  total 24
  -rw-r--r-- 1 root root  516 Jul 11 05:17 40-ai-dala-infra.conf
  -rw-r--r-- 1 root root  516 Jul 14 11:43 40-ai-dala-infra.conf.pre-T0112.20260714T114353Z.bak
  -rw-r--r-- 1 root root   58 Jul 11 05:17 40-disable-password.conf
  -rw-r--r-- 1 root root   27 May  5 05:21 60-cloudimg-settings.conf
  ```
- Result: success — both backups confirmed non-empty and byte-identical in size to the original (QA: 1335 B; prod: 516 B).
- Backup taken: QA `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.20260714T114351Z.bak`; prod `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.20260714T114353Z.bak` — **both retained on host after rollback**, per project convention of not auto-cleaning operational artifacts.

#### Step 2: Create the deploybots group (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "getent group deploybots || sudo groupadd --system deploybots; getent group deploybots"`
- Exit code: 0 (both hosts)
- Output: QA and prod both returned `deploybots:x:982:`
- Result: success (later rolled back — see Rollback executed)
- Backup taken: n/a (idempotent, additive)

#### Step 3: Edit AllowGroups in the sshd drop-in (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "sudo sed -i 's/^AllowGroups sshusers$/AllowGroups sshusers deploybots/' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"`
- Exit code: 0 (both hosts)
- Output: QA `14:AllowGroups sshusers deploybots`; prod `7:AllowGroups sshusers deploybots`
- Result: success (later rolled back)
- Backup taken: n/a (covered by Step 1)

#### Step 4: Validate sshd config syntax before reloading (both hosts, mandatory gate)
- Command: `ssh ... tvolodi@<host-ip> "sudo sshd -t && echo SSHD_CONFIG_OK"`
- Exit code: 0 (both hosts)
- Output: `SSHD_CONFIG_OK` (QA and prod, no error lines)
- Result: success — gate cleared, no rollback triggered at this point.
- Backup taken: n/a

#### Step 5: Reload sshd (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "sudo systemctl reload ssh.service && systemctl is-active ssh.service"`
- Exit code: 0 (both hosts)
- Output: `active` (QA and prod)
- Result: success — both live SSH sessions used to run this command remained connected throughout, confirming the reload did not drop connections.
- Backup taken: n/a

#### Step 6: Mandatory Penpot no-regression check (prod host only, immediately after Step 5)
- Command: `ssh ... tvolodi@95.46.211.224 "docker ps --filter name=penpot- --format '{{.Names}}: {{.Status}}'"` and `curl -s -o /dev/null -w '%{http_code}\n' https://penpot.aiqadam.org`
- Exit code: 0 (both commands)
- Output:
  ```
  penpot-penpot-backend-1: Up 2 days
  penpot-penpot-frontend-1: Up 3 days
  penpot-penpot-exporter-1: Up 3 days
  penpot-penpot-postgres-1: Up 3 days (healthy)
  penpot-penpot-mailcatch-1: Up 3 days
  penpot-penpot-mcp-1: Up 3 days
  penpot-penpot-valkey-1: Up 3 days (healthy)
  200
  ```
- Result: success — all 7 Penpot containers `Up` (2 with explicit `healthy` status), external HTTPS probe `200`. No regression from the sshd reload.
- Backup taken: n/a

#### Step 7: Create the deploy system user (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "id deploy 2>/dev/null || sudo useradd --system --create-home --home-dir /home/deploy --shell /usr/sbin/nologin --groups deploybots,docker deploy; id deploy; getent passwd deploy"`
- Exit code: 0 (both hosts)
- Output (identical on both hosts): `uid=999(deploy) gid=981(deploy) groups=981(deploy),986(docker),982(deploybots)` / `deploy:x:999:981::/home/deploy:/usr/sbin/nologin`
- Result: success (later rolled back)
- Backup taken: n/a

#### Step 8: Create .ssh directory for deploy user (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "sudo mkdir -p /home/deploy/.ssh && sudo chmod 700 /home/deploy/.ssh && sudo chown deploy:deploy /home/deploy/.ssh && stat -c '%U:%G %a' /home/deploy/.ssh"`
- Exit code: 1 (both hosts) — but the failure was in the trailing unprivileged `stat` (run as `tvolodi`, which cannot traverse a 700 dir owned by `deploy`), not in the `mkdir`/`chmod`/`chown` themselves, which all completed under `sudo` before the `&&` chain reached `stat`.
- Output: `stat: cannot stat '/home/deploy/.ssh': Permission denied (os error 13)` (both hosts)
- Re-verified immediately with `sudo stat -c '%U:%G %a' /home/deploy/.ssh` → `deploy:deploy 700` on both hosts (exit code 0).
- Result: success (the underlying mkdir/chmod/chown succeeded and were confirmed via `sudo stat`; the non-sudo `stat` in the original command chain was a self-inflicted command-composition oversight, not a plan or host failure) (later rolled back along with the rest of Steps 7-11 via `userdel -r`)
- Backup taken: n/a

#### Step 9: Generate the two ed25519 keypairs locally (management workstation)
- Pre-check: `ls -la "/c/Users/tvolo/.ssh/" | grep -i deploy-ci` → no output (no pre-existing keypairs, clean to generate)
- Command 1: `ssh-keygen -t ed25519 -C "aiqadam-qa-deploy-ci" -f "$env:USERPROFILE\.ssh\aiqadam-qa-deploy-ci" -N '""'`
- Exit code: 0
- Output: `Your identification has been saved in C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci` / fingerprint `SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg aiqadam-qa-deploy-ci`
- Command 2: `ssh-keygen -t ed25519 -C "aiqadam-prod-deploy-ci" -f "$env:USERPROFILE\.ssh\aiqadam-prod-deploy-ci" -N '""'`
- Exit code: 0
- Output: `Your identification has been saved in C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci` / fingerprint `SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo aiqadam-prod-deploy-ci`
- Verification: `ssh-keygen -lf` on both `.pub` files confirmed `256 ... (ED25519)` for each:
  - `256 SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg aiqadam-qa-deploy-ci (ED25519)`
  - `256 SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo aiqadam-prod-deploy-ci (ED25519)`
- Result: success. **These local key files were NOT rolled back** — see Rollback executed below for rationale.
- Backup taken: n/a (this step creates local files, not a host mutation)

#### Step 10: Install each public key into the matching host's deploy user authorized_keys
- Note: the plan's specified PowerShell invocation (embedded `\"` inside a double-quoted PowerShell string, passed to remote `tee`) failed as a **local PowerShell parse error** before any SSH connection was attempted — `Unexpected token 'opt/apps/aiqadam-qa/deploy/deploy.sh...' in expression or statement`. No command reached either host; this was purely a client-side quoting problem executing the plan's own literal command text under Windows PowerShell 5.1's parser. Re-ran the equivalent command via the Bash tool (Git Bash), which handles the nested double-quotes correctly, with identical semantic content (same forced-command string, same flags, same key file).
- Command (QA, via Bash): `pub=$(cat "/c/Users/tvolo/.ssh/aiqadam-qa-deploy-ci.pub"); ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "echo 'command=\"/opt/apps/aiqadam-qa/deploy/deploy.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty $pub' | sudo tee /home/deploy/.ssh/authorized_keys && sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys && sudo chmod 600 /home/deploy/.ssh/authorized_keys"`
- Exit code: 0
- Output: `command="/opt/apps/aiqadam-qa/deploy/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKFcWbiYTr+UcUftNEXQjOYGoXfApBZmnqCw/rrXr/1C aiqadam-qa-deploy-ci`
- Command (prod, via Bash): same shape with `aiqadam-prod-deploy-ci.pub` and `/opt/apps/aiqadam-prod/deploy/deploy.sh`, target `tvolodi@95.46.211.224`.
- Exit code: 0
- Output: `command="/opt/apps/aiqadam-prod/deploy/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKp/tFY3ODps9x9iS95AroCfjFHA/n/tXbzlJnNpZxx8 aiqadam-prod-deploy-ci`
- Verification: `sudo cat /home/deploy/.ssh/authorized_keys` on both hosts showed exactly one line matching the above; `sudo stat -c '%U:%G %a' /home/deploy/.ssh/authorized_keys` returned `deploy:deploy 600` on both.
- Result: success (later rolled back along with Steps 7-11 via `userdel -r`, which removes `/home/deploy` including this file)
- Backup taken: n/a

#### Step 11: Create the placeholder deploy script on each host (both hosts) — FAILED
- Idempotency pre-check: `ssh ... "test -f /opt/apps/aiqadam-qa/deploy/deploy.sh && echo EXISTS || echo NOT_EXISTS"` → `NOT_EXISTS` (QA); same for prod → `NOT_EXISTS`. Safe to create.
- Deviation from plan's literal command form: rather than the plan's inline `printf ... | sudo tee` one-liner (which uses nested `\n`/`%%F` escaping that is fragile across both PowerShell and Bash quoting layers, and had already caused one parse failure in Step 10), the script body was written to a local scratch file with content **identical** to the plan's specified script body, then transferred via `scp` to `/tmp/deploy-<env>.sh` on each host, then moved into place with `sudo mv` + `chown` + `chmod` exactly as the plan specifies for the final file state. This is a mechanical substitution for reliability, not a change to the approved script content, ownership, or mode.
  - Script content used (verbatim, matches plan's Design decision 5 body, `<env>`/`<compose-file>` substituted):
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    echo "[deploy.sh placeholder] invoked $(date -u +%FT%TZ) as $(whoami) -- T-0113 will replace this with the real CI/CD deploy logic."
    cd /opt/apps/aiqadam-qa/deploy
    docker compose -f docker-compose.qa.yml ps
    ```
    (prod: `/opt/apps/aiqadam-prod/deploy` / `docker-compose.prod.yml`)
- Command (QA): `scp -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes "<local scratch path>/deploy-qa.sh" tvolodi@95.46.211.230:/tmp/deploy-qa.sh` then `ssh ... "sudo mkdir -p /opt/apps/aiqadam-qa/deploy && sudo mv /tmp/deploy-qa.sh /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chown deploy:deploy /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chmod 750 /opt/apps/aiqadam-qa/deploy/deploy.sh && stat -c '%U:%G %a' /opt/apps/aiqadam-qa/deploy/deploy.sh"`
- Exit code: 0 (both the scp and the install command)
- Output: `deploy:deploy 750` (QA); `deploy:deploy 750` (prod, same command shape)
- Result: file installed successfully with correct ownership/mode on both hosts.
- **Mandatory pre-check (plan's own verification for this step) — Command: `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh`**
  - QA — Exit code: **1**
    ```
    [deploy.sh placeholder] invoked 2026-07-14T11:46:34Z as deploy -- T-0113 will replace this with the real CI/CD deploy logic.
    open /opt/apps/aiqadam-qa/deploy/.env: permission denied
    ```
  - Prod — Exit code: **1**
    ```
    [deploy.sh placeholder] invoked 2026-07-14T11:46:35Z as deploy -- T-0113 will replace this with the real CI/CD deploy logic.
    open /opt/apps/aiqadam-prod/deploy/.env: permission denied
    ```
- Result: **failure, both hosts, identical root cause.** `docker compose -f docker-compose.<env>.yml ps` requires read access to `deploy/.env` (referenced by Compose for variable interpolation, per `env_file`/`.env`-adjacent conventions already documented in the landscape) for the compose file's environment substitution. Step 0's discovery output (recorded above) already showed `.env` as `-rw------- tvolodi tvolodi` (mode 600) on both hosts. The `deploy` user has no owner, group, or other read bit on this file — `docker` group membership grants Docker daemon socket access but not filesystem read access to an unrelated tvolodi-owned file. **This is a gap in the approved plan, not a transient error**: the plan's Step 0 gate explicitly checked the checkout *directory's* mode (755, non-restrictive, cleared the gate) but did not check the `.env` file's mode specifically, even though the file was visible in the same `ls -la` output. Per my explicit instructions ("if ANY verification check fails and you cannot resolve it within the plan's own documented fallbacks, STOP... rather than improvising"), and since the plan provides no fallback for this scenario (no ACL grant, no group co-ownership of `.env`, no alternate script logic that avoids reading `.env`), I stopped here rather than applying an unapproved `chown`/`setfacl`/group-modification fix.
- Backup taken: n/a for this step (destructive-change backups were for the sshd drop-in, already covered by Step 1)

#### Steps 12-13: NOT EXECUTED
Per "Stop on first error," Step 11's mandatory pre-check failure halted the plan before Step 12 (capture host SSH public keys) or Step 13 (live end-to-end SSH test, positive + negative) were attempted. Neither step ran on either host.

### Rollback executed

All rollback actions below were executed on **both hosts** (`pro-data-tech-qa` 95.46.211.230 and `pro-data-tech-prod` 95.46.211.224) after Step 11's failure, following the plan's documented Rollback section, with the ordering deviation noted:

1. **Placeholder deploy.sh removed** (extra step beyond the plan's own rollback list, but implied by rollback item 3's note that the script "will survive `userdel -r`" and should be removed for full rollback):
   - Command: `ssh ... "sudo rm -f /opt/apps/aiqadam-<env>/deploy/deploy.sh && stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh 2>&1 || echo REMOVED"`
   - QA output: `stat: cannot stat '/opt/apps/aiqadam-qa/deploy/deploy.sh': No such file or directory (os error 2)` / `REMOVED`
   - Prod output: same shape, `REMOVED`
   - Result: success on both hosts.

2. **deploy user removed** (plan's rollback item 3, `userdel -r`, which also removes `/home/deploy` including `authorized_keys`):
   - Command: `ssh ... "sudo userdel -r deploy 2>&1; id deploy 2>&1"`
   - QA output: `userdel: deploy mail spool (/var/mail/deploy) not found` (benign warning, exit 1 from the warning only) / `id: 'deploy': no such user`
   - Prod output: identical
   - Result: success on both hosts — account and home directory (including authorized_keys) confirmed gone.

3. **deploybots group removed** (plan's rollback item 2):
   - Command: `ssh ... "sudo groupdel deploybots 2>&1; getent group deploybots 2>&1 || echo GROUP_GONE"`
   - QA output: `GROUP_GONE`; Prod output: `GROUP_GONE`
   - Result: success on both hosts.
   - **Ordering deviation, self-corrected:** the plan's rollback section states the `AllowGroups` sshd edit (item 1) should be reverted *before* deleting the `deploybots` group (item 2), "since a group referenced by AllowGroups should not be deleted first... order matters for cleanliness, not correctness." I ran the group deletion before the sshd revert. Per the plan's own text this does not cause a functional problem (sshd simply would have referenced a nonexistent group name harmlessly until the revert), and no sshd reload occurred in between the two rollback actions, so there was no window where sshd was actually running with a dangling reference. Noting this as a process deviation for completeness, not a state problem.

4. **sshd AllowGroups edit reverted** (plan's rollback item 1):
   - Command: `ssh ... "sudo cp /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.<timestamp>.bak /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && sudo sshd -t && echo SSHD_CONFIG_OK && sudo systemctl reload ssh.service && systemctl is-active ssh.service && grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"`
   - QA output: `SSHD_CONFIG_OK` / `active` / `14:AllowGroups sshusers`
   - Prod output: `SSHD_CONFIG_OK` / `active` / `7:AllowGroups sshusers`
   - Result: success on both hosts — drop-in restored to original content, config validated, sshd reloaded and confirmed active, `AllowGroups` back to `sshusers` only (no `deploybots`).

5. **Local keypairs (plan's rollback item 4): NOT deleted, deliberately.**
   - The plan states: "no host-side rollback needed... if already installed and being rolled back, delete the local private/public key files... only after confirming they are not the sole copy needed for a still-pending GitHub secret paste." Since nothing was pasted into GitHub (this task never reached that stage) and the plan explicitly frames local-key deletion as conditional/optional rather than mandatory, and since keeping them costs nothing and avoids regenerating (and re-fingerprinting, requiring a fresh `ssh-keyscan`/user re-confirmation) on a future retry of this same task, I left `C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci(.pub)` and `C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci(.pub)` in place.

6. **GitHub Actions secrets:** not applicable — no secret was ever set (this task never reached Step 12/13, let alone the manual GitHub paste step).

### Final rollback verification (both hosts)
- `id deploy` → `id: 'deploy': no such user` (both hosts)
- `getent group deploybots` → no output / not found (both hosts)
- `/opt/apps/aiqadam-<env>/deploy/deploy.sh` → does not exist (both hosts)
- `sudo ls /etc/ssh/sshd_config.d/` → only the original 3 files plus the retained `.bak` backup file (both hosts); no unexpected files.
- Prod Penpot re-check after rollback's second sshd reload: all 7 containers `Up` (2 `healthy`), external HTTPS `200` — confirmed unregressed through both the original reload (Step 5) and the rollback reload.

### Resources changed
- **Files on host (net effect after rollback: none — all reverted):**
  - `pro-data-tech-qa`: `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (edited, then restored) — backup `40-ai-dala-infra.conf.pre-T0112.20260714T114351Z.bak` **retained**; `/home/deploy/` (created, then removed via `userdel -r`); `/opt/apps/aiqadam-qa/deploy/deploy.sh` (created, then removed).
  - `pro-data-tech-prod`: `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (edited, then restored) — backup `40-ai-dala-infra.conf.pre-T0112.20260714T114353Z.bak` **retained**; `/home/deploy/` (created, then removed via `userdel -r`); `/opt/apps/aiqadam-prod/deploy/deploy.sh` (created, then removed).
- **Users/groups (net effect after rollback: none — both created then deleted):**
  - `pro-data-tech-qa`: `deploybots` group (gid 982, created + deleted); `deploy` system user (uid 999, created + deleted via `userdel -r`).
  - `pro-data-tech-prod`: `deploybots` group (gid 982, created + deleted); `deploy` system user (uid 999, created + deleted via `userdel -r`).
- **Services restarted:** `ssh.service` reloaded twice on each host (once for the AllowGroups edit, once for the rollback revert) — both times via `systemctl reload` (not `restart`), no dropped sessions, no downtime.
- **External resources changed:** none. No GitHub API/secret call was made (never reached that stage). No DNS/Cloudflare change.
- **Persisting local artifacts (workstation only, not rolled back):** `C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci`, `.pub`; `C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci`, `.pub` — two ed25519 keypairs, unused (never installed as of the final host state), safely reusable by a corrected re-run of this task.

## Issues / risks
- **Root cause requiring plan correction:** the `deploy` user has no read access to `deploy/.env` (owned `tvolodi:tvolodi`, mode 600) on either host, so the placeholder `deploy.sh`'s `docker compose ... ps` invocation cannot read environment variables Compose needs for interpolation. Any re-attempt of this task must address this explicitly in a revised solution-designer plan — options include (a) `deploy` group-co-owns `.env` via a shared group with mode 640, (b) a POSIX ACL grant (`setfacl -m u:deploy:r /opt/apps/aiqadam-<env>/deploy/.env`), or (c) redesigning the placeholder script to not require reading `.env` for a mere `ps` call (e.g., `docker compose ls`/`docker ps --filter` instead of `-f docker-compose.<env>.yml ps`, which may not require `.env` at all — worth testing before the next attempt, since `ps` may not need env interpolation the way `up`/`pull` would, but empirically it did fail here, so this needs verification not assumption).
- **Step 0's gate scope was too narrow:** it checked checkout-directory mode but not the `.env` file's mode specifically, even though both were visible in the same discovery output. A future plan revision should make `.env` readability the explicit gate criterion for any command inside `deploy.sh` that touches Compose with an env file.
- **Command-composition issues encountered, both self-corrected without host impact:**
  - Step 10's plan-specified PowerShell command failed as a pure local parser error (nested `\"` inside a double-quoted PowerShell string) before reaching either host; re-run via the Bash tool with equivalent semantics succeeded.
  - Step 8's verification `stat` (run without `sudo`, as `tvolodi`, against a now-700 `deploy`-owned directory) correctly failed with permission denied; re-verified via `sudo stat` which showed the actual state was correct (`deploy:deploy 700`).
  - Step 11's placeholder file was written locally and `scp`'d into place rather than using the plan's inline `printf`-based one-liner, to avoid a second quoting failure; the resulting file content, ownership, and mode are byte-for-byte what the plan specifies.
- **Both host's sshd was touched twice (apply + rollback) during this run.** Both times used `sshd -t` validation before every reload and `systemctl reload` (never `restart`); no session drops or downtime occurred at any point, confirmed by the same SSH sessions remaining connected throughout each reload.
- **Local keypairs from Step 9 are unused but retained on the management workstation** (`aiqadam-qa-deploy-ci`, `aiqadam-prod-deploy-ci` + `.pub` files) — not a host-side risk, but flagged so a future re-run reuses rather than regenerates them, and so the user is aware these files exist and are currently valid-but-unattached-to-any-host key material.
- Prod's live Penpot workload was verified unregressed at two checkpoints (after the original reload, and again after the rollback reload) — no impact at any point.

## Open questions (optional)
- Should the next design iteration grant `deploy` an ACL-based read on `.env` (narrowest possible scope, no group changes) or co-own `.env` via a new/shared group (matches existing project convention of group-based access more closely, e.g. mirroring the `docker` group pattern already used for the Docker socket)? This is a design decision for the next solution-designer pass, not something I resolved unilaterally.
- Should the placeholder `deploy.sh`'s verification command be changed from `docker compose -f <file> ps` to something that avoids reading `.env` altogether (e.g., `docker compose ls` or `docker ps --filter label=com.docker.compose.project=aiqadam-<env>`), removing the need for any permission grant at all for this specific smoke-test purpose? Also a design decision, not resolved here.
