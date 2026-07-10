#!/bin/bash
# R5: re-enable UFW (the previous rollback timer fired and disabled it).
# Use the proven T-0002/T-0083/previous-step-06 pattern: bash here-string 'y'
# to auto-answer the 'Command may disrupt existing ssh connections' prompt.
set +e

echo "=== ufw status BEFORE enable ==="
sudo -n ufw status

echo ""
echo "=== enable UFW (with here-string y) ==="
sudo -n ufw enable <<< "y"

echo ""
echo "=== ufw status AFTER enable ==="
sudo -n ufw status

echo ""
echo "=== ufw status verbose AFTER enable ==="
sudo -n ufw status verbose

echo ""
echo "=== /etc/ufw/ufw.conf ENABLED line ==="
grep -E '^ENABLED' /etc/ufw/ufw.conf

echo ""
echo "=== R5 DONE ==="