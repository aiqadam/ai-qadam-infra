#!/bin/bash
# Independent verification V13 (detailed) + V08 extra + V03/V04 stat
set -u

echo "=== authorized_keys full content ==="
cat /root/.ssh/authorized_keys

echo ""
echo "=== provider-key comment grep ==="
grep -F "rsa-key-20260707" /root/.ssh/authorized_keys

echo ""
echo "=== ssh-rsa prefix count ==="
grep -c "^ssh-rsa" /root/.ssh/authorized_keys

echo ""
echo "=== file count ==="
wc -l /root/.ssh/authorized_keys

echo ""
echo "=== V03+V04: stat on all 3 drop-ins (format: name mode owner:group size) ==="
stat -c '%n %a %U:%G %s' /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

echo ""
echo "=== V08 extra: pubkeyauthentication (sanity) ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^pubkeyauthentication'

echo ""
echo "=== V08 extra: cbc/3des/rc4 in ciphers (expecting NO output = clean) ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^ciphers' | grep -Ei 'cbc|3des|rc4|arcfour'
echo "(end V08 extra — empty above = no cbc/3des/rc4/arcfour in cipher list)"

echo ""
echo "=== V09 extra: hmac-sha1 in macs (expecting NO output = clean) ==="
sudo -n sshd -T 2>/dev/null | grep -Ei '^macs' | grep -Ei 'hmac-sha1'
echo "(end V09 extra — empty above = no hmac-sha1 in mac list)"
