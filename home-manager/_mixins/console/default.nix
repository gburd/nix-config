{ config, pkgs, ... }: {
  imports = [
    ./neovim.nix
    ./tmux.nix
  ];

  home = {
    file = {
      "${config.xdg.configHome}/neofetch/config.conf".text = builtins.readFile ./neofetch.conf;
    };
    # A Modern Unix experience
    # https://jvns.ca/blog/2022/04/12/a-list-of-new-ish--command-line-tools/
    packages = with pkgs; [
      asciinema # Terminal recorder
      breezy # Terminal bzr client
      chafa # Terminal image viewer
      dconf2nix # Nix code from Dconf files
      diffr # Modern Unix `diff`
      difftastic # Modern Unix `diff`
      dua # Modern Unix `du`
      duf # Modern Unix `df`
      du-dust # Modern Unix `du`
      entr # Modern Unix `watch`
      fd # Modern Unix `find`
      ffmpeg-headless # Terminal video encoder
      fzf # Command-line fuzzy finder
      glow # Terminal Markdown renderer
      gping # Modern Unix `ping`
      hexyl # Modern Unix `hexedit`
      hyperfine # Terminal benchmarking
      jpegoptim # Terminal JPEG optimizer
      jiq # Modern Unix `jq`
      lazygit # Terminal Git client
      neofetch # Terminal system info
      nixpkgs-review # Nix code review
      nurl # Nix URL fetcher
      nyancat # Terminal rainbow spewing feline
      optipng # Terminal PNG optimizer
      page # Modern pager
      procs # Modern Unix `ps`
      quilt # Terminal patch manager
      ripgrep # Modern Unix `grep`
      tldr # Modern Unix `man`
      tokei # Modern Unix `wc` for code
      wget # Terminal downloader
      yq-go # Terminal `jq` for YAML
    ];

    sessionVariables = {
      EDITOR = "nvim";
      PAGER = "page";
      SYSTEMD_EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  programs = {
    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      flags = [
        "--disable-up-arrow"
      ];
      package = pkgs.unstable.atuin;
      settings = {
        auto_sync = true;
        dialect = "us";
        show_preview = true;
        style = "compact";
        sync_frequency = "1h";
        sync_address = "https://api.atuin.sh";
        update_check = false;
      };
    };
    bottom = {
      enable = true;
      settings = {
        colors = {
          high_battery_color = "green";
          medium_battery_color = "yellow";
          low_battery_color = "red";
        };
        disk_filter = {
          is_list_ignored = true;
          list = [ "/dev/loop" ];
          regex = true;
          case_sensitive = false;
          whole_word = false;
        };
        flags = {
          dot_marker = false;
          enable_gpu_memory = true;
          group_processes = true;
          hide_table_gap = true;
          mem_as_value = true;
          tree = true;
        };
      };
    };
    dircolors = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv = {
        enable = true;
      };
    };
    eza = {
      enable = true;
      icons = true;
    };
    fish = {
      enable = true;
      shellAliases = {
        diff = "diffr";
        glow = "glow --pager";
        ip = "ip --color --brief";
        top = "btm --basic --tree --hide_table_gap --dot_marker --mem_as_value";
        tree = "eza --tree";
      };
      functions =
        let
          doCurl = type: url: "$(curl -L \"${url}\" 2>/dev/null | ${type}sum | awk '{print $1}')";
          makeSriHasher = type: content: "nix-hash --type ${type} --to-sri ${content}";
          makeSriUrlHasher = url: type: makeSriHasher type (doCurl type url);
          makeSriUrlHasherFishFunction = makeSriUrlHasher "$argv[1]";
        in
        {
          shell = ''
            nix develop $HOME/ws/nix-config#$argv[1] || nix develop $HOME/ws/nix-config#( \
              git remote -v \
                | grep '(push)' \
                | awk '{print $2}' \
                | cut -d ':' -f 2 \
                | rev \
                | sed 's/tig.//' \
                | rev \
            )
          '';
          is-number = ''
            string match --quiet --regex "^\d+\$" $argv[1]
          '';
          deploy-nuc = "is-number $argv[1] && nixos-rebuild --fast --flake $HOME/ws/nix-config#nuc$argv[1] --target-host root@192.168.40.20$argv[1] $argv[2..]";

          sriMd5Url = makeSriUrlHasherFishFunction "md5";
          sriSha1Url = makeSriUrlHasherFishFunction "sha1";
          sriSha256Url = makeSriUrlHasherFishFunction "sha256";
          sriSha512Url = makeSriUrlHasherFishFunction "sha512";
        };
      plugins = with pkgs.fishPlugins; [
        { name = "foreign-env"; inherit (foreign-env) src; }
        { name = "fzf"; inherit (fzf-fish) src; }
      ];
    };
    gh = {
      enable = true;
      extensions = with pkgs; [ gh-markdown-preview ];
      settings = {
        editor = "nvim";
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
    git = {
      enable = true;
      delta = {
        enable = true;
        options = {
          features = "decorations";
          navigate = true;
          line-numbers = true;
          side-by-side = true;
          syntax-theme = "GitHub";
        };
      };
      aliases = {
        a = "add";
        aa = "add --all";
        aaa = "!git a $(git rd)";
        add-nowhitespace = "!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -";
        # amend
        am = "!git cm --amend --no-edit --date=\"$(date +'%Y %D')\"";
        amend = "commit --amend";
        # branch name
        bn = "br --show-current";
        br = "branch";
        ci = "commit";
        co = "checkout";
        cob = "co -b";
        d = "diff";
        dag = "log --graph --format='format:%C(yellow)%h%C(reset) %C(blue)\"%an\" <%ae>%C(reset) %C(magenta)%cr%C(reset)%C(auto)%d%C(reset)%n%s' --date-order";
        dc = "diff --cached";
        di = "diff";
        div = "divergence";
        ds = "d --staged";
        f = "fetch";
        fa = "f --all";
        fast-forward = "merge --ff-only";
        ff = "merge --ff-only";
        files = "show --oneline";
        gn = "goodness";
        gnc = "goodness --cached";
        # generate patch
        gp = "!gitgenpatch() { target=$1; git format-patch $target --stdout | sed -n -e '/^diff --git/,$p' | head -n -3; }; gitgenpatch";
        graph = "log --decorate --oneline --graph";
        h = "!git head";
        head = "!git l -1";
        # shows commit history
        hist = "log --pretty=format:\"%h %ad | %s%d [%an]\" --graph --date=short";
        l = "log --graph --abbrev-commit --date=relative";
        la = "!git l --all";
        lastchange = "log -n 1 -p";
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
        lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
        mend = "commit --amend --no-edit";
        p = "push";
        # force with lease
        pf = "poh --force-with-lease";
        # FORCEEEE
        pff = "poh --force";
        # push to origin HEAD
        poh = "p origin HEAD";
        pom = "push origin master";
        # push and open pr
        ppr = "!git poh; !git pr";
        # open pr
        pr = "!gh pr create";
        pullff = "pull --ff-only";
        pushall = "!git remote | xargs -L1 git push --all";
        r = "!git --no-pager l -20";
        ra = "!git r --all";
        rb = "rebase";
        rbc = "rebase --continue";
        # gets root directory
        rd = "rev-parse --show-toplevel";
        rh = "rs --hard";
        rho = "!git rh origin/$(git bn)";
        rs = "reset";
        # squash it
        sq = "!gitsq() { git rb -i $(git sr $1) $2; }; gitsq";
        # gets latest shared commit
        sr = "merge-base HEAD";
        st = "status --short";
        subdate = "submodule update --init --recursive";
        sync = "pull --rebase";
        unadd = "reset --";
        unedit = "checkout --";
        unrm = "checkout --";
        unstage = "reset HEAD";
        unstash = "stash pop";
        update = "merge --ff-only origin/master";
      };
      extraConfig = {
        push = {
          default = "matching";
        };
        pull = {
          rebase = true;
          ff = "only";
        };
        init = {
          defaultBranch = "main";
        };
      };
      ignores = [
        "*.log"
        "*.out"
        ".DS_Store"
        "bin/"
        "dist/"
        "result"
      ];
    };
    gpg.enable = true;
    home-manager.enable = true;
    info.enable = true;
    jq.enable = true;
    micro = {
      enable = true;
      settings = {
        colorscheme = "simple";
        diffgutter = true;
        rmtrailingws = true;
        savecursor = true;
        saveundo = true;
        scrollbar = true;
      };
    };
    powerline-go = {
      enable = true;
      settings = {
        cwd-max-depth = 5;
        cwd-max-dir-size = 12;
        max-width = 60;
      };
    };
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
  };
}
