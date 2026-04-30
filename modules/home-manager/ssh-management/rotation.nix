{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-management;

  # Calculate interval in days based on rotation setting
  intervalDays = {
    "monthly" = 30;
    "quarterly" = 90;
    "biannually" = 180;
    "annually" = 365;
    "never" = 999999;
  };

  rotationIntervalDays = intervalDays.${cfg.rotationInterval};

  # Script to check key age and notify if rotation needed
  keyAgeCheckScript = pkgs.writeShellScript "ssh-key-age-check" ''
    set -euo pipefail

    # Function to calculate key age in days
    key_age_days() {
      local key_path="$1"
      if [ ! -f "$key_path" ]; then
        echo "999999"  # Key doesn't exist, return large number
        return
      fi
      local key_mtime=$(stat -c %Y "$key_path" 2>/dev/null || stat -f %m "$key_path" 2>/dev/null || echo "0")
      local now=$(date +%s)
      echo $(( (now - key_mtime) / 86400 ))
    }

    # Function to send notification
    notify_rotation() {
      local key_type="$1"
      local key_path="$2"
      local age_days="$3"
      local threshold_days="${toString cfg.rotationThresholdDays}"
      local interval_days="${toString rotationIntervalDays}"

      if command -v notify-send >/dev/null 2>&1; then
        notify-send \
          --urgency=normal \
          --app-name="SSH Key Management" \
          "SSH Key Rotation Due" \
          "Your $key_type key is $age_days days old (threshold: $threshold_days days).\n\nRotation recommended every $interval_days days.\n\nRun: ~/ws/nix-config/scripts/ssh-key-rotation/rotate.sh $key_type --dry-run"
      else
        echo "⚠️  SSH Key Rotation Due: $key_type key is $age_days days old" >&2
      fi
    }

    # Check authentication key age
    ${optionalString (cfg.authKey.path != null) ''
      AUTH_AGE=$(key_age_days "${cfg.authKey.path}")
      if [ "$AUTH_AGE" -gt "${toString cfg.rotationThresholdDays}" ]; then
        notify_rotation "authentication" "${cfg.authKey.path}" "$AUTH_AGE"
        echo "Auth key age: $AUTH_AGE days (threshold: ${toString cfg.rotationThresholdDays} days)"
      fi
    ''}

    # Check signing key age
    ${optionalString (cfg.signingKey.path != null) ''
      SIGNING_AGE=$(key_age_days "${cfg.signingKey.path}")
      if [ "$SIGNING_AGE" -gt "${toString cfg.rotationThresholdDays}" ]; then
        notify_rotation "signing" "${cfg.signingKey.path}" "$SIGNING_AGE"
        echo "Signing key age: $SIGNING_AGE days (threshold: ${toString cfg.rotationThresholdDays} days)"
      fi
    ''}

    # Log check completion
    echo "SSH key age check completed at $(date)"
  '';

  # Script to check if rotation scripts are available
  validateRotationScripts = pkgs.writeShellScript "validate-rotation-scripts" ''
    set -euo pipefail

    SCRIPTS_DIR="${cfg.rotationScriptsPath}"

    if [ ! -d "$SCRIPTS_DIR" ]; then
      echo "⚠️  WARNING: Rotation scripts directory not found: $SCRIPTS_DIR"
      exit 1
    fi

    required_scripts=(
      "rotate.sh"
      "validate.sh"
      "generate-keys.sh"
    )

    missing=0
    for script in "''${required_scripts[@]}"; do
      if [ ! -f "$SCRIPTS_DIR/$script" ]; then
        echo "⚠️  Missing script: $script"
        missing=1
      fi
    done

    if [ $missing -eq 1 ]; then
      echo "⚠️  Some rotation scripts are missing. Run: git pull in nix-config"
      exit 1
    fi

    echo "✓ All rotation scripts found"
  '';

in
{
  config = mkIf (cfg.enable && cfg.rotationInterval != "never") {
    # Systemd timer to check key age weekly
    systemd.user.timers.ssh-key-rotation-check = {
      Unit = {
        Description = "Weekly SSH key age check and rotation notification";
      };
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
        Unit = "ssh-key-rotation-check.service";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };

    # Systemd service to perform the key age check
    systemd.user.services.ssh-key-rotation-check = {
      Unit = {
        Description = "SSH key age check and notification";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${keyAgeCheckScript}";
        # Only check if we have keys configured
        ConditionPathExists = mkIf (cfg.authKey.path != null) cfg.authKey.path;
      };
    };

    # Validation service (runs once at login)
    systemd.user.services.ssh-management-validate = {
      Unit = {
        Description = "Validate SSH management configuration";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${validateRotationScripts}";
        # Don't fail if scripts aren't ready yet
        SuccessExitStatus = "0 1";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Create a helper script for manual rotation checks
    home.file.".local/bin/ssh-check-rotation" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # Manual SSH key rotation check
        echo "Checking SSH key ages..."
        ${keyAgeCheckScript}
      '';
    };

    # Documentation file with rotation instructions
    home.file.".ssh/ROTATION.md" = {
      text = ''
        # SSH Key Rotation Instructions

        This system is configured with automatic SSH key age monitoring.

        ## Current Configuration
        - Rotation Interval: ${cfg.rotationInterval} (${toString rotationIntervalDays} days)
        - Notification Threshold: ${toString cfg.rotationThresholdDays} days
        - Authentication Key: ${cfg.authKey.path}
        - Signing Key: ${cfg.signingKey.path}

        ## Manual Rotation

        To manually check if rotation is needed:
        ```bash
        ~/.local/bin/ssh-check-rotation
        ```

        To perform rotation (dry-run first):
        ```bash
        ${cfg.rotationScriptsPath}/rotate.sh auth --dry-run
        ${cfg.rotationScriptsPath}/rotate.sh signing --dry-run
        ```

        To execute rotation:
        ```bash
        ${cfg.rotationScriptsPath}/rotate.sh auth
        ${cfg.rotationScriptsPath}/rotate.sh signing
        ```

        ## Automatic Checks

        The system automatically checks key age weekly via systemd timer:
        - Timer: `systemctl --user status ssh-key-rotation-check.timer`
        - Service: `systemctl --user status ssh-key-rotation-check.service`

        You will receive desktop notifications when keys need rotation.

        ## Emergency Rotation

        If a key is compromised:
        ```bash
        ${cfg.rotationScriptsPath}/rotate.sh [auth|signing] --force --emergency
        ```

        This will:
        1. Generate new keys immediately
        2. Update git hosting services (GitHub, Codeberg, etc.)
        3. Revoke old keys
        4. Sync to 1Password
        5. Update nix-config repository

        ## Rollback

        If rotation fails, rollback using git:
        ```bash
        cd ~/ws/nix-config
        git log --oneline | grep -i rotation
        git revert <commit-sha>
        home-manager switch
        ```
      '';
    };
  };
}
