---
run_id: 2026-07-11-discovery-pro-data-tech-prod-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0101-add-pro-data-tech-prod-to-inventory
inputs_read:
  - runs/2026-07-11-discovery-pro-data-tech-prod-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/README.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Proceed to step 03 (task-validator) — no landscape blockers. Executor-discovery should verify .ppk key format before first SSH attempt and watch for Docker/service surprises vs. the QA baseline.
---

## Summary

The target host `95.46.211.224` (`pro-data-tech-prod`) has **no existing landscape file** — this is a first-time discovery run. The sister host `pro-data-tech-qa` (`95.46.211.230`, `last_verified: 2026-07-10`) provides a strong baseline for comparison: it is a KVM/QEMU Ubuntu 26.04 LTS (kernel `7.0.0-27-generic`) instance at the same pro-data.tech provider on the same `/25` subnet, with a hardened sshd, UFW, fail2ban, auditd, three operator accounts, and Docker (29.6.1) running the `ai-qadam-test` postgres compose project. The prod host is expected to be a fresh cloud image with none of those project-managed configurations applied yet. `services.md` (`last_verified: 2026-07-10`) has no entry for `pro-data-tech-prod`; the executor-discovery run will create both `landscape/hosts/pro-data-tech-prod.md` and the matching `services.md` entry. Both landscape files are current (last verified 1 day ago); no staleness issues exist.

## Details

### Relevant facts (sourced from landscape)

- **Target host landscape file:** does not exist — `landscape/hosts/pro-data-tech-prod.md` is absent; this discovery run is its first creation. — _source: step-01-task-reader.md_
- **IP / subnet:** `95.46.211.224`, subnet `95.46.211.224/25` (same `/25` as QA host `95.46.211.230`). — _source: `runs/2026-07-11-discovery-pro-data-tech-prod-001/step-01-task-reader.md`_
- **Provider:** pro-data.tech (NOT Hetzner). No Hetzner Cloud Firewall, no Hetzner API, no Hetzner Backups. Provider may or may not offer a control-plane firewall. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **Virtualization (QA reference):** KVM/QEMU (`qemu-guest-agent.service` active on QA). Prod expected to be the same. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **SSH access pattern (QA reference):** `ssh -i C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk root@95.46.211.230`. The `.ppk` extension is misleading — file is OpenSSH RSA format (`-----BEGIN RSA PRIVATE KEY-----`). Prod key follows the same naming convention: `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk`. — _source: `landscape/hosts/pro-data-tech-qa.md`; `step-01-task-reader.md`_
- **QA OS / kernel:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`), kernel `7.0.0-27-generic` (post-T-0099 reboot 2026-07-10). — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **QA hardware profile:** 8 vCPU, 15 GiB RAM, 145 GB root disk. Provider plan not labelled in-host; confirm in pro-data.tech control panel. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **QA sshd hardening:** `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, `AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`, hardened KEX/Ciphers/MACs (no SHA-1, no CBC/3DES/RC4), drop-ins `40-disable-password.conf` and `40-ai-dala-infra.conf`. None of this is expected to be present on the fresh prod host. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **QA UFW state:** active, deny-inbound, allow 22/tcp (v4+v6), `DEFAULT_FORWARD_POLICY="ACCEPT"`. Installed via T-0094. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **QA fail2ban:** active sshd jail, `maxretry=3`, `bantime=600s`, `findtime=600s`, `banaction=iptables-multiport`. Installed via T-0095. — _source: `landscape/services.md`_
- **QA auditd:** active, project CIS-derived ruleset (15 keys, 67 kernel rules), kernel `CONFIG_AUDIT=y` built-in. Installed via T-0096. — _source: `landscape/services.md`_
- **QA operator users:** `tvolodi` (uid 1001), `viktor_d` (uid 1002), `binali_r` (uid 1003), all in `sshusers` group, NOPASSWD sudo, key-only. Provisioned via T-0097. None expected on the prod host yet. — _source: `landscape/hosts/pro-data-tech-qa.md`_
- **QA Docker:** Docker Engine 29.6.1, Compose v5.3.1, running `ai-qadam-test` compose project (one container: `ai-qadam-test-db-1`, image `pgvector/pgvector:pg16`, loopback `127.0.0.1:3112→5432`). — _source: `landscape/services.md`_
- **services.md pro-data-tech-prod entry:** absent — no entry exists for the prod host. — _source: `landscape/services.md`_
- **QA provider-assigned hostname:** `drkkrgm-qa-instance`. Prod hostname is unknown; likely a similar provider-generated name. — _source: `landscape/hosts/pro-data-tech-qa.md`_

### Stale or stub files encountered

- None. `landscape/hosts/pro-data-tech-qa.md` — `last_verified: 2026-07-10`, `status: populated` (1 day ago, within 30-day window). `landscape/services.md` — `last_verified: 2026-07-10`, `status: populated` (1 day ago, within 30-day window).

### Gaps requiring live discovery

1. **OS version and kernel on prod** — assumed Ubuntu 26.04 / kernel `7.0.0-x` (same provider, same image catalogue), but not confirmed. Executor must run `lsb_release -a` and `uname -r`.
2. **Prod hardware profile** — vCPU count, RAM, disk size unknown; may differ from QA's 8 vCPU / 15 GiB / 145 GB if a different plan was selected.
3. **Prod provider-assigned hostname** — unknown; executor should capture `hostname -f`.
4. **Docker pre-installed?** — QA received Docker via T-0090 (explicitly installed by the project). If prod was provisioned from the same base image, Docker is probably NOT pre-installed; verify with `docker version` / `which docker`.
5. **Current UFW state** — likely unconfigured (cloud-init default); executor must run `ufw status`.
6. **fail2ban presence** — almost certainly absent on a fresh image; verify with `systemctl status fail2ban`.
7. **auditd presence** — almost certainly absent; verify with `systemctl status auditd`.
8. **sshd effective config** — cloud-init default `PasswordAuthentication` state and `PermitRootLogin` mode are not yet known; executor must run `sshd -T | grep -E 'passwordauth|permitrootlogin|allowgroups'`.
9. **Authorized SSH key on root** — provider key fingerprint and comment unknown; executor must cat `/root/.ssh/authorized_keys`.
10. **Running services / open ports** — full `ss -tlnp` and `systemctl list-units --state=running` not yet captured for prod.
11. **IPv6 assignment** — pro-data.tech may or may not assign IPv6; `ip -6 addr` needed.
12. **Provider-level firewall** — whether pro-data.tech has an external firewall panel for this host is unknown (same ambiguity as QA). Prod executor should test ports 80 and 443 from the management workstation to assess exposure, as was done for QA.
13. **`pro-data.tech-prod-instance_rsa.ppk` format** — step-01 noted this follows the same `.ppk`-but-actually-OpenSSH convention as the QA key, but it has not yet been verified by a successful SSH session. Executor must confirm with `head -1 C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` before first connection attempt.

## Issues / risks

- **Subnet collision risk:** Both QA (`95.46.211.230`) and prod (`95.46.211.224`) are on the same `/25`. Executor must double-check the `-i` key path and destination IP on every SSH command to avoid accidentally running probes against the QA host.
- **`.ppk` key format unverified:** The prod SSH key shares the misleading `.ppk` naming convention of the QA key. Until the first connection succeeds, treat as unverified. If the SSH attempt fails with a key-format error, the executor should inspect the file header for `-----BEGIN RSA PRIVATE KEY-----` or `-----BEGIN OPENSSH PRIVATE KEY-----` and adjust the `-i` flag accordingly.
- **Unknown service state:** Because this is a brand-new host with no prior inventory entry, the executor should treat every probe result as potentially surprising (e.g., Docker pre-installed by the provider, or a non-standard sshd config baked into the image).

## Open questions

none
