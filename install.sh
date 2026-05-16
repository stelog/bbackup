#!/bin/bash

# ============================================
# Borg Backup System Installer
# ============================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_USER="${SUDO_USER:-$USER}"

# ============================================
# Helper functions
# ============================================

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# ============================================
# Check prerequisites
# ============================================

print_info "Starting Borg Backup System installation..."
echo ""

check_root

# Check if required files exist in repo
print_info "Checking required files in repository..."

REQUIRED_FILES=(
    "borg-backup.sh"
    "borg-backup.conf"
    "borg-exclude.txt"
    "borg-backup.service"
    "borg-backup.timer"
)

MISSING_FILES=false
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        print_error "Missing required file: $file"
        MISSING_FILES=true
    else
        echo "  ✓ Found: $file"
    fi
done

if [ "$MISSING_FILES" = true ]; then
    print_error "Missing required files. Please check your repository."
    exit 1
fi

echo ""

# Check if borgbackup is installed
if ! command -v borg &> /dev/null; then
    print_warn "BorgBackup is not installed"
    read -p "Would you like to install it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing BorgBackup..."
        apt update
        apt install -y borgbackup
        print_info "BorgBackup installed successfully"
    else
        print_error "BorgBackup is required. Exiting."
        exit 1
    fi
else
    BORG_VERSION=$(borg --version)
    print_info "BorgBackup is already installed: $BORG_VERSION"
fi

echo ""

# ============================================
# Create directory structure
# ============================================

print_info "Creating directory structure..."

mkdir -p /usr/local/bin
mkdir -p /usr/local/etc/borg

echo "  ✓ Created /usr/local/bin"
echo "  ✓ Created /usr/local/etc/borg"

echo ""

# ============================================
# Install files
# ============================================

print_info "Installing files..."

# Install backup script
print_info "Installing backup script..."
cp "$SCRIPT_DIR/borg-backup.sh" /usr/local/bin/borg-backup.sh
chmod +x /usr/local/bin/borg-backup.sh
echo "  ✓ Installed: /usr/local/bin/borg-backup.sh"

# Install configuration file
print_info "Installing configuration file..."
if [ -f /usr/local/etc/borg/borg-backup.conf ]; then
    print_warn "Configuration file already exists, creating backup..."
    cp /usr/local/etc/borg/borg-backup.conf /usr/local/etc/borg/borg-backup.conf.backup.$(date +%Y%m%d_%H%M%S)
fi
cp "$SCRIPT_DIR/borg-backup.conf" /usr/local/etc/borg/borg-backup.conf
chmod 644 /usr/local/etc/borg/borg-backup.conf
echo "  ✓ Installed: /usr/local/etc/borg/borg-backup.conf"

# Install exclude file
print_info "Installing exclude patterns..."
if [ -f /usr/local/etc/borg/borg-exclude.txt ]; then
    print_warn "Exclude file already exists, creating backup..."
    cp /usr/local/etc/borg/borg-exclude.txt /usr/local/etc/borg/borg-exclude.txt.backup.$(date +%Y%m%d_%H%M%S)
fi
cp "$SCRIPT_DIR/borg-exclude.txt" /usr/local/etc/borg/borg-exclude.txt
chmod 644 /usr/local/etc/borg/borg-exclude.txt
echo "  ✓ Installed: /usr/local/etc/borg/borg-exclude.txt"

# Install systemd service
print_info "Installing systemd service files..."
cp "$SCRIPT_DIR/borg-backup.service" /usr/local/lib/systemd/system/borg-backup.service
chmod 644 /usr/local/lib/systemd/system/borg-backup.service
echo "  ✓ Installed: /usr/local/lib/systemd/system/borg-backup.service"

# Install systemd timer
cp "$SCRIPT_DIR/borg-backup.timer" /usr/local/lib/systemd/system/borg-backup.timer
chmod 644 /usr/local/lib/systemd/system/borg-backup.timer
echo "  ✓ Installed: /usr/local/lib/systemd/system/borg-backup.timer"

echo ""

# ============================================
# Reload systemd
# ============================================

print_info "Reloading systemd daemon..."
systemctl daemon-reload
echo "  ✓ Systemd daemon reloaded"

echo ""

# ============================================
# Configuration prompts
# ============================================

print_info "Configuration required..."
echo ""

# Check if passphrase file exists
PASSPHRASE_FILE="/usr/local/etc/borg/borg-passphrase"

if [ ! -f "$PASSPHRASE_FILE" ]; then
    print_warn "Borg passphrase file not found: $PASSPHRASE_FILE"
    echo ""
    echo "You need to create a passphrase file for encryption."
    echo ""
    read -p "Would you like to create it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -sp "Enter Borg passphrase: " PASSPHRASE
        echo
        read -sp "Confirm passphrase: " PASSPHRASE_CONFIRM
        echo

        if [ "$PASSPHRASE" != "$PASSPHRASE_CONFIRM" ]; then
            print_error "Passphrases do not match!"
            exit 1
        fi

        echo "$PASSPHRASE" > "$PASSPHRASE_FILE"
        chmod 600 "$PASSPHRASE_FILE"
        print_info "Passphrase file created and secured with permissions 600"
    else
        print_warn "You will need to create $PASSPHRASE_FILE manually"
        echo "  echo 'your-passphrase' > $PASSPHRASE_FILE"
        echo "  sudo chmod 600 $PASSPHRASE_FILE"
    fi
else
    print_info "Passphrase file already exists: $PASSPHRASE_FILE"

    # Check permissions
    PERMS=$(stat -c "%a" "$PASSPHRASE_FILE")
    if [ "$PERMS" != "600" ]; then
        print_warn "Passphrase file has incorrect permissions: $PERMS (should be 600)"
        chmod 600 "$PASSPHRASE_FILE"
        print_info "Fixed permissions to 600"
    fi
fi

echo ""

# ============================================
# Enable and start timer (optional)
# ============================================

print_info "Systemd timer setup..."
echo ""
echo "The timer is now installed but not enabled."
echo "You can enable it to run automatic backups."
echo ""

read -p "Would you like to enable and start the backup timer now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Enabling and starting borg-backup.timer..."
    systemctl enable borg-backup.timer
    systemctl start borg-backup.timer
    echo "  ✓ Timer enabled and started"
    echo ""
    print_info "Timer status:"
    systemctl status borg-backup.timer --no-pager -l
else
    print_warn "Timer not enabled. You can enable it later with:"
    echo "  sudo systemctl enable --now borg-backup.timer"
fi

echo ""

# ============================================
# Post-installation checks
# ============================================

print_info "Running post-installation checks..."
echo ""

# Check if mount point exists
if grep -q "/mnt/backup_borg" /usr/local/etc/borg/borg-backup.conf; then
    if [ ! -d /mnt/backup_borg ]; then
        print_warn "Backup mount point /mnt/backup_borg does not exist"
        echo "  You may need to:"
        echo "  1. Create the mount point: sudo mkdir -p /mnt/backup_borg"
        echo "  2. Configure /etc/fstab for automatic mounting"
        echo "  3. Mount the share: sudo mount /mnt/backup_borg"
    else
        if mountpoint -q /mnt/backup_borg; then
            print_info "Backup mount point is mounted: /mnt/backup_borg"
        else
            print_warn "Backup mount point exists but is not mounted: /mnt/backup_borg"
        fi
    fi
fi

echo ""

# ============================================
# Summary and next steps
# ============================================

print_info "Installation completed successfully!"
echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo "Installed files:"
echo "  • /usr/local/bin/borg-backup.sh"
echo "  • /usr/local/etc/borg/borg-backup.conf"
echo "  • /usr/local/etc/borg/borg-exclude.txt"
echo "  • /usr/local/etc/borg/borg-passphrase"
echo "  • /usr/local/lib/systemd/system/borg-backup.service"
echo "  • /usr/local/lib/systemd/system/borg-backup.timer"
echo ""
echo "========================================="
echo "Next Steps"
echo "========================================="
echo ""
echo "1. Review configuration:"
echo "   sudo nano /usr/local/etc/borg/borg-backup.conf"
echo ""
echo "2. Ensure Samba share is mounted:"
echo "   sudo mount /mnt/backup_borg"
echo ""
echo "3. Initialize Borg repository (if not done):"
echo "   sudo borg init --encryption=repokey-blake2 /mnt/backup_borg/borg-repo"
echo ""
echo "4. Export and backup your encryption key:"
echo "   sudo borg key export /mnt/backup_borg/borg-repo ~/borg-key-backup.txt"
echo ""
echo "5. Test the backup script:"
echo "   sudo /usr/local/bin/borg-backup.sh --dry-run"
echo ""
echo "6. Run a manual backup:"
echo "   sudo /usr/local/bin/borg-backup.sh"
echo ""
echo "7. Check timer status:"
echo "   sudo systemctl status borg-backup.timer"
echo "   sudo systemctl list-timers | grep borg"
echo ""
echo "8. View backup logs:"
echo "   sudo journalctl -u borg-backup.service -f"
echo "   sudo tail -f /var/log/borg-backup.log"
echo ""
echo "========================================="
echo ""

exit 0
