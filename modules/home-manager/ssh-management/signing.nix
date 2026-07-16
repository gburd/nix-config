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
        key = mkForce cfg.signingKey.publicKey;
        signByDefault = mkForce true;
      };

      settings = {
        # Use SSH format for signing
        gpg.format = "ssh";

        # Configure ssh-keygen as the signing program
        "gpg.ssh" = {
          program = "${pkgs.openssh}/bin/ssh-keygen";
          inherit (cfg) allowedSignersFile;
        };

        # Commit and tag signing
        commit.gpgsign = true;
        tag.gpgsign = true;
      };
    };

    # Create allowed_signers file for signature verification
    home.file.".ssh/allowed_signers" = {
      text =
        let
          # Get user email from git config
          userEmail = config.programs.git.settings.user.email or "greg@burd.me";
          # Get hostname for comment
          hostname = let h = builtins.getEnv "HOSTNAME"; in if h == "" then "unknown" else h;
        in
        ''
          # SSH allowed signers file for git signature verification
          # Format: email namespaces="git" ssh-key [comment]
          ${userEmail} namespaces="git" ${cfg.signingKey.publicKey} ${hostname}-signing-${builtins.substring 0 6 (builtins.hashString "sha256" cfg.signingKey.publicKey)}
        '';
      onChange = ''
        echo "✓ Git SSH signing configured with key: ${cfg.signingKey.publicKey}"
        echo "  Allowed signers: ${cfg.allowedSignersFile}"
      '';
    };

    # Verify git signing configuration. The old check
    # (`ssh-keygen -Y check-novalidate -s /dev/null`) passed an EMPTY file
    # as the signature to verify -- ssh-keygen correctly rejects that
    # ("missing header"/"incomplete message") every single time,
    # regardless of whether signing actually works. Confirmed: real
    # signing (git commit --allow-empty -S, git log --show-signature) has
    # always worked correctly; this warning was a false positive from a
    # broken self-test, not a real signing problem. Real check: sign a
    # real throwaway payload with the actual key, then verify THAT.
    home.activation.verifySshSigning = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v git >/dev/null 2>&1; then
        echo "Verifying git SSH signing configuration..."

        # Check if signing key exists
        if [ ! -f "${cfg.signingKey.path}" ]; then
          echo "⚠️  WARNING: Signing key not found at ${cfg.signingKey.path}"
        else
          SIGCHECK_TMP=$(mktemp -d)
          echo "signing self-test" > "$SIGCHECK_TMP/payload"
          if ${pkgs.openssh}/bin/ssh-keygen -Y sign -n git -f "${cfg.signingKey.path}" "$SIGCHECK_TMP/payload" >/dev/null 2>&1 \
             && ${pkgs.openssh}/bin/ssh-keygen -Y check-novalidate -n git -s "$SIGCHECK_TMP/payload.sig" < "$SIGCHECK_TMP/payload" >/dev/null 2>&1; then
            echo "✓ Git SSH signing verification successful"
          else
            echo "⚠️  WARNING: ssh-keygen signature verification may not work correctly"
          fi
          find "$SIGCHECK_TMP" -type f -delete
          rmdir "$SIGCHECK_TMP"
        fi
      fi
    '';
  };
}
