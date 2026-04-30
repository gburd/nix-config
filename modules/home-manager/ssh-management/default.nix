{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-management;
in
{
  options.services.ssh-management = {
    enable = mkEnableOption "SSH key management with rotation support";

    authKey = {
      secret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to sops secret for authentication private key";
      };

      publicKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public key content for authentication";
      };

      path = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.ssh/id_auth_ed25519";
        description = "Path where the authentication key will be deployed";
      };
    };

    signingKey = {
      secret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to sops secret for signing private key";
      };

      publicKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public key content for signing";
      };

      path = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.ssh/id_signing_ed25519";
        description = "Path where the signing key will be deployed";
      };
    };

    rotationInterval = mkOption {
      type = types.enum [ "monthly" "quarterly" "biannually" "annually" "never" ];
      default = "quarterly";
      description = "How often to check for key rotation (90 days for quarterly)";
    };

    rotationThresholdDays = mkOption {
      type = types.int;
      default = 80;
      description = "Notify when keys are older than this many days (should be less than rotation interval)";
    };

    sync1Password = mkOption {
      type = types.bool;
      default = true;
      description = "Enable bidirectional sync with 1Password vault";
    };

    gitHostingServices = mkOption {
      type = types.listOf (types.enum [ "github" "codeberg" "custom" ]);
      default = [ "github" ];
      description = "Git hosting services to update during rotation";
    };

    allowedSignersFile = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.ssh/allowed_signers";
      description = "Path to SSH allowed_signers file for git signature verification";
    };

    rotationScriptsPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/ws/nix-config/scripts/ssh-key-rotation";
      description = "Path to rotation scripts directory";
    };
  };

  config = mkIf cfg.enable {
    # Import submodules
    imports = [
      ./keys.nix
      ./signing.nix
      ./rotation.nix
      ./sync.nix
    ];

    # Ensure SSH directory exists with correct permissions
    home.file.".ssh/.keep" = {
      text = "";
      onChange = ''
        chmod 700 ${config.home.homeDirectory}/.ssh
      '';
    };

    # Use standard ssh-agent instead of 1Password
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";

      # Remove any 1Password agent references
      extraConfig = ''
        # Standard ssh-agent configuration
        # Keys managed by ssh-management module
      '';
    };

    # Configure ssh-agent service
    services.ssh-agent = {
      enable = true;
    };

    # Warn if SSH_AUTH_SOCK points to 1Password
    home.activation.checkSshAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ "''${SSH_AUTH_SOCK:-}" == *"1password"* ]]; then
        echo "⚠️  WARNING: SSH_AUTH_SOCK points to 1Password agent"
        echo "   Remove SSH_AUTH_SOCK override from your configuration"
        echo "   Current value: $SSH_AUTH_SOCK"
      fi
    '';
  };
}
