{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ssh-management;
in
{
  config = mkIf (cfg.enable && cfg.signingKey.publicKey != null) {
    # Configure git to use SSH signing
    programs.git = {
      signing = {
        key = cfg.signingKey.publicKey;
        signByDefault = true;
      };

      extraConfig = {
        # Use SSH format for signing
        gpg.format = "ssh";

        # Configure ssh-keygen as the signing program
        "gpg.ssh" = {
          program = "${pkgs.openssh}/bin/ssh-keygen";
          allowedSignersFile = cfg.allowedSignersFile;
        };

        # Commit and tag signing
        commit.gpgsign = true;
        tag.gpgsign = true;
      };
    };

    # Create allowed_signers file for signature verification
    home.file.".ssh/allowed_signers" = {
      text = let
        # Get user email from git config
        userEmail = config.programs.git.userEmail or (
          if config.programs.git.extraConfig ? user.email
          then config.programs.git.extraConfig.user.email
          else "greg@burd.me"
        );
        # Get hostname for comment
        hostname = builtins.getEnv "HOSTNAME" or "unknown";
      in ''
        # SSH allowed signers file for git signature verification
        # Format: email namespaces="git" ssh-key [comment]
        ${userEmail} namespaces="git" ${cfg.signingKey.publicKey} ${hostname}-signing-${builtins.substring 0 6 (builtins.hashString "sha256" cfg.signingKey.publicKey)}
      '';
      onChange = ''
        echo "✓ Git SSH signing configured with key: ${cfg.signingKey.publicKey}"
        echo "  Allowed signers: ${cfg.allowedSignersFile}"
      '';
    };

    # Verify git signing configuration
    home.activation.verifySshSigning = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v git >/dev/null 2>&1; then
        echo "Verifying git SSH signing configuration..."

        # Check if signing key exists
        if [ ! -f "${cfg.signingKey.path}" ]; then
          echo "⚠️  WARNING: Signing key not found at ${cfg.signingKey.path}"
        else
          # Test signature creation (dry-run)
          if ! ${pkgs.openssh}/bin/ssh-keygen -Y check-novalidate -n git -s /dev/null 2>/dev/null; then
            echo "⚠️  WARNING: ssh-keygen signature verification may not work correctly"
          else
            echo "✓ Git SSH signing verification successful"
          fi
        fi
      fi
    '';
  };
}
