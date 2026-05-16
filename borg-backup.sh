#!/bin/bash

# ============================================
# Borg Backup Script for Ubuntu Server 24.04
# ============================================

# Configuration file location
CONFIG_FILE="/usr/local/etc/borg/borg-backup.conf"

# ============================================
# Load configuration
# ============================================
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    echo "Please create the configuration file before running this script."
    exit 1
fi

# Source the configuration
source "$CONFIG_FILE"

# Load passphrase from file
if [ ! -f "$BORG_PASSPHRASE_FILE" ]; then
    echo "ERROR: Passphrase file not found: $BORG_PASSPHRASE_FILE"
    echo "Please create the passphrase file with: echo 'your-passphrase' > $BORG_PASSPHRASE_FILE"
    echo "And secure it with: chmod 600 $BORG_PASSPHRASE_FILE"
    exit 1
fi

# Export passphrase for borg
export BORG_PASSPHRASE=$(cat "$BORG_PASSPHRASE_FILE")
export BORG_REPO

# ============================================
# Parse command line arguments
# ============================================
DRY_RUN=false
VERBOSE=false
SHOW_HELP=false

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $arg"
            SHOW_HELP=true
            shift
            ;;
    esac
done

# ============================================
# Help message
# ============================================
if [ "$SHOW_HELP" = true ]; then
    echo "========================================="
    echo "Borg Backup Script - Help"
    echo "========================================="
    echo ""
    echo "Usage: $(basename $0) [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run, -n    Show what would be backed up without making changes"
    echo "  --verbose, -v    Enable verbose output with detailed file listings"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Config file:     $CONFIG_FILE"
    echo "  Repository:      $BORG_REPO"
    echo "  Mount point:     $BACKUP_MOUNT"
    echo "  Exclude file:    $EXCLUDE_FILE"
    echo "  Passphrase file: $BORG_PASSPHRASE_FILE"
    echo "  Log file:        $LOG_FILE"
    echo "  Package lists:   $PACKAGE_LIST_DIR"
    echo ""
    echo "Examples:"
    echo "  $(basename $0)                    # Run normal backup"
    echo "  $(basename $0) --dry-run          # Test backup without writing"
    echo "  $(basename $0) --verbose          # Run with detailed output"
    echo "  $(basename $0) --dry-run --verbose  # Test with detailed listing"
    echo ""
    echo "Backup paths:"
    for path in "${BACKUP_PATHS[@]}"; do
        echo "  $path"
    done
    echo ""
    echo "Retention policy:"
    echo "  Daily:    $KEEP_DAILY backups"
    echo "  Weekly:   $KEEP_WEEKLY backups"
    echo "  Monthly:  $KEEP_MONTHLY backups"
    echo ""
    exit 0
fi

# ============================================
# Initial output and mode indicators
# ============================================
if [ "$DRY_RUN" = true ]; then
    echo "========================================="
    echo "DRY RUN MODE - No changes will be made"
    echo "========================================="
fi

if [ "$VERBOSE" = true ]; then
    echo "Verbose mode enabled"
fi

# Setup logging (skip for dry-run to keep output clean)
if [ "$DRY_RUN" = false ]; then
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
fi

echo "========================================="
echo "Borg Backup Started: $(date)"
echo "Hostname: $(hostname)"
echo "Repository: $BORG_REPO"
echo "Config file: $CONFIG_FILE"
echo "Dry Run: $DRY_RUN"
echo "Verbose: $VERBOSE"
echo "========================================="

# ============================================
# Pre-flight checks
# ============================================
echo ""
echo "Running pre-flight checks..."

# Check if mount is available
if ! mountpoint -q "$BACKUP_MOUNT"; then
    echo "ERROR: $BACKUP_MOUNT is not mounted!"
    echo "Please mount the backup destination and try again."
    exit 1
fi
echo "✓ Backup mount point is accessible: $BACKUP_MOUNT"

# Check available space on backup mount
AVAILABLE_SPACE=$(df -BG "$BACKUP_MOUNT" | tail -1 | awk '{print $4}' | sed 's/G//')
echo "✓ Available space on backup mount: ${AVAILABLE_SPACE}GB"

if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    echo "WARNING: Less than 10GB available on backup mount!"
fi

# Check if exclude file exists
if [ ! -f "$EXCLUDE_FILE" ]; then
    echo "WARNING: Exclude file $EXCLUDE_FILE not found!"
    echo "Backup will proceed without exclusions."
else
    EXCLUDE_COUNT=$(grep -v '^#' "$EXCLUDE_FILE" | grep -v '^$' | wc -l)
    echo "✓ Exclude file found with $EXCLUDE_COUNT patterns"
fi

# Check if repository exists
if [ ! -d "$BORG_REPO" ]; then
    echo "ERROR: Borg repository not found at $BORG_REPO"
    echo "Please initialize the repository first with: borg init"
    exit 1
fi
echo "✓ Borg repository found"

# Verify passphrase file permissions
PASSPHRASE_PERMS=$(stat -c "%a" "$BORG_PASSPHRASE_FILE")
if [ "$PASSPHRASE_PERMS" != "600" ]; then
    echo "WARNING: Passphrase file has permissions $PASSPHRASE_PERMS (should be 600)"
    echo "  Run: sudo chmod 600 $BORG_PASSPHRASE_FILE"
fi

# ============================================
# Save package lists (skip in dry-run)
# ============================================
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Saving package lists..."
    dpkg --get-selections > "$PACKAGE_LIST_DIR/installed-packages.txt"
    apt-mark showauto > "$PACKAGE_LIST_DIR/auto-installed-packages.txt"
    echo "✓ Package lists saved to $PACKAGE_LIST_DIR"
fi

# ============================================
# Create backup
# ============================================
echo ""
echo "========================================="
echo "Starting backup creation..."
echo "========================================="

# Create backup with meaningful name
BACKUP_NAME="$(hostname)-$(date +%Y-%m-%d_%H%M%S)"

# Build borg create command
BORG_CREATE_CMD=(
    borg create
    --stats
    --compression "$COMPRESSION"
    --exclude-caches
)

# Add verbose or progress based on mode
if [ "$VERBOSE" = true ]; then
    BORG_CREATE_CMD+=(--verbose --list)
else
    BORG_CREATE_CMD+=(--progress)
fi

# Add dry-run flag if enabled
if [ "$DRY_RUN" = true ]; then
    BORG_CREATE_CMD+=(--dry-run)
    if [ "$VERBOSE" = false ]; then
        BORG_CREATE_CMD+=(--list)
    fi
    echo ""
    echo "Files that would be backed up:"
    echo "----------------------------------------"
fi

# Add exclude file if it exists
if [ -f "$EXCLUDE_FILE" ]; then
    BORG_CREATE_CMD+=(--exclude-from "$EXCLUDE_FILE")
fi

# Add archive name
BORG_CREATE_CMD+=("::$BACKUP_NAME")

# Add backup paths from configuration
BORG_CREATE_CMD+=("${BACKUP_PATHS[@]}")

# Execute backup
echo "Archive name: $BACKUP_NAME"
echo "Compression: $COMPRESSION"
echo ""
"${BORG_CREATE_CMD[@]}"
BACKUP_EXIT=$?

echo ""
echo "Backup create exit code: $BACKUP_EXIT"

# ============================================
# Post-backup operations (skip in dry-run)
# ============================================
if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "========================================="
    echo "Dry run completed - no changes made"
    echo "To perform actual backup, run without --dry-run flag"
    echo "========================================="
    exit 0
fi

# Prune old backups
echo ""
echo "========================================="
echo "Pruning old backups..."
echo "========================================="

PRUNE_CMD=(
    borg prune
    --list
    --prefix "$(hostname)-"
    --keep-daily="$KEEP_DAILY"
    --keep-weekly="$KEEP_WEEKLY"
    --keep-monthly="$KEEP_MONTHLY"
)

if [ "$VERBOSE" = true ]; then
    PRUNE_CMD+=(--verbose)
fi

"${PRUNE_CMD[@]}"
PRUNE_EXIT=$?

echo ""
echo "Prune exit code: $PRUNE_EXIT"

# Compact repository to free space (Borg 1.2+)
if borg --version | grep -q "1.2\|1.4\|2."; then
    echo ""
    echo "========================================="
    echo "Compacting repository..."
    echo "========================================="
    
    COMPACT_CMD=(borg compact)
    
    if [ "$VERBOSE" = true ]; then
        COMPACT_CMD+=(--verbose)
    fi
    
    "${COMPACT_CMD[@]}"
    echo "✓ Repository compacted"
fi

# Check repository consistency (run on configured day)
DAY_OF_WEEK=$(date +%u)
if [ "$DAY_OF_WEEK" -eq "$CHECK_DAY" ]; then
    echo ""
    echo "========================================="
    echo "Running weekly repository check..."
    echo "========================================="
    
    CHECK_CMD=(borg check)
    
    if [ "$VERBOSE" = true ]; then
        CHECK_CMD+=(--verbose)
    fi
    
    "${CHECK_CMD[@]}"
    CHECK_EXIT=$?
    echo ""
    echo "Check exit code: $CHECK_EXIT"
fi

# ============================================
# Display summary
# ============================================
echo ""
echo "========================================="
echo "Backup Summary"
echo "========================================="
echo "Archive created: $BACKUP_NAME"
echo "Repository: $BORG_REPO"
echo ""

# Show repository info
echo "Repository statistics:"
borg info "$BORG_REPO" | tail -n 15

echo ""
echo "Recent backups:"
borg list "$BORG_REPO" --short --last 5

echo ""
echo "========================================="
echo "Borg Backup Finished: $(date)"
echo "========================================="

# Exit with error if backup or prune failed
if [ $BACKUP_EXIT -ne 0 ] || [ $PRUNE_EXIT -ne 0 ]; then
    echo "ERROR: Backup or prune operation failed!"
    exit 1
fi

echo "✓ Backup completed successfully"
exit 0
