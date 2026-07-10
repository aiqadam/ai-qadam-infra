---
run_id: 2026-06-27-apply-hetzner-firewall-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-06-27T00:00:00Z
task_id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-apply-hetzner-firewall-001/step-01-task-reader.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-02-landscape-reader.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-03-task-validator.md
  - tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - workflows/infrastructure.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - landscape/secrets-inventory.md
  - landscape/domains.md
  - runs/2026-05-13-install-rustdesk-server-001/step-04-solution-designer.md
artifacts_changed: []
next_step_hint: Halt for user approval (per shared/approval-protocol.md §"Always requires NEEDS_APPROVAL", firewall rule changes ALWAYS require approval regardless of blast radius or reversibility). Present this handoff to the user; on APPROVE the orchestrator writes step-05-user-approval.md and advances to executor-infra (step 06).
---

## Summary

Apply a NEW Hetzner Cloud Firewall named `ai-qadam-mgmt-ssh` in project `15130993` ("ai-qadam") and bind it to server `145542849` (`ubuntu-16gb-nbg1-1`), with a single inbound rule (TCP 22 from `178.89.57.135/32`) and Hetzner-default allow-all outbound; then enable server-side protection flags `protection.delete=true` and `protection.rebuild=true` on the same server. Verdict: **NEEDS_APPROVAL** (mandatory — firewall rule changes are enumerated under `shared/approval-protocol.md` §"Always requires `NEEDS_APPROVAL`" regardless of blast radius or reversibility).

## Details

### Goal

Close the cloud-layer exposure gap documented in the T-0085 audit (project `ai-qadam` currently has zero Hetzner Cloud Firewalls; the host is reachable on all ports from the public internet at the cloud layer). Mirror the pattern of prod `firewall-1` (id `10145783`, project `12287574`) — single-server, minimal inbound rule set scoped to the management workstation, incrementally expanded when the host gets a role. Bundle the two server-side protection flags (`delete`, `rebuild`) as defense-in-depth — both currently at Hetzner defaults (`False`) per the T-0085 audit.

### Design decisions locked in (carried forward from validator recommendation; non-negotiable per approval gate)

1. **Firewall name:** `ai-qadam-mgmt-ssh` (default). User may override at APPROVE time; if renamed, the orchestrator will modify this handoff's name and re-confirm with the user.
2. **Inbound rule:** exactly one — `direction=in, protocol=tcp, port=22, source_ips=["178.89.57.135/32"], description="SSH from management workstation"`. No IPv6 inbound rule. No web ports (80/443) yet — host has no role.
3. **Outbound rules:** NO explicit `rules.outbound` array in the create body. Hetzner defaults to allow-all. The validator confirms this matches the task's "Hetzner default (allow all) — no customization needed" acceptance criterion.
4. **IPv6 inbound scope:** IPv4-only firewall. IPv6 inbound remains unrestricted at the cloud layer until the host gets a role and a deliberate v6 policy is defined. Documented assumption — surfaced in the approval gate.
5. **Create + apply separation:** `POST /v1/firewalls` with rules only (no `applied_to`) → validate create response → `POST /v1/firewalls/{id}/actions/apply_to_resources` to bind to server. Decouples create from apply so the executor can sanity-check the firewall id and rule set BEFORE binding it to the server (lower lockout risk than `applied_to` in the create body).
6. **Protection-flag call shape:** combined `POST /v1/servers/145542849/actions/change_protection` with body `{delete: true, rebuild: true}` (Hetzner API accepts both in one call). Then a single `GET /v1/servers/145542849` whose response confirms both `protection.delete` AND `protection.rebuild` as `true`. This is fewer round-trips than two separate POSTs and still satisfies the "both verified post-set" acceptance criterion.
7. **Idempotency / re-run safety:** executor's pre-flight #2 (`GET /v1/firewalls?project_id=15130993`) detects an existing firewall named `ai-qadam-mgmt-ssh` and halts with a user prompt rather than auto-deleting or creating a duplicate. The executor must NOT auto-delete a pre-existing firewall.

### Plan

The plan below is what the executor (step 06) will run mechanically. Every command is concrete; every verification step is checkable.

---

#### Pre-flight 0: Approval gate verification (executor must perform first)

The executor MUST verify that `runs/2026-06-27-apply-hetzner-firewall-001/step-05-user-approval.md` exists with `verdict: APPROVED` and `inputs_read` referencing this handoff. If absent, or if `step-04-solution-designer.md` `verdict` is not `NEEDS_APPROVAL`, the executor emits `verdict: BLOCKED` and does not call any API.

---

#### Pre-flight 1: Outbound IP re-verification (HARD GATE)

**Purpose:** catch ISP-rotation IP changes between T-0084 (last live-verification) and this run. The IP MUST be `178.89.57.135`. On any other result, HARD ABORT with `verdict: BLOCKED`.

PowerShell command:
```powershell
(Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 15).Content.Trim()
```

Record the output + the ISO-8601 UTC timestamp in the executor's step-06 handoff under "Pre-flight results" before any POST. Expected: literal string `178.89.57.135`.

Failure modes:
- Non-200 response → HARD ABORT. Do NOT POST.
- 200 response with different IP → HARD ABORT with the captured IP surfaced.
- Timeout (no response within 15s) → HARD ABORT (ambiguous — could be `api.ipify.org` outage OR a network change at the workstation).

---

#### Pre-flight 2: Hetzner token scope re-confirmation + zero-firewall re-check (HARD GATE)

**Purpose:** confirm the token is still valid, still scoped to project `15130993`, and that project still has zero firewalls.

PowerShell command (load token from file, then issue API GET):
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode        # expect 200
$resp.Content           # expect: {"firewalls":[],"meta":{"pagination":{"page":1,"per_page":25,"previous_page":null,"next_page":null,"total_entries":0,"total_pages":0}}}
```

Record status code, parsed `total_entries` (must be 0), and ISO-8601 UTC timestamp in the step-06 handoff.

Failure modes:
- HTTP 401/403 → token is invalid or wrong scope → HARD ABORT. Do NOT POST.
- HTTP 200 but `meta.pagination.total_entries > 0` → a firewall already exists in the project → HARD ABORT. Report the existing firewall's id + name in the handoff. The executor must NOT auto-delete a pre-existing firewall.
- Non-200 other than 401/403 → HARD ABORT.

---

#### Pre-flight 3: Server status re-confirmation (HARD GATE)

**Purpose:** confirm server `145542849` is `running` and not in `initializing`, `off`, `rebuilding`, `migrating`, etc.

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode                                                 # expect 200
($resp.Content | ConvertFrom-Json).server.status                 # expect "running"
($resp.Content | ConvertFrom-Json).server.protection.delete      # expect false (will be flipped to true in Step C)
($resp.Content | ConvertFrom-Json).server.protection.rebuild     # expect false (will be flipped to true in Step C)
```

Record status code, `server.status`, both `protection.*` flags, and ISO-8601 UTC timestamp in the step-06 handoff.

Failure modes:
- HTTP 401/403 → token scope issue → HARD ABORT.
- HTTP 200 but `server.status != "running"` → server not ready → HARD ABORT.
- HTTP 404 → server id typo or wrong project → HARD ABORT.

---

#### Pre-flight 4: Live SSH reachability pre-firewall baseline

**Purpose:** capture a baseline `Test-NetConnection` result to confirm SSH was reachable before applying the firewall. If pre-firewall SSH is already broken, no point in adding a firewall.

PowerShell command:
```powershell
Test-NetConnection 46.225.239.60 -Port 22
```

Record the `TcpTestSucceeded` value and ISO-8601 UTC timestamp in the step-06 handoff. Expected: `TcpTestSucceeded : True`.

Failure modes:
- `TcpTestSucceeded : False` → pre-firewall SSH is already broken → HARD ABORT (no point in applying a firewall that we cannot then test through SSH).

This is informational rather than a hard gate (a non-True result here does not necessarily mean the host is unhealthy; it could be a transient network issue), but the executor MUST capture the baseline so post-apply verification (Verify 3) has a clean before/after comparison.

---

#### Step A: Create the Hetzner Cloud Firewall

**Idempotency:** pre-flight 2 already confirmed zero firewalls exist. If a firewall with the same name exists, pre-flight 2 would have caught it (it returns `total_entries > 0`). The Hetzner API does NOT support `POST /v1/firewalls` with an idempotency key; the executor MUST NOT retry this POST on failure. If `POST` returns 4xx/5xx, surface the response body in the handoff and HARD ABORT.

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
    rules = @{
        inbound = @(
            @{
                direction = 'in'
                protocol = 'tcp'
                port = '22'
                source_ips = @('178.89.57.135/32')
                description = 'SSH from management workstation'
            }
        )
    }
} | ConvertTo-Json -Depth 10
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls' -Headers $headers -Method POST -Body $body -TimeoutSec 20
$resp.StatusCode       # expect 201
($resp.Content | ConvertFrom-Json).firewall.id    # capture for Step B
```

Expected: HTTP 201 Created with body `{"firewall": {"id": <new_id>, "name": "ai-qadam-mgmt-ssh", ...}}`. Capture `firewall.id` for Step B. Also capture `firewall.created` for the landscape change-log row.

Record in step-06 handoff: HTTP status code, firewall id, firewall name, ISO-8601 UTC timestamp.

Failure modes:
- HTTP 4xx → HARD ABORT. Do NOT retry. Surface the response body in the handoff.
- HTTP 5xx → HARD ABORT. Do NOT retry (idempotency concerns).

---

#### Step B: Apply the firewall to the server

**Idempotency / safety:** the firewall was just created in Step A and is not yet applied to any resource. The executor MUST verify the create response before issuing this call — specifically, the firewall id and the `firewall.name` (must match `ai-qadam-mgmt-ssh`).

PowerShell command (using the firewall id captured from Step A):
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{
    Authorization = "Bearer $token"
    'Content-Type' = 'application/json'
}
$firewallId = '<id from Step A>'
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

Expected: HTTP 201 Created with body containing action metadata. Hetzner applies the firewall asynchronously; the action object has `status: "running"` initially and transitions to `"success"` within seconds.

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

Record in step-06 handoff: HTTP status code, action id, final action status, ISO-8601 UTC timestamp.

Failure modes:
- HTTP 4xx/5xx on the apply POST → HARD ABORT. The firewall is created but NOT applied. Surface the response body in the handoff; landscape-updater at step 08 must record the orphan firewall in `landscape/hosts/ubuntu-16gb-nbg1-1.md`.
- Action ends in `status: "error"` after polling → HARD ABORT. Same as above.

---

#### Step C: Enable server-side protection flags (combined call)

**Idempotency:** Hetzner `change_protection` action accepts both flags in one call. Setting a flag that is already `true` is a no-op (Hetzner is idempotent for this action). Safe to re-run; no special handling needed.

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

Expected: HTTP 201 Created. Action runs asynchronously; poll until `status: "success"`.

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

Record in step-06 handoff: HTTP status code, action id, final action status, ISO-8601 UTC timestamp.

Failure modes:
- HTTP 4xx/5xx on the POST → HARD ABORT.
- Action ends in `status: "error"` after polling → HARD ABORT. Note for landscape-updater: the firewall may have been applied (Step B succeeded) but the protection flags were not set.

---

#### Verify 1: Firewall exists, rules match, applied_to includes the server

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$firewallId" -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode       # expect 200
($resp.Content | ConvertFrom-Json).firewall.project_id                      # expect "15130993" or 15130993
($resp.Content | ConvertFrom-Json).firewall.name                            # expect "ai-qadam-mgmt-ssh"
($resp.Content | ConvertFrom-Json).firewall.rules.inbound[0].source_ips[0]  # expect "178.89.57.135/32"
($resp.Content | ConvertFrom-Json).firewall.applied_to[0].server.id          # expect 145542849
```

Record in step-06 handoff: full JSON response (or the four fields above).

Failure modes (any one fails):
- `project_id != "15130993"` / `15130993` → HARD ABORT.
- `name != "ai-qadam-mgmt-ssh"` → HARD ABORT (should never happen given Step A captured it).
- `rules.inbound[0].source_ips[0] != "178.89.57.135/32"` → HARD ABORT.
- `applied_to` empty or missing server `145542849` → HARD ABORT.

---

#### Verify 2: Server protection flags are set

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers $headers -Method GET -TimeoutSec 20
$resp.StatusCode                                            # expect 200
($resp.Content | ConvertFrom-Json).server.protection.delete   # expect $true
($resp.Content | ConvertFrom-Json).server.protection.rebuild  # expect $true
```

Record in step-06 handoff: both `protection.delete` and `protection.rebuild` values.

Failure modes (any one fails):
- `protection.delete != true` → HARD ABORT (Step C did not take effect).
- `protection.rebuild != true` → HARD ABORT (Step C did not take effect).

---

#### Verify 3: Live SSH reachability post-firewall

PowerShell command:
```powershell
Test-NetConnection 46.225.239.60 -Port 22
```

Expected: `TcpTestSucceeded : True`.

This MUST succeed. If it fails, the firewall is misconfigured and the host is unreachable from the management workstation. The lockout recovery path is Hetzner Cloud Console → delete the firewall. The executor MUST NOT proceed to Verify 4 if Verify 3 fails; instead, immediately execute the Rollback (Step R1 below).

Record in step-06 handoff: full `Test-NetConnection` output, ISO-8601 UTC timestamp.

Failure modes:
- `TcpTestSucceeded : False` → IMMEDIATELY invoke Rollback (Step R1 below) and HARD ABORT. Do NOT attempt Verify 4.

---

#### Verify 4: Functional SSH

PowerShell command (using SSH config alias):
```powershell
ssh ubuntu-16gb-nbg1-1 'echo ===_OK===; hostname; date; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw; echo ===_END==='
```

Expected: banner containing `===_OK===`, then hostname, then date, then `active` for both fail2ban and ufw, then `===_END===`.

Record in step-06 handoff: full stdout.

Failure modes:
- Any non-`active` value for fail2ban → record as informational; fail2ban post-firewall being `inactive` is unexpected but not catastrophic (the cloud firewall is the outer filter).
- Any non-`active` value for ufw → record as informational; ufw post-firewall being `inactive` is unexpected but not catastrophic.
- Missing `===_OK===` banner or non-zero exit code → HARD ABORT. Rollback (Step R1 below).

---

### Rollback

The rollback exists for two failure modes:
- **Lockout:** Verify 3 (`Test-NetConnection 46.225.239.60 -Port 22`) returns `False` after Step B succeeds. The firewall is misconfigured and SSH is broken.
- **Step C failure:** protection flag `change_protection` action ends in `error` after Step C posts.

#### Step R1: Delete the firewall (reverts Step A + Step B)

PowerShell command:
```powershell
$token = Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token' -Raw
$headers = @{ Authorization = "Bearer $token" }
$resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1/firewalls/$firewallId" -Headers $headers -Method DELETE -TimeoutSec 20
$resp.StatusCode       # expect 204
```

After this call, the firewall is deleted and the server is once again exposed at the cloud layer (pre-run state). The host becomes SSH-reachable again via the same path as before (UFW + fail2ban only).

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

PowerShell commands:
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

Rollback is idempotent — re-running it after a successful rollback is a no-op (Hetzner returns 404 on the DELETE for a non-existent firewall; the executor must treat 404 as success in the rollback path).

---

### Verification (for step 07 — execution-validator)

**On-host (via Hetzner Cloud API):**
1. `GET /v1/firewalls/<firewall_id>` → confirm `project_id == 15130993`, `name == "ai-qadam-mgmt-ssh"`, `rules.inbound[0]` matches design (`direction=in, protocol=tcp, port=22, source_ips=["178.89.57.135/32"]`), `applied_to` contains server `145542849`.
2. `GET /v1/servers/145542849` → confirm `server.protection.delete == true` AND `server.protection.rebuild == true`.
3. `GET /v1/firewalls?project_id=15130993` → confirm the list contains exactly one firewall with the committed name; no orphan firewalls.

**External (from management workstation):**
1. `Test-NetConnection 46.225.239.60 -Port 22` → `TcpTestSucceeded : True`.
2. `ssh ubuntu-16gb-nbg1-1 'echo ===_OK===; hostname; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw; echo ===_END==='` → banner present, both services `active`.

**Negative-space test (NOT directly executable without a second external probe source):**
- A TCP 22 probe from a non-management IP would be expected to fail (no route through `178.89.57.135/32`). This is documented as inferred from the rule set rather than directly probed. Optional: if a phone on cellular is available, run `Test-NetConnection` from there; otherwise note "negative-space inferred from rules".

---

### Resources used

- **Secrets (by name):**
  - `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` — read from `C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token` (SHA-256 fingerprint `fbf81b3a1ab2f3a9be3d3f30c47f32668ea25ae4fcd7363002a54c013cf03153`). Scope: project `15130993` read+write. NOT sufficient to touch project `12287574`.
- **Files modified on host:** none — this run is entirely API-side and does not touch any files on `ubuntu-16gb-nbg1-1`.
- **Files modified in this repo (landscape/) — to be applied at step 08:**
  - `landscape/hosts/ubuntu-16gb-nbg1-1.md` — rewrite "Hetzner Cloud Firewall" section with new firewall id/name/rule list/applied_to; add "Server protection flags" subsection under "Hetzner Cloud Firewall" recording `protection.delete=true`, `protection.rebuild=true`; bump `last_verified: 2026-06-27`; append a change-log row for run `2026-06-27-apply-hetzner-firewall-001`; update "What needs to happen" item #2 to ✅ done; remove T-0086 from "Open tasks affecting this host" after task close.
  - `landscape/services.md` — no expected change; landscape-updater confirms and may add a one-line change-log row referencing the run.
  - `tasks/_index.md` — T-0086 transitions from `in-progress / P1` to `done / P1` at run close.
- **External APIs called:**
  - Hetzner Cloud API (`api.hetzner.cloud/v1`):
    - `GET /v1/firewalls?project_id=15130993` (pre-flight 2 + Verify 3-rollback)
    - `GET /v1/servers/145542849` (pre-flight 3 + Verify 2 + Verify 3-rollback)
    - `POST /v1/firewalls` (Step A)
    - `POST /v1/firewalls/<id>/actions/apply_to_resources` (Step B)
    - `GET /v1/firewalls/<id>/actions/<action_id>` (Step B poll)
    - `POST /v1/servers/145542849/actions/change_protection` (Step C + Step R2)
    - `GET /v1/servers/145542849/actions/<action_id>` (Step C poll)
    - `GET /v1/firewalls/<id>` (Verify 1)
    - `DELETE /v1/firewalls/<id>` (Step R1)
  - `api.ipify.org` (pre-flight 1)

---

### Estimated impact

- **Downtime:** none — the cloud firewall is applied asynchronously, and Hetzner's `apply_to_resources` action completes within seconds. The host's UFW and fail2ban continue to filter traffic throughout. SSH from the management workstation is uninterrupted in the steady state; in the transient window between Step B's POST and Verify 3's probe (~1–2s), there is no functional outage.
- **Affected services:** none (no application services are running on the host). The cloud-layer filtering changes affect future traffic patterns.
- **Reversibility:** **fully reversible** — the firewall can be deleted via `DELETE /v1/firewalls/<id>` and the protection flags can be reverted via a second `change_protection` call. The default state (no firewall, both flags false) is restored in the rollback path. Pre-run state is preserved in `landscape/hosts/ubuntu-16gb-nbg1-1.md` and in the T-0085 audit handoff.
- **Blast radius:** **medium** (per task frontmatter) — applying rules to a project firewall could lock out management if scoped too tight. Mitigated by pre-flight IP re-verification (Pre-flight 1), the create+apply separation (Step A is decoupled from Step B), and the Hetzner Cloud Console + KVM-over-IP fallback.

---

### Workflow-specific rule compliance (per `workflows/infrastructure.md`)

1. **Idempotency:** the create call is guarded by pre-flight 2 (zero-firewall re-check). The apply call is guarded by Step A's create-response verification. The `change_protection` call is idempotent at the Hetzner API level (setting a flag to its current value is a no-op). The executor MUST NOT auto-retry any POST on failure.
2. **Backup before destructive changes:** the only destructive operations are (a) rollback delete (Step R1) and (b) rollback flag revert (Step R2). Both are guarded by a preceding failure that warrants rollback. The pre-run state is captured in `landscape/hosts/ubuntu-16gb-nbg1-1.md` (frontmatter `last_verified: 2026-06-27`, "Hetzner Cloud Firewall: NONE applied") and in the T-0085 audit handoff.
3. **Verify in two places:** Verify 1, 2 (Hetzner Cloud API on-host) + Verify 3, 4 (external SSH reachability from management workstation). Both verification paths are listed with specific success criteria.

---

### Why `NEEDS_APPROVAL` (verdict rationale)

Per `shared/approval-protocol.md` §"When `PASS` — auto-approval sequence", the solution-designer may only emit `PASS` when **ALL** of the following hold:

1. `estimated_blast_radius` in the task file is `low`. — **FAILS** for this run: `estimated_blast_radius: medium` (per `tasks/T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1.md` frontmatter).
2. `estimated_reversibility` in the task file is `full`. — **HOLDS** for this run.
3. The plan has no steps rated as irreversible. — **HOLDS** (firewall + flags are both reversible).
4. The designer has **no doubts or open questions** about the plan. — **HOLDS** (all design decisions locked; all hard gates specified; pre-flight and verification sequence complete).
5. No "Issues / risks" item is flagged as high-severity. — **FAILS** for this run: lockout risk is flagged as **HIGH if mishandled, MEDIUM overall with mitigations in place** (the misconfiguration vector is real even though mitigations are well-designed).

Additionally, per `shared/approval-protocol.md` §"What does and does not need approval", **firewall changes ALWAYS require `NEEDS_APPROVAL`** regardless of blast radius or reversibility. This is the dominant reason for the verdict.

**Verdict: `NEEDS_APPROVAL`.** The orchestrator must halt and present this handoff to the user with the prompt *"Approve this plan? Reply with `APPROVE`, `REJECT <reason>`, or `MODIFY <changes>`."*

---

## Issues / risks

- **Lockout risk — HIGH if mishandled, MEDIUM overall with mitigations.** If the SSH allow rule omits `178.89.57.135/32` (typo, IP mismatch after ISP rotation, etc.), the host becomes unreachable from the management workstation. **Mitigations are well-designed:** (a) pre-flight 1 `api.ipify.org` re-verification immediately before POST, with hard-abort on mismatch; (b) Hetzner Cloud Console provides manual rollback (operator can delete the firewall via console); (c) KVM-over-IP console is available as a last-resort fallback; (d) the create+apply separation pattern lets the executor verify the rule set BEFORE binding to the server; (e) Verify 3 (`Test-NetConnection` post-apply) catches misconfigurations before any further automation runs.
- **Token scope — LOW severity.** Token is project-scoped to `15130993` only — exactly the project this run needs to touch. The executor must NOT attempt to verify against project `12287574` (prod); the token will return `403`/`404` from that project.
- **Idempotency / re-run safety — MEDIUM severity.** Running the run twice without an idempotency guard would create two firewalls in project `15130993`. Pre-flight 2 detects a non-zero firewall count and halts. The executor MUST NOT auto-delete a pre-existing firewall — it should halt and ask the user.
- **API shape uncertainty — LOW severity.** The Hetzner `applied_to[]` resource reference shape (`{type: "server", server: {id: <id>}}`) and the `change_protection` action body shape (`{delete: true, rebuild: true}`) are documented in the Hetzner Cloud API reference. The body shapes in this handoff match that documentation. If the API rejects the body shape, the executor should hard-abort and surface the error — do not guess alternative shapes.
- **IPv6 exposure remains — LOW severity, documented decision.** Under the IPv4-only design, IPv6 inbound remains unrestricted after this run completes. This is an explicit documented decision (per design lock-in #4) and the IPv6 gap will close when the host is assigned a role and a deliberate v6 policy is defined. The IPv6 risk is bounded: the host has no role yet, so no application-layer IPv6 attack surface exists. Not a task-blocker.
- **`PasswordAuthentication yes` on the host — MEDIUM severity, separate task.** The cloud-layer firewall allow rule for `178.89.57.135/32` is restrictive enough that password auth is not the dominant risk, but defense-in-depth is incomplete until a sibling task disables password auth on this host. This is tracked as a follow-on (item #4 in `landscape/hosts/ubuntu-16gb-nbg1-1.md` "What needs to happen"). Informational; not blocking T-0086.
- **PowerShell `Invoke-WebRequest` exit codes — LOW severity.** PowerShell reports `NativeCommandError` for any stderr output from a native tool (see `powershell-native-command-stderr.md` in user memory). The Hetzner API does not write to stderr in normal operation, so this should not bite. The executor should still check `$resp.StatusCode` rather than relying on PowerShell's exit semantics.
- **Firewall name override — LOW severity.** User may rename the firewall at APPROVE time (e.g., to `ai-qadam-ssh` or `ssh-mgmt`). If renamed, the orchestrator should modify the body in this handoff (Step A PowerShell command) and re-confirm with the user before invoking the executor.

## Open questions (optional)

None. All design decisions are locked in. The user may override the firewall name at APPROVE time; that is the only remaining variable. All hard gates (pre-flights 1–4), all verifications (1–4), and all rollback steps (R1–R3) are fully specified. The executor can follow this plan mechanically without making design decisions.