

## Exclude list

sudo nano /root/borg-exclude.txt


### 
sudo nano /root/.borg-passphrase
export BORG_PASSPHRASE='your-strong-passphrase-here'
sudo chmod 600 /root/.borg-passphrase
source /root/.borg-passphrase


## Installation

/usr/local/bin/borg-backup.sh
/etc/systemd/system/borg-backup.service
/etc/systemd/system/borg-backup.timer


## Enable service and timer

sudo systemctl daemon-reload
sudo systemctl enable borg-backup.timer
sudo systemctl start borg-backup.timer

## Check timer status
sudo systemctl status borg-backup.timer
sudo systemctl list-timers | grep borg

sudo systemctl start borg-backup.service

## How to deal with borg

mkdir /tmp/borg-mount
borg mount /mnt/backup_borg/borg-repo /tmp/borg-mount
cd /tmp/borg-mount

Browse your backups
When done:

borg umount /tmp/borg-mount

## Save installed package list

sudo nano /usr/local/bin/save-package-list.sh
#!/bin/bash
dpkg --get-selections > /root/installed-packages.txt
apt-mark showauto > /root/auto-installed-packages.txt
sudo chmod +x /usr/local/bin/save-package-list.sh

## Monitor disk space

df -h /mnt/backup_borg
borg info /mnt/backup_borg/borg-repo | grep "Original size"



## Multiple exclude files

# Create category-based exclude files
sudo nano /root/borg-exclude-system.txt
sudo nano /root/borg-exclude-docker.txt
sudo nano /root/borg-exclude-dev.txt

# Use them all
borg create \
    --exclude-from /root/borg-exclude-system.txt \
    --exclude-from /root/borg-exclude-docker.txt \
    --exclude-from /root/borg-exclude-dev.txt \
    "::$BACKUP_NAME" \
    /



# Edit configuration
sudo nano /usr/local/etc/borg/borg-backup.conf

# Edit passphrase
sudo nano /usr/local/etc/borg/borg-passphrase
sudo chmod 600 /usr/local/etc/borg/borg-passphrase

# Test backup
sudo /usr/local/bin/borg-backup.sh --dry-run --verbose
