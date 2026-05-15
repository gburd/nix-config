{ inputs, lib, pkgs, config, ... }:
with lib.hm.gvariant;
{
  imports = [
    # NOTE: impermanence only works with home-manager as NixOS module
    # Not compatible with standalone home-manager switch command
    # inputs.impermanence.nixosModules.home-manager.impermanence
    ../../../console/ai # Opt-in AI configuration for this host
    ../../../desktop/vorta.nix
    ../../../services/borgmatic.nix
    ../../../desktop/sublime.nix
    ../../../desktop/sublime-merge.nix
    # Email and productivity services
    ../../../services/protonmail-bridge.nix
    ../../../services/vdirsyncer.nix
    ../../../services/proton-drive.nix
    ../../../console/khal.nix
    ../../../console/taskbook.nix
    # SSH key management with rotation
    (inputs.self + "/modules/home-manager/ssh-management")
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

    # Power management: Performance profile on AC, never auto-suspend
    "org/gnome/settings-daemon/plugins/power" = {
      power-profile-on-ac = "performance";      # max performance when plugged in
      power-profile-on-battery = "power-saver"; # conservative when on battery
      sleep-inactive-ac-type = "nothing";       # don't suspend on AC when idle
      sleep-inactive-ac-timeout = 0;            # 0 = never
    };
  };

  # Sops secrets configuration
  sops = {
    # Use flake root to reference secrets file cleanly
    defaultSopsFile = "${inputs.self}/nixos/workstation/floki/secrets.yaml";
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

      # Borg backup passphrase and SSH key (used by borgmatic)
      "backup/borg-passphrase" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.passphrase";
      };
      "backup/rsync-ssh-key" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.rsync-key";
        mode = "0600";
      };
      "backup/borg-keyfile" = {
        path = "${config.home.homeDirectory}/.config/borg/keys/zh6216_rsync_net__borg";
        mode = "0600";
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

  # SSH key management with rotation support (replaces GPG signing with SSH)
  services.ssh-management = {
    enable = true;

    authKey = {
      secret = config.sops.secrets."ssh-keys/auth".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6HS8oDnpvGKTisMx38pq1I3YJP4+ds7WIYF+L578dW greg@burd.me-auth-floki-202604";
    };

    signingKey = {
      secret = config.sops.secrets."ssh-keys/signing".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ31SSVgFMDHNic/+zA41muVDVIuPVaUOnKIXJ31PyTb greg@burd.me-signing-floki-202604";
    };

    rotationInterval = "quarterly";
    sync1Password = true;
    gitHostingServices = [ "github" "codeberg" ];
  };

  home = {
    # NOTE: persistence disabled for standalone home-manager
    # Enable in NixOS configuration if using home-manager as NixOS module
    # persistence = {
    #   "/persist/home/gburd" = {
    #     directories = [
    #       "Documents"
    #       "Downloads"
    #       "Pictures"
    #       "Videos"
    #       ".local/bin"
    #       ".config"
    #     ];
    #     allowOther = true;
    #   };
    # };

    file.".inputrc".text = ''
      "\C-v": ""
      set enable-bracketed-paste off
    '';

    # Pan NNTP newsreader: pre-configure postgr.esq (PostgreSQL mailing lists)
    file.".pan2/servers.xml".text = ''
      <?xml version="1.0" encoding="utf-8" ?>
      <server-properties>
        <server>
          <host>mail.postgr.esq</host>
          <port>563</port>
          <use-ssl>1</use-ssl>
          <connection-limit>2</connection-limit>
          <rank>1</rank>
        </server>
      </server-properties>
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

    # file.".config/Code/User/keybindings.json".text = ''
    #   // Place your key bindings in this file to override the defaults
    #   [
    #   ]
    # '';


    packages = with pkgs; [
      # TODO: Move some of these into ../../../desktop/<app>.nix files
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
      # gcc  # Removed: conflicts with gcc14 from console/default.nix
      # gdb  # Removed: provided by console/gdb
      # gnumake  # Removed: provided by console/default.nix
      htop
      libtool
      lsof
      luajitPackages.luarocks
      m4
      openssl
      perl
      # pkg-config  # Removed: provided by console/default.nix
      plocate
      python3
      rebar3
      # ripgrep  # Removed: provided by console/default.nix
      # tig  # Removed: provided by cli mixin
      # tree  # Removed: provided by cli mixin
      tree-sitter
      unstable.element-desktop
      unstable.minio-client
      xclip

      # AI tools
      kiro-cli      # Kiro CLI agent for the terminal
      # kiro-ide    # Kiro IDE (download URLs return 404 — not yet publicly available)
      bitnet        # BitNet b1.58 2B-4T 1-bit LLM inference (CPU-optimized)
      lmstudio      # Local LLM runner (LM Studio)
      maki          # AI coding agent from gburd/maki
      terax-ai      # AI assistant UI (Bedrock support pending upstream issue #138)

      # PostgreSQL community
      pan           # GTK NNTP newsreader (postgr.esq PostgreSQL mailing lists)
    ];

    # http://rski.github.io/2021/09/05/nix-debugging.html
    # https://github.com/nix-community/home-manager/commit/0056a5aea1a7b68bdacb7b829c325a1d4a3c4259
    # Disabled: Conflicts with NixOS-level debug-symbols.nix (both provide /lib/debug/getconf)
    # enableDebugInfo = true;
  };
}
