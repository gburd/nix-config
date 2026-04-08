# Multi-Account Email, Calendar, and Productivity Setup

This document provides complete setup instructions for the multi-account email, calendar, and productivity system on NixOS.

## Architecture Overview

```
Email Flow:
  ProtonMail → Bridge (localhost:1143/1025) → Neomutt
  Gmail/iCloud/Outlook → IMAP/SMTP → Neomutt

Calendar Flow:
  Google/iCloud/Outlook CalDAV → vdirsyncer → Local Storage → Evolution + Khal

Notes/Tasks:
  Markdown files → Proton Drive (rclone WebDAV mount) → Neovim + taskbook.sh

Secrets:
  sops-nix encrypted YAML → /run/secrets/ → Application configs
```

## Prerequisites

Before starting, gather the following information:

### Email Accounts (7 total)
1. ProtonMail account credentials
2. Gmail Personal (app-specific password required)
3. Gmail Work (app-specific password required)
4. Fastmail (existing setup)
5. iCloud (app-specific password required)
6. Outlook/Microsoft 365
7. Amazon work email

### Calendar Accounts
1. Google Personal (OAuth credentials needed)
2. Google Work (OAuth credentials needed)
3. iCloud (same as email)
4. Outlook (same as email)

### Proton Drive
- Proton account with WebDAV access (requires Proton Visionary plan)
- Or alternative: Syncthing setup

## Step 1: Configure Secrets

Edit the encrypted secrets file:

```bash
cd /home/gburd/ws/nix-config
sops nixos/workstation/floki/secrets.yaml
```

Add all credentials (see secrets.yaml template below).

### Generate App-Specific Passwords

**Gmail:**
1. Go to https://myaccount.google.com/security
2. Enable 2-Step Verification if not already enabled
3. Go to "App passwords"
4. Generate new password for "Mail" on "Other (Custom name)"
5. Use this password in secrets.yaml

**iCloud:**
1. Go to https://appleid.apple.com/
2. Sign in → Security → App-Specific Passwords
3. Generate password
4. Use this password in secrets.yaml

**Outlook:**
- If using Microsoft 365 with MFA: Generate app password from account settings
- Otherwise: Use regular password

### Google Calendar OAuth Setup

1. Go to https://console.cloud.google.com/
2. Create new project (or select existing)
3. Enable Google Calendar API
4. Create OAuth 2.0 credentials:
   - Application type: Desktop app
   - Name: "vdirsyncer-personal" (or similar)
5. Download credentials and extract:
   - client_id
   - client_secret
6. Add both to secrets.yaml
7. Repeat for work account if different

## Step 2: Rebuild Home-Manager

```bash
cd /home/gburd/ws/nix-config
home-manager switch --flake .#gburd@floki
```

Verify secrets are accessible:

```bash
ls -la ~/.config/sops-nix/secrets/email/
cat ~/.config/sops-nix/secrets/email/fastmail-user
```

## Step 3: Setup ProtonMail Bridge

Run ProtonMail Bridge interactively for first-time setup:

```bash
protonmail-bridge --cli
```

In the bridge CLI:

```
> login
# Follow prompts to login to ProtonMail account

> info
# Note the IMAP/SMTP passwords shown

> change mode
# Select "IMAP/SMTP" mode

> exit
```

**Important:** Copy the IMAP/SMTP password from bridge output and add it to secrets.yaml as `email/protonmail-pass`.

Enable and start the service:

```bash
systemctl --user enable --now protonmail-bridge
systemctl --user status protonmail-bridge
```

Verify bridge is running:

```bash
telnet localhost 1143  # IMAP - should see greeting
telnet localhost 1025  # SMTP - should see greeting
```

## Step 4: Test Neomutt

Launch Neomutt:

```bash
neomutt
```

**Account Switching:**
- F1 = ProtonMail
- F2 = Gmail Personal
- F3 = Gmail Work
- F4 = Fastmail (default)
- F5 = iCloud
- F6 = Outlook
- F7 = Amazon

Test each account:
1. Press F-key to switch
2. Verify inbox loads
3. Check status bar shows correct account
4. Send test email

**Common Issues:**
- "Could not connect to server": Check credentials in secrets
- Gmail "Authentication failed": Ensure using app-specific password, not regular password
- ProtonMail connection refused: Verify bridge is running
- iCloud "Invalid credentials": Verify app-specific password generated correctly

## Step 5: Setup Calendar Sync

### Discover Calendars

```bash
vdirsyncer discover google_personal
vdirsyncer discover google_work
vdirsyncer discover icloud
vdirsyncer discover outlook
```

For Google calendars, a browser window will open for OAuth authentication. Follow the prompts.

### Initial Sync

```bash
vdirsyncer sync
```

This will download all calendar events to `~/.local/share/calendars/`.

### Enable Auto-Sync

```bash
systemctl --user enable --now vdirsyncer.timer
systemctl --user status vdirsyncer.timer
```

Calendar will sync every 15 minutes automatically.

### Verify Calendar Access

**Khal (TUI):**

```bash
khal list
khal calendar
khal new 2025-03-25 10:00 1h "Test event"
```

**Evolution (GUI):**

```bash
evolution &
```

Evolution should auto-discover calendars in `~/.local/share/calendars/`. Or manually add as "Local Calendar" in settings.

## Step 6: Setup Proton Drive

**Note:** Proton Drive WebDAV requires Proton Visionary plan. If unavailable, skip to Alternative Setup below.

### Test rclone Configuration

```bash
rclone lsd protondrive:
```

Should list Proton Drive folders. If authentication fails, verify WebDAV credentials in secrets.

### Enable Mount Service

```bash
systemctl --user enable --now proton-drive-mount
systemctl --user status proton-drive-mount
```

Verify mount:

```bash
ls ~/ProtonDrive
echo "test" > ~/ProtonDrive/test.txt
cat ~/ProtonDrive/test.txt
```

### Alternative Setup (Without WebDAV Access)

Use Syncthing to sync `~/ProtonDrive` with another device that has Proton Drive access:

1. Install Syncthing on both machines
2. Setup sync folder: `~/ProtonDrive`
3. Configure other machine to sync with Proton Drive desktop app
4. Transitive sync: NixOS ↔ Other Machine ↔ Proton Drive

## Step 7: Test Notes and Tasks

### Taskbook

```bash
# Add tasks
taskbook add "Test task 1"
ta "Test task 2"  # Shortcut

# List tasks
taskbook list
tl  # Shortcut

# Mark as done
taskbook done 1
td 1  # Shortcut

# Archive completed
taskbook archive

# Edit in nvim
taskbook edit
te  # Shortcut
```

Tasks are stored in `~/ProtonDrive/Tasks/tasks.md` as markdown.

### Notes

Create notes:

```bash
nvim ~/ProtonDrive/Notes/test.md
```

**Neovim Keybindings:**
- `<leader>fn` - Find notes (Telescope)
- `<leader>fg` - Grep notes (Telescope)
- `<leader>nn` - Create new note

Directory structure:
```
~/ProtonDrive/Notes/
  ├── work/
  ├── personal/
  └── projects/
```

## Step 8: Verification Checklist

- [ ] All secrets accessible: `ls ~/.config/sops-nix/secrets/email/`
- [ ] ProtonMail Bridge running: `systemctl --user status protonmail-bridge`
- [ ] Neomutt loads all 7 accounts (F1-F7)
- [ ] Send test email from each account
- [ ] vdirsyncer timer active: `systemctl --user status vdirsyncer.timer`
- [ ] Khal shows calendar events: `khal list`
- [ ] Evolution displays calendars
- [ ] Proton Drive mounted: `ls ~/ProtonDrive`
- [ ] Taskbook functional: `taskbook list`
- [ ] Notes accessible in nvim

## Maintenance

### Update App-Specific Passwords

Gmail and iCloud app-specific passwords may expire. Regenerate and update secrets:

```bash
sops nixos/workstation/floki/secrets.yaml
# Update password
home-manager switch --flake .#gburd@floki
```

### Clear Neomutt Cache

If experiencing sync issues:

```bash
rm -rf ~/.cache/neomutt/*/
```

### Check Service Logs

```bash
journalctl --user -u protonmail-bridge --since today
journalctl --user -u vdirsyncer --since today
journalctl --user -u proton-drive-mount --since today
```

### Re-authenticate Google OAuth

When tokens expire:

```bash
rm ~/.local/share/vdirsyncer/google_*_token
vdirsyncer discover google_personal
vdirsyncer discover google_work
```

### Monitor Disk Usage

```bash
du -sh ~/.cache/neomutt/*
du -sh ~/ProtonDrive/*
du -sh ~/.local/share/calendars/*
```

## Troubleshooting

### ProtonMail Bridge Won't Start

```bash
# Check logs
journalctl --user -u protonmail-bridge

# Restart service
systemctl --user restart protonmail-bridge

# Test manually
protonmail-bridge --cli
```

### Calendar Not Syncing

```bash
# Manual sync
vdirsyncer sync

# Check config
vdirsyncer discover

# Verify OAuth tokens
ls ~/.local/share/vdirsyncer/
```

### Proton Drive Mount Fails

```bash
# Check logs
journalctl --user -u proton-drive-mount

# Test rclone manually
rclone lsd protondrive:

# Remount
systemctl --user restart proton-drive-mount
```

### Neomutt Account Issues

**Problem:** Can't connect to IMAP
- Verify credentials: `cat ~/.config/sops-nix/secrets/email/<account>-user`
- Check server settings in account config file
- Test with telnet: `telnet imap.example.com 993`

**Problem:** Can't send email
- Verify SMTP settings in account config
- Check SMTP password matches IMAP password
- Test with telnet: `telnet smtp.example.com 465`

**Problem:** Slow folder loading
- Clear cache: `rm -rf ~/.cache/neomutt/<account>/*`
- Reduce `mail_check` interval in neomuttrc

## Secrets Template

Example secrets.yaml structure (encrypted with sops):

```yaml
# Email accounts
email/protonmail-user: user@protonmail.com
email/protonmail-pass: bridge-generated-password
email/gmail-personal-user: personal@gmail.com
email/gmail-personal-pass: app-specific-password
email/gmail-work-user: work@gmail.com
email/gmail-work-pass: app-specific-password
email/fastmail-user: greg@burd.me
email/fastmail-pass: existing-password
email/icloud-user: user@icloud.com
email/icloud-pass: app-specific-password
email/outlook-user: user@outlook.com
email/outlook-pass: password
email/amazon-user: gregburd@amazon.com
email/amazon-pass: work-password

# Calendar credentials
calendar/google-personal-client-id: 123456789-abcdefg.apps.googleusercontent.com
calendar/google-personal-client-secret: GOCSPX-AbCdEfGhIjKlMnOpQrStUvWxYz
calendar/google-work-client-id: 987654321-hijklmn.apps.googleusercontent.com
calendar/google-work-client-secret: GOCSPX-ZyXwVuTsRqPoNmLkJiHgFeDcBa
calendar/icloud-user: user@icloud.com
calendar/icloud-pass: app-specific-password
calendar/outlook-user: user@outlook.com
calendar/outlook-pass: password

# Proton Drive
proton-drive/webdav-user: user@protonmail.com
proton-drive/webdav-pass: webdav-password
```

## Configuration Files Reference

Key files modified/created:

```
home-manager/
├── _mixins/
│   ├── console/
│   │   ├── neomutt/
│   │   │   ├── default.nix           # Multi-account setup
│   │   │   ├── neomuttrc             # F-key account switching
│   │   │   └── accounts/
│   │   │       ├── protonmail.muttrc
│   │   │       ├── gmail-personal.muttrc
│   │   │       ├── gmail-work.muttrc
│   │   │       ├── fastmail.muttrc
│   │   │       ├── icloud.muttrc
│   │   │       ├── outlook.muttrc
│   │   │       └── amazon.muttrc
│   │   ├── khal.nix                  # Calendar TUI config
│   │   └── taskbook.nix              # Task management script
│   ├── services/
│   │   ├── protonmail-bridge.nix     # ProtonMail Bridge service
│   │   ├── vdirsyncer.nix            # Calendar sync service
│   │   └── proton-drive.nix          # Proton Drive mount
│   └── users/gburd/hosts/
│       └── floki.nix                 # Imports and secrets config
└── nixos/workstation/floki/
    └── secrets.yaml                  # Encrypted credentials
```

## Support

For issues or questions:
1. Check logs: `journalctl --user -u <service-name>`
2. Verify secrets: `ls ~/.config/sops-nix/secrets/`
3. Test individual components manually before troubleshooting services
4. Check GitHub issues for known problems
