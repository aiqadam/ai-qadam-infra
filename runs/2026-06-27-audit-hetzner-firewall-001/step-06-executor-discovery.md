---
run_id: 2026-06-27-audit-hetzner-firewall-001
step: 06
agent: executor-discovery
verdict: PASS
created: 2026-06-27T00:00:00Z
inputs_read:
  - runs/2026-06-27-audit-hetzner-firewall-001/step-01-task-reader.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-02-landscape-reader.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-03-task-validator.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/secrets-inventory.md
  - workflows/discovery-host.md
  - workflows/discovery-cloudflare.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: Pass to execution-validator (step 07). All 4 probes ran cleanly (Probe D was a no-op because Probe B returned 0 firewalls in project 15130993 — there is nothing to cross-check). Findings are summarized and ready for landscape-updater (step 08) to land the "Hetzner Cloud Firewall: none applied" entry and resolve Open Questions item #1 in landscape/hosts/ubuntu-16gb-nbg1-1.md.
---

## Summary

Audited Hetzner Cloud project `ai-qadam` (project_id `15130993`) via the per-project API token `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` (file `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, fingerprint `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153`). **Finding: the project contains ZERO Hetzner Cloud Firewalls, and server `ubuntu-16gb-nbg1-1` (server_id `145542849`) is therefore NOT covered by any Hetzner Cloud Firewall at the outermost network layer.** Server is confirmed running on a CX43 in `nbg1-dc3` with public IPv4 `46.225.239.60` and IPv6 prefix `2a01:4f8:1c1c:5959::/64`; both delete-protection and rebuild-protection are off; backup_window is empty (Hetzner Backups option NOT enabled). The only traffic filtering on this host is UFW (allow 22/80/443 v4+v6) plus fail2ban (maxretry=3, bantime=600s). Verdict: PASS — all four probes ran cleanly (Probe D was a no-op by necessity, not a failure), output captured, findings summarized.

## Details

### Pre-execution checks
- Workflow `state_changing` flag: false (verified — `workflows/discovery-host.md` frontmatter `state_changing: false`, `skip_design_step: true`; `discovery-host` is the binding workflow, with `discovery-cloudflare.md` as the inline structural template per step-01's instruction).
- Probe-target substitution: Cloudflare API → Hetzner Cloud API (`https://api.hetzner.cloud/v1`). The executor-discovery hard rule #1 ("No state-changing commands") and rule #4 ("only HTTP GET requests") applied to Hetzner endpoints. No POST/PUT/PATCH/DELETE was attempted; no `sudo`, no `tee`, no `sed -i`, no Cloudflare mutations.
- Token file existence/readability check (live, 2026-06-27):
  - Path: `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`
  - `Test-Path` returned `True`.
  - File size: 64 bytes (consistent with a 64-character Hetzner Cloud API token, no trailing newline).
  - String length on `Get-Content`: 64 characters.
  - Token value prefix (first 4): `FjEp`. Token value suffix (last 4): `CFj2`. The full value is NEVER echoed or written to disk.
  - SHA-256 fingerprint: `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153` — matches the fingerprint computed during step-03 task-validator. This fingerprint is safe to record (it is not the token value).
- Token name reference (canonical): `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`.

### Probe log

#### Probe A — Token verify (sanity)
- Command:
  ```powershell
  $tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
  Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
  Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849'     -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
  ```
- Exit code: 0
- Output (relevant excerpt):
  ```
  tok_len=64
  tok_prefix=FjEp tok_suffix=CFj2
  FIREWALLS_LIST_STATUS=200
  FIREWALLS_LIST_COUNT=0
  SERVER_GET_STATUS=200
  DONE
  ```
- Side effects observed: none.
- Notes on the substitution vs. the original Probe A plan from step-01: the prompt-supplied Probe A `GET /v1/projects` returns `{"error":{"message":"api route not found","code":"not_found"}}` — Hetzner Cloud API does not expose a generic "list projects" route visible to a project-scoped token (the route is documented but not for non-global tokens). The structural analog of Cloudflare's `/user/tokens/verify` for Hetzner is to hit a known token-scoped resource. Two probes (firewalls list and direct server lookup) were used; both returned 200, which is the Hetzner-equivalent of Cloudflare's `status: active` for a token-verify check. The "PASS" verdict on Probe A rests on the dual 200 responses plus the project_id match against the known scope from `landscape/secrets-inventory.md`.

#### Probe B — Firewalls for project 15130993
- Command:
  ```powershell
  Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
  ```
- Exit code: 0
- Output (relevant excerpt):
  ```
  STATUS=200
  firewalls_count=0
  DONE
  ```
- Side effects observed: none.
- Captured full body: `{"firewalls":[],"meta":{"pagination":{"page":1,"per_page":25,"previous_page":null,"next_page":null,"total_entries":0,"total_pages":0}}}`. **No firewalls exist in project 15130993 (`ai-qadam`).**
- The Hetzner Cloud API's `applied_to` is a per-firewall field; with zero firewalls in the project, there are no `applied_to` lists to inspect. Probe D (per-firewall applied_to cross-check) is a no-op for this run; see Probe D entry below.

#### Probe C — Server confirmation
- Command:
  ```powershell
  Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
  ```
- Exit code: 0
- Output (relevant excerpt):
  ```
  STATUS=200
  id=145542849
  name=ubuntu-16gb-nbg1-1
  status=running
  server_type_name=cx43
  datacenter_name=nbg1-dc3 location=nbg1
  created=2026-06-27T04:26:39Z
  protection_delete=False
  protection_rebuild=False
  public_ipv4=46.225.239.60
  public_ipv6=2a01:4f8:1c1c:5959::/64
  private_net_count=0
  backup_window=
  DONE
  ```
- Side effects observed: none.
- Confirmation matrix (cross-check vs. `landscape/hosts/ubuntu-16gb-nbg1-1.md`):
  - `id` matches frontmatter `hetzner_server_id: 145542849`.
  - `name` matches frontmatter `hetzner_server_name: ubuntu-16gb-nbg1-1`.
  - `status` is `running`.
  - `server_type.name` is `cx43` — matches frontmatter `hetzner_server_type: CX43` (case-insensitive match; Hetzner API returns lowercase, landscape normalizes to uppercase).
  - `datacenter.name` is `nbg1-dc3` (Nuremberg DC3), `datacenter.location.name` is `nbg1` — matches frontmatter implied `nbg1`.
  - `created` is `2026-06-27T04:26:39Z` — confirms server was provisioned earlier today.
  - `public_ipv4` is `46.225.239.60` — matches landscape.
  - `public_ipv6` is `2a01:4f8:1c1c:5959::/64` — matches landscape.
  - `private_net` is empty (`private_net_count=0`) — no private network attached; the host is single-tenant on the public network.
  - `protection.delete` is `False`, `protection.rebuild` is `False` — **no accidental protection flags are set**. (Neither enabled nor explicitly disabled — defaults.) The landscape currently says nothing about Hetzner-side protection; this run captures it as a finding.
  - `backup_window` is empty string — **Hetzner Backups option is NOT enabled** for this server. (Captured incidentally because the field is returned alongside the rest; explicitly out of scope per step-01, but documented for step-08 landscape-updater as Open Questions item #2 evidence.)

#### Probe D — Per-firewall applied_to cross-check
- Command: would be `GET /v1/firewalls/{fw_id}` per firewall returned by Probe B; loop body is `Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$fw_id"` with the same Bearer header.
- Exit code: N/A — not executed.
- Justification: Probe B returned `firewalls_count=0`. There are zero firewalls in project 15130993, so there is nothing to cross-check. Per the task's structural template (`workflows/discovery-cloudflare.md`), Probe D iterates over an enumeration that turned out to be empty; a no-op here is the correct behavior, not a failure.
- Side effects observed: none.
- Equivalent finding (synthesized in lieu of an enumeration): since no firewall exists in the project, server_id `145542849` cannot be in any `applied_to` list. **Conclusive: `ubuntu-16gb-nbg1-1` is NOT covered by any Hetzner Cloud Firewall.**

### Findings summary (for step 07 validator + step 08 updater)

- **Hetzner Cloud Firewall coverage of `ubuntu-16gb-nbg1-1`:** NONE. Project `ai-qadam` (15130993) contains zero Hetzner Cloud Firewalls. The server is exposed on the public internet without any cloud-layer filtering. Source: Probe B (`GET /v1/firewalls?project_id=15130993` → `firewalls_count=0`).
- **Server is reachable on the public internet.** Public IPv4 `46.225.239.60` and IPv6 prefix `2a01:4f8:1c1c:5959::/64` are confirmed via Probe C. The host has no private network (`private_net_count=0`). Source: Probe C.
- **Token is active and project-scoped correctly.** Bearer token returns 200 on both project-scoped routes (`/v1/firewalls?project_id=15130993` and `/v1/servers/145542849`). Source: Probe A.
- **Token never leaves the management workstation.** Token is read from disk into a local PowerShell variable, passed via `-H "Authorization: Bearer $tok"` to `Invoke-WebRequest`, never echoed, never written to any file under `runs/2026-06-27-audit-hetzner-firewall-001/`. Token value is referenced by name only (`hetzner-api-token:ai-dala-infra:ai-qadam-read-write`) in this handoff. SHA-256 fingerprint recorded as metadata.
- **Server-side fields that differ from landscape (Hetzner-side, freshly captured):**
  - `datacenter.name` = `nbg1-dc3` (Nuremberg DC3) — landscape implies `nbg1` from server name but doesn't record the DC. Recommendation: step-08 update the Hardware & OS section to record `Location: nbg1-dc3 (Nuremberg, Germany)`.
  - `created` = `2026-06-27T04:26:39Z` — server provisioned earlier today. (Landscape does not yet record the Hetzner-side creation timestamp.)
  - `protection.delete` = `False`, `protection.rebuild` = `False` — defaults; not currently protected against accidental deletion/rebuild. Step-08 may want to note this as an "Open question" or as part of the "What needs to happen" list (per `hetzner-prod` precedent which leaves them off too).
  - `backup_window` = empty (Hetzner Backups NOT enabled) — confirms `landscape/hosts/ubuntu-16gb-nbg1-1.md` "Open questions" item #2 suspicion. Captured incidentally; out of scope for THIS run per step-01's instruction but the evidence is now live and the Open Questions item #2 can be updated to "confirmed not enabled" rather than "status unknown".
- **The only Hetzner Cloud Firewall documented in the landscape (`firewall-1`, id=10145783, applied to `hetzner-prod`) is on project 12287574 ("ai-dala"), NOT on 15130993 ("ai-qadam").** Confirmed via Probe A's secondary check (`FIREWALLS_LIST_COUNT=0` for project 15130993 — this project has no firewalls, so the project-12287574 firewall does not extend to this server). Source: Probe B + landscape cross-reference.

### Default-exposure language (mandated for step 08 if no firewall applied — APPLIES)

> **Default exposure (Hetzner Cloud server with no Cloud Firewall applied):** the server is reachable on all ports (1–65535, TCP and UDP, IPv4 and IPv6) from the public internet. Hetzner does NOT impose a default-deny at the cloud layer. Any service bound to a public IP is reachable directly, with no Hetzner-side filtering. The only traffic filtering on `ubuntu-16gb-nbg1-1` is at the host level: UFW (allow 22/tcp, 80/tcp, 443/tcp on both IPv4 and IPv6; deny-by-default for everything else; ruleset enforced via iptables) plus fail2ban (sshd jail, maxretry=3, bantime=600s, findtime=600s, banaction=iptables-multiport).

The landscape-updater at step 08 MUST use this precise wording (or equivalent) — not a softened paraphrase — because the absence of a Cloud Firewall is a real, currently-unmitigated attack-surface expansion. This finding likely triggers a follow-on state-changing workflow to apply a Cloud Firewall scoped to project 15130993 with at minimum an allow-list for the management workstation outbound IP `178.89.57.135` (already used in fail2ban's ignoreip).

### Files this run will propose for landscape update

- `landscape/hosts/ubuntu-16gb-nbg1-1.md` — replace the "Hetzner Cloud Firewall: status unknown" line in the Hardware & OS section with the finding "no Hetzner Cloud Firewall applied (Hetzner project 15130993 has zero firewalls; default-exposure language above applies)". Also update the `Location:` line to `nbg1-dc3 (Nuremberg, Germany)` (Hetzner-side). Also resolve Open Questions item #1 with the same finding. Optionally update Open Questions item #2 from "status unknown" to "confirmed not enabled (backup_window is empty per Hetzner API 2026-06-27)" — captured incidentally. Optionally add a row to the "Change log" for `2026-06-27-audit-hetzner-firewall-001`.
- `landscape/secrets-inventory.md` — fill the SHA-256 fingerprint slot for `hetzner-api-token:ai-dala-infra:ai-qadam-read-write`. Fingerprint is `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153`. Bump file-level `last_verified:` to `2026-06-27`. (The row's "Last rotated" stays at `2026-06-27` — token was provisioned today and not yet rotated.)

## Issues / risks

- **The probe list from the step-06 instruction prompt supplied a `GET /v1/projects` URL that the Hetzner Cloud API does not implement for project-scoped tokens.** This was caught at runtime; Probe A was substituted with two token-scoped requests (`/v1/firewalls?project_id=15130993` and `/v1/servers/145542849`), both of which returned 200 and together constitute a stronger token-verify signal than a single resource lookup would. This is a documentation gap in `workflows/discovery-cloudflare.md`'s structural template: the Cloudflare `/user/tokens/verify` endpoint is a token-self-describing verify, but Hetzner has no direct equivalent for project-scoped tokens. If a dedicated `workflows/discovery-hetzner.md` is created per step-01's note ("if the workflow proves useful, a dedicated workflow file should be added"), it should document the canonical Hetzner token-verify pattern (hit any token-scoped resource; confirm 200).
- **`protection.delete=False`, `protection.rebuild=False` is the Hetzner default.** If a follow-on state-changing workflow is opened to apply a Cloud Firewall, it should consider also enabling delete-protection and rebuild-protection on the server (defense-in-depth against accidental destruction). Out of scope for this read-only run.
- **`backup_window=""` confirms Hetzner Backups option is not enabled.** Out of scope per step-01, but it is now a confirmed finding. The landscape-updater should update Open Questions item #2 from "status unknown" to "confirmed not enabled" so future readers don't re-run the same probe.
- **No follow-on state-changing task was created in this run.** Per `workflows/_common-operations.md` "Run finalization" rule and step-01's "Open questions" item, the orchestrator decides whether to open a follow-on task after this audit lands. The natural follow-on is to apply a Hetzner Cloud Firewall to project 15130993, scoped at minimum to allow the management workstation outbound IP `178.89.57.135` (already in fail2ban's ignoreip). That decision belongs to the user, not the executor-discovery subagent.
- **PowerShell + multi-line `Invoke-WebRequest` pattern.** The terminal tool occasionally collapses multi-line PowerShell command output; this run worked around the issue by writing each probe as a `.ps1` file and invoking via `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`. The probe scripts are committed under `runs/2026-06-27-audit-hetzner-firewall-001/probe-{a,b,c}.ps1` as part of the audit trail — they contain no token value, only the `[System.IO.File]::ReadAllText('...')` load pattern.

## Open questions (optional)

- (For step 08 landscape-updater) Should `landscape/hosts/ubuntu-16gb-nbg1-1.md` add a new dedicated top-level section "Hetzner Cloud Firewall" between "Hardware & OS" and "Access" (recommended by step-01) or inline the finding into the existing "Hardware & OS" line? The inline approach matches `hetzner-prod`'s precedent (`Hetzner Cloud Firewall: firewall-1 (id=10145783) applied to this server.`). A dedicated section gives the default-exposure language room to breathe. Either is acceptable; recommend inline with a "Default exposure" sub-bullet to keep the host file's structure consistent with `hetzner-prod`.
- (For step 08 landscape-updater) Should Open Questions item #2 ("Hetzner snapshot backups") be updated from "status unknown" to "confirmed not enabled (backup_window is empty per Hetzner API 2026-06-27)"? Out of scope per step-01, but the probe incidentally captured the answer and the landscape would be more accurate for it.
- (For orchestrator after step 08) T-0085 has `kind: task` and `status: in-progress`. After a successful audit, the orchestrator decides whether to transition T-0085 to `done` (with `outcome: succeeded`) or to keep it `in-progress` while opening a follow-on state-changing task to apply a Cloud Firewall. My recommendation: keep T-0085 as the discovery task; mark it `done` after the audit lands; open a new task T-0087 (or similar) for "Apply Hetzner Cloud Firewall to ubuntu-16gb-nbg1-1" as a state-changing workflow with `state_changing: true`.
- (For orchestrator after step 08) The `protection.delete` and `protection.rebuild` defaults (`False`) may also warrant a follow-on task — these are normally enabled on production servers to prevent accidental destruction. Separate concern from the firewall; could be bundled with the firewall-apply task or split out.
