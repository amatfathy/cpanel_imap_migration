#!/bin/bash

# Complete Manual Uninstall Script for Email Migration Plugin
# Run as root

echo "=== Email Migration Plugin Manual Uninstall ==="

# Remove main Perl module
if [ -f "/usr/local/cpanel/Cpanel/API/MigrateMail.pm" ]; then
    rm -f "/usr/local/cpanel/Cpanel/API/MigrateMail.pm"
    echo "✓ Removed MigrateMail.pm API module"
else
    echo "- MigrateMail.pm not found"
fi

# Remove services configuration
if [ -f "/usr/local/cpanel/etc/services.json" ]; then
    rm -f "/usr/local/cpanel/etc/services.json"
    echo "✓ Removed services.json configuration"
else
    echo "- services.json not found"
fi

# Remove plugin frontend files (check multiple theme locations)
THEMES=("jupiter" "paper_lantern" "x3")
for theme in "${THEMES[@]}"; do
    PLUGIN_DIR="/usr/local/cpanel/base/frontend/${theme}/migrate_email"
    if [ -d "$PLUGIN_DIR" ]; then
        rm -rf "$PLUGIN_DIR"
        echo "✓ Removed plugin files from ${theme} theme"
    fi
done

# Remove any plugin registration files
PLUGIN_CONFIGS="/var/cpanel/plugins"
if [ -f "${PLUGIN_CONFIGS}/migrate_email.json" ]; then
    rm -f "${PLUGIN_CONFIGS}/migrate_email.json"
    echo "✓ Removed plugin configuration"
fi

# Clean up temporary files
find /tmp -name "imapsync_*.txt" -type f -delete 2>/dev/null
echo "✓ Cleaned temporary migration logs"

# Remove plugin cache
if [ -d "/usr/local/cpanel/var/cache/migrate_email" ]; then
    rm -rf "/usr/local/cpanel/var/cache/migrate_email"
    echo "✓ Removed plugin cache"
fi

# Restart cPanel to clear loaded modules
echo "Restarting cPanel services..."
/scripts/restartsrv_cpanel --no-verbose

echo ""
echo "=== Uninstall Complete ==="
echo "The Email Migration Plugin has been completely removed."
echo "You may need to refresh your browser to see changes in cPanel."