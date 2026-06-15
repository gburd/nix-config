{ inputs, pkgs, config, ... }:
# meh is a headless terminal-only host (no X / Wayland / GNOME); kept here
# for productivity CLIs, services, and AI tooling. GPU compute support for
# Ollama / llama.cpp / OpenCL is preserved by
# nixos/_mixins/hardware/gpu-compute.nix imported from the NixOS host.
{
  imports = [
    ../../../console/ai # Opt-in AI configuration for this host
    ../../../services/borgmatic.nix
    # Email and productivity services (CLI / daemon)
    ../../../services/protonmail-bridge.nix
    ../../../services/vdirsyncer.nix
    ../../../services/proton-drive.nix
    ../../../console/khal.nix
    ../../../console/taskbook.nix
    # SSH key management with rotation
    (inputs.self + "/modules/home-manager/ssh-management")
  ];

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
      # Crates.io API token (exposed as $CARGO_REGISTRY_TOKEN by console/cargo.nix)
      "cargo/crates_io_token" = { };

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
  # (CLion is a GUI app; meh is headless, so this is intentionally a no-op:
  # the sops secret is no longer declared on this host.)

  # Activation script to link Sublime Merge license
  # (Sublime Merge is a GUI app; meh is headless, so this is intentionally
  # a no-op: the sops secret is no longer declared on this host.)

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
      bitnet # BitNet b1.58 2B-4T 1-bit LLM inference (CPU-optimized)
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
      unstable.minio-client
      xclip
    ];
  };
}
