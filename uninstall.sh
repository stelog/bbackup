#!/bin/bash

# ============================================
# Borg Backup System Uninstaller
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================="
echo "Borg Backup System Uninstaller"
echo "========================================="
echo ""
print_warn "This will remove all installed files and disable the timer."
print_warn "Your backup repository and data will NOT be deleted."
echo ""
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Uninstall cancelled."
    exit 0
fi

echo ""
print_info "Stopping and disabling timer..."
systemctl stop borg-backup.timer 2>/dev/null || true
systemctl disable borg-backup.timer 2>/dev/null || true
echo "  ✓ Timer stopped and disabled"

print_info "Removing systemd files..."
rm -f /usr/local/lib/systemd/system/borg-backup.service
rm -f /usr/local/lib/systemd/system/borg-backup.timer
echo "  ✓ Systemd files removed"

print_info "Reloading systemd..."
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true
echo "  ✓ Systemd reloaded"

print_info "Removing script..."
rm -f /usr/local/bin/borg-backup.sh
echo "  ✓ Backup script removed"

echo ""
read -p "Remove configuration files (/usr/local/etc/borg/)? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
#    print_warn "Creating backup of configuration..."
#    if [ -d /usr/local/etc/borg ]; then
#        tar -czf "/root/borg-config-backup-$(date +%Y%m%d_%H%M%S).tar.gz" \
#            -C /usr/local/etc borg 2>/dev/null || true
#        echo "  ✓ Configuration backed up to /root/"
#    fi

	print_info "Remove /usr/local/etc/borg..."
    rm -rf /usr/local/etc/borg
    echo "  ✓ Configuration removed"
else
    print_info "Configuration files preserved in /usr/local/etc/borg/"
fi

#echo ""
#read -p "Remove passphrase file (borg-passphrase)? (y/n) " -n 1 -r
#echo
#if [[ $REPLY =~ ^[Yy]$ ]]; then
#    rm -f /usr/local/etc/borg/borg-passphrase
#    echo "  ✓ Passphrase file removed"
#else
#    print_info "Passphrase file preserved"
#fi

echo ""
print_info "Uninstall completed successfully!"
echo ""
print_warn "Your Borg repository at /mnt/backup_borg/borg-repo was NOT touched."
print_warn "Your backups remain intact."
echo ""
