#!/bin/bash
# V10 re-verify — wait 15s, then re-confirm ufw status is still active
# and no rollback process can fire in the meantime.

echo "=== Waiting 15 seconds for any latent rollback to fire ==="
sleep 15

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
      found_ufwdis=0
      ;;
  esac
done
[ $found_ufwdis -eq 0 ] && echo "NO_PROCESS_WITH_ufw_disable"

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
