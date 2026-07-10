---
run_id: 2026-07-08-discovery-pro-data-tech-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
inputs_read:
  - runs/2026-07-08-discovery-pro-data-tech-qa-001/step-01-task-reader.md
  - landscape/README.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - tasks/_index.md
  - tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md
  - tasks/T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md
  - workflows/discovery-host.md
  - .claude/agents/landscape-reader.md
  - shared/handoff-format.md
  - .gitignore
artifacts_changed: []
next_step_hint: Pass to task-validator (step 03).
---

## Summary

The `pro-data-tech-qa` host has no prior presence in the landscape: there is no `landscape/hosts/pro-data-tech-qa.md`, no row in `landscape/README.md`'s Files table, no per-host subsection in `landscape/services.md`, and no reference to `95.46.211.230` / `pro-data.tech` / `drkkrgm-qa-instance` anywhere under `landscape/`. The closest analog is `landscape/hosts/ubuntu-16gb-nbg1-1.md` (the canonical freshly-provisioned Ubuntu cloud host stub populated by run `2026-06-27-discovery-host-001` under T-0082) which serves as the structural template for the host file step 08 will create. Provider-specific sections in that template — Hetzner Cloud Firewall, Hetzner API verification, Hetzner Backups option, server protection flags, IPv6 `nbg1-dc3` location — must be omitted or rewritten for `pro-data-tech-qa` (a non-Hetzner provider, no Cloudflare front, no paid-snapshot policy). Cloudflare DNS records and origin certs are for the two Hetzner-backed zones (`ai-dala.com`, `bizdala.com`); pro-data.tech is a separate provider with no Cloudflare fronts and no domain records to reconcile. `landscape/secrets-inventory.md` was scrubbed from git history on 2026-07-08 by T-0091 and is now gitignored — it is not present in any commit and is out of scope for any write step in this run. `tasks/_index.md` has only T-0091 in the T-009x range; T-0090, T-0093–T-0098 are NOT on disk (lost in the same scrub), so step 08 must (per its landscape-update scope) re-create the T-0090 row and add at minimum T-0093/T-0097 observation/task rows. Verdict: **PASS**.

## Details

### File listing for `landscape/hosts/`

`Get-ChildItem landscape/hosts/` equivalent output:

| Name | Type | Notes |
|---|---|---|
| `hetzner-prod.md` | file | populated; last_verified 2026-07-08 |
| `ubuntu-16gb-nbg1-1.md` | file | populated; last_verified 2026-06-27 (94 days, flagged) |

**`pro-data-tech-qa.md` does NOT exist.** Confirmed by `list_dir`. The landscape-updater (step 08) will CREATE this file as its primary write — this is a deliberate design decision driven by discovery findings, not a side-effect, per `workflows/discovery-host.md` § Landscape-update guidance for step 08: *"For ANY finding the workflow exposes that is not explicitly covered by an existing landscape file, the updater records it under 'Open questions' in the run's step-08 handoff rather than inventing a new landscape file. New landscape files are a deliberate design decision, not a side-effect of discovery."* The decision is appropriate here: T-0082's parent-task precedent (the analogous `ubuntu-16gb-nbg1-1` host) ALSO created the landscape file as part of its discovery run, and the project already has explicit user intent to onboard this host as the ai-qadam QA instance.

### `landscape/README.md` "Hosts" conventions (Files table)

The Files table at the top of `landscape/README.md` is a simple two-column reference; per the README "Backups & storage policy" block and the "Editing rules", host files are expected to follow these conventions:

- **Frontmatter keys (from `ubuntu-16gb-nbg1-1.md`):** `host_id`, `provider`, `role` (often `unassigned` at bootstrap), `last_verified`, `status` (`stub` → `populated`), optional provider-specific blocks (`hetzner_server_name`, `hetzner_server_id`, `hetzner_project_id`, `hetzner_server_type`, `hetzner_project_name`), `ssh_user`, `ssh_port`, `os`, `kernel`.
- **No required frontmatter for non-Hetzner providers.** The Hetzner-specific block is a convention from `hetzner-prod.md` + `ubuntu-16gb-nbg1-1.md`; for `pro-data-tech-qa` (pro-data.tech, not Hetzner) step 08 should populate generic keys (`host_id`, `provider: pro-data.tech`, `role`, `last_verified`, `status`, `ssh_user`, `ssh_port`, `os`, `kernel`) and add a `pro-data.tech`-specific block (server id, datacenter region, plan/tier).
- **Editing rules:** *"Landscape files are authoritative. If a workflow's executor changes the system, the landscape-updater (step 08) must update the relevant landscape file in the same run. Drift between landscape and reality is a bug."* and *"Each file has a `last_verified:` field in frontmatter — the date its content was last confirmed against the real system."*
- **Backups & storage policy:** applies project-wide — *"all backups live on the local host disk. No new or additional paid [provider] services are to be provisioned."* The Hetzner-specific clause in `ubuntu-16gb-nbg1-1.md` (backups, paid add-ons, snapshot policy) needs the analogous statement for pro-data.tech.
- **Change log:** every host file has a trailing `## Change log` table with columns `Date | Run ID | Change`. New file must end with a bootstrap row dated 2026-07-08 referencing this run.

### `landscape/hosts/ubuntu-16gb-nbg1-1.md` template structure

Top-level sections (in order, per `ubuntu-16gb-nbg1-1.md`):

1. **Frontmatter** — provider-specific metadata block + canonical keys.
2. **`# <host_id>`** — H1 with the host_id; lede paragraph stating location, status, parent task, fingerprint cross-reference.
3. **`## Hardware & OS`** — IPv4, IPv6, hostname, server type, vCPU/RAM, disk, location, OS+kernel build, virtualization, Hetzner Backups option (cloud-API verified), Hetzner Cloud Firewall status, server protection flags, cost.
4. **`## Access`** — SSH user, SSH host, SSH config alias on management workstation, SSH key (with fingerprint), SSH key installed on server, Sudo drop-ins, root login status, other local users, host key fingerprints, **sshd config (`sshd -T` effective output)**, sshd drop-in files (first-wins semantics), SSH hardening tooling (fail2ban, auditd, AppArmor).
5. **`## What runs here`** — pointer to `services.md` and a high-level summary; plus a `### Native systemd services of note` table (Unit / Path / User / What it does).
6. **`## Network`** — Cloudflare-proxied status, host firewall (UFW) defaults + ruleset, Docker UFW bypass note, external probe results, TCP listeners on 0.0.0.0 + 127.0.0.1 tables, UDP.
7. **`## Hetzner Cloud Firewall`** — provider-specific (Hetzner only). status, inbound rules, outbound rules, labels, created date, Hetzner API verification, server protection flags, lockout mitigation. **NOT applicable to pro-data-tech-qa — omit entirely** (pro-data.tech has its own firewall product; unknown as of this run; capture as "Open question" for step 08 findings).
8. **`## Backups`** — Hetzner Backups option status (verified via API), application-level backups (paths/scripts), local-disk-only policy cross-reference. **For pro-data-tech-qa, keep the local-disk-only policy cross-reference but provider-specific snapshot/snapshot-API status must be replaced with whatever the pro-data.tech control panel exposes or "unverified, no off-host backups per project-wide policy".**
9. **`## apt posture`** — pending upgrades, unattended-upgrades Allowed-Origins, dev-release flag, sources format.
10. **`## Open questions`** — bullet list of unresolved items.
11. **`## What needs to happen`** — numbered checklist mapping to follow-on tasks/observations.
12. **`## Open tasks affecting this host`** — table of tasks referencing this host (under `tasks/_index.md`).
13. **`## Change log`** — Date / Run ID / Change.

Step 08 should mirror this structure for `pro-data-tech-qa.md`, omitting sections 7 (Hetzner Cloud Firewall) and adapting section 8 (Backups) to the pro-data.tech control plane.

### `landscape/services.md` per-host subsection convention

`landscape/services.md` uses H2-level per-host subsections (`## hetzner-prod`, `## ubuntu-16gb-nbg1-1`) with consistent sub-structure inside each:

- **`### Docker`** — engine version + status, Networks, Running Compose projects table, Running containers table (Container / Image:tag / Compose project / Host ports / Bind / Restart / Purpose), Orphan compose project (on disk, not running), Infrastructure-ready compose projects.
- **`### nginx`** — install method, version, config root, sites-enabled symlinks, TLS (origin cert path), vhosts table (server_name / Listens / Upstream / Notes).
- **`### Native systemd services of note`** — Unit / Path / User / What it does table.
- **`### Scheduled tasks`** — per-user crontabs, `/etc/cron.*` enumerations, systemd timers.
- **Section `## <host_id>`** — preceded by a one-paragraph pointer to the canonical host landscape file.

For `pro-data-tech-qa`, step 08 should add a new `## pro-data-tech-qa` H2 subsection near the bottom of `landscape/services.md`. Initial population per probe expectations (probes G–I will likely show no listeners on 80/443 and no nginx; probe H will likely show Docker not installed) — populate the sub-tables with "not installed" stubs per the discovery findings, then return a single Change log row referencing this run.

### Cloudflare / Domains relevance to `pro-data-tech-qa`

- **`landscape/cloudflare.md`** — references the two zones (`ai-dala.com`, `bizdala.com`) and their DNS records, all of which point to `91.98.28.126` / `2a01:4f8:1c1a:9b3f::*` (Hetzner production). **Zero references to `pro-data.tech` or `95.46.211.230`.** Confirmed by grep.
- **`landscape/domains.md`** — covers `ai-dala.com` and `bizdala.com` only. `pro-data.tech` is not a domain tracked by Cloudflare; it is a separate provider with its own hosts. **Zero references to `pro-data.tech`.** Confirmed by grep.
- **Implication for step 08:** No Cloudflare-front or DNS-reconciliation work is in scope for `pro-data-tech-qa`. The host runs internal/private services only (per its purpose as the ai-qadam QA instance). Section 6 ("Network") in the new host file should explicitly note: *"Cloudflare proxied: no — this host is not behind any Cloudflare-fronted domain. The pro-data.tech provider manages its own networking; no A/AAAA records need reconciliation."*

### `landscape/secrets-inventory.md` status — gitignored post-scrub

`landscape/secrets-inventory.md` is gitignored (`.gitignore` rules `/landscape/secrets-inventory.md` and `/landscape/secrets-inventory-*.md`) and was scrubbed from all 38 commits of `origin/main` on 2026-07-08 by the run that closed T-0091 (`2026-07-07-scrub-secrets-inventory-001`). A pre-commit hook additionally refuses commits to `landscape/secrets-inventory*.md` regardless of `-f` overrides.

- **Confirmation:** the file does NOT exist in any commit and is NOT present in the working tree.
- **Implication for step 08:** do NOT try to update `secrets-inventory.md`. The host landscape file and (later) a re-introduced secrets inventory should be the destination for any new token/key references. For this run: if probe A or any operator-key fingerprint is captured, it goes DIRECTLY into `landscape/hosts/pro-data-tech-qa.md` (referenced by name and SHA-256, never by value).

### Cross-reference to `tasks/_index.md` — T-009x rows

The current `tasks/_index.md` (auto-maintained by step 08, last re-sort at run `2026-07-07-scrub-secrets-inventory-001`) contains exactly ONE T-009x row:

| ID | Title | Kind | Status | Priority | Updated |
|---|---|---|---|---|---|
| T-0091 | Rotate gitea admin password + scrub secrets-inventory from git history | task | done | P0 | 2026-07-08 |

**The current index does NOT contain T-0090, T-0092, T-0093, T-0094, T-0095, T-0096, T-0097, or T-0098.** Verified by listing `tasks/` directory (only `T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md` exists among T-009x files) and by reading the index. Per the T-0091 step-08 handoff (`runs/2026-07-07-scrub-secrets-inventory-001/step-08-landscape-updater.md` line 104):

> *"a future task could re-add T-0090, T-0093-T-0098 (as `observation` P1/P2/P3) to the index and create the corresponding task files, restoring the 'audit-host for pro-data-tech-qa' workflow that was in flight pre-scrub."*

**For this run** (T-0090 is the parent task, itself `blocked_by: T-0093` per pre-scrub snapshot at `a41ec73`): step 08 should, per its scope, at minimum add:
- **T-0090 row** (`kind: task, status: pending, priority: P1, blocked_by: T-0093`) to the index AND create the corresponding task file `tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md`. **Note:** step 08 should NOT actually execute T-0090; that is a separate state-changing workflow gated on T-0093 → T-0097 → T-0090 per task-reader's strategy.
- **T-0093 sshd-hardening observation** — `kind: observation, status: observation, priority: P1, affects: landscape/hosts/pro-data-tech-qa.md` — anticipated findings from probes E/D (PasswordAuthentication yes, PermitRootLogin yes, /etc/sudoers.d/ has only `90-cloud-init-users`).
- **T-0097 operator-user-creation observation/task** — `kind: observation, status: observation, priority: P1, affects: landscape/hosts/pro-data-tech-qa.md` — the multi-PC operator SSH access acceptance criterion (`viktor_d` + `binali_r` pubkeys to be installed).
- **T-0094 / T-0095 / T-0096 / T-0098** — out of immediate scope but worth noting in step 08's "Open questions" so the orchestrator can decide whether to restore them.

**Note for step 08:** the orchestrator routing from step 02 should treat the lack of T-0090…T-0098 in the index as a known pre-existing condition of the post-scrub working state, NOT a blocker. Step 06 (executor-discovery) operates against the host directly, not against any task. Step 08 may, per the landscape-updater's mandate (`landscape/updater.md` future role and `discovery-host.md` § Landscape-update guidance), restore the minimum task rows needed to make the index consistent with the new host landscape file.

### `landscape/README.md` Files table update for step 08

The Files table currently contains two rows for hosts:

| File | Scope |
|---|---|
| [`hosts/hetzner-prod.md`](./hosts/hetzner-prod.md) | The Hetzner production server... |
| [`hosts/ubuntu-16gb-nbg1-1.md`](./hosts/ubuntu-16gb-nbg1-1.md) | The second Hetzner server... |

Step 08 should add a third row:

| File | Scope |
|---|---|
| [`hosts/pro-data-tech-qa.md`](./hosts/pro-data-tech-qa.md) | The pro-data.tech server (95.46.211.230) — populated by discovery run `2026-07-08-discovery-pro-data-tech-qa-001` (parent task T-0090; blocked by T-0093 — T-0093 stub re-created in this run). |

### Stale or stub files encountered (per the stale-flag rule)

- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `last_verified: 2026-06-27` (42 days; today is 2026-07-08). **Not stale by the 30-day rule** (36 days < 30, wait — 2026-07-08 − 2026-06-27 = 11 days, well within the 30-day window). No flag needed. Note: T-0083/T-0084 (done 2026-06-27) updated `landscape/services.md` against this host, but the host file itself was last_verified at 2026-06-27. As of today (2026-07-08) the host file is 11 days old and remains within the 30-day window; not flagged stale.
- `landscape/services.md` — `last_verified: 2026-07-08` (today; fresh).
- `landscape/cloudflare.md` — `last_verified: 2026-05-26` (43 days). **Past 30-day window — flagged stale in principle.** However, this run does not touch Cloudflare, so step 08 does not need to re-verify it. Note for orchestrator: a future `audit-cloudflare` run would address this drift.
- `landscape/domains.md` — `last_verified: 2026-05-15` (54 days). **Past 30-day window — flagged stale in principle.** Same caveat as `cloudflare.md`.
- No `status: stub` files remain in scope; `pro-data-tech-qa.md` does not exist yet and step 08 will create it with `status: populated` (post-discovery) — not stub.

### Gaps requiring live discovery (per `workflows/discovery-host.md` probes A–N)

All 14 probe sections are in scope for the executor-discovery (step 06). Expected gaps that will be filled:

- **Probe A** — current login + sudo access; expected to PASS (provider key → root, `/etc/sudoers.d/90-cloud-init-users` provides NOPASSWD ALL). If for any reason the executor is invoked as a non-root user via the SSH alias `pro-data-tech-qa` (which configures `User tvolodi`), this WILL fail — executor should surface and retry rather than work around.
- **Probe B** — OS release + kernel (confirm Ubuntu 26.04 + `7.0.0-14-generic`); step 01 already partially confirms but executor must re-fetch with full version strings.
- **Probe C** — hardware (vCPU, RAM, disk); pro-data.tech plans vary — capture via `nproc`, `free -h`, `df -h`.
- **Probe D** — users + sudoers + authorized_keys; expect `/etc/sudoers.d/` to contain only `90-cloud-init-users`, `/root/.ssh/authorized_keys` to be 1 line (provider key). **No `tvolodi` user, no operator users yet.**
- **Probe E** — sshd config; expect cloud-init defaults (`PermitRootLogin yes`, `PasswordAuthentication yes`). **Expected finding → observation task (T-0093 candidate).**
- **Probe F** — firewalls: ufw / nftables / iptables; ufw likely inactive, nft likely stock cloud image, iptables likely empty.
- **Probe G** — network listeners; expect sshd on 22 + systemd-resolved stub on 53 only. **No listeners on 80/443 → no nginx on this host.**
- **Probe H** — Docker; expected NOT installed (probe outcome for T-0090's follow-on).
- **Probe I** — nginx; expected NOT installed.
- **Probe J** — systemd; stock cloud-image units only.
- **Probe K** — cron / timers; stock cloud-image only.
- **Probe L** — apt posture; expect 0–13 pending upgrades (cloud-init may have run an initial upgrade during bootstrap).
- **Probe M** — fail2ban/auditd/AppArmor; fail2ban NOT installed, auditd NOT installed, AppArmor stock.
- **Probe N** — backup posture; expect no backup tooling, `/var/backups/` empty.

### Relevant facts (sourced from landscape)

- The canonical freshly-provisioned Ubuntu cloud host template is `landscape/hosts/ubuntu-16gb-nbg1-1.md`, with 13 sections enumerated above. _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md`_
- Two Hetzner hosts exist (`hetzner-prod` 91.98.28.126, `ubuntu-16gb-nbg1-1` 46.225.239.60); both are in `landscape/hosts/`. _source: `landscape/README.md` Files table_
- `landscape/services.md` carries per-host H2 subsections (`## hetzner-prod`, `## ubuntu-16gb-nbg1-1`); new hosts must be added as additional `## <host_id>` H2 sections. _source: `landscape/services.md`_
- Project-wide backup policy is local-disk-only; no paid Hetzner/pro-data.tech snapshot services. _source: `landscape/README.md` § Backups & storage policy_
- `landscape/README.md` Files table is the canonical cross-reference for the host landscape files; adding a new host requires updating both this table and creating the host file. _source: `landscape/README.md`_
- Cloudflare is authoritative only for `ai-dala.com` and `bizdala.com` (full zones, 13 + 0 DNS records respectively as of 2026-05-26). Pro-data.tech hosts carry no Cloudflare fronts. _source: `landscape/cloudflare.md`_
- The most-recent closed infrastructure task touching the host inventory (T-0082, "Add new Hetzner server ubuntu-16gb-nbg1-1 to inventory") is the closest analog for T-0090 in shape and audit trail. _source: `tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md`_
- The most-recent infrastructure run touching the inventory (T-0091) was the secrets-inventory scrub; T-0091 closed 2026-07-08 with `outcome: implemented`. _source: `tasks/T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md`_

## Issues / risks

- **`landscape/hosts/pro-data-tech-qa.md` does NOT exist.** Step 08 (landscape-updater) MUST CREATE this file as a new file. The "create new landscape file" decision belongs to this run's step 08 explicitly per `workflows/discovery-host.md` § Landscape-update guidance for step 08 ("New landscape files are a deliberate design decision, not a side-effect of discovery."). The decision is justified: the prior T-0082 (parent of the analogous ubuntu-16gb-nbg1-1 host) ALSO created the landscape file as part of discovery. Pattern is consistent.
- **`landscape/secrets-inventory.md` is NOT in any commit and IS gitignored** as of the T-0091 scrub (2026-07-08, run `2026-07-07-scrub-secrets-inventory-001`). Step 08 should NOT try to update it. Any discovery findings that reference secrets (e.g. the `pro-data.tech-qa-instance_rsa` key fingerprint `SHA256:1X5RtbilgvvakpD5wTENNyKK9Lkoc9sOXoAxeuy9DL0` from task-reader, provider key line in `/root/.ssh/authorized_keys`) should go DIRECTLY into `landscape/hosts/pro-data-tech-qa.md` (referenced by name and SHA-256 only, never by value).
- **T-0090, T-0093–T-0098 task files were lost during the 2026-07-07 secrets-inventory scrub** (removed from `_index.md` between `a41ec73` and `df1144c` — per T-0091 step-08 handoff § line 104). Step 08 should, at minimum, restore T-0090 in the index (and create its task file) since this discovery run is implicitly progressing T-0090. Restoration of T-0093, T-0097 is strongly recommended — they are the immediate unblock path for T-0090. Restoration of T-0094, T-0095, T-0096, T-0098 is optional and should be flagged in step 08's "Open questions" rather than invented silently.
- **`landscape/README.md` Files table does NOT include pro-data-tech-qa yet.** Step 08 MUST add the row, and SHOULD add a paragraph under "Bootstrap status" cross-referencing the new host and T-0090 discovery.
- **`landscape/cloudflare.md` and `landscape/domains.md` are stale (last_verified 2026-05-26 and 2026-05-15 respectively, both >30 days).** This run does NOT touch Cloudflare or domains; not a blocker for step 06. The orchestrator should route a future audit-cloudflare run to address this drift separately.
- **Provider-specific sections of the `ubuntu-16gb-nbg1-1.md` template are NOT transferable as-is** — sections 7 (Hetzner Cloud Firewall) and parts of section 8 (Backups) are Hetzner-specific. Step 08 should OMIT section 7 for pro-data-tech-qa and ADAPT section 8 to the pro-data.tech control plane (or note the absence of a paid-snapshot option as "no off-host backups per project-wide policy"). This is a writing-quality issue for step 08, not a blocker.
- **The `pro-data.tech-qa-instance_rsa.ppk` filename is misleading.** Per task-reader issue note: the file starts with `-----BEGIN RSA PRIVATE KEY-----` (OpenSSH-format RSA, not PuTTY .ppk). The SSH alias works because ssh autodetects the key format from contents. Step 08 should record the actual key format in `landscape/hosts/pro-data-tech-qa.md` and surface a "rename `.ppk` → `.pem`/`.key`" hygiene observation task (T-0098 candidate) so a future workflow can address it.

## Open questions

(none — defer to step 06 executor-discovery and step 08 landscape-updater.)
