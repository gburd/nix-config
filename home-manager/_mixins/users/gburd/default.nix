{ inputs, config, pkgs, username, ... }: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    ../../cli
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

    file."Quickemu/nixos-console.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-console/disk.qcow2"
      disk_size="96G"
      iso="nixos-console/nixos.iso"
    '';
    file."Quickemu/nixos-desktop.conf".text = ''
      #!/run/current-system/sw/bin/quickemu --vm
      guest_os="linux"
      disk_img="nixos-desktop/disk.qcow2"
      disk_size="96G"
      iso="nixos-desktop/nixos.iso"
    '';

    file.".inputrc".text = ''
      "\C-v": ""
      set enable-bracketed-paste off
    '';

    file.".config/direnv/direnv.toml".text = ''
      [global]
      load_dotenv = true
    '';

    file.".gitconfig".text = ''
      [user]
        name = Greg Burd
        email = greg@burd.me

      [color]
        ui = auto
        diff = auto
        status = auto
        branch = auto

      [alias]
        st = status --short
        ci = commit
        co = checkout
        di = diff
        dc = diff --cached
        amend = commit --amend
        aa = add --all
        head = !git l -1
        h = !git head
        r = !git --no-pager l -20
        ra = !git r --all
        ff = merge --ff-only
        pullff = pull --ff-only
        l = log --graph --abbrev-commit --date=relative
        la = !git l --all
        div = divergence
        gn = goodness
        gnc = goodness --cached
        fa = fetch --all
        pom = push origin master
        files = show --oneline
        graph = log --graph --decorate --all
        lol = log --graph --decorate --pretty=oneline --abbrev-commit
        lola = log --graph --decorate --pretty=oneline --abbrev-commit --all
        lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative
        sync = pull --rebase
        update = merge --ff-only origin/master
        mend = commit --amend --no-edit
        unadd = reset --
        unedit = checkout --
        unstage = reset HEAD
        unrm = checkout --
        unstash = stash pop
        lastchange = log -n 1 -p
          dag = log --graph --format='format:%C(yellow)%h%C(reset) %C(blue)\"%an\" <%ae>%C(reset) %C(magenta)%cr%C(reset)%C(auto)%d%C(reset)%n%s' --date-order
          subdate = submodule update --init --recursive

      [format]
        pretty=format:%C(yellow)%h%Creset | %C(green)%ad (%ar)%Creset | %C(blue)%an%Creset | %s

      [push]
        default = simple
        autoSetupRemote = true

      [branch]
        autosetuprebase = always

      [receive]
        denyCurrentBranch = warn

      [filter "media"]
        clean = git media clean %f
        smudge = git media smudge %f
        required = true

      # http://nicercode.github.io/blog/2013-04-30-excel-and-line-endings/
      [filter "cr"]
            clean = LC_CTYPE=C awk '{printf(\"%s\\n\", $0)}' | LC_CTYPE=C tr '\\r' '\\n'
            smudge = tr '\\n' '\\r'

      [diff]
          tool = meld
      [difftool]
          prompt = false
      [difftool "meld"]
          cmd = meld "$LOCAL" "$REMOTE"

      [merge]
          tool = meld
      [mergetool "meld"]
          # Choose one of these 2 lines (not both!) explained below.
          cmd = meld "$LOCAL" "$MERGED" "$REMOTE" --output "$MERGED"
          cmd = meld "$LOCAL" "$BASE" "$REMOTE" --output "$MERGED"

      [core]
          editor = nvim
      #    editor = emacs -nw -q
          excludesfile = ~/.gitignore_global
          pager = less -FMRiX
          quotepath = false

      [filter "lfs"]
        process = git-lfs filter-process
        required = true
        clean = git-lfs clean -- %f
        smudge = git-lfs smudge -- %f

      [init]
        templateDir = /home/gregburd/.git-template
        defaultBranch = main
      [commit]
      #	gpgsign = true
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

    file.".config/Code/User/keybindings.json".text = ''
      // Place your key bindings in this file to override the defaults
      [
        // allow arrow keys to work in the find widget
        {
          "key": "right",
          "command": "-emacs-mcx.isearchExit"
        },
        {
          "key": "left",
          "command": "-emacs-mcx.isearchExit"
        },
        {
          "key": "up",
          "command": "-emacs-mcx.isearchExit"
        },
        {
          "key": "down",
          "command": "-emacs-mcx.isearchExit"
        },
        // allow ctrl+f to find next in the find widget
        {
          "key": "ctrl+f",
          "command": "-emacs-mcx.isearchExit",
          "when": "editorFocus && findWidgetVisible"
        },
        // allow other stuff to functional normally in the find widget
        {
          "key": "ctrl+b",
          "command": "-emacs-mcx.isearchExit",
          "when": "editorFocus && findWidgetVisible"
        },
        {
          "key": "ctrl+p",
          "command": "-emacs-mcx.isearchExit",
          "when": "editorFocus && findWidgetVisible"
        },
        {
          "key": "ctrl+n",
          "command": "-emacs-mcx.isearchExit",
          "when": "editorFocus && findWidgetVisible"
        },
        {
          "key": "ctrl+a",
          "command": "-emacs-mcx.isearchExit",
          "when": "editorFocus && findWidgetVisible"
        },
        {
          "key": "ctrl+e",
          "command": "-emacs-mcx.isearchExit",
          "when": "editorFocus && findWidgetVisible"
        },
        {
          "key": "enter",
          "command": "-emacs-mcx.isearchExit"
        },
        // allow curly quotes and ellipses characters on mac
        {
          "key": "alt+shift+[",
          "command": "-emacs-mcx.backwardParagraph"
        },
        {
          "key": "alt+shift+]",
          "command": "-emacs-mcx.forwardParagraph"
        },
        {
          "key": "alt+;",
          "command": "-editor.action.blockComment",
          "when": "editorTextFocus && !config.emacs-mcx.useMetaPrefixMacCmd && !editorReadonly"
        },
        {
          "key": "alt+;",
          "command": "-emacs-mcx.executeCommands",
          "when": "editorFocus && findWidgetVisible && !config.emacs-mcx.useMetaPrefixMacCmd"
        },
        // stop backward kill word from adding to clipboard
        {
          "key": "alt+backspace",
          "command": "-emacs-mcx.backwardKillWord",
          "when": "editorTextFocus && !config.emacs-mcx.useMetaPrefixMacCmd && !editorReadonly"
        }
      ]
    '';

    file.".config/nvim/init.nvim".source = ./init.nvim;

    # file.".config/sublime-text-2/Local/License.sublime_license".text =
    #   config.sops.secrets.sublime-licenses.text.path;

    # file.".config/sublime-merge/Local/License.sublime_license".text =
    #   config.sops.secrets.sublime-licenses.merge.path;

    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages = with pkgs; [
      asciinema # Terminal recorder
      black # Code format Python
      bmon # Modern Unix `iftop`
      breezy # Terminal bzr client
      butler # Terminal Itch.io API client
      chafa # Terminal image viewer
      chroma # Code syntax highlighter
      clinfo # Terminal OpenCL info
      curlie # Terminal HTTP client
      dconf2nix # Nix code from Dconf files
      debootstrap # Terminal Debian installer
      diffr # Modern Unix `diff`
      difftastic # Modern Unix `diff`
      dogdns # Modern Unix `dig`
      dua # Modern Unix `du`
      duf # Modern Unix `df`
      du-dust # Modern Unix `du`
      entr # Modern Unix `watch`
      fast-cli # Terminal fast.com
      fd # Modern Unix `find`
      glow # Terminal Markdown renderer
      gping # Modern Unix `ping`
      hexyl # Modern Unix `hexedit`
      httpie # Terminal HTTP client
      hyperfine # Terminal benchmarking
      iperf3 # Terminal network benchmarking
      iw # Terminal WiFi info
      jpegoptim # Terminal JPEG optimizer
      jiq # Modern Unix `jq`
      lazygit # Terminal Git client
      libva-utils # Terminal VAAPI info
      lurk # Modern Unix `strace`
      mdp # Terminal Markdown presenter
      #moar # Modern Unix `less`
      mtr # Modern Unix `traceroute`
      netdiscover # Modern Unix `arp`
      nethogs # Modern Unix `iftop`
      nixpkgs-review # Nix code review
      nodePackages.prettier # Code format
      nurl # Nix URL fetcher
      nyancat # Terminal rainbow spewing feline
      speedtest-go # Terminal speedtest.net
      optipng # Terminal PNG optimizer
      procs # Modern Unix `ps`
      python310Packages.gpustat # Terminal GPU info
      quilt # Terminal patch manager
      ripgrep # Modern Unix `grep`
      rustfmt # Code format Rust
      shellcheck # Code lint Shell
      shfmt # Code format Shell
      tldr # Modern Unix `man`
      tokei # Modern Unix `wc` for code
      vdpauinfo # Terminal VDPAU info
      wavemon # Terminal WiFi monitor
      yq-go # Terminal `jq` for YAML

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
    sessionVariables = {
      #      PAGER = "moar";
    };

    # http://rski.github.io/2021/09/05/nix-debugging.html
    # https://github.com/nix-community/home-manager/commit/0056a5aea1a7b68bdacb7b829c325a1d4a3c4259
    enableDebugInfo = true;
  };
  programs = {
    bash = {
      shellAliases = {
        pubip = "curl -s ifconfig.me/ip"; # "curl -s https://api.ipify.org";
        speedtest = "speedtest-go";
        vi = "nvim";
        vim = "nvim";
      };
    };
    fish = {
      shellAliases = {
        #diff = "diffr";
        #fast = "fast -u";
        #glow = "glow --pager";
        pubip = "curl -s ifconfig.me/ip"; # "curl -s https://api.ipify.org";
        speedtest = "speedtest-go";
        vi = "nvim";
        vim = "nvim";
      };
    };
  };

  systemd.user.tmpfiles.rules = [
    "d ${config.home.homeDirectory}/ws 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Dropbox 0755 ${username} users - -"
    #    "d ${config.home.homeDirectory}/Quickemu/nixos-console 0755 ${username} users - -"
    #    "d ${config.home.homeDirectory}/Quickemu/nixos-desktop 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/bin 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/ 0755 ${username} users - -"
    #    "d ${config.home.homeDirectory}/Syncthing 0755 ${username} users - -"
    "d ${config.home.homeDirectory}/Websites 0755 ${username} users - -"
    "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
  ];

}
