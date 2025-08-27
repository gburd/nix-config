{ inputs, config, pkgs, username, ... }: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    ../../pass
    ../../cli
    ../../nvim
  ];

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

    file.".face".source = ./face.png;

    file.".ssh/config".text = ''
      Host burd.me *.burd.me *.ts.burd.me
      ForwardAgent yes
      Host floki
        ForwardAgent yes
        RemoteForward /%d/.gnupg-sockets/S.gpg-agent /%d/.gnupg-sockets/S.gpg-agent.extra

      Host *
        ForwardAgent no
        Compression no
        ServerAliveInterval 0
        ServerAliveCountMax 3
        HashKnownHosts no
        UserKnownHostsFile ~/.ssh/known_hosts
        ControlMaster no
        ControlPath ~/.ssh/master-%r@%n:%p
        ControlPersist no

      Host github.com
        HostName github.com
        User git
    '';

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

    file.".config/alacritty/alacritty.yml".source = ./alacritty.yml;

    file.".config/Code/User/keybindings.json".text = ''
    '';

    file.".config/nvim/init.nvim".source = ./init.nvim;

    # file.".config/sublime-text-2/Local/License.sublime_license".text =
    #   config.sops.secrets.sublime-licenses.text.path;

    # file.".config/sublime-merge/Local/License.sublime_license".text =
    #   config.sops.secrets.sublime-licenses.merge.path;

    # A Modern Unix experience, for the "kids"
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages = with pkgs; [
      asciinema # Terminal recorder
      chafa # Terminal image viewer
      chroma # Code syntax highlighter
      clinfo # Terminal OpenCL info
      dconf2nix # Nix code from Dconf files
      httpie # Terminal HTTP client
      iw # Terminal WiFi info
      nixpkgs-review # Nix code review
      ripgrep # Modern Unix `grep`
      shellcheck # Code lint Shell

      _1password-cli
      _1password-gui
      cfssl
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
    ];
    sessionVariables = {
      PAGER = "less";
    };

    # http://rski.github.io/2021/09/05/nix-debugging.html
    # https://github.com/nix-community/home-manager/commit/0056a5aea1a7b68bdacb7b829c325a1d4a3c4259
    enableDebugInfo = true;
  };

  programs = { };

  systemd.user.tmpfiles.rules = [
    "d ${config.home.homeDirectory}/ws 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/bin 0755 ${username} users - -"
  ];

}
