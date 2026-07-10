#!/bin/bash
# R1: detect any stale rollback processes and confirm UFW state
set +e

echo "=== sleep processes (exact basename, avoid self-match) ==="
pgrep -x sleep -a 2>&1 || echo "NO_SLEEP"

echo "=== /tmp/ufw-rollback processes (path-anchored) ==="
pgrep -f /tmp/ufw-rollback 2>&1 || echo "NO_UFWROLLBACK"

echo "=== ufw-disable processes ==="
pgrep -f "ufw disable" 2>&1 || echo "NO_UFWDISABLE"

echo "=== /tmp/ufw-rollback files ==="
ls -la /tmp/ufw-rollback* 2>&1

echo "=== ufw status (real) ==="
sudo -n ufw status

echo "=== ufw.conf ENABLED line ==="
grep -E '^ENABLED' /etc/ufw/ufw.conf

echo "=== defensive kill (idempotent, expects 'no such process') ==="
pkill -9 -f 'sleep 300' 2>&1 || true
pkill -9 -f /tmp/ufw-rollback 2>&1 || true
pkill -9 -f 'ufw disable' 2>&1 || true

echo "=== post-kill pgrep ==="
pgrep -x sleep -a 2>&1 || echo "NO_SLEEP"
pgrep -f /tmp/ufw-rollback 2>&1 || echo "NO_UFWROLLBACK"
pgrep -f "ufw disable" 2>&1 || echo "NO_UFWDISABLE"

echo "=== R1 DONE ==="