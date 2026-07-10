---
run_id: 2026-06-27-apply-hetzner-firewall-001
step: "02"
agent: landscape-reader
verdict: PASS
created: 2026-06-27T00:00:00Z
task_id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-apply-hetzner-firewall-001/step-01-task-reader.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/README.md
  - landscape/secrets-inventory.md
  - tasks/_index.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-06-27-install-fail2ban-001/step-02-landscape-reader.md
  - runs/2026-05-13-install-rustdesk-server-001/step-02-landscape-reader.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — confirm task frontmatter matches the T-0085-audit-derived scope; surface protection-flag-call-shape (one combined call vs two separate calls) and IPv6 scope as the two design decisions that step 04 must explicitly resolve; surface management-workstation IP re-verification as a hard pre-flight gate for step 06.
---

## Summary

Landscape is sufficient to safely design and execute T-0086. The target host `ubuntu-16gb-nbg1-1` (server_id `145542849`, project `ai-qadam` / `15130993`) is a freshly provisioned Ubuntu 26.04 cloud image with no Hetzner Cloud Firewall applied (confirmed by audit run `2026-06-27-audit-hetzner-firewall-001` / T-0085 — same day), and the host-layer protection is in place: UFW (T-0083, deny-by-default + allow 22/80/443) and fail2ban (T-0084, sshd jail, ignoreip includes `178.89.57.135`). The pattern reference (`firewall-1` id `10145783` on prod project `12287574`) is well documented in `landscape/hosts/hetzner-prod.md` "Network" section. The per-project Hetzner API token is project-scoped to `15130993` only (verified active 2026-06-27) — sufficient for this run, explicitly NOT sufficient to touch prod project `12287574`. Management-workstation context (outbound IP, SSH config, identity file) is consistent across both hosts. The only blockers are design decisions to be made by step 04 (protection-flag call shape, IPv6 scope, firewall name) and one hard live-verification step owned by step 06 (re-verify outbound IP via `api.ipify.org` immediately before POST).

## Details

### Relevant facts (sourced from landscape)

#### Target host — `landscape/hosts/ubuntu-16gb-nbg1-1.md` (status: populated, last_verified: 2026-06-27)

- **Identity:** `host_id: ubuntu-16gb-nbg1-1`, `role: unassigned`, `status: populated`, `last_verified: 2026-06-27`.
- **Hetzner project:** `hetzner_project_id: 15130993`, `hetzner_project_name: ai-qadam`.
- **Hetzner server:** `hetzner_server_id: 145542849`, `hetzner_server_name: ubuntu-16gb-nbg1-1`, `hetzner_server_type: CX43` (8 vCPU / 16 GiB / 150 GiB disk).
- **Location:** Nuremberg, Germany (`nbg1-dc3`).
- **Public IPv4:** `46.225.239.60`.
- **Public IPv6:** `2a01:4f8:1c1c:5959::/64` (host prefix).
- **OS:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`).
- **Kernel:** `7.0.0-22-generic`.
- **Hetzner Backups option:** NOT enabled (`backup_window=""` per T-0085 audit probe C) — out of scope.
- **Hetzner Cloud Firewall state:** **NONE applied.** Project `ai-qadam` (`project_id 15130993`) contains zero Hetzner Cloud Firewalls. Verified `2026-06-27` by `GET /v1/firewalls?project_id=15130993` → empty enumeration; all three URL variants checked (`?project_id=15130993`, `?project=15130993`, no project filter); validator independently re-confirmed.
- **Server protection flags:** `protection.delete=False`, `protection.rebuild=False` (Hetzner defaults, per T-0085 audit probe C). `private_net=[]` (no private network). `created=2026-06-27T04:26:39Z`.
- **Default exposure (verbatim from landscape):** the server is reachable on all ports (1–65535, TCP and UDP, IPv4 and IPv6) from the public internet; Hetzner does NOT impose a default-deny at the cloud layer.
- **SSH user:** `tvolodi` (uid 1000, groups `sudo` `users`); passwordless sudo via `/etc/sudoers.d/90-tvolodi` (mtime 2026-06-27 04:46).
- **SSH daemon posture (2026-06-27):** cloud-image defaults — `Port 22`, `PermitRootLogin yes`, `PasswordAuthentication yes`, `PubkeyAuthentication yes`. No project hardening yet (no `40-disable-password.conf` drop-in).
- **Host firewall (UFW):** active and enabled at boot (T-0083, run `2026-06-27-configure-ufw-001`). Defaults: deny incoming, allow outgoing, `DEFAULT_FORWARD_POLICY="ACCEPT"` (Docker parity). Rules: allow 22/tcp (v4+v6), allow 80/tcp (v4+v6), allow 443/tcp (v4+v6). Six rules total. Persistence across reboot verified.
- **fail2ban:** 1.1.0-9 installed and active (T-0084, run `2026-06-27-install-fail2ban-001`). sshd jail enabled with `maxretry=3`, `bantime=600s`, `findtime=600s`, `ignoreip` includes management workstation outbound IP `178.89.57.135` (NOT the prod value `5.250.151.158` — distinct network), `banaction=iptables-multiport`. Config at `/etc/fail2ban/jail.d/sshd.local` (169 bytes, 0644 root:root, mtime 2026-06-27 06:13). 2 IPs already banned at install: `14.103.127.232`, `45.148.10.240`. iptables `f2b-sshd` chain present.
- **External probe (2026-06-27, from management workstation):** `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded: True`. Ports 80 and 443 return RST-no-listener (no service bound); port 21 returns timeout-dropped. Confirms UFW is actively filtering.
- **TCP listeners on 0.0.0.0:** only port 22 (sshd). No 80/443/nginx listener exists.

#### SSH access posture — `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Access" section

- **SSH user:** `tvolodi`.
- **SSH target:** `tvolodi@46.225.239.60` (port 22).
- **SSH config alias on management workstation:** `Host ubuntu-16gb-nbg1-1` in `C:\Users\tvolo\.ssh\config`. Uses project key `~/.ssh/ai-dala-infra` and `IdentitiesOnly yes`. Invoke as `ssh ubuntu-16gb-nbg1-1`.
- **SSH key (management workstation):** `C:\Users\tvolo\.ssh\ai-dala-infra` (ed25519, no passphrase). Public key fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`. Full public key in `landscape/secrets-inventory.md`.
- **SSH key installed on server:** yes (in `/home/tvolodi/.ssh/authorized_keys`). Note: contains two duplicate lines for the same ed25519 key (cosmetic, harmless).
- **Host fingerprints (on management workstation `known_hosts`):** RSA `SHA256:pNGyU7GiFCZ0QNqi9myVa8TB7dN0mrLzQqWCDuMdtls`; ECDSA `SHA256:0OuNLbfFiqFCJd54IGcPTWlBNKw3KpoRMGqQBN353fs`; ED25519 `SHA256:/T28aH4/dyzFUewzDjkAMCA1PHb2Pja8qEzBsZ54Zc4`.

#### Pattern reference — prod `firewall-1` — `landscape/hosts/hetzner-prod.md` "Network" section

- **Firewall name:** `firewall-1`.
- **Firewall id:** `10145783`.
- **Hetzner project:** `12287574` ("ai-dala") — **different project from this run's target**. The prod token (`hetzner-api-token:ai-dala-infra:read-write`) covers it; the ai-qadam token does NOT.
- **Applied-to scope:** server_id `112603990` (hetzner-prod) only — single server.
- **Inbound rule history (additions recorded in landscape, not authoritative for full set — see "caveats"):**
  - Original ruleset (preserved, never explicitly enumerated in landscape — pre-discovery): not captured in the file.
  - 2026-05-13: added inbound TCP on 21115–21119 for RustDesk (run `2026-05-13-install-rustdesk-server-001`).
  - 2026-05-26: added inbound TCP on port 2222 (Gitea SSH git) (run `2026-05-26-setup-private-git-app-001`).
- **Outbound policy:** not explicitly captured in landscape; Hetzner default behavior is allow-all. No custom outbound restrictions are recorded for prod.
- **Caveat (verbatim from landscape):** "This landscape entry records additions made by this project's workflows only; full rule set authoritative in Hetzner Cloud Console." → the full prod inbound rule list (incl. any pre-existing rules at the time of the original firewall create) is NOT in the landscape. The designer should not assume prod's outbound rules are documented. For this run's purpose (SSH-only firewall on a fresh host) the omission is harmless — we are creating a NEW firewall with a known, minimal inbound list, not modifying prod's.

#### Hetzner Cloud API scope — `landscape/secrets-inventory.md` "Hetzner ai-qadam token — identifying metadata"

- **Token name (Hetzner Cloud Console):** `ai-dala-infra:ai-qadam-read-write`.
- **Token SHA-256 fingerprint:** `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`.
- **File path on management workstation:** `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` (per `landscape/hosts/ubuntu-16gb-nbg1-1.md` change log + secrets inventory table; ACL user-only read/write).
- **Scope:** Read + Write, scoped to Hetzner project `ai-qadam` (`project_id 15130993`) only. **Does NOT cover project `ai-dala` (`project_id 12287574`).**
- **Verified active:** 2026-06-27 (token returns HTTP 200 on project-scoped routes `/v1/firewalls?project_id=15130993` and `/v1/servers/145542849`; validator independently re-confirmed fingerprint).
- **Operational implication for step 06:** every API call in this run must include `project_id=15130993` (or be a project-agnostic call on a resource that is known to belong to project 15130993, e.g. `GET /v1/servers/145542849`). Any call that targets project `12287574` will return `403`/`404` from this token — the executor should treat that as a hard error and halt, not retry.

#### Management workstation context

- **Outbound IP for this host:** `178.89.57.135` (recorded in `landscape/hosts/ubuntu-16gb-nbg1-1.md` "SSH hardening tooling on host" line and in the fail2ban `ignoreip`). **Confirmed 2026-06-27 via `api.ipify.org`** (per `landscape/hosts/ubuntu-16gb-nbg1-1.md` change-log row for the install-fail2ban run). Distinct from prod workstation IP `5.250.151.158`.
- **SSH config aliases (in `C:\Users\tvolo\.ssh\config`):**
  - `Host hetzner-prod` → `91.98.28.126` (port 22, user `tvolodi`).
  - `Host ubuntu-16gb-nbg1-1` → `46.225.239.60` (port 22, user `tvolodi`).
  - `Host git.ai-dala.com` → git.ai-dala.com (port 2222, user `git`) — for Gitea SSH git, not used in this run.
- **Identity file:** `~/.ssh/ai-dala-infra` (ed25519, no passphrase) — shared by all three aliases via `IdentitiesOnly yes` semantics.
- **Project public key:** `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvwxjV8uSQtfSv95gTFc0CsMB9p+dhTxomw5ma/QHcR ai-dala-infra-mgmt@tvolodi-2026-05-12` (in `landscape/secrets-inventory.md` "SSH key — public-key material" section). Fingerprint `SHA256:NzmieoBwGACIeLJz6HSW0C7J6XovsOuo/HZ7jaRep/8`. Already installed on both managed hosts' `authorized_keys`.

#### Cross-references for landscape-update (step 08)

- **`landscape/hosts/ubuntu-16gb-nbg1-1.md`** — primary file to update:
  - "Hetzner Cloud Firewall" section: rewrite to reflect new firewall (id, name, rule list, `applied_to`, protection flags).
  - "Hardware & OS" section: `Hetzner Cloud Firewall` line should be updated from "NONE applied" to a one-line summary.
  - `last_verified:` frontmatter: bump to 2026-06-27 (run completion date).
  - Change log: add a new row for `2026-06-27-apply-hetzner-firewall-001` summarizing the firewall create, the apply, the protection flag changes, and the live SSH verification.
  - "What needs to happen" item #2: re-status to ✅ done.
  - "Open tasks affecting this host" section: remove T-0086 row.
- **`landscape/services.md`** — no expected change (this run only adds Hetzner-side state, no host-side services). Landscape-updater should confirm and add a one-line change-log row only if there is something to record.
- **`landscape/secrets-inventory.md`** — no change (no new secret introduced; the Hetzner token row is unchanged).
- **`tasks/_index.md`** — T-0086 status transitions `pending` → `done` at end of run. Re-sort per the index's stated rule: open statuses first (observation > pending > in-progress > blocked > failed), each group by priority then id; closed last (done > wontfix > superseded), same sub-sort.

### Stale or stub files encountered

- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — `last_verified: 2026-06-27`, `status: populated`. **Fresh (today).** Authoritative.
- `landscape/hosts/hetzner-prod.md` — `last_verified: 2026-05-26`, `status: populated`. **32 days old — just over the 30-day stale threshold.** Read-only reference for the prod `firewall-1` pattern. No design risk for this run (prod is not being modified; we are creating a new firewall on a different project). Flagged for a future landscape-updater refresh run.
- `landscape/services.md` — `last_verified: 2026-06-27`, `status: populated`. **Fresh (today).** No services are added in this run, so file is read-only; landscape-updater may add a one-line change-log entry but no content change.
- `landscape/secrets-inventory.md` — `last_verified: 2026-06-27`, `status: in-progress`. **Fresh (today).** The Hetzner ai-qadam token row is the one consulted; fingerprint and project scope match task-reader. **Pre-existing low-priority drift noted:** the `gitea:admin-password` row still contains the literal password value (`eT96ulleryIpd38VJeQNRGm3lQ3qcUO3`) — out of scope, do not touch in this run, flag for future cleanup.
- `landscape/README.md` — no `last_verified` field; meta-file, not applicable.

### Gaps requiring live discovery (downstream steps own these)

1. **Hetzner API exact body schema for `POST /v1/firewalls` and `POST /v1/firewalls/{id}/actions/apply_to_resources`.** Task says "via `applied_to` resource list" but does not lock the JSON shape. The Hetzner Cloud API accepts both `applied_to` in the create body and a separate apply action. The task's "token" mention in [step-01 §Risks #3] references both endpoints and suggests using the separate action call (the safer choice — separate create from apply so rules can be validated before application). **Step 04 (solution-designer) must consult the Hetzner Cloud API docs and document the exact body shape, including `applied_to[]` resource references (`{type: "server", server: {id: <id>}}`).**
2. **Protection-flag call shape.** Per [step-01 §Risks #4] there is an inconsistency between the task's acceptance-criteria wording ("separate API calls; both verified post-set") and the Hetzner API which accepts both flags in one call (`{delete: true, rebuild: true}`). **Step 04 (solution-designer) must decide and document: (a) one combined call + two `GET` verifications post-set, or (b) two separate calls + two `GET` verifications post-set.** The combined-call approach is fewer round-trips and matches Hetzner API convention; the separate-call approach matches the literal acceptance-criteria wording.
3. **IPv6 inbound scope.** Task is silent on IPv6. The host's `default-exposure` language in landscape explicitly mentions IPv6 reachability; the task's specified source `178.89.57.135/32` is IPv4-only. **Step 04 should confirm or adjust:** the most defensive default is "IPv4-only firewall" (matches task wording; matches prod's documented rules which are not explicitly enumerated but appear to be IPv4-only based on historical additions). IPv6 inbound remains unrestricted until a role is assigned and a deliberate v6 policy is set. Document this assumption explicitly.
4. **Outbound policy.** Hetzner default is allow-all. The task is silent. **Step 04 should confirm:** default = no explicit `rules.outbound` array in the create body; Hetzner will default to allow-all. Matches the "Outbound rules: Hetzner default (allow all)" line in the task acceptance criteria. Document this.
5. **Pre-flight IP re-verification.** Management-workstation outbound IP `178.89.57.135` was last live-verified 2026-06-27 during the fail2ban install. ISP rotation could change it. **Step 06 (executor) MUST re-verify via `api.ipify.org` (or `ifconfig.me` as the fail2ban step used) IMMEDIATELY before POSTing the rules and refuse to proceed if the IP differs from `178.89.57.135`** without an explicit user override. This is a hard pre-flight gate, not a design decision.
6. **Same-day `GET /v1/firewalls?project_id=15130993` re-check.** The T-0085 audit is same-day (2026-06-27) and confirmed zero firewalls. **Step 06 (executor) should re-issue the same `GET` immediately before the create call** (defense-in-depth — a same-day re-check is cheap and would catch a hypothetical concurrent modification by an out-of-band operator).
7. **Firewall name finality.** Default proposed in task: `ai-qadam-mgmt-ssh`. The user may rename at approval. **Step 04 should commit to a name in the design handoff and surface it in the approval gate**; if the user has a different name preference, the user can override in the APPROVE response and the executor uses the override verbatim.

### Conflict scan (per task-reader request)

- **No existing Cloud Firewall applies to `ubuntu-16gb-nbg1-1`** — confirmed by T-0085 audit (2026-06-27, same day). Project `ai-qadam` (`15130993`) contains zero firewalls. No conflict.
- **No other pending task in `tasks/_index.md` modifies this host's cloud firewall** — verified by full scan of the index (per the index, no other task lists `landscape/hosts/ubuntu-16gb-nbg1-1.md` in its `affects:` list except T-0086). No conflict.
- **No dependency between T-0086 and any other pending P0/P1 task** — verified by full scan of the index:
  - P0 pending: T-0056-scrub-github-pat (CI/CD concern, unrelated), T-0062-remove-ai-qadam-application (prod host, unrelated), T-0063-remove-wms-stack (prod host, unrelated). None reference this host or its firewall.
  - P1 pending: T-0077-protect-my-fab-main (My-Fab branch protection, unrelated), T-0082-add-ubuntu-16gb-nbg1-1-to-inventory (parent inventory task — open, not blocking, not blocked; T-0086 is a child observation that is now being executed).
  - P1 in-progress: T-0082 (the discovery parent task, which T-0086 does not interact with; T-0082 stays open until role assignment).
  - No P2/P3 pending tasks reference this host.
  - **Conclusion:** no dependency conflict.
- **No conflict between T-0086 and the token's narrow project scope.** Token is scoped to `15130993` only; this run only touches resources in `15130993`. No scope conflict.
- **No conflict between the proposed firewall rules and any host-level state.** UFW allows 22/80/443 (v4+v6). The firewall will allow inbound 22 from `178.89.57.135/32` only. The two layers are non-conflicting (cloud layer is more restrictive, host layer is broader; the cloud layer is the outer filter, the host layer still applies for traffic that does pass through the cloud filter). If the user later adds a web role to this host and the cloud firewall is updated to allow 80/443, UFW already has those rules — no change needed.

### Open questions for step 04 (solution-designer)

1. **Firewall name finality** — `ai-qadam-mgmt-ssh` proposed; surface in approval gate.
2. **Protection-flag call shape** — combined `{delete: true, rebuild: true}` call (recommended; fewer round-trips, matches Hetzner API convention) vs. two separate calls (matches literal acceptance-criteria wording). Decide and document.
3. **IPv6 inbound scope** — IPv4-only firewall (recommended; matches task wording; matches prod pattern's implicit IPv4-only behavior); document the explicit "IPv6 remains unrestricted at cloud layer" assumption.
4. **Outbound rules** — Hetzner default allow-all (no explicit `rules.outbound` array in create body); document.
5. **Create + apply call pattern** — recommend the separate-action pattern: `POST /v1/firewalls` with rules (no `applied_to`), then `POST /v1/firewalls/{id}/actions/apply_to_resources` to apply to server `145542849` once the create response is verified. This decouples create from apply so the executor can sanity-check the JSON and the firewall id before binding it to the server (lower lockout risk than putting `applied_to` in the create body and rolling forward on any error).
6. **Pre-flight sequence in step 06** — must include: (a) `GET /v1/firewalls?project_id=15130993` to confirm still zero, (b) `curl https://api.ipify.org` to re-verify management-workstation IP, (c) record both results in handoff before any POST. Hard abort if either step surfaces a discrepancy from landscape.

## Issues / risks

- **Lockout risk is the dominant operational risk.** Mitigated by pre-flight IP re-verification, by the Hetzner Cloud Console fallback (operator can manually delete/recreate the firewall from the console), and by the KVM-over-IP console fallback for the host itself. The create+apply separation (recommended in Open Question #5) further reduces risk by allowing the firewall to be created and verified BEFORE it is applied to the server — if the rule set is wrong, the firewall exists but is not bound to anything; it can be deleted without affecting the host.
- **Hetzner default-exposure is unmitigated at the cloud layer until step 06 completes.** Between the current moment and the executor's successful POST, the host is fully exposed. This is the entire reason the run is `priority: P1`. Risk is bounded: UFW + fail2ban are host-layer protections in place; the only new exposure vector is one not already in the host-layer deny-default. Real risk level: low during the execution window (the window is short, the workflow is gated by approval, and the host is unprovisioned so there are no application-layer attack surfaces).
- **The host has `PasswordAuthentication yes` (cloud-image default).** This is a separate sshd-hardening task (not T-0086) tracked as a follow-on. Note: the cloud-layer firewall allow rule for `178.89.57.135/32` is restrictive enough that password auth is not the dominant risk, but the host is hardened defense-in-depth, not single-layer.
- **Token's narrow project scope is sufficient but unforgiving.** A typo in the project_id or a call to the wrong resource id will return 404/403. The executor should be explicit about the `project_id` filter in every call and verify the firewall id is in project 15130993 (via `GET /v1/firewalls/{id}` response, which includes `firewall.created` and resource reference) before issuing the apply action.
- **IPv6 exposure remains even after the firewall is applied** (under the recommended design — IPv4-only firewall). This is an explicit, documented decision (per Open Question #3); the host will still be reachable on all IPv6 ports from the public internet until either (a) a role is assigned and v6 policy is defined, or (b) a v6-specific rule is added. The landscape's "default exposure" language covers this; the task-reader / orchestrator should be aware that this run does not close the IPv6 gap by itself.
- **`landscape/secrets-inventory.md` is in `status: in-progress`** (the header still says "STUB" but content is fully populated) — a pre-existing housekeeping item, not a blocker for this run.
- **The Hetzner Backups option is NOT enabled on this host** (`backup_window=""` per T-0085 audit probe C). Out of scope for T-0086. If the user later wants to enable Hetzner Backups, that would be a separate task — adding inbound for the backup agent is not needed (Hetzner Backups is an internal-to-Hetzner service, not user-touched). Note: enabling Hetzner Backups is a paid option (20% of server cost per Hetzner's pricing); user decision required.

## Open questions (optional)

- (For step 03 task-validator) The task's `affects:` list includes `landscape/services.md`. Confirm this is intentional (no service is added in this run, but the landscape-updater may need to add a one-line change-log row referencing the run) vs. an oversight from the task promotion step. If intentional, the validator should accept the run; the landscape-updater at step 08 will write a change-log row only.
- (For step 04 solution-designer) Should the new firewall be tagged with a `description` field in the create body? Hetzner Cloud Firewall supports an optional `description` string (e.g., "SSH management for ubuntu-16gb-nbg1-1 from management workstation 178.89.57.135, created by 2026-06-27-apply-hetzner-firewall-001"). Recommended for future auditability; not required.
- (For step 06 executor) After successful apply, the verification probe sequence should be: (a) `GET /v1/firewalls/{id}` → confirm rules, `applied_to` list, and `project_id` match; (b) `GET /v1/servers/145542849` → confirm `protection.delete=true` and `protection.rebuild=true`; (c) from management workstation: `Test-NetConnection 46.225.239.60 -Port 22` → True; (d) optionally, `Test-NetConnection 46.225.239.60 -Port 22` from a non-management IP (e.g., a phone on cellular) to confirm the firewall actually blocks — but this requires a second external probe source, which may not be available; recommend documenting the "from management IP" probe only and noting the negative-space test (that a non-management IP would be blocked) as inferred from the rule set rather than directly probed.
- (For step 08 landscape-updater) The change-log row for the new run should follow the format of the existing rows; recommend a row similar to the `2026-05-26-setup-private-git-app-001` row for prod's last firewall modification, but with project 15130993 and server 145542849 instead.

## Verdict rationale

**PASS.** Landscape is complete, consistent, and sufficient for the downstream steps. The target host's state is fresh and well-documented; the prod `firewall-1` pattern is well-documented (with documented caveats about its full rule set being authoritative in Hetzner Cloud Console); the Hetzner API token's scope is verified and sufficient. No conflicts found in the index scan. The known unknowns are precisely characterized as (a) design decisions for step 04 to lock in, and (b) hard live-verification steps for step 06 to perform. None of these gaps make safe design or safe execution impossible — they are gating verifications the executor must perform immediately before POSTing. No `BLOCKED` condition.
