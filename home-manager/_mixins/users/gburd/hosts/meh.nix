{ inputs, lib, pkgs, config, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../console/ai # Opt-in AI configuration for this host
    ../../../desktop/vorta.nix
    ../../../desktop/sublime.nix
    ../../../desktop/sublime-merge.nix
    # Email and productivity services
    ../../../services/protonmail-bridge.nix
    ../../../services/vdirsyncer.nix
    ../../../services/proton-drive.nix
    ../../../console/khal.nix
    ../../../console/taskbook.nix
    # SSH key management with rotation
    ../../../../modules/home-manager/ssh-management
  ];

  # GNOME configuration
  dconf.settings = {
    # Disable paste warnings in GNOME Console
    "org/gnome/Console" = {
      unsafe-paste-warning = false;
    };

    # Fix Alt-Tab window switching
    "org/gnome/desktop/wm/keybindings" = {
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
      # Alternative app switcher (if using grouped mode)
      switch-applications = [ ];
      switch-applications-backward = [ ];
    };

    # Disable idle timeout on meh (desktop - never sleep)
    "org/gnome/desktop/session" = {
      idle-delay = mkUint32 0;  # Never go idle (overrides gnome.nix default)
    };
  };

  # Sops secrets configuration
  sops = {
    # Use flake root to reference secrets file cleanly
    defaultSopsFile = "${inputs.self}/nixos/workstation/meh/secrets.yaml";
    # Use age key derived from SSH key for decryption
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secrets = {
      "aws/bearer_token_bedrock" = {
        path = "${config.home.homeDirectory}/.config/claude-code/.bearer_token";
      };
      "jetbrains/clion-key" = {
        path = "${config.home.homeDirectory}/.config/JetBrains/clion.key";
      };
      "sublime/merge-license" = {
        path = "${config.home.homeDirectory}/.config/sublime-merge-license.bin";
      };

      # SSH key management (new)
      "ssh-keys/auth" = {
        path = "${config.home.homeDirectory}/.ssh/id_auth_ed25519";
      };
      "ssh-keys/signing" = {
        path = "${config.home.homeDirectory}/.ssh/id_signing_ed25519";
      };

      # Email account credentials (nested structure)
      "email/proton/user" = { };
      "email/proton/pass" = { };
      "email/google/personal/user" = { };
      "email/google/personal/pass" = { };
      "email/google/pgus/user" = { };
      "email/google/pgus/pass" = { };
      "email/fastmail/user" = { };
      "email/fastmail/pass" = { };
      "email/apple/icloud/user" = { };
      "email/apple/icloud/pass" = { };
      "email/ms/outlook/user" = { };
      "email/ms/outlook/pass" = { };
      "email/amazon/user" = { };
      "email/amazon/pass" = { };

      # Calendar credentials (nested structure)
      "calendar/google/personal/client-id" = { };
      "calendar/google/personal/secret" = { };
      "calendar/google/pgus/client-id" = { };
      "calendar/google/pgus/secret" = { };
      "calendar/apple/icloud/user" = { };
      "calendar/apple/icloud/pass" = { };
      "calendar/ms/outlook/user" = { };
      "calendar/ms/outlook/pass" = { };

      # Proton Drive credentials (nested structure)
      "drive/proton/user" = { };
      "drive/proton/pass" = { };
    };
  };

  # Activation script to link CLion license to all version directories
  home.activation.linkClionLicense = lib.mkIf (config.sops.secrets ? "jetbrains/clion-key") (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CLION_LICENSE="${config.sops.secrets."jetbrains/clion-key".path}"

      if [ -f "$CLION_LICENSE" ]; then
        # Find all CLion version directories and create symlinks
        for clion_dir in ${config.home.homeDirectory}/.config/JetBrains/CLion*; do
          if [ -d "$clion_dir" ]; then
            TARGET="$clion_dir/clion.key"
            # Remove existing file/symlink if it exists
            if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
              rm -f "$TARGET"
            fi
            # Create symlink
            ln -sf "$CLION_LICENSE" "$TARGET"
            echo "Linked CLion license to $TARGET"
          fi
        done
      else
        echo "Warning: CLion license not found at $CLION_LICENSE"
      fi
    ''
  );

  # Activation script to link Sublime Merge license
  home.activation.linkSublimeMergeLicense = lib.mkIf (config.sops.secrets ? "sublime/merge-license") (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      MERGE_LICENSE="${config.sops.secrets."sublime/merge-license".path}"
      MERGE_TARGET="${config.home.homeDirectory}/.config/sublime-merge/Local/License.sublime_license"

      if [ -f "$MERGE_LICENSE" ]; then
        # Create Local directory if it doesn't exist
        mkdir -p "$(dirname "$MERGE_TARGET")"
        # Remove existing file/symlink if it exists
        if [ -e "$MERGE_TARGET" ] || [ -L "$MERGE_TARGET" ]; then
          rm -f "$MERGE_TARGET"
        fi
        # Create symlink
        ln -sf "$MERGE_LICENSE" "$MERGE_TARGET"
        echo "Linked Sublime Merge license to $MERGE_TARGET"
      else
        echo "Warning: Sublime Merge license not found at $MERGE_LICENSE"
      fi
    ''
  );

  # SSH key management with rotation support (replaces 1Password SSH agent)
  services.ssh-management = {
    enable = true;

    authKey = {
      secret = config.sops.secrets."ssh-keys/auth".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIH57HkgLJYRhgkZGBs+/LBmiBrZtIr08INS2zQkEJoS greg@burd.me-auth-meh-202604";
    };

    signingKey = {
      secret = config.sops.secrets."ssh-keys/signing".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuaVJD7BbkXTN0dYCT6HURZZ8kGS/WbmS+nd+B8KtMY greg@burd.me-signing-meh-202604";
    };

    rotationInterval = "quarterly";
    sync1Password = true;
    gitHostingServices = [ "github" "codeberg" ];
  };

  home = {
    file.".inputrc".text = ''
      "\C-v": ""
      set enable-bracketed-paste off
    '';

    file.".config/direnv/direnv.toml".text = ''
      [global]
      load_dotenv = true
    '';

    file.".envrc".text = ''
      ENVFS_RESOLVE_ALWAYS=1
    '';

    file.".config/Code/User/settings.json".text = ''
      {
          "editor.inlineSuggest.enabled": true,
          "editor.fontFamily": "'FiraCode Nerd Font Mono', 'Droid Sans Mono', 'monospace', monospace",
          "editor.fontLigatures": true,
          "cSpell.userWords": [
              "Burd",
              "Wpedantic",
              "Wvariadic"
          ],
          "files.watcherExclude": {
              "**/.bloop": true,
              "**/.metals": true,
              "**/.ammonite": true
          },
          "extensions.experimental.affinity": {
              "asvetliakov.vscode-neovim": 1
          },
          "vscode-neovim.neovimExecutablePaths.linux": "/home/gburd/.nix-profile/bin/nvim",
      }
    '';

    packages = with pkgs; [
      _1password-cli
      _1password-gui
      autoconf
      bash
      cfssl
      cmake
      dig
      elixir
      emacs
      erlang
      file
      htop
      libtool
      lsof
      luajitPackages.luarocks
      m4
      openssl
      perl
      plocate
      python3
      rebar3
      tree-sitter
      unstable.element-desktop
      unstable.flyctl
      unstable.minio-client
      xclip
    ];
  };
}
