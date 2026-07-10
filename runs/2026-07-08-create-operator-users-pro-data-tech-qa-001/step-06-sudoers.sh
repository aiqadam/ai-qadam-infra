#!/bin/bash
set -e

echo "--- write drop-ins to /tmp ---"
cat > /tmp/90-tvolodi <<'EOF'
tvolodi ALL=(ALL) NOPASSWD: ALL
EOF
cat > /tmp/90-viktor-d <<'EOF'
viktor_d ALL=(ALL) NOPASSWD: ALL
EOF
cat > /tmp/90-binali-r <<'EOF'
binali_r ALL=(ALL) NOPASSWD: ALL
EOF

echo "--- visudo -c -f each ---"
visudo -c -f /tmp/90-tvolodi
visudo -c -f /tmp/90-viktor-d
visudo -c -f /tmp/90-binali-r

echo "--- install to /etc/sudoers.d/ ---"
install -m 0440 -o root -g root /tmp/90-tvolodi /etc/sudoers.d/90-tvolodi
install -m 0440 -o root -g root /tmp/90-viktor-d /etc/sudoers.d/90-viktor-d
install -m 0440 -o root -g root /tmp/90-binali-r /etc/sudoers.d/90-binali-r
rm -f /tmp/90-tvolodi /tmp/90-viktor-d /tmp/90-binali-r

echo "--- final visudo -c ---"
visudo -c

echo "--- ls -l /etc/sudoers.d/ ---"
ls -l /etc/sudoers.d/

echo "--- cat each drop-in ---"
cat /etc/sudoers.d/90-tvolodi
cat /etc/sudoers.d/90-viktor-d
cat /etc/sudoers.d/90-binali-r