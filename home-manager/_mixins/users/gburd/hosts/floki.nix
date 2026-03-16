{ inputs, lib, pkgs, config, ... }:
with lib.hm.gvariant;
{
  imports = [
    # NOTE: impermanence only works with home-manager as NixOS module
    # Not compatible with standalone home-manager switch command
    # inputs.impermanence.nixosModules.home-manager.impermanence
    ../../../console/ai  # Opt-in AI configuration for this host
    ../../../desktop/vorta.nix
    ../../../desktop/sublime.nix
    ../../../desktop/sublime-merge.nix
  ];
  # GNOME Terminal/Console paste warnings cannot be disabled via dconf
  # Use Alacritty instead (already configured) to avoid paste confirmation dialogs
  dconf.settings = { };

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
      unstable.flyctl
      unstable.minio-client
      xclip
    ];

    # http://rski.github.io/2021/09/05/nix-debugging.html
    # https://github.com/nix-community/home-manager/commit/0056a5aea1a7b68bdacb7b829c325a1d4a3c4259
    # Disabled: Conflicts with NixOS-level debug-symbols.nix (both provide /lib/debug/getconf)
    # enableDebugInfo = true;
  };
}
