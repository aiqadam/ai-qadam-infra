#!/bin/bash
echo "=== V16 Rollback dry-run ==="
echo ""
echo "--- Step 1: list files owned by each operator user (anywhere on host) ---"
for u in tvolodi viktor_d binali_r; do
  echo "Files owned by $u (excluding /home/$u, /proc, /sys):"
  find / -user "$u" -not -path "/home/$u/*" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -10
  echo "  (count: $(find / -user $u -not -path "/home/$u/*" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | wc -l))"
done

echo ""
echo "--- Step 2: simulate userdel -r (without actually deleting) ---"
for u in tvolodi viktor_d binali_r; do
  echo "Dry-run: userdel -r $u"
  userdel -r --dry-run "$u" 2>&1 || echo "  (--dry-run unsupported; check would succeed if user has nothing locked)"
done

echo ""
echo "--- Step 3: check for any cron jobs / systemd user services for the operators ---"
for u in tvolodi viktor_d binali_r; do
  echo "  crontab for $u: $(crontab -u $u -l 2>&1 | head -1)"
  echo "  systemd user instances for $u: $(ls /run/user/$(id -u $u) 2>/dev/null | wc -l) items"
done

echo ""
echo "--- Step 4: check /var/backups/pre-T-0097-* snapshot exists ---"
ls -ld /var/backups/pre-T-0097-*/ 2>&1

echo ""
echo "--- Step 5: confirm no critical process is running as these users ---"
for u in tvolodi viktor_d binali_r; do
  procs=$(ps -u "$u" --no-headers 2>/dev/null | wc -l)
  echo "  processes running as $u: $procs"
done
