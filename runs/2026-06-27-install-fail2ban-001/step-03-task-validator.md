---
run_id: 2026-06-27-install-fail2ban-001
step: "03"
agent: task-validator
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-install-fail2ban-001/step-01-task-reader.md
  - runs/2026-06-27-install-fail2ban-001/step-02-landscape-reader.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-05-12-install-fail2ban-001/step-03-task-validator.md
  - tasks/T-0005-install-fail2ban.md
  - tasks/T-0084-install-fail2ban-on-ubuntu-16gb-nbg1-1.md
  - runs/2026-06-27-configure-ufw-001/step-02-landscape-reader.md
  - runs/2026-06-27-discovery-host-001/step-02-landscape-reader.md
artifacts_changed: []
next_step_hint: solution-designer — design the fail2ban install + sshd jail config; condition banaction selection on the live iptables-backend probe; design a "confirm workstation IP" gate before writing the jail file (task forbids hardcoding 5.250.151.158); include the post-install `iptables -L -n` (or `nft list ruleset`) coexistence sanity check with UFW.
---

## Summary

Task T-0084 is valid, well-formed, not already done, and free of landscape conflicts; all six validation checks pass. The task is ready for solution design. This is a near-parallel of the prior T-0005 (fail2ban install on `hetzner-prod`) — same shape, same blast radius, same reversibility profile — adapted to a fresh Ubuntu 26.04 host whose only material difference from prod is the OS major version (and the consequent apt + iptables-backend unknowns, which the executor owns to probe).

## Details

### Validation results

1. **Well-formed: PASS** — T-0084 names six concrete, verifiable acceptance criteria:
   - `fail2ban` package installed via apt (verifiable with `dpkg -l fail2ban`).
   - `/etc/fail2ban/jail.d/sshd.local` exists with quantified parameters: `maxretry=3`, `bantime=600s`, `findtime=600s`, `ignoreip` including verified workstation IP (verifiable with `cat /etc/fail2ban/jail.d/sshd.local`).
   - `systemctl status fail2ban` shows `Active: active (running)` (verifiable with `systemctl is-active fail2ban`).
   - `fail2ban-client status sshd` shows `Currently failed:` / `Currently banned:` fields (verifiable with the literal command).
   - Management workstation IP confirmed via `curl https://ifconfig.me` BEFORE writing to `ignoreip` (verifiable by reading the executor's run log; the explicit "verify before write" gate is itself the check).
   - `landscape/hosts/ubuntu-16gb-nbg1-1.md` security tools section updated (verifiable at step 08).
   Every criterion is checkable with a specific command or file diff. No vague intent.

2. **In-scope: PASS** — Per `workflows/infrastructure.md` ("When this workflow applies"): "OS package install/upgrade, systemd unit changes" and "New tool installation or removal on managed hosts" both apply. Installing fail2ban (apt package) + enabling `fail2ban.service` (systemd unit) on `ubuntu-16gb-nbg1-1` (a managed host listed in `landscape/hosts/`) is squarely within scope. No re-routing to `workflows/cicd.md` is warranted — there is no application code or pipeline involvement.

3. **Not already done: PASS** — `landscape/hosts/ubuntu-16gb-nbg1-1.md` (populated today, `last_verified: 2026-06-27`) states verbatim under SSH hardening tooling: **"fail2ban not installed"**. The discovery run `2026-06-27-discovery-host-001` (probe H) confirmed this. The T-0084 task frontmatter `executed_by_runs:` lists only `2026-06-27-install-fail2ban-001` (the current run, in-progress). No no-op risk. The reference task T-0005 (closed done 2026-05-12) covers the same install on `hetzner-prod` only — it does not make T-0084 redundant because the two hosts are physically distinct machines.

4. **No conflict with current state: PASS** — Layering analysis vs. T-0083 (UFW):
   - UFW is active on the host, governing the INPUT chain (allow 22/80/443 v4+v6; default deny inbound). fail2ban's `sshd` jail adds its own iptables rules via the `banaction` parameter; on prod (T-0005) this works because fail2ban inserts its chain above UFW's by fail2ban convention, and UFW's allow-22 rules remain intact for legitimate traffic.
   - UFW `DEFAULT_FORWARD_POLICY="ACCEPT"` was set in T-0083 for Docker parity; today IP forwarding is disabled (`/proc/sys/net/ipv4/ip_forward=0`) AND Docker is not installed, so the FORWARD policy has no effect on traffic. fail2ban bans are INPUT-chain only and do not interact with the FORWARD chain. No conflict.
   - SSH path: T-0083 opened port 22; landscape confirms `sshd` is the only TCP listener on 0.0.0.0 (`ss -tlnp` snapshot in `ubuntu-16gb-nbg1-1.md`); fail2ban's sshd filter targets the same `sshd` log source.
   - **PasswordAuthentication: PASS with note.** Landscape confirms `PasswordAuthentication yes` on this host (cloud-init default; `50-cloud-init.conf`). This is NOT a conflict — it is the exact motivation for T-0084 (fail2ban is most valuable while password auth is still enabled; T-0007-equivalent for this host is a natural follow-on, not a prerequisite). The user request for this step explicitly says to flag without blocking. Flag noted; not a verdict-blocker.

5. **Discoverable scope: PASS** — Three live-discovery gaps were characterized by step 02 landscape-reader; none block design:
   - **Ubuntu 26.04 apt repo availability of `fail2ban` package** — solvable in two commands (`apt-get update && apt-cache policy fail2ban`); fail2ban is in `universe` on every Ubuntu LTS for over a decade, so availability is overwhelmingly likely, but the executor confirms. If unavailable, the executor must surface and return BLOCKED — this is a step-06 concern, not a step-03 blocker.
   - **Active iptables backend (`iptables-nft` vs `iptables-legacy`)** — solvable in two commands (`iptables --version` and `update-alternatives --list iptables`); this drives the `banaction` choice (`iptables-multiport` vs `nftables-multiport`). The design should commit to `iptables-multiport` as the default with a fallback to `nftables-multiport` if the backend is `iptables-legacy` — this is a designer's call, not a blocker on validation.
   - **Management workstation outbound IP for this host** — NOT recorded anywhere in landscape (the only IP recorded is `5.250.151.158` from prod). The task explicitly forbids hardcoding prod's value. This is a **user-supplied** value, resolved at run time via `curl https://ifconfig.me` from the workstation (task "What done looks like" item #5). The design must include an explicit gate that asks the user for the value (or instructs them to paste it from their own curl) BEFORE the jail file is written. Failure mode: if no IP can be obtained, the executor returns BLOCKED — again, a step-06 concern, not a step-03 blocker.

6. **Workflow-specific rules respected: PASS** — Per `workflows/infrastructure.md` rules:
   - **Idempotency:** `apt install fail2ban` is idempotent (apt will report "already newest version" on re-run). Writing `/etc/fail2ban/jail.d/sshd.local` is idempotent if the executor either (a) checks for file existence first and overwrites with deterministic content, or (b) uses a single `cat > ... <<'EOF'` heredoc. `systemctl enable --now fail2ban` is idempotent. No half-configured-state risk; if a re-run fails after the apt install but before the jail file write, the service can be enabled with an empty default config and the jail file written next time. Safe.
   - **Backup before destructive change:** fail2ban is a NEW package install on a NEW config file (`/etc/fail2ban/jail.d/sshd.local`). The Ubuntu-default `/etc/fail2ban/jail.conf` exists but is not modified (fail2ban best practice: use `jail.d/*.local` overrides, never edit `jail.conf` directly). The Ubuntu-default `/etc/fail2ban/filter.d/sshd.conf` is reused as-is. NO existing project config is overwritten. No backup required. If the executor chooses to be defensive, a one-line `cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak-$(date +%Y%m%d)` is cheap insurance and the validator can confirm it exists.
   - **Verify in two places:** Two-place verification is achievable. Place 1 (host-side): `systemctl is-active fail2ban` + `fail2ban-client status sshd` (the client status command shows `Currently failed`, `Total failed`, `Currently banned`, `Total banned`, `Banned IP list` — proven on prod to populate within minutes on an internet-facing port). Place 2 (host-side + cross-reference): `iptables -L -n | grep f2b-sshd` (or `nft list ruleset | grep f2b-sshd`) to confirm fail2ban inserted its ban chain above UFW's INPUT rules — this is the "coexistence sanity check" the landscape-reader flagged. No external HTTP probe is meaningful for a SSH brute-force daemon (banning is invisible to an external prober), so the workflow's "verify in two places" requirement is satisfied by two distinct host-side commands plus the upstream-rule-list check.

## Issues / risks

- **Ubuntu 26.04 apt + iptables-backend drift (medium, executor-owned).** Prod (T-0005) was Ubuntu 24.04 with `iptables v1.8.10 (nf_tables)`. Ubuntu 26.04 may ship a different default or version. The design should be parameterized: commit to `banaction = iptables-multiport` as the default with a one-line conditional swap to `nftables-multiport` if `update-alternatives --display iptables` reports `iptables-legacy`. Risk is fully solvable in executor runbook; not a step-04 design blocker.
- **Hardcoded prod workstation IP risk (low, explicitly mitigated).** T-0084's "Notes" section explicitly forbids hardcoding `5.250.151.158` (prod's value). The design must include a "confirm workstation IP" gate as the FIRST step of execution (before apt install even, so that if the user is unreachable, the run aborts cleanly without leaving a half-installed state). Suggested phrasing for the gate: "Read or accept the management workstation's outbound IP for this host. Default: `curl https://ifconfig.me` from the workstation. Hardcoded prod value `5.250.151.158` is NOT acceptable without explicit user confirmation." If the user is unreachable / non-interactive, executor returns BLOCKED rather than guessing.
- **No `PasswordAuthentication` disable yet (informational, NOT blocking).** This is the exact motivation for T-0084 — fail2ban is most valuable while password auth is still on. Disabling password auth on this host is a natural follow-on (parallels T-0007 for prod) but is not in scope for T-0084's task definition. The user request explicitly says "flag but do not block (separate task ... could be opened for the new host, or noted as related follow-on)". Logged as such; verdict remains PASS.
- **UFW + fail2ban coexistence sanity check required (low).** Step 02 surfaced this; the design must include a post-install `iptables -L -n` (or `nft list ruleset`) check that confirms both layers coexist — UFW's allow-22 rules remain in place AND fail2ban's `f2b-sshd` chain is present. If the chain is missing, fail2ban silently no-ops and the run should fail. Validator (step 07) must independently confirm.
- **`landscape/secrets-inventory.md` and `landscape/hosts/hetzner-prod.md` are 32 days old** (just over the 30-day threshold). Read-only references for this run; no design risk. Pre-existing drift; flagged for a future landscape-updater audit, not a blocker here.
- **`gitea:admin-password` row in `landscape/secrets-inventory.md` still contains the literal password value** (`eT96ulleryIpd38VJeQNRGm3lQ3qcUO3`). Pre-existing convention violation; out of scope for this run; flagged as a low-priority cleanup item.

## Open questions

- (For step 04 solution-designer) Confirm the `banaction` strategy: default `iptables-multiport` with conditional swap to `nftables-multiport` on legacy backend. Mirror T-0005's choice unless Ubuntu 26.04 surprises.
- (For step 06 executor-infra) Build the "confirm workstation IP" gate as the first executable step of the runbook. If the user cannot supply an IP (offline, non-interactive), return BLOCKED with a precise ask — do NOT guess and do NOT use `5.250.151.158`.
- (For step 06 executor-infra) Verify fail2ban + UFW coexistence with `iptables -L -n` (or `nft list ruleset`) immediately after `systemctl restart fail2ban`. If the `f2b-sshd` chain is not visible, fail the run and report.
- (For step 08 landscape-updater) Mirror the prod change-log row format exactly, substituting the new host's workstation IP and the package version from `dpkg -l fail2ban | grep ^ii`. Add a `fail2ban.service` row to the systemd-units table in `landscape/services.md` under the `ubuntu-16gb-nbg1-1` section. Append a fail2ban clause to the "SSH hardening tooling on host" sentence in the host file.

## Verdict rationale

**PASS.** Task T-0084 is well-formed, in-scope for the infrastructure workflow, not redundant with prior work, free of landscape conflicts, has no critical unknowns (the three live-discovery gaps are precisely characterized and executor-owned), and respects every workflow-specific rule. The task is ready for solution design. The user-flagged note about `PasswordAuthentication` not yet being disabled is acknowledged but is a follow-on, not a blocker — T-0084 is most valuable BEFORE that hardening (it provides brute-force protection while password auth is still on). No BLOCKED condition exists; no FAIL condition exists.
