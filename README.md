# Borg Backup

## Exclude list

sudo nano /root/borg-exclude.txt

###

```bash
sudo nano /root/.borg-passphrase
export BORG_PASSPHRASE='your-strong-passphrase-here'
sudo chmod 600 /root/.borg-passphrase
source /root/.borg-passphrase
```

## Installation

Run ```install.sh```.

The following files are copied or created:

```bash
/usr/local/bin/borg-backup.sh
/etc/systemd/system/borg-backup.service
/etc/systemd/system/borg-backup.timer
```

## Enable service and timer

sudo systemctl daemon-reload
sudo systemctl enable borg-backup.timer
sudo systemctl start borg-backup.timer

## Check timer status

```bash
sudo systemctl status borg-backup.timer
sudo systemctl list-timers | grep borg
sudo systemctl start borg-backup.timer
```

## How to deal with borg

### Browse files and restore

```bash
sudo mkdir /tmp/borg-mount
export BORG_PASSPHRASE='your-passphrase'
sudo -E borg mount /mnt/artemis_backup/borg-repo /tmp/borg-mount
cd /tmp/borg-mount
# Browse your backups like normal directories
# When done:
sudo borg umount /tmp/borg-mount
```

### List all backups

export BORG_PASSPHRASE='your-passphrase'
sudo borg list /mnt/backup/borg-repo

### Browse files in backup

sudo borg list /mnt/backup/borg-repo::hostname-2024-05-16_020000

### Restore entire backup

sudo borg extract /mnt/backup/borg-repo::hostname-2024-05-16_020000 --target /tmp/restore

### Restore specific file or folder

sudo borg extract /mnt/backup/borg-repo::hostname-2024-05-16_020000 home/user/important-file.txt

## Save installed package list

```bash
sudo nano /usr/local/bin/save-package-list.sh
#!/bin/bash
dpkg --get-selections > /root/installed-packages.txt
apt-mark showauto > /root/auto-installed-packages.txt
sudo chmod +x /usr/local/bin/save-package-list.sh
```

## Monitor disk space

df -h /mnt/backup_borg
borg info /mnt/backup_borg/borg-repo | grep "Original size"

## Multiple exclude files

## Create category-based exclude files

```bash
sudo nano /root/borg-exclude-system.txt
sudo nano /root/borg-exclude-docker.txt
sudo nano /root/borg-exclude-dev.txt
```

## Use them all

```bash
borg create \
    --exclude-from /root/borg-exclude-system.txt \
    --exclude-from /root/borg-exclude-docker.txt \
    --exclude-from /root/borg-exclude-dev.txt \
    "::$BACKUP_NAME" \
    /
```

## Edit configuration

```bash
sudo nano /usr/local/etc/borg/borg-backup.conf
```

## Edit passphrase

```bash
sudo nano /usr/local/etc/borg/borg-passphrase
sudo chmod 600 /usr/local/etc/borg/borg-passphrase
````

## Test backup

sudo /usr/local/bin/borg-backup.sh --dry-run --verbose
