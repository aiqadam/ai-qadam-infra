---
run_id: 2026-08-17-prepare-letflow-host-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-08-17T05:45:00Z
task_id: T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow
inputs_read:
  - runs/2026-08-17-prepare-letflow-host-001/step-01-task-reader.md
  - runs/2026-08-17-prepare-letflow-host-001/step-02-landscape-reader.md
  - runs/2026-08-17-prepare-letflow-host-001/step-03-task-validator.md
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - shared/approval-protocol.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - tasks/T-0134-prepare-ubuntu-16gb-nbg1-1-for-letflow.md
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
next_step_hint: Orchestrator should halt and present this plan to the user per shared/approval-protocol.md — verdict NEEDS_APPROVAL is mandatory here regardless of plan quality because the task file itself declares estimated_blast_radius medium, and the plan touches package installs, a firewall rule change, and sshd hardening (all three independently on the "always requires NEEDS_APPROVAL" list). User should specifically confirm or object to: (1) the fuller sshusers/AllowGroups sshd hardening pattern (exceeds T-0134's literal 2-directive checklist), (2) the 0.0.0.0/0 + ::/0 world-open CIDR for 80/443, (3) the proposed role: letflow-app frontmatter value, (4) the secrets-inventory.md documentation-only additions. If APPROVED, advance to executor-infra (step 06) with this file plus step-05 as inputs.
---

## Summary

Plan to bring `ubuntu-16gb-nbg1-1` (46.225.239.60, Hetzner project "ai-qadam", server id 145542849) from its current unassigned/unhardened state to a Docker-ready, firewall-opened (80/443 world-open at the Hetzner Cloud Firewall layer), sshd-hardened application host in four ordered phases — live-state reconfirmation, Docker CE + Compose plugin install, a Hetzner Cloud Firewall rule update (reusing firewall `ai-qadam-mgmt-ssh` id `11204449`), and sshd hardening (full `sshusers`/`AllowGroups` pattern, matching T-0093/T-0102) — leaving `role:` and `services.md` updates for step 08 and explicitly deferring all Letflow application deployment to a follow-on task. End state: no listener on 80/443 (by design — app deploy is out of scope), Docker functional and network-capable, SSH reachable only via key auth from the management workstation plus (now) the public internet on 80/443 at the firewall layer only.

## Details

### Why `NEEDS_APPROVAL` (not `PASS`)

Per `shared/approval-protocol.md`, `PASS` requires `estimated_blast_radius: low` in the task file. T-0134's frontmatter declares `estimated_blast_radius: medium` — condition 1 for auto-approval already fails, independent of plan quality. Additionally, this plan contains three items independently on the "Always requires `NEEDS_APPROVAL`" list: an OS package install (Docker CE), a firewall rule change (Hetzner Cloud Firewall 80/443), and an sshd hardening change. Verdict is `NEEDS_APPROVAL` per role rules; this was expected by the task author (see T-0134 "Notes") and by steps 01–03.

### Four design decisions made explicit (per step 03's next_step_hint)

**(a) sshd-hardening depth — full `sshusers`/`AllowGroups` pattern chosen, not the literal 2-directive reading.**
T-0134's literal checklist names only `PasswordAuthentication no` and `PermitRootLogin prohibit-password`, but its own "Why"/checklist language says "matching T-0093/T-0102's precedent," and the host's own landscape file's "What needs to happen" item 4 already describes the fuller scope ("disable PasswordAuthentication, disable PermitRootLogin, drop SHA-1 MACs, set explicit KexAlgorithms/Ciphers... project-managed drop-in"). Fleet consistency (this would otherwise be the only hardened host without `AllowGroups sshusers`) and the precedent's own experience (T-0093 also shipped ~10 directives against a narrower prompt, without objection) both favor the fuller pattern. **Decision: apply the full T-0093/T-0102 drop-in content verbatim** (same two files, same directive set), adapted only for this host's actual operator user. This exceeds T-0134's literal acceptance criteria — flagged in Issues/risks, not hidden.

Critical adaptation vs. precedent: on `pro-data-tech-prod`/`pro-data-tech-qa`, `root` was the *sole* pre-existing SSH-capable user at hardening time, so `root` was added to `sshusers` as the transitional member. On `ubuntu-16gb-nbg1-1`, **`root` cannot SSH in at all** (`/root/.ssh/` is empty per landscape) — the only functioning SSH identity is `tvolodi`. **Decision: add `tvolodi` to `sshusers` (the real, load-bearing addition — omitting this would lock out the only working access path), and also add `root`** (harmless — root has no key, so this grants no new access today, but mirrors the fleet's break-glass convention and costs nothing if a root key is ever installed later).

**(b) Docker/UFW `after.rules` DOCKER-USER append — NOT applied proactively; live-tested and conditionally deferred.**
`pro-data-tech-prod` (T-0106) needed the `after.rules` DOCKER-USER/MASQUERADE block because its UFW `DEFAULT_FORWARD_POLICY` was `DROP`. `ubuntu-16gb-nbg1-1`'s UFW already has `DEFAULT_FORWARD_POLICY="ACCEPT"`, pre-set on 2026-06-27 explicitly "for Docker parity" — the landscape file itself notes this value is inert only because IP forwarding is currently disabled, and "will activate the moment IP forwarding is enabled (e.g., when Docker is installed)." Docker's own postinst enables `net.ipv4.ip_forward=1` when it creates the `docker0` bridge, which is exactly the trigger the landscape file anticipated. **Decision: do not append the `after.rules` block preemptively.** Instead, Phase 1 includes a live container-egress test (Step 1.10); the `after.rules` fallback is fully specified but is a **conditional** sub-step, only executed if that test fails, per Design rule "design a discovery sub-step... instead of making assumptions."

**(c) Hetzner Cloud Firewall 80/443 source CIDR — `0.0.0.0/0` and `::/0` (world-open).**
T-0134 says "allow inbound TCP 80/443" without a CIDR. This host will carry public Letflow web traffic per the task's own "Why" section, and the existing host-level UFW rule for the same two ports is already world-open (`allow 80/tcp, allow 443/tcp` for v4+v6, no source restriction) — a world-open Hetzner Cloud Firewall rule is simply extending the same posture to the outer layer, not introducing a new one. **Decision: `0.0.0.0/0` + `::/0`.** This is an inference, not a literal instruction — flagged in Issues/risks so the user can object during this `NEEDS_APPROVAL` review if a narrower CIDR (e.g., Cloudflare's IP ranges only, once DNS is proxied by the follow-on task) was actually intended.

**(d) `secrets-inventory.md` — two documentation-only additions, no new secret values.**
No acceptance criterion in T-0134 names a new secret, and this task's own execution introduces none (Docker install needs no credential; the firewall change and sshd hardening use only the existing `ai-dala-infra` management key and the existing `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` API token). Two gaps close naturally as a byproduct of this task assigning the host's role: (1) the host's own landscape file already asserts "Full public key in `../secrets-inventory.md`" for the `ai-dala-infra` SSH key, but no such entry currently exists there; (2) the Hetzner API token used by Phase 2 of this very plan (`hetzner-api-token:ai-dala-infra:ai-qadam-read-write`, per T-0086) also has no current entry, despite `ubuntu-16gb-nbg1-1.md`'s 2026-06-27 change log claiming a fingerprint was recorded there (likely lost in the post-spinoff `secrets-inventory.md` recreation — the file is gitignored and was "never committed" per `landscape/README.md`'s bootstrap note). **Decision: step 08 (landscape-updater) adds two name-only, no-value documentation rows** — see "Resources used" below. This is documentation of existing secrets this plan uses, not a new secret being introduced, so it stays in scope for the executor/landscape-updater without needing a separate task.

---

### Pre-execution requirement

All host-side commands run over a single persistent SSH session opened before any changes, using the existing config alias: `ssh ubuntu-16gb-nbg1-1` (management workstation `C:\Users\tvolo\.ssh\config`, key `C:\Users\tvolo\.ssh\ai-dala-infra`, user `tvolodi`). The session must stay open through Phase 3 (sshd hardening) so a live rollback path exists if a hard gate fails.

All Hetzner Cloud API calls use the existing PowerShell helper pattern from `runs/2026-06-27-apply-hetzner-firewall-001/executor-02-helpers.ps1` (token loaded from disk into a local variable, never echoed, never written to a file): token file `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, secret name `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`.

---

### Phase 0 — Live-state reconfirmation (read-only; addresses the 51-day-stale landscape snapshot)

**0.1 — SSH baseline.** Command: `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; whoami; hostname; date -u"` — Verification: `===OK===` banner, `whoami` returns `tvolodi`.

**0.2 — Current sshd effective config.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(passwordauthentication|permitrootlogin|allowgroups) '"` — Verification: capture output; expected (per landscape) `passwordauthentication yes`, `permitrootlogin yes`, no `allowgroups` line. Any deviation from this expectation must be reconciled before Phase 3 proceeds (re-run Phase 3 idempotency checks accordingly rather than assuming the landscape snapshot).

**0.3 — Current UFW / after.rules state.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo ufw status verbose; echo ---; sudo cat /etc/ufw/after.rules"` — Verification: confirm `DEFAULT_FORWARD_POLICY` reads `ACCEPT`-configured (verbose output may show `disabled (routed)` per the landscape file's documented quirk — this is expected, not a failure) and that `after.rules` contains no pre-existing `DOCKER-USER` or `T-0134` marker (idempotency guard for Phase 1's conditional fallback).

**0.4 — Docker absence check.** Command: `ssh ubuntu-16gb-nbg1-1 "dpkg -l docker-ce 2>/dev/null | grep '^ii' || echo NOT_INSTALLED"` — Verification: `NOT_INSTALLED`. If Docker is already installed, skip Phase 1 install sub-steps (1.4–1.9) and run only the verification sub-steps (1.10–1.12).

**0.5 — Current Hetzner Cloud Firewall rule set (live, not from the landscape doc — this response is also the pre-change backup/snapshot for Phase 2's rollback).** Command: `GET https://api.hetzner.cloud/v1/firewalls/11204449` — Verification: HTTP 200; exactly one rule (`tcp/22` from `178.89.57.135/32`); save response to `runs/2026-08-17-prepare-letflow-host-001/step-0-5-firewall-baseline.json`. **Use the exact `source_ips`/`description` values from this live response (not the landscape doc's copy) when constructing Phase 2's `set_rules` body**, in case the management workstation's outbound IP or the rule description drifted since 2026-06-27.

**0.6 — Baseline external TCP-reachability probe for 80/443 (pre-change signature, for the step 07 dual-probe comparison — see "Verification (for step 07)" below).** Commands, from the management workstation:
```powershell
Measure-Command { Test-NetConnection 46.225.239.60 -Port 80 } | Select-Object TotalSeconds
Measure-Command { Test-NetConnection 46.225.239.60 -Port 443 } | Select-Object TotalSeconds
```
Verification: expect `TcpTestSucceeded: False` for both, with a **slow/timeout-length** completion (several seconds) — consistent with the Hetzner Cloud Firewall silently dropping non-allow-listed ports at the cloud edge (this host's own UFW already allows 80/443, so today's blocking layer must be the Hetzner Cloud Firewall, not UFW). Save outputs to `preflight-0-6-tcp80-before.txt` / `preflight-0-6-tcp443-before.txt`.

---

### Phase 1 — Docker Engine + Compose plugin install

Mirrors T-0106 (`pro-data-tech-prod`), adapted per decision (b) above: no proactive `after.rules` edit.

**1.1 — Connectivity probe.** Command: `ssh ubuntu-16gb-nbg1-1 "curl -s --max-time 10 https://download.docker.com/linux/ubuntu/gpg > /dev/null && echo CONNECTIVITY_OK"` — Verification: output contains `CONNECTIVITY_OK`.

**1.2 — Idempotency guard (re-check of 0.4).** Command: `ssh ubuntu-16gb-nbg1-1 "dpkg -l docker-ce 2>/dev/null | grep -c '^ii'"` — Verification: `0`. If `1`, skip to 1.10.

**1.3 — Install apt prerequisites.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo apt-get install -y ca-certificates curl gnupg"` — Verification: `dpkg -l ca-certificates curl gnupg | grep -c '^ii'` returns `3`.

**1.4 — Docker GPG key into apt keyring.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && sudo chmod a+r /etc/apt/keyrings/docker.gpg"` — Verification: `test -f /etc/apt/keyrings/docker.gpg && echo GPG_OK`.

**1.5 — Add Docker stable apt repository.** `lsb_release -cs` returns `resolute` on Ubuntu 26.04 (confirmed working identically on `pro-data-tech-qa`/`pro-data-tech-prod`, same OS). Command:
```
ssh ubuntu-16gb-nbg1-1 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
```
Verification: `cat /etc/apt/sources.list.d/docker.list` contains `download.docker.com` and `resolute`.

**1.6 — Update apt index.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo apt-get update"` — Verification: exit 0; output contains `download.docker.com`; no `E:` lines for that source.

**1.7 — Install Docker Engine + Compose plugin.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"` — Verification: `docker --version` prints `Docker version ...`; exit 0.

**1.8 — Enable and start Docker.** (No pre-stop needed here — unlike T-0106, we are not modifying `after.rules` before Docker starts, so there is no ordering hazard.) Command: `ssh ubuntu-16gb-nbg1-1 "sudo systemctl enable docker && sudo systemctl start docker"` — Verification: `systemctl is-active docker` → `active`; `systemctl is-enabled docker` → `enabled`.

**1.9 — Add `tvolodi` to the `docker` group.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG docker tvolodi"` — Verification: `id tvolodi | grep docker`.

**1.10 — Verify: `docker run hello-world`.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo docker run hello-world"` — Verification: output contains `Hello from Docker!`; exit 0. (Run via `sudo`, since `tvolodi`'s new group membership isn't active in the existing SSH session — matches T-0106's documented workaround.)

**1.11 — Verify: `docker compose version`.** Command: `ssh ubuntu-16gb-nbg1-1 "docker compose version"` — Verification: output starts with `Docker Compose version v`; exit 0.

**1.12 — Live container-egress test (resolves design decision (b)).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo docker run --rm alpine:3.20 sh -c 'wget -q -T 5 -O- https://api.ipify.org || echo EGRESS_FAILED'"` — Verification: output is a bare IPv4 address (egress works — `DEFAULT_FORWARD_POLICY=ACCEPT` + Docker's own iptables NAT rules are sufficient; **no `after.rules` change needed, Phase 1 is complete**). If output is `EGRESS_FAILED` or the command times out, proceed to the conditional fallback below.

**1.13 — CONDITIONAL fallback (only if 1.12 shows `EGRESS_FAILED`) — discover the public interface name, then append the DOCKER-USER/MASQUERADE block.**
- 1.13a — Discover interface: `ssh ubuntu-16gb-nbg1-1 "ip -4 route show default"` — read the `dev <name>` field (expected `eth0` by Hetzner convention, but must be confirmed live, not assumed).
- 1.13b — Backup: `ssh ubuntu-16gb-nbg1-1 "sudo cp /etc/ufw/after.rules /var/backups/ufw-after.rules-pre-T0134.bak"` — Verification: `test -f /var/backups/ufw-after.rules-pre-T0134.bak`.
- 1.13c — Append (using the discovered interface name, here shown as `eth0`, matching T-0106's exact block content):
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
- 1.13d — Reload UFW: `ssh ubuntu-16gb-nbg1-1 "sudo ufw reload"` — Verification: `sudo ufw status` exits 0.
- 1.13e — Re-run 1.12. If it still fails, STOP and escalate — this is an execution-time blocker requiring re-design, not a scripted retry.

---

### Phase 2 — Hetzner Cloud Firewall: allow inbound TCP 80/443

**Reuse decision:** reuse firewall `ai-qadam-mgmt-ssh` (id `11204449`) via `set_rules`, rather than creating a second firewall. Rationale: exactly one firewall should exist per host (established convention, verified by the `2026-06-27-apply-hetzner-firewall-001` precedent's own idempotency guard); `11204449` is already applied to server `145542849`; a second firewall would need its own `apply_to_resources` call and would fragment the ruleset across two objects with overlapping `managed-by=ai-dala-infra` labels, which is more error-prone, not less.

**2.1 — Construct the full replacement rule set (uses 0.5's live values, not the landscape doc's copy).**
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
The `port: "22"` entry's `source_ips`/`description` MUST be copied verbatim from Phase 0.5's live `GET` response, not retyped from this document, in case it drifted.

**2.2 — Apply.** Command: `POST https://api.hetzner.cloud/v1/firewalls/11204449/actions/set_rules` with the body above, `Content-Type: application/json`, `Authorization: Bearer <hetzner-api-token:ai-dala-infra:ai-qadam-read-write>`. Verification: HTTP 201 with an `actions` array; poll `GET /v1/firewalls/11204449/actions/<action_id>` every 2s (max 30s) until `status: "success"`.

**2.3 — Post-apply verification (on-host / API).** Command: `GET https://api.hetzner.cloud/v1/firewalls/11204449` — Verification: `rules` array contains exactly 3 entries matching 2.1; `applied_to` still contains server `145542849` (untouched by `set_rules`, which only replaces the rule list, not the application binding).

**2.4 — Post-apply external TCP-reachability probe (dual-signature comparison against 0.6 — this is the step 07 "externally observable" check; see note below on why this cannot be an HTTP probe).**
```powershell
Measure-Command { Test-NetConnection 46.225.239.60 -Port 80 } | Select-Object TotalSeconds
Measure-Command { Test-NetConnection 46.225.239.60 -Port 443 } | Select-Object TotalSeconds
```
Expected change from 0.6's baseline: `TcpTestSucceeded: False` for both (unchanged — nothing listens on 80/443, app deploy is out of scope for T-0134), but completion is now **fast** (immediate TCP RST from the host's own kernel — the packet now clears the Hetzner Cloud Firewall and reaches UFW's pre-existing ALLOW rule, which was already in place, then finds no listener), versus 0.6's **slow/timeout** completion (packet silently dropped at the Hetzner Cloud Firewall, never reaching the host). **A fast-RST result on both ports, contrasted with 0.6's slow-timeout baseline, is the positive signal that the Hetzner Cloud Firewall rule is now live** — this is the TCP-level reachability check step 03 flagged as necessary in place of an HTTP status probe, since no service will be listening. Also spot-check that SSH (port 22) is unaffected: `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True`, same as always.

**2.5 — Functional SSH still works (regression check).** Command: `ssh ubuntu-16gb-nbg1-1 "echo ===OK===; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw"` — Verification: `===OK===`, both `active`.

---

### Phase 3 — sshd hardening (full `sshusers`/`AllowGroups` pattern — decision (a) above)

**3.1 — Backup existing sshd config.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo cp -r /etc/ssh /var/backups/pre-T0134.$(date +%Y%m%dT%H%M%SZ)"` — Verification: `ls /var/backups/ | grep pre-T0134` returns a timestamped directory containing `sshd_config`, `sshd_config.d/`, `50-cloud-init.conf`.

**3.2 — Create `sshusers` group (idempotent).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo groupadd -f sshusers"` — Verification: `getent group sshusers` returns `sshusers:x:<gid>:`.

**3.3 — Add `tvolodi` to `sshusers` (CRITICAL — the load-bearing step; omitting this locks out the only working SSH identity on this host once `AllowGroups sshusers` is active).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG sshusers tvolodi"` — Verification: `id tvolodi | grep sshusers` exits 0.

**3.4 — Add `root` to `sshusers` (break-glass parity; harmless today since root has no installed key).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo usermod -aG sshusers root"` — Verification: `id root | grep sshusers` exits 0.

**3.5 — Write `/etc/ssh/sshd_config.d/40-disable-password.conf`.**
```
ssh ubuntu-16gb-nbg1-1 "cat | sudo tee /etc/ssh/sshd_config.d/40-disable-password.conf > /dev/null << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF"
```
`40-` sorts before this host's cloud-init drop-in (`50-cloud-init.conf`, which sets `PasswordAuthentication yes`) under first-wins semantics — the project drop-in wins. (Note: this host's cloud-init file is named `50-cloud-init.conf`, not `60-cloudimg-settings.conf` as on `pro-data-tech-qa`/`pro-data-tech-prod` — a fleet naming difference; the `40-` prefix still safely sorts first either way.)

**3.6 — Write `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf`** (identical content to T-0093/T-0102, for fleet consistency):
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

**3.7 — Set permissions.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo chmod 644 /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf"` — Verification: `ls -la /etc/ssh/sshd_config.d/` shows both, mode `-rw-r--r--`, owner `root root`.

**3.8 — HARD GATE: `sshd -t`.** Command: `ssh ubuntu-16gb-nbg1-1 "sudo sshd -t"` — Verification: exit 0, no error output. **If non-zero: ABORT, do not proceed to 3.9/3.10, execute Rollback scenario A immediately.**

**3.9 — HARD GATE: confirm `tvolodi` is in `sshusers` before reload.** Command: `ssh ubuntu-16gb-nbg1-1 "id tvolodi | grep sshusers"` — Verification: exit 0, output contains `sshusers`. **If non-zero: ABORT, do not reload, execute Rollback scenario A immediately.**

**3.10 — Reload sshd (preserves the active session).** Command: `ssh ubuntu-16gb-nbg1-1 "sudo systemctl reload ssh"` — Verification: `systemctl is-active ssh` → `active`. (This host's systemd unit is named `ssh.service`, per its own landscape file's systemd table — not `sshd.service`.)

**3.11 — Verify sshd still running.** Command: `ssh ubuntu-16gb-nbg1-1 "systemctl is-active ssh"` — Verification: `active`.

**3.12 — Verify effective config (14 directives).**
```
ssh ubuntu-16gb-nbg1-1 "sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowgroups|kexalgorithms|ciphers|macs|usedns) '"
```
Expected: `permitrootlogin=prohibit-password`, `passwordauthentication=no`, `kbdinteractiveauthentication=no`, `pubkeyauthentication=yes`, `permitemptypasswords=no`, `maxauthtries=3`, `logingracetime=30`, `x11forwarding=no`, `clientaliveinterval=300`, `clientalivecountmax=2`, `allowgroups=sshusers`, `kexalgorithms` contains `curve25519-sha256` and no `sha1`, `ciphers` contains `chacha20-poly1305` and no `3des`/`cbc`, `macs` contains `etm@openssh.com` and no `hmac-sha1`, `usedns=no`.

**3.13 — Verify group/membership.** Commands: `ssh ubuntu-16gb-nbg1-1 "getent group sshusers; id tvolodi; id root"` — Verification: `sshusers` group lists both `tvolodi` and `root`.

**3.14 — Verify drop-in files + backup.** Commands: `ssh ubuntu-16gb-nbg1-1 "ls -la /etc/ssh/sshd_config.d/; cat /etc/ssh/sshd_config.d/40-disable-password.conf; cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf; ls /var/backups/ | grep pre-T0134"` — Verification: both files present with correct content and mode; `50-cloud-init.conf` still present, unchanged; backup directory exists.

**3.15 — External check: fresh SSH connection (new session, not the held-open one) confirms key auth still works post-hardening.** Command (from management workstation, a second/new terminal): `ssh ubuntu-16gb-nbg1-1 "whoami; id | grep sshusers"` — Verification: connects successfully, output contains `tvolodi` and `sshusers`.

**3.16 — External check: password auth is rejected.** Command: `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes ubuntu-16gb-nbg1-1 exit` — Verification: fails with `Permission denied (publickey)` — confirms the server advertises only `publickey`, i.e. both `PasswordAuthentication no` and `KbdInteractiveAuthentication no` are effective.

---

### Rollback

**Phase 1 (Docker) rollback** — if any step 1.3–1.13 fails or post-install verification fails:
1. `sudo systemctl stop docker.service docker.socket containerd.service`
2. `sudo deluser tvolodi docker` (if 1.9 ran)
3. If 1.13 ran: `sudo cp /var/backups/ufw-after.rules-pre-T0134.bak /etc/ufw/after.rules && sudo ufw reload`
4. `sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && sudo apt-get autoremove -y`
5. `sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/sources.list.d/docker.list`
6. Verify: `sudo ufw status` unchanged; `dpkg -l docker-ce 2>/dev/null | grep -c '^ii'` → `0`.
Fully reversible — no application data exists on this host to lose.

**Phase 2 (Hetzner Firewall) rollback** — if 2.4's post-apply probe shows SSH (port 22) no longer reachable, or `set_rules` returns an error:
1. `POST /v1/firewalls/11204449/actions/set_rules` with the original single-rule body captured in `step-0-5-firewall-baseline.json` (Phase 0.5's live snapshot serves as the backup for this rollback — no file restore needed, the API call itself reverts state).
2. Re-verify: `GET /v1/firewalls/11204449` shows exactly 1 rule; `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True`.
Fully reversible via the same API used to make the change.

**Phase 3 (sshd) rollback:**

*Scenario A — before reload (3.8 or 3.9 gate fired):*
1. `sudo rm -f /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf`
2. `ls /etc/ssh/sshd_config.d/` — confirm only `50-cloud-init.conf` remains.
3. `sudo sshd -t` — must exit 0.
4. No reload was ever issued; the active session was never disrupted. Host is back to pre-change (cloud-init default) sshd state.

*Scenario B — after reload, unexpected behavior:*
1. `sudo rm -f /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf`
2. `sudo sshd -t`
3. `sudo systemctl reload ssh`
4. `systemctl is-active ssh` → `active`.

*Scenario C — catastrophic, full restore from backup:*
1. `sudo cp -r /var/backups/pre-T0134.<timestamp>/ssh/* /etc/ssh/`
2. `sudo sshd -t`
3. `sudo systemctl reload ssh`

**No-rollback-possible note:** if `tvolodi` (and `root`) were somehow both excluded from `sshusers` at reload time despite gates 3.8/3.9 passing (i.e., a bug in this plan's ordering, not a gate failure), and the held-open session also terminates before rollback is applied, the only recovery path is the **Hetzner Cloud Console (KVM-over-IP)**, which is confirmed available for this host (unlike `pro-data-tech-prod`, where this same risk class was flagged as *unconfirmed* recovery). This lowers — but does not eliminate — the severity of this plan's highest risk item; still flagged HIGH in Issues/risks.

---

### Verification (for step 07)

**On-host:**
- Docker: `dpkg -l docker-ce docker-compose-plugin | grep -c '^ii'` → `2`; `systemctl is-active docker` → `active`; `systemctl is-enabled docker` → `enabled`; `id tvolodi | grep docker`; `sudo docker run hello-world` succeeds; `docker compose version` succeeds.
- Firewall (API-side, treated as "on-host" for this workflow since it's queried via API not host SSH): `GET /v1/firewalls/11204449` shows 3 rules (22/80/443) and `applied_to` still contains server `145542849`.
- sshd: all 14 `sshd -T` directives listed in step 3.12; `getent group sshusers` contains `tvolodi` and `root`; both drop-in files present, mode 644; backup directory `/var/backups/pre-T0134.*` exists; cloud-init's `50-cloud-init.conf` unchanged.

**External:**
- TCP-level dual-signature probe (NOT an HTTP status check — nothing will be listening on 80/443 after this task, by design; app deploy is out of scope): compare `preflight-0-6-tcp{80,443}-before.txt` (slow/timeout — Hetzner-firewall-dropped) against a post-change re-run of the same `Measure-Command { Test-NetConnection ... }` probes (fast RST — Hetzner-firewall-permits, UFW-permits, no-listener). A fast-RST result confirms the firewall change is live; a continued slow-timeout result means it did not take effect.
- SSH: fresh (new-session) connection via `ssh ubuntu-16gb-nbg1-1` succeeds with key auth; `ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes ubuntu-16gb-nbg1-1 exit` is rejected with `Permission denied (publickey)`.
- Port 22 unaffected throughout: `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True` at every checkpoint.

---

### Resources used

- **Secrets (by name):**
  - `ai-dala-infra` SSH key (management workstation, ed25519) — used for all host SSH commands.
  - `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` — used for the Phase 2 Hetzner Cloud API calls.
  - No new secrets are created by this plan.
- **Files modified on host (`ubuntu-16gb-nbg1-1`):**
  - `/etc/apt/keyrings/docker.gpg`, `/etc/apt/sources.list.d/docker.list` (created)
  - `dpkg`/`apt` package database (Docker CE + Compose plugin installed)
  - `/etc/group` (`docker` group: `tvolodi` added; `sshusers` group: created, `tvolodi` + `root` added)
  - `/etc/ssh/sshd_config.d/40-disable-password.conf`, `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` (created)
  - `/var/backups/pre-T0134.<timestamp>/` (created — backup)
  - Conditionally, only if 1.12 fails: `/etc/ufw/after.rules` (appended) + `/var/backups/ufw-after.rules-pre-T0134.bak` (backup)
- **Files modified in this repo (`landscape/`) — to be applied at step 08, not by this plan's executor:**
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `role:` frontmatter (proposed value `letflow-app` — see Issues/risks), `last_verified` refresh, Access/sshd section rewrite, Hetzner Cloud Firewall section rule-set update, "What needs to happen" item 4 marked done, Docker install recorded, Change log entry.
  - `landscape/services.md` — `## ubuntu-16gb-nbg1-1` section: Docker status flipped to installed (engine/compose versions, empty "Running Compose projects" table — "no containers running yet" per T-0134's own acceptance criterion), systemd table updated with `docker.service`.
  - `landscape/secrets-inventory.md` — two new documentation-only rows (no values):
    - `ai-dala-infra-ssh-key` | ed25519 keypair for SSH access to Hetzner-provisioned hosts in project ai-qadam; public key fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8` | Private key `C:\Users\tvolo\.ssh\ai-dala-infra` on management workstation.
    - `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` | Hetzner Cloud API token, project-scoped read-write, used for Cloud Firewall rule management on project ai-qadam (15130993) | `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` on management workstation.
- **External APIs called:** `api.hetzner.cloud` (Phase 2); `download.docker.com` and `registry-1.docker.io` (Phase 1, package + hello-world image fetch); `api.ipify.org` (Phase 1.12 egress test, and reused for the Phase 0/2 outbound-IP pattern if needed).

### Estimated impact

- **Downtime:** none for any existing service — this host runs no application workloads yet (fresh cloud image). `systemctl reload ssh` (SIGHUP) preserves the active session; the Hetzner Cloud Firewall `set_rules` action is applied atomically with no window of total lockout (the 22 rule is present in the new rule set throughout).
- **Affected services:** `sshd` (hardened), `docker` (newly installed and started), Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (rule set expanded). No other running service is touched.
- **Reversibility:** fully reversible. Docker: clean apt removal, no data to lose. Firewall: single API call back to the Phase 0.5 snapshot. sshd: drop-in removal + reload, with a full `/etc/ssh` backup as a last resort; `sshd -t` and group-membership hard gates prevent ever reloading into a broken/locking config in the first place.

## Issues / risks

- **HIGH — sshd lockout risk (Phase 3).** `AllowGroups sshusers` denies all SSH logins to anyone not in that group at reload time. Mitigated by two hard gates (3.8 `sshd -t`, 3.9 `id tvolodi | grep sshusers`) that abort before reload if either fails, by keeping the executing session open throughout, and by the Hetzner Cloud Console being a confirmed (unlike prod) out-of-band recovery path for this specific host. This is the primary driver, alongside the task's own declared `medium` blast radius, of the `NEEDS_APPROVAL` verdict.
- **MEDIUM — sshd hardening exceeds T-0134's literal 2-directive acceptance criteria.** Design decision (a) applies the full ~10-directive T-0093/T-0102 pattern instead of just `PasswordAuthentication no` + `PermitRootLogin prohibit-password`. Precedent (T-0093) did the same against a similarly narrow prompt without issue, but flagging explicitly here per step 03's instruction — the user should confirm this is wanted, not merely tolerated, during this approval gate.
- **MEDIUM — 80/443 CIDR is an inference, not a literal instruction.** `0.0.0.0/0` + `::/0` was chosen by analogy with the existing world-open UFW rule and the host's future public-web-traffic purpose. If the user intended a narrower scope (e.g., Cloudflare-only ranges, pending the follow-on DNS task), object now — reverting to a narrower CIDR later is a one-line `set_rules` change either way.
- **LOW/INFORMATIONAL — `POST .../actions/set_rules` body shape is inferred, not previously exercised in this repo.** Unlike `apply_to_resources` and `change_protection` (both debugged through prior attempts in `2026-06-27-apply-hetzner-firewall-001` and now known-good), `set_rules` has no prior run history here. The `rules` field name and per-rule schema (`direction`/`protocol`/`port`/`source_ips`/`description`) are the same shape already proven for firewall creation (`POST /v1/firewalls`), which is strong but not conclusive evidence. If the API rejects the body with a 4xx, the executor must capture the error verbatim and treat it as a `FAIL` requiring a redesign — not an improvised retry (matching the discipline established, after some early missteps, in the `apply_to_resources` precedent).
- **LOW — Docker/UFW `after.rules` decision (b) is conditional, not guaranteed.** If the live egress test (1.12) fails, the plan falls back to a discovery step (1.13a, live interface-name lookup) before writing any `after.rules` content — deliberately not assuming `eth0` even though that's the Hetzner convention on this fleet so far.
- **LOW — proposed `role: letflow-app` value is a designer's proposal, not dictated by any input file.** T-0134 requires *some* role value be set but does not name one. Chosen for consistency with the fleet's existing `<app>-<purpose>` convention (`ai-qadam-qa`, `penpot-prod`). User may prefer a different string (e.g., `letflow`, `letflow-host`) — low-cost to change at step 08 if flagged during this approval.
- **INFORMATIONAL — 51-day-stale landscape snapshot.** Addressed structurally: Phase 0 re-derives every fact this plan depends on (sshd state, UFW/after.rules state, Docker absence, live firewall rule set) from the host/API directly rather than trusting the 2026-06-27 documentation, and Phase 2 explicitly requires using Phase 0.5's live values over this document's copy when constructing the `set_rules` body.
- **INFORMATIONAL — this plan does not touch `shared/app-registry.md`, Cloudflare DNS, or nginx.** Correctly out of scope per T-0134's own "Why" section (explicitly deferred to a not-yet-created follow-on task); called out here only to confirm the boundary was respected, not crossed.
