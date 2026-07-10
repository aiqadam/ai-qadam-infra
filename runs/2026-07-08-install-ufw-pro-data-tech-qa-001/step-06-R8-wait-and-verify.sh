#!/bin/bash
# R8: wait 10s then re-verify nothing rolls back UFW
set +e

echo "=== sleeping 10 seconds to confirm timer is truly dead ==="
sleep 10
echo "=== awake ==="

echo ""
echo "=== sleep processes (must be empty) ==="
pgrep -x sleep -a 2>&1 || echo "NO_SLEEP"

echo ""
echo "=== /tmp/ufw-rollback processes (must be empty) ==="
pgrep -af /tmp/ufw-rollback 2>&1 || echo "NO_UFWROLLBACK"

echo ""
echo "=== ufw disable processes (must be empty) ==="
pgrep -af "ufw disable" 2>&1 || echo "NO_UFWDISABLE"

echo ""
echo "=== ufw status (MUST show Status: active) ==="
sudo -n ufw status verbose

echo ""
echo "=== /etc/ufw/ufw.conf ENABLED line (MUST be ENABLED=yes) ==="
grep -E '^ENABLED' /etc/ufw/ufw.conf

echo ""
echo "=== /tmp/ufw-rollback.log (should still be empty - no ufw disable fired) ==="
sudo -n ls -la /tmp/ufw-rollback.log 2>&1
sudo -n cat /tmp/ufw-rollback.log 2>&1
echo "(end of log)"

echo ""
echo "=== R8 DONE ==="