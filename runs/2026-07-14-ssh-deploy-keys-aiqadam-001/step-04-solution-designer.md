---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-14T12:30:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
retry_of: step-04
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-1.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - shared/app-registry.md
  - workflows/infrastructure.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Orchestrator should present this revised plan to the user for a fresh APPROVE/REJECT/MODIFY, per shared/approval-protocol.md — the three previously-approved design decisions (deploybots group, forced-command+no-pty, no-sudo/docker-group) are unchanged and do not need re-litigating; only the NEW Step 11a (.env read-access grant) is net-new content requiring sign-off. Executor-infra must re-run the full plan from Step 0 (both hosts are back at clean baseline per the attempt-1 rollback); Steps 0-10 are unchanged from the previously-approved plan and Step 9's local keypairs should be REUSED, not regenerated (still present at C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci and aiqadam-prod-deploy-ci, unused, safe to reuse per attempt-1's own rollback note).
---

## Summary
Revised plan (same overall shape as the previously-approved design) creates a dedicated `deploy` system user on both `pro-data-tech-qa` and `pro-data-tech-prod`, gated into SSH via the `deploybots` group in `AllowGroups`, restricted to a forced-command placeholder script with no sudo — and now additionally creates one new per-environment secrets group (`aiqadam-qa-secrets` / `aiqadam-prod-secrets`) that co-owns each host's `deploy/.env` file (group changed to the new group, mode tightened to 640) so that `deploy` can read the file Compose needs for variable interpolation, closing the gap that caused attempt 1 to fail its own Step 11 pre-check.

## Details

### What changed since the prior (approved) version, and why

Attempt 1 executed Steps 0–10 successfully on both hosts but failed its own Step 11 pre-check: `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh` returned `open .../deploy/.env: permission denied`, because `docker compose -f docker-compose.<env>.yml ps` reads the `.env` file that `docker-compose.<env>.yml` references (via `env_file:`/implicit `.env` interpolation) for variable substitution — and `.env` is `tvolodi:tvolodi` mode 600 on both hosts, unreadable by `deploy` regardless of `deploy`'s group memberships (`deploybots`, `docker`), neither of which co-owns that file. The executor correctly stopped rather than improvise, and rolled back cleanly — both hosts are confirmed back at their exact pre-execution baseline. Nothing about the three previously-approved design decisions changes here; this is a narrow addition of one new step (a permission grant) inserted before the existing Step 11.

**None of it can be worked around by changing the placeholder script instead.** T-0113 (the next task, `blocked_by` this one) will replace the placeholder body with the real deploy logic (`docker compose ... build`, `up -d`, `pull`), and every one of those commands reads the same `.env` for the same reason `ps` does — Compose resolves `${VAR}` interpolation in the compose file from `.env` before it can do anything, including a read-only `ps`. Switching the smoke test to a command that doesn't need `.env` (e.g. `docker compose ls` or `docker ps --filter`) would make attempt 1's own pre-check pass, but would only be papering over the gap: T-0113's real commands would hit the identical `permission denied` the first time CI actually tries to deploy. The fix must be a real, persistent read grant on `.env` for the `deploy` user, not a smoke-test workaround.

### Option analysis (per the retry instructions — evaluated, one recommended)

**Option 1 — `chgrp docker` + `chmod 640`.** Rejected as primary. `docker` group membership is driven by an unrelated concern (Docker daemon socket access) and already includes every human operator on each host (`tvolodi`/`viktor_d`/`binali_r` on QA; `tvolodi` on prod) plus, after this task, `deploy`. Piggybacking secrets-file read access onto that group doesn't move today's human-access boundary (those operators can already read the file as its owner or via sudo) but it does mean *any future member added to `docker` for an unrelated reason* — e.g. a monitoring agent, a future CI runner for a different app — would silently also gain `.env` read on this specific app's secrets. That's a coupling this design shouldn't introduce when a purpose-built alternative (Option 3) costs one extra `groupadd`.

**Option 2 — `chown deploy:deploy .env`.** Rejected as primary. Functionally sufficient for T-0113 (deploy owns the file it needs to read), and does not touch the secret values (only owner/mode bits, as required). But it inverts today's convention without a compelling reason: `tvolodi` is the operator who actually ran T-0110/T-0111 and populated these `.env` files by hand, and per both hosts' landscape entries remains the accountable human for that content. Making `deploy` the owner means `tvolodi` would need to fall back to sudo (available, but an unnecessary regression in convenience) to inspect or hand-edit a file they created, for no functional gain over Option 3. It also means a future full rollback of T-0112 (`userdel -r deploy`) would leave `.env` owned by a deleted uid until someone notices and re-chowns it back — an extra manual cleanup step Option 3 doesn't require.

**Option 3 — new dedicated group, RECOMMENDED.** Create `aiqadam-qa-secrets` (QA) / `aiqadam-prod-secrets` (prod), add both `tvolodi` (existing owner, unaffected) and `deploy` (new) to it, `chgrp` each host's `deploy/.env` to the new group, `chmod 640`. Owner stays `tvolodi:tvolodi` — no ownership inversion, no rollback-orphaned-uid risk. Only `deploy` and `tvolodi` (and root, via sudo, on either option) can read the file; `viktor_d`/`binali_r` (QA) do not gain anything they don't already have via sudo, and nothing outside this one app's secrets is affected. This mirrors the project's own existing pattern of purpose-built groups gating a specific resource (`docker` for the Docker socket, `sshusers`/`deploybots` for SSH admission) rather than overloading an existing group for a new purpose. This is the only option of the three that (a) satisfies T-0113's real `docker compose build/up/pull` needs exactly the same way it satisfies this task's `ps` smoke test, (b) does not touch secret values, and (c) leaves the cleanest rollback story (delete the group, revert the `chgrp`/`chmod`, done — no orphaned ownership).

Group naming: `aiqadam-qa-secrets` / `aiqadam-prod-secrets` (system group, one per environment — matches the existing per-environment separation already used for keypairs, script paths, and Compose projects).

### Design decisions carried forward unchanged (not re-litigated per instructions)
1. **`deploybots` group** added as a second `AllowGroups` entry (`AllowGroups sshusers deploybots`) — unchanged.
2. **Forced-command via `authorized_keys`**, `no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty` — unchanged.
3. **No sudo; `docker` group membership instead** — unchanged. (Note: `docker` group membership remains necessary and unaffected by this revision — it is what lets `deploy` talk to the Docker daemon socket at all; the new secrets group is an *additional*, narrower grant solely for reading `.env`, not a replacement for `docker` group membership.)

### Plan

Run once per host (`<host>` = `pro-data-tech-qa` / `95.46.211.230` or `pro-data-tech-prod` / `95.46.211.224`; `<env>` = `qa` / `prod`; `<secrets-group>` = `aiqadam-qa-secrets` / `aiqadam-prod-secrets`). SSH as `tvolodi` per each host's landscape-documented operator path, using sudo for root-owned changes. **Both hosts are at clean baseline (confirmed by attempt 1's rollback) — run the full sequence below from Step 0, do not attempt to resume mid-sequence.**

Steps 0 through 10 are **unchanged** from the previously-approved plan (`runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/` — the version the user approved in step-05). Reproduced here by reference with their exact commands, since this file must be self-contained for the executor:

**Step 0 — Live pre-flight discovery (read-only, both hosts, run first, do not skip):**
```
ssh tvolodi@<host-ip> "id deploy 2>&1; getent group deploybots 2>&1; getent group docker; getent group <secrets-group> 2>&1; stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/; ls -la /opt/apps/aiqadam-<env>/deploy/ 2>&1; stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/.env; sshd -T | grep -i allowgroups; sudo cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```
Verification: `id deploy` returns "no such user" (both hosts should be clean per attempt-1's confirmed rollback — if `deploy` already exists, STOP, this contradicts the expected baseline, escalate rather than proceed); `getent group deploybots` and `getent group <secrets-group>` both return nothing (neither exists yet); `getent group docker` confirms gid 986; `stat` on `.env` confirms it is still `tvolodi:tvolodi 600` (the attempt-1-recorded state) — if it is NOT, something else has changed `.env` since attempt 1 and the executor must stop and escalate rather than assume this plan's `chgrp`/`chmod` commands are still safe to apply blindly.

**Step 1 — Back up the sshd drop-in (both hosts):**
```
ssh tvolodi@<host-ip> "sudo cp /etc/ssh/sshd_config.d/40-ai-dala-infra.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo ls -la /etc/ssh/sshd_config.d/"
```
Verification: backup file exists, same byte size as the original. Idempotent: yes (safe to re-run, creates an additional timestamped backup).

**Step 2 — Create the `deploybots` group (both hosts):**
```
ssh tvolodi@<host-ip> "getent group deploybots || sudo groupadd --system deploybots"
```
Verification: `getent group deploybots` returns a line. Idempotent: yes.

**Step 3 — Edit `AllowGroups` in the sshd drop-in (both hosts):**
```
ssh tvolodi@<host-ip> "sudo sed -i 's/^AllowGroups sshusers$/AllowGroups sshusers deploybots/' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```
Verification: `grep` shows exactly `AllowGroups sshusers deploybots`. Idempotent: yes (pattern only matches the pre-edit line).

**Step 4 — Validate sshd config syntax BEFORE reloading (both hosts, mandatory gate):**
```
ssh tvolodi@<host-ip> "sudo sshd -t && echo SSHD_CONFIG_OK"
```
Verification: output ends with `SSHD_CONFIG_OK`. **If this fails, STOP — restore from the Step 1 backup immediately.**

**Step 5 — Reload sshd (both hosts) — reload, not restart:**
```
ssh tvolodi@<host-ip> "sudo systemctl reload ssh.service && systemctl is-active ssh.service"
```
Verification: returns `active`; the SSH session used to run this remains connected.

**Step 6 — Mandatory Penpot no-regression check (prod host only, immediately after Step 5):**
```
ssh tvolodi@95.46.211.224 "docker ps --filter name=penpot- --format '{{.Names}}: {{.Status}}'" && curl -s -o /dev/null -w '%{http_code}\n' https://penpot.aiqadam.org
```
Verification: all 7 Penpot containers `Up`; external HTTPS probe returns `200`.

**Step 7 — Create the `deploy` system user (both hosts):**
```
ssh tvolodi@<host-ip> "id deploy 2>/dev/null || sudo useradd --system --create-home --home-dir /home/deploy --shell /usr/sbin/nologin --groups deploybots,docker deploy"
```
Verification: `id deploy` shows groups including `deploybots` and `docker`; shell `/usr/sbin/nologin`. Idempotent: yes.

**Step 8 — Create `.ssh` directory for `deploy` user (both hosts):**
```
ssh tvolodi@<host-ip> "sudo mkdir -p /home/deploy/.ssh && sudo chmod 700 /home/deploy/.ssh && sudo chown deploy:deploy /home/deploy/.ssh && sudo stat -c '%U:%G %a' /home/deploy/.ssh"
```
Verification: `sudo stat -c '%U:%G %a' /home/deploy/.ssh` returns `deploy:deploy 700`. **Use `sudo stat`, not plain `stat`** — attempt 1 hit a harmless self-inflicted failure here by running the verification `stat` without `sudo` against a 700 directory it (as `tvolodi`) cannot traverse; the underlying `mkdir`/`chmod`/`chown` succeed regardless. Idempotent: yes.

**Step 9 — Reuse the two ed25519 keypairs already generated on the management workstation. Do NOT regenerate.**
The keypairs from attempt 1 are confirmed present and unused:
- `C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci` (+`.pub`), fingerprint `SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg`
- `C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci` (+`.pub`), fingerprint `SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo`

Verification (re-confirm before use, do not regenerate): `ssh-keygen -lf "$env:USERPROFILE\.ssh\aiqadam-qa-deploy-ci.pub"` and same for prod — confirm the fingerprints above still match. If either file is missing or the fingerprint differs from the above, STOP and escalate (do not silently regenerate — a regenerated key invalidates the plan's assumption that these are unused-but-valid, and would need re-verification against nothing since neither was ever installed on a host, so regeneration is actually low-risk if genuinely needed, but confirm first rather than assume).

**Step 10 — Install each public key into the matching host's `deploy` user `authorized_keys`:**
Command (QA, via Bash tool — the plan's original PowerShell one-liner failed as a local parser error in attempt 1 due to nested-quote handling; use Bash/Git Bash for this step, not native PowerShell):
```
pub=$(cat "/c/Users/tvolo/.ssh/aiqadam-qa-deploy-ci.pub"); ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "echo 'command=\"/opt/apps/aiqadam-qa/deploy/deploy.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty $pub' | sudo tee /home/deploy/.ssh/authorized_keys && sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys && sudo chmod 600 /home/deploy/.ssh/authorized_keys"
```
Command (prod), same shape with `aiqadam-prod-deploy-ci.pub` and `/opt/apps/aiqadam-prod/deploy/deploy.sh`, target `tvolodi@95.46.211.224`.
Verification: `sudo cat /home/deploy/.ssh/authorized_keys` shows exactly one line with the correct `command=` path and matching key comment; `deploy:deploy 600`. Idempotent: `tee` (no `-a`) overwrites — safe to re-run with the same key.

**Step 11a — NEW: Grant `deploy` read access to `deploy/.env` via a dedicated per-environment secrets group (both hosts). Run this BEFORE Step 11's placeholder-script pre-check.**

Command (QA):
```
ssh tvolodi@95.46.211.230 "getent group aiqadam-qa-secrets || sudo groupadd --system aiqadam-qa-secrets; sudo usermod -aG aiqadam-qa-secrets tvolodi; sudo usermod -aG aiqadam-qa-secrets deploy; sudo chgrp aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env; sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env; sudo stat -c '%U:%G %a' /opt/apps/aiqadam-qa/deploy/.env; getent group aiqadam-qa-secrets"
```
Command (prod), same shape substituting `aiqadam-prod-secrets` / `/opt/apps/aiqadam-prod/deploy/.env`, target `tvolodi@95.46.211.224`.

Verification: `sudo stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/.env` returns `tvolodi:aiqadam-<env>-secrets 640` (owner unchanged, group changed, mode tightened from 600); `getent group aiqadam-<env>-secrets` shows both `tvolodi` and `deploy` as members. **No secret value is read, written, or regenerated by this step — only the file's group and mode bits change.** `sudo -u deploy test -r /opt/apps/aiqadam-<env>/deploy/.env && echo DEPLOY_CAN_READ` confirms the grant actually works from `deploy`'s perspective before proceeding to Step 11.

Idempotent: `getent group ... || groupadd` guards group creation; `usermod -aG` is safe to re-run (appends, does not duplicate); `chgrp`/`chmod` are safe to re-run (same target state each time).

**Caveat — group membership and existing SSH sessions:** `usermod -aG` updates `/etc/group` immediately, but a *already-logged-in* session's process only picks up new supplementary groups on its next login (new session), not retroactively. This does not affect this plan (the forced-command `deploy.sh` invocation via SSH in Step 13 is a fresh session each time, and `sudo -u deploy` in the pre-check below is also a fresh process), but is worth noting for any operator investigating "why doesn't my already-open shell see the new group" if `tvolodi` checks this manually later.

**Step 11 — Create the placeholder deploy script on each host (both hosts). Script content UNCHANGED from the previously-approved plan** — the fix belongs in Step 11a's permission grant, not in the script itself, since T-0113's real commands need the same `.env` access this placeholder's `docker compose ps` needs.

Command (QA):
```
ssh tvolodi@95.46.211.230 "sudo mkdir -p /opt/apps/aiqadam-qa/deploy && printf '#!/usr/bin/env bash\nset -euo pipefail\necho \"[deploy.sh placeholder] invoked \$(date -u +%%FT%%TZ) as \$(whoami) -- T-0113 will replace this with the real CI/CD deploy logic.\"\ncd /opt/apps/aiqadam-qa/deploy\ndocker compose -f docker-compose.qa.yml ps\n' | sudo tee /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chown deploy:deploy /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chmod 750 /opt/apps/aiqadam-qa/deploy/deploy.sh"
```
Command (prod), same shape substituting `aiqadam-prod` / `docker-compose.prod.yml`, target `tvolodi@95.46.211.224`.

**Note for the executor:** if the plan's inline `printf`-based one-liner again causes quoting problems across PowerShell/Bash layers, the attempt-1 mitigation (write the identical script body to a local scratch file, `scp` to `/tmp/deploy-<env>.sh`, then `sudo mv` + `chown` + `chmod` into place) is pre-approved as a mechanical substitution — it changes nothing about the approved script content, ownership, or mode, only the transport mechanism, and was already used successfully in attempt 1 without any issue being raised.

Verification: `stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh` returns `deploy:deploy 750`; **mandatory pre-check** — `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh` (run by the executor directly, NOT via the CI key) must now print the marker line AND a `docker compose ps` table with exit code 0 — this is the check that failed in attempt 1 and must pass now that Step 11a has run. **If this still fails, STOP — do not proceed to Step 12/13, and do not attempt a second, different permission fix without a new design/approval cycle.**

Idempotent: `tee`/`mv` overwrites; safe to re-run with identical content. Guard against clobbering a T-0113-authored real script: `test -f .../deploy.sh` check before overwrite, as in the original plan.

**Step 12 — Capture host SSH public keys for GitHub Actions `known_hosts` pinning (unchanged):**
```
ssh-keyscan -t ed25519 95.46.211.230 > "$env:TEMP\qa-host-key.pub"
ssh-keyscan -t ed25519 95.46.211.224 > "$env:TEMP\prod-host-key.pub"
Get-Content "$env:TEMP\qa-host-key.pub"
Get-Content "$env:TEMP\prod-host-key.pub"
```
Verification: each output is one line, `<ip> ssh-ed25519 AAAA...`; cross-check fingerprint against the workstation's existing `known_hosts` entry for that host.

**Step 13 — Live SSH end-to-end test of each new deploy key (both environments — satisfies acceptance criterion 6):**
Command (QA):
```
ssh -i "$env:USERPROFILE\.ssh\aiqadam-qa-deploy-ci" -o IdentitiesOnly=yes deploy@95.46.211.230
```
Command (prod), same shape with `aiqadam-prod-deploy-ci` and `95.46.211.224`.

Verification: session connects, forced-command fires (no shell prompt), output shows the marker line and a `docker compose ps` table listing that host's containers, connection closes cleanly (exit 0). This now must succeed end-to-end including the `.env` read, proving the full chain works for a real CI invocation, not just for the executor's local pre-check as `sudo -u deploy`.

### Rollback

1. **`.env` group/mode grant (Step 11a) — both hosts:**
   ```
   ssh tvolodi@<host-ip> "sudo chmod 600 /opt/apps/aiqadam-<env>/deploy/.env && sudo chgrp tvolodi /opt/apps/aiqadam-<env>/deploy/.env && sudo stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/.env"
   ```
   Restores `.env` to `tvolodi:tvolodi 600` (its confirmed pre-change state, re-verified in Step 0). Then remove the group: `ssh tvolodi@<host-ip> "sudo groupdel aiqadam-<env>-secrets"` (only after the `chgrp` above has moved `.env` off this group — a group referenced by a file's gid can still be deleted, but the file would then show a numeric gid instead of a name until reused, so do the `chgrp` first for cleanliness). No secret value is touched by this rollback, matching the forward step.
2. **sshd `AllowGroups` edit (Step 3) — both hosts:** unchanged from the original plan — restore from the Step 1 backup, `sshd -t`, `systemctl reload ssh.service`.
3. **`deploybots` group (Step 2):** `sudo groupdel deploybots` — after Step 2's rollback (AllowGroups reverted).
4. **`deploy` user (Steps 7–11):** `sudo userdel -r deploy` — removes `/home/deploy` including `authorized_keys`. Note: since `deploy` was added to `aiqadam-<env>-secrets` in Step 11a, `userdel -r deploy` does not require the secrets-group rollback to happen first or after — `userdel` only affects the user's own account/home, not group definitions or other files' ownership. The placeholder `deploy.sh` at `/opt/apps/aiqadam-<env>/deploy/deploy.sh` survives `userdel -r` (not under `/home/deploy`); follow with `sudo rm -f /opt/apps/aiqadam-<env>/deploy/deploy.sh` for full rollback.
5. **Local keypairs (Step 9):** unchanged from the original plan — no host-side rollback needed if not yet installed; if installed and rollback is required, delete the local key files only after confirming no pending GitHub secret paste depends on them.
6. **GitHub Actions secrets:** out of scope, as before — not reached by this plan.

### Verification (for step 07)

- **On-host (both hosts):**
  - `getent group deploybots` returns a line; `id deploy` shows groups including `deploybots`, `docker`, and `aiqadam-<env>-secrets`; `getent passwd deploy` shows shell `/usr/sbin/nologin`.
  - `sudo grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` shows `AllowGroups sshusers deploybots`.
  - `sudo sshd -t` exits 0; `systemctl is-active ssh.service` returns `active`.
  - `sudo cat /home/deploy/.ssh/authorized_keys` shows exactly one line with the correct `command=` path and matching key comment; file is `deploy:deploy 600`.
  - `stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh` returns `deploy:deploy 750`.
  - **NEW:** `sudo stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/.env` returns `tvolodi:aiqadam-<env>-secrets 640`; `getent group aiqadam-<env>-secrets` shows exactly `tvolodi,deploy` as members (no other users added); the secret file's **content is unchanged** — `sudo diff <(sudo cat /opt/apps/aiqadam-<env>/deploy/.env) <backup-or-known-checksum>` is not directly available without a pre-image, so verification instead confirms via **byte count and mtime unchanged from Step 0's discovery** (`stat -c '%s %Y'` before/after Step 11a must match, proving only metadata — not content — changed).
  - `sudo -u deploy test -r /opt/apps/aiqadam-<env>/deploy/.env && echo DEPLOY_CAN_READ` succeeds.
  - `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh` exits 0 and prints a `docker compose ps` table (this is the check that failed in attempt 1).
  - No `/etc/sudoers.d/90-deploy` file exists on either host — confirms no sudo grant was made.
  - Backup file `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.<timestamp>.bak` exists on both hosts.
- **Prod-specific no-regression:** all 7 Penpot containers `Up`; `https://penpot.aiqadam.org` returns `200`; `https://aiqadam.org/health` returns `200`.
- **External (both hosts):**
  - `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip>` connects, forced-command fires, `docker compose ps` output appears (now succeeding past the `.env` read), session closes cleanly (exit 0).
  - Attempt `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip> "whoami; cat /etc/shadow"` (forbidden arbitrary command) and confirm it is REJECTED / forced-command still runs instead.
  - `ssh-keyscan -t ed25519 <host-ip>` output matches the fingerprint already in the workstation's `known_hosts`.

### Resources used
- Secrets (by name): `aiqadam-qa-deploy-ssh-key`, `aiqadam-prod-deploy-ssh-key` (new, private key values never enter this repo). Existing secrets `aiqadam-qa-jwt-signing-secret`, `aiqadam-qa-internal-api-token`, `aiqadam-prod-jwt-signing-secret`, `aiqadam-prod-internal-api-token`, `aiqadam-prod-postgres-password` are **referenced by name only, never read or modified** — Step 11a changes only the containing file's group/mode, not any value inside it. (Note: the task instructions mention `DATABASE_URL` and a QA Postgres password as also present in these `.env` files — `aiqadam-qa-jwt-signing-secret` and `aiqadam-qa-internal-api-token` are the only two QA secrets currently named in `landscape/secrets-inventory.md`; if QA's `.env` also contains a Postgres password or constructed `DATABASE_URL` not yet named there, that is a pre-existing landscape gap, not something this plan introduces or needs to resolve — it does not touch any secret value either way.)
- Files modified on host:
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (both hosts — `AllowGroups` line edited)
  - `/home/deploy/.ssh/authorized_keys` (both hosts — new file)
  - `/opt/apps/aiqadam-qa/deploy/deploy.sh` (QA — new file)
  - `/opt/apps/aiqadam-prod/deploy/deploy.sh` (prod — new file)
  - **NEW:** `/opt/apps/aiqadam-qa/deploy/.env` (QA — group and mode changed only, `tvolodi:tvolodi 600` → `tvolodi:aiqadam-qa-secrets 640`; content untouched)
  - **NEW:** `/opt/apps/aiqadam-prod/deploy/.env` (prod — group and mode changed only, `tvolodi:tvolodi 600` → `tvolodi:aiqadam-prod-secrets 640`; content untouched)
- Files modified in this repo (landscape/), to be applied at step 08:
  - [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) — new `deploy` user, `deploybots` group, `AllowGroups` update, placeholder script path, **new `aiqadam-qa-secrets` group and `.env` group/mode change**.
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) — same, plus explicit note that Penpot was confirmed unregressed, **plus `aiqadam-prod-secrets` group and `.env` group/mode change**.
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) — add `aiqadam-qa-deploy-ssh-key` and `aiqadam-prod-deploy-ssh-key` rows (names + storage location only).
- External APIs called: none. Manual step required of the user after execution: paste `QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY` into GitHub Actions repository secrets in `aiqadam/ai-qadam-platform` — unchanged from the original plan, still a hard stop for this repo's own tooling.

### Estimated impact
- Downtime: none expected. sshd `reload` (not `restart`) preserves sessions. The new `.env` permission change (`chgrp`/`chmod`) does not restart or touch any running container — Compose only re-reads `.env` when a command is next invoked, and no running process holds `.env` open in a way a mode/group change would disrupt.
- Affected services: `ssh.service` (config reload, both hosts). No application service is restarted. Penpot and the AiQadam QA/prod app stacks are explicitly verified unaffected.
- Reversibility: fully reversible. `.env`'s group/mode reverts to its exact pre-change state (`tvolodi:tvolodi 600`, confirmed via Step 0's live re-discovery before this run and available from attempt 1's own recorded discovery output); the new secrets group is deletable; sshd drop-in restored from backup; `deploy` user and `deploybots` group removed via `userdel -r`/`groupdel`. The one exception, as before, is anything already pasted into GitHub Actions secrets by the time a rollback is requested.

## Issues / risks
- **sshd drop-in edit on two hosts, one running a live Penpot workload — HIGH severity by policy, not by actual risk profile.** Unchanged from the prior version: additive, narrow (`AllowGroups sshusers` → `AllowGroups sshusers deploybots`), validated with `sshd -t` before `reload` (not `restart`), with an explicit Penpot no-regression check. Per this workflow's approval rules, any sshd/OS-level config change on a host carrying a live prod workload requires human sign-off regardless of how contained the blast radius looks on paper.
- **NEW: `.env` permission change on both hosts, one with live prod secrets already in use by running containers (JWT_SIGNING_SECRET, INTERNAL_API_TOKEN, DATABASE_URL/POSTGRES_PASSWORD on prod).** The change is metadata-only (group + mode bits) and does not touch, read, log, or transmit any secret value — but it is nonetheless a permission change to a file holding live production credentials, on a host that also runs Penpot. This alone would independently justify `NEEDS_APPROVAL` even if the sshd change did not. `chmod 640` narrows "other" access from none-anyway (600 had no other-read either) to still-none (640 has no other-read) — the only change in practice is that `aiqadam-<env>-secrets` group members (`tvolodi`, `deploy`) can now read it via group bit instead of only via owner bit or sudo. No broadening of access beyond `deploy` (the intended new reader) occurs.
- **New user creation + SSH key generation/installation on two hosts** — per `shared/approval-protocol.md`, OS-level/access-control changes always require `NEEDS_APPROVAL`, independent of the task frontmatter's blast-radius/reversibility ratings (`medium`/`full`).
- **Placeholder `deploy.sh` remains intentionally non-mutating** (runs only `docker compose ps`) — unchanged; T-0113 supplies the real mutating deploy logic.
- **Idempotency of the retry itself:** since Steps 0–10 were already run and fully rolled back once, re-running them from scratch is expected to behave identically to a first run (all guarded by `id deploy 2>/dev/null ||` / `getent group ... ||` patterns) — Step 0 in this revision adds an explicit check that `.env`'s mode is still `600` before proceeding, specifically to catch the case where something changed between attempt 1's rollback and this retry's execution.
- **Blast radius remains bounded** to the `deploy` user, `deploybots` group, the two new `deploy.sh` files, and now also the two new `aiqadam-<env>-secrets` groups and the group/mode bits (not content) of the two `.env` files. No existing operator account, sudoers drop-in, Docker container, nginx vhost, TLS cert, Cloudflare record, or secret **value** is touched.

## Open questions
none — the option analysis above resolves the one new design decision (Option 3, dedicated per-environment secrets group) with a recommendation for the user's APPROVE/REJECT/MODIFY response. The three previously-approved decisions are unchanged and not reopened.
