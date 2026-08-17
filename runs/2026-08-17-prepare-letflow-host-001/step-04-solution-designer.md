---
run_id: 2026-08-17-prepare-letflow-host-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-17T11:40:00Z
task_id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
retry_of: step-04
inputs_read:
  - runs/2026-08-17-prepare-letflow-host-001/step-01-task-reader.md
  - runs/2026-08-17-prepare-letflow-host-001/step-02-landscape-reader.md
  - runs/2026-08-17-prepare-letflow-host-001/step-03-task-validator.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-04-solution-designer-attempt-2.md
  - runs/2026-08-17-prepare-letflow-host-001/step-05-user-approval.md
  - runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-06-executor-infra.attempt1.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-06-executor-infra.attempt2.md
  - runs/2026-08-17-prepare-letflow-host-001/step-0-3-accounts-baseline.txt
  - runs/2026-08-17-prepare-letflow-host-001/step-0-6-firewall-baseline.json
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md
  - tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - landscape/README.md
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - tasks/T-0102-harden-sshd-on-pro-data-tech-prod.md
  - tasks/T-0106-install-docker-on-pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-04-solution-designer.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-06-executor-infra.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-b-apply-request.json
  - runs/2026-06-27-apply-hetzner-firewall-001/executor-02-helpers.ps1
  - runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-harden-sshd-pro-data-tech-prod-001/step-04-solution-designer.md
artifacts_changed: []
next_step_hint: >
  Second re-plan, superseding the attempt-2 design (approved, then FAILed a
  third time at executor step 06 — this time at Phase 0 step 0.6, on a live
  Hetzner Cloud Firewall port-22 rule that has been widened to 0.0.0.0/0 +
  ::/0, undocumented anywhere in this repo). The user has already been asked
  and has already answered the one open question this halt produced: leave
  port 22 open to anywhere, do not narrow it back. Orchestrator must re-run
  the full approval gate: present this plan fresh, do NOT reuse the prior
  step-05 APPROVED verdict — the substantive change here (preserving a wide
  SSH rule instead of narrowing it) was never presented to the user as part
  of a plan before now, only as a bare open question after a halt. If
  APPROVED, advance to executor-infra with this file plus the new step-05 as
  inputs. Executor MUST re-run Phase 0 in full (0.0-0.7), not resume from
  0.6, per this design's explicit instruction below.
---

## Summary

Revised plan (second revision) that is identical in substance to the attempt-2 design for Phases 1-3 (account lockout of `viktor_d`/`binali_r`, sshd hardening reconciliation, Docker install — all already user-approved and already re-confirmed live by the attempt-3 executor run through step 0.5) and differs only in Phase 4 (Hetzner Cloud Firewall): the port-22 rule is now preserved exactly as its live, widened state — `source_ips: ["0.0.0.0/0", "::/0"]` — per the user's explicit instruction ("Leave it open to anywhere"), instead of being narrowed back to `178.89.57.135/32` as the prior design assumed. The firewall-widening discovery is folded into the same `T-0135` undocumented-change observation task this plan already opens, as a second finding alongside the `T-0087` sshd/account discovery. End state: unchanged from attempt-2's design except the Hetzner Cloud Firewall carries three rules (22 open to `0.0.0.0/0`/`::/0` reconfirmed as-is, 80 and 443 newly opened to `0.0.0.0/0`/`::/0`) rather than reverting port 22 to the workstation IP.

## Details

### Why this revision exists

Attempt 3 of executor-infra (`runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md`, verdict `FAIL`, `retry_of: step-06`) ran Phase 0 steps 0.0 through 0.5 cleanly — every value matched attempt-2's live findings exactly, no further drift — then halted at **0.6** (Hetzner Cloud Firewall live-state check) because the live rule for TCP 22 no longer matches what the attempt-2 plan assumed:

- Attempt-2 plan's 0.6 verification expected "exactly one rule (`tcp/22` from `178.89.57.135/32`)".
- Live response (`runs/2026-08-17-prepare-letflow-host-001/step-0-6-firewall-baseline.json`) shows:
  ```json
  {
    "description": "SSH from anywhere (widened 2026-06-27)",
    "direction": "in",
    "port": "22",
    "protocol": "tcp",
    "source_ips": ["0.0.0.0/0", "::/0"]
  }
  ```
- No task or run anywhere in this repo's `tasks/` or `runs/` trees documents this widening (the attempt-3 executor's own grep across `landscape/`, `tasks/`, and `runs/` found nothing beyond the original `T-0086` narrow-rule application, still `done`).
- This is the **third** undocumented out-of-band change discovered on this host during this run, after `T-0087`'s sshd hardening and the `viktor_d`/`binali_r` accounts (attempt-2's discovery). The executor correctly refused to improvise either a silent re-narrow or a silent carry-forward of the wide rule, and halted per its own rule against off-plan inference on a live firewall change.

The user was asked how to handle this and replied: **"Leave it open to anywhere."** This is read as an explicit, deliberate instruction not to narrow port 22 back to the workstation CIDR as part of this run's Phase 4 firewall update — the widened rule is to be reconfirmed/preserved, not reverted.

Per this revision's design brief: Phase 4's `4.1` example JSON body in the attempt-2 plan still showed `"source_ips": ["178.89.57.135/32"]` for port 22 as an illustrative placeholder, even though the surrounding prose already said to use "0.6's live response" — this ambiguity (a stale literal next to a correct-but-generic instruction) is exactly the kind of thing an executor should not have to resolve by inference on a live firewall change, and this revision removes it by making the literal correct.

### What is unchanged from attempt-2's design (re-confirmed live, not re-litigated)

Phases 0 (0.0-0.5), 1, 2, and 3 are carried forward **verbatim** from the attempt-2 design (`runs/2026-08-17-prepare-letflow-host-001/.attempts/step-04-solution-designer-attempt-2.md`), including all five design decisions (a)-(f) documented there:
- (a) Account disposition for `viktor_d`/`binali_r`: lock via `usermod -e 1` + `usermod -L`, do not delete.
- (b) sshd hardening reconciliation: replace `T-0087`'s `40-ssh-hardening.conf` with the fleet-standard `40-ai-dala-infra.conf` (`AllowGroups sshusers`, `tvolodi`+`root` only).
- (c) Account lockout ordered strictly before sshd hardening (Phase 1 before Phase 2).
- (d) Docker/UFW `after.rules` DOCKER-USER: not applied proactively, live-tested and conditionally deferred.
- (f) `secrets-inventory.md` documentation additions and the new observation task `T-0135` (scope extended in this revision — see below).

These were independently re-confirmed live by the attempt-3 executor run (steps 0.0-0.5 all matched attempt-2's findings exactly, with zero further drift) immediately before the run halted at 0.6. Re-litigating them here would contradict the instruction that authored this revision. **Only decision (e) — the Hetzner Cloud Firewall port-22 CIDR — changes, and only in Phase 4.**

### Revised decision (e) — Hetzner Cloud Firewall port-22 rule: preserve the live wide-open state, do not narrow

**Prior assumption (attempt-2 design, now superseded):** port 22 would be re-submitted unchanged at `178.89.57.135/32` (the workstation IP), on the assumption that this was still the live state; 80/443 would be newly opened to `0.0.0.0/0`/`::/0`.

**Live fact (attempt-3 executor, step 0.6):** port 22 is currently `0.0.0.0/0` + `::/0`, self-described by its own `description` field as "SSH from anywhere (widened 2026-06-27)" — a deliberate, named, but undocumented change.

**User's decision (this revision's authorizing instruction):** "Leave it open to anywhere."

**Concrete effect on the plan:** Phase 4.1's `set_rules` request body must carry the port-22 entry's `source_ips` as `["0.0.0.0/0", "::/0"]` — copied verbatim from `step-0-6-firewall-baseline.json` — not `178.89.57.135/32`. The description is updated to record that this run reconfirmed the widening as an intentional, now-documented state (rather than leaving the unexplained "(widened 2026-06-27)" wording, which reads as informal and undated-as-to-*why*). This is shown as a literal, non-ambiguous JSON body in Phase 4.1 below — there is no placeholder value left for the executor to resolve by inference.

This is flagged HIGH in Issues/risks below: it is a live change to a production firewall's security posture, explicitly instructed by the user but still substantively different from this host's original, narrower Hetzner-firewall design (`T-0086`) and worth the user's final confirmation at the approval gate, since this is the first time a *plan* (not just a bare question after a halt) presents the concrete before/after.

### Revised scope of `T-0135` — now covers two undocumented changes, not one

Attempt-2's design opened `T-0135` to track only the `T-0087` sshd-hardening + operator-account discovery. This revision folds the firewall-widening discovery into the **same** task rather than opening a third task, because:
- Both changes are on the same host (`ubuntu-16gb-nbg1-1`).
- Both are dated in or immediately around 2026-06-27 (`T-0087`'s drop-in files are dated 2026-06-27; the firewall rule's own `description` says "widened 2026-06-27"; the firewall object itself was `created: 2026-06-27T07:14:31Z`).
- Both share the identical process-gap pattern: a deliberate, seemingly-intentional change to this host's security posture, made outside this repo's task/workflow/landscape-update discipline, with zero record in `tasks/` or `runs/`.
- Investigating "who/what changed this host outside the process on 2026-06-27" is a single coherent question whether the answer turns out to be one actor making multiple changes or several unrelated ones — splitting it into two tasks would fragment a single investigation without a clear scoping benefit.

`T-0135`'s acceptance criteria (to be finalized by landscape-updater at step 08, per the resources-used section below) now explicitly lists both findings as in-scope, and notes the corroborating-but-unconfirmed link to `tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md` (same accounts, same date, same key-naming convention) as before, without conflating that corroboration with the firewall finding (no equivalent corroborating record was found for the firewall widening — it is a bare fact with no matching pattern elsewhere in the repo).

### Whether Phase 0 (0.0-0.5) must be re-run in full, or execution may resume from 0.6

**Decision: re-run Phase 0 in full, 0.0 through 0.7.** Do not resume from 0.6.

Reasoning: this project's stated discipline (carried through both prior revisions of this plan, and restated in this run's own halts) is to always reconfirm live state, never assume it has not drifted since the plan was written — and this run has now produced *three* separate instances of exactly that drift happening (the SSH-alias question at attempt 1, the `T-0087`/account discovery at attempt 2, and the firewall widening at attempt 3). Each was caught only because Phase 0 re-checked live state instead of trusting the prior handoff. There is no basis for treating this fourth attempt as exempt from that discipline merely because the most recent halt happened relatively recently (within the same session) — a new executor invocation is a fresh process with no continuity guarantee from the halted one, and re-running 0.0-0.5 costs a handful of cheap, read-only commands against commands that already have known-good expected outputs to check against. The cost of skipping and being wrong (proceeding into Phase 1's account lockout on stale assumptions) is materially higher than the cost of five redundant read-only checks. This is spelled out explicitly in Phase 0 below so the executor does not have to infer it.

---

### Pre-execution requirement

All host-side commands run over a single persistent SSH session opened before any changes, using the existing config alias: `ssh ubuntu-16gb-nbg1-1` (management workstation `C:\Users\tvolo\.ssh\config`, key `C:\Users\tvolo\.ssh\ai-dala-infra`, user `tvolodi`).

The session must stay open through Phase 3 (sshd hardening) so a live rollback path exists if a hard gate fails.

All Hetzner Cloud API calls use the existing PowerShell helper pattern from `runs/2026-06-27-apply-hetzner-firewall-001/executor-02-helpers.ps1` (already copied into this run's directory as `executor-06-helpers.ps1` by the attempt-3 executor; reuse it as-is). Token loaded from disk into a local variable, never echoed, never written to a file: token file `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, secret name `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`.

---

### Phase 0 — Live-state reconfirmation (read-only, full re-run — see "Whether Phase 0 must be re-run" above)

**0.0 — SSH alias reachability.** Command: `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; whoami"` — Verification: `===OK===` banner, `whoami` returns `tvolodi`. If this fails, STOP — report to the user; do not improvise an alternate invocation.

**0.1 — Current sshd effective config (re-check; expect the same T-0087 state attempt 3 found).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries|logingracetime|allowusers|allowgroups) '"` — Verification: expected `permitrootlogin no`, `passwordauthentication no`, `kbdinteractiveauthentication no`, `maxauthtries 6`, `logingracetime 120`, `allowusers` = `tvolodi`, `viktor_d`, `binali_r` (three separate lines), no `allowgroups` line. If this deviates, STOP and escalate — do not proceed on stale assumptions a fourth time.

**0.2 — Current sshd_config.d contents (re-check).** Command: `ssh ubuntu-16gb-nbg1-1 "ls -la /etc/ssh/sshd_config.d/; cat /etc/ssh/sshd_config.d/40-disable-password.conf; cat /etc/ssh/sshd_config.d/40-ssh-hardening.conf"` — Verification: `40-disable-password.conf` contains `PasswordAuthentication no` / `KbdInteractiveAuthentication no`; `40-ssh-hardening.conf` contains `AllowUsers tvolodi viktor_d binali_r` and the `.bak.20260627T145652Z` sibling is present (per attempt 3's exact findings). If `40-ssh-hardening.conf` is absent or its `AllowUsers` line no longer lists exactly these three users, STOP and escalate.

**0.3 — Current account state for `viktor_d`/`binali_r` (re-check + fresh pre-change snapshot for rollback — overwrite the prior baseline file so Phase 1's rollback reference is current).** Command: `ssh ubuntu-16gb-nbg1-1 "id viktor_d; id binali_r; sudo chage -l viktor_d; sudo chage -l binali_r; sudo passwd -S viktor_d; sudo passwd -S binali_r"` — Verification: both accounts exist, uid 1001/1002, groups include `sudo`; capture full `chage -l` and `passwd -S` output verbatim into `runs/2026-08-17-prepare-letflow-host-001/step-0-3-accounts-baseline.txt` (overwrite the attempt-3 copy with a fresh timestamped capture — this is the authoritative pre-change snapshot for this attempt, not a re-use of a now-hours-old file).

**0.4 — Current UFW / after.rules state.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo ufw status verbose; echo ---; sudo cat /etc/ufw/after.rules"` — Verification: `22/tcp`, `80/tcp`, `443/tcp` all `ALLOW IN Anywhere` (host-level UFW, already open — unrelated to the Hetzner Cloud Firewall layer this plan's Phase 4 changes); `after.rules` contains no pre-existing `DOCKER-USER` or `T-0134` marker.

**0.5 — Docker absence check.** Command: `ssh ubuntu-16gb-nbg1-1 "dpkg -l docker-ce 2>/dev/null | grep '^ii' || echo NOT_INSTALLED"` — Verification: `NOT_INSTALLED`. If Docker is already installed, skip Phase 3's install sub-steps and run only its verification sub-steps.

**0.6 — Current Hetzner Cloud Firewall rule set (live, not from the landscape doc — also the pre-change backup/snapshot for Phase 4's rollback). Expected to show the widened port-22 rule; this is no longer a halt condition.** Command: `GET https://api.hetzner.cloud/v1/firewalls/11204449` — Verification: HTTP 200; exactly one rule, `tcp/22`, `source_ips: ["0.0.0.0/0", "::/0"]`, `description` containing "widened" (per the attempt-3 finding, now expected and accepted). Save response to `runs/2026-08-17-prepare-letflow-host-001/step-0-6-firewall-baseline.json` (overwrite with a fresh capture). **If the live rule differs from this expectation in any way other than matching it — e.g. it has been narrowed again, or changed to some third value — STOP and escalate; do not proceed into Phase 4 on a fourth stale assumption.** Use the exact `source_ips`/live values from this fresh response when constructing Phase 4's `set_rules` body (Phase 4.1 below already reflects the expected value literally, but this step's fresh capture is the authoritative source if there is ever a discrepancy between it and this document).

**0.7 — Baseline external TCP-reachability probe for 80/443 (pre-change signature, for step 07's dual-probe comparison).** Commands, from the management workstation:
```powershell
Measure-Command { Test-NetConnection 46.225.239.60 -Port 80 } | Select-Object TotalSeconds
Measure-Command { Test-NetConnection 46.225.239.60 -Port 443 } | Select-Object TotalSeconds
```
Verification: expect `TcpTestSucceeded: False` for both, slow/timeout-length completion (Hetzner Cloud Firewall dropping non-allow-listed ports at the cloud edge). Save outputs to `preflight-0-7-tcp80-before.txt` / `preflight-0-7-tcp443-before.txt`.

---

### Phase 1 — Account lockout: `viktor_d` and `binali_r` (per user decision — lock, not delete)

Unchanged from attempt-2's design. This phase is intentionally first and intentionally separate from the sshd hardening in Phase 2, so the access-revocation decision is explicit and independently verifiable, not an implicit side effect of `AllowGroups` membership.

**1.1 — Expire `viktor_d`'s account (blocks all login methods immediately, independent of sshd config).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -e 1 viktor_d"` — Verification: `sudo chage -l viktor_d` shows `Account expires : Jan 02, 1970` (or equivalent already-expired date).

**1.2 — Expire `binali_r`'s account.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -e 1 binali_r"` — Verification: `sudo chage -l binali_r` shows an already-expired date.

**1.3 — Lock `viktor_d`'s password (defense in depth; password auth is already host-wide disabled).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -L viktor_d"` — Verification: `sudo passwd -S viktor_d` shows `L` (locked) in the status field. (Note: attempt 3's step 0.3 found both accounts' passwords were already `L`-locked at provisioning time — this step is idempotent and expected to be a no-op confirmation, not a new state change.)

**1.4 — Lock `binali_r`'s password.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -L binali_r"` — Verification: `sudo passwd -S binali_r` shows `L`.

**1.5 — Verify: SSH login attempt as `viktor_d` is rejected (external check, requires a key for that user — if unavailable, verify via account-expiry state instead).** Since no `viktor_d`/`binali_r` private key exists on the management workstation, this cannot be tested end-to-end as an external SSH probe. Verification is instead via on-host state only: `ssh ubuntu-16gb-nbg1-1 "sudo -u viktor_d -i true 2>&1 || echo LOGIN_BLOCKED"` — Verification: output contains `LOGIN_BLOCKED` or an equivalent expired-account/`su`-denial message. This is a best-effort local proxy for "cannot log in," not a gap in the lockout itself (the `chage`/`passwd -S` checks in 1.1-1.4 are the authoritative state checks).

**1.6 — Confirm no other locked-out side effects.** Command: `ssh ubuntu-16gb-nbg1-1 "id viktor_d; id binali_r; ls -la /home/viktor_d /home/binali_r 2>&1 | head -5"` — Verification: both accounts still resolve (uid/gid/groups unchanged — confirms they were not deleted), home directories still present with original ownership and contents untouched.

---

### Phase 2 — sshd hardening reconciliation (replaces `T-0087`'s access-control drop-in with the fleet-standard pattern)

Unchanged from attempt-2's design.

**2.1 — Backup existing sshd config (full directory, before any edit).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo cp -r /etc/ssh /var/backups/pre-T0134.$(date +%Y%m%dT%H%M%SZ)"` — Verification: `ls /var/backups/ | grep pre-T0134` returns a timestamped directory containing `sshd_config`, `sshd_config.d/` (including the `T-0087`-authored `40-ssh-hardening.conf` and its own pre-existing `.bak` file), `50-cloud-init.conf`.

**2.2 — Create `sshusers` group (idempotent).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo groupadd -f sshusers"` — Verification: `getent group sshusers` returns `sshusers:x:<gid>:`.

**2.3 — Add `tvolodi` to `sshusers` (CRITICAL — load-bearing; omitting this locks out the only working SSH identity once `AllowGroups sshusers` is active).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG sshusers tvolodi"` — Verification: `id tvolodi | grep sshusers` exits 0.

**2.4 — Add `root` to `sshusers` (break-glass parity; harmless — root has no installed key, `/root/.ssh/` confirmed empty).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG sshusers root"` — Verification: `id root | grep sshusers` exits 0.

**2.5 — Explicit non-step: `viktor_d` and `binali_r` are NOT added to `sshusers`.** No command — this is the intentional, reviewable omission implementing the user's decision. Verified negatively in 2.13 below.

**2.6 — Rewrite `/etc/ssh/sshd_config.d/40-disable-password.conf` (idempotent — content matches what `T-0087` already wrote; reused, not left as an unmanaged legacy file).**
```
ssh ubuntu-16gb-nbg1-1 "cat | sudo tee /etc/ssh/sshd_config.d/40-disable-password.conf > /dev/null << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF"
```
Verification: `cat /etc/ssh/sshd_config.d/40-disable-password.conf` matches exactly (no change expected — confirms idempotency, not a functional edit).

**2.7 — Write `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf`** (fleet-standard content, identical to T-0093/T-0102):
```
ssh ubuntu-16gb-nbg1-1 "cat | sudo tee /etc/ssh/sshd_config.d/40-ai-dala-infra.conf > /dev/null << 'EOF'
PermitRootLogin prohibit-password
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
AllowGroups sshusers
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
EOF"
```
`PubkeyAuthentication yes` and `UseDNS no` are left unset (already OpenSSH/host defaults, consistent with the QA/prod drop-ins).

**2.8 — Backup and remove `T-0087`'s superseded `40-ssh-hardening.conf` and its `.bak` sibling (this is the destructive step of this phase — full backup already captured in 2.1 before this runs).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo mv /etc/ssh/sshd_config.d/40-ssh-hardening.conf /var/backups/pre-T0134.\$(ls /var/backups/ | grep pre-T0134 | tail -1 | sed 's/pre-T0134\.//')/40-ssh-hardening.conf.removed 2>/dev/null || sudo cp /etc/ssh/sshd_config.d/40-ssh-hardening.conf /var/backups/40-ssh-hardening.conf.removed-T0134 && sudo rm -f /etc/ssh/sshd_config.d/40-ssh-hardening.conf /etc/ssh/sshd_config.d/40-ssh-hardening.conf.bak.20260627T145652Z"` — Verification: `ls /etc/ssh/sshd_config.d/` no longer lists `40-ssh-hardening.conf` or its `.bak` sibling; the pre-move content is recoverable from either the 2.1 full-directory backup or the explicit `/var/backups/40-ssh-hardening.conf.removed-T0134` copy.

**2.9 — Set permissions.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo chmod 644 /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"` — Verification: `ls -la /etc/ssh/sshd_config.d/` shows both, mode `-rw-r--r--`, owner `root root`.

**2.10 — HARD GATE: `sshd -t`.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -t"` — Verification: exit 0, no error output. **If non-zero: ABORT, do not proceed to 2.11/2.12, execute Rollback Scenario A immediately.**

**2.11 — HARD GATE: confirm `tvolodi` is in `sshusers` before reload.** Command: `ssh ubuntu-16gb-nbg1-1 "id tvolodi | grep sshusers"` — Verification: exit 0, output contains `sshusers`. **If non-zero: ABORT, do not reload, execute Rollback Scenario A immediately.**

**2.12 — HARD GATE: confirm `viktor_d`/`binali_r` are NOT in `sshusers` (positive confirmation the exclusion took effect as designed, not by accident).** Command: `ssh ubuntu-16gb-nbg1-1 "getent group sshusers | grep -qE 'viktor_d|binali_r' && echo UNEXPECTED_MEMBER || echo EXCLUSION_OK"` — Verification: output is `EXCLUSION_OK`. **If `UNEXPECTED_MEMBER`: ABORT — execute Rollback Scenario A and re-investigate before retrying.**

**2.13 — Reload sshd (preserves the active session).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo systemctl reload ssh"` — Verification: `systemctl is-active ssh` → `active`. (Unit is `ssh.service`, not `sshd.service`, per this host's landscape file.)

**2.14 — Verify sshd still running.** Command: `ssh ubuntu-16gb-nbg1-1 "systemctl is-active ssh"` — Verification: `active`.

**2.15 — Verify effective config (full directive set).**
```
ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowusers|allowgroups|kexalgorithms|ciphers|macs|usedns) '"
```
Expected: `permitrootlogin=prohibit-password`, `passwordauthentication=no`, `kbdinteractiveauthentication=no`, `pubkeyauthentication=yes`, `permitemptypasswords=no`, `maxauthtries=3`, `logingracetime=30`, `x11forwarding=no`, `clientaliveinterval=300`, `clientalivecountmax=2`, `allowgroups=sshusers`, **no `allowusers` line at all**, `kexalgorithms` contains `curve25519-sha256` and no `sha1`, `ciphers` contains `chacha20-poly1305` and no `3des`/`cbc`, `macs` contains `etm@openssh.com` and no `hmac-sha1`, `usedns=no`.

**2.16 — Verify group/membership (exact expected membership — positive AND negative check).** Command: `ssh ubuntu-16gb-nbg1-1 "getent group sshusers"` — Verification: output is exactly `sshusers:x:<gid>:root,tvolodi` (order may vary) — contains `tvolodi` and `root`, does **not** contain `viktor_d` or `binali_r`.

**2.17 — Verify drop-in files + backup + removed-file recoverability.** Commands: `ssh ubuntu-16gb-nbg1-1 "ls -la /etc/ssh/sshd_config.d/; cat /etc/ssh/sshd_config.d/40-disable-password.conf; cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf; ls /var/backups/ | grep -E 'pre-T0134|40-ssh-hardening'"` — Verification: `sshd_config.d/` contains exactly `40-disable-password.conf`, `40-ai-dala-infra.conf`, `50-cloud-init.conf` (no `40-ssh-hardening.conf*` remaining); both project files present with correct content and mode; `50-cloud-init.conf` unchanged; backup directory and the removed-file copy both exist.

**2.18 — External check: fresh SSH connection (new session, not the held-open one) confirms key auth still works post-hardening.** Command (from management workstation, a second/new terminal): `ssh ubuntu-16gb-nbg1-1 "whoami; id | grep sshusers"` — Verification: connects successfully, output contains `tvolodi` and `sshusers`.

**2.19 — External check: password auth is rejected.** Command: `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes ubuntu-16gb-nbg1-1 exit` — Verification: fails with `Permission denied (publickey)`.

---

### Phase 3 — Docker Engine + Compose plugin install

Unchanged from attempt-2's design. Mirrors T-0106 (`pro-data-tech-prod`).

**3.1 — Connectivity probe.** Command: `ssh ubuntu-16gb-nbg1-1 "curl -s --max-time 10 https://download.docker.com/linux/ubuntu/gpg > /dev/null && echo CONNECTIVITY_OK"` — Verification: output contains `CONNECTIVITY_OK`.

**3.2 — Idempotency guard (re-check of 0.5).** Command: `ssh ubuntu-16gb-nbg1-1 "dpkg -l docker-ce 2>/dev/null | grep -c '^ii'"` — Verification: `0`. If `1`, skip to 3.10.

**3.3 — Install apt prerequisites.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo apt-get install -y ca-certificates curl gnupg"` — Verification: `dpkg -l ca-certificates curl gnupg | grep -c '^ii'` returns `3`.

**3.4 — Docker GPG key into apt keyring.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && sudo chmod a+r /etc/apt/keyrings/docker.gpg"` — Verification: `test -f /etc/apt/keyrings/docker.gpg && echo GPG_OK`.

**3.5 — Add Docker stable apt repository.** `lsb_release -cs` returns `resolute` on Ubuntu 26.04 (confirmed on `pro-data-tech-qa`/`pro-data-tech-prod`, same OS). Command:
```
ssh ubuntu-16gb-nbg1-1 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
```
Verification: `cat /etc/apt/sources.list.d/docker.list` contains `download.docker.com` and `resolute`.

**3.6 — Update apt index.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo apt-get update"` — Verification: exit 0; output contains `download.docker.com`; no `E:` lines for that source.

**3.7 — Install Docker Engine + Compose plugin.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"` — Verification: `docker --version` prints `Docker version ...`; exit 0.

**3.8 — Enable and start Docker.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo systemctl enable docker && sudo systemctl start docker"` — Verification: `systemctl is-active docker` → `active`; `systemctl is-enabled docker` → `enabled`.

**3.9 — Add `tvolodi` to the `docker` group.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG docker tvolodi"` — Verification: `id tvolodi | grep docker`.

**3.10 — Verify: `docker run hello-world`.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo docker run hello-world"` — Verification: output contains `Hello from Docker!`; exit 0.

**3.11 — Verify: `docker compose version`.** Command: `ssh ubuntu-16gb-nbg1-1 "docker compose version"` — Verification: output starts with `Docker Compose version v`; exit 0.

**3.12 — Live container-egress test.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo docker run --rm alpine:3.20 sh -c 'wget -q -T 5 -O- https://api.ipify.org || echo EGRESS_FAILED'"` — Verification: output is a bare IPv4 address (egress works; **no `after.rules` change needed, Phase 3 is complete**). If `EGRESS_FAILED` or timeout, proceed to the conditional fallback below.

**3.13 — CONDITIONAL fallback (only if 3.12 shows `EGRESS_FAILED`) — discover the public interface name, then append the DOCKER-USER/MASQUERADE block.**
- 3.13a — Discover interface: `ssh ubuntu-16gb-nbg1-1 "ip -4 route show default"` — read the `dev <name>` field.
- 3.13b — Backup: `ssh ubuntu-16gb-nbg1-1 "sudo cp /etc/ufw/after.rules /var/backups/ufw-after.rules-pre-T0134.bak"` — Verification: `test -f /var/backups/ufw-after.rules-pre-T0134.bak`.
- 3.13c — Append (using the discovered interface name, here shown as `eth0`):
  ```
  ssh ubuntu-16gb-nbg1-1 "sudo tee -a /etc/ufw/after.rules > /dev/null << 'DOCKERRULES'

  # BEGIN Docker UFW coexistence rules (T-0134)
  *filter
  :DOCKER-USER - [0:0]
  -A DOCKER-USER -i eth0 -j RETURN
  COMMIT
  *nat
  :POSTROUTING - [0:0]
  -A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE
  COMMIT
  # END Docker UFW coexistence rules (T-0134)
  DOCKERRULES"
  ```
  Verification: `grep -c 'T-0134' /etc/ufw/after.rules` → `2`.
- 3.13d — Reload UFW: `ssh ubuntu-16gb-nbg1-1 "sudo ufw reload"` — Verification: `sudo ufw status` exits 0.
- 3.13e — Re-run 3.12. If it still fails, STOP and escalate — this is an execution-time blocker requiring re-design.

---

### Phase 4 — Hetzner Cloud Firewall: allow inbound TCP 80/443, preserve the live port-22 "anywhere" rule as-is

**REVISED from both prior attempts.** Port 22 is no longer re-narrowed to the workstation IP — per the user's explicit instruction ("Leave it open to anywhere"), the live wide-open rule is carried forward unchanged in substance, with only its `description` updated to reflect that this run reconfirmed it deliberately.

**Reuse decision:** reuse firewall `ai-qadam-mgmt-ssh` (id `11204449`) via `set_rules`, rather than creating a second firewall.

**4.1 — Construct the full replacement rule set (uses 0.6's live values for port 22, literally — no placeholder, no inference required).**
```json
{
  "rules": [
    {
      "direction": "in",
      "protocol": "tcp",
      "port": "22",
      "source_ips": ["0.0.0.0/0", "::/0"],
      "description": "SSH from anywhere (widened 2026-06-27, reconfirmed T-0134 2026-08-17 per explicit user decision)"
    },
    {
      "direction": "in",
      "protocol": "tcp",
      "port": "80",
      "source_ips": ["0.0.0.0/0", "::/0"],
      "description": "HTTP - public web traffic (T-0134, Letflow app host prep)"
    },
    {
      "direction": "in",
      "protocol": "tcp",
      "port": "443",
      "source_ips": ["0.0.0.0/0", "::/0"],
      "description": "HTTPS - public web traffic (T-0134, Letflow app host prep)"
    }
  ]
}
```
**This is now a literal, final body — not an illustrative example.** The port-22 entry's `source_ips` (`["0.0.0.0/0", "::/0"]`) matches Phase 0.6's live response exactly. If Phase 0.6 (re-run fresh in this attempt) shows any value other than what is documented above for port 22, STOP per 0.6's own instruction — do not substitute a different value into this body without a further design revision.

**4.2 — Apply.** Command: `POST https://api.hetzner.cloud/v1/firewalls/11204449/actions/set_rules` with the body above, `Content-Type: application/json`, `Authorization: Bearer <hetzner-api-token:ai-dala-infra:ai-qadam-read-write>`. Verification: HTTP 201 with an `actions` array; poll `GET /v1/firewalls/11204449/actions/<action_id>` every 2s (max 30s) until `status: "success"`.

**4.3 — Post-apply verification.** Command: `GET https://api.hetzner.cloud/v1/firewalls/11204449` — Verification: `rules` array contains exactly 3 entries matching 4.1 (port 22 still `0.0.0.0/0`+`::/0`, ports 80/443 newly `0.0.0.0/0`+`::/0`); `applied_to` still contains server `145542849`.

**4.4 — Post-apply external TCP-reachability probe (dual-signature comparison against 0.7).**
```powershell
Measure-Command { Test-NetConnection 46.225.239.60 -Port 80 } | Select-Object TotalSeconds
Measure-Command { Test-NetConnection 46.225.239.60 -Port 443 } | Select-Object TotalSeconds
```
Expected change from 0.7's baseline: `TcpTestSucceeded: False` for both (unchanged — no listener, by design), but completion is now **fast** (immediate TCP RST — packet now clears the Hetzner Cloud Firewall and UFW, finds no listener), versus 0.7's **slow/timeout** completion. Also spot-check SSH: `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True` (unaffected throughout — was already open, remains open).

**4.5 — Functional SSH still works (regression check).** Command: `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw"` — Verification: `===OK===`, both `active`. Note: `fail2ban`'s relevance is heightened by port 22 remaining world-reachable — this check confirms it is still the active defense-in-depth layer against brute-force attempts, since the Hetzner Cloud Firewall CIDR restriction (the outermost layer) is not providing that function for SSH on this host.

---

### Rollback

**Phase 1 (account lockout) rollback** — if execution must be aborted after Phase 1 but the accounts need restoring to their exact pre-lockout state:
1. Restore exact pre-lockout expiration from `step-0-3-accounts-baseline.txt`: `sudo usermod -e "<original-expiry-or-empty>" viktor_d` (and `binali_r`).
2. Restore exact pre-lockout password-lock state from the same file: if `passwd -S` showed unlocked (`P` or `NP`), run `sudo usermod -U viktor_d` (and `binali_r`); if it showed already-locked, no action needed (per 0.3/attempt-3's finding, both were already `L`-locked, so this step is expected to be a no-op in practice).
3. Verify: `sudo chage -l viktor_d; sudo passwd -S viktor_d` (and `binali_r`) match the 0.3 baseline file exactly.
Fully reversible — no data was touched, only account metadata, and the exact pre-change values were captured in 0.3.

**Phase 2 (sshd) rollback:**

*Scenario A — before reload (2.10, 2.11, or 2.12 gate fired):*
1. `sudo rm -f /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (the new file; `40-disable-password.conf` is unchanged/idempotent, left in place).
2. If 2.8 already ran (removed `40-ssh-hardening.conf`): restore it — `sudo cp /var/backups/40-ssh-hardening.conf.removed-T0134 /etc/ssh/sshd_config.d/40-ssh-hardening.conf` (and restore its `.bak` sibling from the 2.1 full-directory backup if needed).
3. `sudo sshd -t` — must exit 0.
4. No reload was ever issued; the active session was never disrupted. Host is back to its pre-Phase-2 state (T-0087's original hardening, with `viktor_d`/`binali_r` already locked out by Phase 1, which is NOT rolled back here — Phase 1 and Phase 2 rollbacks are independent).

*Scenario B — after reload, unexpected behavior:*
1. Same file restoration as Scenario A steps 1-2.
2. `sudo sshd -t`
3. `sudo systemctl reload ssh`
4. `systemctl is-active ssh` → `active`.

*Scenario C — catastrophic, full restore from backup:*
1. `sudo cp -r /var/backups/pre-T0134.<timestamp>/ssh/* /etc/ssh/`
2. `sudo sshd -t`
3. `sudo systemctl reload ssh`

**No-rollback-possible note (unchanged severity from prior attempts, still HIGH):** if `tvolodi` (and `root`) were somehow both excluded from `sshusers` at reload time despite gates 2.10/2.11/2.12 passing, and the held-open session also terminates before rollback is applied, the only recovery path is the **Hetzner Cloud Console (KVM-over-IP)**, confirmed available for this host. Note: since this revision leaves port 22 world-reachable rather than narrowing it, the Hetzner Cloud Console remains the correct recovery path regardless (it does not depend on the Cloud Firewall's port-22 CIDR either way).

**Phase 3 (Docker) rollback** — if any step 3.3-3.13 fails or post-install verification fails:
1. `sudo systemctl stop docker.service docker.socket containerd.service`
2. `sudo deluser tvolodi docker` (if 3.9 ran)
3. If 3.13 ran: `sudo cp /var/backups/ufw-after.rules-pre-T0134.bak /etc/ufw/after.rules && sudo ufw reload`
4. `sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && sudo apt-get autoremove -y`
5. `sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/sources.list.d/docker.list`
6. Verify: `sudo ufw status` unchanged; `dpkg -l docker-ce 2>/dev/null | grep -c '^ii'` → `0`.
Fully reversible — no application data exists on this host to lose.

**Phase 4 (Hetzner Firewall) rollback** — if 4.4's post-apply probe shows SSH (port 22) no longer reachable, or `set_rules` returns an error:
1. `POST /v1/firewalls/11204449/actions/set_rules` with the exact single-rule body captured fresh in this attempt's `step-0-6-firewall-baseline.json` (port 22, `0.0.0.0/0`+`::/0`, original "widened 2026-06-27" description — i.e. revert to the pre-this-run state, which already had port 22 world-open; this rollback does NOT narrow port 22, it only removes the newly-added 80/443 rules).
2. Re-verify: `GET /v1/firewalls/11204449` shows exactly 1 rule (port 22 only); `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True`.
Fully reversible via the same API used to make the change.

---

### Verification (for step 07)

**On-host:**
- Accounts: `viktor_d` and `binali_r` show expired (`chage -l`, expiry in the past) and locked (`passwd -S` shows `L`); both still resolve via `id` (not deleted); home directories `/home/viktor_d`, `/home/binali_r` still present, ownership/contents unchanged from the 0.3 baseline.
- sshd: `sshd -T` shows the full T-0093/T-0102-pattern directive set (see step 2.15); no `allowusers` line present at all; `getent group sshusers` is exactly `tvolodi`+`root`, explicitly excluding `viktor_d`/`binali_r`; `sshd_config.d/` contains exactly `40-disable-password.conf`, `40-ai-dala-infra.conf`, `50-cloud-init.conf` (no leftover `40-ssh-hardening.conf*`); backup directory `/var/backups/pre-T0134.*` exists and contains the original T-0087 files.
- Docker: `dpkg -l docker-ce docker-compose-plugin | grep -c '^ii'` → `2`; `systemctl is-active docker` → `active`; `systemctl is-enabled docker` → `enabled`; `id tvolodi | grep docker`; `sudo docker run hello-world` succeeds; `docker compose version` succeeds.
- Firewall (API-side): `GET /v1/firewalls/11204449` shows 3 rules — port 22 at `0.0.0.0/0`+`::/0` (unchanged from live pre-run state, description updated), ports 80/443 newly at `0.0.0.0/0`+`::/0` — and `applied_to` still contains server `145542849`.

**External:**
- TCP-level dual-signature probe: compare `preflight-0-7-tcp{80,443}-before.txt` (slow/timeout) against a post-change re-run of the same `Measure-Command { Test-NetConnection ... }` probes (fast RST).
- SSH: fresh (new-session) connection via `ssh ubuntu-16gb-nbg1-1` succeeds with key auth as `tvolodi`; `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes ubuntu-16gb-nbg1-1 exit` is rejected with `Permission denied (publickey)`.
- Port 22 reachable throughout (by design, unchanged from before this run): `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True` at every checkpoint.
- No external probe is possible for `viktor_d`/`binali_r` login denial (no key on the management workstation for either identity) — documented verification limitation, covered on-host only.

---

### Resources used

- **Secrets (by name):**
  - `ai-dala-infra` SSH key (management workstation, ed25519) — used for all host SSH commands.
  - `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` — used for the Phase 4 Hetzner Cloud API calls.
  - No new secrets are created by this plan.
- **Files modified on host (`ubuntu-16gb-nbg1-1`):**
  - `/etc/shadow`, `/etc/gshadow` (via `usermod -e`/`usermod -L` — account expiry + password lock for `viktor_d`, `binali_r`)
  - `/etc/group` (`sshusers` group: created, `tvolodi` + `root` added; `docker` group: `tvolodi` added)
  - `/etc/ssh/sshd_config.d/40-disable-password.conf` (rewritten idempotently, no net change)
  - `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (created)
  - `/etc/ssh/sshd_config.d/40-ssh-hardening.conf` and its `.bak` sibling (removed, backed up)
  - `/var/backups/pre-T0134.<timestamp>/` (created — full `/etc/ssh` backup)
  - `/var/backups/40-ssh-hardening.conf.removed-T0134` (created — explicit removed-file copy)
  - `/etc/apt/keyrings/docker.gpg`, `/etc/apt/sources.list.d/docker.list` (created)
  - `dpkg`/`apt` package database (Docker CE + Compose plugin installed)
  - Conditionally, only if 3.12 fails: `/etc/ufw/after.rules` (appended) + `/var/backups/ufw-after.rules-pre-T0134.bak` (backup)
- **External resources modified:**
  - Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`): rule set replaced from 1 rule (port 22, world-open) to 3 rules (port 22 world-open — reconfirmed, not changed in substance; ports 80/443 newly world-open).
- **Files modified in this repo (`landscape/`) — to be applied at step 08, not by this plan's executor:**
  - [landscape/hosts/ubuntu-16gb-nbg1-1.md](landscape/hosts/ubuntu-16gb-nbg1-1.md) — `role:` frontmatter (proposed value `letflow-app`), `last_verified` refresh, Access section fully rewritten (remove the false "clean slate" claim; document `T-0087`'s prior existence and this plan's reconciliation of it; document `viktor_d`/`binali_r` as present-but-locked, not absent), Hetzner Cloud Firewall section rule-set update **documenting port 22 as intentionally world-open** (not the workstation-scoped CIDR the section previously described), "What needs to happen" item 4 marked done, Docker install recorded, Change log entries for this run AND retroactive entries acknowledging both `T-0087`'s undocumented 2026-06-27 sshd/account changes AND the undocumented 2026-06-27 firewall port-22 widening.
  - [landscape/services.md](landscape/services.md) — `## ubuntu-16gb-nbg1-1` section: Docker status flipped to installed, systemd table updated with `docker.service`.
  - [landscape/secrets-inventory.md](landscape/secrets-inventory.md) — two new documentation-only rows (no values), unchanged from prior attempts:
    - `ai-dala-infra-ssh-key` | ed25519 keypair for SSH access to Hetzner-provisioned hosts in project ai-qadam; public key fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8` | Private key `C:\Users\tvolo\.ssh\ai-dala-infra` on management workstation.
    - `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` | Hetzner Cloud API token, project-scoped read-write, used for Cloud Firewall rule management on project ai-qadam (15130993) | `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` on management workstation.
  - `tasks/T-0135-<slug>.md` (NEW observation task, created at step 08) — **scope extended in this revision** to track two undocumented changes on `ubuntu-16gb-nbg1-1`, both dated 2026-06-27, both discovered only by this run's live Phase-0 checks: (1) sshd hardening (`T-0087`-labeled drop-in) + `viktor_d`/`binali_r` account provisioning, with a plausible-but-unconfirmed corroborating link to `tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md` (same accounts, same date, same key-naming convention); (2) the Hetzner Cloud Firewall port-22 rule widened from `178.89.57.135/32` to `0.0.0.0/0`+`::/0`, self-described in the API as "widened 2026-06-27," with no corroborating record found elsewhere in the repo. Both findings share the same process-gap pattern (deliberate-looking change to a managed host's security posture, made entirely outside this repo's task/workflow/landscape-update discipline) and are investigated together rather than as separate tasks. Added to `tasks/_index.md`.
- **External APIs called:** `api.hetzner.cloud` (Phase 4); `download.docker.com` and `registry-1.docker.io` (Phase 3, package + hello-world image fetch); `api.ipify.org` (Phase 3.12 egress test).

### Estimated impact

- **Downtime:** none for any existing service — this host runs no application workloads yet. `systemctl reload ssh` (SIGHUP) preserves the active session; the Hetzner Cloud Firewall `set_rules` action is applied atomically with no window of total lockout.
- **Affected services:** `sshd` (hardening reconciled — `T-0087`'s `AllowUsers` mechanism replaced with `AllowGroups sshusers`), local account state for `viktor_d`/`binali_r` (expired + locked, not deleted), `docker` (newly installed and started), Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (rule set expanded from 1 to 3 rules; port 22's world-open exposure is reconfirmed/continued, not newly introduced by this plan).
- **Reversibility:** fully reversible for Docker and the firewall (clean removal / API rollback — rollback restores the pre-run 1-rule state, which itself already had port 22 world-open, so rollback does not "fix" the wide-open SSH exposure; that is the accepted, user-directed end state, not a defect). sshd: drop-in restoration + reload, full `/etc/ssh` backup as last resort, hard gates prevent reloading into a broken/locking config. Account lockout: fully reversible via documented re-enable commands (not executed by this plan) — no data loss, home directories untouched.

## Issues / risks

- **HIGH — port 22 on the Hetzner Cloud Firewall remains open to the entire internet (`0.0.0.0/0` + `::/0`) by explicit user instruction, not narrowed back to the management workstation IP.** This is the substantive change this revision makes and the reason `NEEDS_APPROVAL` is retained rather than treating this as a minor correction. The user has already said "leave it open to anywhere" in response to a direct question, but that answer was given in reaction to a bare halt-report, not in review of a concrete plan showing the exact before/after JSON. This plan surfaces the literal rule body (Phase 4.1) so the user's final approval is against the actual change, not an abstract description. Mitigating factors already in place at other layers: UFW (host-level) does not restrict port 22 by source IP either (confirmed at 0.4, unchanged by this plan) so this plan does not reduce defense relative to the live state; `fail2ban` is confirmed active (4.5) as the operative brute-force defense; `PasswordAuthentication no` is enforced host-wide (Phase 2), so exposure is to key-guessing only, not credential-stuffing.
- **HIGH — sshd lockout risk (Phase 2), same class as both prior attempts.** `AllowGroups sshusers` denies all SSH logins to anyone not in that group at reload time. Mitigated by three hard gates (2.10 `sshd -t`, 2.11 `tvolodi` present, 2.12 `viktor_d`/`binali_r` absent) that abort before reload if any fails, by keeping the executing session open throughout, and by the Hetzner Cloud Console being a confirmed out-of-band recovery path.
- **HIGH — this plan revokes SSH access for two real operators (`viktor_d`, `binali_r`) per explicit user instruction.** Unchanged from the prior attempt's framing — carried forward, already user-approved once, re-confirmed live and unchanged by attempt 3's Phase 0 run.
- **MEDIUM — replacing `T-0087`'s `40-ssh-hardening.conf` changes the effective `MaxAuthTries` (6→3) and `LoginGraceTime` (120→30) to the older, stricter fleet values, and drops the post-quantum `KexAlgorithms` entries that `T-0087` had included but the fleet pattern does not.** Unchanged from the prior attempt's framing. If the user considers `T-0087`'s posture the more current/deliberate one, the better fix is a follow-on task to *upgrade* the fleet pattern (T-0093/T-0102) to add PQ KEX, not to drop it here.
- **MEDIUM — `viktor_d`/`binali_r` lockout has no external verification path.** Unchanged — structural limitation, not a plan defect.
- **MEDIUM — the undocumented changes are a process gap, not merely landscape staleness, and there are now two of them (sshd/accounts, and firewall) instead of one, both on the same host, both dated 2026-06-27.** Addressed by `T-0135`'s expanded scope (see Resources used). Whether they share a common cause is explicitly left as an open question for `T-0135`'s investigation, not assumed here.
- **LOW/INFORMATIONAL — `POST .../actions/set_rules` body shape is inferred from a prior successful use in this repo (`runs/2026-06-27-apply-hetzner-firewall-001`), not newly speculative.** If the API rejects the body with a 4xx, the executor must capture the error verbatim and treat it as a `FAIL` requiring redesign, not an improvised retry.
- **LOW — Docker/UFW `after.rules` decision is conditional, not guaranteed.** Falls back to a discovery step before writing any `after.rules` content if the live egress test fails.
- **LOW — proposed `role: letflow-app` value is a designer's proposal, not dictated by any input file.** Low-cost to change at step 08 if flagged during this approval.
- **INFORMATIONAL — this design assumes the user's "leave it open to anywhere" instruction applies specifically to the Hetzner Cloud Firewall's port-22 rule (the subject of the halt that prompted the question), not as a broader statement about SSH exposure policy in general.** If the user intended something broader (e.g., also wants UFW's existing unrestricted port-22 rule reviewed, or wants this posture applied/reviewed fleet-wide on the other two hosts), that is out of scope for T-0134 and would need its own task — flagged here so the user can correct the scope if this reading is too narrow.
- **INFORMATIONAL — this plan re-runs Phase 0 (0.0-0.7) in full rather than resuming from 0.6, per this repo's live-reconfirmation discipline and given three separate drift discoveries have already occurred in this run.** If Phase 0's fresh re-check finds anything different from what attempt 3 found (including the firewall rule itself changing yet again), the plan's own STOP instructions apply and this would require a further revision.
- **INFORMATIONAL — this plan does not touch `shared/app-registry.md`, Cloudflare DNS, or nginx.** Correctly out of scope per T-0134's own "Why" section.

## Open questions (optional)

None — this design is not `BLOCKED`. The user's decision on the one open question that halted attempt 3 (port 22 CIDR) has already been given and is incorporated above. The remaining items above are flagged for the user's approval-gate review (per `NEEDS_APPROVAL`), not information gaps that prevent the plan from being written.
