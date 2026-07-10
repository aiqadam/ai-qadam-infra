#!/bin/bash
# R2: confirm /etc/ufw/user.rules and user6.rules still contain the 22/tcp allow rule
set +e

echo "=== /etc/ufw/user.rules (last 30 lines, sudo) ==="
sudo -n tail -30 /etc/ufw/user.rules

echo ""
echo "=== /etc/ufw/user6.rules (last 30 lines, sudo) ==="
sudo -n tail -30 /etc/ufw/user6.rules

echo ""
echo "=== grep for 22/tcp ACCEPT in both rule files ==="
echo "--- user.rules ---"
sudo -n grep -E '(dport 22|tcp dpt:22)' /etc/ufw/user.rules || echo "NO_22_TCP_RULE_IN_USER_RULES"
echo "--- user6.rules ---"
sudo -n grep -E '(dport 22|tcp dpt:22)' /etc/ufw/user6.rules || echo "NO_22_TCP_RULE_IN_USER6_RULES"

echo ""
echo "=== ufw show added (committed staged rules) ==="
sudo -n ufw show added

echo ""
echo "=== R2 DONE ==="