#!/bin/bash
# R3: confirm /etc/default/ufw has the plan target values
set +e

echo "=== grep for DEFAULT_*/IPV6 in /etc/default/ufw ==="
grep -E '^(DEFAULT_INPUT_POLICY|DEFAULT_OUTPUT_POLICY|DEFAULT_FORWARD_POLICY|IPV6)' /etc/default/ufw

echo ""
echo "=== full /etc/default/ufw (for forensic diff) ==="
sudo -n cat /etc/default/ufw

echo ""
echo "=== diff /etc/default/ufw vs /etc/default/ufw.bak ==="
sudo -n diff /etc/default/ufw /etc/default/ufw.bak

echo ""
echo "=== R3 DONE ==="