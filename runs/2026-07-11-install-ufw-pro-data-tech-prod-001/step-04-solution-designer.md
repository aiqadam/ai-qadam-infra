---
run_id: 2026-07-11-install-ufw-pro-data-tech-prod-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-11T00:00:00Z
task_id: T-0103-install-ufw-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-01-task-reader.md
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-02-landscape-reader.md
  - runs/2026-07-11-install-ufw-pro-data-tech-prod-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - shared/approval-protocol.md
artifacts_changed: []
next_step_hint: user-approval (step 05) — present plan to user; executor (step 06) may proceed only after APPROVED
---

## Summary

Activate UFW on `pro-data-tech-prod` (95.46.211.224) with a deny-incoming baseline and explicit allows for 22/tcp, 80/tcp, and 443/tcp, transitioning the host from fully-open (policy ACCEPT, no rules) to a hardened firewall posture for the first time.

## Details

### Approval reason

`NEEDS_APPROVAL` is required because: (1) this is a first-time firewall activation on a **production** host; (2) blast radius is `medium` — a port misconfiguration before or during `ufw --force enable` would lock out all SSH access with no out-of-band recovery path documented in the landscape; (3) the plan contains an irreversible-until-recovered step (`ufw --force enable` — reverting requires active SSH access, which is itself at risk).

---

### Plan

All commands run as `root` via SSH: `ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" root@95.46.211.224`

**Step 1 — Back up `/etc/default/ufw` before any edit.**

```
cp -p /etc/default/ufw /etc/default/ufw.bak.$(date +%Y%m%dT%H%M%S)
```

Verification: `ls -la /etc/default/ufw.bak.*` shows a single timestamped file; its content matches the original `cat /etc/default/ufw`.

---

**Step 2 — Ensure UFW package is installed (idempotent; already installed per landscape).**

```
apt-get install -y ufw
```

Verification: `dpkg -l ufw | grep '^ii'` exits 0 and shows installed version.

---

**Step 3 — Set `DEFAULT_FORWARD_POLICY="DROP"` in `/etc/default/ufw`.**

```
sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="DROP"/' /etc/default/ufw
```

Idempotency: if the line is already `"DROP"`, the sed expression is a no-op.

Verification: `grep '^DEFAULT_FORWARD_POLICY' /etc/default/ufw` returns `DEFAULT_FORWARD_POLICY="DROP"`.

---

**Step 4 — Set default incoming policy to deny.**

```
ufw default deny incoming
```

Verification: `ufw status verbose` (after full enable) shows `Default: deny (incoming)`.

---

**Step 5 — Set default outgoing policy to allow.**

```
ufw default allow outgoing
```

Verification: `ufw status verbose` shows `Default: allow (outgoing)`.

---

**Step 6 — Allow SSH (port 22/tcp). MUST be applied before step 9.**

```
ufw allow 22/tcp
```

Verification: `ufw show added | grep '22/tcp'` confirms the rule is staged. This step is the primary lockout-prevention control; it MUST succeed with exit code 0 before proceeding.

---

**Step 7 — Allow HTTP (port 80/tcp).**

```
ufw allow 80/tcp
```

Verification: `ufw show added | grep '80/tcp'` confirms rule staged.

---

**Step 8 — Allow HTTPS (port 443/tcp).**

```
ufw allow 443/tcp
```

Verification: `ufw show added | grep '443/tcp'` confirms rule staged.

---

**Step 9 — Enable UFW.**

```
ufw --force enable
```

The `--force` flag suppresses the interactive "may disrupt existing ssh connections" prompt. This is the state-change point. If any prior step failed, the executor MUST abort before reaching this step.

Verification: exit code 0; `ufw status` shows `Status: active`.

---

**Step 10 — Inspect full rule set on-host.**

```
ufw status verbose
```

Expected output contains all of:
- `Status: active`
- `Default: deny (incoming), allow (outgoing), disabled (routed)`
- `22/tcp` — ALLOW IN — Anywhere (v4 + v6)
- `80/tcp` — ALLOW IN — Anywhere (v4 + v6)
- `443/tcp` — ALLOW IN — Anywhere (v4 + v6)

---

**Step 11 — External SSH reconnect verification (from management workstation).**

Close the current SSH session and open a fresh connection:

```
ssh -i "C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk" -o ConnectTimeout=10 root@95.46.211.224 "echo UFW-VERIFY-OK"
```

Expected: exits 0, prints `UFW-VERIFY-OK`. Failure at this step means port 22 is blocked and recovery must begin immediately (see Rollback step R3).

---

### Rollback

Rollback procedures assume SSH access is still available (i.e., a lock-out has NOT yet occurred). If SSH access is lost, provider-console recovery is required — **no out-of-band console is documented in the landscape**; this would require a pro-data.tech support ticket or console access to be arranged manually.

**R1 — Before `ufw --force enable` (if any pre-enable step fails): abort without enabling.**

No rollback needed for the partial configuration — UFW is inactive until step 9. If the sed edit (step 3) produced an incorrect result, restore the backup:

```
cp -p /etc/default/ufw.bak.$(ls -t /etc/default/ufw.bak.* | head -1 | xargs basename) /etc/default/ufw
```

Or more directly (substitute actual timestamp):

```
cp -p /etc/default/ufw.bak.<TIMESTAMP> /etc/default/ufw
```

---

**R2 — After `ufw --force enable`, SSH still reachable: disable UFW.**

```
ufw disable
```

Then restore the `/etc/default/ufw` backup:

```
cp -p /etc/default/ufw.bak.<TIMESTAMP> /etc/default/ufw
```

Verification: `ufw status` shows `Status: inactive`; `iptables -L` shows policy ACCEPT with no rules.

---

**R3 — After `ufw --force enable`, SSH reconnect FAILS (lockout).**

No rollback can be performed via SSH. The following out-of-band recovery path must be followed:

1. Access the pro-data.tech provider control panel console for `drkkrgm-prod-instance`.
2. Log in as root at the console.
3. Run: `ufw disable`
4. Verify SSH is reachable from the management workstation before proceeding.
5. Investigate why the allow-22/tcp rule did not take effect before re-attempting.

> **Note:** This path carries high risk. No provider console credentials or procedure are documented in the landscape. Confirm out-of-band access before executing step 9.

---

### Verification (for step 07)

**On-host:**

1. `ufw status` exits 0 and returns `Status: active`.
2. `ufw status verbose` output contains:
   - `Default: deny (incoming), allow (outgoing), disabled (routed)`
   - `22/tcp` ALLOW IN Anywhere (v4)
   - `22/tcp (v6)` ALLOW IN Anywhere (v6)
   - `80/tcp` ALLOW IN Anywhere (v4)
   - `80/tcp (v6)` ALLOW IN Anywhere (v6)
   - `443/tcp` ALLOW IN Anywhere (v4)
   - `443/tcp (v6)` ALLOW IN Anywhere (v6)
3. `grep '^DEFAULT_FORWARD_POLICY' /etc/default/ufw` returns exactly `DEFAULT_FORWARD_POLICY="DROP"`.
4. `/etc/default/ufw.bak.*` exists (backup was created).
5. `systemctl is-active ssh` returns `active` (sshd still running post-enable).

**External:**

1. From the management workstation, a fresh SSH connection to `root@95.46.211.224` using key `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` succeeds and returns exit code 0.
2. TCP port scan (optional sanity check): `nc -zv 95.46.211.224 22` succeeds; `nc -zv 95.46.211.224 23` fails (connection refused or times out), confirming the deny-incoming default is active for unallowed ports.

---

### Resources used

- **Secrets (by name):** SSH private key referenced as `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (not a managed secret name in `landscape/secrets-inventory.md`; it is the management workstation key used by the executor directly).
- **Files modified on host:**
  - `/etc/default/ufw` (DEFAULT_FORWARD_POLICY line edited)
  - `/etc/default/ufw.bak.<TIMESTAMP>` (created as backup)
  - UFW kernel state (iptables/ip6tables chains populated on enable)
- **Files modified in this repo (landscape/):** `landscape/hosts/pro-data-tech-prod.md` — to be updated at step 08 to reflect: UFW active, rules as configured, last_verified date, removal of security warning for T-0103.
- **External APIs called:** none.

---

### Estimated impact

- **Downtime:** none for SSH (rule applied before enable). No HTTP/HTTPS services are currently running on the host (only port 22 is listening per landscape). Zero-downtime activation expected.
- **Affected services:** sshd (port 22) — rule pre-applied, no interruption expected. All other inbound traffic (previously unrestricted) will be denied after enable — no active workloads are affected since none are deployed.
- **Reversibility:** fully reversible via `ufw disable` while SSH access is maintained. Irreversible without SSH access (requires provider console — see R3).

## Issues / risks

- **SSH lockout risk (HIGH severity):** `ufw allow 22/tcp` (step 6) MUST succeed before `ufw --force enable` (step 9). The executor must verify exit code 0 and confirm the rule appears in `ufw show added` before proceeding to enable. If step 6 produces any error, the executor must ABORT.
- **No documented out-of-band console access:** the landscape does not record provider-console credentials or procedure for `pro-data-tech-prod`. A lockout (R3 scenario) would require ad-hoc provider support contact. This is the primary reason for `NEEDS_APPROVAL`.
- **eth1 private LAN (192.168.0.3/24):** UFW rules without interface specifiers apply to all interfaces, including eth1. Inbound traffic from the provider private LAN will also be subject to the deny-incoming default. This is the desired posture (no workload on the private interface), but the executor and validator should note this in `ufw status verbose` output — both `eth0` and `eth1` traffic is governed by the configured rules.
- **No HTTP/HTTPS services currently listening:** allowing 80/tcp and 443/tcp is forward-looking (per task requirements for when services are deployed). These rules are harmless today but should be recorded in the landscape.
- **Kernel 7.0.0-14-generic (12 pending upgrades):** not a blocker for this task, but the kernel is two minor versions behind QA. iptables/UFW behaviour should be unaffected. Noted for T-0105.
- **Production host (not QA):** any error has higher impact. The external SSH reconnect check (step 11) is mandatory and must not be skipped.
