cat > /etc/fail2ban/jail.d/sshd.local <<'JAILEOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 600
banaction = iptables-multiport
ignoreip = 127.0.0.1/8 ::1 178.89.57.135
JAILEOF
chmod 644 /etc/fail2ban/jail.d/sshd.local
cat /etc/fail2ban/jail.d/sshd.local