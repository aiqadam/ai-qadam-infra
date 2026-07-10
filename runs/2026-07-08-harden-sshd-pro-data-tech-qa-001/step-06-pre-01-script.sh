#!/bin/bash
echo "=== STEP 1: idempotency check ==="
echo "--- drop-ins ---"
ls -la /etc/ssh/sshd_config.d/ 2>&1
echo "--- sshusers group ---"
getent group sshusers 2>&1 || echo "sshusers group: not present"
echo "--- root supplementary groups ---"
id root 2>&1
echo "--- Include directive in main sshd_config ---"
grep -E '^Include\s+/etc/ssh/sshd_config\.d' /etc/ssh/sshd_config 2>&1 || echo "Include directive: NOT FOUND"
echo "--- current passwordauthentication effective ---"
sudo -n sshd -T 2>&1 | grep -i ^passwordauthentication
echo "--- current permitrootlogin effective ---"
sudo -n sshd -T 2>&1 | grep -i ^permitrootlogin
