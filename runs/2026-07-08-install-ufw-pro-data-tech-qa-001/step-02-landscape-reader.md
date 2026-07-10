---
run_id: 2026-07-08-install-ufw-pro-data-tech-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0094-install-local-baseline-firewall-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-install-ufw-pro-data-tech-qa-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/hosts/hetzner-prod.md
  - landscape/README.md
  - tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md
artifacts_read:
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - tasks/T-0083-configure-ufw-on-ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
  - .claude/agents/landscape-reader.md
next_step_hint: Pass to task-validator (step 03).
---

## Summary
The host `pro-data-tech-qa` (95.46.211.230, Ubuntu 26.04, kernel 7.0.0-14-generic) is freshly leased, has no project services, and currently sits with **no host-level firewall**: `ufw` is installed (binary at `/usr/sbin/ufw`) but `Status: inactive`; `nft list ruleset` returns empty; `iptables` and `ip6tables` are at `policy ACCEPT` with no rules (per discovery run `2026-07-08-discovery-pro-data-tech-qa-001`, probe F). The only public-internet-exposed service today is `sshd` on 0.0.0.0:22 (post-T-0093 hardened: `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `AllowGroups sshusers`). The pro-data.tech provider has no Hetzner Cloud Firewall analogue, so UFW is the only packet filter in the network path. The user decision of 2026-07-08 is: enable UFW with `default deny incoming`, `default allow outgoing`, `default forward ACCEPT`, `IPV6=yes`, and a single `ufw allow 22/tcp` (no source-IP filter). The sibling `hetzner-prod` provides the reference UFW pattern (ruleset, DEFAULT_FORWARD_POLICY, IPv6 yes, persistence-across-reboot verification). IPv6 link state on `pro-data-tech-qa` was **not** enumerated in discovery and remains a small live-discovery gap for the executor to confirm before relying on `IPV6=yes`.

## Current host network state

From discovery run `2026-07-08-discovery-pro-data-tech-qa-001` (verified 2026-07-08) — the canonical network facts:

- **Public IPv4:** `95.46.211.230` (provider: pro-data.tech). — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **IPv6:** "not enumerated in the discovery probes; provider may or may not assign one — verify in the pro-data.tech control panel." — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **Cloudflare proxied:** no. The pro-data.tech provider manages its own networking; no A/AAAA records to reconcile. `landscape/cloudflare.md` and `landscape/domains.md` cover only Hetzner-backed `ai-dala.com` / `bizdala.com`. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **Provider-level firewall:** **unknown** (and intentionally not used per project policy). Per README § Backups & storage policy, paid provider add-ons are out of scope; even if a paid pro-data.tech firewall product exists, it should be **disabled in favor of a host-level firewall** (this task, T-0094). — _source: `landscape/hosts/pro-data-tech-qa.md` + `landscape/README.md`_
- **Host firewall (UFW):** **inactive** (`Status: inactive`). Installed at `/usr/sbin/ufw`. cloud-init leaves it disabled. This is the primary T-0094 finding. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **nftables:** present; `nft list ruleset` returns empty (no rules loaded). — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **iptables (IPv4 + IPv6):** all chains default `policy ACCEPT`; no rules. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **External probe:** the discovery run did **not** run a `Test-NetConnection` from the management workstation; SSH reachability was confirmed by `ssh root@95.46.211.230` succeeding for all 14 probes. — _source: `landscape/hosts/pro-data-tech-qa.md`_

### Listening ports (as of 2026-07-08)

- **TCP on 0.0.0.0:** `22` (sshd, pid 28491) — **the only** public-internet-exposed service. Post-T-0093 hardened: key-only auth, `AllowGroups sshusers`. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **TCP on 127.0.0.1 only:** `127.0.0.53:53` and `127.0.0.54:53` (systemd-resolved stub). No app ports bound. **No 80/443, no Docker-published ports, no app server.** — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **UDP:** `127.0.0.53:53` and `127.0.0.54:53` (systemd-resolved), `127.0.0.1:323` and `[::1]:323` (chronyd). — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **Effective exposure today:** SSH port 22 is the only public-internet-exposed service. There is no host-level filter between the provider's network (if any) and sshd. — _source: `landscape/hosts/pro-data-tech-qa.md`_

### systemd-resolved / NetworkManager

- `systemd-resolved.service` is **active** (Local DNS stub on 127.0.0.53 / 127.0.0.54). — _source: `landscape/hosts/pro-data-tech-qa.md`_
- NetworkManager: not enumerated in the discovery probe (Ubuntu 26.04 cloud images typically use `systemd-networkd` + `networkd-dispatcher`; both `systemd-networkd.service` and `networkd-dispatcher.service` are present per the systemd units table). — _source: `landscape/hosts/pro-data-tech-qa.md`_

## UFW readiness

From discovery run + T-0094 acceptance criteria:

- **UFW binary:** present at `/usr/sbin/ufw`. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **UFW service state:** `Status: inactive` (cloud-init default). — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **`/etc/ufw/` directory:** not enumerated in the landscape. The user-provided probe list includes `ls -la /etc/ufw 2>&1 | head -5` to confirm a clean slate. **Live-discovery gap.** — _source: user-instructed probe list, not yet executed_
- **`/etc/default/ufw` contents:** not yet read. Per T-0094 acceptance criteria, executor will need to (a) back up to `/etc/default/ufw.bak` (mode 0644, owner root:root), (b) ensure `IPV6=yes`, (c) confirm `DEFAULT_INPUT_POLICY="DROP"`, `DEFAULT_OUTPUT_POLICY="ACCEPT"`, `DEFAULT_FORWARD_POLICY="ACCEPT"`, `DEFAULT_APPLICATION_POLICY="SKIP"`. **Live-discovery gap.** — _source: `tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md`_
- **`ufw` package version:** not yet captured in landscape. **Live-discovery gap.** — _source: user-instructed probe list (`apt-cache policy ufw | head -10`)_
- **netplan config:** not yet captured in landscape (user-provided probe: `ls -la /etc/netplan/`). **Live-discovery gap.** — _source: user-instructed probe list_

## iptables / ip6tables current state

- All chains default `policy ACCEPT`; no rules. (Confirmed for both v4 and v6.) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- This is a **clean slate**: enabling UFW will start from no rules, no chains managed by other tools, no Docker iptables chains, no fail2ban iptables chains (fail2ban not yet installed — T-0095).

## IPv6 link status

- **Not enumerated in discovery.** The `landscape/hosts/pro-data-tech-qa.md` entry under "Hardware & OS" states: "**IPv6:** not enumerated in the discovery probes; provider may or may not assign one — verify in the pro-data.tech control panel." — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Implication for T-0094: setting `IPV6=yes` in `/etc/default/ufw` is harmless if no IPv6 link is present (rules apply to a non-existent address family silently). However, the executor should confirm via `ip -6 addr show` whether the link is up at all — if it is up but not routed by the provider, the IPv6 allow rule for 22/tcp will accept traffic on a non-routable link, which is benign. — _source: risk-flag from step-01_
- The user's risk list notes: **"Tunneled IPv6 risk — if `IPV6=yes` is set but the provider only ships IPv4 link, rules apply to a non-existent address family silently. Step 02 should check `ip -6 addr` output."** — _source: `runs/.../step-01-task-reader.md` (issues/risks section)_

## Reference pattern from hetzner-prod

From `landscape/hosts/hetzner-prod.md` (verified 2026-07-08; this is the canonical pattern for both `ubuntu-16gb-nbg1-1` and the upcoming `pro-data-tech-qa`):

- **UFW active since 2026-05-12** (run `2026-05-12-add-host-firewall-001`). — _source: `landscape/hosts/hetzner-prod.md`_
- **Defaults:** `default deny incoming`, `default allow outgoing`, `DEFAULT_FORWARD_POLICY="ACCEPT"` (preserved for Docker FORWARD chain). — _source: `landscape/hosts/hetzner-prod.md`_
- **IPv6:** enabled (`IPV6=yes`); rules installed in matched v4+v6 pairs. — _source: `landscape/hosts/hetzner-prod.md`_
- **Ruleset (as of 2026-05-26):** deny incoming (default), allow outgoing (default), allow 22/tcp (v4+v6), allow 80/tcp (v4+v6), allow 443/tcp (v4+v6), allow 2222/tcp (v4+v6), allow 21115/tcp (v4+v6), allow 21116/tcp (v4+v6), allow 21116/udp (v4+v6), allow 21117/tcp (v4+v6), allow 21118/tcp (v4+v6), allow 21119/tcp (v4+v6). — _source: `landscape/hosts/hetzner-prod.md`_
- **Persistence across reboot:** verified live ("Rules confirmed to survive reboot"). — _source: `landscape/hosts/hetzner-prod.md`_
- **Docker UFW bypass:** documented. "Docker-published ports bypass UFW via iptables DOCKER chain. Port 5678 (n8n) confirmed reachable from off-host despite UFW active deny. Ports bound to `0.0.0.0` in Compose files are NOT protected by UFW alone — see T-0003, T-0004 for the correct fix (bind to 127.0.0.1 in Compose)." — _source: `landscape/hosts/hetzner-prod.md`_
  - **Implication for `pro-data-tech-qa`:** Docker is not yet installed, so no Docker UFW bypass exists today. But when T-0090 (ai-qadam QA prep) installs Docker, the same caveat applies — future projects on this host must bind to 127.0.0.1 in Compose. The landscape-updater (step 08 of a future run) should capture this.
- **Hetzner Cloud Firewall** (`firewall-1`, id=10145783) is the **outer** filter on hetzner-prod; this **has no analogue on pro-data-tech-qa**. UFW here is the **only** filter. — _source: `landscape/hosts/hetzner-prod.md` + `landscape/hosts/pro-data-tech-qa.md`_

### Sibling UFW precedent: `ubuntu-16gb-nbg1-1` (T-0083)

- **Configured 2026-06-27** via run `2026-06-27-configure-ufw-001` / T-0083. — _source: `landscape/services.md`_
- `ufw.service` row in services.md: "**Enabled and active** — deny-by-default + allow 22/80/443 (v4+v6), `DEFAULT_FORWARD_POLICY="ACCEPT"` preserved for Docker parity". — _source: `landscape/services.md`_
- Sibling task pattern explicitly referenced by T-0094 ("Sibling task pattern: T-0083 is the closest analog — same UFW baseline, same `DEFAULT_FORWARD_POLICY="ACCEPT"` reasoning, same persistence-across-reboot verification pattern"). — _source: `tasks/T-0094-install-local-baseline-firewall-on-pro-data-tech-qa.md`_

## Risks flagged

These are the risks enumerated by the user-instructed task prompt and by step-01's risk section; restated for the designer's attention:

1. **No outer cloud firewall** — pro-data.tech provider does not have a Cloud Firewall equivalent. UFW is the only packet filter. A misconfiguration (e.g. forgetting `default deny incoming`) would be the only line of defense. Executor must verify the active ruleset post-`ufw enable` rather than trust the configure step alone. — _source: `runs/.../step-01-task-reader.md` (issues/risks) + `landscape/hosts/pro-data-tech-qa.md`_
2. **IPv6 link unknown** — should UFW handle IPv6 too? Check default `/etc/default/ufw` setting (`IPV6=yes` recommended). If `IPV6=yes` is set but the provider only ships IPv4 link, rules apply to a non-existent address family silently. The `ip -6 addr show` output was not captured in discovery; the executor must confirm live. — _source: `runs/.../step-01-task-reader.md` + `landscape/hosts/pro-data-tech-qa.md`_
3. **DEFAULT_FORWARD_POLICY="ACCEPT" activation** — currently a no-op (ip_forward=0) but will activate the moment Docker (or any other forwarder) is installed. Acceptable per task, but the landscape file should note this clearly so future runs do not treat it as a bug. — _source: `runs/.../step-01-task-reader.md` + `landscape/hosts/hetzner-prod.md` (Docker UFW bypass section)_
4. **Lockout risk** — only one inbound port open (22), and sshd is hardened. UFW changes are reversible. Mitigated by (a) T-0093 hardening (`AllowGroups sshusers` + `PermitRootLogin prohibit-password` + `PasswordAuthentication no`), (b) the break-glass provider key still in `/root/.ssh/authorized_keys` (untouched, 1 line, comment `rsa-key-20260707`), (c) all three operator users (`tvolodi`/`viktor_d`/`binali_r`) in `sshusers` group with NOPASSWD sudo. **If UFW enable somehow drops port 22, recovery path is Hetzner-style web console (pro-data.tech equivalent) or provider-side VNC.** — _source: `landscape/hosts/pro-data-tech-qa.md` (Access + Security posture) + T-0093 + T-0097_
5. **Tunneled IPv6 risk** — see risk #2. Confirmed via provider-control-panel gap, not via in-host data. — _source: `runs/.../step-01-task-reader.md` (issues/risks)_
6. **Reboot test in a remote workflow** — persistence verification requires SSH-after-reboot, which means the operator must have access post-reboot. The sshusers / non-root users from T-0097 / T-0093 are in place to make this safe, but the executor should explicitly stage a re-connect plan before rebooting. — _source: `runs/.../step-01-task-reader.md` (issues/risks)_

### Additional landscape-level risks surfaced (not in user's enumerated list)

7. **Future Docker UFW bypass** — when T-0090 lands Docker on this host, Docker-published ports will bypass UFW via iptables DOCKER chain (per hetzner-prod precedent). This is not a problem for T-0094 itself (only 22/tcp is open), but the landscape-updater (step 08) should add a `## Network` note that future Compose projects on this host must bind to 127.0.0.1 — same as hetzner-prod guidance. — _source: `landscape/hosts/hetzner-prod.md`_
8. **`fail2ban` is NOT installed** (T-0095 queued). UFW alone does not stop a brute-force SSH scan; the user's defense-in-depth model (UFW + AllowGroups sshusers + fail2ban) requires fail2ban to be installed for the 22/tcp allow rule to be acceptable. This is a sequencing concern, not a T-0094 blocker — the user's decision explicitly accepts UFW without fail2ban for now. — _source: `landscape/hosts/pro-data-tech-qa.md` + `tasks/T-0094-...md`_

## Stale or stub files encountered

- `landscape/hosts/pro-data-tech-qa.md` — `last_verified: 2026-07-08` (today). `status: populated`. **Not stale** (under 30-day threshold).
- `landscape/services.md` — `last_verified: 2026-07-08` (today). `status: populated`. **Not stale**. Note: the `## pro-data-tech-qa` section in `services.md` was added by run `2026-07-08-discovery-pro-data-tech-qa-001` and confirmed by runs on 2026-07-08 (`2026-07-08-harden-sshd-pro-data-tech-qa-001` and `2026-07-08-create-operator-users-pro-data-tech-qa-001`).
- `landscape/hosts/hetzner-prod.md` — `last_verified: 2026-07-08` (today). `status: populated`. **Not stale**.
- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — last_verified date not extracted; sibling UFW precedent. **Not stale** (within 30 days based on services.md history rows showing 2026-06-27 activity).
- `landscape/README.md` — no `last_verified` field in frontmatter; treated as evergreen. **Not stale**.

## Gaps requiring live discovery

Items the user-instructed task prompt provided as SSH probes; the landscape-reader agent role is read-only and did not execute them. The executor (step 05) or a dedicated discovery sub-step should run these to confirm the design assumptions. None of the gaps are blocking for design — they all have safe fallbacks documented above.

1. **`which ufw`, `dpkg -l | grep -i ufw`, `apt-cache policy ufw | head -10`** — confirm `ufw` package version and that it is in fact installed (landscape says yes; this is a low-cost confirmation).
2. **`iptables -L -n -v --line-numbers 2>&1 | head -50`** — confirm v4 chain state matches "all ACCEPT, no rules".
3. **`ip6tables -L -n -v --line-numbers 2>&1 | head -30`** — confirm v6 chain state matches "all ACCEPT, no rules".
4. **`ip -6 addr show | grep -E "inet6|scope"`** — confirm whether IPv6 link is up at all. The landscape does not capture this. If no global-scope IPv6, `IPV6=yes` rules will be silently inert.
5. **`ss -tlnp 2>&1` or `netstat -tlnp 2>&1`** — confirm listening ports match landscape (22 on 0.0.0.0; 127.0.0.53/54 on 127.0.0.1; nothing else).
6. **`systemctl is-active systemd-resolved` / `systemctl is-active NetworkManager`** — confirm systemd-resolved active (already documented in landscape; NetworkManager is not enumerated).
7. **`ss -ulnp 2>&1 | head -20`** — confirm UDP listeners (chronyd 323, systemd-resolved 53, both loopback).
8. **`ls -la /etc/ufw 2>&1 | head -5`** — confirm clean-slate `/etc/ufw/` directory exists.
9. **`ls -la /etc/netplan/ 2>&1`** — confirm netplan config files; may want to preserve during UFW enable (cloud-init netplan coexists with UFW on Ubuntu).
10. **`ss -tlnp | grep -E ":22|sshd"`** — confirm sshd listening state post-T-0093 (lands on 0.0.0.0:22 per landscape).
11. **`cat /etc/default/ufw`** — read current contents to plan the diff (IPV6=yes, default policies, application policy).
12. **`apt-cache policy ufw | head -10`** — confirm package version and upgrade availability.
13. **`systemctl is-enabled ufw.service`** — confirm whether the ufw.service unit is enabled in systemd (cloud-init may have it masked, disabled, or static).

The landscape-reader has **deliberately not executed these commands** in keeping with the agent role's "Do NOT run any command against managed hosts" rule. The orchestrator (or the executor in step 05) should fold them into the executor's pre-change probe set.

## Issues / risks

- **Conflict between user-instructed task and agent role:** The user-instructed task prompt includes a block of "Commands to run" via SSH (`ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk" ... root@95.46.211.230 '<cmd>'`). The landscape-reader agent role explicitly forbids running commands against managed hosts ("Do NOT run any command against managed hosts. You read files only."). This handoff honors the agent role; the live-discovery probes are listed under "Gaps requiring live discovery" for the executor or a dedicated sub-step to run. **The orchestrator should note this and either (a) re-route the live probes to a dedicated discovery sub-step, or (b) accept the landscape-only handoff and let the executor run the probes pre-flight as part of step 05/06.** No verdict is downgraded on this basis — the landscape data is sufficient to design T-0094, with the gaps clearly itemized.
- **No other issues** — the landscape is current, the host is in the expected state for T-0094 (UFW installed but inactive; iptables empty; only sshd listening; post-T-0093 hardening in place; operator users available for SSH-after-reboot).

## Recommendation: pass to step 03

The landscape provides enough context to design T-0094:

- The UFW baseline (deny in / allow out / forward accept / IPV6=yes / 22/tcp from any source) is unambiguous from T-0094 + step-01.
- The reference pattern from `hetzner-prod` (and the sibling `ubuntu-16gb-nbg1-1`) provides verified command sequences and persistence-across-reboot verification.
- The risks are itemized and have documented fallbacks.
- The live-discovery gaps (IPv6 link state, current `/etc/default/ufw` contents, package version, `ufw.service` enable state) are low-risk confirmation probes the executor can run pre-flight without changing the design.

**Verdict: PASS.** Pass to task-validator (step 03).
