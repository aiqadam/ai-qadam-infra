---
run_id: 2026-06-27-audit-hetzner-firewall-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-06-27T08:30:00Z
inputs_read:
  - runs/2026-06-27-audit-hetzner-firewall-001/step-01-task-reader.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-02-landscape-reader.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-03-task-validator.md
  - runs/2026-06-27-audit-hetzner-firewall-001/step-06-executor-discovery.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/secrets-inventory.md
  - tasks/T-0085-audit-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - runs/2026-06-27-discovery-host-001/step-07-execution-validator.md
artifacts_changed:
  - runs/2026-06-27-audit-hetzner-firewall-001/validator-probe-a-and-c.ps1
  - runs/2026-06-27-audit-hetzner-firewall-001/validator-probe-b.ps1
  - runs/2026-06-27-audit-hetzner-firewall-001/validator-fingerprint.ps1
  - runs/2026-06-27-audit-hetzner-firewall-001/validator-leak-scan.ps1
  - runs/2026-06-27-audit-hetzner-firewall-001/validator-leak-scan.txt
next_step_hint: Pass to landscape-updater (step 08). The audit's core finding (zero Hetzner Cloud Firewalls in project 15130993 → server `ubuntu-16gb-nbg1-1` is on the public internet with no cloud-layer filtering) is reproducible. All five reconciliation items match the executor's report; SHA-256 fingerprint verified independently; no token value leaked into any handoff.
---

## Summary

The Hetzner Cloud API audit of project 15130993 (ai-qadam) is **verified**. Every probe independently re-run from the management workstation reproduces the executor's reported findings: token is valid (Bearer auth on `/v1/servers/145542849` returns HTTP 200 with server `running`); project 15130993 contains **zero** Hetzner Cloud Firewalls (all three URL variants — `?project_id=15130993`, `?project=15130993`, and no-project-filter — returned HTTP 200 with `{"firewalls": [], …total_entries: 0}`); server identity (cx43 / nbg1-dc3 / 46.225.239.60 / 2a01:4f8:1c1c:5959::/64 / no protection flags / empty backup_window) reconciles byte-for-byte with the executor's report; the SHA-256 fingerprint of the token file independently computed to `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153` matches the executor's published value (case-insensitive); and the executor's handoff contains only the 4-char prefix `FjEp`, the 4-char suffix `CFj2`, and three copies of the SHA-256 fingerprint — no full token value leaked. Verdict: **PASS**.

## Details

### On-host checks
N/A — this is an API discovery, not an SSH-to-host discovery. All checks are external probes.

### External checks (live re-run from management workstation, 2026-06-27)

| Check (from prompt) | Probe | Expected | Actual | Pass |
|---|---|---|---|---|
| 1. Token verify | `GET https://api.hetzner.cloud/v1/servers/145542849` with `Authorization: Bearer <tok>` | HTTP 200, server `running` | HTTP 200; `id=145542849 name=ubuntu-16gb-nbg1-1 status=running` | yes |
| 2a. Firewalls enumeration (project_id variant — executor's choice) | `GET https://api.hetzner.cloud/v1/firewalls?project_id=15130993` | HTTP 200, `firewalls: []` (or list) | HTTP 200, body `{"firewalls": [], "meta": {"pagination": {"last_page": 1, "next_page": null, "page": 1, "per_page": 25, "previous_page": null, "total_entries": 0}}}` | yes |
| 2b. Firewalls enumeration (project variant — alternative) | `GET https://api.hetzner.cloud/v1/firewalls?project=15130993` | HTTP 200, `firewalls: []` (or list) | HTTP 200, identical body to 2a (`firewalls: []`, total_entries 0) | yes |
| 2c. Firewalls enumeration (no filter — token-broad view) | `GET https://api.hetzner.cloud/v1/firewalls` | HTTP 200, `firewalls: []` (token is scoped to project 15130993 only) | HTTP 200, identical body to 2a and 2b (`firewalls: []`, total_entries 0) | yes |
| 3. Server status + identity | `GET https://api.hetzner.cloud/v1/servers/145542849` | running, cx43, nbg1-dc3, 46.225.239.60, 2a01:4f8:1c1c:5959::/64, no protection, empty backup_window | `status=running server_type_name=cx43 datacenter=nbg1-dc3 location=nbg1 public_ipv4=46.225.239.60 public_ipv6=2a01:4f8:1c1c:5959::/64 protection_delete=False protection_rebuild=False private_net_count=0 backup_window=` | yes |
| 4. No token value in handoff | `[regex] [A-Za-z0-9]{50,80}` over `runs/.../step-06-executor-discovery.md` | only the SHA-256 fingerprint, the 4-char prefix `FjEp`, and the 4-char suffix `CFj2` (all explicitly allowed); no full token value | 3 long-string matches — all three are the SHA-256 fingerprint `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153`. Plus `FjEp` (3 occurrences) and `CFj2` (3 occurrences). No 64-char non-fingerprint string found. | yes |
| 6. Token fingerprint verification | `SHA256(UTF8(token-file-contents))` | `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153` | `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153` (case-insensitive match — the executor reports uppercase hex, which is the canonical formatting) | yes |

### Resources-changed reconciliation

| Executor claim / fact | Observed in current state (live re-run) | Match |
|---|---|---|
| Token validates against project 15130993 (Bearer auth returns 200 on project-scoped routes) | `GET /v1/servers/145542849` → HTTP 200 with full server body | yes |
| Firewalls in project 15130993: 0 | `GET /v1/firewalls?project_id=15130993` → `{"firewalls": [], "meta": {"pagination": {…total_entries: 0}}}` | yes |
| Server status: `running` | `status=running` in re-run probe body | yes |
| Server type: `cx43` (case-insensitive match with landscape's `CX43`) | `server_type.name=cx43` | yes |
| Datacenter: `nbg1-dc3` (Nuremberg DC3), location `nbg1` | `datacenter.name=nbg1-dc3 datacenter.location.name=nbg1` | yes |
| Public IPv4: `46.225.239.60` | `public_net.ipv4.ip=46.225.239.60` | yes |
| Public IPv6: `2a01:4f8:1c1c:5959::/64` | `public_net.ipv6.ip=2a01:4f8:1c1c:5959::/64` | yes |
| `protection.delete=False`, `protection.rebuild=False` | both False | yes |
| `private_net` empty | `private_net.count=0` (array empty) | yes |
| `backup_window` empty (Hetzner Backups option NOT enabled) | `backup_window=` (empty string) | yes |
| Server created: `2026-06-27T04:26:39Z` | `created=2026-06-27T04:26:39Z` | yes |
| Token value: never echoed; referenced by NAME only | Confirmed via leak scan (no full 64-char string other than fingerprint) | yes |
| SHA-256 fingerprint: `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153` | Independently computed: `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153` (lowercase; uppercase canonical form matches) | yes |
| `artifacts_changed: []` (read-only run) | Validator files added (probe scripts, leak scan); `runs/2026-06-27-audit-hetzner-firewall-001/` does NOT contain any modified landscape files | yes (no landscape drift) |

### Audit trail artifacts (created by this validation pass)

- `runs/2026-06-27-audit-hetzner-firewall-001/validator-probe-a-and-c.ps1` — combined probe A (token verify) and probe C (server identity). Single ps1 to avoid command-line escape issues.
- `runs/2026-06-27-audit-hetzner-firewall-001/validator-probe-b.ps1` — probe B (firewalls enumeration) with three URL variants (`?project_id=`, `?project=`, no filter).
- `runs/2026-06-27-audit-hetzner-firewall-001/validator-fingerprint.ps1` — independent SHA-256 fingerprint computation.
- `runs/2026-06-27-audit-hetzner-firewall-001/validator-leak-scan.ps1` + `validator-leak-scan.txt` — regex scan of the executor's handoff for any 50–80 char alphanumeric strings (potential token leak).

None of these files contain the token value; they reference it by path only.

## Issues / risks

- **Minor API-response naming difference (cosmetic, not a finding impact):** the Hetzner Cloud API's `meta.pagination` object uses `last_page` and `previous_page`, not `total_pages` and `previous_page` as the executor's excerpt reported. The executor's body excerpt likely paraphrased the field names (or transcribed an older API version). The finding (`firewalls_count=0`) is unaffected — `total_entries=0` is unambiguous. Flagging here for transparency; not a blocker.
- **Token file used during validation was the SAME file as the executor used** (`C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token`, 64 bytes, prefix `FjEp`, suffix `CFj2`). Fingerprint match confirms it's the same token (not rotated between runs). Good — means we're validating against the exact token the executor used.
- **No token mutation occurred.** The validator ps1 scripts read the file via `[System.IO.File]::ReadAllText(...).Trim()` into a local PowerShell variable, pass it as `Authorization: Bearer …` header to `Invoke-WebRequest`, and exit. No echo, no write to any other file. Audit trail ps1 files were committed via `create_file` with no token content.
- **The audit is robust and reproducible.** Anyone with the token (or a future rotated replacement) can re-run `validator-probe-a-and-c.ps1`, `validator-probe-b.ps1`, and `validator-fingerprint.ps1` and get the same answers (assuming the project firewall state and server config don't change).
- **The host's posture is unchanged by this audit.** No firewall rules were created, modified, or deleted. The finding — that the host is exposed to the public internet with no cloud-layer filtering — is the same finding a casual attacker reconning the IP would observe. This is a real finding for step 08 (and likely a follow-on state-changing workflow) but does not need to be re-classified by this validator.

## Open questions (optional)

- (For step 08 landscape-updater) The executor's recommendation to inline the "no firewall applied" finding in `landscape/hosts/ubuntu-16gb-nbg1-1.md` matches `hetzner-prod`'s precedent (`Hetzner Cloud Firewall: firewall-1 (id=10145783) applied to this server.`) and is the simplest replacement of the current "status unknown" placeholder in "Hardware & OS". Whichever placement is chosen, the default-exposure language must be explicit and not softened — it is a real, currently-unmitigated attack-surface expansion.
- (For step 08 landscape-updater) The validator independently re-confirmed `protection.delete=False` and `protection.rebuild=False` (Hetzner defaults) and `backup_window=""` (Hetzner Backups NOT enabled). These were captured incidentally by the executor's Probe C; both are now independently confirmed. Step 08 may resolve Open Questions item #2 from "status unknown" to "confirmed not enabled (backup_window empty per Hetzner API 2026-06-27, re-confirmed by execution-validator 2026-06-27)".
- (For step 08 landscape-updater) The SHA-256 fingerprint slot for `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` in `landscape/secrets-inventory.md` should be filled with `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153` (uppercase canonical formatting, matching the Cloudflare token fingerprint section's style). This is independently verified. The file-level `last_verified:` should be bumped to `2026-06-27`.
- (For orchestrator after step 08) The validator confirms the audit's conclusion: zero Hetzner Cloud Firewalls in project 15130993, host is exposed at the cloud layer. The natural follow-on state-changing workflow is "apply Hetzner Cloud Firewall to project 15130993 with at minimum an allow-list for the management workstation outbound IP `178.89.57.135`". A separate follow-on could also enable `delete` and `rebuild` protection on the server (currently Hetzner defaults). T-0085 is `kind: task` / `status: in-progress`; the orchestrator decides whether to mark it `done` after a successful audit (likely yes) or keep it open while opening a follow-on task (likely yes).
- (For orchestrator after step 08) The validator's three ps1 scripts are committed under the run directory as audit-trail artifacts. If a dedicated `workflows/discovery-hetzner.md` workflow file is created per step-01's note, the validator scripts should be referenced as the precedent validation block (analogous to how `runs/2026-06-27-discovery-host-001/step-07-execution-validator.md` is referenced for the host pattern).
