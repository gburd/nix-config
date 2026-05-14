{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-management;
in
{
  config = mkIf cfg.enable {
    # Public keys are managed via home.file (text content)
    home.file = mkMerge [
      (mkIf (cfg.authKey.publicKey != null) {
        ".ssh/id_auth_ed25519.pub" = {
          text = cfg.authKey.publicKey;
        };
      })

      (mkIf (cfg.signingKey.publicKey != null) {
        ".ssh/id_signing_ed25519.pub" = {
          text = cfg.signingKey.publicKey;
        };
      })

      # Create metadata file with key information
      (mkIf (cfg.authKey.publicKey != null || cfg.signingKey.publicKey != null) {
        ".ssh/key-metadata.json" = {
          text = builtins.toJSON {
            hostname = config.home.username + "@" + (let h = builtins.getEnv "HOSTNAME"; in if h == "" then "unknown" else h);
            rotation_interval = cfg.rotationInterval;
            last_check = "managed-by-systemd-timer";
            auth_key = {
              inherit (cfg.authKey) path;
              fingerprint = "calculated-at-runtime";
              deployed = "managed-by-home-manager";
            };
            signing_key = {
              inherit (cfg.signingKey) path;
              fingerprint = "calculated-at-runtime";
              deployed = "managed-by-home-manager";
            };
          };
        };
      })
    ];

    # Activation script to handle private key permissions and ssh-agent
    home.activation.setupSshKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${optionalString (cfg.authKey.secret != null && cfg.authKey.publicKey != null) ''
        # Authentication key setup
        if [ -f "${cfg.authKey.secret}" ]; then
          # Sops has already placed the private key, ensure correct permissions
          chmod 600 "${cfg.authKey.secret}" 2>/dev/null || true

          # Add to ssh-agent if running
          if [ -n "''${SSH_AUTH_SOCK:-}" ] && command -v ssh-add >/dev/null 2>&1; then
            ${pkgs.openssh}/bin/ssh-add "${cfg.authKey.secret}" 2>/dev/null || true
          fi

          echo "✓ Authentication key configured at ${cfg.authKey.secret}"
        else
          echo "⚠️  WARNING: Authentication key not found at ${cfg.authKey.secret}"
        fi
      ''}

      ${optionalString (cfg.signingKey.secret != null && cfg.signingKey.publicKey != null) ''
        # Signing key setup
        if [ -f "${cfg.signingKey.secret}" ]; then
          # Sops has already placed the private key, ensure correct permissions
          chmod 600 "${cfg.signingKey.secret}" 2>/dev/null || true

          echo "✓ Signing key configured at ${cfg.signingKey.secret}"
        else
          echo "⚠️  WARNING: Signing key not found at ${cfg.signingKey.secret}"
        fi
      ''}
    '';

    # SSH config to use the auth key
    programs.ssh.matchBlocks = mkIf (cfg.authKey.publicKey != null) {
      "*" = {
        identityFile = [ cfg.authKey.path ];
      };

      # Specific configurations for git hosting services
      "github.com" = mkIf (builtins.elem "github" cfg.gitHostingServices) {
        hostname = "github.com";
        user = "git";
        identityFile = [ cfg.authKey.path ];
      };

      "codeberg.org" = mkIf (builtins.elem "codeberg" cfg.gitHostingServices) {
        hostname = "codeberg.org";
        user = "git";
        identityFile = [ cfg.authKey.path ];
      };
    };
  };
}
