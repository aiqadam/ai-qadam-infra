---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-17T06:40:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
retry_of: step-06
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-3.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-2.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed:
  - "Local (workstation): C:\\Users\\tvolo\\.ssh\\aiqadam-qa-deploy-ci(.pub) — reused, fingerprint re-confirmed, now installed and live-verified"
  - "Local (workstation): C:\\Users\\tvolo\\.ssh\\aiqadam-prod-deploy-ci(.pub) — reused, fingerprint re-confirmed, now installed and live-verified"
  - "pro-data-tech-qa: deploybots group created (gid 982, permanent)"
  - "pro-data-tech-qa: deploy system user created (uid 999, shell /bin/bash, groups deploy/docker/deploybots/aiqadam-qa-secrets) — permanent"
  - "pro-data-tech-qa: /home/deploy/.ssh/authorized_keys installed (deploy:deploy 600, one forced-command line) — permanent"
  - "pro-data-tech-qa: aiqadam-qa-secrets group created (gid 980, members tvolodi,deploy) — permanent"
  - "pro-data-tech-qa: /opt/apps/aiqadam-qa/deploy/.env — group/mode changed tvolodi:tvolodi 600 -> tvolodi:aiqadam-qa-secrets 640; content never read; size/mtime unchanged (597/1783926015) — permanent"
  - "pro-data-tech-qa: /opt/apps/aiqadam-qa/deploy/deploy.sh created (deploy:deploy 750, placeholder script with -p aiqadam-qa flag) — permanent"
  - "pro-data-tech-qa: /etc/ssh/sshd_config.d/40-ai-dala-infra.conf — AllowGroups edited to 'sshusers deploybots'; new backup 40-ai-dala-infra.conf.pre-T0112.20260717T063435Z.bak retained — permanent"
  - "pro-data-tech-prod: deploybots group created (gid 982, permanent)"
  - "pro-data-tech-prod: deploy system user created (uid 999, shell /bin/bash, groups deploy/docker/deploybots/aiqadam-prod-secrets) — permanent"
  - "pro-data-tech-prod: /home/deploy/.ssh/authorized_keys installed (deploy:deploy 600, one forced-command line) — permanent"
  - "pro-data-tech-prod: aiqadam-prod-secrets group created (gid 980, members tvolodi,deploy) — permanent"
  - "pro-data-tech-prod: /opt/apps/aiqadam-prod/deploy/.env — group/mode changed tvolodi:tvolodi 600 -> tvolodi:aiqadam-prod-secrets 640; content never read; size/mtime unchanged (700/1783959940) — permanent"
  - "pro-data-tech-prod: /opt/apps/aiqadam-prod/deploy/deploy.sh created (deploy:deploy 750, placeholder script with -p aiqadam-prod flag) — permanent"
  - "pro-data-tech-prod: /etc/ssh/sshd_config.d/40-ai-dala-infra.conf — AllowGroups edited to 'sshusers deploybots'; new backup 40-ai-dala-infra.conf.pre-T0112.20260717T063437Z.bak retained — permanent"
  - "Local (workstation): $TEMP/qa-host-key.pub, $TEMP/prod-host-key.pub — ssh-keyscan captures for known_hosts pinning, cross-checked against workstation known_hosts, fingerprints match"
next_step_hint: "T-0112's on-host acceptance criteria are now fully met on both hosts: forced-command SSH deploy keys installed and verified working end-to-end (Step 13 PASS on both QA and prod, including a genuine positive-proof negative control). No rollback was needed — this is the first fully successful execution of this run's plan. Step 07 (execution-validator) should independently re-run the plan's verification section. Step 08 (landscape-updater) should update landscape/hosts/pro-data-tech-qa.md, landscape/hosts/pro-data-tech-prod.md (new deploy user with shell /bin/bash, deploybots group, AllowGroups change, aiqadam-<env>-secrets group + .env group/mode change, deploy.sh placeholder path with explicit -p flag), and landscape/secrets-inventory.md (add aiqadam-qa-deploy-ssh-key and aiqadam-prod-deploy-ssh-key rows, names only). Two of T-0112's acceptance criteria remain outside this executor's scope and are NOT yet done: (1) private keys have not been pasted into GitHub Actions repository secrets (QA_SSH_DEPLOY_KEY, PROD_SSH_DEPLOY_KEY, QA_SSH_HOST_KEY, PROD_SSH_HOST_KEY in aiqadam/ai-qadam-platform) — this requires a manual user action per the plan's own scoping; (2) the task file itself should only be marked done once that manual step is confirmed complete by the user, per its 'What done looks like' checklist which explicitly includes the GitHub secrets step."
---

## Summary
Executed the full approved plan (Steps 0 through 13) on both pro-data-tech-qa and pro-data-tech-prod exactly as specified; every step succeeded on both hosts, including the previously-failing Step 13 live SSH end-to-end test (now passing because of this revision's Step 7 shell fix, `/usr/sbin/nologin` → `/bin/bash`) and its negative-control injection test (now a genuine positive proof rather than attempt 3's degenerate pass). Step 11's `-p aiqadam-<env>` fix also resolved the cosmetic empty-table gap previously seen on prod. No rollback was required — this is the first fully successful execution of this run across all four attempts. The `.env`-content-reading prohibition was fully observed throughout; no secret value was read, printed, or logged at any point.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED
- Design references match: yes — step-05's `inputs_read` lists `runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-04-solution-designer.md`
- Step-04 verdict confirmed: `NEEDS_APPROVAL` (third design revision, `retry_of: step-04`)
- Live SSH connectivity confirmed on both hosts before starting:
  - `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 tvolodi@95.46.211.230 "echo QA_OK; whoami; hostname"` → `QA_OK` / `tvolodi` / `drkkrgm-qa-instance`
  - Same for `tvolodi@95.46.211.224` → `PROD_OK` / `tvolodi` / `drkkrgm-prod-instance`

### Execution log

#### Step 0: Live pre-flight discovery (both hosts, hard gate)
- Command (QA): `ssh ... tvolodi@95.46.211.230 "id deploy 2>&1; getent group deploybots 2>&1; getent group docker; getent group aiqadam-qa-secrets 2>&1; stat -c '%U:%G %a' /opt/apps/aiqadam-qa/; ls -la /opt/apps/aiqadam-qa/deploy/ 2>&1; stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-qa/deploy/.env; sudo sshd -T | grep -i allowgroups; sudo cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"`
- Exit code: 0
- Output (trimmed): `id: 'deploy': no such user`; `deploybots`/`aiqadam-qa-secrets` groups return nothing (absent, as expected); `docker:x:986:tvolodi,viktor_d,binali_r`; checkout dir `tvolodi:tvolodi 755`; `.env` listed `-rw------- tvolodi tvolodi 597`, confirmed via `stat`: `tvolodi:tvolodi 600 597 1783926015` — **exactly matches attempt 3's recorded baseline**; `allowgroups sshusers`; full drop-in shown, `AllowGroups sshusers` confirmed as the line to edit.
- Command (prod): same shape, target `tvolodi@95.46.211.224`.
- Exit code: 0
- Output (trimmed): identical shape; `.env` confirmed `tvolodi:tvolodi 600 700 1783959940` — exactly matches attempt 3's recorded baseline.
- Result: success — gate cleared on both hosts, baseline confirmed clean per attempt 3's own rollback verification.
- Backup taken: n/a (read-only step)

#### Step 1: Back up the sshd drop-in (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "sudo cp /etc/ssh/sshd_config.d/40-ai-dala-infra.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo ls -la /etc/ssh/sshd_config.d/"`
- Exit code: 0 (both hosts)
- Output: QA new backup `40-ai-dala-infra.conf.pre-T0112.20260717T063435Z.bak` (1335 B, matches original size); prod new backup `40-ai-dala-infra.conf.pre-T0112.20260717T063437Z.bak` (516 B, matches original size). All three prior attempts' backups (`20260714T114351Z`/`20260714T181250Z`/`20260717T055045Z` on QA; `20260714T114353Z`/`20260714T181252Z`/`20260717T055046Z` on prod) remain present, as expected.
- Result: success — both new backups confirmed non-empty and byte-identical in size to the original.
- Backup taken: QA `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.20260717T063435Z.bak`; prod `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.20260717T063437Z.bak` — both retained on host (rollback not needed this attempt).

#### Step 2: Create the deploybots group (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "getent group deploybots || sudo groupadd --system deploybots; getent group deploybots"`
- Exit code: 0 (both hosts)
- Output: `deploybots:x:982:` (QA and prod) — gid matches all prior attempts.
- Result: success.
- Backup taken: n/a (idempotent, additive)

#### Step 3: Edit AllowGroups in the sshd drop-in (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "sudo sed -i 's/^AllowGroups sshusers$/AllowGroups sshusers deploybots/' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"`
- Exit code: 0 (both hosts)
- Output: QA `14:AllowGroups sshusers deploybots`; prod `7:AllowGroups sshusers deploybots`
- Result: success.
- Backup taken: n/a (covered by Step 1)

#### Step 4: Validate sshd config syntax before reloading (both hosts, mandatory gate)
- Command: `ssh ... tvolodi@<host-ip> "sudo sshd -t && echo SSHD_CONFIG_OK"`
- Exit code: 0 (both hosts)
- Output: `SSHD_CONFIG_OK` (QA and prod)
- Result: success — gate cleared.
- Backup taken: n/a

#### Step 5: Reload sshd (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "sudo systemctl reload ssh.service && systemctl is-active ssh.service"`
- Exit code: 0 (both hosts)
- Output: `active` (QA and prod)
- Result: success — subsequent SSH round-trips to both hosts continued to succeed immediately after, confirming no session/service disruption.
- Backup taken: n/a

#### Step 6: Mandatory Penpot no-regression check (prod host only, immediately after Step 5)
- Command: `ssh ... tvolodi@95.46.211.224 "docker ps --filter name=penpot- --format '{{.Names}}: {{.Status}}'"` and `curl -s -o /dev/null -w '%{http_code}\n' https://penpot.aiqadam.org`
- Exit code: 0 (both commands)
- Output: all 7 Penpot containers `Up` (`penpot-backend-1`, `-frontend-1`, `-exporter-1`, `-postgres-1` (healthy), `-mailcatch-1`, `-mcp-1`, `-valkey-1` (healthy)); external HTTPS probe `200`.
- Result: success — no regression from the sshd reload.
- Backup taken: n/a

#### Step 7: Create the deploy system user (both hosts) — CHANGED THIS REVISION: `--shell /bin/bash`
- Command: `ssh ... tvolodi@<host-ip> "id deploy 2>/dev/null || sudo useradd --system --create-home --home-dir /home/deploy --shell /bin/bash --groups deploybots,docker deploy; id deploy; getent passwd deploy"`
- Exit code: 0 (both hosts)
- Output (identical shape on both hosts): `uid=999(deploy) gid=981(deploy) groups=981(deploy),986(docker),982(deploybots)` / `deploy:x:999:981::/home/deploy:/bin/bash`
- Result: success — uid/gid match all prior attempts exactly; shell is now `/bin/bash` as intended by this revision.
- Backup taken: n/a

#### Step 8: Create .ssh directory for deploy user (both hosts)
- Command: `ssh ... tvolodi@<host-ip> "sudo mkdir -p /home/deploy/.ssh && sudo chmod 700 /home/deploy/.ssh && sudo chown deploy:deploy /home/deploy/.ssh && sudo stat -c '%U:%G %a' /home/deploy/.ssh"`
- Exit code: 0 (both hosts)
- Output: `deploy:deploy 700` (QA and prod)
- Result: success.
- Backup taken: n/a

#### Step 9: Reuse existing ed25519 keypairs (management workstation, no regeneration)
- Command: `ssh-keygen -lf "/c/Users/tvolo/.ssh/aiqadam-qa-deploy-ci.pub"` and same for prod.
- Output:
  - `256 SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg aiqadam-qa-deploy-ci (ED25519)` — matches plan's recorded fingerprint.
  - `256 SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo aiqadam-prod-deploy-ci (ED25519)` — matches plan's recorded fingerprint.
- Result: success — reused without regeneration.
- Backup taken: n/a (no host mutation)

#### Step 10: Install each public key into the matching host's deploy user authorized_keys
- Used the Bash tool (Git Bash) per the plan's note on nested double-quotes.
- Command (QA): `pub=$(cat "/c/Users/tvolo/.ssh/aiqadam-qa-deploy-ci.pub"); ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "echo 'command=\"/opt/apps/aiqadam-qa/deploy/deploy.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty $pub' | sudo tee /home/deploy/.ssh/authorized_keys && sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys && sudo chmod 600 /home/deploy/.ssh/authorized_keys"`
- Exit code: 0
- Output: `command="/opt/apps/aiqadam-qa/deploy/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKFcWbiYTr+UcUftNEXQjOYGoXfApBZmnqCw/rrXr/1C aiqadam-qa-deploy-ci`
- Command (prod): same shape with `aiqadam-prod-deploy-ci.pub` and `/opt/apps/aiqadam-prod/deploy/deploy.sh`, target `tvolodi@95.46.211.224`.
- Exit code: 0
- Output: `command="/opt/apps/aiqadam-prod/deploy/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKp/tFY3ODps9x9iS95AroCfjFHA/n/tXbzlJnNpZxx8 aiqadam-prod-deploy-ci`
- Verification: `sudo cat /home/deploy/.ssh/authorized_keys` on both hosts showed exactly one matching line (authorized_keys is explicitly exempt from the `.env` content-reading prohibition); `sudo stat -c '%U:%G %a'` returned `deploy:deploy 600` on both.
- Result: success.
- Backup taken: n/a

#### Step 11: Create the placeholder deploy script on each host — CHANGED THIS REVISION: explicit `-p aiqadam-<env>` flag
- Idempotency pre-check: `test -f /opt/apps/aiqadam-<env>/deploy/deploy.sh && echo EXISTS || echo NOT_EXISTS` → `NOT_EXISTS` on both hosts.
- Used the plan's documented mitigation (local scratch file + `scp` + `sudo mv`/`chown`/`chmod`), per the pre-approved fallback for quoting reliability. Script content matches the plan's Step 11 body exactly, with the `-p` flag added:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  echo "[deploy.sh placeholder] invoked $(date -u +%FT%TZ) as $(whoami) -- T-0113 will replace this with the real CI/CD deploy logic."
  cd /opt/apps/aiqadam-qa/deploy
  docker compose -p aiqadam-qa -f docker-compose.qa.yml ps
  ```
  (prod: `/opt/apps/aiqadam-prod/deploy` / `docker-compose.prod.yml` / `-p aiqadam-prod`)
- Command (QA): `scp` scratch file to `/tmp/deploy-qa.sh`, then `ssh ... "sudo mkdir -p /opt/apps/aiqadam-qa/deploy && sudo mv /tmp/deploy-qa.sh /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chown deploy:deploy ... && sudo chmod 750 ... && stat -c '%U:%G %a' ..."`
- Exit code: 0 (both scp and install command, both hosts)
- Output: `deploy:deploy 750` (QA and prod)
- Verification: `sudo grep -F 'docker compose -p aiqadam-qa' /opt/apps/aiqadam-qa/deploy/deploy.sh` → `docker compose -p aiqadam-qa -f docker-compose.qa.yml ps`; same shape confirmed on prod with `aiqadam-prod`. (grep targets the script file, not `.env` — permitted.)
- Result: file installed with correct ownership/mode and the explicit `-p` flag confirmed present on both hosts.
- Backup taken: n/a

#### Step 11a: Grant deploy read access to deploy/.env via dedicated secrets group (both hosts)
- Command (QA): `ssh ... tvolodi@95.46.211.230 "getent group aiqadam-qa-secrets || sudo groupadd --system aiqadam-qa-secrets; sudo usermod -aG aiqadam-qa-secrets tvolodi; sudo usermod -aG aiqadam-qa-secrets deploy; sudo chgrp aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env; sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env; sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-qa/deploy/.env; getent group aiqadam-qa-secrets"`
- Exit code: 0
- Output: `tvolodi:aiqadam-qa-secrets 640 597 1783926015` / `aiqadam-qa-secrets:x:980:tvolodi,deploy`. **Size (597) and mtime (1783926015) numerically identical to Step 0's recorded values — content untouched.**
- Command (prod): same shape substituting `aiqadam-prod-secrets` / `/opt/apps/aiqadam-prod/deploy/.env`.
- Exit code: 0
- Output: `tvolodi:aiqadam-prod-secrets 640 700 1783959940` / `aiqadam-prod-secrets:x:980:tvolodi,deploy`. Size (700) and mtime (1783959940) numerically identical to Step 0's recorded values.
- Secondary check — `sudo -u deploy id`:
  - QA: `uid=999(deploy) gid=981(deploy) groups=981(deploy),980(aiqadam-qa-secrets),982(deploybots),986(docker)`
  - Prod: `uid=999(deploy) gid=981(deploy) groups=981(deploy),980(aiqadam-prod-secrets),982(deploybots),986(docker)`
- **PRIMARY functional check:** `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh`
  - QA — Exit code: **0**
    ```
    [deploy.sh placeholder] invoked 2026-07-17T06:37:06Z as deploy -- T-0113 will replace this with the real CI/CD deploy logic.
    NAME                     IMAGE                   COMMAND                  SERVICE     CREATED      STATUS                PORTS
    aiqadam-qa-api-1         aiqadam-qa-api:latest   "docker-entrypoint.s…"   api         4 days ago   Up 4 days (healthy)
    aiqadam-qa-oidc-stub-1   nginx:alpine            "/docker-entrypoint.…"   oidc-stub   4 days ago   Up 4 days (healthy)
    ```
  - Prod — Exit code: **0**
    ```
    [deploy.sh placeholder] invoked 2026-07-17T06:37:07Z as deploy -- T-0113 will replace this with the real CI/CD deploy logic.
    NAME                       IMAGE                     COMMAND                  SERVICE     CREATED      STATUS                PORTS
    aiqadam-prod-api-1         aiqadam-prod-api:latest   "docker-entrypoint.s…"   api         3 days ago   Up 3 days (healthy)
    aiqadam-prod-oidc-stub-1   nginx:alpine              "/docker-entrypoint.…"   oidc-stub   3 days ago   Up 3 days (healthy)
    aiqadam-prod-postgres-1    postgres:16               "docker-entrypoint.s…"   postgres    3 days ago   Up 3 days (healthy)
    ```
    **Prod now shows data rows for all 3 containers** (previously an empty table in attempt 3) — confirms the Step 11 `-p` fix resolved the cosmetic gap.
- Result: **PASS** on both hosts. No secret value read, printed, or logged.
- Backup taken: n/a (reversible via chgrp/chmod if ever needed; not exercised this attempt — no rollback occurred)

#### Step 12: Capture host SSH public keys for known_hosts pinning (management workstation, local)
- Command: `ssh-keyscan -t ed25519 95.46.211.230 > ...` and same for prod (`95.46.211.224`).
- Exit code: 0 (both)
- Output: QA `95.46.211.230 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfJ4OplY05m062tG2l6153V6TU6XJInr5Gl14poYJhH`; prod `95.46.211.224 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9lE6sL+QjaY3JpbH8kUtGuel2Kv4XJdQUtFU7s0Jau`. Both single-line, well-formed.
- Cross-check: `ssh-keygen -F <ip> -f known_hosts` confirmed both fingerprints match the workstation's existing `known_hosts` entries exactly.
- Result: success.
- Backup taken: n/a (local, read-only)

#### Step 13: Live SSH end-to-end test of each new deploy key — PASSED (both environments)
- Command (QA): `ssh -i "/c/Users/tvolo/.ssh/aiqadam-qa-deploy-ci" -o IdentitiesOnly=yes deploy@95.46.211.230`
- Exit code: **0**
- Output:
  ```
  Pseudo-terminal will not be allocated because stdin is not a terminal.
  [deploy.sh placeholder] invoked 2026-07-17T06:37:27Z as deploy -- T-0113 will replace this with the real CI/CD deploy logic.
  NAME                     IMAGE                   COMMAND                  SERVICE     CREATED      STATUS                PORTS
  aiqadam-qa-api-1         aiqadam-qa-api:latest   "docker-entrypoint.s…"   api         4 days ago   Up 4 days (healthy)
  aiqadam-qa-oidc-stub-1   nginx:alpine            "/docker-entrypoint.…"   oidc-stub   4 days ago   Up 4 days (healthy)
  ```
- Command (prod): same shape, `aiqadam-prod-deploy-ci` / `95.46.211.224`.
- Exit code: **0**
- Output: same shape, all 3 prod containers listed with data rows.
- **No "This account is currently not available." message on either host** — confirms the Step 7 shell fix resolved attempt 3's failure exactly as predicted: sshd's `<shell> -c <forced-command>` invocation now succeeds because `/bin/bash` can execute `-c`, whereas `/usr/sbin/nologin` unconditionally refused to.
- **Negative control (both hosts):** `ssh -i <key> -o IdentitiesOnly=yes deploy@<host-ip> "whoami; cat /etc/shadow"` — output on both hosts was **identical to the legitimate Step 13 run** (marker line + `docker compose ps` table), exit 0. The injected command (`whoami; cat /etc/shadow`) never executed; no `/etc/shadow` content or `whoami` output appeared. This is a **stronger, genuine proof** than attempt 3's degenerate pass (where both paths were blocked identically by nologin) — it now positively demonstrates that `authorized_keys`' `command=` override is the actual enforcing mechanism.
- Result: **PASS** on both hosts. Session connects, forced-command fires, marker line + `docker compose ps` table (with data rows) appears, connection closes cleanly (exit 0).
- Backup taken: n/a (Step 13 makes no host changes)

### Final verification sweep (both hosts, post Step 13)
- `test -f /etc/sudoers.d/90-deploy` → `ABSENT` (both hosts) — confirms no sudo grant was made.
- `getent group deploybots` → `deploybots:x:982:deploy` (both hosts).
- `id deploy` → groups include `deploy`, `docker`, `deploybots`, `aiqadam-<env>-secrets` (both hosts).
- `getent passwd deploy` → shell `/bin/bash` (both hosts) — the key changed-state check for this revision.
- `sudo grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` → `AllowGroups sshusers deploybots` (both hosts).
- `sudo sshd -t` → exit 0 (`SSHD_OK`); `systemctl is-active ssh.service` → `active` (both hosts).
- Final Penpot re-check (prod): all 7 containers `Up` (2 `healthy`); `https://penpot.aiqadam.org` → `200`; `https://aiqadam.org/health` → `200`. No regression at end of run.

### Rollback executed
Not needed — every step succeeded on both hosts on the first pass. No rollback commands were run this attempt.

### Resources changed
- **Files on host (both hosts, all permanent — no rollback):**
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` — `AllowGroups` edited to `sshusers deploybots`. New backups retained: QA `40-ai-dala-infra.conf.pre-T0112.20260717T063435Z.bak`, prod `40-ai-dala-infra.conf.pre-T0112.20260717T063437Z.bak` (plus all three prior attempts' backups, untouched).
  - `/home/deploy/` created (including `.ssh/authorized_keys`, mode 600, one forced-command line per host).
  - `/opt/apps/aiqadam-qa/deploy/deploy.sh` (QA) and `/opt/apps/aiqadam-prod/deploy/deploy.sh` (prod) — new files, mode 750, owner `deploy:deploy`, with explicit `-p aiqadam-<env>` flag.
  - `/opt/apps/aiqadam-qa/deploy/.env` and `/opt/apps/aiqadam-prod/deploy/.env` — group changed to `aiqadam-<env>-secrets`, mode changed to 640. Content never read or written at any point; size/mtime confirmed numerically unchanged from Step 0's baseline.
- **Users/groups created (both hosts, permanent):** `deploybots` group (gid 982), `deploy` system user (uid 999, shell `/bin/bash`), `aiqadam-<env>-secrets` group (gid 980, members `tvolodi,deploy`).
- **Services restarted:** `ssh.service` reloaded once per host (`systemctl reload`, not `restart`) — no dropped sessions, no downtime, confirmed by continued successful SSH connections immediately after.
- **External resources changed:** none. No GitHub API/secret call was made (out of scope for this executor per the plan).
- **Local artifacts (workstation):** the same two ed25519 keypairs (`aiqadam-qa-deploy-ci`, `aiqadam-prod-deploy-ci` + `.pub`), now installed and live-verified on their respective hosts. `known_hosts`-cross-checked host key captures at `$TEMP\qa-host-key.pub` / `prod-host-key.pub`.

## Issues / risks
- **This is the first fully successful execution of T-0112's plan across four attempts.** Steps 0–12 were already proven correct by attempt 3; this attempt additionally proves Step 13 (the live SSH end-to-end test, including a genuine positive-proof negative control) now passes on both hosts, confirming the Step 7 shell fix (`/usr/sbin/nologin` → `/bin/bash`) and the Step 11 `-p aiqadam-<env>` fix both work exactly as the solution-designer predicted.
- **No secret-exposure incident.** The `.env`-content-reading prohibition was fully observed at every step; only `stat`-based metadata checks and the functional `deploy.sh` exit-code/marker-line check were used to verify `.env` access, consistent with the plan's hard constraint.
- **Both hosts' sshd was reloaded once this attempt** (not twice, since no rollback was needed) — validated with `sshd -t` before reload, used `systemctl reload` (never `restart`); no session drops or downtime observed at any point, and Penpot was re-verified unregressed both immediately after the Step 5/6 reload and again at the end of the run.
- **Blast radius matches exactly what the approved plan declared:** the `deploy` user (with `/bin/bash` shell, locked down entirely by `authorized_keys`' `command=`/`no-pty`/`no-port-forwarding`/`no-X11-forwarding`/`no-agent-forwarding`), the `deploybots` group, the two `deploy.sh` files, the two `aiqadam-<env>-secrets` groups, and the group/mode bits (never content) of the two `.env` files. No existing operator account, sudoers drop-in, Docker container, nginx vhost, TLS cert, Cloudflare record, or secret value was touched.
- **Off-plan observation (not fixed, per instructions):** none noticed. All host state observed during this run matched the plan's expectations exactly; nothing extraneous was flagged.
- **Remaining T-0112 acceptance-criteria items outside this executor's scope:** pasting the private keys and host keys into GitHub Actions repository secrets (`QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY` in `aiqadam/ai-qadam-platform`) remains a manual user action per the plan's own scoping — not attempted by this executor, and not something any repo tooling here performs automatically.

## Open questions (optional)
- None from this executor's perspective — the plan executed exactly as designed, on both hosts, with no deviations or improvisations required. The one item requiring follow-up is procedural, not technical: the user still needs to complete the manual GitHub Actions secrets paste step before T-0112 can be marked fully `done` (its "What done looks like" checklist explicitly includes that step). Step 07/08 should account for this distinction — the on-host provisioning and live-verification acceptance criteria are met; the GitHub-side secret storage criterion is not yet met and is out of this repo's tooling scope.
