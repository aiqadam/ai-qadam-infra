#!/bin/bash
# R6: verify UFW active, systemd unit enabled
set +e

echo "=== ufw status verbose ==="
sudo -n ufw status verbose

echo ""
echo "=== ufw status numbered ==="
sudo -n ufw status numbered

echo ""
echo "=== systemctl is-enabled ufw ==="
sudo -n systemctl is-enabled ufw

echo ""
echo "=== systemctl is-active ufw ==="
sudo -n systemctl is-active ufw

echo ""
echo "=== iptables INPUT policy + ufw-before-input chain (head) ==="
sudo -n iptables -L INPUT -n -v 2>&1 | head -10
echo "--- ufw-before-input ---"
sudo -n iptables -L ufw-before-input -n -v 2>&1 | head -10 || echo "(not loaded yet)"

echo ""
echo "=== ip6tables (head) ==="
sudo -n ip6tables -L -n -v 2>&1 | head -10

echo ""
echo "=== R6 DONE ==="