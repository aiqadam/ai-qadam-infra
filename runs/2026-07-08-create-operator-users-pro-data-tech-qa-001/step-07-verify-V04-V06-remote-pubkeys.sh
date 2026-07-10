#!/bin/bash
echo "=== Raw /home/tvolodi/.ssh/authorized_keys ==="
od -c /home/tvolodi/.ssh/authorized_keys | head -5
echo "---decoded---"
cat /home/tvolodi/.ssh/authorized_keys
echo "===END==="

echo "=== Raw /home/viktor_d/.ssh/authorized_keys ==="
od -c /home/viktor_d/.ssh/authorized_keys | head -5
echo "---decoded---"
cat /home/viktor_d/.ssh/authorized_keys
echo "===END==="

echo "=== Raw /home/binali_r/.ssh/authorized_keys ==="
od -c /home/binali_r/.ssh/authorized_keys | head -5
echo "---decoded---"
cat /home/binali_r/.ssh/authorized_keys
echo "===END==="

echo "=== sha256 of all three ==="
sha256sum /home/tvolodi/.ssh/authorized_keys /home/viktor_d/.ssh/authorized_keys /home/binali_r/.ssh/authorized_keys
