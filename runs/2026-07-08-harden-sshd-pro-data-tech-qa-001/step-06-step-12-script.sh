BACKUP_DIR=/tmp/sshd_config.d.pre-T0093.20260708T165653Z.bak
echo BACKUP_PATH=$BACKUP_DIR
ls -la $BACKUP_DIR
echo BACKUP_CONTENT
cat $BACKUP_DIR/60-cloudimg-settings.conf
echo BACKUP_SIZE
wc -c $BACKUP_DIR/60-cloudimg-settings.conf
echo KEYS
wc -l /root/.ssh/authorized_keys
grep -c '^ssh-rsa' /root/.ssh/authorized_keys
grep '^rsa-key-20260707' /root/.ssh/authorized_keys | head -1
echo HOST_DROPIN_LIST
ls -la /etc/ssh/sshd_config.d/
echo HOST_DROPIN_40_DISABLE
cat /etc/ssh/sshd_config.d/40-disable-password.conf
echo HOST_DROPIN_40_INFRA
cat /etc/ssh/sshd_config.d/40-ai-dala-infra.conf
echo ROOT_GROUPS
id root
echo SSHUSERS
getent group sshusers
echo DROPIN_STAT
stat -c '%n %a %U:%G %s' /etc/ssh/sshd_config.d/40-disable-password.conf /etc/ssh/sshd_config.d/40-ai-dala-infra.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
