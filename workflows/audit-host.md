---
name: workflow-audit-host
version: 1
description: Read-only vulnerability audit of a managed host. Probes the host for security weaknesses (CVE/patch posture, SSH/sudoers hardening, container security flags, nginx TLS posture, exposed services, log review, world-writable paths). Surfaces findings as observation task files. Does NOT enumerate state for the first time — that is workflows/discovery-host.md.
extends: workflows/_common-operations.md
state_changing: false
skip_design_step: true
---

# Audit: host

Read-only **vulnerability-focused** audit of a managed host. Complements `workflows/discovery-host.md`:

- `discovery-host` answers *"what is on this host?"* — initial state enumeration.
- `audit-host` (this workflow) answers *"what on this host is a security risk?"* — patch posture, configuration hardening, runtime security flags.

Both are `state_changing: false` and skip the approval gate.

## Step bindings

| Step | Agent | Status |
|---|---|---|
| 01 | `task-reader` | required |
| 02 | `landscape-reader` | required |
| 03 | `task-validator` | required |
| 04 | `solution-designer` | **skipped** (`skip_design_step: true`) — probe list lives in this file |
| 05 | user-approval | **skipped** (`state_changing: false`) |
| 06 | **`executor-discovery`** | required |
| 07 | `execution-validator` | required (judges severity of findings, flags drift from landscape) |
| 08 | `landscape-updater` | required (creates observation task files; does NOT modify landscape body — audit findings live in tasks, not landscape) |

## Landscape files in scope

Read:
- `landscape/hosts/<host_id>.md` — the target host (current-state reference)
- `landscape/services.md`
- `landscape/secrets-inventory.md` (for token/key references, never values)
- `tasks/_index.md` — to avoid duplicating already-open observations

Write (at step 08):
- `tasks/T-NNNN-<slug>.md` — one observation task per material finding (see Findings policy below)
- `tasks/_index.md` — index update
- `landscape/hosts/<host_id>.md` — ONLY the `last_verified:` date and a Change log row recording the audit run. No other body edits.

## Probe checklist for executor-discovery

The executor runs each probe in order via `ssh hetzner-prod '<command>'` unless noted. All probes are read-only. The executor captures exit code and output for every probe. **No `sudo` with state-changing payloads. No file writes server-side.**

### A. Pre-flight (sanity)
```bash
whoami && id && hostname && sudo -n true && echo SUDO_OK && uptime && date -u
```

### B. Kernel & OS patch posture
```bash
echo "--- kernel running ---"
uname -r && cat /proc/version
echo "--- reboot-required marker ---"
test -f /var/run/reboot-required && cat /var/run/reboot-required /var/run/reboot-required.pkgs || echo "no reboot-required"
echo "--- pending upgrades ---"
sudo apt list --upgradable 2>/dev/null | tail -n +2
echo "--- security-only pending ---"
sudo apt list --upgradable 2>/dev/null | grep -c -- '-security' || true
echo "--- last unattended-upgrades run ---"
sudo grep -E '^[0-9-]+ [0-9:]+,' /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null | tail -10 || echo "no unattended-upgrades log"
echo "--- unattended-upgrades effective config ---"
apt-config dump | grep -E 'Unattended-Upgrade|APT::Periodic'
echo "--- debsecan if available ---"
which debsecan && sudo debsecan --suite $(lsb_release -cs) --only-fixed 2>/dev/null | head -50 || echo "debsecan not installed (acceptable; would require apt install)"
```

### C. SSH daemon hardening
```bash
echo "--- effective sshd config ---"
sudo sshd -T 2>/dev/null | sort
echo "--- ciphers / KEX / MACs ---"
sudo sshd -T 2>/dev/null | grep -Ei '^(ciphers |kexalgorithms |macs |hostkeyalgorithms |pubkeyacceptedalgorithms |hostbasedacceptedalgorithms |casignaturealgorithms ) ' | sort
echo "--- host keys present ---"
sudo ls -la /etc/ssh/ssh_host_*_key.pub
echo "--- sshd config drop-ins ---"
sudo ls -la /etc/ssh/sshd_config.d/
sudo grep -r '' /etc/ssh/sshd_config.d/ 2>/dev/null
echo "--- authorized_keys posture (count + algo per user) ---"
for u in $(getent passwd | awk -F: '$3>=1000 || $1=="root" {print $1}'); do
  echo "=== $u ==="
  HOME_DIR=$(getent passwd $u | cut -d: -f6)
  sudo test -f $HOME_DIR/.ssh/authorized_keys && {
    sudo stat -c '%n mode=%a owner=%U:%G size=%s' $HOME_DIR/.ssh/authorized_keys
    sudo awk '{print $1}' $HOME_DIR/.ssh/authorized_keys | sort | uniq -c
  } || echo "no authorized_keys"
done
```

### D. sudoers review
```bash
echo "--- /etc/sudoers main ---"
sudo cat /etc/sudoers | grep -v '^#' | grep -v '^$'
echo "--- /etc/sudoers.d/ contents ---"
sudo ls -la /etc/sudoers.d/
sudo grep -r '' /etc/sudoers.d/ 2>/dev/null
echo "--- syntactically valid? ---"
sudo visudo -c -q && echo "VISUDO_OK" || echo "VISUDO_FAILED"
echo "--- members of sudo + admin + wheel ---"
for g in sudo admin wheel; do echo "[$g]"; getent group $g; done
echo "--- members of docker (effectively root) ---"
getent group docker
```

### E. Failed authentication & ban activity
```bash
echo "--- recent failed sshd auths (auth.log) ---"
sudo grep -E 'Failed|Invalid user|authentication failure' /var/log/auth.log 2>/dev/null | tail -50 || echo "no auth.log"
echo "--- last 30 successful logins ---"
last -n 30 --time-format iso
echo "--- fail2ban status ---"
which fail2ban-client && sudo fail2ban-client status 2>/dev/null
echo "--- fail2ban sshd jail ---"
sudo fail2ban-client status sshd 2>/dev/null || echo "no sshd jail"
echo "--- currently banned ---"
sudo fail2ban-client banned 2>/dev/null || true
```

### F. Listening services and exposure
```bash
echo "--- TCP listeners (any bind) ---"
sudo ss -tlnp
echo "--- UDP listeners (any bind) ---"
sudo ss -ulnp
echo "--- summary: bound to 0.0.0.0 or :: (publicly reachable absent firewall) ---"
sudo ss -tlnp | awk 'NR>1 && ($4 ~ /^0\.0\.0\.0:/ || $4 ~ /^\[::\]:/) {print $4, $6}'
sudo ss -ulnp | awk 'NR>1 && ($4 ~ /^0\.0\.0\.0:/ || $4 ~ /^\[::\]:/) {print $4, $6}'
```

### G. Firewall ruleset (UFW + iptables + nftables)
```bash
echo "--- ufw status verbose ---"
sudo ufw status verbose
echo "--- iptables (filter) ---"
sudo iptables -L -n -v --line-numbers | head -120
sudo ip6tables -L -n -v --line-numbers | head -60
echo "--- iptables nat (DOCKER chain published ports) ---"
sudo iptables -t nat -L DOCKER -n -v --line-numbers 2>/dev/null
echo "--- nftables ruleset ---"
sudo nft list ruleset 2>/dev/null | head -150 || echo "no nft tables"
```

### H. Docker daemon and container security
```bash
echo "--- docker version + info ---"
docker --version && sudo docker info --format 'Server={{.ServerVersion}} Containers={{.Containers}} Images={{.Images}} StorageDriver={{.Driver}} CgroupDriver={{.CgroupDriver}} SecurityOpt={{.SecurityOptions}}'
echo "--- daemon config ---"
sudo cat /etc/docker/daemon.json 2>/dev/null || echo "no daemon.json (defaults in effect)"
echo "--- per-container security inspection ---"
for c in $(sudo docker ps -q); do
  echo "=== container $c ==="
  sudo docker inspect $c --format '
Name:          {{.Name}}
Image:         {{.Config.Image}}
ImageID:       {{.Image}}
User:          {{.Config.User}}
Privileged:    {{.HostConfig.Privileged}}
CapAdd:        {{.HostConfig.CapAdd}}
CapDrop:       {{.HostConfig.CapDrop}}
SecurityOpt:   {{.HostConfig.SecurityOpt}}
ReadonlyRoot:  {{.HostConfig.ReadonlyRootfs}}
PidMode:       {{.HostConfig.PidMode}}
NetworkMode:   {{.HostConfig.NetworkMode}}
PortBindings:  {{.HostConfig.PortBindings}}
Mounts:'
  sudo docker inspect $c --format '{{range .Mounts}}  - {{.Type}} {{.Source}} -> {{.Destination}} (rw={{.RW}}){{"\n"}}{{end}}'
  echo "EnvKeys:"
  sudo docker inspect $c --format '{{range .Config.Env}}{{println "  -" .}}{{end}}' | sed 's/=.*$//' | sort -u
done
echo "--- image ages (LOCAL pull/build time, NOT upstream patch date) ---"
sudo docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.CreatedSince}}\t{{.Size}}' | head -40
echo "--- containers with no healthcheck (excluding 'starting' state) ---"
for c in $(sudo docker ps -q); do
  hc=$(sudo docker inspect $c --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}')
  name=$(sudo docker inspect $c --format '{{.Name}}')
  echo "$name: health=$hc"
done
```

### I. nginx TLS posture
```bash
echo "--- nginx version + modules ---"
nginx -V 2>&1 | tr ' ' '\n' | grep -E '^(nginx/|--with-)' | head -30
echo "--- effective config (trimmed) ---"
sudo nginx -T 2>&1 | grep -E '^\s*(ssl_protocols|ssl_ciphers|ssl_prefer_server_ciphers|ssl_session_|ssl_stapling|add_header|server_name|listen )' | sort -u
echo "--- TLS handshake test against each served vhost (locally, sni=hostname) ---"
for h in $(sudo nginx -T 2>/dev/null | awk '/server_name/ {for(i=2;i<=NF;i++){gsub(";",""); if($i!="_") print $i}}' | sort -u); do
  echo "=== $h ==="
  timeout 5 openssl s_client -connect 127.0.0.1:443 -servername $h </dev/null 2>/dev/null | grep -E '^(subject=|issuer=|SSL-Session:|Protocol|Cipher)' | head -10
done
echo "--- cert files on disk ---"
sudo find /etc/nginx /etc/ssl /etc/letsencrypt /root /home -maxdepth 4 -name '*.crt' -o -name '*.pem' -o -name 'fullchain*' 2>/dev/null | head -30
```

### J. Filesystem hygiene
```bash
echo "--- world-writable files NOT in /tmp /proc /sys /dev /run /var/lib/docker /var/log ---"
sudo find / -xdev -type f -perm -0002 \
  -not -path '/tmp/*' -not -path '/proc/*' -not -path '/sys/*' -not -path '/dev/*' \
  -not -path '/run/*' -not -path '/var/lib/docker/*' -not -path '/var/log/*' \
  2>/dev/null | head -50
echo "--- SUID binaries (informational; many are normal) ---"
sudo find / -xdev -type f -perm -4000 -not -path '/var/lib/docker/*' 2>/dev/null | head -50
echo "--- files with broken ownership (no user/no group) ---"
sudo find / -xdev \( -nouser -o -nogroup \) -not -path '/var/lib/docker/*' 2>/dev/null | head -30
echo "--- home directory permissions ---"
sudo ls -la /home/
sudo ls -la /root | head -20
echo "--- /etc/shadow + /etc/sudoers permissions ---"
sudo ls -l /etc/shadow /etc/gshadow /etc/passwd /etc/sudoers
```

### K. Secrets-on-disk scan
```bash
echo "--- compose .env files and likely env files ---"
sudo find / -xdev -name '.env' -o -name '.env.*' -o -name '*.env' 2>/dev/null \
  | grep -v '/proc/' | grep -v '/var/lib/docker/' | head -40
echo "--- world-readable env files (BAD) ---"
sudo find / -xdev \( -name '.env' -o -name '.env.*' \) -perm -004 2>/dev/null \
  | grep -v '/proc/' | grep -v '/var/lib/docker/' | head -30
echo "--- key files (informational; PEM/PFX/JWK keys outside /etc/ssl) ---"
sudo find / -xdev \( -name 'id_rsa' -o -name 'id_ed25519' -o -name '*.key' -o -name '*.pem' -o -name '*.pfx' -o -name 'known_hosts' \) \
  -not -path '/proc/*' -not -path '/sys/*' -not -path '/var/lib/docker/*' -not -path '/etc/ssl/*' 2>/dev/null | head -40
echo "--- bash/zsh histories with secret-ish patterns (heuristic, NEVER print matched line — only file + line count) ---"
for h in /root/.bash_history /root/.zsh_history $(getent passwd | awk -F: '$3>=1000 {print $6"/.bash_history"; print $6"/.zsh_history"}'); do
  sudo test -f $h || continue
  n=$(sudo grep -cEi '(password|token|api[_-]?key|secret|BEGIN PRIVATE|BEGIN RSA)' $h 2>/dev/null || echo 0)
  echo "$h: $n suspect lines (content NOT printed)"
done
```

### L. Cron and scheduled task review
```bash
echo "--- per-user crontabs ---"
for u in $(getent passwd | awk -F: '$3>=1000 || $1=="root" {print $1}'); do
  sudo crontab -u $u -l 2>/dev/null | grep -vE '^\s*(#|$)' | sed "s|^|[$u] |"
done
echo "--- /etc/cron.* contents ---"
sudo ls -la /etc/cron.d/ /etc/cron.hourly/ /etc/cron.daily/ /etc/cron.weekly/ /etc/cron.monthly/
echo "--- /etc/crontab ---"
sudo cat /etc/crontab
echo "--- systemd timers (active) ---"
systemctl list-timers --all --no-pager
```

### M. Running services and binaries
```bash
echo "--- services listening + binary path ---"
sudo ss -tlnp | awk 'NR>1' | sed -n 's/.*users:(("\([^"]*\)",pid=\([0-9]*\).*/\1 \2/p' | sort -u | while read proc pid; do
  bin=$(sudo readlink -f /proc/$pid/exe 2>/dev/null)
  pkg=$(dpkg -S "$bin" 2>/dev/null | awk -F: '{print $1}')
  echo "pid=$pid proc=$proc bin=$bin pkg=${pkg:-unmanaged}"
done | sort -u
echo "--- enabled but not running services (could indicate stale install) ---"
systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | head -40
echo "--- failed units ---"
systemctl --failed --no-pager
```

### N. Audit logs and security tooling presence
```bash
echo "--- auditd ---"
which auditctl && sudo systemctl is-active auditd || echo "auditd not present"
echo "--- AppArmor profiles in enforce mode ---"
sudo aa-status 2>/dev/null | head -20
echo "--- SELinux ---"
which getenforce && getenforce || echo "SELinux not present"
echo "--- /var/log/auth.log retention ---"
sudo ls -la /var/log/auth.log* 2>/dev/null
echo "--- journal disk usage ---"
sudo journalctl --disk-usage
```

### O. Cloudflare-edge-vs-host sanity (cross-reference, not state change)
```bash
echo "--- check whether services bound to 0.0.0.0 are protected by host firewall ---"
sudo ufw status numbered | grep -E '(ALLOW|DENY)'
echo "--- check that internet-facing ports match expected set (22,80,443 + RustDesk + anything in landscape) ---"
sudo ss -tlnp '( sport = :22 or sport = :80 or sport = :443 )' && echo "expected exposed ports OK"
```

## Validation criteria for step 07 (execution-validator)

The execution-validator MUST:

1. Confirm probe A returned `SUDO_OK` and a recent date.
2. Confirm every probe A–O has an output entry in the executor handoff.
3. Confirm NO probe reported a side effect.
4. For each probe, judge severity of findings against current landscape:
   - **Drift** (landscape says X, audit found Y): flag with severity = high if X was a security control (firewall rule, sshd setting); medium otherwise.
   - **New risk** (not in landscape): assign severity (P0/P1/P2/P3) per `tasks/README.md` priority guidance.
   - **Already-tracked** (matches an open task in `tasks/_index.md`): do NOT propose a new task; reference the existing T-NNNN.
5. Produce a Findings table in the validator handoff: `(probe, finding, severity, action: new-task | already-tracked T-NNNN | no-action)`.

## Landscape-update guidance for step 08

The landscape-updater MUST:

1. For each Finding marked `action: new-task` in the validator handoff, create one observation task file using `tasks/_template.md`:
   - `kind: observation`
   - `status: observation`
   - `priority: <as judged by validator>`
   - `created_by: <run_id>`
   - `source_runs: [<run_id>]`
   - `affects:` includes `landscape/hosts/<host_id>.md` and any other relevant landscape file
   - `workflow: infrastructure` (assumed remediation path)
   - History initial line: `- <today>: created as kind: observation by <run_id>`
2. Append all new task IDs to `tasks/_index.md` in the correct sorted position.
3. Update ONLY two things in `landscape/hosts/<host_id>.md`:
   - The frontmatter `last_verified:` date.
   - One Change log row: `<run_id> | audit-host run; N findings (N1 P0, N2 P1, …); see [T-NNNN, T-NNNN, ...]`.
4. Do NOT rewrite or restructure landscape body. This audit reports findings; remediation happens in follow-up state-changing runs that consume the new task files.

## Findings policy (what becomes a task vs. what doesn't)

| Severity | Examples | Action |
|---|---|---|
| P0 (critical) | exposed db with weak/no auth on public IP; unpatched kernel CVE actively exploited; world-writable system file; passwordless sudo on a service account; cleartext secret in world-readable file | Create observation task, priority P0, AND raise it to the user in the closing summary. |
| P1 (important) | pending security upgrades > 14 days; missing fail2ban or equivalent; SSH allowing weak ciphers/KEX; container running as root with privileged: true | Create observation task, priority P1. |
| P2 (nice-to-have) | container without healthcheck; image > 90 days old; nginx TLS missing HSTS header; ssh X11Forwarding yes on a server with no users | Create observation task, priority P2. |
| Informational only | SUID binary that's part of the distro; many `Failed password` entries from the open internet that fail2ban already handled | Mention in step-07 handoff. Do NOT create a task. |
| Already tracked | finding matches an open T-NNNN in `tasks/_index.md` | Note in validator's Findings table; reference T-NNNN; do NOT create a duplicate. |
