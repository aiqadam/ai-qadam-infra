---
run_id: 2026-06-27-discovery-host-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
inputs_read:
  - runs/2026-06-27-discovery-host-001/step-01-task-reader.md
  - workflows/discovery-host.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/README.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/services.md
  - landscape/secrets-inventory.md
  - landscape/hosts/hetzner-prod.md
  - tasks/T-0082-add-ubuntu-16gb-nbg1-1-to-inventory.md
artifacts_changed: []
next_step_hint: Pass to task-validator (step 03) with target host ubuntu-16gb-nbg1-1. The host stub is ready to populate; pre-flight checks (SSH reachability, SUDO_OK via probe A) are the gate.
---

## Summary

The landscape is in a known-asymmetric state for this run: `landscape/hosts/ubuntu-16gb-nbg1-1.md` exists as a documented **stub** with user-supplied identity + access facts already captured by manual bootstrap, but `status: stub` and a partial body (sections "What runs here", "Network", "Backups" empty). The other landscape files (`services.md`, `secrets-inventory.md`, `hosts/hetzner-prod.md`) are populated and serve as cross-reference templates for step 08 to mirror. The discovery-host workflow's 14 probe sections (A–N) are well-defined and the gaps between landscape and reality are precisely the questions those probes answer. Verdict: **PASS** — landscape loaded, gaps documented; the stub being unpopulated is expected and is the entire purpose of this run, not a blocker.

## Details

### Relevant facts (sourced from landscape)

#### From `landscape/hosts/ubuntu-16gb-nbg1-1.md` (status: stub — the central fact for this run)

- **Frontmatter already populated (do not overwrite at step 08; reconcile if drift):**
  - `host_id: ubuntu-16gb-nbg1-1`
  - `provider: hetzner`
  - `role: unassigned` — **gap**: must be set once user decides purpose
  - `last_verified: 2026-06-27`
  - `status: stub` — **target state at step 08**: `populated`
  - `hetzner_server_name: ubuntu-16gb-nbg1-1`
  - `hetzner_server_id: 145542849`
  - `hetzner_project_id: 15130993`
  - `hetzner_server_type: CX43`
  - `hetzner_project_name: Al-Qadam` — **different** Hetzner project from `hetzner-prod` (project_id `12287574`); Hetzner API token in scope per `secrets-inventory.md` is `hetzner-api-token:ai-dala-infra:read-write` — must be checked for whether it has access to project 15130993 before any Hetzner Cloud Firewall or snapshot work in a future run
  - `ssh_user: tvolodi`
  - `ssh_port: 22`
  - `os: ubuntu-26.04` — provided by user, to be verified by probe B (`/etc/os-release`)
  - `kernel: 7.0.0-22-generic` — provided by user, to be verified by probe B
- **Body sections with content already in place:**
  - "Identity (provided by user, 2026-06-27)" lists IPv4 `46.225.239.60`, IPv6 prefix `2a01:4f8:1c1c:5959::/64`, spec (8 vCPU / 16 GiB / 160 GB), €15.99/month, location `nbg1`, OS Ubuntu 26.04 LTS "Resolute Raccoon", kernel `7.0.0-22-generic`, uptime 34 minutes at first contact, Hetzner project "Al-Qadam" id `15130993`. All flagged as "user-provided" — step 06 must verify each.
  - "Access (verified 2026-06-27)" documents SSH user `tvolodi` (uid 1000; sudo + users groups), `sudo -n true` returning 0 (probe A pre-verified by bootstrap — step 06 must re-verify), `/etc/sudoers.d/` empty at first contact (NOPASSWD from cloud-init default in `/etc/sudoers`), SSH config alias `Host ubuntu-16gb-nbg1-1` on the management workstation using `~/.ssh/ai-dala-infra` with `IdentitiesOnly yes`.
- **Open question already noted in the stub body (line under "Access"):** ED25519 host fingerprint recorded by client on first connection (`StrictHostKeyChecking=accept-new`), but RSA / ECDSA not yet recorded — the management workstation's `ssh-keyscan` rejects the server's preferred KEX (`sntrup761x25519-sha512@openssh.com`) and falls back to none. The stub suggests step A.1 should record these via a client-side `KexAlgorithms` override or by reading the running sshd's `HostKey` entries. **Action for step 06:** surface this gap explicitly under "Findings" so step 08 can capture all three fingerprints in the populated file.
- **"What needs to happen" checklist (6 items, current state):**
  1. ✅ SSH access from management workstation.
  2. ⏳ Hetzner Cloud Firewall — audit and (if needed) apply permitting management IP; record firewall ID in frontmatter. **gap: firewall ID is NOT yet a frontmatter field** — step 08 should add `hetzner_firewall_id:` if discovered (mirror the practice on `hetzner-prod` which records `hetzner_project_id` / `hetzner_server_id` but lists the firewall ID inside the Network section body, not frontmatter; be consistent with that).
  3. ⏳ OS-level firewall (UFW) — UFW deny-by-default + allow 22/80/443 for parity with `hetzner-prod`. **Note**: this is a *follow-on* state-changing workflow, NOT a discovery probe — discovery (probe F) should capture current state, not apply.
  4. ⏳ Project-managed sudoers drop-in `/etc/sudoers.d/90-tvolodi` — same as #3, follow-on, not in scope for this run.
  5. ⏳ This discovery run itself — populates real OS/kernel/hardware/users/services/listeners/firewall/docker/nginx data; transitions stub → populated.
  6. ⏳ Role assignment — `role:` in frontmatter + `affects:` entries in `tasks/_index.md`. Out of scope for this run; step 08 may flag as open question but should NOT unilaterally pick a role.
- **Empty body sections that step 08 must fill from probe output:** "What runs here", "Network", "Backups".
- **Change log (already has 3 rows dated 2026-06-27):** step 08 appends one row with `(run_id, "Initial discovery run")` per workflow guidance — mirror the format used in `hetzner-prod.md`.

#### From `landscape/services.md` (status: populated; reference for table structure only)

- **Structure to mirror at step 08 (when adding a section for `ubuntu-16gb-nbg1-1`):**
  - Per-host top-level heading (`## hetzner-prod` today).
  - Subsections in order: `### Docker`, `### nginx`, `### Native systemd services of note`, `### Scheduled tasks`.
  - Docker subsection has paragraphs for engine version + status, then a "Running Compose projects" table, a "Running containers" table (Container / Image:tag / Compose project / Host ports / Bind / Restart+health / Purpose), and optional "Orphan compose project" / "Infrastructure-ready compose projects" sections.
  - nginx subsection has paragraphs for install/version/config root/sites-enabled/TLS, then a vhosts table (server_name / Listens / Upstream / Notes).
  - systemd table: Unit / Path / User / What it does.
  - Scheduled tasks: free-form list.
  - File ends with a `## Change log` table (Date / Run ID / Change) — same row format used in `landscape/hosts/hetzner-prod.md`.
- **Forward-looking note for step 08:** per the workflow's probe scope, this run expects the new host to have **no services yet** (probe H/I/J will likely show docker not installed, nginx not installed, only base systemd units). Step 08 should add a new top-level `## ubuntu-16gb-nbg1-1` section with each subsection marked "no services discovered" or omitted with a one-line note, mirroring the "empty until discovery" placeholder pattern used in the stub host file rather than inventing rows.
- **Stale fact flag:** `services.md` frontmatter says `last_verified: 2026-06-10` but the Change log runs through `2026-06-10-redeploy-bilimbaga-test-001` (also dated 2026-06-10). Not stale enough to flag as out-of-policy (>30 days is the threshold per the landscape-reader rules); today is 2026-06-27 so 2026-06-10 is 17 days old — within tolerance.

#### From `landscape/secrets-inventory.md` (status: in-progress; reference for SSH public-key format)

- **SSH public-key fingerprint format (for host file to use at step 08):** the inventory records the management-workstation public key as `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvwxjV8uSQtfSv95gTFc0CsMB9p+dhTxomw5ma/QHcR ai-dala-infra-mgmt@tvolodi-2026-05-12` with fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`. The stub host file references this by saying "Public-key fingerprint recorded in `../secrets-inventory.md`" — step 08 should preserve that cross-reference and not duplicate the full key material.
- **SSH key inventory row:** `ssh-key:ai-dala-infra-mgmt` — managed workstation key, last rotated 2026-05-12. The stub already implicitly assumes this same key is in use on `ubuntu-16gb-nbg1-1`; if probe D shows a different key fingerprint installed there, that is drift to surface.
- **Hetzner API token reference:** `hetzner-api-token:ai-dala-infra:read-write` at `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-dala.token` — name only, value never in this file. **Out of scope for this discovery run** (the workflow's probes A–N are on-host only); flag in Open questions if the Hetzner Cloud Firewall audit (item #2 on the stub's "What needs to happen" list) cannot be deferred to a follow-on run because the token may not have access to project_id `15130993` ("Al-Qadam").
- **Cloudflare tokens** in the inventory are zone-scoped to `ai-dala.com` and `bizdala.com` — irrelevant to this run (new host has no DNS or proxied zones yet).
- **`gitea:admin-password` row shows the value (`eT96ulleryIpd38VJeQNRGm3lQ3qcUO3`)** — this is a known convention violation (the file's own header says "Never put secret values in this file"). Flagging as drift in "Issues / risks" below; do NOT touch in this run (out of scope).

#### From `landscape/hosts/hetzner-prod.md` (status: populated; conventions to mirror at step 08)

- **Frontmatter fields present (template for new host file):** `host_id`, `provider`, `role`, `last_verified`, `status`, `hetzner_project_id`, `hetzner_server_id`. The stub already has these populated and adds `hetzner_server_name`, `hetzner_server_type`, `hetzner_project_name`, `ssh_user`, `ssh_port`, `os`, `kernel` — preserving them at step 08 is the right call (the stub already has more frontmatter than `hetzner-prod` because it was bootstrap-populated from the console screenshot).
- **sshd drop-in naming convention:** `NN-name.conf` under `/etc/ssh/sshd_config.d/` with first-wins semantics. `hetzner-prod` has `40-disable-password.conf` and `50-cloud-init.conf`. Step 08 should describe what exists on the new host (likely just `50-cloud-init.conf` and `90-cloud-init-users.conf` on a fresh Ubuntu cloud image).
- **UFW rule format:** `(port)/(proto) ALLOW IN` — mirror the bullet style on `hetzner-prod`'s Network section.
- **Change log row format:** pipe-delimited table with three columns (Date | Run ID | Change). The new row for this run should read roughly: `2026-06-27 | 2026-06-27-discovery-host-001 | Initial discovery run.`.
- **Open tasks / follow-ons section pattern:** `## Open tasks affecting this host` links to `tasks/_index.md` and lists specific task IDs. Step 08 should NOT invent T-numbers — only list task IDs that already exist in `tasks/`. At the time of this run, no task references `ubuntu-16gb-nbg1-1` except T-0082 itself.
- **TCP listeners table format:** two sub-tables — "TCP listeners on 0.0.0.0" and "TCP listeners on 127.0.0.1 only". For a fresh host, the only expected 0.0.0.0 listener is `22/sshd`; everything else is "nothing yet".

### Stale or stub files encountered

- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — **the central stub for this run**. `last_verified: 2026-06-27`, `status: stub`. Not stale in the >30-day sense (it's the same day) — it's stub by design and is the target this run exists to populate. Step 08 transitions to `status: populated`.
- `landscape/services.md` — `last_verified: 2026-06-10`, `status: populated`. 17 days old, within tolerance. **No new section exists for `ubuntu-16gb-nbg1-1`** — step 08 will add one (with content reflecting "no services yet" or similar) per workflow guidance.
- `landscape/secrets-inventory.md` — `last_verified: 2026-05-26`, `status: in-progress`. 32 days old — **just over the 30-day stale threshold** for a reference file. Since this run does not write to `secrets-inventory.md`, no action required from this run; flag for a future secrets-inventory refresh run.
- `landscape/hosts/hetzner-prod.md` — `last_verified: 2026-05-26`, `status: populated`. 32 days old, also just over the threshold. Reference only in this run; no action required.

### Gaps requiring live discovery (probes A–N)

These are facts downstream steps need that the landscape does not contain and step 06 must produce via the discovery-host workflow's probe sections:

1. **Effective OS / kernel** (probe B): user-claimed `ubuntu-26.04` + `7.0.0-22-generic` need re-verification from `/etc/os-release` and `uname -a`.
2. **Live hardware view** (probe C): `nproc`, `free -h`, `df -h` — confirm 8 vCPU / 16 GiB / 160 GB from Hetzner's claim.
3. **Other users and their authorized_keys** (probe D): the stub only documents `tvolodi`. Probe D will enumerate any other local users (uid >= 1000 plus root). For a fresh cloud image, expected: only `root` and `tvolodi`.
4. **sshd effective config** (probe E): the bare minimum a fresh Ubuntu cloud image ships. Should differ from `hetzner-prod` in that it has none of this project's hardening yet (no `40-disable-password.conf`, no fail2ban).
5. **Firewall state — UFW, nftables, iptables** (probe F): confirm UFW is not yet installed (per stub "Not yet provisioned"). nft and iptables will show the cloud image defaults. No Docker iptables bypass expected yet.
6. **Network listeners** (probe G): only `22/sshd` expected (and any cloud-image defaults like `systemd-resolved` on 127.0.0.1:53). Contrast with `hetzner-prod`'s long list.
7. **Docker** (probe H): expected absent — capture the "not installed" output.
8. **nginx** (probe I): expected absent — capture the "not installed" output.
9. **systemd units of interest** (probe J): only base cloud-image services expected (ssh, cron, systemd-resolved, qemu-guest-agent, cloud-init, unattended-upgrades).
10. **Scheduled tasks** (probe K): cloud-init defaults; certbot not installed; only unattended-upgrades timers and the standard `fstrim.timer` etc.
11. **Package & update posture** (probe L): pending upgrade count and `20auto-upgrades`/`50unattended-upgrades` contents. Note this server runs Ubuntu 26.04 (cloud-image convention); unattended-upgrades may be installed but inactive.
12. **Security tools** (probe M): fail2ban / auditd / AppArmor — all expected absent or in cloud-image default state. AppArmor likely loaded with default Ubuntu profile set.
13. **Backup posture** (probe N): nothing expected — no `app-backup.timer`, no restic/borg/duplicity. This is a known gap that will need to be addressed in a future state-changing workflow run for parity with `hetzner-prod`.
14. **Hetzner Cloud Firewall ID**: NOT covered by any of probes A–N (those are all on-host). The workflow's "Landscape-update guidance" section says: "For ANY finding the workflow exposes that is not explicitly covered by an existing landscape file, the updater records it under 'Open questions' in the run's step-08 handoff rather than inventing a new landscape file." So if no Hetzner Cloud Firewall data surfaces from probes A–N (which is expected — they're on-host), step 08 should explicitly note "Hetzner Cloud Firewall audit deferred to a follow-on Hetzner-API workflow" rather than fabricate an ID. **Do not silently add a `hetzner_firewall_id` field without data.**
15. **RSA / ECDSA host fingerprints for known_hosts**: flagged by the stub itself as a known gap. Step 06 should record via probe A.1 / ssh-keyscan workaround; step 08 should add them to the host file's "Access" section in the same format `hetzner-prod.md` uses (three bullet items: RSA / ECDSA / ED25519 each with `SHA256:...` fingerprint).

## Issues / risks

- **`secrets-inventory.md` is 32 days old** (just over the 30-day stale threshold). Not a blocker for this discovery run since the file is read-only reference; flag for a future refresh.
- **`gitea:admin-password` row in `secrets-inventory.md` embeds the actual value** (`eT96ulleryIpd38VJeQNRGm3lQ3qcUO3`). This violates the file's own header rule "Never put secret values in this file" — pre-existing drift, not introduced by this run. Out of scope to fix here; surface as a low-priority cleanup item.
- **Hetzner API token scope uncertainty**: the read-write Hetzner token in `secrets-inventory.md` was created 2026-05-13 for project_id `12287574` (hetzner-prod's project). The new host lives in project_id `15130993` ("Al-Qadam"). Step 06 should NOT probe Hetzner API endpoints (out of scope for this workflow's A–N probes); but step 08's open-questions section should note that any future Hetzner Cloud Firewall / Floating IP work on this host will first require either (a) verifying the existing token has access to project 15130993, or (b) provisioning a project-scoped token.
- **Stub frontmatter has `os: ubuntu-26.04` and `kernel: 7.0.0-22-generic`**: these are unverified until probe B runs. The values look unusual (Ubuntu 26.04 LTS "Resolute Raccoon" is plausible for a 2026-06 fresh image; kernel 7.0.0 is plausible for an Ubuntu mainline/packaging choice). Step 06 should accept the values as verified if probe B's `/etc/os-release` shows PRETTY_NAME containing "Ubuntu 26.04" and `uname -r` shows `7.0.0-22-generic`. If they differ, step 08 updates the frontmatter.
- **`role: unassigned` is expected to remain so** after step 08. The workflow does not assign roles; that's T-0082 item #6 / "Notes" follow-on. Step 08 should NOT change `role` to a guessed value.
- **`hetzner_firewall_id` frontmatter field is not yet present on the stub**; do not invent one. Per workflow guidance, surface as an open question at step 08 instead.

## Open questions (optional)

- (For step 03 task-validator) SSH reachability + SUDO_OK were already verified by bootstrap; step 03 should still confirm probe A pre-flight is in scope for step 06, not skip it.
- (For step 06 executor-discovery) The "What needs to happen" items #2, #3, #4 are *follow-on state-changing workflows*, not part of this discovery run. Do not apply UFW / sudoers drop-in / Hetzner Cloud Firewall changes during probe execution. Capture current state only.
- (For step 06 executor-discovery) On RSA / ECDSA fingerprint recording: if `ssh-keyscan` with a `KexAlgorithms` override does not work in PowerShell + Windows OpenSSH client, fall back to reading the server's `/etc/ssh/ssh_host_*_key.pub` files via `ssh ubuntu-16gb-nbg1-1 'sudo awk "{print \$2}" /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub'` and computing fingerprints client-side via `ssh-keygen -lf`.
- (For step 08 landscape-updater) The stub says `host_id: ubuntu-16gb-nbg1-1`. T-0082's "Notes" raises the question of whether to assign a short canonical `host_id` (e.g., `hetzner-2`). Decision is the user's; do not change unilaterally. Flag in open questions.
- (For step 08 landscape-updater) If probe B shows the OS is NOT Ubuntu 26.04 (e.g., it's the latest 24.04 LTS as expected for new Hetzner cloud images), update the frontmatter `os:` and `kernel:` fields to match what `/etc/os-release` and `uname -r` return. Do not preserve user-provided values that conflict with the probe output.
- (For the user, post-run) `secrets-inventory.md` `gitea:admin-password` row contains the literal password value in violation of the file's own "no values" rule. Suggest a low-priority cleanup task to scrub this value (rotate the password, then remove from the file).
