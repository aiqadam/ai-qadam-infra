---
run_id: 2026-07-14-ssh-deploy-keys-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-17T07:00:00Z
task_id: T-0112-github-actions-ssh-deploy-keys-aiqadam
retry_of: step-04
inputs_read:
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-03-task-validator.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-04-solution-designer-attempt-2.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/step-05-user-approval.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-1.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-2.md
  - runs/2026-07-14-ssh-deploy-keys-aiqadam-001/.attempts/step-06-executor-infra-attempt-3.md
  - tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/secrets-inventory.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - workflows/infrastructure.md
artifacts_changed: []
next_step_hint: This is a narrow, targeted revision (third design pass) — only Step 7's shell choice changed, plus a one-line host-independence fix to Step 11's placeholder script. Steps 0-6, 8-10, 11a, 12 are byte-for-byte unchanged from the twice-executed, twice-proven plan. Present to the user as a fresh, small approval request — the diff versus the already-approved plan is exactly: (a) Step 7 shell /usr/sbin/nologin -> /bin/bash with updated verification/rollback text, (b) Step 11 deploy.sh gains an explicit -p aiqadam-<env> flag on its docker compose ps line, (c) Step 13's expected outcome text updated to explain why it will now succeed. No other line changed. Executor-infra should run the full sequence from Step 0 again (both hosts confirmed at clean baseline after attempt 3's rollback).
---

## Summary
Revised plan (Steps 0–6, 8–10, 11a, 12 unchanged from the twice-executed design; only Step 7's `deploy` user shell and one line of Step 11's placeholder script change) fixes the Step 13 failure by changing the `deploy` system user's login shell from `/usr/sbin/nologin` to `/bin/bash`, since this host's sshd/PAM build refuses to run an `authorized_keys` forced command at all for a nologin-shell account — while `authorized_keys`' own `command=`,`no-pty`,`no-port-forwarding`,`no-X11-forwarding`,`no-agent-forwarding` restrictions (unchanged, already proven to parse and apply correctly by attempt 3's own verbose SSH log) remain the sole and sufficient lockdown mechanism, exactly as the task's own Notes always intended.

## Details

### Root cause recap (from attempt 3, not re-litigated — already conclusively diagnosed by the executor)
Verbose SSH diagnostics on both hosts showed: publickey auth succeeded; sshd correctly parsed and logged the `command=` key option from `authorized_keys` (`Remote: /home/deploy/.ssh/authorized_keys:1: key options: command user-rc`); the session was entered; then `/usr/sbin/nologin` printed its own hardcoded refusal ("This account is currently not available.") and exited 1 — before the forced command executed. This is a property of `nologin` itself, not of `authorized_keys`' `command=` mechanism or of anything in Step 11a's `.env`-permission grant (which is proven correct — its own functional check passed on both hosts in attempt 3, using the identical `deploy.sh` invocation path). No `.env` content was read at any point during this diagnosis; no secret-exposure risk exists in this revision's scope.

### Shell-choice investigation (this revision's task)

**How OpenSSH actually invokes a forced command.** Per `sshd_config(5)` (`ForceCommand`) and `sshd(8)` (AUTHORIZED_KEYS FILE FORMAT, `command=` option): regardless of whether the forced command comes from `authorized_keys`' `command=` or from an `sshd_config`-level `ForceCommand`/`Match` block, sshd does not exec the command directly — it invokes the user's configured login shell with `-c <command>` (i.e., `<shell> -c "<command>"`). The shell is therefore not a bypassable implementation detail; it is the mechanism the forced command runs through, for both mechanisms alike.

**Option 2 (sshd-level `Match User deploy` + `ForceCommand`) — considered and rejected.** Because both `authorized_keys`' `command=` and `sshd_config`'s `ForceCommand` route through the identical `<shell> -c <command>` invocation, moving the forced-command declaration from `authorized_keys` to a `Match User deploy` block in `sshd_config` does not change which program is asked to interpret `-c <command>` — it is still the account's login shell. `/usr/sbin/nologin` is not a shell that supports `-c`; it is a fixed program that prints a refusal message and calls `exit(1)` unconditionally, ignoring any arguments passed to it (this is nologin's documented, entire purpose — see `nologin(8)`: "nologin displays a message that an account is not available and exits non-zero. It is intended as a replacement shell field for accounts that have been disabled."). Attempt 3's own log is direct evidence of this: sshd successfully parsed and reached the point of invoking the command, and nologin still blocked it. There is no sshd-side directive that changes what `nologin` does once invoked — `Match`/`ForceCommand` only change **where** the forced-command string is declared, not **what program executes it**. Testing this live would not be expected to produce a different outcome and would add config surface (a second, `sshd_config`-level forced-command declaration, on top of the existing `authorized_keys`-level one, now two places defining the same restriction that must be kept in sync) without a credible mechanism for success. Rejected — not carried into the plan.

**Option 1 (real shell + authorized_keys-only lockdown) — selected.** Changing `--shell` to `/bin/bash` gives sshd a shell capable of executing `-c <command>`. Security is unaffected by this change for the following reasons, all specific to this account:
- `command=` in `authorized_keys` is documented to unconditionally override any command the SSH client requests — "Note that this option applies to shell, command or subsystem execution" and the client-requested command, if any, is ignored entirely (`sshd(8)`). Attempt 3's own negative-control test already exercised this exact property (`ssh ... deploy@<host> "whoami; cat /etc/shadow"`) and confirmed the injected command never ran — it hit nologin's refusal same as the plain login attempt, which is consistent with (not contrary to) `command=`'s override behavior; with a real shell in place, the same negative control will now prove the override positively (forced command runs; injected command does not), which is a **stronger** demonstration than attempt 3 could produce.
- `no-pty` prevents allocation of any pseudo-terminal for this key, which is what would be required for an interactive shell session — so even a client that omits `-o RequestTTY=no` and requests a PTY gets refused a TTY, leaving no path to an interactive `bash` prompt regardless of the shell field.
- `no-port-forwarding`, `no-X11-forwarding`, `no-agent-forwarding` (unchanged) close the other channel types a real shell's SSH session could otherwise expose.
- The account has no password (`useradd --system` with no `passwd` call — password-locked by default), is not in the `sudo` group, has no sudoers drop-in, and is authenticated by exactly one dedicated CI key per host (not the operator `ai-dala-infra` key). A real login shell does not grant this account any new privilege — it only allows the one command that `authorized_keys` already unconditionally forces to actually run.
- This is, in fact, the pattern the task file's own Notes section describes: *"Recommend a forced-command approach... for defense-in-depth — if the CI key leaks, it can only run the deploy script, not arbitrary commands."* The defense-in-depth layer was always meant to be `command=`, not the shell field. `nologin` was an additional, reflexively-applied "system account" hardening choice layered on top — one that turns out to be redundant with, and actively incompatible with, the mechanism that was supposed to do the actual restricting.

**Conclusion:** change Step 7's `--shell /usr/sbin/nologin` to `--shell /bin/bash`. No other Step 7 flag changes (still `--system --create-home --home-dir /home/deploy --groups deploybots,docker deploy`). No change to Step 10 (authorized_keys content, `command=` string, `no-pty` etc. — already correct and unchanged). No change to Step 11a (secrets-group `.env` grant — proven correct twice, untouched).

### Steps 8–10, 12 — confirmed no change needed
- **Step 8** (`.ssh` directory creation) does not reference the shell in any way — unchanged.
- **Step 9** (reuse existing keypairs) — unaffected, unchanged.
- **Step 10** (install `authorized_keys`) — the `command=`,`no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty` string is unchanged; this restriction was already proven to parse and apply correctly by attempt 3's verbose log (`key options: command user-rc` — sshd read it correctly). No change needed.
- **Step 12** (capture host keys via `ssh-keyscan`) — local, read-only, unaffected by any host-side change in this run. Unchanged.

### Step 11 — one-line host-independence fix (in addition to the shell fix)
Attempt 3 found that on prod, `docker compose -f docker-compose.prod.yml ps` (no project flag) printed a header row but zero data rows despite all 3 containers confirmed `Up (healthy)` via `docker ps --filter` and `docker inspect` label cross-check — while the identical invocation worked correctly on QA. The executor correctly declined to investigate by reading `.env` (forbidden). Reasoning about scope:

- This is very likely a `COMPOSE_PROJECT_NAME`-resolution difference: Compose derives the default project name from either an explicit flag/env var or the last path component of the working directory (or `.env`'s own `COMPOSE_PROJECT_NAME` if set) — and the landscape confirms both hosts' Compose projects are already named explicitly (`aiqadam-qa` / `aiqadam-prod`) via `docker-compose.qa.yml`'s / `docker-compose.prod.yml`'s own `name:` field or prior explicit `-p` usage at deploy time (T-0110/T-0111). A bare `docker compose -f <file> ps` with no `-p`/`--project-name` and no `COMPOSE_PROJECT_NAME` exported in the *shell* (as opposed to inside `.env`, which Compose reads for container **variable interpolation**, not automatically as its own project-name source unless `COMPOSE_PROJECT_NAME` is itself a key in it) resolves the project name from the directory basename by default — `/opt/apps/aiqadam-prod/deploy` → default project name would be `deploy` on both hosts, not `aiqadam-prod`, unless something host-specific overrides it. Since this reads identically on paper for both hosts but behaves differently, the most likely explanation remains a difference in `COMPOSE_PROJECT_NAME` presence inside prod's `.env` versus QA's — consistent with the executor's own hypothesis — but this remains unconfirmed without reading `.env`, which is out of bounds.
- **Decision: fix it now, in this plan, with an explicit flag — not deferred to T-0113.** This is a one-line, zero-risk change to a file this very plan already creates from scratch on both hosts (Step 11), it removes host-dependent ambiguity from a script whose entire purpose is to be an unambiguous verification/deploy vehicle, and it costs nothing to add now versus filing a follow-up for T-0113 to discover independently. Leaving a known-flaky verification command in place when the fix is a single explicit flag would be a needless rough edge in a script this plan is already authoring. This is a content change to `deploy.sh`, not a new host mutation category — same file, same ownership, same mode, same idempotency profile as before.
- **Fix:** add `-p aiqadam-<env>` explicitly to the `docker compose` invocation inside `deploy.sh`, making project-name resolution explicit and host-independent regardless of what `COMPOSE_PROJECT_NAME` may or may not be set to in either host's `.env` or shell environment. `-p`/`--project-name` is documented to take precedence over every other project-name source in Compose's resolution order, so this removes the ambiguity outright rather than working around a guessed cause.

### Design decisions carried forward unchanged (not re-litigated — proven correct by two consecutive successful executions of Steps 0–11a)
1. **`deploybots` group** as a second `AllowGroups` entry (`AllowGroups sshusers deploybots`).
2. **Forced-command via `authorized_keys`**, `no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`.
3. **No sudo; `docker` group membership instead.**
4. **Option 3 (dedicated per-environment secrets group `aiqadam-<env>-secrets`)** for `.env` read access, verified via the functional `deploy.sh` check (not `test -r`).
5. **Credential rotation: explicitly NOT part of this plan.** Unchanged from the prior revision — the user's out-of-band decision not to rotate the QA Postgres password exposed in attempt 2 remains final and is not reopened here.
6. **The `.env`-content-reading prohibition** (no `cat`/`head`/`tail`/`grep` content-mode/`less`/`more`/`od`/`xxd`/etc. against any `.env` file, anywhere, under any circumstance) remains in force for this and all future attempts on this run.

### Plan

Run once per host (`<host>` = `pro-data-tech-qa` / `95.46.211.230` or `pro-data-tech-prod` / `95.46.211.224`; `<env>` = `qa` / `prod`; `<secrets-group>` = `aiqadam-qa-secrets` / `aiqadam-prod-secrets`). SSH as `tvolodi` per each host's landscape-documented operator path, using sudo for root-owned changes. **Both hosts are confirmed at clean baseline (no `deploy` user, no `deploybots` group, no `aiqadam-<env>-secrets` group, `.env` at `tvolodi:tvolodi` mode 600 on both hosts, per attempt 3's own rollback verification) — run the full sequence below from Step 0. Do not attempt to resume mid-sequence.**

**Step 0 — Live pre-flight discovery (read-only, both hosts, run first, do not skip):**
```
ssh tvolodi@<host-ip> "id deploy 2>&1; getent group deploybots 2>&1; getent group docker; getent group <secrets-group> 2>&1; stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/; ls -la /opt/apps/aiqadam-<env>/deploy/ 2>&1; stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-<env>/deploy/.env; sshd -T | grep -i allowgroups; sudo cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```
Verification: `id deploy` returns "no such user"; `getent group deploybots` and `getent group <secrets-group>` both return nothing; `getent group docker` confirms gid 986; `stat` on `.env` confirms `tvolodi:tvolodi 600` — expected sizes: QA 597 bytes/mtime 1783926015, prod 700 bytes/mtime 1783959940 (both recorded and reconfirmed unchanged across attempts 2 and 3's rollbacks). **If `.env`'s owner, mode, or size differs from these recorded values, STOP and escalate — do not proceed on an assumption that this plan's commands are still safe to apply.** This command does not read file content — `stat`/`ls -la` report metadata only.

**Step 1 — Back up the sshd drop-in (both hosts):**
```
ssh tvolodi@<host-ip> "sudo cp /etc/ssh/sshd_config.d/40-ai-dala-infra.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo ls -la /etc/ssh/sshd_config.d/"
```
Verification: backup file exists, same byte size as the original (QA 1335 B, prod 516 B). Idempotent: yes (safe to re-run, creates an additional timestamped backup; prior attempts' backups remain, expected and correct per project convention).

**Step 2 — Create the `deploybots` group (both hosts):**
```
ssh tvolodi@<host-ip> "getent group deploybots || sudo groupadd --system deploybots; getent group deploybots"
```
Verification: `getent group deploybots` returns a line (expect gid 982, matching all prior attempts). Idempotent: yes.

**Step 3 — Edit `AllowGroups` in the sshd drop-in (both hosts):**
```
ssh tvolodi@<host-ip> "sudo sed -i 's/^AllowGroups sshusers$/AllowGroups sshusers deploybots/' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf && grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"
```
Verification: `grep` shows exactly `AllowGroups sshusers deploybots`. Idempotent: yes (pattern only matches the pre-edit line; a second run is a safe no-op).

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
Verification: all 7 Penpot containers `Up`; external HTTPS probe returns `200`. **If this fails, STOP and restore the sshd drop-in from Step 1's backup immediately** (all three prior attempts confirmed this reload path is safe, but the check must still gate forward progress).

**Step 7 — Create the `deploy` system user (both hosts). CHANGED THIS REVISION: `--shell /bin/bash` replaces `--shell /usr/sbin/nologin`.**
```
ssh tvolodi@<host-ip> "id deploy 2>/dev/null || sudo useradd --system --create-home --home-dir /home/deploy --shell /bin/bash --groups deploybots,docker deploy; id deploy; getent passwd deploy"
```
Verification: `id deploy` shows groups including `deploybots` and `docker`; shell `/bin/bash` (uid/gid expected to match prior attempts — uid 999, gid 981 — since this is a fresh `useradd` on a clean-baseline host and system-uid allocation is otherwise identical). Idempotent: yes.

**Why this is safe (see full investigation above):** the account remains password-locked (no `passwd` call, `useradd --system` default), has no sudo grant (no `/etc/sudoers.d/90-deploy` file, confirmed absent by Step 0 and by the plan's own verification section below), and is reachable only via the one dedicated CI key per host. `authorized_keys`' `command=`,`no-pty`,`no-port-forwarding`,`no-X11-forwarding`,`no-agent-forwarding` (Step 10, unchanged) remain the sole and sufficient restriction — `no-pty` specifically blocks any interactive use of the now-real shell, and `command=` unconditionally overrides any client-requested command, so a real shell does not create a path to interactive access. This mirrors the task file's own stated intent (forced-command as the defense-in-depth layer, not the shell field) and is the standard, widely-documented pattern for CI/CD forced-command deploy accounts.

**Step 8 — Create `.ssh` directory for `deploy` user (both hosts). Unchanged.**
```
ssh tvolodi@<host-ip> "sudo mkdir -p /home/deploy/.ssh && sudo chmod 700 /home/deploy/.ssh && sudo chown deploy:deploy /home/deploy/.ssh && sudo stat -c '%U:%G %a' /home/deploy/.ssh"
```
Verification: returns `deploy:deploy 700`. **Use `sudo stat`, not plain `stat`** (a non-sudo `stat` against a 700 directory owned by `deploy` fails with permission denied even though correctly configured — already-diagnosed, harmless). Idempotent: yes.

**Step 9 — Reuse the two ed25519 keypairs already generated on the management workstation. Do NOT regenerate. Unchanged.**
- `C:\Users\tvolo\.ssh\aiqadam-qa-deploy-ci` (+`.pub`), fingerprint `SHA256:SLM2PY1Enq+oZ4nepJ5l499sPC9ulG1wc7Wi0ibUkZg`
- `C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci` (+`.pub`), fingerprint `SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo`

Verification (re-confirm before use, do not regenerate): `ssh-keygen -lf "$env:USERPROFILE\.ssh\aiqadam-qa-deploy-ci.pub"` and same for prod — confirm the fingerprints above still match (confirmed unchanged across all three prior attempts). If either file is missing or the fingerprint differs, STOP and escalate before regenerating.

**Step 10 — Install each public key into the matching host's `deploy` user `authorized_keys`. Unchanged.**
Use the Bash tool (Git Bash), not native PowerShell — the plan's forced-command string contains nested double-quotes that PowerShell 5.1's parser cannot handle directly (confirmed failure mode in attempt 1, worked around successfully in attempts 2 and 3 via Bash).

Command (QA):
```
pub=$(cat "/c/Users/tvolo/.ssh/aiqadam-qa-deploy-ci.pub"); ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.230 "echo 'command=\"/opt/apps/aiqadam-qa/deploy/deploy.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty $pub' | sudo tee /home/deploy/.ssh/authorized_keys && sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys && sudo chmod 600 /home/deploy/.ssh/authorized_keys"
```
Command (prod), same shape with `aiqadam-prod-deploy-ci.pub` and `/opt/apps/aiqadam-prod/deploy/deploy.sh`, target `tvolodi@95.46.211.224`.

Verification: `sudo cat /home/deploy/.ssh/authorized_keys` shows exactly one line with the correct `command=` path and matching key comment; `deploy:deploy 600`. (This `cat` targets `authorized_keys`, a non-secret SSH config file — not a `.env` file; safe to read per the plan's own scoping, as in all prior attempts.) Idempotent: `tee` (no `-a`) overwrites — safe to re-run with the same key.

**Step 11 — Create the placeholder deploy script on each host (both hosts). CHANGED THIS REVISION: `docker compose ps` invocation now takes an explicit `-p aiqadam-<env>` project-name flag to remove host-dependent project-name-resolution ambiguity (see Details section above). No other content change.**

Command (QA):
```
ssh tvolodi@95.46.211.230 "sudo mkdir -p /opt/apps/aiqadam-qa/deploy && printf '#!/usr/bin/env bash\nset -euo pipefail\necho \"[deploy.sh placeholder] invoked \$(date -u +%%FT%%TZ) as \$(whoami) -- T-0113 will replace this with the real CI/CD deploy logic.\"\ncd /opt/apps/aiqadam-qa/deploy\ndocker compose -p aiqadam-qa -f docker-compose.qa.yml ps\n' | sudo tee /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chown deploy:deploy /opt/apps/aiqadam-qa/deploy/deploy.sh && sudo chmod 750 /opt/apps/aiqadam-qa/deploy/deploy.sh"
```
Command (prod), same shape substituting `aiqadam-prod` / `docker-compose.prod.yml` / `-p aiqadam-prod`, target `tvolodi@95.46.211.224`.

**Note for the executor:** if the plan's inline `printf`-based one-liner causes quoting problems across PowerShell/Bash layers (as it did in attempt 1), the pre-approved mitigation is to write the identical script body to a local scratch file, `scp` it to `/tmp/deploy-<env>.sh`, then `sudo mv` + `chown` + `chmod` into place — a transport-mechanism substitution only, not a content change. This was used successfully in attempts 2 and 3.

Verification (idempotency pre-check first): `test -f /opt/apps/aiqadam-<env>/deploy/deploy.sh && echo EXISTS || echo NOT_EXISTS` before writing, to guard against clobbering a possible future T-0113-authored real script. Then: `stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh` returns `deploy:deploy 750`.

**Step 11a — Grant `deploy` read access to `deploy/.env` via a dedicated per-environment secrets group (both hosts). Unchanged — forward commands and verification method both proven correct by attempt 3.**

Command (QA):
```
ssh tvolodi@95.46.211.230 "getent group aiqadam-qa-secrets || sudo groupadd --system aiqadam-qa-secrets; sudo usermod -aG aiqadam-qa-secrets tvolodi; sudo usermod -aG aiqadam-qa-secrets deploy; sudo chgrp aiqadam-qa-secrets /opt/apps/aiqadam-qa/deploy/.env; sudo chmod 640 /opt/apps/aiqadam-qa/deploy/.env; sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-qa/deploy/.env; getent group aiqadam-qa-secrets"
```
Command (prod), same shape substituting `aiqadam-prod-secrets` / `/opt/apps/aiqadam-prod/deploy/.env`, target `tvolodi@95.46.211.224`.

**Verification (unchanged from the second design revision — proven reliable in attempt 3):**
1. **Metadata check (secondary, corroborating only):** `sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-<env>/deploy/.env` returns `tvolodi aiqadam-<env>-secrets 640 <size> <mtime>` with size/mtime numerically equal to Step 0's recorded values. `getent group aiqadam-<env>-secrets` shows exactly `tvolodi,deploy`. `sudo -u deploy id` shows `aiqadam-<env>-secrets` in `deploy`'s group list. None of these commands read or print file content.
2. **Functional check (PRIMARY, authoritative pass/fail gate):** `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh`. Expected: exit 0, marker line, then a `docker compose ps` table (now with the explicit `-p aiqadam-<env>` flag from Step 11, so both hosts are expected to show their container rows, resolving attempt 3's prod cosmetic gap as a side effect). This exercises the real `open()` path Compose uses.

**If the functional check (2) fails:** STOP. Do not attempt any further diagnostic beyond re-running check 1's metadata commands. **Under no circumstances run `cat`, `head`, `grep` (content mode), or any other command that could print `.env` content, even a single line.** Escalate to a fresh solution-designer pass rather than improvising.

Idempotent: `getent group ... || groupadd` guards group creation; `usermod -aG` is safe to re-run; `chgrp`/`chmod` are safe to re-run.

**Caveat — group membership and existing SSH sessions:** `usermod -aG` updates `/etc/group` immediately; an already-logged-in session's process only picks up new supplementary groups on its next login. Not relevant here — every check spawns a fresh process.

**Step 12 — Capture host SSH public keys for GitHub Actions `known_hosts` pinning. Unchanged.**
```
ssh-keyscan -t ed25519 95.46.211.230 > "$env:TEMP\qa-host-key.pub"
ssh-keyscan -t ed25519 95.46.211.224 > "$env:TEMP\prod-host-key.pub"
Get-Content "$env:TEMP\qa-host-key.pub"
Get-Content "$env:TEMP\prod-host-key.pub"
```
Verification: each output is one line, `<ip> ssh-ed25519 AAAA...`; cross-check fingerprint against the workstation's existing `known_hosts` entry for that host.

**Step 13 — Live SSH end-to-end test of each new deploy key (both environments — satisfies acceptance criterion 6). Commands unchanged; expected outcome now changes from FAIL to PASS because of the Step 7 shell fix.**

Command (QA):
```
ssh -i "$env:USERPROFILE\.ssh\aiqadam-qa-deploy-ci" -o IdentitiesOnly=yes deploy@95.46.211.230
```
Command (prod), same shape with `aiqadam-prod-deploy-ci` and `95.46.211.224`.

**Why this will now succeed (it did not in attempt 3):** the forced-command mechanism (`authorized_keys`' `command=` option) was already proven to be correctly parsed and applied by sshd in attempt 3's own verbose log — the only failure was that `/usr/sbin/nologin` refused to execute anything once invoked. With `/bin/bash` as the shell (Step 7, this revision), sshd's `<shell> -c <forced-command>` invocation will actually run `/opt/apps/aiqadam-<env>/deploy/deploy.sh` instead of being blocked before it starts.

Verification: session connects, forced-command fires (no shell prompt — `no-pty` still blocks any interactive fallback), output shows the marker line and a `docker compose ps` table listing that host's containers (now with visible data rows on prod too, per the Step 11 fix), connection closes cleanly (exit 0).

Also, as a negative control (both environments, unchanged): attempt `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip> "whoami; cat /etc/shadow"` and confirm the forced-command still fires instead of the injected command. **This is a stronger proof now than in attempt 3** — previously both the legitimate and the injected command were blocked identically by nologin, which is a degenerate pass (nothing runs, so nothing leaks, but the mechanism being tested wasn't actually exercised). With a working shell, this control now genuinely demonstrates that `command=`'s override is what's enforcing the restriction, not an unrelated shell failure.

### Rollback

1. **`.env` group/mode grant (Step 11a) — both hosts:**
   ```
   ssh tvolodi@<host-ip> "sudo chmod 600 /opt/apps/aiqadam-<env>/deploy/.env && sudo chgrp tvolodi /opt/apps/aiqadam-<env>/deploy/.env && sudo stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/.env"
   ```
   Restores `.env` to `tvolodi:tvolodi 600`. Then: `ssh tvolodi@<host-ip> "sudo groupdel aiqadam-<env>-secrets"`. No secret value is touched.
2. **sshd `AllowGroups` edit (Step 3) — both hosts:** restore from the Step 1 backup, `sshd -t`, `systemctl reload ssh.service`.
3. **`deploybots` group (Step 2):** `sudo groupdel deploybots` — after the `AllowGroups` revert.
4. **`deploy` user (Steps 7–11):** `sudo userdel -r deploy` — removes `/home/deploy` including `authorized_keys`. The shell field (`/bin/bash` vs `/usr/sbin/nologin`) requires no separate rollback step — it is deleted along with the account by `userdel`. The placeholder `deploy.sh` at `/opt/apps/aiqadam-<env>/deploy/deploy.sh` survives `userdel -r` (not under `/home/deploy`); follow with `sudo rm -f /opt/apps/aiqadam-<env>/deploy/deploy.sh`.
5. **Local keypairs (Step 9):** no host-side rollback needed if not yet installed. If already installed and rollback is required, delete the local key files only after confirming no pending GitHub secret paste depends on them.
6. **GitHub Actions secrets:** out of scope — not reached by this plan.

### Verification (for step 07)

- **On-host (both hosts):**
  - `getent group deploybots` returns a line; `id deploy` shows groups including `deploybots`, `docker`, and `aiqadam-<env>-secrets`; `getent passwd deploy` shows shell `/bin/bash` (not `/usr/sbin/nologin` — this is the key changed-state check for this revision).
  - `sudo grep -n '^AllowGroups' /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` shows `AllowGroups sshusers deploybots`.
  - `sudo sshd -t` exits 0; `systemctl is-active ssh.service` returns `active`.
  - `sudo cat /home/deploy/.ssh/authorized_keys` shows exactly one line with the correct `command=` path and matching key comment; file is `deploy:deploy 600`.
  - `stat -c '%U:%G %a' /opt/apps/aiqadam-<env>/deploy/deploy.sh` returns `deploy:deploy 750`; `grep -F "docker compose -p aiqadam-<env>" /opt/apps/aiqadam-<env>/deploy/deploy.sh` (grep on the script file, not `.env` — not a secret) confirms the explicit project-name flag is present.
  - `sudo stat -c '%U:%G %a %s %Y' /opt/apps/aiqadam-<env>/deploy/.env` returns `tvolodi:aiqadam-<env>-secrets 640 <size> <mtime>`, size/mtime numerically unchanged from Step 0's discovery; `getent group aiqadam-<env>-secrets` shows exactly `tvolodi,deploy`.
  - `sudo -u deploy /opt/apps/aiqadam-<env>/deploy/deploy.sh` exits 0 and prints the marker line plus a `docker compose ps` table with data rows on **both** hosts (QA already showed rows in attempt 3; prod is now expected to as well, per the Step 11 `-p` fix).
  - No `/etc/sudoers.d/90-deploy` file exists on either host — confirms no sudo grant was made.
  - Backup files under `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf.pre-T0112.*.bak` exist on both hosts.
  - **The validator must NOT run any command that reads `.env` content** — all `.env` verification is metadata-only (stat) or functional (deploy.sh's `docker compose ps` output).
- **Prod-specific no-regression:** all 7 Penpot containers `Up`; `https://penpot.aiqadam.org` returns `200`; `https://aiqadam.org/health` returns `200`.
- **External (both hosts) — this is the check that failed in attempt 3 and is the primary thing step 07 must re-confirm:**
  - `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip>` connects, forced-command fires, marker line + `docker compose ps` output (with data rows) appears, session closes cleanly (exit 0). **No "This account is currently not available." message.**
  - `ssh -i <local-private-key> -o IdentitiesOnly=yes deploy@<host-ip> "whoami; cat /etc/shadow"` (forbidden arbitrary command) results in the forced command running instead of the injected command — confirmed by output matching the legitimate Step 13 run's output, not `whoami`/`/etc/shadow` content.
  - `ssh-keyscan -t ed25519 <host-ip>` output matches the fingerprint already in the workstation's `known_hosts`.

### Resources used
- Secrets (by name): `aiqadam-qa-deploy-ssh-key`, `aiqadam-prod-deploy-ssh-key` (new, private key values never enter this repo). Existing secrets (`aiqadam-qa-jwt-signing-secret`, `aiqadam-qa-internal-api-token`, `aiqadam-prod-jwt-signing-secret`, `aiqadam-prod-internal-api-token`, `aiqadam-prod-postgres-password`) are referenced by name only, never read or modified. Per the user's prior out-of-band decision, the QA Postgres password exposed in attempt 2 is NOT being rotated as part of this plan.
- Files modified on host:
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (both hosts — `AllowGroups` line edited)
  - `/home/deploy/.ssh/authorized_keys` (both hosts — new file)
  - `/opt/apps/aiqadam-qa/deploy/deploy.sh` (QA — new file, now with explicit `-p aiqadam-qa`)
  - `/opt/apps/aiqadam-prod/deploy/deploy.sh` (prod — new file, now with explicit `-p aiqadam-prod`)
  - `/opt/apps/aiqadam-qa/deploy/.env` (QA — group and mode changed only, content untouched)
  - `/opt/apps/aiqadam-prod/deploy/.env` (prod — group and mode changed only, content untouched)
  - `deploy` system user itself now has shell `/bin/bash` instead of `/usr/sbin/nologin` (both hosts) — this is the substantive change in this revision.
- Files modified in this repo (landscape/), to be applied at step 08:
  - [landscape/hosts/pro-data-tech-qa.md](../../landscape/hosts/pro-data-tech-qa.md) — new `deploy` user (shell `/bin/bash`, forced-command-restricted), `deploybots` group, `AllowGroups` update, placeholder script path (with explicit `-p` flag), `aiqadam-qa-secrets` group and `.env` group/mode change.
  - [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md) — same, plus explicit note that Penpot was confirmed unregressed, plus `aiqadam-prod-secrets` group and `.env` group/mode change.
  - [landscape/secrets-inventory.md](../../landscape/secrets-inventory.md) — add `aiqadam-qa-deploy-ssh-key` and `aiqadam-prod-deploy-ssh-key` rows (names + storage location only).
- External APIs called: none. Manual step required of the user after execution: paste `QA_SSH_DEPLOY_KEY`, `PROD_SSH_DEPLOY_KEY`, `QA_SSH_HOST_KEY`, `PROD_SSH_HOST_KEY` into GitHub Actions repository secrets in `aiqadam/ai-qadam-platform` — unchanged, still a hard stop for this repo's own tooling.

### Estimated impact
- Downtime: none expected. sshd `reload` (not `restart`) preserves sessions. The `.env` permission change does not restart or touch any running container. The `deploy` user's shell change is a metadata-only `useradd` field, applied only at account-creation time (fresh account each run, since the plan always starts from clean baseline) — no running process is affected.
- Affected services: `ssh.service` (config reload, both hosts). No application service is restarted. Penpot and the AiQadam QA/prod app stacks are explicitly verified unaffected.
- Reversibility: fully reversible. `.env`'s group/mode reverts to its exact pre-change state; the secrets group is deletable; sshd drop-in restored from backup; `deploy` user (including its shell field) and `deploybots` group removed entirely via `userdel -r`/`groupdel`. The one exception, as before, is anything already pasted into GitHub Actions secrets by the time a rollback is requested.

## Issues / risks
- **sshd drop-in edit on two hosts, one running a live Penpot workload — requires approval by policy.** Unchanged from all prior versions: additive, narrow, validated with `sshd -t` before `reload`, with an explicit Penpot no-regression check.
- **`.env` permission change on both hosts, one with live prod secrets already in use by running containers.** The change is metadata-only and does not touch, read, log, or transmit any secret value. This alone independently justifies `NEEDS_APPROVAL`.
- **New user creation + SSH key generation/installation on two hosts, now with a real login shell (`/bin/bash`) instead of `/usr/sbin/nologin`.** Per `shared/approval-protocol.md`, OS-level/access-control changes always require `NEEDS_APPROVAL`; a shell-field change for a CI-facing account is squarely in that category and is the specific thing this revision changes — it must not be treated as automatically low-risk just because it is a narrow diff. The security reasoning is laid out in full above (password-locked, no sudo, single dedicated key, `command=` unconditional override, `no-pty` blocking interactive use) and this designer has **no residual doubt** about its safety, but the category itself (shell/account posture for an SSH-reachable account) is one `shared/approval-protocol.md` places in the always-`NEEDS_APPROVAL` bucket regardless of designer confidence.
- **This is the fourth design pass and fourth execution attempt for this run.** Attempt 1 failed cleanly at Step 11's pre-check (`.env` permission gap, no `deploy` user existed yet). Attempt 2's forward commands succeeded but its verification command produced a false negative, and an off-plan diagnostic exposed a secret value in the transcript (resolved: user chose not to rotate, verification method corrected). Attempt 3 executed Steps 0–12 flawlessly on both hosts, including the corrected Step 11a verification, and failed only at Step 13 due to the `nologin` shell blocking forced-command execution — a narrower, purely mechanical gap unrelated to permissions or secrets. This revision's diff versus the already-twice-proven plan is exactly two lines: Step 7's `--shell` flag, and Step 11's `docker compose` invocation gaining a `-p` flag. No other design surface changed.
- **Blast radius remains bounded** to the `deploy` user (now with a real but tightly-restricted shell), the `deploybots` group, the two `deploy.sh` files, the two `aiqadam-<env>-secrets` groups, and the group/mode bits (never content) of the two `.env` files. No existing operator account, sudoers drop-in, Docker container, nginx vhost, TLS cert, Cloudflare record, or secret value is touched.
- **Idempotency:** all steps are guarded (`id deploy 2>/dev/null ||`, `getent group ... ||`, `test -f ... ||`) so re-running from a clean baseline behaves identically to a first run. Step 0 explicitly re-verifies the clean-baseline assumption (including `.env`'s exact size/mtime) before any mutating command runs.

## Open questions
none — the shell-choice investigation is fully resolved above (real shell + authorized_keys-only lockdown selected; sshd-level `Match`/`ForceCommand` considered and rejected as routing through the identical `<shell> -c <command>` mechanism that would still be blocked by nologin), Steps 0–6/8–10/11a/12 are carried forward unchanged and proven correct by two consecutive successful executions, Step 11's cosmetic prod `docker compose ps` gap is resolved in-plan with an explicit `-p` flag rather than deferred, and Step 13 is expected to succeed with a stated mechanical reason why. This still requires human approval per policy (new-account shell/access-control change on two hosts, one hosting a live Penpot workload) — not because the designer has doubts, but because this category of change is always `NEEDS_APPROVAL` regardless of confidence.
