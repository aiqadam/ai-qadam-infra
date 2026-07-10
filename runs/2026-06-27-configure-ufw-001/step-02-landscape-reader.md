---
run_id: 2026-06-27-configure-ufw-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-configure-ufw-001/step-01-task-reader.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/README.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md
artifacts_changed: []
next_step_hint: task-validator — confirm UFW scope is well-defined; flag Ubuntu 26.04 package-version differences; confirm DEFAULT_FORWARD_POLICY decision is resolved (or deferred to solution-designer)
---

## Summary

Landscape is sufficient to design the UFW configuration. The target host (`ubuntu-16gb-nbg1-1`, 46.225.239.60, Ubuntu 26.04) is a fresh cloud image with the `ufw` binary present but inactive, all iptables/ip6tables chains at default ACCEPT, no Docker installed, and only one TCP listener on 0.0.0.0 (port 22). The reference template — `hetzner-prod`'s UFW ruleset applied by run `2026-05-12-add-host-firewall-001` (T-0002) — provides the proven command sequence, including `DEFAULT_FORWARD_POLICY="ACCEPT"` for Docker FORWARD-chain future-proofing. SSH lockout is the primary execution risk; the prior run handled it with an `at`-based rollback timer plus per-command SSH success as proof. The 30-day staleness check flags two reference files (`hetzner-prod.md`, `secrets-inventory.md`) but neither blocks safe design — both are read-only inputs to this run.

## Details

### Relevant facts (sourced from landscape)

#### Target host — current state (sourced from `landscape/hosts/ubuntu-16gb-nbg1-1.md`)

- **Identity:** `ubuntu-16gb-nbg1-1`, Hetzner Cloud server id `145542849`, project id `15130993` ("Al-Qadam"), CX43, Nuremberg (`nbg1`).
- **Network:** IPv4 `46.225.239.60`, IPv6 `2a01:4f8:1c1c:5959::/64` — both stacks available, UFW must install rules for both.
- **OS:** Ubuntu 26.04 LTS (`resolute`), kernel `7.0.0-22-generic`. This is **newer** than `hetzner-prod`'s 24.04 — UFW package defaults may differ.
- **Role:** `unassigned` — no Docker, no nginx, no application data. This means there are no Docker-managed ports or compose bridges to consider for FORWARD-chain behavior *today*, but future-proofing `DEFAULT_FORWARD_POLICY="ACCEPT"` for Docker parity with `hetzner-prod` is appropriate.
- **Current firewall state:** `ufw` binary present at `/usr/sbin/ufw`; `ufw.service` listed as enabled-but-inactive in `landscape/services.md`; `iptables` / `ip6tables` chains all default ACCEPT; `nft` binary present but empty ruleset. Effectively no host firewall.
- **TCP listeners on 0.0.0.0 (reachable from internet):** only port 22 (`sshd`). Port 22's daemon config currently allows `PasswordAuthentication yes` (cloud-image default — hardening pending; out of scope for this task).
- **TCP listeners on 127.0.0.1 only:** `127.0.0.53:53` and `127.0.0.54:54` (systemd-resolved stub). Not affected by UFW.
- **SSH access (verified):**
  - User: `tvolodi` (uid 1000, groups `sudo` `users`), passwordless sudo via `/etc/sudoers.d/90-tvolodi` (content `tvolodi ALL=(ALL) NOPASSWD:ALL`, mode 0440, mtime 2026-06-27 04:46).
  - Port: 22.
  - SSH key installed on server: yes — `/home/tvolodi/.ssh/authorized_keys` (contains **two duplicate lines** for the same ed25519 key; harmless, do NOT touch in this run).
  - Management key: `C:\Users\tvolo\.ssh\ai-dala-infra` (ed25519, no passphrase); fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`; SSH config alias `ubuntu-16gb-nbg1-1`.
  - `atd.service` status: not explicitly listed in the host's systemd table, but `atd.service` is in the stock cloud-image base unit list. The prior run (T-0002) used `at` for rollback successfully on `hetzner-prod`, so the tooling is available; executor should still confirm `atd` is active on first SSH in.

#### Reference ruleset — `hetzner-prod` post-T-0002 (sourced from `landscape/hosts/hetzner-prod.md`)

- **UFW status:** active as of 2026-05-12 (run `2026-05-12-add-host-firewall-001`).
- **Defaults:** deny inbound, allow outbound, **allow routed (= `DEFAULT_FORWARD_POLICY="ACCEPT"`)** — set to preserve Docker FORWARD chain.
- **Final ruleset as of 2026-05-26 (after subsequent RustDesk + Gitea adds):** deny incoming (default), allow outgoing (default), allow 22/tcp (v4+v6), allow 80/tcp (v4+v6), allow 443/tcp (v4+v6), allow 2222/tcp (v4+v6), allow 21115/tcp (v4+v6), allow 21116/tcp (v4+v6), allow 21116/udp (v4+v6), allow 21117/tcp (v4+v6), allow 21118/tcp (v4+v6), allow 21119/tcp (v4+v6). The **first three (22, 80, 443)** are the exact set this run needs to mirror.
- **Change-log line:** `2026-05-12 | 2026-05-12-add-host-firewall-001 | Enabled UFW: default deny inbound, allow 22/80/443. DEFAULT_FORWARD_POLICY=ACCEPT for Docker. Rules survive reboot. Docker iptables bypass confirmed (port 5678 still reachable).` — exact format to replicate at step 08.
- **Operational notes from `hetzner-prod`:** UFW `enable` is idempotent; `ufw reload` is idempotent; `ufw allow X` is idempotent. Recovery path is `ufw disable`. Docker-published ports bypass UFW via iptables DOCKER chain — out of scope here (no Docker installed on target host).

#### T-0002 proven pattern (sourced from `runs/2026-05-12-add-host-firewall-001/step-06-executor-infra.md`, via `inputs_read`)

- **Step sequence (paraphrased, not pasted):** (1) pre-flight `ufw status verbose` + `cat /etc/default/ufw | grep DEFAULT_FORWARD_POLICY`; (2) schedule `at`-job to run `ufw disable` 5 min out; (3) backup `/etc/default/ufw` → `/etc/default/ufw.bak`; (4) `sed -i /DEFAULT_FORWARD_POLICY/s/DROP/ACCEPT/ /etc/default/ufw` (quote-safe sed form that avoids PowerShell double-quote stripping); (5) `ufw --force reset`; (6) `ufw default deny incoming && ufw default allow outgoing`; (7) `ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp` (each rule applies to v4 + v6); (8) `ufw --force enable`; (9) verify with `ufw status verbose` from same session; (10) every subsequent SSH command opening a fresh TCP connection to 22 proves port-22 rule works; (11) `sudo atrm <job_id>` to cancel rollback; (12) `sudo reboot` + post-reboot `ufw status verbose` + `systemctl is-enabled ufw` to confirm persistence.
- **Quirk noted:** the prior run's sed pattern `s/^DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/` failed under PowerShell/SSH quote stripping; the working alternative was `sed -i /DEFAULT_FORWARD_POLICY/s/DROP/ACCEPT/ /etc/default/ufw` (no quote characters in the expression). Executor should default to the working form.
- **Quirk noted:** the `docker ps` (without `sudo`) "permission denied" is pre-existing on `hetzner-prod` (user not in `docker` group); not relevant on this host (no Docker installed) but listed here so the executor does not chase a phantom issue.

#### SSH lockout risk and recovery (synthesized)

- **Risk:** UFW `enable` while no `22/tcp ALLOW` rule is committed, OR a v6-rule failure that silently drops v6 traffic to port 22, will lock out the management workstation with no recovery except the Hetzner web console (rescue mode or boot into debug).
- **Mitigations (proven in T-0002):** (a) `at`-based rollback timer; (b) apply 22/tcp allow rule **before** `ufw --force enable`; (c) verify with a fresh SSH session after enable (each `ssh ...` invocation is a new TCP connection to 22, so any successful command post-enable proves the rule works); (d) before declaring done, executor should also verify `systemctl is-enabled ufw` returns `enabled`.
- **Validator role at step 07:** execution-validator MUST independently verify SSH from a fresh connection AND verify `ufw status verbose` from off-host before returning PASS.

#### Secret handling (sourced from `landscape/secrets-inventory.md`, read-only)

- **Management SSH key** (`ssh-key:ai-dala-infra-mgmt`): private key at `C:\Users\tvolo\.ssh\ai-dala-infra`, public key fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`, public key block also recorded in the inventory. **No secret values need to be added or rotated by this run** — the key is already deployed to `ubuntu-16gb-nbg1-1`'s `authorized_keys`.
- **Other secrets** in the inventory (Cloudflare tokens, Hetzner API token, GitHub PATs, Gitea credentials, RustDesk private key, etc.) are all `hetzner-prod`-bound and not affected by this run.
- **Workflow rule reminder:** secrets must never appear in handoff bodies; the inventory references them by name only. This run does not introduce any new secret references.

### Stale or stub files encountered

- `landscape/hosts/hetzner-prod.md` — `last_verified: 2026-05-26`, status `populated`. As of today (2026-06-27) this is **32 days old**, just over the 30-day threshold. **STALE per the staleness rule.** However, the file is referenced only for the historical UFW ruleset (which is a one-way write that hasn't been undone) and the change-log entry format — both immutable history at this point. **Does not block design.** Flagged for an unrelated follow-on landscape-updater audit, not a blocker for this run.
- `landscape/secrets-inventory.md` — `last_verified: 2026-05-26`, status `in-progress`. **32 days old, STALE.** Read-only for this run. The SSH key entry is the only one referenced and its current state (`last_rotated: 2026-05-12`, fingerprint unchanged) is corroborated by the target host's landscape file which references the same fingerprint. No design risk.
- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `last_verified: 2026-06-27`, status `populated`. **Fresh (today).**
- `landscape/services.md` — `last_verified: 2026-06-27`, status `populated`. **Fresh (today).**
- `landscape/README.md` — no `last_verified` field; not applicable (meta-file).

### Gaps requiring live discovery

1. **On-host UFW package version and `/etc/default/ufw` defaults** on Ubuntu 26.04. T-0002 ran on Ubuntu 24.04 — the `DEFAULT_FORWARD_POLICY="DROP"` default may differ on 26.04, and UFW's default rules-file syntax (`/etc/ufw/user.rules`) may have evolved. Executor (step 06) must inspect the file **before** applying the sed/reset sequence to avoid the off-quote-characters sed bug repeating.
2. **`atd.service` active state on `ubuntu-16gb-nbg1-1`.** Listed in the cloud-image base systemd unit table but not explicitly verified by the discovery run. Executor should confirm `systemctl is-active atd` before relying on the `at`-based rollback safety timer; fallback to a `nohup`-based sleep-and-disable timer if `atd` is unavailable.
3. **Hetzner Cloud Firewall state on project 15130993.** Explicitly out of scope per task T-0083 "Notes" and T-0082 open questions. Recorded here so the executor does not assume a Hetzner-side firewall is providing outer-layer mitigation — it may or may not be.

### Issues / risks

- **SSH lockout risk (primary):** see "SSH lockout risk and recovery" above. Mitigated by the proven T-0002 pattern (allow-rule-first, `at` rollback, fresh-connection proof). Solution-designer (step 04) MUST include the rollback timer in the plan; task-validator (step 03) MUST check that the plan has it.
- **`DEFAULT_FORWARD_POLICY` decision is currently deferred by the task.** Two viable choices: (a) `"ACCEPT"` for parity with `hetzner-prod` and Docker-future-proofing, even though no Docker exists today; (b) `"DROP"` (stricter; current reality; would need to be flipped later when Docker lands). My read matches step 01's: **(a) `"ACCEPT"`** is the correct call because the task's "What done looks like" already lists `"ACCEPT"` as a parity option, the cost of getting it wrong is zero today (no FORWARD traffic to drop), and the cost of flipping it later is a one-line sed change but a real workflow run. Step 04 owns the formal decision; this is a strong recommendation, not a verdict.
- **Ubuntu 26.04 UFW package drift:** see "Gaps" item 1. Executor should `diff /etc/default/ufw /etc/default/ufw.bak` (the backup it just took) and report any non-FORWARD-policy differences before declaring done — they may indicate the package version changed default settings the plan didn't account for.
- **Docker+UFW bypass (informational):** not applicable on this host (no Docker installed). Recorded so step 08's landscape-updater notes that the bypass caveat does not apply, unlike the prod change-log entry which had to call it out.

### Open questions

None for step 02. Step 04 owns the `DEFAULT_FORWARD_POLICY` decision (recommendation: `ACCEPT`); step 06 owns the on-host UFW package-version check.