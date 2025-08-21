# Email Migration Plugin for cPanel

A cPanel plugin for migrating emails from Gmail and other IMAP services to cPanel email accounts.

## Features

- Migrate from Gmail (with App Password support)
- Migrate from any IMAP-compatible email service
- Simple web interface integrated with cPanel
- Preserves email folder structure and dates
- Detailed migration progress and error reporting

## Requirements

- cPanel/WHM 11.70.0 or higher
- `imapsync` tool installed on server
- Root access for installation

## Installation

1. Login to your server via SSH as root
2. Clone or download the plugin files
3. Install the plugin:
   ```bash
   /scripts/install_plugin /path/to/migrate-email/install.json
   ```
4. Copy the API module:
   ```bash
   cp /path/to/migrate-email/src/MigrateMail.pm /usr/local/cpanel/Cpanel/API/
   cp /path/to/migrate-email/src/etc/services.json /usr/local/cpanel/etc/
   ```
5. Restart cPanel:
   ```bash
   /scripts/restartsrv_cpanel
   ```

## Uninstallation

### Method 1: WHM Interface (Recommended)
1. Login to WHM
2. Go to Software → Manage Plugins
3. Find "Email Migration" and click Uninstall

### Method 2: Command Line
```bash
/scripts/uninstall_plugin /path/to/migrate-email/install.json
```

### Method 3: Manual Cleanup (if needed)
```bash
chmod +x manual_uninstall.sh
./manual_uninstall.sh
```

## Usage

1. Login to cPanel
2. Go to Email section → Email Migration
3. Enter source email credentials
4. Select destination cPanel email account
5. Click "Start Migration"

### Gmail Setup
For Gmail accounts, you must:
1. Enable 2-Factor Authentication
2. Generate an App Password
3. Use the App Password instead of your regular Gmail password

## Troubleshooting

- **"imapsync not found"**: Install imapsync on your server
- **Gmail login fails**: Ensure you're using an App Password, not regular password
- **Migration slow**: Large mailboxes may take considerable time
- **Permission errors**: Ensure plugin files have correct ownership/permissions

## Support

This plugin requires `imapsync` to be installed on your server. Contact your hosting provider if you encounter installation issues.

## License

Licensed under the Apache License, Version 2.0