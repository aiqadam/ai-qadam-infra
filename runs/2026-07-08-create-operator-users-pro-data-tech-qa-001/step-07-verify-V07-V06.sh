#!/bin/bash
echo "=== V07 .ssh dir modes (expect 700 owner:user) ==="
for p in /home/tvolodi/.ssh /home/viktor_d/.ssh /home/binali_r/.ssh; do
  stat -c '%a %U:%G %n' "$p"
done

echo "=== V04-V06 authorized_keys stat (expect 600 owner:user) ==="
for p in /home/tvolodi/.ssh/authorized_keys /home/viktor_d/.ssh/authorized_keys /home/binali_r/.ssh/authorized_keys; do
  stat -c '%a %U:%G %n' "$p"
done

echo "=== V04-V06 authorized_keys content (raw) ==="
for u in tvolodi viktor_d binali_r; do
  echo "--- /home/$u/.ssh/authorized_keys ---"
  cat /home/$u/.ssh/authorized_keys
  echo
done
