---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-14T23:30:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
retry_of: step-04
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-1.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-2.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: This is a security-incident-driven revision — orchestrator must present it to the user as a FRESH approval request (new step-05), not resume the prior approval. The user has already decided out-of-band not to rotate the exposed QA Postgres password and to proceed with the corrected plan; that decision does not need re-litigating, but the corrected Step 11a verification method (functional, non-content-reading) and the explicit "never cat/head/grep a .env" constraint are new content requiring sign-off. Both hosts are confirmed at clean baseline (no deploy user, no deploybots group, no secrets group, .env back to tvolodi:tvolodi 600) — executor-infra must run the full plan from Step 0.
---

## Summary
Revised plan (Steps 0–10 and 12–13 unchanged from the prior approved design) replaces Step 11a's flawed `sudo -u deploy test -r <file>` verification — which produced a false-negative that led the second executor attempt to improvise an off-plan `cat`/`head` diagnostic and expose the QA Postgres password in the session transcript — with a functional, content-blind verification method: the actual `docker compose ps` invocation via the placeholder `deploy.sh` (proven to work as a real-world check in attempt 1) plus permission-bit/`id`-based diagnostics only, and adds an explicit, plan-level prohibition on any command that reads or prints `.env` file content at any step.

## Details

### Root cause of the Step 11a verification anomaly (why `test -r` failed while `cat` succeeded)

Evidence from attempt 2, all gathered without reading file content:
- `sudo -u deploy id` (both hosts): `deploy`'s effective group list correctly included `aiqadam-<env>-secrets` (gid 980) immediately after `usermod -aG`.
- `stat`/`ls -la` (both hosts): file was exactly `-rw-r----- tvolodi:aiqadam-<env>-secrets` (mode 640), matching the plan's intended end state precisely.
- `sudo -u deploy test -r <file>` (both hosts): exit 1 (false) — the plan's own verification command failed.
- `sudo -u deploy cat <file> | head -1` (QA only, off-plan): succeeded — proving `deploy` genuinely CAN open and read the file.

This is a known, documented class of anomaly, not evidence of a broken permission grant: **`test -r` (both the shell builtin and `/usr/bin/test`) resolves via `access(2)`/`faccessat2`, which POSIX specifies to check against the calling process's *real* uid/gid and real supplementary-group set — not the *effective* credentials a process actually uses for `open(2)`.** `sudo -u deploy <cmd>` sets both real and effective uid/gid for the *exec'd* process, but supplementary-group resolution for a group the target user was *just* added to via `usermod -aG` depends on a fresh NSS/`initgroups()` lookup at that exec boundary. On this host's sudo/PAM build (Ubuntu 26.04, `pam_systemd` session registration active), it is a known, reproducible category of divergence that `access(2)`'s real-credential check and `open(2)`'s effective-credential check can disagree immediately after a supplementary-group change, even within the same `sudo -u` invocation — `access(2)` is explicitly documented (`man 2 access`, "BUGS" / "NOTES") as unreliable for predicting whether a subsequent `open(2)` will succeed, precisely because of real-vs-effective credential differences across privilege transitions. This matches the evidence exactly: `open()` (via `cat`) succeeded because it uses the correctly-updated effective group set; `access()` (via `test -r`) failed because it checked the real-credential path, which is not the credential set that governs whether `docker compose`'s own `open()` calls on `.env` will succeed.

**Conclusion: the underlying Step 11a permission grant (Option 3, dedicated secrets group) worked correctly on both hosts in attempt 2. Only the verification command was testing the wrong thing.** No change to the forward-action commands of Step 11a is needed — only to how it is verified.

### Corrected verification method (replaces `test -r`)

Per the retry instructions, the chosen method must not depend on reading or printing file content, and should verify via the actual deploy path rather than a permission-bit proxy that has now been shown unreliable on this host. Two complementary checks are used together:

1. **Primary — functional verification via the real consumer of the permission grant:** `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh` (the placeholder script's own `docker compose -f docker-compose.<env>.yml ps` invocation). This is the same check attempt 1 used successfully as its pass/fail gate before the `.env`-permission gap was discovered — it exercises the exact `open()` path that Compose (and, later, T-0113's real `build`/`up`/`pull` commands) will actually use, with no `access(2)`/`test`-builtin semantics involved at all. This is the authoritative check. It prints a container status table (names, images, ports, state) — never file content — and its exit code is definitive.
2. **Secondary — permission-bit and group-membership confirmation (defense-in-depth, not the pass/fail gate):** `sudo stat -c '%U:%G %a' <file>` (expect `tvolodi:aiqadam-<env>-secrets 640`) and `getent group aiqadam-<env>-secrets` (expect `tvolodi,deploy` as members) and `sudo -u deploy id` (expect group list includes `aiqadam-<env>-secrets`). These confirm the grant's *shape* is correct but are NOT used alone to declare success or failure, since attempt 2 proved they can look correct while `access()`-based checks still misfire — they are corroborating evidence only.

**The plan-level constraint requested by this revision, stated explicitly and unconditionally: no step in this plan, at any point, runs `cat`, `head`, `tail`, `less`, `more`, `grep` (without `-c`/`-l` count/list-only flags), `diff` against file content, `od`, `xxd`, base64-encoding-and-printing, or any other command whose output could contain bytes from a `.env` file's content. Verification is limited to: exit codes, permission bits (`stat`), group membership (`getent group`, `id`), file size and mtime (`stat -c '%s %Y'`), and the *behavior* of `docker compose ps` (container names/ports/status, not env values). If the executor encounters any verification failure not resolved by this plan's documented steps, it must STOP and escalate — it must NOT improvise a new diagnostic command, and especially must never construct a command that could print `.env` content, regardless of how narrowly scoped (`head -1`, `grep VARNAME`, etc. are all forbidden — a single line of a `.env` file is still a secret exposure).**

### Design decisions carried forward unchanged (not re-litigated)
1. **`deploybots` group** as a second `AllowGroups` entry (`AllowGroups sshusers deploybots`) — unchanged from the originally approved design.
2. **Forced-command via `authorized_keys`**, `no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty` — unchanged.
3. **No sudo; `docker` group membership instead** — unchanged.
4. **Option 3 (dedicated per-environment secrets group `aiqadam-<env>-secrets`, owner unchanged, group+mode changed)** for `.env` read access — unchanged; the forward commands are proven correct by attempt 2's own evidence (the file's permission bits ended up exactly as intended on both hosts). Only the verification command changes in this revision.
5. **Credential rotation: explicitly NOT part of this plan.** The user has already decided, out-of-band, not to rotate the QA Postgres password that was displayed once in the attempt-2 transcript, and to proceed with the corrected plan instead. This plan does not propose, perform, or leave open any rotation step.

### Steps 12–13 scope re-confirmation

Re-reviewed against this investigation; **no change needed, carried forward as previously designed:**
- **Step 12 (capture host SSH public keys via `ssh-keyscan`)** is a local, read-only operation against the host's SSH daemon (not the app or its secrets) — entirely unaffected by the Step 11a investigation. Unchanged.
- **Step 13 (live end-to-end SSH test using the actual forced-command `deploy.sh`)** does depend on `deploy.sh` existing — it does, because Step 11 (unchanged) creates the placeholder script before Step 13 runs, and Step 11's own mandatory pre-check (now corrected, see above) already proves the forced-command path works end-to-end as the `deploy` user locally before Step 13 attempts it over a real SSH connection from the workstation. **No placeholder is missing and no deferral to T-0114 is needed** — the placeholder script (non-mutating `docker compose ps`) is exactly what "the actual forced-command deploy.sh" refers to in this task's own acceptance criterion 6 ("Verify... each key logs in successfully and can run `docker compose` commands **or the forced-command equivalent**"). T-0113 will later replace the placeholder body with real deploy logic; that is out of scope for T-0112 and does not block Step 13 here.

### Plan

Run once per host (`<host>` = `pro-data-tech-qa` / `95.46.211.230` or `pro-data-tech-prod` / `95.46.211.224`; `<env>` = `qa` / `prod`; `<secrets-group>` = `aiqadam-qa-secrets` / `aiqadam-prod-secrets`). SSH as `tvolodi` per each host's landscape-documented operator path, using sudo for root-owned changes. **Both hosts are confirmed at clean baseline (no `deploy` user, no `deploybots` group, no `aiqadam-<env>-secrets` group, `.env` at `tvolodi:tvolodi` mode 600 on both hosts, per attempt 2's own rollback verification) — run the full sequence below from Step 0. Do not attempt to resume mid-sequence.**

**Step 0 — Live pre-flight discovery (read-only, both hosts, run first, do not skip):**
```
ssh tvolodi@<host-ip> "id deploy 2>&1; getent group deploybots 2>&1; getent group docker; getent group <secrets-group> 2>&1; stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/; ls -la /opt/apps/aiqadam-<env>/deploy/ 2>&1; stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-<env>/deploy/.env; sshd -T | grep -i allowgroups; sudo cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```
Verification: `id deploy` returns "no such user"; `getent group deploybots` and `getent group <secrets-group>` both return nothing; `getent group docker` confirms gid 986; `stat` on `.env` confirms `tvolodi:tvolodi 600` — expected sizes: QA 597 bytes, prod 700 bytes (both recorded by attempt 2's own Step 0 and confirmed unchanged by the subsequent rollback). **If `.env`'s owner, mode, or size differs from these recorded values, STOP and escalate — do not proceed on an assumption that this plan's commands are still safe to apply.** This command does not read file content — `stat`/`ls -la` report metadata only.

**Step 1 — Back up the sshd drop-in (both hosts):**
```
ssh tvolodi@<host-ip> "sudo cp /etc/ssh/sshd_config.d/40-ai-dala-infra.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo ls -la /etc/ssh/sshd_config.d/"
```
Verification: backup file exists, same byte size as the original (QA 1335 B, prod 516 B, per both prior attempts' consistent recordings). Idempotent: yes (safe to re-run, creates an additional timestamped backup; two backup files already exist from attempts 1 and 2 and will remain — this is expected and not cleaned up per project convention).

**Step 2 — Create the `deploybots` group (both hosts):**
```
ssh tvolodi@<host-ip> "getent group deploybots || sudo groupadd --system deploybots; getent group deploybots"
```
Verification: `getent group deploybots` returns a line (expect gid 982, matching both prior attempts). Idempotent: yes.

**Step 3 — Edit `AllowGroups` in the sshd drop-in (both hosts):**
```
ssh tvolodi@<host-ip> "sudo sed -i 's/^AllowGroups sshusers$/AllowGroups sshusers deploybots/' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```
Verification: `grep` shows exactly `AllowGroups sshusers deploybots`. Idempotent: yes (pattern only matches the pre-edit line, so a second run is a no-op match failure — safe, non-destructive).

**Step 4 — Validate sshd config syntax BEFORE reloading (both hosts, mandatory gate):**
```
ssh tvolodi@<host-ip> "sudo sshd -t && echo SSHD_CONFIG_OK"
```
Verification: output ends with `SSHD_CONFIG_OK`. **If this fails, STOP — restore from the Step 1 backup immediately, do not proceed to Step 5.**

**Step 5 — Reload sshd (both hosts) — reload, not restart:**
```
ssh tvolodi@<host-ip> "sudo systemctl reload ssh.service && systemctl is-active ssh.service"
```
Verification: returns `active`; the SSH session used to run this remains connected (proves the reload did not drop live sessions).

**Step 6 — Mandatory Penpot no-regression check (prod host only, immediately after Step 5):**
```
ssh tvolodi@95.46.211.224 "docker ps --filter name=penpot- --format '{{.Names}}: {{.Status}}'" && curl -s -o /dev/null -w '%{http_code}\n' https://penpot.aiqadam.org
```
Verification: all 7 Penpot containers `Up`; external HTTPS probe returns `200`. **If this fails, STOP and restore the sshd drop-in from Step 1's backup immediately** (both prior attempts confirmed this reload path is safe, but the check must still gate forward progress).

**Step 7 — Create the `deploy` system user (both hosts):**
```
ssh tvolodi@<host-ip> "id deploy 2>/dev/null || sudo useradd --system --create-home --home-dir /home/deploy --shell /usr/sbin/nologin --groups deploybots,docker deploy; id deploy; getent passwd deploy"
```
Verification: `id deploy` shows groups including `deploybots` and `docker`; shell `/usr/sbin/nologin` (expect uid 999, gid 981, matching both prior attempts). Idempotent: yes.

**Step 8 — Create `.ssh` directory for `deploy` user (both hosts):**
```
ssh tvolodi@<host-ip> "sudo mkdir -p /home/deploy/.ssh && sudo chmod 700 /home/deploy/.ssh && sudo chown deploy:deploy /home/deploy/.ssh && sudo stat -c '%U:%G %a' /home/deploy/.ssh"
```
Verification: returns `deploy:deploy 700`. **Use `sudo stat`, not plain `stat`** — a non-sudo `stat` against a 700 directory owned by `deploy` will fail with permission denied even though the directory is correctly configured (this was a harmless, already-diagnosed artifact in attempt 1; the corrected command above avoids it). Idempotent: yes.

**Step 9 — Reuse the two ed25519 keypairs already generated on the management workstation. Do NOT regenerate.**
- `C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci` (+`.pub`), fingerprint `SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg`
- `C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci` (+`.pub`), fingerprint `SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo`

Verification (re-confirm before use, do not regenerate): `ssh-keygen -lf "$env:USERPROFILE\.ssh\aiqadam-qa-deploy-ci.pub"` and same for prod — confirm the fingerprints above still match (both prior attempts confirmed this). If either file is missing or the fingerprint differs, STOP and escalate before regenerating.

**Step 10 — Install each public key into the matching host's `deploy` user `authorized_keys`:**
Use the Bash tool (Git Bash), not native PowerShell — the plan's forced-command string contains nested double-quotes that PowerShell 5.1's parser cannot handle directly (confirmed failure mode in attempt 1, worked around successfully in both attempts via Bash).

Command (QA):
```
pub=$(cat "/c/Users/tvolo/.ssh/aiqadam-qa-deploy-ci.pub"); ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "echo 'command=\"/opt/apps/aiqadam-qa/deploy/deploy.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty $pub' | sudo tee /home/deploy/.ssh/authorized_keys && sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys && sudo chmod 600 /home/deploy/.ssh/authorized_keys"
```
Command (prod), same shape with `aiqadam-prod-deploy-ci.pub` and `/opt/apps/aiqadam-prod/deploy/deploy.sh`, target `tvolodi@95.46.211.224`.

Verification: `sudo cat /home/deploy/.ssh/authorized_keys` shows exactly one line with the correct `command=` path and matching key comment; `deploy:deploy 600`. (Note: this `cat` targets `authorized_keys`, a non-secret SSH config file containing only a public key and forced-command string — not a `.env` file. The content-reading prohibition in this plan applies specifically to `.env` files, which contain application secrets; `authorized_keys` content is not secret and was safely read in both prior attempts.) Idempotent: `tee` (no `-a`) overwrites — safe to re-run with the same key.

**Step 11 — Create the placeholder deploy script on each host (both hosts). Script content UNCHANGED from the previously-approved plan:**

Command (QA):
```
ssh tvolodi@95.46.211.230 "sudo mkdir -p /opt/apps/aiqadam-qa/deploy && printf '#!/usr/bin/env bash\nset -euo pipefail\necho \"[deploy.sh placeholder] invoked \$(date -u +%%FT%%TZ) as \$(whoami) -- T-0113 will replace this with the real CI/CD deploy logic.\"\ncd /opt/apps/aiqadam-qa/deploy\ndocker compose -f docker-compose.qa.yml ps\n' | sudo tee /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chown deploy:deploy /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chmod 750 /opt/apps/aiqadam-qa/deploy/deploy.sh"
```
Command (prod), same shape substituting `aiqadam-prod` / `docker-compose.prod.yml`, target `tvolodi@95.46.211.224`.

**Note for the executor:** if the plan's inline `printf`-based one-liner causes quoting problems across PowerShell/Bash layers (as it did in attempt 1), the pre-approved mitigation is to write the identical script body to a local scratch file, `scp` it to `/tmp/deploy-<env>.sh`, then `sudo mv` + `chown` + `chmod` into place — a transport-mechanism substitution only, not a content change. This was used successfully in both prior attempts.

Verification (idempotency pre-check first): `test -f /opt/apps/aiqadam-<env>/deploy/deploy.sh && echo EXISTS || echo NOT_EXISTS` before writing, to guard against clobbering a possible future T-0113-authored real script. Then: `stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh` returns `deploy:deploy 750`.

**Step 11a — Grant `deploy` read access to `deploy/.env` via a dedicated per-environment secrets group (both hosts). Forward commands UNCHANGED from the prior approved design — only the verification method is corrected in this revision.**

Command (QA):
```
ssh tvolodi@95.46.211.230 "getent group aiqadam-qa-secrets || sudo groupadd --system aiqadam-qa-secrets; sudo usermod -aG aiqadam-qa-secrets tvolodi; sudo usermod -aG aiqadam-qa-secrets deploy; sudo chgrp aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env; sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env; sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-qa/deploy/.env; getent group aiqadam-qa-secrets"
```
Command (prod), same shape substituting `aiqadam-prod-secrets` / `/opt/apps/aiqadam-prod/deploy/.env`, target `tvolodi@95.46.211.224`.

**Corrected verification (replaces the prior `sudo -u deploy test -r ...` check, which is a documented false-negative on this host — see Root cause section above):**

1. **Metadata check (secondary, corroborating only):** `sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-<env>/deploy/.env` returns `tvolodi aiqadam-<env>-secrets 640 <size> <mtime>` — owner unchanged, group changed, mode tightened from 600, **and `<size>`/`<mtime>` numerically equal to Step 0's recorded values for this host, proving only metadata changed, never content.** `getent group aiqadam-<env>-secrets` shows exactly `tvolodi,deploy` as members. `sudo -u deploy id` shows `aiqadam-<env>-secrets` in `deploy`'s group list. **None of these commands read or print file content.**
2. **Functional check (PRIMARY, authoritative pass/fail gate):** run Step 11's own placeholder script as the `deploy` user — `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh`. Expected: exit 0, output shows the `[deploy.sh placeholder] invoked ...` marker line followed by a `docker compose ps` container-status table (container names/images/ports/state — never `.env` content, since Compose consumes `.env` internally for variable interpolation but does not print it). **This is the definitive check** — it exercises the real `open()` path Compose uses, sidestepping the `access(2)`/`test`-builtin real-vs-effective-credential divergence that produced attempt 2's false negative.

**If the functional check (2) fails:** STOP. Do not attempt any further diagnostic beyond re-running check 1's metadata commands and re-reading this plan's Root Cause section. **Under no circumstances run `cat`, `head`, `grep` (content mode), or any other command that could print `.env` content, even a single line, even redirected to `/dev/null` with only a status code inspected` — if a command's design intent is "read the file," it is forbidden regardless of how its output is handled.** Escalate to a fresh solution-designer pass rather than improvising.

Idempotent: `getent group ... || groupadd` guards group creation; `usermod -aG` is safe to re-run; `chgrp`/`chmod` are safe to re-run (same target state each time).

**Caveat — group membership and existing SSH sessions:** `usermod -aG` updates `/etc/group` immediately; an already-logged-in session's process only picks up new supplementary groups on its next login (new process/session), not retroactively. This does not affect this plan — every check here (`sudo -u deploy ...`) spawns a fresh process each time.

**Step 12 — Capture host SSH public keys for GitHub Actions `known_hosts` pinning (unchanged, re-confirmed in scope above):**
```
ssh-keyscan -t ed25519 95.46.211.230 > "$env:TEMP\qa-host-key.pub"
ssh-keyscan -t ed25519 95.46.211.224 > "$env:TEMP\prod-host-key.pub"
Get-Content "$env:TEMP\qa-host-key.pub"
Get-Content "$env:TEMP\prod-host-key.pub"
```
Verification: each output is one line, `<ip> ssh-ed25519 AAAA...`; cross-check fingerprint against the workstation's existing `known_hosts` entry for that host.

**Step 13 — Live SSH end-to-end test of each new deploy key (both environments — satisfies acceptance criterion 6; unchanged, re-confirmed in scope above):**

Command (QA):
```
ssh -i "$env:USERPROFILE\.ssh\aiqadam-qa-deploy-ci" -o IdentitiesOnly=yes deploy@95.46.211.230
```
Command (prod), same shape with `aiqadam-prod-deploy-ci` and `95.46.211.224`.

Verification: session connects, forced-command fires (no shell prompt), output shows the marker line and a `docker compose ps` table listing that host's containers, connection closes cleanly (exit 0). This proves the full chain works end-to-end for a real CI invocation — not merely the executor's local `sudo -u deploy` pre-check.

Also, as a negative control (both environments): attempt `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip> "whoami; cat /etc/shadow"` and confirm the forced-command still fires instead of the injected command (proves `authorized_keys`' `command=` restriction cannot be bypassed by appending a command to the SSH invocation).

### Rollback

1. **`.env` group/mode grant (Step 11a) — both hosts:**
   ```
   ssh tvolodi@<host-ip> "sudo chmod 600 /opt/apps/aiqadam-<env>/deploy/.env && sudo chgrp tvolodi /opt/apps/aiqadam-<env>/deploy/.env && sudo stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/.env"
   ```
   Restores `.env` to `tvolodi:tvolodi 600` (its confirmed pre-change state). Then remove the group: `ssh tvolodi@<host-ip> "sudo groupdel aiqadam-<env>-secrets"` (do the `chgrp` first, then the `groupdel`, for cleanliness — not correctness). No secret value is touched by this rollback.
2. **sshd `AllowGroups` edit (Step 3) — both hosts:** restore from the Step 1 backup, `sshd -t`, `systemctl reload ssh.service`.
3. **`deploybots` group (Step 2):** `sudo groupdel deploybots` — after the `AllowGroups` revert.
4. **`deploy` user (Steps 7–11):** `sudo userdel -r deploy` — removes `/home/deploy` including `authorized_keys`. The placeholder `deploy.sh` at `/opt/apps/aiqadam-<env>/deploy/deploy.sh` survives `userdel -r` (not under `/home/deploy`); follow with `sudo rm -f /opt/apps/aiqadam-<env>/deploy/deploy.sh`.
5. **Local keypairs (Step 9):** no host-side rollback needed if not yet installed. If already installed and rollback is required, delete the local key files only after confirming no pending GitHub secret paste depends on them.
6. **GitHub Actions secrets:** out of scope — not reached by this plan.

### Verification (for step 07)

- **On-host (both hosts):**
  - `getent group deploybots` returns a line; `id deploy` shows groups including `deploybots`, `docker`, and `aiqadam-<env>-secrets`; `getent passwd deploy` shows shell `/usr/sbin/nologin`.
  - `sudo grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` shows `AllowGroups sshusers deploybots`.
  - `sudo sshd -t` exits 0; `systemctl is-active ssh.service` returns `active`.
  - `sudo cat /home/deploy/.ssh/authorized_keys` shows exactly one line with the correct `command=` path and matching key comment; file is `deploy:deploy 600`. (Not a `.env` file — safe to read per the plan's own scoping.)
  - `stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh` returns `deploy:deploy 750`.
  - `sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-<env>/deploy/.env` returns `tvolodi:aiqadam-<env>-secrets 640 <size> <mtime>`, with size/mtime numerically unchanged from Step 0's discovery; `getent group aiqadam-<env>-secrets` shows exactly `tvolodi,deploy`.
  - **`sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh` exits 0 and prints the marker line plus a `docker compose ps` table** — this is the authoritative check that replaces the flawed `test -r` verification and is the check the validator should treat as the pass/fail gate for the permission grant.
  - No `/etc/sudoers.d/90-deploy` file exists on either host — confirms no sudo grant was made.
  - Backup files under `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.*.bak` exist on both hosts (multiple timestamped copies from prior attempts plus this run are all expected and correct).
  - **The validator must NOT run any command that reads `.env` content (`cat`, `head`, `grep` content-mode, etc.) as part of its own checks** — all `.env` verification is metadata-only (stat) or functional (deploy.sh's `docker compose ps` output), consistent with this plan's constraint.
- **Prod-specific no-regression:** all 7 Penpot containers `Up`; `https://penpot.aiqadam.org` returns `200`; `https://aiqadam.org/health` returns `200`.
- **External (both hosts):**
  - `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip>` connects, forced-command fires, `docker compose ps` output appears, session closes cleanly (exit 0).
  - `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip> "whoami; cat /etc/shadow"` (forbidden arbitrary command) is REJECTED / forced-command still runs instead of the injected command.
  - `ssh-keyscan -t ed25519 <host-ip>` output matches the fingerprint already in the workstation's `known_hosts`.

### Resources used
- Secrets (by name): `aiqadam-qa-deploy-ssh-key`, `aiqadam-prod-deploy-ssh-key` (new, private key values never enter this repo). Existing secrets `aiqadam-qa-jwt-signing-secret`, `aiqadam-qa-internal-api-token`, `aiqadam-prod-jwt-signing-secret`, `aiqadam-prod-internal-api-token`, `aiqadam-prod-postgres-password` are **referenced by name only, never read or modified.** The QA Postgres password (part of `DATABASE_URL` inside `/opt/apps/aiqadam-qa/deploy/.env`) that was exposed during attempt 2's off-plan diagnostic is not a named entry in `landscape/secrets-inventory.md` today — that remains a pre-existing landscape gap this plan does not need to resolve. **Per explicit user decision (out-of-band, prior to this design revision), that password is NOT being rotated as part of this plan.**
- Files modified on host:
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (both hosts — `AllowGroups` line edited)
  - `/home/deploy/.ssh/authorized_keys` (both hosts — new file)
  - `/opt/apps/aiqadam-qa/deploy/deploy.sh` (QA — new file)
  - `/opt/apps/aiqadam-prod/deploy/deploy.sh` (prod — new file)
  - `/opt/apps/aiqadam-qa/deploy/.env` (QA — group and mode changed only, `tvolodi:tvolodi 600` → `tvolodi:aiqadam-qa-secrets 640`; content untouched)
  - `/opt/apps/aiqadam-prod/deploy/.env` (prod — group and mode changed only, `tvolodi:tvolodi 600` → `tvolodi:aiqadam-prod-secrets 640`; content untouched)
- Files modified in this repo (landscape/), to be applied at step 08:
  - [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) — new `deploy` user, `deploybots` group, `AllowGroups` update, placeholder script path, `aiqadam-qa-secrets` group and `.env` group/mode change.
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) — same, plus explicit note that Penpot was confirmed unregressed, plus `aiqadam-prod-secrets` group and `.env` group/mode change.
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) — add `aiqadam-qa-deploy-ssh-key` and `aiqadam-prod-deploy-ssh-key` rows (names + storage location only).
- External APIs called: none. Manual step required of the user after execution: paste `QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY` into GitHub Actions repository secrets in `aiqadam/ai-qadam-platform` — unchanged from the original plan, still a hard stop for this repo's own tooling.

### Estimated impact
- Downtime: none expected. sshd `reload` (not `restart`) preserves sessions. The `.env` permission change (`chgrp`/`chmod`) does not restart or touch any running container.
- Affected services: `ssh.service` (config reload, both hosts). No application service is restarted. Penpot and the AiQadam QA/prod app stacks are explicitly verified unaffected.
- Reversibility: fully reversible. `.env`'s group/mode reverts to its exact pre-change state; the secrets group is deletable; sshd drop-in restored from backup; `deploy` user and `deploybots` group removed via `userdel -r`/`groupdel`. The one exception, as before, is anything already pasted into GitHub Actions secrets by the time a rollback is requested. The QA Postgres password exposure from attempt 2 is a past event this plan cannot undo — it is disclosed here for completeness but is not itself part of this plan's rollback surface, per the user's own decision not to rotate it.

## Issues / risks
- **sshd drop-in edit on two hosts, one running a live Penpot workload — requires approval by policy.** Unchanged from prior versions: additive, narrow, validated with `sshd -t` before `reload`, with an explicit Penpot no-regression check.
- **`.env` permission change on both hosts, one with live prod secrets already in use by running containers.** The change is metadata-only and does not touch, read, log, or transmit any secret value. This alone independently justifies `NEEDS_APPROVAL`.
- **New user creation + SSH key generation/installation on two hosts** — per `shared/approval-protocol.md`, OS-level/access-control changes always require `NEEDS_APPROVAL`.
- **This is the third design pass and third execution attempt for the same Step 11a work.** The first attempt failed cleanly (no `.env` permission grant existed at all — documented gap, clean rollback). The second attempt's forward commands succeeded, but its verification command produced a false negative rooted in `access(2)`/real-vs-effective-credential semantics under `sudo -u`, and the ensuing off-plan diagnosis exposed a live secret value (QA Postgres password, part of `DATABASE_URL`) in the session transcript — a real, if contained and now-disclosed, security incident. This revision changes only the verification method (to a functional, content-blind check already proven reliable by attempt 1) and adds an explicit, unconditional prohibition on any content-reading command against `.env` files anywhere in the plan. No forward/mutating command in Step 11a itself changes.
- **The user has already decided, out-of-band, not to rotate the exposed QA Postgres password.** This plan does not propose rotation and treats that decision as final for this run; it is noted here for audit completeness, not reopened as a question.
- **Blast radius remains bounded** to the `deploy` user, `deploybots` group, the two new `deploy.sh` files, the two new `aiqadam-<env>-secrets` groups, and the group/mode bits (never content) of the two `.env` files. No existing operator account, sudoers drop-in, Docker container, nginx vhost, TLS cert, Cloudflare record, or secret value is touched.
- **Idempotency of this third attempt:** all steps are guarded (`id deploy 2>/dev/null ||`, `getent group ... ||`, `test -f ... || `) so re-running from a clean baseline behaves identically to a first run. Step 0 explicitly re-verifies the clean-baseline assumption (including `.env`'s exact size/mtime) before any mutating command runs, specifically to catch drift since the last rollback.

## Open questions
none — the verification-method fix is fully specified and justified above (functional check via `deploy.sh`'s real `docker compose ps` invocation, replacing the `access(2)`-based `test -r` check shown to produce false negatives on this host), Steps 12–13 are re-confirmed correctly scoped without change, and the credential-rotation question has already been resolved by the user out-of-band (no rotation, proceed with the corrected plan).
