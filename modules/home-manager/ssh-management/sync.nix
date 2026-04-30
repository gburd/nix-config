{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-management;

  # Script for syncing keys to 1Password
  sync1PasswordScript = pkgs.writeShellScript "sync-ssh-to-1password" ''
    set -euo pipefail

    # Check if op CLI is available
    if ! command -v op >/dev/null 2>&1; then
      echo "⚠️  1Password CLI (op) not found. Install with: nix-shell -p _1password-cli"
      exit 1
    fi

    # Check if we're signed in to 1Password
    if ! op account list >/dev/null 2>&1; then
      echo "⚠️  Not signed in to 1Password. Run: eval \$(op signin)"
      exit 1
    fi

    HOSTNAME=$(hostname)
    VAULT="Private"  # Default vault, can be configured

    # Function to sync a key to 1Password
    sync_key() {
      local key_type="$1"
      local private_key_path="$2"
      local public_key_path="''${private_key_path}.pub"

      if [ ! -f "$private_key_path" ]; then
        echo "⚠️  Key not found: $private_key_path"
        return 1
      fi

      local title="''${HOSTNAME}-''${key_type}-$(date +%Y%m)"
      local private_key=$(cat "$private_key_path")
      local public_key=$(cat "$public_key_path" 2>/dev/null || echo "")

      # Check if item already exists
      if op item get "$title" --vault "$VAULT" >/dev/null 2>&1; then
        echo "Updating existing 1Password item: $title"
        op item edit "$title" \
          --vault "$VAULT" \
          "private_key[password]=$private_key" \
          "public_key[text]=$public_key" \
          "hostname[text]=$HOSTNAME" \
          "last_synced[text]=$(date -Iseconds)" || {
          echo "⚠️  Failed to update 1Password item: $title"
          return 1
        }
      else
        echo "Creating new 1Password item: $title"
        op item create \
          --category "SSH Key" \
          --title "$title" \
          --vault "$VAULT" \
          "private_key[password]=$private_key" \
          "public_key[text]=$public_key" \
          "hostname[text]=$HOSTNAME" \
          "key_type[text]=$key_type" \
          "created[text]=$(date -Iseconds)" || {
          echo "⚠️  Failed to create 1Password item: $title"
          return 1
        }
      fi

      echo "✓ Synced $key_type key to 1Password: $title"
    }

    # Sync authentication key
    ${optionalString (cfg.authKey.path != null) ''
      sync_key "auth" "${cfg.authKey.path}"
    ''}

    # Sync signing key
    ${optionalString (cfg.signingKey.path != null) ''
      sync_key "signing" "${cfg.signingKey.path}"
    ''}

    echo "✓ 1Password sync completed at $(date)"
  '';

  # Script for syncing keys from 1Password (recovery scenario)
  syncFrom1PasswordScript = pkgs.writeShellScript "sync-ssh-from-1password" ''
    set -euo pipefail

    # Check if op CLI is available
    if ! command -v op >/dev/null 2>&1; then
      echo "⚠️  1Password CLI (op) not found. Install with: nix-shell -p _1password-cli"
      exit 1
    fi

    # Check if we're signed in to 1Password
    if ! op account list >/dev/null 2>&1; then
      echo "⚠️  Not signed in to 1Password. Run: eval \$(op signin)"
      exit 1
    fi

    HOSTNAME=$(hostname)
    VAULT="Private"

    # Function to restore a key from 1Password
    restore_key() {
      local key_type="$1"
      local target_path="$2"

      # Find the most recent key for this host and type
      local title=$(op item list --vault "$VAULT" --categories "SSH Key" --format json | \
        jq -r ".[] | select(.title | contains(\"$HOSTNAME-$key_type\")) | .title" | \
        sort -r | head -n1)

      if [ -z "$title" ]; then
        echo "⚠️  No $key_type key found in 1Password for $HOSTNAME"
        return 1
      fi

      echo "Found key in 1Password: $title"

      # Get the private key
      local private_key=$(op item get "$title" --vault "$VAULT" --fields "private_key" 2>/dev/null)
      if [ -z "$private_key" ]; then
        echo "⚠️  Failed to retrieve private key from 1Password"
        return 1
      fi

      # Backup existing key if present
      if [ -f "$target_path" ]; then
        echo "Backing up existing key to ''${target_path}.backup"
        cp "$target_path" "''${target_path}.backup"
      fi

      # Write private key
      echo "$private_key" > "$target_path"
      chmod 600 "$target_path"

      # Get public key
      local public_key=$(op item get "$title" --vault "$VAULT" --fields "public_key" 2>/dev/null)
      if [ -n "$public_key" ]; then
        echo "$public_key" > "''${target_path}.pub"
        chmod 644 "''${target_path}.pub"
      fi

      echo "✓ Restored $key_type key from 1Password: $title"
    }

    # Restore authentication key
    ${optionalString (cfg.authKey.path != null) ''
      restore_key "auth" "${cfg.authKey.path}"
    ''}

    # Restore signing key
    ${optionalString (cfg.signingKey.path != null) ''
      restore_key "signing" "${cfg.signingKey.path}"
    ''}

    echo "✓ 1Password restore completed at $(date)"
    echo ""
    echo "Remember to:"
    echo "  1. Test SSH authentication: ssh -T git@github.com"
    echo "  2. Test git signing: git commit --allow-empty -S -m 'Test'"
    echo "  3. Add keys to ssh-agent: ssh-add ~/.ssh/id_*_ed25519"
  '';

in
{
  config = mkIf (cfg.enable && cfg.sync1Password) {
    # Create helper scripts for 1Password sync
    home.file.".local/bin/ssh-sync-to-1password" = {
      executable = true;
      source = sync1PasswordScript;
    };

    home.file.".local/bin/ssh-sync-from-1password" = {
      executable = true;
      source = syncFrom1PasswordScript;
    };

    # Create a combined bidirectional sync script
    home.file.".local/bin/ssh-sync-1password" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # Bidirectional SSH key sync with 1Password

        set -euo pipefail

        DIRECTION="''${1:-to}"

        case "$DIRECTION" in
          to|push|upload)
            echo "Syncing SSH keys TO 1Password..."
            ~/.local/bin/ssh-sync-to-1password
            ;;
          from|pull|download|restore)
            echo "Syncing SSH keys FROM 1Password..."
            ~/.local/bin/ssh-sync-from-1password
            ;;
          bidirectional|both)
            echo "Performing bidirectional sync..."
            echo "Step 1: Checking for updates from 1Password..."
            # In bidirectional mode, we prefer local keys but check 1Password first
            # This is a safety check - normally you'd use 'to' or 'from' explicitly
            echo "⚠️  Bidirectional sync not yet implemented. Use 'to' or 'from'."
            echo ""
            echo "Usage:"
            echo "  ssh-sync-1password to     # Push local keys to 1Password"
            echo "  ssh-sync-1password from   # Restore keys from 1Password"
            exit 1
            ;;
          *)
            echo "Usage: ssh-sync-1password [to|from]"
            echo ""
            echo "  to      Sync local SSH keys TO 1Password (backup)"
            echo "  from    Sync SSH keys FROM 1Password (restore)"
            exit 1
            ;;
        esac
      '';
    };

    # Optional: Automatic sync after key changes (disabled by default to avoid surprises)
    # Uncomment the following to enable automatic syncing:
    #
    # home.activation.syncKeysTo1Password = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    #   if command -v op >/dev/null 2>&1 && op account list >/dev/null 2>&1; then
    #     echo "Auto-syncing SSH keys to 1Password..."
    #     ${sync1PasswordScript} || echo "⚠️  Auto-sync to 1Password failed (non-fatal)"
    #   fi
    # '';

    # Documentation
    home.file.".ssh/1PASSWORD-SYNC.md" = {
      text = ''
        # 1Password SSH Key Synchronization

        This system maintains bidirectional sync between your SSH keys and 1Password.

        ## Available Commands

        ### Backup Keys to 1Password
        ```bash
        ssh-sync-1password to
        ```
        or
        ```bash
        ssh-sync-to-1password
        ```

        This syncs your local SSH keys to 1Password vault (${cfg.sync1Password} vault).

        ### Restore Keys from 1Password
        ```bash
        ssh-sync-1password from
        ```
        or
        ```bash
        ssh-sync-from-1password
        ```

        This restores SSH keys from 1Password to your local filesystem.
        Use this for emergency recovery if you lose local keys.

        ## Authentication

        Before syncing, ensure you're signed in to 1Password:
        ```bash
        op signin
        # or for persistent session:
        eval $(op signin)
        ```

        ## Key Naming Convention

        Keys are stored in 1Password with the format:
        ```
        {hostname}-{type}-{YYYYMM}
        ```

        Examples:
        - `meh-auth-202604`
        - `meh-signing-202604`
        - `floki-auth-202604`

        ## Recovery Scenario

        If you lose access to your SSH keys but have them backed up in 1Password:

        1. Sign in to 1Password:
           ```bash
           eval $(op signin)
           ```

        2. Restore keys:
           ```bash
           ssh-sync-1password from
           ```

        3. Verify keys work:
           ```bash
           ssh -T git@github.com
           git commit --allow-empty -S -m "Test signing"
           ```

        4. Add keys to ssh-agent:
           ```bash
           ssh-add ~/.ssh/id_auth_ed25519
           ```

        ## Security Note

        - Keys are stored encrypted in 1Password vault
        - Private keys use 1Password's "password" field type (concealed)
        - Always use `op signin` for authentication, never save credentials
        - Sync operations require active 1Password session
      '';
    };
  };
}
