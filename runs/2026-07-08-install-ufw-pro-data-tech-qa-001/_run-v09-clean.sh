#!/bin/bash
# V09 re-verify — no rollback processes, no self-match false positives.
# Authoritative scan: /proc/<pid>/cmdline (raw, null-separated)
# A "sleep 300" or "ufw disable" only counts if its comm is exactly sleep/ufw
# AND the command line literally contains the rollback shape (sleep 300, ufw disable).

set -u

echo "=== ps -eo pid,comm,args (filtered for ufw/sleep) ==="
ps -eo pid,ppid,pgid,sid,comm,args | awk 'NR==1 || $5=="sleep" || $5=="ufw" || $6 ~ /sleep/ || $6 ~ /ufw/ || $7 ~ /sleep/ || $7 ~ /ufw/ {print}'

echo
echo "=== /proc scan for any process whose cmdline literally contains 'sleep 300' (full 5-min rollback) ==="
found_sleep=0
for p in /proc/[0-9]*; do
  c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
  case "$c" in
    *sleep*300*)
      echo "PID ${p##*/}: $c"
      found_sleep=1
      ;;
  esac
done
[ $found_sleep -eq 0 ] && echo "NO_PROCESS_WITH_sleep_300"

echo
echo "=== /proc scan for any process whose cmdline literally contains 'ufw disable' ==="
found_ufwdis=0
for p in /proc/[0-9]*; do
  c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
  case "$c" in
    *ufw*disable*)
      echo "PID ${p##*/}: $c"
      found_ufwdis=1
      ;;
  esac
done
[ $found_ufwdis -eq 0 ] && echo "NO_PROCESS_WITH_ufw_disable"

echo
echo "=== /tmp/ rollback artifacts ==="
ls -la /tmp/ 2>/dev/null | grep -E 'ufw|rollback' || echo "NO_TMP_ROLLBACK_FILES"

echo
echo "=== /etc/ufw/ufw.conf ENABLED status ==="
grep -E '^ENABLED' /etc/ufw/ufw.conf

echo
echo "=== ufw status verbose ==="
sudo ufw status verbose

echo
echo "=== systemd unit state ==="
systemctl is-enabled ufw
systemctl is-active ufw
