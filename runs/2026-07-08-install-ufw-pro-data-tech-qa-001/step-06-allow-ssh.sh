#!/bin/bash
# Step 7 — allow 22/tcp
sudo ufw allow 22/tcp comment "sshd - operator access T-0094 baseline"
sudo ufw show added