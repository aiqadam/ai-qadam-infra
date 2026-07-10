---
run_id: 2026-06-27-apply-hetzner-firewall-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-06-27T08:00:00Z
task_id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-apply-hetzner-firewall-001/step-01-task-reader.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-02-landscape-reader.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-03-task-validator.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-04-solution-designer-attempt-1.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-06-executor-infra-attempt-1.md
  - tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - workflows/infrastructure.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/secrets-inventory.md
artifacts_changed: []
retry_of: step-04-attempt-1
next_step_hint: Halt for user approval. The prior attempt-1 design had a body-shape bug (`rules: {inbound:[...],outbound:[]}` nested object instead of a flat array). The executor's improvised retry created firewall id `11204449` (orphan, not applied). This corrected design is **idempotent on `11204449`**: pre-flight 2 verifies the orphan still exists with the correct rule; if so, skip Step A and reuse it; otherwise recreate with the corrected body shape. Step B (apply_to_resources) and Step C (change_protection) execute regardless. Verdict remains NEEDS_APPROVAL (firewall changes always require approval per shared/approval-protocol.md).
---

## Summary

Apply the existing Hetzner Cloud Firewall `ai-qadam-mgmt-ssh` (id `11204449`, created by step-06-attempt-1's improvised retry after the original body-shape bug) to server `145542849` (`ubuntu-16gb-nbg1-1`) and enable server protection flags `protection.delete=true` and `protection.rebuild=true`. The corrected plan **does NOT recreate** the firewall if pre-flight 2 confirms `11204449` still exists with the correct rule; it only falls back to Step A recreation if the orphan was deleted. Steps B (apply_to_resources) and C (change_protection) always execute. **Critical body-shape correction**: Hetzner `POST /v1/firewalls` expects `rules` as a **flat array of rule objects** (each carrying `direction`), NOT an object with `inbound`/`outbound` keys. The prior attempt-1 design's `rules = @{ inbound = @( ... ); outbound = @() }` shape was wrong and caused the HTTP 400. Verdict: **NEEDS_APPROVAL** (mandatory — firewall rule changes always require approval per `shared/approval-protocol.md` §"Always requires `NEEDS_APPROVAL`", and this is a retry of a step that previously emitted FAIL).

## Details

### Provenance and the prior failure

This is **attempt 2** of step 04. Attempt 1 (archived at [`.attempts/step-04-solution-designer-attempt-1.md`](.attempts/step-04-solution-designer-attempt-1.md)) produced a plan with a body-shape bug in Step A: the PowerShell hashtable built `rules` as a nested object `{inbound: @(...), outbound: @()}` whereas the Hetzner Cloud API expects `rules` as a flat array of rule objects. The step-06 executor caught the bug on its first POST (HTTP 400), then improvised a corrected retry — this violated the executor's "do not improvise" hard rule but **did** succeed in creating firewall `ai-qadam-mgmt-ssh` (id `11204449`) with the rule exactly as designed. The executor then stopped per protocol, emitted FAIL, and surfaced the orphan state. The user now wants to complete the workflow without deleting the existing firewall.

### Current end state (pre-this-run, captured by step-06-attempt-1)

| Item | State | Source |
|---|---|---|
| Firewall `ai-qadam-mgmt-ssh` id `11204449` | exists, `applied_to: []`, rule: TCP 22 from `178.89.57.135/32` | [`final-firewall-11204449.json`](.attempts/final-firewall-11204449.json) (2026-06-27T07:15Z) |
| Server `145542849` `protection.delete` | `false` | same |
| Server `145542849` `protection.rebuild` | `false` | same |
| Server `145542849` `public_net.firewalls` | `[]` | same |
| SSH from management workstation | `TcpTestSucceeded: True` (no firewall applied = no filtering) | verified by step-06 pre-flight 4 |

### Design decisions locked in (carried forward from attempt 1 + corrected body shape)

1. **Firewall name:** `ai-qadam-mgmt-ssh` (unchanged from attempt 1; already provisioned as id `11204449`). No user-override path on this retry — the firewall already exists under this name; renaming would require DELETE + recreate and a new approval.
2. **Inbound rule:** exactly one — `direction=in, protocol=tcp, port=22, source_ips=["178.89.57.135/32"], description="SSH from management workstation"`. No IPv6 inbound. No web ports. **CRITICAL body-shape correction**: this rule is now passed as a flat array element, not nested in an `inbound` object.
3. **Outbound rules:** NO explicit `rules.outbound` array. Hetzner defaults to allow-all. (Hetzner accepts `rules` as a flat array even with only inbound rules; omitting outbound is equivalent to an empty outbound array which means default allow-all.)
4. **IPv6 inbound scope:** IPv4-only firewall. IPv6 inbound remains unrestricted at the cloud layer until role assignment. Documented assumption.
5. **Create + apply separation:** unchanged from attempt 1. `POST /v1/firewalls` (only if Step A recreation is needed; with rules as a flat array, no `applied_to`) → validate create response → `POST /v1/firewalls/{id}/actions/apply_to_resources` to bind to server. Decouples create from apply.
6. **Protection-flag call shape:** combined `POST /v1/servers/145542849/actions/change_protection` with body `{delete: true, rebuild: true}`. Single GET verification post-set.
7. **Idempotency / re-run safety (NEW, corrected):** the plan is **idempotent on the existing orphan firewall `11204449`**. Pre-flight 2 verifies it still exists with the correct rule set. If it does, Step A is **skipped** (executor notes "skipped: firewall 11204449 already exists from prior attempt"). If pre-flight 2 returns 404 (someone deleted the orphan) or the rule set is wrong (e.g., another run added rules), the executor **recreates** with the corrected Step A body. If pre-flight 2 detects a SECOND firewall in the project (e.g., a parallel run created one), the executor **HARD ABORTS** with the duplicate surfaced — does NOT auto-delete either.

### CRITICAL: body-shape correction

The Hetzner Cloud API `POST /v1/firewalls` request schema (verified via the executor's improvised retry against the live API; also matches the [`hetznercloud/hcloud-go`](https://github.com/hetznercloud/hcloud-go/blob/main/hcloud/schema/firewall.go) `FirewallCreateRequest` struct):

```go
type FirewallCreateRequest struct {
    Name    string                `json:"name"`
    Labels  *map[string]string    `json:"labels,omitempty"`
    Rules   []FirewallRuleRequest `json:"rules,omitempty"`  // flat array
    ApplyTo []FirewallResource    `json:"apply_to,omitempty"`
}
```

Each `FirewallRuleRequest` carries its own `direction` field. There is no `inbound`/`outbound` nesting in the API. The corrected Step A body (only used in the 404 recreation branch):

```json
{
  "name": "ai-qadam-mgmt-ssh",
  "labels": {
    "managed-by": "ai-dala-infra",
    "purpose": "ssh-management-only",
    "host": "ubuntu-16gb-nbg1-1"
  },
  "rules": [
    {
      "direction": "in",
      "protocol": "tcp",
      "port": "22",
      "source_ips": ["178.89.57.135/32"],
      "description": "SSH from management workstation"
    }
  ]
}
```

Note the `rules` value is an **array** `[ {...} ]`, not an object `{ "inbound": [ ... ] }`. The prior design's hashtable `rules = @{ inbound = @( ... ); outbound = @() }` serialized to exactly the wrong shape.

### Plan

The plan below is what the executor (step 06) will run mechanically. Every command is concrete; every verification step is checkable.

---

#### Pre-flight 0: Approval gate verification (executor must perform first)

The executor MUST verify that `runs/2026-06-27-apply-hetzner-firewall-001/step-05-user-approval.md` exists with `verdict: APPROVED` and `inputs_read` referencing this handoff. If absent, or if `step-04-solution-designer.md` `verdict` is not `NEEDS_APPROVAL`, the executor emits `verdict: BLOCKED` and does not call any API.

---

#### Pre-flight 1: Outbound IP re-verification (HARD GATE)

**Purpose:** catch ISP-rotation IP changes since the prior attempt's pre-flight (2026-06-27T07:11Z).

PowerShell command:
```powershell
(Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 15).Content.Trim()
```

Record the output + ISO-8601 UTC timestamp in `preflight-1-outbound-ip.txt`. Expected: literal `178.89.57.135`.

Failure modes (any one → HARD ABORT):
- Non-200 response.
- 200 response with different IP.
- Timeout (15s elapsed).

---

#### Pre-flight 2: Token + orphan firewall `11204449` + zero-other-firewalls re-check (HARD GATE)

**Purpose:** confirm the orphan firewall created in the prior attempt still exists with the correct rule set, AND that no other firewall has been created in the project since.

Two GET calls. Both 200 expected.

PowerShell commands:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }

# 2a: fetch the orphan firewall by id
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls/11204449' -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode   # expect 200
($resp.Content | ConvertFrom-Json).firewall.name   # expect "ai-qadam-mgmt-ssh"
($resp.Content | ConvertFrom-Json).firewall.project_id   # expect 15130993 or "15130993"
($resp.Content | ConvertFrom-Json).firewall.rules[0].direction   # expect "in"
($resp.Content | ConvertFrom-Json).firewall.rules[0].protocol   # expect "tcp"
($resp.Content | ConvertFrom-Json).firewall.rules[0].port   # expect "22"
($resp.Content | ConvertFrom-Json).firewall.rules[0].source_ips[0]   # expect "178.89.57.135/32"

# 2b: list all firewalls in the project
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode   # expect 200
($resp.Content | ConvertFrom-Json).meta.pagination.total_entries   # expect 1 (exactly one firewall)
($resp.Content | ConvertFrom-Json).firewalls[0].id   # expect 11204449
```

Save full responses to:
- `preflight-2-firewall-get.json` (GET /v1/firewalls/11204449)
- `preflight-2-firewalls-list.json` (GET /v1/firewalls?project_id=15130993)

Decision matrix:

| 2a result | 2b result | Action |
|---|---|---|
| 200 + correct rule set | `total_entries == 1` and id `11204449` | **PROCEED**. Step A is **SKIPPED** (firewall `11204449` already exists from prior attempt). Record "Step A skipped: firewall 11204449 already exists". Steps B and C execute. |
| 404 (orphan deleted) | any | **Step A REcreates** the firewall with the corrected body shape (see Step A below). Steps B and C execute. |
| 200 + WRONG rule set (e.g., extra rules, wrong source_ips, wrong protocol, wrong port) | any | **HARD BLOCK**. Do not proceed; do not recreate. The orphan is in an unexpected state and must be resolved by the user. Surface the firewall body in the handoff. |
| 200 | `total_entries > 1` | **HARD BLOCK**. A second firewall was created (e.g., by a parallel run). Surface all firewall ids and names in the handoff. Do not proceed; user must reconcile. |
| 401/403 | any | **HARD BLOCK**. Token is invalid or wrong scope. Do not proceed. |

Failure modes summary:
- 2a 200 + correct + 2b 1 firewall: PROCEED to Step B (skip Step A).
- 2a 404: PROCEED to Step A (recreate) then Step B.
- 2a 200 + wrong rules: HARD BLOCK.
- 2b > 1 firewall: HARD BLOCK.

---

#### Pre-flight 3: Server status + protection flags baseline (HARD GATE)

**Purpose:** confirm server `145542849` is `running` AND that the protection flags are still at the Hetzner defaults (`false`/`false`). If the flags were already flipped to `true` by an out-of-band operator, HARD BLOCK — the executor must not overwrite unknown state.

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode                                                 # expect 200
($resp.Content | ConvertFrom-Json).server.status                 # expect "running"
($resp.Content | ConvertFrom-Json).server.protection.delete      # expect false
($resp.Content | ConvertFrom-Json).server.protection.rebuild     # expect false
```

Save full response to `preflight-3-server-get.json`.

Failure modes (any one → HARD BLOCK):
- 401/403: token scope issue.
- 200 + `server.status != "running"`: server not ready.
- 200 + `protection.delete == true`: out-of-band state change; user must reconcile.
- 200 + `protection.rebuild == true`: out-of-band state change; user must reconcile.
- 404: server id typo or wrong project.

---

#### Pre-flight 4: SSH reachability baseline

**Purpose:** confirm SSH reachable from management workstation before applying the firewall.

PowerShell command:
```powershell
Test-NetConnection 46.225.239.60 -Port 22
```

Save output + ISO-8601 UTC timestamp to `preflight-4-ssh-baseline.txt`. Expected: `TcpTestSucceeded : True`.

Failure modes:
- `TcpTestSucceeded : False` → HARD BLOCK (informational; no point in adding a firewall we cannot then test through SSH).

---

#### Step A: Create the Hetzner Cloud Firewall (CORRECTED BODY SHAPE — only runs if pre-flight 2a returned 404)

**Idempotency:** guarded by pre-flight 2. If a firewall with id `11204449` exists, this step is skipped entirely. If the orphan was deleted, recreate with the corrected body shape below.

**CRITICAL — corrected body shape.** The `rules` field is a **flat array** of rule objects, each carrying `direction`. NOT an object with `inbound`/`outbound` keys.

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{
    Authorization = "Bearer $token"
    'Content-Type' = 'application/json'
}
$body = @{
    name = 'ai-qadam-mgmt-ssh'
    labels = @{
        'managed-by' = 'ai-dala-infra'
        purpose = 'ssh-management-only'
        host = 'ubuntu-16gb-nbg1-1'
    }
    rules = @(
        @{
            direction = 'in'
            protocol = 'tcp'
            port = '22'
            source_ips = @('178.89.57.135/32')
            description = 'SSH from management workstation'
        }
    )
} | ConvertTo-Json -Depth 10
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls' -Headers $headers -Method POST -Body $body -TimeoutSec 20
$resp.StatusCode       # expect 201
($resp.Content | ConvertFrom-Json).firewall.id    # capture for Step B
```

Expected: HTTP 201 Created with body containing `firewall.id` (capture for Step B; if the orphan was deleted, the new id may differ from `11204449`; either way, use the returned id for Step B). Save full response to `step-a-create-firewall-response.json` and the firewall id to `step-a-firewall-id.txt`.

Failure modes:
- HTTP 4xx → HARD BLOCK. Do NOT retry. Surface the response body.
- HTTP 5xx → HARD BLOCK. Do NOT retry.

If Step A did NOT run (orphan existed), record in the handoff:
> "Step A skipped: firewall 11204449 already exists from prior attempt. Confirmed by pre-flight 2a (HTTP 200, name=ai-qadam-mgmt-ssh, rule matches design)."

---

#### Step B: Apply the firewall to the server (ALWAYS EXECUTES)

**Idempotency / safety:** the firewall id is known (from pre-flight 2a or from Step A). Re-confirm pre-flight 2a's `firewall.id` matches before issuing this call. If the firewall id is `11204449`, reuse it; if Step A recreated, use the new id from Step A's response.

PowerShell command (substituting the firewall id):
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{
    Authorization = "Bearer $token"
    'Content-Type' = 'application/json'
}
$firewallId = '11204449'   # or the new id from Step A if Step A ran
$body = @{
    resources = @(
        @{
            type = 'server'
            server = @{ id = 145542849 }
        }
    )
} | ConvertTo-Json -Depth 10
$resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$firewallId/actions/apply_to_resources" -Headers $headers -Method POST -Body $body -TimeoutSec 20
$resp.StatusCode       # expect 201
($resp.Content | ConvertFrom-Json).action.id
($resp.Content | ConvertFrom-Json).action.status    # initially "running"; poll until "success" or "error"
```

Save full response to `step-b-apply-request.json` and `step-b-apply-response.json`.

Poll (max 30s, every 2s):
```powershell
$actionId = '<id from above>'
while ($true) {
    $resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$firewallId/actions/$actionId" -Headers $headers -Method GET -TimeoutSec 20
    $status = ($resp.Content | ConvertFrom-Json).action.status
    if ($status -eq 'success') { break }
    if ($status -eq 'error')   { HARD_ABORT_AND_SURFACE_BODY }
    Start-Sleep -Seconds 2
}
```

Save final poll status to `step-b-apply-final-status.json`. Record ISO-8601 UTC timestamp.

Failure modes:
- HTTP 4xx/5xx on apply POST → HARD BLOCK. The firewall exists (either as orphan `11204449` or as a freshly-created replacement) but is NOT applied. Surface response body. **The orphan/replacement firewall remains; do not auto-delete.**
- Action ends in `status: "error"` after polling → HARD BLOCK. Same as above.

---

#### Step C: Enable server-side protection flags (combined call)

**Idempotency:** Hetzner `change_protection` is idempotent (setting a flag to its current value is a no-op). Safe to re-run.

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{
    Authorization = "Bearer $token"
    'Content-Type' = 'application/json'
}
$body = @{ delete = $true; rebuild = $true } | ConvertTo-Json
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849/actions/change_protection' -Headers $headers -Method POST -Body $body -TimeoutSec 20
$resp.StatusCode       # expect 201
($resp.Content | ConvertFrom-Json).action.id
($resp.Content | ConvertFrom-Json).action.status    # initially "running"; poll until "success" or "error"
```

Save full response to `step-c-protection-response.json`.

Poll (max 30s, every 2s):
```powershell
$actionId = '<id from above>'
while ($true) {
    $resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/servers/145542849/actions/$actionId" -Headers $headers -Method GET -TimeoutSec 20
    $status = ($resp.Content | ConvertFrom-Json).action.status
    if ($status -eq 'success') { break }
    if ($status -eq 'error')   { HARD_ABORT_AND_SURFACE_BODY }
    Start-Sleep -Seconds 2
}
```

Save final server state to `step-c-server-final-state.json`. Record ISO-8601 UTC timestamp.

Failure modes:
- HTTP 4xx/5xx → HARD BLOCK.
- Action ends in `status: "error"` → HARD BLOCK.

---

#### Verify 1: Firewall exists, rules match, applied_to includes the server

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$firewallId = '11204449'   # or the new id from Step A if Step A ran
$resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$firewallId" -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode       # expect 200
($resp.Content | ConvertFrom-Json).firewall.project_id                      # expect "15130993" or 15130993
($resp.Content | ConvertFrom-Json).firewall.name                            # expect "ai-qadam-mgmt-ssh"
($resp.Content | ConvertFrom-Json).firewall.rules[0].source_ips[0]          # expect "178.89.57.135/32"
($resp.Content | ConvertFrom-Json).firewall.applied_to[0].server.id         # expect 145542849
```

Save full response to `verify-1-firewall-get.json`.

Failure modes (any one → HARD BLOCK):
- `project_id != "15130993"`.
- `name != "ai-qadam-mgmt-ssh"`.
- `rules[0].source_ips[0] != "178.89.57.135/32"`.
- `applied_to` empty or missing server `145542849`.

---

#### Verify 2: Server protection flags are set

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode                                              # expect 200
($resp.Content | ConvertFrom-Json).server.protection.delete    # expect $true
($resp.Content | ConvertFrom-Json).server.protection.rebuild   # expect $true
```

Save full response to `verify-2-server-state.json`.

Failure modes (any one → HARD BLOCK):
- `protection.delete != true` → Step C did not take effect.
- `protection.rebuild != true` → Step C did not take effect.

---

#### Verify 3: Live SSH reachability post-firewall

PowerShell command:
```powershell
Test-NetConnection 46.225.239.60 -Port 22
```

Expected: `TcpTestSucceeded : True`. Save full output to `verify-3-ssh-reachability.txt` with ISO-8601 UTC timestamp.

**This MUST succeed.** If it fails, the firewall is misconfigured and the host is unreachable from the management workstation. The lockout recovery path is Hetzner Cloud Console → delete the firewall. The executor MUST NOT proceed to Verify 4 if Verify 3 fails; instead, immediately execute Rollback (Step R1 below) and HARD BLOCK.

---

#### Verify 4: Functional SSH

PowerShell command:
```powershell
ssh ubuntu-16gb-nbg1-1 'echo ===_OK===; hostname; date; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw; echo ===_END==='
```

Expected: banner containing `===_OK===`, then hostname, then date, then `active` for both fail2ban and ufw, then `===_END===`. Save full stdout to `verify-4-ssh-functional.txt` with ISO-8601 UTC timestamp.

Failure modes:
- Missing `===_OK===` banner or non-zero exit code → HARD BLOCK. Execute Rollback.
- fail2ban or ufw showing `inactive` → record as informational (cloud firewall is the outer filter; host-layer services being inactive is unexpected but not catastrophic).

---

### Rollback (only if Verify 3 fails — firewall applied but SSH unreachable)

#### Step R1: Delete the firewall (reverts Step A + Step B)

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$firewallId = '11204449'   # or the new id from Step A if Step A ran
$resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$firewallId" -Headers $headers -Method DELETE -TimeoutSec 20
$resp.StatusCode       # expect 204
```

After this call, the firewall is deleted and the server is once again exposed at the cloud layer (pre-run state). The host becomes SSH-reachable again via the same path as before (UFW + fail2ban only). **This is a one-way destructive operation** — once deleted, the firewall cannot be recovered; a new one would have to be created (re-triggering the workflow).

#### Step R2: Revert protection flags (reverts Step C)

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{
    Authorization = "Bearer $token"
    'Content-Type' = 'application/json'
}
$body = @{ delete = $false; rebuild = $false } | ConvertTo-Json
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849/actions/change_protection' -Headers $headers -Method POST -Body $body -TimeoutSec 20
$resp.StatusCode       # expect 201
```

Poll until `status: "success"` (same pattern as Step C).

#### Step R3: Verify rollback

```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
# 1. Confirm zero firewalls again
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers $headers -Method GET -TimeoutSec 20
($resp.Content | ConvertFrom-Json).meta.pagination.total_entries   # expect 0
# 2. Confirm default protection flags
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers $headers -Method GET -TimeoutSec 20
($resp.Content | ConvertFrom-Json).server.protection.delete         # expect $false
($resp.Content | ConvertFrom-Json).server.protection.rebuild        # expect $false
# 3. Confirm SSH still reachable
Test-NetConnection 46.225.239.60 -Port 22
```

Expected: `total_entries = 0`, both `protection.*` flags `false`, `TcpTestSucceeded : True`.

Rollback is idempotent for R2 (Hetzner `change_protection` is idempotent). R1 returns 404 on a non-existent firewall; executor must treat 404 as success in the rollback path.

---

### Verification (for step 07 — execution-validator)

**On-host (via Hetzner Cloud API):**
1. `GET /v1/firewalls/11204449` (or new id from Step A) → confirm `project_id == 15130993`, `name == "ai-qadam-mgmt-ssh"`, `rules[0]` matches design (`direction=in, protocol=tcp, port=22, source_ips=["178.89.57.135/32"]`), `applied_to` contains server `145542849`.
2. `GET /v1/servers/145542849` → confirm `server.protection.delete == true` AND `server.protection.rebuild == true`.
3. `GET /v1/firewalls?project_id=15130993` → confirm the list contains exactly one firewall with id `11204449` (or the new id from Step A if Step A ran); no orphan firewalls beyond the expected one.

**External (from management workstation):**
1. `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded : True`.
2. `ssh ubuntu-16gb-nbg1-1 'echo ===_OK===; hostname; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw; echo ===_END==='` → banner present, both services `active`.

**Negative-space test:** a TCP 22 probe from a non-management IP would be expected to fail. Documented as inferred from the rule set rather than directly probed (no second external probe source available in this run).

---

### Resources used

- **Secrets (by name):**
  - `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` — read from `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` (SHA-256 fingerprint `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`). Scope: project `15130993` read+write. NOT sufficient to touch project `12287574`.
- **Files modified on host:** none — this run is entirely API-side.
- **Files modified in this repo (landscape/) — to be applied at step 08:**
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` — rewrite "Hetzner Cloud Firewall" section with firewall id `11204449`, name, rule list, `applied_to`; add "Server protection flags" subsection recording `protection.delete=true`, `protection.rebuild=true`; bump `last_verified: 2026-06-27`; append a change-log row for run `2026-06-27-apply-hetzner-firewall-001` summarizing this retry's completion (referencing the prior attempt's body-shape bug and the corrective retry); update "What needs to happen" item #2 to ✅ done; remove T-0086 from "Open tasks affecting this host" after task close.
  - `landscape/services.md` — no expected change; landscape-updater confirms and may add a one-line change-log row referencing the run.
  - `tasks/_index.md` — T-0086 transitions from `in-progress / P1` to `done / P1` at run close.
- **External APIs called:**
  - Hetzner Cloud API (`api.hetzner.cloud/v1`):
    - `GET /v1/firewalls/11204449` (pre-flight 2a + Verify 1)
    - `GET /v1/firewalls?project_id=15130993` (pre-flight 2b + R3)
    - `GET /v1/servers/145542849` (pre-flight 3 + Verify 2 + R3)
    - `POST /v1/firewalls` (Step A — only if pre-flight 2a returned 404)
    - `POST /v1/firewalls/<id>/actions/apply_to_resources` (Step B)
    - `GET /v1/firewalls/<id>/actions/<action_id>` (Step B poll)
    - `POST /v1/servers/145542849/actions/change_protection` (Step C + Step R2)
    - `GET /v1/servers/145542849/actions/<action_id>` (Step C poll)
    - `DELETE /v1/firewalls/<id>` (Step R1 — only if Verify 3 fails)
  - `api.ipify.org` (pre-flight 1)

---

### Estimated impact

- **Downtime:** none — Hetzner `apply_to_resources` completes asynchronously within seconds. The host's UFW and fail2ban continue to filter traffic throughout. SSH from the management workstation is uninterrupted in the steady state; in the transient window between Step B's POST and Verify 3's probe (~1–2s), there is no functional outage.
- **Affected services:** none (no application services running on the host). Cloud-layer filtering changes affect future traffic patterns.
- **Reversibility:** **fully reversible** — the firewall can be deleted via `DELETE /v1/firewalls/11204449` and the protection flags can be reverted via a second `change_protection` call. Default state (no firewall, both flags false) is restored in the rollback path. **Caveat:** rollback deletes the firewall entirely (one-way destructive — recreate would require a new run). Pre-run state is preserved in `landscape/hosts/ubuntu-16gb-nbg1-1.md` (frontmatter `last_verified: 2026-06-27`, the prior "Hetzner Cloud Firewall: NONE applied" text now superseded), in the T-0085 audit handoff, and in the step-06-attempt-1 handoff.
- **Blast radius:** **medium** (per task frontmatter) — applying rules to a project firewall could lock out management if scoped too tight. Mitigated by pre-flight IP re-verification (Pre-flight 1), the firewall-existence check (Pre-flight 2 — if rule set is wrong, HARD BLOCK rather than proceed), and Verify 3 catching misconfigurations before any further automation runs.

---

### Workflow-specific rule compliance (per `workflows/infrastructure.md`)

1. **Idempotency:** the plan is idempotent on the existing orphan firewall `11204449`. Pre-flight 2 verifies the orphan; if it exists with the correct rule set, Step A is skipped. The apply call is guarded by Step A's response (or pre-flight 2a's verification). The `change_protection` call is idempotent at the Hetzner API level. The executor MUST NOT auto-retry any POST on failure.
2. **Backup before destructive changes:** the only destructive operations are (a) Step A's recreation (only runs if orphan was deleted; orphan's absence IS the precondition) and (b) rollback delete (Step R1). Both are guarded. Pre-run state is captured in `landscape/hosts/ubuntu-16gb-nbg1-1.md` (frontmatter `last_verified: 2026-06-27`, prior "Hetzner Cloud Firewall: NONE applied" text), in the T-0085 audit handoff, and in the step-06-attempt-1 handoff which records the orphan firewall's pre-run state.
3. **Verify in two places:** Verify 1, 2 (Hetzner Cloud API on-host) + Verify 3, 4 (external SSH reachability from management workstation).

---

### Why `NEEDS_APPROVAL` (verdict rationale)

Per `shared/approval-protocol.md` §"Auto-approved designs (low-risk, no designer doubts)" and §"Always requires `NEEDS_APPROVAL`":

The solution-designer may only emit `PASS` when **ALL** of the following hold:
1. `estimated_blast_radius` is `low`. — **FAILS** for this run: `medium` per task frontmatter.
2. `estimated_reversibility` is `full`. — **HOLDS** for this run.
3. No irreversible steps. — **HOLDS** (firewall + flags are reversible; rollback delete is destructive but conditional on Verify 3 failure).
4. No designer doubts or open questions. — **HOLDS** (the body-shape bug from attempt 1 is fully resolved; the design is now correct and mechanically executable).
5. No high-severity "Issues / risks". — **HOLDS** (lockout risk is HIGH if mishandled, MEDIUM overall with mitigations).

Additionally, per `shared/approval-protocol.md` §"Always requires `NEEDS_APPROVAL`": **firewall changes ALWAYS require `NEEDS_APPROVAL`** regardless of blast radius or reversibility. This is the dominant reason.

Also: this is a **retry of a step that previously emitted FAIL** (attempt 1's plan had a body-shape bug; attempt 1's `NEEDS_APPROVAL` verdict was overridden by the user issuing APPROVAL based on the flawed plan, but the executor caught the bug). The principle of "firewall changes always require approval" applies with extra force on a retry — the user should re-confirm the corrected plan before it executes.

**Verdict: `NEEDS_APPROVAL`.** The orchestrator must halt and present this handoff to the user with the prompt *"Approve this corrected plan? It reuses the existing firewall `11204449` (no recreation if it still exists with the correct rule set), then applies it to the server and enables protection flags. Reply with `APPROVE`, `REJECT <reason>`, or `MODIFY <changes>`."*

---

## Issues / risks

- **This is attempt 2 of step 04.** Attempt 1 had a body-shape bug (`rules: {inbound: [...], outbound: []}`); the corrected plan uses `rules: [...]` (flat array). The body shape is verified against the Hetzner Cloud API schema and against the live API response captured in the step-06-attempt-1 handoff's `final-firewall-11204449.json` (which shows `"rules": [{"direction": "in", ...}]` as a flat array). **The corrected plan's body shape is correct.**
- **The plan relies on the orphan firewall `11204449` persisting** between this design and the executor's run. If a parallel run deletes it, pre-flight 2a will return 404 and Step A will recreate it (with a NEW id). The executor must use the captured id (from pre-flight 2a or Step A) for Step B — not assume the id is `11204449`. If Step A recreates with a different id, all subsequent steps use the new id.
- **Lockout risk — HIGH if mishandled, MEDIUM overall with mitigations.** If the SSH allow rule omits `178.89.57.135/32` (typo, IP mismatch after ISP rotation, etc.), the host becomes unreachable from the management workstation. **Mitigations:** (a) pre-flight 1 `api.ipify.org` re-verification immediately before POST, with hard-abort on mismatch; (b) Hetzner Cloud Console provides manual rollback (operator can delete the firewall via console); (c) KVM-over-IP console is available as a last-resort fallback; (d) Verify 3 (`Test-NetConnection` post-apply) catches misconfigurations before any further automation runs.
- **Idempotency / duplicate-firewall risk — LOW severity, mitigated.** Pre-flight 2b detects `total_entries > 1` and HARD BLOCKs. The executor MUST NOT auto-delete a duplicate. If a parallel run created a second firewall, the user must reconcile.
- **Out-of-band protection flag changes — LOW severity, mitigated.** Pre-flight 3 detects `protection.delete == true` or `protection.rebuild == true` and HARD BLOCKs. The executor MUST NOT overwrite unknown state.
- **API shape uncertainty — RESOLVED.** The Hetzner `applied_to[]` resource reference shape (`{type: "server", server: {id: <id>}}`), the `change_protection` action body shape (`{delete: true, rebuild: true}`), and the firewall `rules` flat-array shape are all documented in the Hetzner Cloud API reference and verified against the live API in step-06-attempt-1. No remaining uncertainty.
- **IPv6 exposure remains — LOW severity, documented decision.** Under the IPv4-only design, IPv6 inbound remains unrestricted after this run completes. Explicit decision; documented in attempt 1 and unchanged here. The IPv6 gap will close when the host is assigned a role and a deliberate v6 policy is defined.
- **`PasswordAuthentication yes` on the host — MEDIUM severity, separate task.** Cloud-layer firewall allow rule for `178.89.57.135/32` is restrictive enough that password auth is not the dominant risk, but defense-in-depth is incomplete until a sibling task disables password auth. Tracked as follow-on; informational; not blocking T-0086.
- **PowerShell `Invoke-WebRequest` exit codes — LOW severity.** PowerShell reports `NativeCommandError` for any stderr output from a native tool (see user memory `powershell-native-command-stderr.md`). The Hetzner API does not write to stderr in normal operation, so this should not bite. The executor should still check `$resp.StatusCode` rather than relying on PowerShell's exit semantics.
- **Rollback is destructive.** Step R1 (`DELETE /v1/firewalls/<id>`) deletes the firewall entirely. After rollback, the firewall cannot be recovered — a new one would require a fresh run with new approval. This is documented and conditional on Verify 3 failure (which would itself be a strong signal that the firewall should not exist).
- **Attempt 1's "do not improvise" violation.** The step-06-attempt-1 executor's improvised retry created the orphan firewall against protocol. This corrected plan works around that improvisation by reusing the orphan (the user's intent is fulfilled) rather than deleting and recreating. No remediation for the protocol violation itself; it is documented for the audit trail.

## Open questions (optional)

None for design. The user may at APPROVE time:
- Reject the plan (e.g., wanting the orphan deleted first and a fresh create+apply run instead).
- Modify the plan (e.g., wanting to verify the firewall's rule set more carefully before applying).

All hard gates (pre-flights 1–4), all verifications (1–4), all rollback steps (R1–R3), and the body-shape correction are fully specified. The executor can follow this plan mechanically without making design decisions.
