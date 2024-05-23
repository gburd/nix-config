{ lib, pkgs, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../desktop/vorta.nix
  ];
  dconf.settings = { };

  home = {
    persistence = {
      "/persist/home/gburd" = {
        directories = [
          "Documents"
          "Downloads"
          "Pictures"
          "Videos"
          ".local/bin"
          ".config"
        ];
        allowOther = true;
      };
    };

    file.".inputrc".text = ''
      "\C-v": ""
      set enable-bracketed-paste off
    '';

    file.".config/direnv/direnv.toml".text = ''
      [global]
      load_dotenv = true
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

    # file.".config/sublime-text-2/Local/License.sublime_license".text =
    #   config.sops.secrets.sublime-licenses.text.path;

    # file.".config/sublime-merge/Local/License.sublime_license".text =
    #   config.sops.secrets.sublime-licenses.merge.path;

    packages = with pkgs; [
      _1password
      _1password-gui
      cfssl
      gnumake
      cmake
      autoconf
      libtool
      m4
      perl
      pkg-config
      python3
      gcc
      gdb
      dig
      emacs
      file
      git-credential-1password
      htop
      openssl
      plocate
      ripgrep
      tig
      tree
      lsof
      unstable.flyctl
      unstable.minio-client
      unstable.element-desktop
      erlang
      rebar3
      elixir
    ];

    # http://rski.github.io/2021/09/05/nix-debugging.html
    # https://github.com/nix-community/home-manager/commit/0056a5aea1a7b68bdacb7b829c325a1d4a3c4259
    enableDebugInfo = true;
  };
}
