---
run_id: 2026-07-11-install-ufw-pro-data-tech-prod-001
step: 06
agent: executor-infra
verdict: PASS
created: 2026-07-11T05:50:00Z
task_id: T-0103-install-ufw-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-05-user-approval.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed:
  - host:95.46.211.224:/var/backups/ufw-defaults-pre-T0103.bak
  - host:95.46.211.224:/etc/default/ufw
  - host:95.46.211.224:ufw-rules (22/tcp, 80/tcp, 443/tcp ALLOW IN)
  - host:95.46.211.224:ufw-status (inactive → active)
next_step_hint: proceed to execution-validator (step 07)
---

## Summary

Executed all 11 plan steps in order against `root@95.46.211.224`; UFW is now active with deny-incoming defaults and explicit ALLOW rules for 22/tcp, 80/tcp, and 443/tcp (IPv4 + IPv6). SSH reconnect verification (step 11) passed — no lockout occurred.

## Details

### Pre-execution checks
- Approval handoff verified: yes
- Approval verdict: APPROVED (`runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-05-user-approval.md`)
- Design references match: yes — step-05 `inputs_read` lists step-04 handoff

### Execution log

#### Step 1: Backup /etc/default/ufw
- Command: `ssh ... root@95.46.211.224 "cp /etc/default/ufw /var/backups/ufw-defaults-pre-T0103.bak && echo backup-ok && ls -la /var/backups/ufw-defaults-pre-T0103.bak"`
- Exit code: 0
- Output:
  ```
  backup-ok
  -rw-r--r-- 1 root root 1897 Jul 11 05:45 /var/backups/ufw-defaults-pre-T0103.bak
  ```
- Result: success
- Backup taken: `/var/backups/ufw-defaults-pre-T0103.bak` (1897 bytes, non-empty ✓)

#### Step 2: Install UFW (apt-get)
- Command: `ssh ... root@95.46.211.224 "DEBIAN_FRONTEND=noninteractive apt-get install -y ufw"`
- Exit code: 0
- Output:
  ```
  Reading package lists...
  Building dependency tree...
  Reading state information...
  ufw is already the newest version (0.36.2-9build1).
  ufw set to manually installed.
  Solving dependencies...
  0 upgraded, 0 newly installed, 0 to remove and 12 not upgraded.
  ```
- Result: success (already installed — idempotent)

#### Step 3: Set DEFAULT_FORWARD_POLICY="DROP"
- Command: `ssh ... root@95.46.211.224 "sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=\"DROP\"/' /etc/default/ufw && grep DEFAULT_FORWARD_POLICY /etc/default/ufw"`
- Exit code: non-zero on sed sub-expression (the terminal tool normalized `&&` to `;` and mangled double-quote escaping inside the `s/…/…/` expression, producing "unterminated `s' command"). This was a local shell-quoting artifact, **not a host-side failure**.
- Verification: `grep DEFAULT_FORWARD_POLICY /etc/default/ufw` — run independently immediately after — returned:
  ```
  DEFAULT_FORWARD_POLICY="DROP"
  ```
- Result: success — file already contained the correct value (Ubuntu 26.04 cloud image default is `"DROP"`); sed was a no-op and the desired state is confirmed.

#### Step 4: ufw default deny incoming
- Command: `ssh ... root@95.46.211.224 "ufw default deny incoming"`
- Exit code: 0
- Output:
  ```
  Default incoming policy changed to 'deny'
  (be sure to update your rules accordingly)
  ```
- Result: success

#### Step 5: ufw default allow outgoing
- Command: `ssh ... root@95.46.211.224 "ufw default allow outgoing"`
- Exit code: 0
- Output:
  ```
  Default outgoing policy changed to 'allow'
  (be sure to update your rules accordingly)
  ```
- Result: success

#### Step 6: ufw allow 22/tcp (CRITICAL — before enable)
- Command: `ssh ... root@95.46.211.224 "ufw allow 22/tcp"`
- Exit code: 0
- Output:
  ```
  Rules updated
  Rules updated (v6)
  ```
- Result: success

#### Step 7: ufw allow 80/tcp
- Command: `ssh ... root@95.46.211.224 "ufw allow 80/tcp"`
- Exit code: 0
- Output:
  ```
  Rules updated
  Rules updated (v6)
  ```
- Result: success

#### Step 8: ufw allow 443/tcp
- Command: `ssh ... root@95.46.211.224 "ufw allow 443/tcp"`
- Exit code: 0
- Output:
  ```
  Rules updated
  Rules updated (v6)
  ```
- Result: success

#### Pre-enable verification: ufw show added
- Command: `ssh ... root@95.46.211.224 "ufw show added"`
- Exit code: 0
- Output:
  ```
  Added user rules (see 'ufw status' for running firewall):
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ```
- Result: all three rules staged ✓ — safe to enable

#### Step 9: ufw --force enable
- Command: `ssh ... root@95.46.211.224 "ufw --force enable"`
- Exit code: 0
- Output:
  ```
  Firewall is active and enabled on system startup
  ```
- Result: success — UFW activated

#### Step 10: ufw status verbose
- Command: `ssh ... root@95.46.211.224 "ufw status verbose"`
- Exit code: 0
- Output:
  ```
  Status: active
  Logging: on (low)
  Default: deny (incoming), allow (outgoing), disabled (routed)
  New profiles: skip

  To                         Action      From
  --                         ------      ----
  22/tcp                     ALLOW IN    Anywhere                  
  80/tcp                     ALLOW IN    Anywhere                  
  443/tcp                    ALLOW IN    Anywhere                  
  22/tcp (v6)                ALLOW IN    Anywhere (v6)             
  80/tcp (v6)                ALLOW IN    Anywhere (v6)             
  443/tcp (v6)               ALLOW IN    Anywhere (v6)             
  ```
- Result: success — all expected entries present:
  - `Status: active` ✓
  - `Default: deny (incoming), allow (outgoing), disabled (routed)` ✓
  - `22/tcp` ALLOW IN Anywhere (v4 + v6) ✓
  - `80/tcp` ALLOW IN Anywhere (v4 + v6) ✓
  - `443/tcp` ALLOW IN Anywhere (v4 + v6) ✓

#### Step 11: External SSH reconnect verification
- Command: `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@95.46.211.224 "echo UFW-VERIFY-OK"` (new TCP connection)
- Exit code: 0
- Output:
  ```
  UFW-VERIFY-OK
  ```
- Result: success — SSH access confirmed through active UFW; no lockout

### Rollback executed
Not needed.

### Resources changed
- Files on host: `/var/backups/ufw-defaults-pre-T0103.bak` (backup created); `/etc/default/ufw` (state verified as `DEFAULT_FORWARD_POLICY="DROP"` — unchanged from default)
- Services restarted: none (UFW activated via `ufw --force enable`; iptables rules applied inline; no service restart required)
- External resources changed: none

## Issues / risks

- Step 3 sed produced a local shell-quoting error ("unterminated `s' command") due to the terminal tool normalizing the command. The grep verification confirms the file is in the correct state (`DEFAULT_FORWARD_POLICY="DROP"` — Ubuntu 26.04 cloud image default). No corrective action required.
- 12 package upgrades remain outstanding on the host (noted in landscape; pre-existing, out of scope for T-0103).
- No out-of-band console is documented in the landscape for `drkkrgm-prod-instance`. SSH is now the only recovery path if the UFW configuration is later mis-edited. Recommend provider-console access be documented (out of scope for this task).

## Open questions

none
