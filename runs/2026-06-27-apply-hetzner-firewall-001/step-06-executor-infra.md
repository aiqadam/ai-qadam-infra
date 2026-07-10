---
run_id: 2026-06-27-apply-hetzner-firewall-001
step: "06"
agent: executor-infra
verdict: PASS
created: 2026-06-27T07:31:45Z
task_id: T-0086-apply-hetzner-cloud-firewall-for-ubuntu-16gb-nbg1-1
inputs_read:
  - runs/2026-06-27-apply-hetzner-firewall-001/step-04-solution-designer.md
  - runs/2026-06-27-apply-hetzner-firewall-001/step-05-user-approval.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-06-executor-infra-attempt-1.md
  - runs/2026-06-27-apply-hetzner-firewall-001/.attempts/step-06-executor-infra-attempt-2.md
  - memories/repo/hetzner-firewall-api.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed:
  - runs/2026-06-27-apply-hetzner-firewall-001/preflight-1-outbound-ip.txt
  - runs/2026-06-27-apply-hetzner-firewall-001/preflight-2-firewall-get.json
  - runs/2026-06-27-apply-hetzner-firewall-001/preflight-2-firewalls-list.json
  - runs/2026-06-27-apply-hetzner-firewall-001/preflight-3-server-get.json
  - runs/2026-06-27-apply-hetzner-firewall-001/preflight-4-ssh-baseline.txt
  - runs/2026-06-27-apply-hetzner-firewall-001/step-b-apply-request.json
  - runs/2026-06-27-apply-hetzner-firewall-001/step-b-apply-response.json
  - runs/2026-06-27-apply-hetzner-firewall-001/step-b-action-id.txt
  - runs/2026-06-27-apply-hetzner-firewall-001/step-b-apply-final-status.json
  - runs/2026-06-27-apply-hetzner-firewall-001/step-c-protection-response.json
  - runs/2026-06-27-apply-hetzner-firewall-001/step-c-action-id.txt
  - runs/2026-06-27-apply-hetzner-firewall-001/step-c-protection-final-status.json
  - runs/2026-06-27-apply-hetzner-firewall-001/step-c-server-final-state.json
  - runs/2026-06-27-apply-hetzner-firewall-001/verify-1-firewall-get.json
  - runs/2026-06-27-apply-hetzner-firewall-001/verify-3-ssh-reachability.txt
  - runs/2026-06-27-apply-hetzner-firewall-001/verify-4-ssh-functional.txt
next_step_hint: All steps + verifications passed. Firewall 11204449 is applied to server 145542849; protection flags delete+rebuild are true; SSH reachable and functional. Landscape updater (step 08) should record this in landscape/hosts/ubuntu-16gb-nbg1-1.md and landscape/hosts/hetzner-prod.md.
retry_of: step-06-attempt-2
attempt: 3
---

## Summary

This is **attempt 3** of step 06. Pre-execution verification (step-04 `verdict: NEEDS_APPROVAL` + step-05 `verdict: APPROVED` with `inputs_read` referencing step-04) PASSED. All 4 hard-gate pre-flights PASSED. **Step A was correctly SKIPPED** (orphan firewall `11204449` from attempt-1 still exists with the corrected rule set). **Step B succeeded** with HTTP 201 + action `status: success, progress: 100%` using the **corrected `apply_to` body field name** (the body-shape bug from attempts 1 and 2 is fully resolved). **Step C succeeded** with HTTP 201 and synchronous action `status: success`; final server state shows `protection.delete=true, protection.rebuild=true` and `public_net.firewalls=[11204449]`. All 4 post-apply verifications PASSED (firewall `applied_to` contains the server; protection flags true/true; SSH TCP reachable; functional SSH succeeds with fail2ban + ufw both active). No rollback required. Verdict: **PASS**.

## Details

### Pre-execution checks (approval gate)

- Approval handoff verified: yes
  - step-04 verdict: `NEEDS_APPROVAL` ✓
  - step-05 verdict: `APPROVED` ✓
  - step-05 `inputs_read` includes `runs/2026-06-27-apply-hetzner-firewall-001/step-04-solution-designer.md` ✓
- Approval gate cleared per `shared/approval-protocol.md` §"Executor verification".

### Pre-flight results (all hard-gate PASS)

#### Pre-flight 1 — Outbound IP re-verification

- Command: `(Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 15).Content.Trim()`
- Output: `178.89.57.135`
- Result: PASS (matches expected management workstation IP)
- Artifact: `preflight-1-outbound-ip.txt`

#### Pre-flight 2a — Orphan firewall 11204449 still exists

- Command: `GET /v1/firewalls/11204449`
- HTTP status: 200
- `firewall.id`: `11204449`
- `firewall.name`: `ai-qadam-mgmt-ssh`
- `firewall.rules[0]`: `direction=in, protocol=tcp, port=22, source_ips=[178.89.57.135/32], description="SSH from management workstation"`
- `firewall.applied_to`: `[]` (still orphan — confirms idempotent path)
- Result: PASS (rule set matches design exactly)
- Artifact: `preflight-2-firewall-get.json`

#### Pre-flight 2b — Project firewall count

- Command: `GET /v1/firewalls?project_id=15130993`
- HTTP status: 200
- `meta.pagination.total_entries`: `1`
- `firewalls[0].id`: `11204449`
- `firewalls[0].name`: `ai-qadam-mgmt-ssh`
- Result: PASS (exactly 1 firewall in project)
- Artifact: `preflight-2-firewalls-list.json`

**Decision:** Step A SKIPPED (firewall 11204449 exists with correct rule set from attempt-1's improvised retry). `$firewallId = 11204449`. No recreation needed.

#### Pre-flight 3 — Server baseline

- Command: `GET /v1/servers/145542849`
- HTTP status: 200
- `server.name`: `ubuntu-16gb-nbg1-1`
- `server.status`: `running`
- `server.protection.delete`: `false`
- `server.protection.rebuild`: `false`
- `server.public_net.firewalls`: `[]`
- Result: PASS (defaults, no firewalls bound, ready for apply)
- Artifact: `preflight-3-server-get.json`

#### Pre-flight 4 — SSH baseline reachability

- Command: `Test-NetConnection 46.225.239.60 -Port 22`
- Output: `TcpTestSucceeded: True`
- Result: PASS
- Artifact: `preflight-4-ssh-baseline.txt`

### Execution log

#### Step A: Create firewall — SKIPPED (per pre-flight 2a)

- Reason: firewall `11204449` already exists with the rule set matching design.
- Verified by: pre-flight 2a (HTTP 200, `name=ai-qadam-mgmt-ssh`, rules match design) + pre-flight 2b (exactly one entry in project).
- `$firewallId = 11204449`. No POST issued. No `step-a-create-firewall-response.json` written this attempt.

#### Step B: Apply firewall to server — PASS

- Command: `POST /v1/firewalls/11204449/actions/apply_to_resources`
- Request body (CORRECTED — uses `apply_to` top-level field, verified against `hcloud-go`):
  ```json
  {
    "apply_to": [
      { "type": "server", "server": { "id": 145542849 } }
    ]
  }
  ```
- HTTP status: **201 Created**
- Response body (action object nested in `actions` array):
  ```json
  {
    "actions": [
      {
        "id": 638945109182443,
        "status": "running",
        "command": "apply_firewall",
        "progress": 10,
        "started": "2026-06-27T07:30:36Z",
        "finished": null,
        "error": null,
        "resources": [
          { "id": 11204449, "type": "firewall" },
          { "id": 145542849, "type": "server" }
        ]
      }
    ]
  }
  ```
- Polled action status: terminal state reached on first poll (~immediate):
  ```json
  {
    "action": {
      "id": 638945109182443,
      "status": "success",
      "command": "apply_firewall",
      "progress": 100,
      "started": "2026-06-27T07:30:36Z",
      "finished": "2026-06-27T07:30:40Z",
      "error": null,
      "resources": [
        { "id": 11204449, "type": "firewall" },
        { "id": 145542849, "type": "server" }
      ]
    }
  }
  ```
- Result: **success** (firewall applied atomically within 4s)
- Backup taken: n/a (apply action is non-destructive)
- Artifacts:
  - `step-b-apply-request.json` (verbatim request body)
  - `step-b-apply-response.json` (HTTP 201 body, actions array)
  - `step-b-action-id.txt` (`638945109182443`)
  - `step-b-apply-final-status.json` (terminal action status)

#### Step C: Enable server protection flags — PASS

- Command: `POST /v1/servers/145542849/actions/change_protection`
- Request body:
  ```json
  { "delete": true, "rebuild": true }
  ```
- HTTP status: **201 Created**
- Response body (action already reports `success, progress: 100, finished` — change_protection is synchronous on this endpoint):
  ```json
  {
    "action": {
      "id": 638945111775820,
      "command": "change_protection",
      "started": "2026-06-27T07:30:55Z",
      "finished": "2026-06-27T07:30:55Z",
      "progress": 100,
      "status": "success",
      "resources": [{ "id": 145542849, "type": "server" }],
      "error": null
    }
  }
  ```
- Final server state (re-GET):
  - `server.name`: `ubuntu-16gb-nbg1-1`
  - `server.status`: `running`
  - `server.protection.delete`: **true** ✓
  - `server.protection.rebuild`: **true** ✓
  - `server.public_net.firewalls`: 1 entry ✓ (firewall 11204449 bound)
- Result: **success** (both protection flags set, firewall bound)
- Note: I attempted to poll the action via `GET /v1/servers/{id}/actions/{action_id}` per the Hetzner API reference, but that endpoint returned `not_found` immediately — Hetzner's server-action-status endpoint does not expose per-action polling for synchronous actions (the action is reported as terminal in the POST response itself). This is informational; the action is verifiably terminal from the POST response and the subsequent server GET confirms the state.
- Artifacts:
  - `step-c-protection-response.json` (HTTP 201, action already terminal)
  - `step-c-action-id.txt` (`638945111775820`)
  - `step-c-protection-final-status.json` (terminal action snapshot from response)
  - `step-c-server-final-state.json` (GET server post-change)

### Post-apply verification

#### Verify 1 — Firewall `applied_to` contains the server

- Command: `GET /v1/firewalls/11204449`
- HTTP status: 200
- `firewall.name`: `ai-qadam-mgmt-ssh`
- `firewall.applied_to`: array of 1 entry
  - `{ "type": "server", "server": { "id": 145542849 } }`
- Result: PASS
- Artifact: `verify-1-firewall-get.json`

#### Verify 2 — Protection flags true/true

- Source: `step-c-server-final-state.json` (re-GET post-change)
- `server.protection.delete`: `true`
- `server.protection.rebuild`: `true`
- Result: PASS

#### Verify 3 — SSH reachability post-firewall (HARD GATE)

- Command: `Test-NetConnection 46.225.239.60 -Port 22`
- Output: `TcpTestSucceeded: True`
- Result: PASS (host still reachable; Hetzner Cloud Firewall permits 178.89.57.135/32 to TCP 22, source matches)
- Artifact: `verify-3-ssh-reachability.txt`

#### Verify 4 — Functional SSH

- Command: `ssh ubuntu-16gb-nbg1-1 'echo ===_OK===; hostname; date; sudo systemctl is-active fail2ban; sudo systemctl is-active ufw; echo ===_END==='`
- Output (trimmed):
  ```
  ===_OK===
  ubuntu-16gb-nbg1-1
  Sat Jun 27 07:31:41 AM UTC 2026
  active
  active
  ===_END===
  ```
- Exit code: 0
- Result: PASS (login succeeded; host-level fail2ban + ufw remain active; lockout risk did not materialize)
- Artifact: `verify-4-ssh-functional.txt`

### Rollback executed

**Not needed.** All verifications passed; the host remains reachable; firewall applied with the correct (allowlist) semantics. The rollback path defined in the design was gated on Verify 3 failure, which did not occur.

### Final state summary

| Item | Pre-run | Post-this-run | Target |
|---|---|---|---|
| Firewall `ai-qadam-mgmt-ssh` id 11204449 | exists, orphan, rule set matches | **exists, applied to server 145542849** | exists, applied to server 145542849 |
| Server `public_net.firewalls` | `[]` | `[11204449]` | contains firewall |
| Server `protection.delete` | `false` | **`true`** | `true` |
| Server `protection.rebuild` | `false` | **`true`** | `true` |
| Management SSH | reachable | reachable | reachable |
| Host fail2ban | active | active | active |
| Host ufw | active | active | active |

System is in the **target state**.

### Resources changed

- **Hetzner Cloud (project 15130993, server 145542849):**
  - Firewall 11204449: `applied_to` changed from `[]` → `[{type: server, server: {id: 145542849}}]`
  - Server 145542849: `protection.delete` changed `false` → `true`
  - Server 145542849: `protection.rebuild` changed `false` → `true`
  - Server 145542849: `public_net.firewalls` changed `[]` → `[11204449]`
- **Files on host (`ubuntu-16gb-nbg1-1`):** none
- **Files in repo:** this handoff + 16 supporting artifacts (listed below); landscape updates are step-08's job
- **External resources:** none

### Artifacts written (16 files in this run directory)

Pre-flight (5):
- `preflight-1-outbound-ip.txt`
- `preflight-2-firewall-get.json`
- `preflight-2-firewalls-list.json`
- `preflight-3-server-get.json`
- `preflight-4-ssh-baseline.txt`

Step B (4):
- `step-b-apply-request.json`
- `step-b-apply-response.json`
- `step-b-action-id.txt`
- `step-b-apply-final-status.json`

Step C (4):
- `step-c-protection-response.json`
- `step-c-action-id.txt`
- `step-c-protection-final-status.json`
- `step-c-server-final-state.json`

Post-apply verification (3):
- `verify-1-firewall-get.json`
- `verify-3-ssh-reachability.txt`
- `verify-4-ssh-functional.txt`

(Step A artifacts from attempt-1's improvised retry remain at `step-a-create-firewall-response.json` and `step-a-firewall-id.txt`; not regenerated this attempt.)

## Issues / risks

1. **Body-shape bugs fully resolved.** Both prior body-shape bugs are fixed and verified against the Hetzner API:
   - Step A: `rules: [...]` (flat array) — already corrected in attempt-2 and confirmed working by attempt-1's improvised retry that created firewall 11204449 (HTTP 201).
   - Step B: `apply_to: [...]` (top-level field) — corrected in step-04 attempt-3, executed in this attempt-3 with HTTP 201 + action `success`. **This is the fix that broke attempts 1 and 2.** A repo-memory note at `memories/repo/hetzner-firewall-api.md` captures the canonical schema for future solution-designers.
   - Step C: `change_protection` body `{delete: true, rebuild: true}` — verified against `hcloud-go schema/server.go` (attempt-2 diagnostic).

2. **Retry budget status (informational).** This run consumed:
   - step-04: 3 attempts (attempt-1 + attempt-2 + attempt-3 PASSED after fix)
   - step-06: 3 attempts (attempt-1 improvised Step A and halted; attempt-2 failed Step B; attempt-3 PASSED)
   - The default retry budget is 2 retries (3 total attempts) per step. Both steps have now exhausted their retry budget with this attempt being the terminal successful attempt. **No further retries are needed.**

3. **PowerShell `NativeCommandError` noise (informational).** The HTTP 201 from this attempt-3's Step B triggered PowerShell's stderr-based `NativeCommandError` reporting (per `powershell-native-command-stderr.md` user memory). The HTTP status was read from `$_.Exception.Response.StatusCode.value__` (where applicable) and parsed from the response object; decisions were driven by `$LASTEXITCODE` / parsed HTTP status / parsed JSON body, never the PowerShell stderr noise.

4. **Server-action polling endpoint unavailable (informational).** I attempted `GET /v1/servers/{id}/actions/{action_id}` to poll Step C's change_protection action per Hetzner API reference; the endpoint returned `not_found` immediately. Hetzner's server-action-status endpoint does not appear to expose per-action polling for this action class (the action is reported as terminal in the POST response itself). Workaround: read the terminal state from the POST response (it included `status: "success", progress: 100, finished: <ts>`) and re-GET the server to confirm persisted state. Both confirmations succeeded.

5. **Token handling.** Token was read from disk via `[System.IO.File]::ReadAllText(...).Trim()` into a local variable (`$tok`), used as `Authorization: Bearer $tok`, never echoed, never written to any file. Length 64, prefix `FjEp`, suffix `CFj2` — matches canonical `hetzner-api-token:ai-dala-infra:ai-qadam-read-write` (fingerprint `FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153`).

6. **Lockout risk did not materialize.** Outbound IP at apply time (`178.89.57.135`) was within the firewall's allowlist (`178.89.57.135/32`). Hetzner Cloud Firewall is enforced at the cloud-edge before host-level UFW + fail2ban; the SSH path from management workstation went through cleanly, and Verify 3 + Verify 4 both succeeded. No rollback path triggered.

7. **Step A orphan reuse — design intent satisfied.** The orphan firewall `11204449` from attempt-1's improvised retry was correctly reused in attempt-3 per the design's idempotency contract. The user's prior "Up to you" approval covered this; no recreation was needed.

## Open questions

- (For landscape-updater at step 08): update `landscape/hosts/ubuntu-16gb-nbg1-1.md` to record the new `last_verified` state including the Hetzner Cloud Firewall binding (id 11204449), and the new `protection.delete=true / protection.rebuild=true` flags. Also note in `landscape/hosts/hetzner-prod.md` the new firewall `ai-qadam-mgmt-ssh` and the apply path used.
- (For execution-validator at step 07): verify pre-flights 1–4 PASSED with artifacts present; verify Step A was correctly skipped; verify Step B succeeded with HTTP 201 + action `success`; verify Step C succeeded with HTTP 201 + both flags `true` + `public_net.firewalls=[11204449]`; verify all 4 post-apply verifications PASSED (artifacts present, SSH reachable, functional SSH succeeds).
- (None for the user — workflow complete from executor's perspective.)
