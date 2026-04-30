{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-management;
in
{
  config = mkIf cfg.enable {
    # Deploy authentication key from sops
    home.file = mkMerge [
      (mkIf (cfg.authKey.secret != null && cfg.authKey.publicKey != null) {
        ".ssh/id_auth_ed25519" = {
          source = cfg.authKey.secret;
          onChange = ''
            chmod 600 ${cfg.authKey.path}
            # Ensure public key is also present
            if [ ! -f "${cfg.authKey.path}.pub" ]; then
              echo "${cfg.authKey.publicKey}" > "${cfg.authKey.path}.pub"
              chmod 644 "${cfg.authKey.path}.pub"
            fi
            # Add to ssh-agent if running
            if [ -n "''${SSH_AUTH_SOCK:-}" ] && command -v ssh-add >/dev/null 2>&1; then
              ${pkgs.openssh}/bin/ssh-add "${cfg.authKey.path}" 2>/dev/null || true
            fi
            echo "✓ Authentication key deployed to ${cfg.authKey.path}"
          '';
        };

        ".ssh/id_auth_ed25519.pub" = {
          text = cfg.authKey.publicKey;
        };
      })

      (mkIf (cfg.signingKey.secret != null && cfg.signingKey.publicKey != null) {
        ".ssh/id_signing_ed25519" = {
          source = cfg.signingKey.secret;
          onChange = ''
            chmod 600 ${cfg.signingKey.path}
            # Ensure public key is also present
            if [ ! -f "${cfg.signingKey.path}.pub" ]; then
              echo "${cfg.signingKey.publicKey}" > "${cfg.signingKey.path}.pub"
              chmod 644 "${cfg.signingKey.path}.pub"
            fi
            echo "✓ Signing key deployed to ${cfg.signingKey.path}"
          '';
        };

        ".ssh/id_signing_ed25519.pub" = {
          text = cfg.signingKey.publicKey;
        };
      })
    ];

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

    # Create metadata file with key information
    home.file.".ssh/key-metadata.json" = mkIf (cfg.authKey.publicKey != null || cfg.signingKey.publicKey != null) {
      text = builtins.toJSON {
        hostname = config.home.username + "@" + (builtins.getEnv "HOSTNAME" or "unknown");
        rotation_interval = cfg.rotationInterval;
        last_check = "managed-by-systemd-timer";
        auth_key = {
          path = cfg.authKey.path;
          fingerprint = "calculated-at-runtime";
          deployed = "managed-by-home-manager";
        };
        signing_key = {
          path = cfg.signingKey.path;
          fingerprint = "calculated-at-runtime";
          deployed = "managed-by-home-manager";
        };
      };
    };
  };
}
