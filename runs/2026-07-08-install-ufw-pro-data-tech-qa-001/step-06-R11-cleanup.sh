#!/bin/bash
# R11: cleanup rollback PID file and log (keep backups)
set +e

echo "=== BEFORE cleanup ==="
ls -la /tmp/ufw-rollback* 2>&1
ls -la /etc/default/ufw.bak 2>&1
ls -la /tmp/ufw.pre-T0094.*.bak/ 2>&1 | head -5

echo ""
echo "=== removing /tmp/ufw-rollback.pid and /tmp/ufw-rollback.log ==="
sudo -n rm -f /tmp/ufw-rollback.pid /tmp/ufw-rollback.log
echo "rm exit: $?"

echo ""
echo "=== AFTER cleanup ==="
ls -la /tmp/ufw-rollback* 2>&1 || echo "(all rollback artifacts removed)"

echo ""
echo "=== confirm backups still intact ==="
ls -la /etc/default/ufw.bak 2>&1
ls -la /tmp/ufw.pre-T0094.*.bak/ 2>&1 | head -5

echo ""
echo "=== final ufw status ==="
sudo -n ufw status verbose | head -8

echo ""
echo "=== R11 DONE ==="