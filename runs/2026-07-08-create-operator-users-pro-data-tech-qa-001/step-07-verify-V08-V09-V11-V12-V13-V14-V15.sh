#!/bin/bash
echo "=== V08 sudoers.d/90-* stat + content (expect 440 root:root + '<user> ALL=(ALL) NOPASSWD: ALL') ==="
for f in /etc/sudoers.d/90-tvolodi /etc/sudoers.d/90-viktor-d /etc/sudoers.d/90-binali-r; do
  stat -c '%a %U:%G %n' "$f"
  echo "  content: $(cat $f)"
done

echo "=== V09 visudo -c ==="
visudo -c
echo "exit code: $?"

echo "=== V11 ssh-keygen viktor_d fingerprint ==="
ssh-keygen -lf /home/viktor_d/.ssh/authorized_keys -E sha256

echo "=== V12 ssh-keygen binali_r fingerprint ==="
ssh-keygen -lf /home/binali_r/.ssh/authorized_keys -E sha256

echo "=== V13 provider key in /root/.ssh/authorized_keys ==="
wc -l /root/.ssh/authorized_keys
head -1 /root/.ssh/authorized_keys

echo "=== V14 passwd -S all three (expect L) ==="
passwd -S tvolodi
passwd -S viktor_d
passwd -S binali_r

echo "=== V15 getent passwd all three (expect /bin/bash shell) ==="
getent passwd tvolodi
getent passwd viktor_d
getent passwd binali_r
