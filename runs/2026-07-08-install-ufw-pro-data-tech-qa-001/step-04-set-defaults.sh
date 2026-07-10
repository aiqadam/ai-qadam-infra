#!/bin/bash
# Step 5 — set UFW defaults
echo "--- BEFORE ---"
sudo grep -E "^(DEFAULT_|IPV6)=" /etc/default/ufw
sudo sed -i '/DEFAULT_INPUT_POLICY/s/=.*/="DROP"/' /etc/default/ufw
sudo sed -i '/DEFAULT_OUTPUT_POLICY/s/=.*/="ACCEPT"/' /etc/default/ufw
sudo sed -i '/DEFAULT_FORWARD_POLICY/s/=.*/="DROP"/' /etc/default/ufw
sudo sed -i '/^IPV6=/s/=.*/=yes/' /etc/default/ufw
echo "--- AFTER ---"
grep -E "^(DEFAULT_|IPV6)=" /etc/default/ufw
echo "--- DIFF ---"
sudo diff /etc/default/ufw /etc/default/ufw.bak