#!/bin/bash
# R7a: post-cancel sanity check
set +e

echo "=== ufw status (head) ==="
sudo -n ufw status verbose | head -4

echo ""
echo "=== sleep processes ==="
pgrep -x sleep -a 2>&1 || echo "NO_SLEEP"

echo ""
echo "=== /tmp/ufw-rollback processes ==="
pgrep -af /tmp/ufw-rollback 2>&1 || echo "NO_UFWROLLBACK"

echo ""
echo "=== R7a DONE ==="