#!/bin/bash

# Email Migration Plugin Cleanup Script
# Removes temporary files and logs created during migrations

echo "Cleaning up Email Migration Plugin..."

# Remove temporary migration logs
if [ -d "/tmp" ]; then
    find /tmp -name "imapsync_*.txt" -type f -mtime +7 -delete 2>/dev/null
    echo "Removed old migration log files"
fi

# Remove plugin cache if it exists
if [ -d "/usr/local/cpanel/var/cache/migrate_email" ]; then
    rm -rf "/usr/local/cpanel/var/cache/migrate_email"
    echo "Removed plugin cache directory"
fi

# Restart cPanel services to clear any loaded modules
/scripts/restartsrv_cpanel --no-verbose 2>/dev/null

echo "Email Migration Plugin cleanup completed"
exit 0