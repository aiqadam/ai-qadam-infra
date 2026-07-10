#!/bin/bash
# R7: cancel rollback timer using kill -- -$PID (process group kill)
# This is the FIX vs the previous step-06 which only killed the bash wrapper
# and left the sleep 300 child running. Here we kill the ENTIRE process group
# established by setsid in R4.
set +e

# Read the rollback PID captured in R4
ROLLBACK_PID=$(cat /tmp/ufw-rollback.pid)
echo "ROLLBACK_PID (group leader) = $ROLLBACK_PID"

echo ""
echo "=== BEFORE cancel: process tree of the rollback group ==="
ps -o pid,ppid,pgid,sid,comm -p "$ROLLBACK_PID" 2>&1
echo "--- children of group leader ---"
ps --ppid "$ROLLBACK_PID" -o pid,ppid,pgid,sid,comm 2>&1 || echo "(none)"
echo "--- pgrep sleep (should show sleep 300) ---"
pgrep -x sleep -a 2>&1

echo ""
echo "=== CANCEL via kill -9 -- -PGID (negative PID = process group) ==="
# sudo: needs root to kill processes owned by root
sudo -n kill -9 -- "-$ROLLBACK_PID" 2>&1 || echo "kill -- -$ROLLBACK_PID failed; trying by name"

echo ""
echo "=== belt-and-suspenders: also pkill by pattern ==="
sudo -n pkill -9 -x sleep 2>&1 || echo "no sleep to kill"
sudo -n pkill -9 -f /tmp/ufw-rollback 2>&1 || echo "no /tmp/ufw-rollback proc"
sudo -n pkill -9 -f "ufw disable" 2>&1 || echo "no ufw-disable proc"

echo ""
echo "=== AFTER cancel: process tree (should be empty) ==="
ps -o pid,ppid,pgid,sid,comm -p "$ROLLBACK_PID" 2>&1 || echo "PID $ROLLBACK_PID gone"
echo "--- pgrep sleep (must be empty) ---"
pgrep -x sleep -a 2>&1 || echo "NO_SLEEP"
echo "--- pgrep /tmp/ufw-rollback (must be empty) ---"
pgrep -af /tmp/ufw-rollback 2>&1 || echo "NO_UFWROLLBACK"
echo "--- pgrep ufw disable (must be empty) ---"
pgrep -af "ufw disable" 2>&1 || echo "NO_UFWDISABLE"

echo ""
echo "=== R7 DONE ==="