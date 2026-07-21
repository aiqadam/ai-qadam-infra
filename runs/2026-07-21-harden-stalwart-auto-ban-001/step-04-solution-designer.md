---
run_id: 2026-07-21-harden-stalwart-auto-ban-001
step: "04"
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-21T00:00:00Z
task_id: T-0121-harden-stalwart-auto-ban-against-bridge-ip
inputs_read:
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-01-task-reader.md
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-02-landscape-reader.md
  - runs/2026-07-21-harden-stalwart-auto-ban-001/step-03-task-validator.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — MEDIUM blast radius, live production mail server, docker compose restart required; present plan to user before executor proceeds
---

## Summary

Add three complementary defences against the recurrence of the 2026-07-20 Stalwart bridge-IP auto-ban incident on `pro-data-tech-prod` (`95.46.211.224`): (A) whitelist the Docker bridge gateway IP `172.19.0.1` in Stalwart's config store, (B) restrict the nginx admin vhost for `mail.aiqadam.org` to loopback-only (requiring SSH port-forwarding for operator browser access going forward), (C) investigate and enable X-Forwarded-For trust in Stalwart if the config knob is available in v0.16; plus a host-resident cron-based mail-reachability monitor and a JMAP emergency-remediation runbook addition in the landscape file. **`NEEDS_APPROVAL` because the plan touches a live production mail server, requires a brief `docker compose restart` (~10–20 s of SMTP/IMAP outage), and changes how operators access the admin UI.**

---

## Details

### Connection preamble (all executor SSH commands use)

```
ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224
```

Sudo is passwordless on this host. The admin password for the Stalwart API is `stalwart-mail-admin-password` (value in `credentials.md` on the management workstation). The executor must read its value from `credentials.md` before starting the SSH session and export it as `STALWART_PASS` in the shell. All `http://127.0.0.1:8080` calls in the plan reach Stalwart directly from the host; no peer-container workaround is needed here (the current bridge IP is **not** banned — that was resolved 2026-07-20 and is the state after incident recovery).

---

### Plan

#### Step 1 — Pre-flight discovery (read-only; no changes)

**1a. Confirm bridge gateway IP and get container bridge IP.**

```bash
docker network inspect stalwart-mail_default \
  --format '{{range .IPAM.Config}}gateway={{.Gateway}} subnet={{.Subnet}}{{end}}'
# Expected: gateway=172.19.0.1 subnet=172.19.0.0/16

CONTAINER_IP=$(docker inspect stalwart-mail-server-1 \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "Container IP: $CONTAINER_IP"
# Expected: 172.19.0.x (exact address noted for later peer-container fallback steps)
```

Verification: both values returned without error; confirm gateway matches the incident record (`172.19.0.1`).

---

**1b. Get exact Stalwart patch version.**

```bash
docker exec stalwart-mail-server-1 stalwart --version
# Expected output: "Stalwart Mail Server v0.16.x"
# Record exact x — needed for changelog cross-reference in Step 3
```

---

**1c. Read the live nginx vhost config.**

```bash
cat /etc/nginx/sites-available/mail.aiqadam.org
```

Record the exact content. Verify: (i) HTTP→HTTPS redirect on port 80 is present; (ii) HTTPS server block on 443 proxies to `http://127.0.0.1:8080`; (iii) whether `proxy_set_header X-Forwarded-For` is already present (determines whether Step 3 must add it).

---

**1d. Inspect Stalwart config store for IP-related settings (auto-ban / allowed-IP / proxy-trust knobs).**

```bash
curl -sf -u "admin:${STALWART_PASS}" http://127.0.0.1:8080/api/settings \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
keys = sorted(k for k in d if any(x in k.lower() for x in
    ['block','ban','allow','trust','proxy','forward','network','security','firewall','ip']))
print(json.dumps({k: d[k] for k in keys}, indent=2))
"
```

Record all matching keys. Specifically look for:
- `server.allowed-ip.*` — allowed-IP whitelist (Mitigation A target)
- `server.blocked-ip.*` — existing blocked IPs (confirm `172.19.0.1` is absent post-recovery)
- `server.proxy.trusted-networks` or `server.trusted-proxy-ips` or `proxy.trusted` — X-Forwarded-For trust (Mitigation C target)

---

**1e. Check current `x:BlockedIp` list (confirm bridge IP is still absent).**

```bash
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:${STALWART_PASS}" -X POST \
  -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/query",{},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap
```

Expected: an IDs list NOT containing any entry for `172.19.0.1`. If `172.19.0.1` appears again (fresh re-ban since recovery), it must be deleted first before proceeding (using the same `x:BlockedIp/set destroy` procedure documented in the "Notes" section of T-0121 and in `landscape/hosts/pro-data-tech-prod.md`). If such a fresh ban is found, pause, delete it, do `docker compose restart`, then re-confirm before continuing the plan.

---

#### Step 2 — Backup

**2a. Backup nginx vhost.**

```bash
sudo cp /etc/nginx/sites-available/mail.aiqadam.org \
  /var/backups/mail.aiqadam.org.pre-T0121.$(date -u +%Y%m%dT%H%M%SZ).bak
ls -lh /var/backups/mail.aiqadam.org.pre-T0121.*.bak
```

Verification: backup file exists, non-zero size.

---

**2b. Export current Stalwart IP settings to backup file.**

```bash
curl -sf -u "admin:${STALWART_PASS}" http://127.0.0.1:8080/api/settings \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
subset = {k: d[k] for k in d if any(x in k.lower() for x in
    ['block','ban','allow','trust','proxy','network','security','firewall','ip'])}
print(json.dumps(subset, indent=2))
" \
  | sudo tee /var/backups/stalwart-ip-settings.pre-T0121.$(date -u +%Y%m%dT%H%M%SZ).bak
```

Verification: backup file exists; contains JSON; `server.blocked-ip.172.19.0.1` key is NOT present (confirms post-recovery clean state).

---

#### Step 3 — Mitigation C: X-Forwarded-For investigation + nginx header addition

**3a. From discovery step 1d and 1c, evaluate the X-Forwarded-For situation:**

Branch on the live discovery output:

**If nginx vhost does NOT contain `proxy_set_header X-Forwarded-For`:** add it.
Inside the HTTPS `server` block's `location /` block, add immediately before `proxy_pass`:
```nginx
proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header  X-Real-IP         $remote_addr;
```
The exact edit is via `sudo sed` or `sudo nano`/`sudo tee` on the vhost file, guided by the live content read in step 1c. After editing, proceed to step 3b.

**If nginx vhost ALREADY contains `proxy_set_header X-Forwarded-For`:** document the finding ("nginx already passes X-Forwarded-For"), skip the nginx header addition here, and still proceed to step 3b.

---

**3b. Check Stalwart's proxy-trust config knob:**

From step 1d output, check whether any `proxy` or `trusted` key was found.

**If a proxy-trust config key exists** (e.g., `server.proxy.trusted-networks`):
```bash
# Enable trust for 127.0.0.1 (where nginx connects from on the host side)
curl -sf -u "admin:${STALWART_PASS}" -X POST \
  -H "Content-Type: application/json" \
  -d '{"server.proxy.trusted-networks": "127.0.0.1"}' \
  http://127.0.0.1:8080/api/settings
# If the key name differs, substitute the exact key name found in discovery step 1d
```
Verification: HTTP 200 returned; re-query settings to confirm key is set.

**If no proxy-trust config knob is found in Stalwart v0.16.x:** document the finding: "Stalwart v0.16.x does not expose a config knob for X-Forwarded-For proxy trust in auto-ban attribution — skip enabling; flag as a follow-on for the next Stalwart version upgrade." Still add the nginx header directives from step 3a (they cost nothing and prepare for when the knob becomes available).

---

#### Step 4 — Mitigation A: Stalwart allowed-IP config

From step 1d output, check whether an `allowed-ip` config key family exists in Stalwart.

**Branch A1 — if `server.allowed-ip.*` key family is present in the settings schema:**

```bash
# Add the bridge gateway IP and its /16 subnet to the allowed-IP list
# (belt-and-suspenders: both the specific gateway IP and the full bridge subnet)
curl -sf -u "admin:${STALWART_PASS}" -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "server.allowed-ip.172.19.0.1": "true",
    "server.allowed-ip.172.19.0.0/16": "true"
  }' \
  http://127.0.0.1:8080/api/settings
```

Verification: HTTP 200; re-query settings:
```bash
curl -sf -u "admin:${STALWART_PASS}" http://127.0.0.1:8080/api/settings \
  | python3 -c "import json,sys; d=json.load(sys.stdin); [print(k,'=',v) for k,v in d.items() if 'allowed-ip' in k]"
# Expected: server.allowed-ip.172.19.0.1 = true
#           server.allowed-ip.172.19.0.0/16 = true
```

Idempotency: re-posting the same key-value pair is a no-op (Stalwart config-store PUT semantics).

Rollback for Branch A1:
```bash
curl -sf -u "admin:${STALWART_PASS}" -X DELETE \
  http://127.0.0.1:8080/api/settings/server.allowed-ip.172.19.0.1
curl -sf -u "admin:${STALWART_PASS}" -X DELETE \
  http://127.0.0.1:8080/api/settings/server.allowed-ip.172.19.0.0%2F16
# Then restart container to flush in-memory state:
cd /opt/stalwart-mail && sudo docker compose restart stalwart
```

**Branch A2 — if `server.allowed-ip.*` key family does NOT exist in v0.16.x:**

Document finding: "Stalwart v0.16.x does not expose a server.allowed-ip.* config key for auto-ban whitelist — skipping Mitigation A. Relying exclusively on Mitigations B (nginx restriction) and C (X-Forwarded-For trust if found). Flag as follow-on for Stalwart version upgrade." No config change is made; proceed to Step 5.

---

#### Step 5 — Mitigation B: nginx admin UI access restriction (loopback-only)

> **OPERATOR IMPACT (flag for approval):** After this step, `https://mail.aiqadam.org/` will return `403 Forbidden` from any external IP address. Operators must use SSH port forwarding to access the Stalwart admin UI in a browser. The SSH tunnel command is:
> ```
> ssh -L 9080:127.0.0.1:8080 -N -i "C:\Users\tvolo\.ssh\ai-dala-infra" tvolodi@95.46.211.224
> # Then open: http://localhost:9080/ in the browser
> ```
> This bypasses nginx entirely and connects directly to Stalwart's loopback listener. The stalwart-cli tool continues to work as-is (it connects to port 8080 directly via loopback). SMTP/IMAP/submission ports (25/465/587/993) are NOT affected by this change — they are not proxied through nginx.

**5a. Idempotency pre-check:**

```bash
grep -q "allow 127.0.0.1" /etc/nginx/sites-available/mail.aiqadam.org \
  && echo "SKIP: allow/deny already present" \
  || echo "PROCEED: need to add allow/deny"
```

If "SKIP": the directives are already there; skip the edit in 5b, still run nginx test (5c) to confirm validity.

**5b. Add `allow`/`deny` to the HTTPS `location /` block:**

Using the exact live content from step 1c, add the following **as the first two directives** inside the HTTPS `server` block's `location /` block (before `proxy_pass`):

```nginx
allow 127.0.0.1;
deny all;
```

The editor should use `sudo` and edit the file in-place. Exact method (sed or text editor) is the executor's choice, guided by the live content. The resulting location block must contain:

```nginx
location / {
    allow 127.0.0.1;
    deny all;
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  # added in step 3a if not pre-existing
    proxy_set_header X-Real-IP $remote_addr;                       # added in step 3a if not pre-existing
    # ... any other headers that were already in the live config
}
```

Note: If the live config has additional headers or directives not listed above, preserve them exactly.

---

**5c. nginx syntax test and graceful reload:**

```bash
sudo nginx -t
# Expected:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

If the test fails: restore from backup (`sudo cp /var/backups/mail.aiqadam.org.pre-T0121.*.bak /etc/nginx/sites-available/mail.aiqadam.org`) and diagnose the parse error before retrying.

```bash
sudo systemctl reload nginx
# Expected: no output (success); service remains active
systemctl is-active nginx
# Expected: active
```

Rollback for Mitigation B (nginx restriction only):
```bash
# Identify the backup file from step 2a:
ls /var/backups/mail.aiqadam.org.pre-T0121.*.bak
sudo cp /var/backups/mail.aiqadam.org.pre-T0121.<timestamp>.bak \
  /etc/nginx/sites-available/mail.aiqadam.org
sudo nginx -t && sudo systemctl reload nginx
```

No-restart (reload only): existing connections are not dropped; the service does not experience outage.

---

#### Step 6 — Docker restart (BRIEF SERVICE INTERRUPTION ~10–20 seconds)

> **INTERRUPTION NOTE:** This step causes ~10–20 seconds of SMTP/IMAP/submission unavailability. SMTP clients that have live connections will receive a TCP RST; most will retry. Schedule during a low-traffic period (e.g., early morning UTC).

Required if:
- Step 4 Branch A1 was executed (Stalwart allowed-IP config changed via API; config must be flushed from in-memory store), OR
- Step 3b found and set a proxy-trust knob (requires restart to take effect).

If both Step 4 and Step 3b were skipped (Branch A2 + no proxy knob found), the restart is still recommended to flush any residual in-memory state, but is not strictly required by the nginx-only change.

```bash
cd /opt/stalwart-mail
sudo docker compose restart stalwart
# Waits for container to stop and restart (~15 seconds)

# Confirm healthy:
sleep 30
docker inspect stalwart-mail-server-1 --format '{{.State.Health.Status}}'
# Expected: healthy
```

Rollback (if restart leaves container in unhealthy state):
```bash
cd /opt/stalwart-mail && sudo docker compose stop stalwart
# Restore Stalwart config settings to pre-change state using the backup from step 2b:
# Re-POST the exact key-value pairs from the backup file, setting deleted keys back:
sudo docker compose start stalwart
sleep 30
docker inspect stalwart-mail-server-1 --format '{{.State.Health.Status}}'
```

If the container stays unhealthy after rollback: escalate as `BLOCKED`; do not proceed.

---

#### Step 7 — Monitoring: install host-resident mail health check

**7a. Create the script:**

```bash
sudo tee /usr/local/bin/mail-health-check.sh > /dev/null << 'SCRIPT'
#!/bin/bash
# mail-health-check.sh — T-0121 monitoring
# Checks Stalwart mail service reachability via Docker proxy path (catches bridge-IP ban scenario).
# Cron: */5 * * * * /usr/local/bin/mail-health-check.sh
set -euo pipefail

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG="/var/log/mail-health-check.log"
FAILED=()

# Check 1: Admin UI via HTTPS — goes through nginx → docker-proxy → container
# This catches the bridge-IP ban scenario (the docker-proxy path uses 172.19.0.1 on the container side)
if ! curl -sf --max-time 15 -o /dev/null https://mail.aiqadam.org/; then
  FAILED+=("https/443/admin-ui")
fi

# Check 2: SMTP (port 25) — via docker-proxy → container
if ! (timeout 5 bash -c '</dev/tcp/127.0.0.1/25') 2>/dev/null; then
  FAILED+=("tcp/25/smtp")
fi

# Check 3: Submission (port 587) — via docker-proxy → container
if ! (timeout 5 bash -c '</dev/tcp/127.0.0.1/587') 2>/dev/null; then
  FAILED+=("tcp/587/submission")
fi

# Check 4: IMAPS (port 993) — via docker-proxy → container
if ! (timeout 5 bash -c '</dev/tcp/127.0.0.1/993') 2>/dev/null; then
  FAILED+=("tcp/993/imaps")
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  MSG="[${TIMESTAMP}] ALERT: mail.aiqadam.org failing checks: ${FAILED[*]}"
  echo "$MSG" | tee -a "$LOG"
  logger -p mail.crit -t mail-health-check "ALERT: ${FAILED[*]}"
  # Optional: POST to a Slack/webhook URL if MAIL_HEALTH_ALERT_WEBHOOK is set in /etc/environment
  if [ -n "${MAIL_HEALTH_ALERT_WEBHOOK:-}" ]; then
    curl -sf --max-time 10 -X POST \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"${MSG}\"}" \
      "$MAIL_HEALTH_ALERT_WEBHOOK" 2>/dev/null || true
  fi
else
  echo "[${TIMESTAMP}] OK: all checks passed" >> "$LOG"
fi
SCRIPT

sudo chmod 755 /usr/local/bin/mail-health-check.sh
```

Verification:
```bash
ls -lh /usr/local/bin/mail-health-check.sh
# Expected: -rwxr-xr-x root root ... /usr/local/bin/mail-health-check.sh
```

---

**7b. Create log file:**

```bash
sudo touch /var/log/mail-health-check.log
sudo chmod 644 /var/log/mail-health-check.log
```

---

**7c. Install cron job (idempotent — removes any existing entry before re-adding):**

```bash
(sudo crontab -l 2>/dev/null | grep -v "mail-health-check.sh"; \
 echo "*/5 * * * * /usr/local/bin/mail-health-check.sh") \
  | sudo crontab -

# Verify:
sudo crontab -l | grep mail-health-check
# Expected: */5 * * * * /usr/local/bin/mail-health-check.sh
```

---

**7d. Run a test invocation:**

```bash
sudo /usr/local/bin/mail-health-check.sh
tail -5 /var/log/mail-health-check.log
# Expected: "[<timestamp>] OK: all checks passed"
# If ALERT appears: investigate before declaring step successful
```

Rollback for monitoring:
```bash
(sudo crontab -l | grep -v "mail-health-check.sh") | sudo crontab -
sudo rm -f /usr/local/bin/mail-health-check.sh
# Keep log file for audit
```

---

#### Step 8 — Verification (for execution-validator step 07)

**8a. nginx tests:**
```bash
sudo nginx -t
# Expected: syntax ok + test successful

systemctl is-active nginx
# Expected: active
```

**8b. Stalwart container health:**
```bash
docker inspect stalwart-mail-server-1 --format '{{.State.Health.Status}}'
# Expected: healthy
docker ps --filter "name=stalwart-mail-server-1" --format "{{.Status}}"
# Expected: Up ... (healthy)
```

**8c. Admin UI — must be reachable from loopback (127.0.0.1) but blocked from external IPs:**
```bash
# From the host (loopback — should succeed after nginx restriction):
curl -sf -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/
# Expected: 200 (direct to Stalwart, bypasses nginx restriction)

# Confirm nginx itself returns 403 from the host's public IP (simulating external access):
curl -sf -o /dev/null -w '%{http_code}' --resolve "mail.aiqadam.org:443:127.0.0.1" https://mail.aiqadam.org/
# Expected: 403 (nginx deny all takes effect from any non-127.0.0.1 source the host presents)
```

Alternatively, the execution-validator (step 07) confirms from the external management workstation:
```
curl -sf -o /dev/null -w '%{http_code}' https://mail.aiqadam.org/
# Expected: 403 (admin UI locked to loopback — confirms nginx restriction is in effect)
```
Note: 403 from external is the EXPECTED AND CORRECT outcome after Mitigation B. This is not a failure.

**8d. Mail ports reachable externally (from management workstation):**
```
# Run from C:\Users\tvolo workstation (PowerShell):
Test-NetConnection -ComputerName mail.aiqadam.org -Port 25
# Expected: TcpTestSucceeded: True

Test-NetConnection -ComputerName mail.aiqadam.org -Port 587
# Expected: TcpTestSucceeded: True

Test-NetConnection -ComputerName mail.aiqadam.org -Port 993
# Expected: TcpTestSucceeded: True
```

Or from the host itself:
```bash
# SMTP:
timeout 5 bash -c '</dev/tcp/127.0.0.1/25' && echo "SMTP OK" || echo "SMTP FAIL"
# Submission:
timeout 5 bash -c '</dev/tcp/127.0.0.1/587' && echo "SUBMISSION OK" || echo "SUBMISSION FAIL"
# IMAPS:
timeout 5 bash -c '</dev/tcp/127.0.0.1/993' && echo "IMAPS OK" || echo "IMAPS FAIL"
# Expected: all three print OK
```

**8e. Monitor script passes:**
```bash
sudo /usr/local/bin/mail-health-check.sh
tail -1 /var/log/mail-health-check.log
# Expected: "[<timestamp>] OK: all checks passed"
```

**8f. Coexistence: Penpot and AiQadam prod unregressed:**
```bash
curl -sf -o /dev/null -w '%{http_code}' https://penpot.aiqadam.org/
# Expected: 200

curl -sf -o /dev/null -w '%{http_code}' https://aiqadam.org/health
# Expected: 200

docker ps --filter "name=penpot-" --format "{{.Names}}: {{.Status}}"
# Expected: 7 penpot-* containers, all "Up ... (healthy)" or "Up ..."
docker ps --filter "name=aiqadam-prod-" --format "{{.Names}}: {{.Status}}"
# Expected: 4 aiqadam-prod-* containers, all Up
```

**8g. nginx reload (not restart) confirmation:**
```bash
# Confirm nginx is in 'active (running)' state, not briefly restarted:
systemctl show nginx --property=ExecMainPID,ActiveState
# Expected: ExecMainPID should be the same PID as before the reload (graceful reload, not restart)
```

---

#### Step 9 — Documentation (repo-side; performed on management workstation, not the host)

This step is a file-edit in the repo, not a host command. The executor-infra's scope is host commands; the executor should note these as pending edits for the landscape-updater (step 08). However, since the task acceptance criteria require this to be done in this run, the executor should perform it as a local file edit on the management workstation immediately after SSHing out.

**Content to add** to `landscape/hosts/pro-data-tech-prod.md`, in the "Stalwart CLI gotchas" section, immediately after the existing auto-ban incident paragraph, as a new sub-section:

```markdown
#### Stalwart JMAP Emergency Remediation — `x:BlockedIp` step-by-step

When external access is broken (502/connection refused) but `docker inspect` shows `healthy`, suspect a Stalwart auto-ban on the Docker bridge gateway IP. Remediate as follows:

**Step R1: Confirm Stalwart is healthy from inside the network (bypass docker-proxy)**
```bash
# Get the container's bridge IP:
CONTAINER_IP=$(docker inspect stalwart-mail-server-1 \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
# Test via peer container (bypasses the banned docker-proxy path entirely):
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf http://${CONTAINER_IP}:8080/healthz/live
# Expected: "healthy" — confirms Stalwart itself is up; the ban is the problem
```

**Step R2: Query the blocked-IP list**
```bash
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:<stalwart-mail-admin-password>" -X POST \
  -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/query",{},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap
# Returns: {"methodResponses":[["x:BlockedIp/query",{"ids":["<id1>","<id2>","..."]},"0"]]}
```

**Step R3: Get details for each ID (find the bridge gateway entry)**
```bash
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:<stalwart-mail-admin-password>" -X POST \
  -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/get",{"ids":["<id1>","<id2>"]},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap
# Returns list with address/reason/createdAt/expiresAt per entry
# Look for address="172.19.0.1" — that is the bridge gateway entry to delete
# Leave genuine external-scanner IPs in place
```

**Step R4: Delete only the bridge gateway entry**
```bash
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:<stalwart-mail-admin-password>" -X POST \
  -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/set",{"destroy":["<id-of-172.19.0.1>"]},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap
# Expected: {"methodResponses":[["x:BlockedIp/set",{"destroyed":["<id>"]},"0"]]}
```

**Step R5: Restart the container to flush in-memory ban state**
```bash
# The on-disk ban entry is now deleted, but Stalwart holds an in-memory copy.
# A restart is mandatory to clear it.
cd /opt/stalwart-mail && sudo docker compose restart stalwart
sleep 30
docker inspect stalwart-mail-server-1 --format '{{.State.Health.Status}}'
# Expected: healthy
```

**Step R6: Verify external access is restored**
```bash
curl -sf -o /dev/null -w '%{http_code}' https://mail.aiqadam.org/
# Expected: 403 if nginx loopback-only restriction is in place (correct post-T-0121)
# OR 200/302 if nginx restriction is not yet applied (pre-T-0121 state)
# SMTP/IMAP:
Test-NetConnection -ComputerName mail.aiqadam.org -Port 25  # from Windows workstation
Test-NetConnection -ComputerName mail.aiqadam.org -Port 993
```

**Key facts:**
- `x:BlockedIp` is an internal (`x:`-prefixed) JMAP type — NOT listed by `stalwart-cli describe`; requires raw JMAP POST.
- The peer-container technique (`docker run --rm --network stalwart-mail_default curlimages/curl:latest curl http://${CONTAINER_IP}:8080/...`) is necessary because the normal `docker exec` path for JMAP calls goes through docker-proxy, which itself is blocked when 172.19.0.1 is banned.
- `expiresAt: null` means the ban is permanent — it will survive any number of container restarts if not deleted from the config store first.
- After T-0121 mitigation, the nginx admin vhost is restricted to `127.0.0.1` only — external browser access requires an SSH tunnel: `ssh -L 9080:127.0.0.1:8080 -N tvolodi@95.46.211.224`, then `http://localhost:9080/`.
```

**Also update the landscape file frontmatter:**
- `last_verified: 2026-07-21`
- Add to `last_verified_note`: "T-0121 done 2026-07-21 via run 2026-07-21-harden-stalwart-auto-ban-001 — three mitigations applied: (A) Stalwart allowed-IP for 172.19.0.1 (if config key exists in v0.16.x; else documented as not available), (B) nginx admin vhost restricted to loopback-only (operators use SSH tunnel for browser access), (C) X-Forwarded-For headers added to nginx vhost + Stalwart proxy-trust configured if available; host-resident cron monitor installed at /usr/local/bin/mail-health-check.sh (every 5 min); JMAP emergency-remediation runbook added to this file."

---

### Rollback (full)

In order (most recently applied change first):

1. **Monitoring:** Remove cron entry and script.
   ```bash
   (sudo crontab -l | grep -v "mail-health-check.sh") | sudo crontab -
   sudo rm -f /usr/local/bin/mail-health-check.sh
   ```

2. **Stalwart allowed-IP (if Branch A1 was executed):**
   ```bash
   curl -sf -u "admin:${STALWART_PASS}" -X DELETE \
     http://127.0.0.1:8080/api/settings/server.allowed-ip.172.19.0.1
   curl -sf -u "admin:${STALWART_PASS}" -X DELETE \
     http://127.0.0.1:8080/api/settings/server.allowed-ip.172.19.0.0%2F16
   ```

3. **Stalwart proxy-trust (if Step 3b set a knob):**
   ```bash
   curl -sf -u "admin:${STALWART_PASS}" -X DELETE \
     http://127.0.0.1:8080/api/settings/server.proxy.trusted-networks
   # Substitute exact key name if different
   ```

4. **Docker restart (to flush Stalwart in-memory state after rollback of any Stalwart config):**
   ```bash
   cd /opt/stalwart-mail && sudo docker compose restart stalwart
   ```

5. **nginx vhost (Mitigation B + any nginx header additions from Mitigation C):**
   ```bash
   sudo cp /var/backups/mail.aiqadam.org.pre-T0121.<timestamp>.bak \
     /etc/nginx/sites-available/mail.aiqadam.org
   sudo nginx -t && sudo systemctl reload nginx
   ```

---

### Verification summary (for execution-validator step 07)

**On-host checks:**

| Check | Command | Expected |
|---|---|---|
| nginx config valid | `sudo nginx -t` | `syntax ok` + `test successful` |
| nginx active | `systemctl is-active nginx` | `active` |
| Stalwart container healthy | `docker inspect stalwart-mail-server-1 --format '{{.State.Health.Status}}'` | `healthy` |
| Stalwart direct loopback | `curl -sf -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/` | `200` |
| nginx allows 127.0.0.1 | `curl -sf -o /dev/null -w '%{http_code}' -H "Host: mail.aiqadam.org" http://127.0.0.1:443/` | _(only testable via https; see external check)_ |
| SMTP from host loopback | `timeout 5 bash -c '</dev/tcp/127.0.0.1/25' && echo OK` | `OK` |
| Submission from host loopback | `timeout 5 bash -c '</dev/tcp/127.0.0.1/587' && echo OK` | `OK` |
| IMAPS from host loopback | `timeout 5 bash -c '</dev/tcp/127.0.0.1/993' && echo OK` | `OK` |
| Cron installed | `sudo crontab -l \| grep mail-health-check` | line present |
| Monitor test run | `sudo /usr/local/bin/mail-health-check.sh && tail -1 /var/log/mail-health-check.log` | `OK: all checks passed` |
| Penpot unregressed | `curl -sf -o /dev/null -w '%{http_code}' https://penpot.aiqadam.org/` | `200` |
| AiQadam prod unregressed | `curl -sf -o /dev/null -w '%{http_code}' https://aiqadam.org/health` | `200` |
| Allowed-IP in Stalwart (if A1) | `curl -sf -u "admin:${STALWART_PASS}" http://127.0.0.1:8080/api/settings \| python3 -c "..."` | `server.allowed-ip.172.19.0.1 = true` |

**External checks (from management workstation):**

| Check | Method | Expected |
|---|---|---|
| Admin UI blocked externally | `curl -o /dev/null -w '%{http_code}' https://mail.aiqadam.org/` | `403` (correct — loopback restriction in effect) |
| SMTP reachable from internet | `Test-NetConnection mail.aiqadam.org -Port 25` | `TcpTestSucceeded: True` |
| Submission reachable | `Test-NetConnection mail.aiqadam.org -Port 587` | `TcpTestSucceeded: True` |
| IMAPS reachable | `Test-NetConnection mail.aiqadam.org -Port 993` | `TcpTestSucceeded: True` |

---

### Resources used

- **Secrets (by name):** `stalwart-mail-admin-password`
- **Files modified on host:**
  - `/etc/nginx/sites-available/mail.aiqadam.org` (nginx vhost — Mitigation B + possible Mitigation C headers)
  - `/usr/local/bin/mail-health-check.sh` (new file — monitoring)
  - `/var/log/mail-health-check.log` (new file — monitoring log)
  - `root` crontab (new entry — monitoring)
  - Stalwart config store (in-process via `/api/settings` POST — Mitigations A and C, if knobs available)
  - Backup files: `/var/backups/mail.aiqadam.org.pre-T0121.*.bak`, `/var/backups/stalwart-ip-settings.pre-T0121.*.bak`
- **Files modified in this repo (landscape/) — for step 08 landscape-updater:**
  - `landscape/hosts/pro-data-tech-prod.md` — add JMAP remediation runbook subsection; update `last_verified` / `last_verified_note`; document discovered Stalwart config knob availability
- **External APIs called:** none (all changes are on-host)

### Estimated impact

- **Downtime:**
  - nginx changes: **zero** — graceful reload; existing connections not dropped
  - `docker compose restart stalwart`: **~10–20 seconds** — SMTP/IMAP/submission unavailable during restart; in-flight SMTP connections will receive TCP RST and most senders will retry automatically
- **Affected services:** Stalwart mail (SMTP/IMAP/submission/admin UI); nginx for `mail.aiqadam.org`; Penpot and AiQadam prod are NOT affected (different stacks, different nginx vhosts)
- **Reversibility:** fully reversible — all changes have explicit rollback steps; backups taken before any modification

---

## Issues / risks

- **Admin UI access change (HIGH UX IMPACT — requires operator consent at approval):** After Mitigation B, `https://mail.aiqadam.org/` returns `403 Forbidden` from all external IPs. Operators (`tvolodi`, `viktor_d`, `binali_r`) who previously accessed the admin UI directly from their browsers must now use an SSH port-forward tunnel. This is a deliberate trade-off: it eliminates the scanning surface that triggered the original incident. The approval gate must surface this trade-off explicitly.

- **Mitigation A conditionality:** Whether Stalwart v0.16.x exposes a `server.allowed-ip.*` config key is unknown until live discovery (step 1d). If Branch A2 applies, the only permanent mitigations are nginx restriction (B) and nginx X-Forwarded-For passthrough (C). This is still a significant reduction in risk but is not the belt-and-suspenders triple-layer design. The executor must document clearly which branch was taken.

- **Mitigation C conditionality:** Whether Stalwart v0.16.x exposes a proxy-trust config knob is similarly unknown until discovery. If not found, this mitigation is deferred to a future Stalwart version upgrade.

- **Monitoring is host-resident, not truly external:** The cron job on `pro-data-tech-prod` shares the failure domain with the monitored service in some failure modes (e.g., the host is unreachable). However, it does correctly catch the specific bridge-IP-ban failure scenario (which is the priority), because the cron-job's `curl https://mail.aiqadam.org/` probe goes through the same nginx→docker-proxy→container path that would be blocked. A truly external monitor (separate host, different network, separate notification channel) is recommended as a follow-on but is out of scope for this task.

- **`docker compose restart` brief interruption:** ~10–20 seconds of SMTP/IMAP unavailability. Most legitimate SMTP senders will auto-retry within minutes. IMAP sessions will drop and clients will reconnect. Plan accordingly: run the restart step outside business hours or during a known low-traffic window.

- **Coexistence:** Steps in this plan do not touch UFW, the Penpot stack, or the AiQadam prod stack. Verification step 8f confirms no regression. No risk of cross-stack impact identified.

- **`allowed-ip` semantics (from GitHub issue #1383):** If the `server.allowed-ip.*` knob exists and is set, its confirmed behavior in prior Stalwart versions is: prevents FUTURE bans on that IP, does not retroactively remove existing bans, and may be overridden if a `server.blocked-ip.*` entry for the same IP is later created by a new auto-ban event on a version without the fix. This makes Mitigation B (nginx lockdown) the more reliable long-term defence even if Mitigation A succeeds.

## Open questions

_(none — all required information is resolvable via live discovery during execution; no design gap blocks the plan)_
