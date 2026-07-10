---
name: workflow-discovery-host
version: 1
description: Read-only enumeration of a managed host. Populates landscape/hosts/<name>.md and landscape/services.md with OS, hardware, users, services, network, firewall, and (lightly) installed application context.
extends: workflows/_common-operations.md
state_changing: false
skip_design_step: true
---

# Discovery: host

Read-only enumeration of a managed host. Produces a current-state snapshot in `runs/<run_id>/` and proposes landscape updates that the landscape-updater applies at step 08.

## Step bindings

| Step | Agent | Status |
|---|---|---|
| 01 | `task-reader` | required |
| 02 | `landscape-reader` | required |
| 03 | `task-validator` | required |
| 04 | `solution-designer` | **skipped** (`skip_design_step: true`) — probe list lives in this file |
| 05 | user-approval | **skipped** (`state_changing: false`) |
| 06 | **`executor-discovery`** | required |
| 07 | `execution-validator` | required (compares findings to landscape; flags drift) |
| 08 | `landscape-updater` | required (writes findings to landscape/) |

## Landscape files in scope

Read:
- `landscape/hosts/<host_id>.md` — the target host
- `landscape/services.md`
- `landscape/secrets-inventory.md` (for token/key references, not values)

Write (at step 08, based on findings):
- `landscape/hosts/<host_id>.md`
- `landscape/services.md`

## Probe checklist for executor-discovery

The executor runs each probe in order. Each is a single `ssh hetzner-prod '<command>'` invocation unless noted. The executor captures exit code and output for every probe.

### A. Identity & access (sanity)
```bash
whoami && id && hostname && sudo -n true && echo SUDO_OK
```

### B. OS & kernel
```bash
cat /etc/os-release && uname -a && lsb_release -a 2>/dev/null
```

### C. Hardware (cloud-VM view)
```bash
nproc && free -h && df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs
```

### D. Users & groups
```bash
getent passwd | awk -F: '$3>=1000 || $1=="root"'
echo "--- sudoers.d ---"
sudo ls -la /etc/sudoers.d/
echo "--- sudoers.d contents ---"
sudo grep -r '' /etc/sudoers.d/ 2>/dev/null
echo "--- currently logged in ---"
who && last -n 20 --time-format iso
echo "--- authorized_keys ---"
for u in $(getent passwd | awk -F: '$3>=1000 {print $1}'); do
  echo "=== $u ==="
  sudo test -f /home/$u/.ssh/authorized_keys && sudo wc -l /home/$u/.ssh/authorized_keys && sudo awk '{print $1, $3}' /home/$u/.ssh/authorized_keys
done
sudo test -f /root/.ssh/authorized_keys && echo "--- root authorized_keys ---" && sudo wc -l /root/.ssh/authorized_keys && sudo awk '{print $1, $3}' /root/.ssh/authorized_keys
```

### E. SSH daemon config
```bash
sudo sshd -T 2>/dev/null | grep -Ei '^(port |permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|usedns|x11forwarding|allowusers|allowgroups|maxauthtries|clientaliveinterval|loginGraceTime)' | sort
```

### F. Firewall
```bash
echo "--- ufw ---"
sudo ufw status verbose 2>/dev/null || echo "ufw not installed"
echo "--- nftables ---"
sudo nft list ruleset 2>/dev/null | head -100 || echo "nft not installed"
echo "--- iptables ---"
sudo iptables -L -n -v 2>/dev/null | head -80 || true
sudo ip6tables -L -n -v 2>/dev/null | head -40 || true
```

### G. Network listeners
```bash
sudo ss -tlnp
echo "---"
sudo ss -ulnp
```

### H. Docker
```bash
which docker && docker --version
docker info --format 'Server: {{.ServerVersion}} | Containers: {{.Containers}} (running {{.ContainersRunning}}) | Images: {{.Images}}' 2>/dev/null
echo "--- containers ---"
sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
echo "--- compose projects discoverable ---"
sudo docker compose ls 2>/dev/null || echo "no docker compose ls"
echo "--- compose files on disk ---"
sudo find / -name 'docker-compose*.y*ml' -not -path '/proc/*' -not -path '/sys/*' -not -path '/var/lib/docker/*' 2>/dev/null | head -20
```

### I. nginx
```bash
which nginx && nginx -v 2>&1
sudo nginx -T 2>&1 | head -200
echo "--- vhost summary ---"
sudo nginx -T 2>/dev/null | awk '/server_name/ {print}' | sort -u
```

### J. systemd units of interest
```bash
systemctl list-units --type=service --state=running --no-pager --no-legend | head -40
echo "--- enabled non-default ---"
systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | head -40
```

### K. Scheduled tasks
```bash
echo "--- per-user crontabs ---"
for u in $(getent passwd | awk -F: '$3>=1000 || $1=="root" {print $1}'); do sudo crontab -u $u -l 2>/dev/null | grep -v '^#' | grep -v '^$' | sed "s/^/[$u] /" ; done
echo "--- system crontabs ---"
sudo ls -la /etc/cron.* 2>/dev/null
echo "--- systemd timers ---"
systemctl list-timers --all --no-pager --no-legend
```

### L. Package & update posture
```bash
echo "--- apt sources ---"
sudo ls /etc/apt/sources.list.d/
echo "--- pending upgrades count ---"
sudo apt list --upgradable 2>/dev/null | grep -c upgradable || true
echo "--- unattended-upgrades ---"
cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null
cat /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null | head -40
echo "--- last apt activity ---"
sudo stat /var/log/apt/history.log 2>/dev/null | grep Modify
```

### M. Security tools
```bash
echo "--- fail2ban ---"
which fail2ban-client && sudo fail2ban-client status 2>/dev/null || echo "fail2ban not present"
echo "--- auditd ---"
which auditctl && sudo systemctl is-active auditd || echo "auditd not present"
echo "--- AppArmor ---"
which aa-status && sudo aa-status 2>/dev/null | head -5
```

### N. Backup posture
```bash
echo "--- Hetzner cloud-agent / snapshot hooks ---"
systemctl list-units --no-pager | grep -Ei 'backup|snapshot' || true
echo "--- Restic / borg / duplicity ---"
which restic borg duplicity 2>/dev/null
echo "--- common backup paths ---"
sudo find / -maxdepth 3 -type d -iname '*backup*' 2>/dev/null | head -20
```

## Validation criteria for step 07 (execution-validator)

- Pre-execution self-check (probe A) reported `SUDO_OK`.
- Every probe section A–N has an output entry in the executor handoff (even if "not installed").
- No probe reported a side effect.
- The findings summary references each probe by letter.

## Landscape-update guidance for step 08

The landscape-updater should write:
- `landscape/hosts/hetzner-prod.md` — fill the hardware/OS/kernel section, the access section, the network section (open ports/firewall), and the backups section with concrete findings.
- `landscape/services.md` — populate the Docker, nginx, and systemd tables for `hetzner-prod` from the findings.
- Append one row to `landscape/hosts/hetzner-prod.md`'s Change log with `(run_id, "Initial discovery run")`.
- For ANY finding the workflow exposes that is not explicitly covered by an existing landscape file, the updater records it under "Open questions" in the run's step-08 handoff rather than inventing a new landscape file. New landscape files are a deliberate design decision, not a side-effect of discovery.
