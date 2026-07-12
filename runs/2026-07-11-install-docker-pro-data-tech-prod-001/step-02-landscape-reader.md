---
run_id: 2026-07-11-install-docker-pro-data-tech-prod-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0106-install-docker-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-docker-pro-data-tech-prod-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/pro-data-tech-qa.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — validate the task is well-scoped and the landscape supports safe design
---

## Summary

`pro-data-tech-prod` (95.46.211.224, Ubuntu 26.04) currently has no Docker and no Docker-related configuration. The security baseline is complete: UFW is active with `DEFAULT_FORWARD_POLICY="DROP"` (T-0103), sshd is hardened (T-0102), fail2ban is active (T-0104), and operator users `tvolodi` / `viktor_d` / `binali_r` are provisioned (T-0105). The QA host (`pro-data-tech-qa`, 95.46.211.230) provides a verified installation precedent: Docker 29.6.1 from the official apt repo, Compose plugin v5.3.1, and all three operator users in the `docker` group. The critical divergence is that QA resolved UFW/Docker iptables coexistence by flipping `DEFAULT_FORWARD_POLICY` to `ACCEPT`; this task (T-0106) explicitly forbids that approach and requires the `/etc/ufw/after.rules` DOCKER-USER chain method instead, keeping `DEFAULT_FORWARD_POLICY="DROP"`.

## Details

### Relevant facts (sourced from landscape)

**pro-data-tech-prod current state:**
- No Docker installed, no `/etc/docker/daemon.json`, no `docker0` bridge interface — _source: `landscape/hosts/pro-data-tech-prod.md`_
- OS: Ubuntu 26.04 LTS (`VERSION_CODENAME=resolute`); kernel `7.0.0-14-generic` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- UFW: **active**, `DEFAULT_FORWARD_POLICY="DROP"` (set by T-0103), default deny incoming, allow outgoing — _source: `landscape/hosts/pro-data-tech-prod.md`_
- UFW open rules: 22/tcp, 80/tcp, 443/tcp ALLOW IN (v4+v6). No custom rules beyond these — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Pre-T-0103 UFW backup exists at `/var/backups/ufw-defaults-pre-T0103.bak` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Network interfaces: `eth0` (95.46.211.224/25, public), `eth1` (192.168.0.3/24, private LAN — not present on QA) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- `tvolodi` (uid 1000) is provisioned with NOPASSWD sudo, member of `sudo` and `sshusers` groups; NOT yet in `docker` group (group does not exist without Docker) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- SSH primary: `tvolodi@95.46.211.224`; management key `C:\Users\tvolo\.ssh\ai-dala-infra` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- nftables ruleset: empty (UFW uses iptables/ip6tables) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- No provider-level firewall (pro-data.tech exposes none) — _source: `landscape/hosts/pro-data-tech-prod.md`_
- 12 pending package upgrades outstanding (non-blocking for this task) — _source: `landscape/hosts/pro-data-tech-prod.md`_

**QA reference (T-0090 precedent):**
- Docker 29.6.1 (build `8900f1d`) installed via official Docker apt repository, containerd runtime — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Docker Compose plugin v5.3.1 — _source: `landscape/hosts/pro-data-tech-qa.md`_
- QA's `docker` group gid is 986 — _source: `landscape/hosts/pro-data-tech-qa.md`_
- `tvolodi`, `viktor_d`, `binali_r` all added to `docker` group on QA — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **Key divergence:** QA resolved UFW/Docker coexistence by flipping `DEFAULT_FORWARD_POLICY` to `ACCEPT` (T-0090 Phase A2); prod task T-0106 prohibits this and mandates the `/etc/ufw/after.rules` DOCKER-USER chain approach instead — _source: `landscape/hosts/pro-data-tech-qa.md`_

### Stale or stub files encountered

None. Both landscape files are current:
- `landscape/hosts/pro-data-tech-prod.md` — last_verified 2026-07-11 (today), status `hardened`
- `landscape/hosts/pro-data-tech-qa.md` — last_verified 2026-07-10 (yesterday), status `populated`

### Gaps requiring live discovery

1. **`/etc/ufw/after.rules` current content on prod** — the after.rules DOCKER-USER snippet must be appended without duplicating any existing content; the designer needs the exact current file state. Requires live SSH probe.
2. **`/etc/ufw/before.rules` current content on prod** — to confirm no existing MASQUERADE or FORWARD rules are present that could conflict with the new snippet.
3. **`docker0` bridge interface name post-install** — almost certainly `docker0` (Docker default), but the after.rules MASQUERADE rule targets a specific outbound interface; must be verified post-install before writing after.rules. Not discoverable from landscape.
4. **Impact of `eth1` (private LAN 192.168.0.3/24) on after.rules scope** — the QA host has no `eth1`. The MASQUERADE rule in after.rules typically targets outbound traffic on `eth0` only; prod has a second interface. The designer should explicitly scope the rule to `eth0` to avoid masquerading traffic bound for the private LAN.

## Issues / risks

- **UFW/Docker iptables coexistence is the highest-risk element.** The prod approach (after.rules DOCKER-USER) differs from QA (ACCEPT FORWARD). The after.rules snippet must be written **before** Docker is started for the first time, or containers will have no internet access. Execution order: install → write after.rules → `ufw reload` → `systemctl start docker`.
- **`eth1` private LAN interface** on prod (absent on QA) means a naive copy of QA's after.rules pattern could masquerade traffic toward the private LAN through `eth0`. The designer must scope masquerade to `-o eth0` explicitly.
- **`tvolodi` is not yet in the `docker` group** (group does not exist pre-Docker). This is expected; the group is created by the Docker package install and `tvolodi` must be added post-install. No session disconnect required for sudo usage; interactive shell would need a new login for group membership to take effect.
- **12 pending package upgrades** are outstanding on prod (non-blocking for this task but worth noting; an `apt-get upgrade` before `apt-get install docker-ce` may pull in a newer kernel that requires a reboot — the designer should consider whether to defer package upgrades or accept them as part of this run).
- **Outbound port 443** from the host to Docker Hub (for `docker run hello-world`) must be unblocked. UFW default allow outgoing is active — this should be fine, but the Hetzner-side firewall analogue is unknown for pro-data.tech. Step 01 flagged this; worth confirming via a live connectivity probe during execution.
