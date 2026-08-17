---
run_id: 2026-08-17-prepare-letflow-host-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-17T04:26:02Z
task_id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
retry_of: step-04
inputs_read:
  - runs/2026-08-17-prepare-letflow-host-001/step-01-task-reader.md
  - runs/2026-08-17-prepare-letflow-host-001/step-02-landscape-reader.md
  - runs/2026-08-17-prepare-letflow-host-001/step-03-task-validator.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-08-17-prepare-letflow-host-001/step-05-user-approval.md
  - runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md
  - runs/2026-08-17-prepare-letflow-host-001/.attempts/step-06-executor-infra.attempt1.md
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
next_step_hint: This is a re-plan superseding the archived attempt-1 design (which was approved and then FAILed at executor step 06 twice — once on a workstation SSH-alias defect, once on live-state contradicting the plan's sshd assumptions). Orchestrator must re-run the full approval gate: present this plan fresh, do NOT reuse the prior step-05 APPROVED verdict (per shared/verdicts.md and shared/approval-protocol.md, each design revision requires its own approval — the substance changed materially: account lockout added, sshd Phase 3 rewritten, a new T-0135 observation task will be created at step 08). If APPROVED, advance to executor-infra with this file plus the new step-05 as inputs. Executor MUST re-run Phase 0 live-state checks in full before touching anything, since the host state may have drifted again since this design was written.
---

## Summary

Revised plan to bring `ubuntu-16gb-nbg1-1` (46.225.239.60, Hetzner project "ai-qadam", server id `145542849`) from its true live state — Docker absent, Hetzner Cloud Firewall allowing only TCP 22, and sshd **already partially hardened by an undocumented prior action (`T-0087`, 2026-06-27)** with `AllowUsers tvolodi viktor_d binali_r` and two real sudo-capable operator accounts (`viktor_d`, `binali_r`) that the original plan and the landscape file's "clean slate" claim did not account for — to a Docker-ready, firewall-opened (80/443 world-open at the Hetzner Cloud Firewall layer), fleet-consistent sshd-hardened (`AllowGroups sshusers`) application host, with `viktor_d` and `binali_r` **locked out but not deleted** per the user's explicit decision ("remove for now... will not participate for a while"), in five ordered phases — live-state reconfirmation, account lockout, sshd hardening reconciliation, Docker install, and the Hetzner Cloud Firewall rule change. End state: only `tvolodi` (and `root`, break-glass) can SSH in; `viktor_d`/`binali_r` accounts and home directories are preserved on disk but cannot authenticate by any method; Docker is functional; 80/443 reachable at the firewall layer with no listener behind them (app deploy stays out of scope); `landscape/hosts/ubuntu-16gb-nbg1-1.md` is corrected to remove the false "clean slate" claim and document `T-0087`; a new observation task `T-0135` is opened to track the undocumented-change process gap.

## Details

### Why this revision exists

Attempt 2 of executor-infra (`runs/2026-08-17-prepare-letflow-host-001/step-06-executor-infra.md`, verdict `FAIL`, `retry_of: step-06`) halted during Phase 0 (before any state-changing command) because live inspection contradicted the approved plan's assumptions:

- `landscape/hosts/ubuntu-16gb-nbg1-1.md` claimed sshd hardening was `⏳` not yet applied and the account list was a "clean slate" of `root`, `nobody`, `tvolodi` only.
- Live state (`sshd -T`, `sshd_config.d/` contents, `id`/`getent passwd`) showed sshd hardening **already applied** on 2026-06-27 by a task/run labeled `T-0087` in the drop-in files' own comment headers (`# Managed by ai-dala-infra. T-0087.`), and two real, provisioned, sudo-capable accounts — `viktor_d` (uid 1001) and `binali_r` (uid 1002), both in the `sudo` group, home directories active as recently as 2026-06-28 — permitted to SSH in via `AllowUsers tvolodi viktor_d binali_r`.
- `T-0087` does not exist anywhere in this repo's `tasks/` or `runs/` trees (confirmed again during this revision: `find tasks -iname '*0087*'` and `find runs -iname '*0087*'` both return nothing).
- The user was asked how to handle `viktor_d`/`binali_r` and replied: **"Remove for now. They will not participate in activities for a while. Our prod system on other host now."** — read as: revoke access now, but keep it reversible, since "for now"/"for a while" signals this is not a permanent deprovisioning decision.

Notably, `tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md` (done, closed 2026-07-11) shows `viktor_d`/`binali_r` are known real operators previously provisioned on `pro-data-tech-prod` with the **exact same naming convention** (`viktor_d@ai-dala-infra-2026-06-27`, `binali_r@ai-dala-infra-2026-06-27` — same date as `ubuntu-16gb-nbg1-1`'s undocumented `T-0087`). This strongly suggests `T-0087` mirrored the T-0105 operator-provisioning pattern onto this second host as part of the same 2026-06-27 provisioning burst, just never folded into this repo. This is corroborating context, not proof — still flagged as a process gap requiring its own task (`T-0135` below), not silently absorbed into T-0134's scope.

### Five design decisions made explicit

**(a) Account disposition for `viktor_d`/`binali_r` — lock, do not delete.**
The user's phrasing ("for now", "will not participate... for a while") is explicitly reversible language, not a deprovisioning order. Per the design brief's own guidance, ambiguity here favors a reversible measure over `userdel -r` (which would delete home directories — `/home/viktor_d` and `/home/binali_r`, 4-6 items each per the executor's `ls -la /home/` finding — and cannot be undone without re-provisioning from scratch, including new SSH keys since neither user's public key is recorded anywhere in this repo's `secrets-inventory.md`). **Decision: lock, don't delete.** Concretely:
- Remove both from the SSH allow-list (they will not appear in the new `AllowGroups sshusers` membership — see Phase 2).
- Expire both accounts (`usermod -e 1`, i.e. account expiration date of 1970-01-02 — the standard "disable login" idiom, blocks all login methods including any key that might still be trusted, independent of the `AllowGroups` mechanism — defense in depth).
- Lock both passwords (`usermod -L`) — belt-and-braces; password auth is already globally disabled host-wide (`PasswordAuthentication no`), so this has no practical effect today but costs nothing and matches convention.
- Leave home directories, UIDs, group memberships (`sudo`, own primary group), and all files untouched.
- Reversal path (documented, not executed by this plan): `sudo usermod -e "" viktor_d && sudo usermod -U viktor_d && sudo usermod -aG sshusers viktor_d` (same for `binali_r`) — restores login capability without re-provisioning. This path is recorded here for future reference; it is intentionally not part of this plan's rollback (rollback undoes *this plan's own* changes if something fails mid-execution, not a future business decision to re-enable these operators).

**(b) sshd hardening reconciliation — replace `T-0087`'s access-control drop-in, keep the password-auth drop-in.**
`40-disable-password.conf` (from `T-0087`) is byte-identical to what this plan would write — reused as-is (rewritten idempotently in Phase 3, harmless no-op if unchanged). `40-ssh-hardening.conf` (from `T-0087`) diverges from the T-0093/T-0102 fleet pattern in `MaxAuthTries` (6 vs. fleet's 3), `LoginGraceTime` (120 vs. fleet's 30), `KexAlgorithms` (includes post-quantum `mlkem768x25519-sha256`/`sntrup761x25519-sha512` variants, absent from the fleet pattern), and uses `AllowUsers` instead of `AllowGroups`. None of these divergences are documented as a deliberate, newer security posture anywhere in this repo — they are simply what an unrecorded action happened to write, and `T-0134`'s own acceptance criteria explicitly call for "parity with T-0093/T-0102's precedent." **Decision: fully replace `40-ssh-hardening.conf` with the fleet-standard `40-ai-dala-infra.conf` file** (same name and content as T-0093/T-0102), and delete the old `40-ssh-hardening.conf` (after backup) so there is exactly one project-managed access-control drop-in, not two overlapping ones. The post-quantum KexAlgorithms addition is flagged in Issues/risks as something the user may want adopted fleet-wide in a separate follow-on — not silently discarded, but not adopted here either, since T-0134 asks for parity with the *existing* fleet pattern, not a new one.

Critical adaptation: `root` cannot SSH in on this host (`/root/.ssh/` is empty per the landscape file, unchanged fact). The only functioning SSH identity going forward is `tvolodi`. **Decision: `sshusers` group contains `tvolodi` and `root`** (root harmless/break-glass-only, same rationale as attempt 1) — **`viktor_d` and `binali_r` are deliberately excluded** per decision (a).

**(c) Account lockout must happen BEFORE the new `AllowGroups sshusers` config is written and reloaded — explicit ordering, not incidental.**
This is the change from attempt 1 that directly addresses why it failed: the ordering must make the removal of `viktor_d`/`binali_r`'s access an intentional, reviewable, separately-verified step, not a side effect of who happens to be in a group. Phase 1 (account lockout) runs first and is independently verified (their accounts show `expired`/no shell access) before Phase 2 (sshd hardening) even begins. This also means the lockout takes effect immediately via `usermod -e 1` — independent of and prior to any sshd config change — so there is no window where the outcome depends on drop-in file precedence or reload timing.

**(d) Docker/UFW `after.rules` DOCKER-USER append — unchanged from attempt 1's decision: not applied proactively, live-tested and conditionally deferred.**
Nothing in the FAIL findings touches this area (0.4's Docker-absence check was confirmed clean in attempt 2 before the halt). Carried forward verbatim from the original design: `ubuntu-16gb-nbg1-1`'s UFW `DEFAULT_FORWARD_POLICY` is already `ACCEPT` (set 2026-06-27 "for Docker parity"), so Phase 4 includes a live container-egress test; the `after.rules` fallback is fully specified but conditional.

**(e) Hetzner Cloud Firewall 80/443 source CIDR — unchanged from attempt 1's decision: `0.0.0.0/0` and `::/0` (world-open).**
Nothing in the FAIL findings touches this area (Phase 2/firewall was never reached in either attempt). Carried forward verbatim: this host will carry public Letflow web traffic per T-0134's own "Why" section; the existing host-level UFW rule for 80/443 is already world-open. Still flagged in Issues/risks for the user to object to if a narrower CIDR was actually intended — this is the user's second opportunity to weigh in on this specific inference, since it was never explicitly confirmed or denied in the "approve" reply to attempt 1's plan (that approval covered a plan that never reached this phase in execution).

**(f) `secrets-inventory.md` and new observation task `T-0135`.**
Same two documentation-only additions as attempt 1 (SSH key fingerprint, Hetzner API token — both already in use, no new secret introduced). Additionally, this revision adds: a new observation task `T-0135` (next available task number — confirmed via `tasks/_index.md`, highest existing is `T-0134`) to track the undocumented `T-0087` change as a landscape/process discrepancy: an sshd-hardening change and two operator-account provisions were made to a managed host outside this repo's workflow, with no task or run record, discovered only by live executor inspection. This is flagged for investigation (who/what ran it, why no record exists, whether other undocumented changes exist on this or other hosts) — not silently absorbed into T-0134, which is scoped to Letflow host prep, not process auditing.

---

### Pre-execution requirement

All host-side commands run over a single persistent SSH session opened before any changes, using the existing config alias: `ssh ubuntu-16gb-nbg1-1` (management workstation `C:\Users\tvolo\.ssh\config`, key `C:\Users\tvolo\.ssh\ai-dala-infra`, user `tvolodi`).

**Carried-forward blocker note from attempt 1:** attempt 1 of executor-infra failed because this alias was found missing from the live `C:\Users\tvolo\.ssh\config` (present as of a 2026-06-27 backup, absent as of a 2026-08-15 out-of-band edit). Attempt 2 succeeded in reaching the host (`whoami` returned `tvolodi`), so the alias has evidently been restored or was otherwise reachable by the time attempt 2 ran. **Step 0.0 below re-verifies this explicitly before anything else**, since this design cannot assume the workstation environment is stable between runs.

The session must stay open through Phase 3 (sshd hardening) so a live rollback path exists if a hard gate fails.

All Hetzner Cloud API calls use the existing PowerShell helper pattern from `runs/2026-06-27-apply-hetzner-firewall-001/executor-02-helpers.ps1` (token loaded from disk into a local variable, never echoed, never written to a file): token file `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, secret name `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`.

---

### Phase 0 — Live-state reconfirmation (read-only)

**0.0 — SSH alias reachability (addresses attempt 1's blocker).** Command: `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; whoami"` — Verification: `===OK===` banner, `whoami` returns `tvolodi`. If this fails with a resolution error, STOP — do not attempt an ad hoc alternate invocation (per executor rule against improvising past a wrong/missing step); report to the user that the workstation SSH alias needs attention before this plan can run.

**0.1 — Current sshd effective config (re-check; must match attempt 2's findings or this design is stale again).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries|logingracetime|allowusers|allowgroups) '"` — Verification: expected (per attempt 2's live findings) `permitrootlogin no`, `passwordauthentication no`, `kbdinteractiveauthentication no`, `maxauthtries 6`, `logingracetime 120`, no `allowgroups` line. If this deviates from what is documented here, STOP and escalate — do not proceed on stale assumptions a second time.

**0.2 — Current sshd_config.d contents (re-check).** Command: `ssh ubuntu-16gb-nbg1-1 "ls -la /etc/ssh/sshd_config.d/; cat /etc/ssh/sshd_config.d/40-disable-password.conf; cat /etc/ssh/sshd_config.d/40-ssh-hardening.conf"` — Verification: `40-disable-password.conf` contains `PasswordAuthentication no` / `KbdInteractiveAuthentication no`; `40-ssh-hardening.conf` contains `AllowUsers tvolodi viktor_d binali_r` among its directives (per attempt 2's findings). If `40-ssh-hardening.conf` is absent or its `AllowUsers` line no longer lists exactly these three users, STOP and escalate — the live state has changed again since this design was written and Phase 2 below must not proceed on a stale assumption.

**0.3 — Current account state for `viktor_d`/`binali_r` (re-check + pre-change snapshot for rollback).** Command: `ssh ubuntu-16gb-nbg1-1 "id viktor_d; id binali_r; sudo chage -l viktor_d; sudo chage -l binali_r; sudo passwd -S viktor_d; sudo passwd -S binali_r"` — Verification: both accounts exist, uid 1001/1002, groups include `sudo`; capture full `chage -l` and `passwd -S` output verbatim into `runs/2026-08-17-prepare-letflow-host-001/step-0-3-accounts-baseline.txt` — **this is the pre-change backup/snapshot for Phase 1's rollback** (records each account's exact pre-lockout expiration date and password-lock state so Phase 1's rollback can restore precisely, not just "unlock").

**0.4 — Current UFW / after.rules state.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo ufw status verbose; echo ---; sudo cat /etc/ufw/after.rules"` — Verification: `DEFAULT_FORWARD_POLICY` reads `ACCEPT`-configured; `after.rules` contains no pre-existing `DOCKER-USER` or `T-0134` marker (idempotency guard for Phase 4's conditional fallback).

**0.5 — Docker absence check.** Command: `ssh ubuntu-16gb-nbg1-1 "dpkg -l docker-ce 2>/dev/null | grep '^ii' || echo NOT_INSTALLED"` — Verification: `NOT_INSTALLED` (matches attempt 2's finding). If Docker is already installed, skip Phase 4's install sub-steps and run only its verification sub-steps.

**0.6 — Current Hetzner Cloud Firewall rule set (live, not from the landscape doc — also the pre-change backup/snapshot for Phase 5's rollback).** Command: `GET https://api.hetzner.cloud/v1/firewalls/11204449` — Verification: HTTP 200; exactly one rule (`tcp/22` from `178.89.57.135/32`); save response to `runs/2026-08-17-prepare-letflow-host-001/step-0-6-firewall-baseline.json`. Use the exact `source_ips`/`description` values from this live response when constructing Phase 5's `set_rules` body.

**0.7 — Baseline external TCP-reachability probe for 80/443 (pre-change signature, for step 07's dual-probe comparison).** Commands, from the management workstation:
```powershell
Measure-Command { Test-NetConnection 46.225.239.60 -Port 80 } | Select-Object TotalSeconds
Measure-Command { Test-NetConnection 46.225.239.60 -Port 443 } | Select-Object TotalSeconds
```
Verification: expect `TcpTestSucceeded: False` for both, slow/timeout-length completion (Hetzner Cloud Firewall dropping non-allow-listed ports at the cloud edge). Save outputs to `preflight-0-7-tcp80-before.txt` / `preflight-0-7-tcp443-before.txt`.

---

### Phase 1 — Account lockout: `viktor_d` and `binali_r` (per user decision — lock, not delete)

This phase is intentionally first and intentionally separate from the sshd hardening in Phase 2, so the access-revocation decision is explicit and independently verifiable, not an implicit side effect of `AllowGroups` membership.

**1.1 — Expire `viktor_d`'s account (blocks all login methods immediately, independent of sshd config).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -e 1 viktor_d"` — Verification: `sudo chage -l viktor_d` shows `Account expires : Jan 02, 1970` (or equivalent already-expired date).

**1.2 — Expire `binali_r`'s account.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -e 1 binali_r"` — Verification: `sudo chage -l binali_r` shows an already-expired date.

**1.3 — Lock `viktor_d`'s password (defense in depth; password auth is already host-wide disabled).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -L viktor_d"` — Verification: `sudo passwd -S viktor_d` shows `L` (locked) in the status field.

**1.4 — Lock `binali_r`'s password.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -L binali_r"` — Verification: `sudo passwd -S binali_r` shows `L`.

**1.5 — Verify: SSH login attempt as `viktor_d` is rejected (external check, requires a key for that user — if unavailable, verify via account-expiry state instead).** Since no `viktor_d`/`binali_r` private key exists on the management workstation, this cannot be tested end-to-end as an external SSH probe. Verification is instead via on-host state only: `ssh ubuntu-16gb-nbg1-1 "sudo -u viktor_d -i true 2>&1 || echo LOGIN_BLOCKED"` — Verification: output contains `LOGIN_BLOCKED` or an equivalent expired-account/`su`-denial message (exact wording depends on PAM configuration; any denial confirms the account cannot be used interactively). This is a best-effort local proxy for "cannot log in" — noted as a verification limitation, not a gap in the lockout itself (the `chage`/`passwd -S` checks in 1.1–1.4 are the authoritative state checks).

**1.6 — Confirm no other locked-out side effects.** Command: `ssh ubuntu-16gb-nbg1-1 "id viktor_d; id binali_r; ls -la /home/viktor_d /home/binali_r 2>&1 | head -5"` — Verification: both accounts still resolve (uid/gid/groups unchanged — confirms they were not deleted), home directories still present with original ownership and contents untouched.

---

### Phase 2 — sshd hardening reconciliation (replaces `T-0087`'s access-control drop-in with the fleet-standard pattern)

**2.1 — Backup existing sshd config (full directory, before any edit).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo cp -r /etc/ssh /var/backups/pre-T0134.$(date +%Y%m%dT%H%M%SZ)"` — Verification: `ls /var/backups/ | grep pre-T0134` returns a timestamped directory containing `sshd_config`, `sshd_config.d/` (including the `T-0087`-authored `40-ssh-hardening.conf` and its own pre-existing `.bak` file), `50-cloud-init.conf`.

**2.2 — Create `sshusers` group (idempotent).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo groupadd -f sshusers"` — Verification: `getent group sshusers` returns `sshusers:x:<gid>:`.

**2.3 — Add `tvolodi` to `sshusers` (CRITICAL — load-bearing; omitting this locks out the only working SSH identity once `AllowGroups sshusers` is active).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG sshusers tvolodi"` — Verification: `id tvolodi | grep sshusers` exits 0.

**2.4 — Add `root` to `sshusers` (break-glass parity; harmless — root has no installed key, `/root/.ssh/` confirmed empty).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG sshusers root"` — Verification: `id root | grep sshusers` exits 0.

**2.5 — Explicit non-step: `viktor_d` and `binali_r` are NOT added to `sshusers`.** No command — this is the intentional, reviewable omission implementing the user's decision. Verified negatively in 2.13 below (group membership listed and checked to exclude both names).

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

**2.8 — Backup and remove `T-0087`'s superseded `40-ssh-hardening.conf` and its `.bak` sibling (this is the destructive step of this phase — full backup already captured in 2.1 before this runs).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo mv /etc/ssh/sshd_config.d/40-ssh-hardening.conf /var/backups/pre-T0134.\$(ls /var/backups/ | grep pre-T0134 | tail -1 | sed 's/pre-T0134\.//')/40-ssh-hardening.conf.removed 2>/dev/null || sudo cp /etc/ssh/sshd_config.d/40-ssh-hardening.conf /var/backups/40-ssh-hardening.conf.removed-T0134 && sudo rm -f /etc/ssh/sshd_config.d/40-ssh-hardening.conf /etc/ssh/sshd_config.d/40-ssh-hardening.conf.bak.20260627T145652Z"` — Verification: `ls /etc/ssh/sshd_config.d/` no longer lists `40-ssh-hardening.conf` or its `.bak` sibling; the pre-move content is recoverable from either the 2.1 full-directory backup or the explicit `/var/backups/40-ssh-hardening.conf.removed-T0134` copy (belt-and-braces — the exact `mv` destination path depends on 2.1's timestamp, so a plain `cp` fallback with a fixed name is included to guarantee a recoverable copy regardless of shell quoting edge cases).

**2.9 — Set permissions.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo chmod 644 /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"` — Verification: `ls -la /etc/ssh/sshd_config.d/` shows both, mode `-rw-r--r--`, owner `root root`.

**2.10 — HARD GATE: `sshd -t`.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -t"` — Verification: exit 0, no error output. **If non-zero: ABORT, do not proceed to 2.11/2.12, execute Rollback Scenario A immediately.**

**2.11 — HARD GATE: confirm `tvolodi` is in `sshusers` before reload.** Command: `ssh ubuntu-16gb-nbg1-1 "id tvolodi | grep sshusers"` — Verification: exit 0, output contains `sshusers`. **If non-zero: ABORT, do not reload, execute Rollback Scenario A immediately.**

**2.12 — HARD GATE: confirm `viktor_d`/`binali_r` are NOT in `sshusers` (positive confirmation the exclusion took effect as designed, not by accident).** Command: `ssh ubuntu-16gb-nbg1-1 "getent group sshusers | grep -qE 'viktor_d|binali_r' && echo UNEXPECTED_MEMBER || echo EXCLUSION_OK"` — Verification: output is `EXCLUSION_OK`. **If `UNEXPECTED_MEMBER`: ABORT — this would mean 2.5's intended omission did not hold (e.g. a stale group definition from elsewhere); execute Rollback Scenario A and re-investigate before retrying.**

**2.13 — Reload sshd (preserves the active session).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo systemctl reload ssh"` — Verification: `systemctl is-active ssh` → `active`. (Unit is `ssh.service`, not `sshd.service`, per this host's landscape file.)

**2.14 — Verify sshd still running.** Command: `ssh ubuntu-16gb-nbg1-1 "systemctl is-active ssh"` — Verification: `active`.

**2.15 — Verify effective config (full directive set).**
```
ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowusers|allowgroups|kexalgorithms|ciphers|macs|usedns) '"
```
Expected: `permitrootlogin=prohibit-password`, `passwordauthentication=no`, `kbdinteractiveauthentication=no`, `pubkeyauthentication=yes`, `permitemptypasswords=no`, `maxauthtries=3`, `logingracetime=30`, `x11forwarding=no`, `clientaliveinterval=300`, `clientalivecountmax=2`, `allowgroups=sshusers`, **no `allowusers` line at all** (confirms `T-0087`'s `AllowUsers` mechanism is fully superseded, not layered underneath), `kexalgorithms` contains `curve25519-sha256` and no `sha1`, `ciphers` contains `chacha20-poly1305` and no `3des`/`cbc`, `macs` contains `etm@openssh.com` and no `hmac-sha1`, `usedns=no`.

**2.16 — Verify group/membership (exact expected membership — positive AND negative check).** Command: `ssh ubuntu-16gb-nbg1-1 "getent group sshusers"` — Verification: output is exactly `sshusers:x:<gid>:root,tvolodi` (order may vary) — contains `tvolodi` and `root`, does **not** contain `viktor_d` or `binali_r`.

**2.17 — Verify drop-in files + backup + removed-file recoverability.** Commands: `ssh ubuntu-16gb-nbg1-1 "ls -la /etc/ssh/sshd_config.d/; cat /etc/ssh/sshd_config.d/40-disable-password.conf; cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf; ls /var/backups/ | grep -E 'pre-T0134|40-ssh-hardening'"` — Verification: `sshd_config.d/` contains exactly `40-disable-password.conf`, `40-ai-dala-infra.conf`, `50-cloud-init.conf` (no `40-ssh-hardening.conf*` remaining); both project files present with correct content and mode; `50-cloud-init.conf` unchanged; backup directory and the removed-file copy both exist.

**2.18 — External check: fresh SSH connection (new session, not the held-open one) confirms key auth still works post-hardening.** Command (from management workstation, a second/new terminal): `ssh ubuntu-16gb-nbg1-1 "whoami; id | grep sshusers"` — Verification: connects successfully, output contains `tvolodi` and `sshusers`.

**2.19 — External check: password auth is rejected.** Command: `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes ubuntu-16gb-nbg1-1 exit` — Verification: fails with `Permission denied (publickey)`.

---

### Phase 3 — Docker Engine + Compose plugin install

Unchanged from attempt 1's design (its assumptions here were never contradicted by either FAIL). Mirrors T-0106 (`pro-data-tech-prod`).

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

### Phase 4 — Hetzner Cloud Firewall: allow inbound TCP 80/443

Unchanged from attempt 1's design (never reached by either prior attempt; assumptions unchallenged).

**Reuse decision:** reuse firewall `ai-qadam-mgmt-ssh` (id `11204449`) via `set_rules`, rather than creating a second firewall.

**4.1 — Construct the full replacement rule set (uses 0.6's live values, not the landscape doc's copy).**
```json
{
  "rules": [
    {
      "direction": "in",
      "protocol": "tcp",
      "port": "22",
      "source_ips": ["178.89.57.135/32"],
      "description": "SSH from management workstation"
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
The `port: "22"` entry's `source_ips`/`description` MUST be copied verbatim from Phase 0.6's live `GET` response.

**4.2 — Apply.** Command: `POST https://api.hetzner.cloud/v1/firewalls/11204449/actions/set_rules` with the body above, `Content-Type: application/json`, `Authorization: Bearer <hetzner-api-token:ai-dala-infra:ai-qadam-read-write>`. Verification: HTTP 201 with an `actions` array; poll `GET /v1/firewalls/11204449/actions/<action_id>` every 2s (max 30s) until `status: "success"`.

**4.3 — Post-apply verification.** Command: `GET https://api.hetzner.cloud/v1/firewalls/11204449` — Verification: `rules` array contains exactly 3 entries matching 4.1; `applied_to` still contains server `145542849`.

**4.4 — Post-apply external TCP-reachability probe (dual-signature comparison against 0.7).**
```powershell
Measure-Command { Test-NetConnection 46.225.239.60 -Port 80 } | Select-Object TotalSeconds
Measure-Command { Test-NetConnection 46.225.239.60 -Port 443 } | Select-Object TotalSeconds
```
Expected change from 0.7's baseline: `TcpTestSucceeded: False` for both (unchanged — no listener, by design), but completion is now **fast** (immediate TCP RST — packet now clears the Hetzner Cloud Firewall and UFW, finds no listener), versus 0.7's **slow/timeout** completion. Also spot-check SSH: `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True`.

**4.5 — Functional SSH still works (regression check).** Command: `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw"` — Verification: `===OK===`, both `active`.

---

### Rollback

**Phase 1 (account lockout) rollback** — if execution must be aborted after Phase 1 but the accounts need restoring to their exact pre-lockout state:
1. Restore exact pre-lockout expiration from `step-0-3-accounts-baseline.txt`: `sudo usermod -e "<original-expiry-or-empty>" viktor_d` (and `binali_r`).
2. Restore exact pre-lockout password-lock state from the same file: if `passwd -S` showed unlocked (`P` or `NP`), run `sudo usermod -U viktor_d` (and `binali_r`); if it showed already-locked, no action needed.
3. Verify: `sudo chage -l viktor_d; sudo passwd -S viktor_d` (and `binali_r`) match the 0.3 baseline file exactly.
Fully reversible — no data was touched, only account metadata, and the exact pre-change values were captured in 0.3.

**Phase 2 (sshd) rollback:**

*Scenario A — before reload (2.10, 2.11, or 2.12 gate fired):*
1. `sudo rm -f /etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (the new file; `40-disable-password.conf` is unchanged/idempotent, left in place).
2. If 2.8 already ran (removed `40-ssh-hardening.conf`): restore it — `sudo cp /var/backups/40-ssh-hardening.conf.removed-T0134 /etc/ssh/sshd_config.d/40-ssh-hardening.conf` (and restore its `.bak` sibling from the 2.1 full-directory backup if needed).
3. `sudo sshd -t` — must exit 0.
4. No reload was ever issued; the active session was never disrupted. Host is back to its pre-Phase-2 state (T-0087's original hardening, with `viktor_d`/`binali_r` already locked out by Phase 1, which is NOT rolled back here — Phase 1 and Phase 2 rollbacks are independent).

*Scenario B — after reload, unexpected behavior:*
1. Same file restoration as Scenario A steps 1–2.
2. `sudo sshd -t`
3. `sudo systemctl reload ssh`
4. `systemctl is-active ssh` → `active`.

*Scenario C — catastrophic, full restore from backup:*
1. `sudo cp -r /var/backups/pre-T0134.<timestamp>/ssh/* /etc/ssh/`
2. `sudo sshd -t`
3. `sudo systemctl reload ssh`

**No-rollback-possible note (unchanged severity from attempt 1, still HIGH):** if `tvolodi` (and `root`) were somehow both excluded from `sshusers` at reload time despite gates 2.10/2.11/2.12 passing, and the held-open session also terminates before rollback is applied, the only recovery path is the **Hetzner Cloud Console (KVM-over-IP)**, confirmed available for this host. This risk is structurally unchanged from attempt 1 — the new gate 2.12 adds a check for the *account-exclusion* correctness but does not change the *lockout-if-misconfigured* risk profile for `tvolodi`/`root`.

**Phase 3 (Docker) rollback** — if any step 3.3–3.13 fails or post-install verification fails:
1. `sudo systemctl stop docker.service docker.socket containerd.service`
2. `sudo deluser tvolodi docker` (if 3.9 ran)
3. If 3.13 ran: `sudo cp /var/backups/ufw-after.rules-pre-T0134.bak /etc/ufw/after.rules && sudo ufw reload`
4. `sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && sudo apt-get autoremove -y`
5. `sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/sources.list.d/docker.list`
6. Verify: `sudo ufw status` unchanged; `dpkg -l docker-ce 2>/dev/null | grep -c '^ii'` → `0`.
Fully reversible — no application data exists on this host to lose.

**Phase 4 (Hetzner Firewall) rollback** — if 4.4's post-apply probe shows SSH (port 22) no longer reachable, or `set_rules` returns an error:
1. `POST /v1/firewalls/11204449/actions/set_rules` with the original single-rule body captured in `step-0-6-firewall-baseline.json`.
2. Re-verify: `GET /v1/firewalls/11204449` shows exactly 1 rule; `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True`.
Fully reversible via the same API used to make the change.

---

### Verification (for step 07)

**On-host:**
- Accounts: `viktor_d` and `binali_r` show expired (`chage -l`, expiry in the past) and locked (`passwd -S` shows `L`); both still resolve via `id` (not deleted); home directories `/home/viktor_d`, `/home/binali_r` still present, ownership/contents unchanged from the 0.3/executor-attempt-2 baseline.
- sshd: `sshd -T` shows the full T-0093/T-0102-pattern directive set (see step 2.15); no `allowusers` line present at all; `getent group sshusers` is exactly `tvolodi`+`root`, explicitly excluding `viktor_d`/`binali_r`; `sshd_config.d/` contains exactly `40-disable-password.conf`, `40-ai-dala-infra.conf`, `50-cloud-init.conf` (no leftover `40-ssh-hardening.conf*`); backup directory `/var/backups/pre-T0134.*` exists and contains the original T-0087 files.
- Docker: `dpkg -l docker-ce docker-compose-plugin | grep -c '^ii'` → `2`; `systemctl is-active docker` → `active`; `systemctl is-enabled docker` → `enabled`; `id tvolodi | grep docker`; `sudo docker run hello-world` succeeds; `docker compose version` succeeds.
- Firewall (API-side): `GET /v1/firewalls/11204449` shows 3 rules (22/80/443) and `applied_to` still contains server `145542849`.

**External:**
- TCP-level dual-signature probe: compare `preflight-0-7-tcp{80,443}-before.txt` (slow/timeout) against a post-change re-run of the same `Measure-Command { Test-NetConnection ... }` probes (fast RST).
- SSH: fresh (new-session) connection via `ssh ubuntu-16gb-nbg1-1` succeeds with key auth as `tvolodi`; `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes ubuntu-16gb-nbg1-1 exit` is rejected with `Permission denied (publickey)`.
- Port 22 unaffected throughout: `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True` at every checkpoint.
- No external probe is possible for `viktor_d`/`binali_r` login denial (no key on the management workstation for either identity) — this is a documented verification limitation, covered on-host only (see above).

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
- **Files modified in this repo (`landscape/`) — to be applied at step 08, not by this plan's executor:**
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `role:` frontmatter (proposed value `letflow-app`), `last_verified` refresh, Access section fully rewritten (remove the false "clean slate" claim; document `T-0087`'s prior existence and this plan's reconciliation of it; document `viktor_d`/`binali_r` as present-but-locked, not absent), Hetzner Cloud Firewall section rule-set update, "What needs to happen" item 4 marked done, Docker install recorded, Change log entries for this run AND a retroactive entry acknowledging `T-0087`'s undocumented 2026-06-27 changes.
  - `landscape/services.md` — `## ubuntu-16gb-nbg1-1` section: Docker status flipped to installed, systemd table updated with `docker.service`.
  - `landscape/secrets-inventory.md` — two new documentation-only rows (no values), same as attempt 1:
    - `ai-dala-infra-ssh-key` | ed25519 keypair for SSH access to Hetzner-provisioned hosts in project ai-qadam; public key fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8` | Private key `C:\Users\tvolo\.ssh\ai-dala-infra` on management workstation.
    - `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` | Hetzner Cloud API token, project-scoped read-write, used for Cloud Firewall rule management on project ai-qadam (15130993) | `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` on management workstation.
  - `tasks/T-0135-<slug>.md` (NEW observation task, created at step 08) — tracks the undocumented `T-0087` change: sshd hardening + `viktor_d`/`binali_r` account provisioning applied to `ubuntu-16gb-nbg1-1` on 2026-06-27 with no task or run record in this repo. Notes the corroborating pattern match with `tasks/T-0105-create-operator-users-on-pro-data-tech-prod.md` (same accounts, same date, same key-naming convention) as a plausible but unconfirmed explanation. Added to `tasks/_index.md`.
- **External APIs called:** `api.hetzner.cloud` (Phase 4); `download.docker.com` and `registry-1.docker.io` (Phase 3, package + hello-world image fetch); `api.ipify.org` (Phase 3.12 egress test).

### Estimated impact

- **Downtime:** none for any existing service — this host runs no application workloads yet. `systemctl reload ssh` (SIGHUP) preserves the active session; the Hetzner Cloud Firewall `set_rules` action is applied atomically with no window of total lockout.
- **Affected services:** `sshd` (hardening reconciled — `T-0087`'s `AllowUsers` mechanism replaced with `AllowGroups sshusers`), local account state for `viktor_d`/`binali_r` (expired + locked, not deleted), `docker` (newly installed and started), Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (rule set expanded).
- **Reversibility:** fully reversible for Docker and the firewall (clean removal / API rollback). sshd: drop-in restoration + reload, full `/etc/ssh` backup as last resort, hard gates prevent reloading into a broken/locking config. Account lockout: fully reversible via documented re-enable commands (not executed by this plan) — no data loss, home directories untouched.

## Issues / risks

- **HIGH — sshd lockout risk (Phase 2), same class as attempt 1, now with an added exclusion-correctness gate.** `AllowGroups sshusers` denies all SSH logins to anyone not in that group at reload time. Mitigated by three hard gates (2.10 `sshd -t`, 2.11 `tvolodi` present, 2.12 `viktor_d`/`binali_r` absent) that abort before reload if any fails, by keeping the executing session open throughout, and by the Hetzner Cloud Console being a confirmed out-of-band recovery path. This, plus the task's own declared `medium` blast radius, plus account lockout being an inherently sensitive operation, together drive `NEEDS_APPROVAL`.
- **HIGH — this plan revokes SSH access for two real operators (`viktor_d`, `binali_r`) per explicit user instruction.** This is the primary substantive change from the originally-approved plan and must be re-confirmed by the user, not carried over from the prior "approve" — that approval was given before either the accounts' existence or the lockout decision existed as a plan element. The user's own words ("remove for now... will not participate for a while") are treated here as authorizing lockout, not deletion; if the user meant something stronger (e.g., full `userdel`) or weaker (e.g., a warning first), object now.
- **MEDIUM — replacing `T-0087`'s `40-ssh-hardening.conf` changes the effective `MaxAuthTries` (6→3) and `LoginGraceTime` (120→30) to the older, stricter fleet values, and drops the post-quantum `KexAlgorithms` entries (`mlkem768x25519-sha256`, `sntrup761x25519-sha512[@openssh.com]`) that `T-0087` had included but the fleet pattern does not.** This is a downgrade in one dimension (losing PQ-resistant key exchange) in exchange for fleet consistency in others. If the user considers `T-0087`'s posture the more current/deliberate one, the better fix is a follow-on task to *upgrade* the fleet pattern (T-0093/T-0102's drop-ins on the other two hosts) to add PQ KEX, not to drop it here. Flagged for explicit confirmation — not silently decided.
- **MEDIUM — `viktor_d`/`binali_r` lockout has no external verification path.** Neither user's private key is present on the management workstation, so there is no way to externally confirm "this identity can no longer log in" the way port/SSH probes do for `tvolodi`. Verification relies entirely on on-host account-state checks (`chage`, `passwd -S`, `id`). This is a structural limitation of the lockout approach, not a plan defect, but it means step 07 cannot produce an external/independent confirmation for this specific change.
- **MEDIUM — 80/443 CIDR is still an inference, not a literal instruction (unchanged from attempt 1, never yet exercised or re-confirmed by the user in an execution that actually reached this phase).** `0.0.0.0/0` + `::/0` chosen by analogy with the existing world-open UFW rule and the host's future public-web-traffic purpose.
- **MEDIUM — the undocumented `T-0087` change is a process gap, not merely a landscape staleness issue.** A prior action modified a managed host's security configuration and created two operator accounts without going through this repo's task/workflow/landscape-update discipline at all — not "the doc is 51 days stale" (attempt 1's framing) but "a change happened entirely outside the process this repo exists to enforce." This is addressed by opening `T-0135` (see Resources used) rather than being absorbed silently into T-0134's landscape update. The corroborating match with `T-0105` (same accounts, same date, same key-naming pattern) suggests a plausible innocent explanation (a manual/parallel provisioning pass mirroring T-0105 onto this second host) but this is not confirmed and should not be assumed in `T-0135`'s framing.
- **LOW/INFORMATIONAL — `POST .../actions/set_rules` body shape is inferred, not previously exercised in this repo (unchanged from attempt 1).** If the API rejects the body with a 4xx, the executor must capture the error verbatim and treat it as a `FAIL` requiring redesign, not an improvised retry.
- **LOW — Docker/UFW `after.rules` decision is conditional, not guaranteed (unchanged from attempt 1).** Falls back to a discovery step before writing any `after.rules` content if the live egress test fails.
- **LOW — proposed `role: letflow-app` value is a designer's proposal, not dictated by any input file (unchanged from attempt 1).** Low-cost to change at step 08 if flagged during this approval.
- **INFORMATIONAL — this design assumes attempt 2's live findings (T-0087's drop-in contents, `viktor_d`/`binali_r` account state) are still current.** Phase 0 (0.1–0.3) re-verifies all of them before Phase 1 proceeds; if any deviate, execution must stop and escalate rather than proceed on a third stale assumption.
- **INFORMATIONAL — this plan does not touch `shared/app-registry.md`, Cloudflare DNS, or nginx.** Correctly out of scope per T-0134's own "Why" section; called out to confirm the boundary was respected.

## Open questions (optional)

None — this design is not `BLOCKED`. The items above are flagged for the user's approval-gate review (per `NEEDS_APPROVAL`), not information gaps that prevent the plan from being written. The one genuine unresolved fact (who/what produced `T-0087`) is deliberately routed to a new investigation task (`T-0135`) rather than blocking this plan, since T-0134's own scope (Letflow host prep) does not require that question answered first — only that its consequences (existing hardening, existing accounts) are correctly reconciled, which this plan does.
