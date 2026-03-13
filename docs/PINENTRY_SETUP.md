# Pinentry Auto-Detection Setup

This configuration provides intelligent pinentry selection based on your environment.

## How It Works

The `pinentry-auto` wrapper script automatically detects your environment and chooses the appropriate pinentry:

1. **GUI Available** (DISPLAY or WAYLAND_DISPLAY set):
   - First tries: `pinentry-gnome3` (GNOME/GTK environments)
   - Fallback to: `pinentry-gtk2` (generic GTK)

2. **No GUI** (console, SSH, etc.):
   - Uses: `pinentry-curses` (terminal-based)

## Implementation

Located in: `home-manager/_mixins/cli/gpg.nix`

```nix
pinentry-auto = pkgs.writeShellScriptBin "pinentry-auto" ''
  # Check for GUI
  if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    # Try GNOME/GTK pinentry
    exec pinentry-gnome3 "$@" || exec pinentry-gtk2 "$@"
  fi

  # Fall back to curses
  exec pinentry-curses "$@"
'';
```

## Testing

### Test GUI Mode
```bash
# In a GUI session (GNOME, KDE, etc.)
echo "GETPIN" | gpg-connect-agent
# Should show a GUI dialog

# Or test with a real GPG operation
echo "test" | gpg --clearsign
```

### Test Console Mode
```bash
# In a pure console (Ctrl+Alt+F2 or SSH without X forwarding)
unset DISPLAY WAYLAND_DISPLAY
echo "GETPIN" | gpg-connect-agent
# Should show terminal prompt

# Or test with GPG
echo "test" | gpg --clearsign
```

### Test SSH Mode
```bash
# SSH without X11 forwarding
ssh yourhost
echo "test" | gpg --clearsign
# Should use curses pinentry
```

## Troubleshooting

### Pinentry not showing up

1. **Check GPG agent is running:**
   ```bash
   gpg-connect-agent /bye
   ```

2. **Verify GPG_TTY is set:**
   ```bash
   echo $GPG_TTY
   # Should show your terminal device like /dev/pts/0
   ```

3. **Restart GPG agent:**
   ```bash
   gpgconf --kill gpg-agent
   gpgconf --launch gpg-agent
   ```

### GUI pinentry not appearing

1. **Check display variables:**
   ```bash
   echo $DISPLAY
   echo $WAYLAND_DISPLAY
   ```

2. **Verify pinentry-gnome3 is installed:**
   ```bash
   which pinentry-gnome3
   pinentry-gnome3 --version
   ```

3. **Check GCR library is available:**
   ```bash
   nix-store -q --references $(which pinentry-gnome3) | grep gcr
   ```

### Curses pinentry not working

1. **Check GPG_TTY environment:**
   ```bash
   # Should be set in shell init
   export GPG_TTY=$(tty)
   gpg-connect-agent updatestartuptty /bye
   ```

2. **Verify pinentry-curses exists:**
   ```bash
   which pinentry-curses
   ```

## Manual Override

You can temporarily override the pinentry for testing:

```bash
# Force GUI pinentry
export PINENTRY_USER_DATA="USE_GUI"

# Force curses pinentry
unset DISPLAY WAYLAND_DISPLAY

# Or set in gpg-agent.conf
echo "pinentry-program $(which pinentry-curses)" > ~/.gnupg/gpg-agent.conf
gpgconf --reload gpg-agent
```

## Installed Pinentry Variants

The configuration installs these pinentry versions:

| Package | Use Case | Size |
|---------|----------|------|
| `pinentry-gnome3` | GNOME/GTK GUI | ~200KB |
| `pinentry-gtk2` | Generic GTK2 GUI | ~100KB |
| `pinentry-curses` | Terminal/Console | ~50KB |
| `pinentry-auto` | Smart wrapper | ~1KB |

## Related Files

- Main config: `home-manager/_mixins/cli/gpg.nix`
- Console config: `home-manager/_mixins/console/systems/linux.nix`
- Bootstrap shell: `shell.nix`

## NixOS Rebuild

After changes, rebuild your configuration:

```bash
# Home Manager
home-manager switch --flake .

# Or NixOS system
sudo nixos-rebuild switch --flake .
```

## See Also

- [GnuPG Documentation](https://www.gnupg.org/documentation/)
- [Pinentry Manual](https://www.gnupg.org/related_software/pinentry/)
- GPG agent config: `~/.gnupg/gpg-agent.conf`
