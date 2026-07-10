#!/bin/bash
set -e
echo "--- useradd tvolodi ---"
useradd -m -u 1001 -s /bin/bash -c 'Operator tvolodi - workstation user ed25519' tvolodi
echo "--- useradd viktor_d ---"
useradd -m -u 1002 -s /bin/bash -c 'Operator viktor_d - ed25519' viktor_d
echo "--- useradd binali_r ---"
useradd -m -u 1003 -s /bin/bash -c 'Operator binali_r - ed25519' binali_r
echo "--- passwd -l ---"
passwd -l tvolodi
passwd -l viktor_d
passwd -l binali_r
echo "--- usermod -aG sshusers ---"
usermod -aG sshusers tvolodi
usermod -aG sshusers viktor_d
usermod -aG sshusers binali_r
echo "--- usermod -aG sudo,users ---"
usermod -aG sudo,users tvolodi
usermod -aG sudo,users viktor_d
usermod -aG sudo,users binali_r
echo "--- verify ---"
id tvolodi
id viktor_d
id binali_r
getent group sshusers
getent group sudo
getent group users