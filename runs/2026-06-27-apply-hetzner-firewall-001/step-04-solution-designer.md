---
run_id: 2026-06-27-apply-hetzner-firewall-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-06-27T09:30:00Z
task_id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-apply-hetzner-firewall-001/step-01-task-reader.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-02-landscape-reader.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-03-task-validator.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-04-solution-designer-attempt-2.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-06-executor-infra-attempt-1.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-06-executor-infra-attempt-2.md
  - tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - workflows/infrastructure.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/secrets-inventory.md
artifacts_changed: []
retry_of: step-04-attempt-2
next_step_hint: Halt for user approval. Attempt-2 design fixed the Step A body shape (`rules` flat array) but left Step B with `resources: [...]` instead of the canonical `apply_to: [...]`. This attempt-3 fixes Step B to match the canonical hcloud-go schema (verified against the upstream source). Pre-flight 2a confirms firewall 11204449 (orphan from attempt-1) still exists with the correct rule set; if so, skip Step A and reuse the existing firewall. Otherwise Step A recreates with the corrected shape. Verdict remains NEEDS_APPROVAL (mandatory per shared/approval-protocol.md).
---

## Summary

Apply the existing Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`, created by step-06-attempt-1's improvised retry after the original body-shape bug) to server `145542849` (`ubuntu-16gb-nbg1-1`) and enable server protection flags `protection.delete=true` and `protection.rebuild=true`. The corrected plan **does NOT recreate** the firewall if pre-flight 2 confirms `11204449` still exists with the correct rule; it only falls back to Step A recreation if the orphan was deleted. Steps B (apply_to_resources) and C (change_protection) always execute.

## Critical body-shape corrections (verified against hetznercloud/hcloud-go)

This is attempt 3 of step-04. Two body-shape bugs have been corrected:

1. **Step A `POST /v1/firewalls`**: `rules` is a **flat array of rule objects**, not a nested object with `inbound`/`outbound` keys. (Fixed in attempt 2.)
2. **Step B `POST /v1/firewalls/{id}/actions/apply_to_resources`**: top-level field is **`apply_to`**, NOT `resources`. (Fixed in this attempt 3.)

Source: `hetznercloud/hcloud-go/hcloud/schema/firewall.go`:
```go
type FirewallActionApplyToResourcesRequest struct {
    ApplyTo []FirewallResource `json:"apply_to"`
}
```

A repo-memory note has been saved to `~/.claude/memory/repo/hetzner-firewall-api.md` capturing both shapes for future runs.

## Plan (idempotent on firewall `11204449`)

### Pre-flight (all hard-abort on failure)

#### Pre-flight 1: Outbound IP re-verification
```
(Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 15).Content.Trim()
```
Expected: `178.89.57.135`. Save to `preflight-1-outbound-ip.txt`.

#### Pre-flight 2a: Orphan firewall still exists
```
GET /v1/firewalls/11204449
Authorization: Bearer <token>
```
Expected HTTP 200 with body containing `name: "ai-qadam-mgmt-ssh"` and `rules: [{direction: "in", protocol: "tcp", port: "22", source_ips: ["178.89.57.135/32"], ...}]`. Save to `preflight-2-firewall-get.json`.

#### Pre-flight 2b: Project firewall count
```
GET /v1/firewalls?project_id=15130993
```
Expected HTTP 200 with `firewalls: [<single entry: firewall id 11204449>]`. If 0 (orphan deleted) → run Step A. If 2+ → BLOCKED. Save to `preflight-2-firewalls-list.json`.

#### Pre-flight 3: Server baseline
```
GET /v1/servers/145542849
```
Expected: status `running`, `protection.delete: false`, `protection.rebuild: false`. If either flag already true → BLOCKED. Save to `preflight-3-server-get.json`.

#### Pre-flight 4: SSH baseline
```
Test-NetConnection 46.225.239.60 -Port 22
```
Expected: `TcpTestSucceeded: True`. Save to `preflight-4-ssh-baseline.txt`.

### Step A: Create firewall (ONLY if pre-flight 2a returned 404)

**Corrected body shape** (flat array for `rules`):

```powershell
$body = @{
  name = "ai-qadam-mgmt-ssh"
  labels = @{
    "managed-by" = "ai-dala-infra"
    "purpose" = "ssh-management-only"
    "host" = "ubuntu-16gb-nbg1-1"
  }
  rules = @(
    @{
      direction = "in"
      protocol = "tcp"
      port = "22"
      source_ips = @("178.89.57.135/32")
      description = "SSH from management workstation"
    }
  )
}
$json = $body | ConvertTo-Json -Depth 10
Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls" -Method POST -Headers @{Authorization = "Bearer $tok"} -Body $json -ContentType "application/json" -UseBasicParsing -TimeoutSec 30
```

Capture response to `step-a-create-firewall-response.json`. Set `$firewallId` from response.

If pre-flight 2a confirmed firewall 11204449 still exists, set `$firewallId = 11204449` and note "skipped" in artifacts.

### Step B: Apply firewall to server (CORRECTED body shape)

**CORRECTED**: top-level field is `apply_to`, not `resources`.

```powershell
$applyBody = @{
  apply_to = @(
    @{
      type = "server"
      server = @{ id = 145542849 }
    }
  )
}
$applyJson = $applyBody | ConvertTo-Json -Depth 10
Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$firewallId/actions/apply_to_resources" -Method POST -Headers @{Authorization = "Bearer $tok"} -Body $applyJson -ContentType "application/json" -UseBasicParsing -TimeoutSec 30
```

Expected: HTTP 201 Created with action object. Capture to:
- `step-b-apply-request.json` (the body sent)
- `step-b-apply-response.json`

Poll action status (every 2s, max 30s):
```
GET /v1/firewalls/$firewallId/actions/<action_id>
```
Wait until `status: "success"`. Capture final status to `step-b-apply-final-status.json`. If `status: "error"` → BLOCKED with the action body.

### Step C: Enable server protection flags

```powershell
$protBody = @{
  delete  = $true
  rebuild = $true
}
$protJson = $protBody | ConvertTo-Json
Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/servers/145542849/actions/change_protection" -Method POST -Headers @{Authorization = "Bearer $tok"} -Body $protJson -ContentType "application/json" -UseBasicParsing -TimeoutSec 30
```

Expected: HTTP 201 Created. Capture to `step-c-protection-response.json`. Poll action status.

Final state verification: `GET /v1/servers/145542849` → save to `step-c-server-final-state.json`. Confirm `server.protection.delete == true` and `server.protection.rebuild == true`.

### Post-apply verification

1. **Verify 1** — firewall applied: `GET /v1/firewalls/$firewallId` → `verify-1-firewall-get.json`. Confirm `applied_to` array contains the server resource.
2. **Verify 2** — protection flags: re-check `step-c-server-final-state.json`. Both flags `true`.
3. **Verify 3** — SSH reachability: `Test-NetConnection 46.225.239.60 -Port 22` → `verify-3-ssh-reachability.txt`. Expected: `TcpTestSucceeded: True`. **If this fails → BLOCKED.**
4. **Verify 4** — functional SSH: `ssh ubuntu-16gb-nbg1-1 "echo ===_OK===; hostname; date; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw; echo ===_END==="` → `verify-4-ssh-functional.txt`. Expected: `===_OK===` banner, hostname, date, fail2ban active, ufw active.

### Rollback (only if Verify 3 fails)

1. `DELETE /v1/firewalls/$firewallId` — capture response
2. `POST /v1/servers/145542849/actions/change_protection` with `{delete: false, rebuild: false}` — capture response
3. Re-verify: SSH reachable, no firewalls in project, default protection flags.

### Artifacts to capture (target: ~16 files)

- preflight-1-outbound-ip.txt
- preflight-2-firewall-get.json
- preflight-2-firewalls-list.json
- preflight-3-server-get.json
- preflight-4-ssh-baseline.txt
- step-a-create-firewall-response.json (only if Step A ran; otherwise absent)
- step-b-apply-request.json
- step-b-apply-response.json
- step-b-apply-final-status.json
- step-c-protection-response.json
- step-c-server-final-state.json
- verify-1-firewall-get.json
- verify-2-server-state.json (alias of step-c-server-final-state.json for clarity)
- verify-3-ssh-reachability.txt
- verify-4-ssh-functional.txt

## Handoff structure

1. Frontmatter with `retry_of: step-04-attempt-2`, `attempt: 3`.
2. **Pre-execution verification result** (the executor will confirm step-04 NEEDS_APPROVAL + step-05 APPROVED before acting).
3. **Pre-flight results**: all 4 with actual outputs.
4. **Step A result**: skipped (firewall 11204449 exists) OR recreated with new id.
5. **Step B result**: apply action status (success expected).
6. **Step C result**: protection flags set (true/true expected).
7. **Post-apply verification**: all 4 verifies.
8. **Rollback executed**: yes/no.
9. **Final state summary.**
10. **Artifacts written.**
11. **Issues / risks** — note this is attempt 3; second body-shape bug (apply_to field name) fixed.

## Issues / risks

- **Body-shape risk (now mitigated)**: both prior body-shape bugs (rules array, apply_to field) are now corrected and verified against `hcloud-go` source. Saved to repo memory for future runs.
- **Lockout risk (HIGH severity)**: if `178.89.57.135` changes between pre-flight 1 and the firewall apply, the host becomes unreachable. Mitigation: pre-flight IP check is the last thing before the POST; Hetzner Cloud Console provides manual fallback.
- **Idempotency**: pre-flight 2a/2b guard against duplicate firewall creation. If the orphan 11204449 was deleted, Step A recreates exactly one firewall.
- **Token scope**: confirmed project-scoped to 15130993. Cannot affect project 12287574 (prod).

## Open questions

None. All body-shape decisions are locked in.

Verdict: **NEEDS_APPROVAL** (mandatory for firewall changes).
