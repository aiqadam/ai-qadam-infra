#!/bin/bash
# R4: arm rollback safety timer using setsid + sudo bash
# The previous step-06 ran this as tvolodi; /tmp/ufw-rollback.log is owned by
# root mode 644, so the redirect failed and the setsid child exited immediately.
# This run does it as root via sudo so the redirect works AND so ufw disable
# later has the necessary privilege.
set +e

echo "=== cleaning old rollback files (sudo) ==="
sudo -n rm -f /tmp/ufw-rollback.sh /tmp/ufw-rollback.log /tmp/ufw-rollback.pid
ls -la /tmp/ufw-rollback* 2>&1 || echo "(none — clean)"

echo ""
echo "=== ARMING rollback timer via setsid (sudo) ==="
# Run the setsid command in a sudo shell so file writes and ufw disable can succeed.
# The PID we capture is the setsid child (process group leader); all descendants
# (the bash -c, the sleep 300, and the future ufw disable) share this PGID.
sudo -n bash -c '
  setsid bash -c "sleep 300 && /usr/sbin/ufw disable" </dev/null >/tmp/ufw-rollback.log 2>&1 &
  ROLLBACK_PID=$!
  disown
  echo "$ROLLBACK_PID" > /tmp/ufw-rollback.pid
  echo "Rollback PID (process group leader): $ROLLBACK_PID"
  # Give the setsid child time to fork the sleep
  sleep 1
  echo "--- child processes ---"
  ps -o pid,ppid,pgid,sid,comm -p "$ROLLBACK_PID" 2>&1 || echo "PID gone"
  ps --ppid "$ROLLBACK_PID" -o pid,ppid,pgid,sid,comm 2>&1 || echo "no children"
'

echo ""
echo "=== confirmation (as tvolodi) ==="
echo "--- pgrep sleep ---"
pgrep -x sleep -a 2>&1 || echo "NO_SLEEP"
echo "--- pgrep /tmp/ufw-rollback (script and log paths) ---"
pgrep -af /tmp/ufw-rollback 2>&1 || echo "NO_UFWROLLBACK"
echo "--- /tmp/ufw-rollback.pid ---"
sudo -n cat /tmp/ufw-rollback.pid
echo "--- /tmp/ufw-rollback files ---"
sudo -n ls -la /tmp/ufw-rollback* 2>&1
echo "--- /tmp/ufw-rollback.log ---"
sudo -n cat /tmp/ufw-rollback.log 2>&1 || true
echo "(end of log)"
echo "--- /tmp/ufw-rollback.sh ---"
sudo -n cat /tmp/ufw-rollback.sh 2>&1 || true

echo ""
echo "=== R4 DONE ==="