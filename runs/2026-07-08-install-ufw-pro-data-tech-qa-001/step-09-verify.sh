#!/bin/bash
# Step 10 — on-host verification + cancel rollback timer
echo "=== ufw status verbose ==="
sudo ufw status verbose
echo
echo "=== ufw status numbered ==="
sudo ufw status numbered
echo
echo "=== systemd ufw ==="
sudo systemctl is-enabled ufw
sudo systemctl is-active ufw
echo
echo "=== rollback timer status ==="
pgrep -af ufw-rollback.sh || echo "ROLLBACK_TIMER_NOT_FOUND"
echo
echo "=== cancel rollback timer ==="
ROLLBACK_PID=$(pgrep -f ufw-rollback.sh)
if [ -n "$ROLLBACK_PID" ]; then
  sudo kill "$ROLLBACK_PID" && echo "KILLED_ROLLBACK_PID=$ROLLBACK_PID"
else
  echo "NO_ROLLBACK_TIMER_TO_KILL"
fi
sleep 1
pgrep -af ufw-rollback.sh || echo "ROLLBACK_TIMER_CANCELLED"
echo
echo "=== iptables v4 ==="
sudo iptables -L -n -v | head -40
echo
echo "=== ip6tables v6 ==="
sudo ip6tables -L -n -v | head -40