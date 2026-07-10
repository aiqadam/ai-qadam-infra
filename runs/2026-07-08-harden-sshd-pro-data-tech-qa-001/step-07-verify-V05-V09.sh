#!/bin/bash
# Independent verification V05-V09: sshd -T directives
# Written by execution-validator at step 07 to avoid PowerShell quoting hazards
# when passing complex grep regex through SSH.
set -u

echo "=== V05: passwordauthentication + kbdinteractiveauthentication ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^(passwordauthentication|kbdinteractiveauthentication) ' | sort

echo ""
echo "=== V06: full hardening directive set ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|maxauthtries|logingracetime|x11forwarding|clientaliveinterval|clientalivecountmax|allowgroups) ' | sort

echo ""
echo "=== V07: kexalgorithms (SHA-1 must be absent) ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^kexalgorithms '

echo ""
echo "=== V07b: check for SHA-1 kex (expecting NO matches) ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^(kexalgorithms|.*sha1.*)' | sort
echo "(end V07b - if 'sha1' appears above, that's a SHA-1 KEX leak)"

echo ""
echo "=== V08: ciphers (cbc/3des/rc4 must be absent) ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^ciphers '

echo ""
echo "=== V09: macs (hmac-sha1 must be absent) ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^macs '

echo ""
echo "=== V09b: any line containing 'sha1' in sshd -T (should be NONE in ciphers/macs/kex) ==="
sudo -n sshd -T 2>/dev/null | grep -i 'sha1'
echo "(end V09b - if anything above is non-empty, SHA-1 leak)"
