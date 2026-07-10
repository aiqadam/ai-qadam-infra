---
run_id: 2026-06-27-discovery-host-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-06-27T05:25:00Z
inputs_read:
  - workflows/discovery-host.md
  - runs/2026-06-27-discovery-host-001/step-06-executor-discovery.md
  - runs/2026-06-27-discovery-host-001/step-02-landscape-reader.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Pass to landscape-updater (step 08). Findings list reconciles; F4 (sudoers drop-in drift) and F19 (host fingerprints now present) are the only intentional non-trivial stub updates.
retry_of: ~
---

## Summary

Discovery-host run verified independently. Every workflow validation criterion (`workflows/discovery-host.md` § "Validation criteria for step 07") holds: probe A returned `SUDO_OK`, all probe sections A–N plus the supplementary A.1 produced output entries, no side effects were reported, and the findings summary references every probe by letter. Six spot-checks re-run live against `ubuntu-16gb-nbg1-1` reconcile exactly with the executor's reported output. The single drift (F4 — `/etc/sudoers.d/90-tvolodi` already present at mtime 2026-06-27 04:46, contrary to stub "What needs to happen" item #4) was correctly surfaced, not silently "fixed". `artifacts_changed` is empty — read-only run honored.

## Details

### Workflow validation criteria (per workflows/discovery-host.md § "Validation criteria for step 07")

| Criterion (from workflow) | Observation in executor handoff | Pass |
|---|---|---|
| Pre-execution probe A reported `SUDO_OK` | "Probe A output" block in step-06 prints `SUDO_OK`; exit 0 on `sudo -n true` | yes |
| Every probe section A–N has an output entry | Sections A, B, C, D, E, F, G, H, I, J, K, L, M, N all present in "Probe log"; supplementary A.1 also present | yes |
| No probe reported a side effect | Each probe section ends with `Side effects observed: none.` | yes |
| Findings summary references each probe by letter | F1↔B, F2↔C, F3↔D, F4↔D, F5↔D, F6↔D+A.1, F7↔D, F8↔E, F9↔E, F10↔F, F11↔G, F12↔H, F13↔I, F14↔J, F15↔K, F16↔L, F17↔M, F18↔N, F19↔A.1 — every probe letter is referenced | yes |

### Spot-check: live re-run of selected probes

Re-executed from the management workstation via `ssh ubuntu-16gb-nbg1-1` to independently confirm the executor's reported output.

### Live verification checks

| Check (from executor findings) | Command run | Result | Pass |
|---|---|---|---|
| Probe A — identity + SUDO_OK | `ssh ubuntu-16gb-nbg1-1 'whoami && id && hostname && sudo -n true && echo SUDO_OK'` | `tvolodi\nuid=1000(tvolodi) gid=1000(tvolodi) groups=1000(tvolodi),27(sudo),100(users)\nubuntu-16gb-nbg1-1\nSUDO_OK` (exit 0) | yes |
| Probe B — OS release & kernel | `ssh ubuntu-16gb-nbg1-1 'cat /etc/os-release && uname -a && lsb_release -a 2>/dev/null'` | `PRETTY_NAME="Ubuntu 26.04 LTS"` / `VERSION_ID="26.04"` / `VERSION_CODENAME=resolute`; `Linux ubuntu-16gb-nbg1-1 7.0.0-22-generic #22-Ubuntu SMP PREEMPT_DYNAMIC Mon May 25 15:54:34 UTC 2026 x86_64 GNU/Linux` — exact match | yes |
| Probe C — hardware | `ssh ubuntu-16gb-nbg1-1 'nproc && free -h && df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs'` | `nproc=8`; `Mem: total 15Gi, used 570Mi, free 14Gi`; `df: /dev/sda1 150G /dev/sda15 253M` — matches (memory `used` drift 536Mi→570Mi is expected live counter advance, not a discrepancy) | yes |
| Probe A.1 — SSH host key fingerprints | `ssh ubuntu-16gb-nbg1-1 'sudo ssh-keygen -l -f /etc/ssh/ssh_host_{rsa,ecdsa,ed25519}_key'` | RSA `SHA256:pNGyU7GiFCZ0QNqi9myVa8TB7dN0mrLzQqWCDuMdtls`; ECDSA `SHA256:0OuNLbfFiqFCJd54IGcPTWlBNKw3KpoRMGqQBN353fs`; ED25519 `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4` — all three match executor output exactly | yes |
| Probe H — Docker absence | `ssh ubuntu-16gb-nbg1-1 'which docker; docker --version 2>&1; sudo docker ps -a 2>&1 \| head -5'` | `bash: line 1: docker: command not found` + `sudo: 'docker': command not found` — Docker not installed, matches | yes |
| Drift F4 — sudoers drop-in existence | `ssh ubuntu-16gb-nbg1-1 'sudo ls -la /etc/sudoers.d/ 2>&1'` | `-r--r----- 1 root root 31 Jun 27 04:46 90-tvolodi` — drop-in present with mtime 2026-06-27 04:46, exactly matching F4 claim | yes |

### Live verification — supplementary checks (for F4 detail)

| Check | Command run | Result | Pass |
|---|---|---|---|
| F4 — drop-in contents | `sudo cat /etc/sudoers.d/90-tvolodi` | `tvolodi ALL=(ALL) NOPASSWD:ALL` (matches F4 content claim) | yes |
| F4 — drop-in metadata | `sudo stat /etc/sudoers.d/90-tvolodi` | mode `0440`, owner `root:root`, Modify `2026-06-27 04:46:14`, Birth `2026-06-27 04:46:14` — mtime matches executor's "2026-06-27 04:46" | yes |

### Drift surfacing (F4)

The executor correctly flagged that `/etc/sudoers.d/90-tvolodi` already exists at mtime `2026-06-27 04:46` (during cloud-init bootstrap), contradicting the stub's "What needs to happen" item #4 ("Project-managed sudoers drop-in… should be created later for parity with `hetzner-prod`"). The stub body item #4 should be marked **done** at step 08.

The executor also correctly:
- Did NOT silently "fix" the stub (`landscape/hosts/ubuntu-16gb-nbg1-1.md` is unchanged after step 06 — file mtime/state still as last manual edit).
- Surfaced the drift as a finding (F4) with enough detail for step 08 to act on it.
- Preserved the stub's "Access" section claim that `/etc/sudoers.d/` is "empty at first contact" as **wrong** (now flagged), rather than parroting the drift forward.

### Other probes (not re-run live — relied on executor output)

Probes E (sshd), F (firewall), G (listeners), I (nginx), J (systemd), K (timers), L (apt), M (security tools), N (backups) were not re-run live for this validation pass. They are covered indirectly by:
- Probe B confirms SSH daemon is up and accepting the connection used to land Probe A.
- Probe H's `command not found` result is consistent with Probe F's "iptables all chains ACCEPT" (no docker-proxy, no postgres, no redis-bypass).
- The host's responsiveness and Cloud-init completion are consistent with Probe J's claim of standard Ubuntu 26.04 cloud image units.
- The lack of any `app-backup.timer`, certbot timer, or restic/borg/duplicity is consistent with the stub's "empty at first contact" framing and with probe H's "no docker" finding.

A future state-changing run (UFW / sshd hardening) will re-probe F, G, E anyway as part of its own validation block; I did not duplicate that work in this read-only validation step.

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| (empty list — read-only run) | `runs/2026-06-27-discovery-host-001/` contains only step-01 through step-06 files; `landscape/hosts/ubuntu-16gb-nbg1-1.md` is still in stub state with the last change log row dated 2026-06-27 (manual verification) | yes |

No state changed anywhere as a result of this discovery run. The read-only contract was honored.

## Issues / risks

- None introduced by this validation step. All findings, drift items, and open questions in the executor's handoff stand as written.
- The executor's documented minor cosmetic artifact in probe D (`bash: line 37: syntax error: unexpected end of file from \`if' command on line 31`) is noted in step-06 Open questions. The actual data captured before the error is what was validated here; no impact on findings.

## Open questions (optional)

- (For step 08 landscape-updater) When populating `landscape/hosts/ubuntu-16gb-nbg1-1.md`, the "Access" section's bullet about `/etc/sudoers.d/` being "empty at first contact" must be **replaced** with the F4 fact (drop-in present at mtime 2026-06-27 04:46), not appended. The stub body item #4 in "What needs to happen" must be flipped to ✅ done, and the explanatory note about cloud-init default should be removed (or amended to "also has cloud-init default at `/etc/sudoers.d/90-cloud-init-users`").
- (For step 08 landscape-updater) All three host fingerprints from F19 should be written into the "Access" section in the same `SHA256:...` format that `landscape/hosts/hetzner-prod.md` uses for its recorded fingerprints. Do not echo the actual public key material.
- (For step 08 landscape-updater) The ED25519 fingerprint recorded on the management workstation's `known_hosts` (added via `StrictHostKeyChecking=accept-new`) should be reconciled against `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`. Step 08 should add the RSA and ECDSA fingerprints to `known_hosts` (using a one-shot `ssh-keyscan -t rsa,ecdsa ubuntu-16gb-nbg1-1` with a `KexAlgorithms` workaround, or by editing the file directly with the verified values from F19). If the existing ED25519 entry does NOT match the F19 fingerprint, that is a serious problem (MITM or server re-key) and step 08 should emit `BLOCKED` rather than overwrite blindly.
- (For step 08 landscape-updater) The executor's open question about whether `host_id: ubuntu-16gb-nbg1-1` should be renamed to a short canonical `hetzner-2` was raised in T-0082's "Notes". Step 08 should NOT change it unilaterally — leave a note in the host file's "Open questions" body and surface to the user.
- (For the user, post-run) F4 is a concrete action item: once the populated stub is reviewed, item #4 of "What needs to happen" can be permanently retired (it was already done at bootstrap; the stub just didn't know). Items #2 (Hetzner Cloud Firewall audit) and #3 (UFW) and #8 (sshd hardening) remain open; they are independent of role assignment and could be picked up in a single follow-on hardening workflow.