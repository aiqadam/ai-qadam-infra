#!/bin/bash
# R12 (extra): final 15-second wait + verify, defensive against any latent rollback
set +e

echo "=== sleeping 15 seconds ==="
sleep 15
echo "=== awake ==="

echo ""
echo "=== sleep processes (must be empty) ==="
pgrep -x sleep -a 2>&1 || echo "NO_SLEEP"

echo ""
echo "=== /tmp/ufw-rollback processes (must be empty) ==="
pgrep -af /tmp/ufw-rollback 2>&1 || echo "NO_UFWROLLBACK"

echo ""
echo "=== ufw status ==="
sudo -n ufw status verbose

echo ""
echo "=== R12 DONE ==="