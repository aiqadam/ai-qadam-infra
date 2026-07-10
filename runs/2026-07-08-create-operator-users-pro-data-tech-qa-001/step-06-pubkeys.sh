#!/bin/bash
set -e

# Step 5: Create ~/.ssh directories with user:user ownership (per user prompt)
for u in tvolodi viktor_d binali_r; do
  install -d -m 0700 -o "$u" -g "$u" /home/"$u"/.ssh
  chmod 0700 /home/"$u"/.ssh
done

echo "--- ls -la /home/<user>/.ssh ---"
ls -ld /home/tvolodi/.ssh /home/viktor_d/.ssh /home/binali_r/.ssh

echo "--- sshusers group ready, proceeding to authorized_keys ---"