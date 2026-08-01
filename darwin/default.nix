{ self, lib, pkgs, hostname, username, platform, stateVersion, outputs, ... }: {
  imports = [
    ./${hostname}
    ./_mixins/users/${username}
  ];

  # Home Manager configuration for the primary user
  home-manager.users.${username} = { pkgs, ... }: {
    imports = [
      ../modules/home-manager/ai
      ./_mixins/console/ai
      ../home-manager/_mixins/emacs
    ];

    home.username = lib.mkForce username;
    home.homeDirectory = lib.mkForce "/Users/${username}";
    home.stateVersion = "24.11";

    # This host runs the home-manager 26.05 module against rolling (unstable)
    # darwin pkgs (nix-darwin follows nixpkgs-unstable + useGlobalPkgs), an
    # intentional pairing; the release check false-positives on it.
    home.enableNixpkgsReleaseCheck = false;

    # Skip building home-manager manpages here: it triggers HM's docs/options.json
    # generation, which emits an upstream "references store path without proper
    # context" eval warning. `home-manager-help` / the HTML manual are unaffected.
    manual.manpages.enable = false;

    # Amazon-toolbox MCP servers — this work Mac ("aws") only; NOT synced to
    # the Linux hosts (they have no Amazon toolbox). extraServers is {} elsewhere.
    programs.ai.mcps.extraServers = lib.mkIf (hostname == "aws") {
      "builder-mcp" = { command = "builder-mcp"; args = [ ]; };
      "amzn-mcp" = { command = "amzn-mcp"; args = [ "--include-publish-status=experimental" ]; };
    };

    # SSH host aliases. enableDefaultConfig=false (its defaults are being
    # removed upstream); shared defaults live in matchBlocks."*".
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          identityFile = "~/.ssh/id_ecdsa";
          identitiesOnly = true;
          extraOptions.StrictHostKeyChecking = "accept-new";
        };
        "aws" = {
          hostname = "80a99738d7e2";
          user = username;
        };
        # Home-lab hosts (LAN; user gburd). Restored from the pre-nix-darwin
        # ~/.ssh/config so unison/ssh to these hosts keeps working.
        "floki" = { hostname = "192.168.1.151"; user = "gburd"; };
        "arnold" = { hostname = "192.168.1.37"; user = "gburd"; };
        "meh" = { hostname = "192.168.1.185"; user = "gburd"; };
        "rv greenfly" = { hostname = "192.168.1.126"; user = "gburd"; };
        "sun icarus" = { hostname = "192.168.1.206"; user = "gburd"; };
        "santorini win unicorn" = { hostname = "100.112.230.126"; user = "gburd"; };
      };
    };

    # Git config
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user.name = "Greg Burd";
        user.email = "greg@burd.me";
        alias = {
          st = "status --short";
          ci = "commit";
          co = "checkout";
          di = "diff";
          dc = "diff --cached";
          aa = "add --all";
          amend = "commit --amend";
          mend = "commit --amend --no-edit";
          head = "!git l -1";
          h = "!git head";
          r = "!git --no-pager l -20";
          ra = "!git r --all";
          ff = "merge --ff-only";
          pullff = "pull --ff-only";
          l = "log --graph --abbrev-commit --date=relative";
          la = "!git l --all";
          div = "divergence";
          gn = "goodness";
          gnc = "goodness --cached";
          fa = "fetch --all";
          pom = "push origin master";
          files = "show --oneline";
          graph = "log --graph --decorate --all";
          lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
          lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
          lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
          unadd = "reset --";
          unedit = "checkout --";
          unstage = "reset HEAD";
          unrm = "checkout --";
          unstash = "stash pop";
          lastchange = "log -n 1 -p";
          subdate = "submodule update --init --recursive";
          sync = "pull --rebase";
          update = "merge --ff-only origin/master";
        };
        # Mirrors ~/.gitconfig [core] excludesFile. The ~/.gitconfig credential
        # helper (plaintext PAT) is deliberately NOT codified (secret; repo public).
        core.excludesFile = "~/.gitignore";
      };
    };

    # Emacs (shared mixin, now colorscheme-optional). The mixin defaults to
    # emacs-gtk (X11) which is wrong on macOS -> use the Cocoa/NS build; and
    # socketActivation is systemd-only, so disable it (launchd emacs still runs).
    programs.emacs.package = lib.mkForce pkgs.emacs;
    services.emacs.socketActivation.enable = lib.mkForce false;

    # Amazon Builder Toolbox stays self-managed under ~/.toolbox (brazil, ada,
    # cr, toolbox, q, builder-mcp, amzn-mcp, ...); it self-updates and must NOT
    # be managed by nix or Homebrew. Just keep it on PATH.
    home.sessionPath = [ "$HOME/.toolbox/bin" ];

    home.packages = with pkgs; [
      gh
      nodejs
      uv
      # curated CLI dev tools, migrated from Homebrew to nixpkgs
      ripgrep
      eza
      bat
      fd
      tree
      bottom
      dust
      wget
      tig
      shellcheck
      git-absorb
      git-filter-repo
      fzf
    ];
  };

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    # SYSTEM packages, for all users
    direnv
    glances
    home-manager
  ];

  fonts = {
    packages = with pkgs; [
      # iosevka-bin (prebuilt) — building iosevka from source crashes on macOS
      # (Node/libuv kqueue assertion), which broke `nix build` of the system.
      iosevka-bin
      font-awesome
      nerd-fonts.fira-code
    ];
  };

  # These Macs run Determinate Nix, which owns the daemon and /etc/nix/nix.conf.
  # nix-darwin must NOT manage Nix or the two conflict at switch time. Determinate
  # already enables the nix-command and flakes experimental features, so there is
  # nothing for nix-darwin to configure here.
  nix.enable = false;

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.trunk-packages
    ];
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = false; # default shell on catalina

  programs = {
    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_cursor_default block blink
        set fish_cursor_insert line blink
        set fish_cursor_replace_one underscore blink
        set fish_cursor_visual block
        set -U fish_color_autosuggestion brblack
        set -U fish_color_cancel -r
        set -U fish_color_command green
        set -U fish_color_comment brblack
        set -U fish_color_cwd brgreen
        set -U fish_color_cwd_root brred
        set -U fish_color_end brmagenta
        set -U fish_color_error red
        set -U fish_color_escape brcyan
        set -U fish_color_history_current --bold
        set -U fish_color_host normal
        set -U fish_color_match --background=brblue
        set -U fish_color_normal normal
        set -U fish_color_operator cyan
        set -U fish_color_param blue
        set -U fish_color_quote yellow
        set -U fish_color_redirection magenta
        set -U fish_color_search_match bryellow '--background=brblack'
        set -U fish_color_selection white --bold '--background=brblack'
        set -U fish_color_status red
        set -U fish_color_user brwhite
        set -U fish_color_valid_path --underline
        set -U fish_pager_color_completion normal
        set -U fish_pager_color_description yellow
        set -U fish_pager_color_prefix white --bold --underline
        set -U fish_pager_color_progress brwhite '--background=cyan'
      '';
      shellAliases = {
        nix-gc = "sudo nix-collect-garbage --delete-older-than 14d";
        rebuild-all = "sudo nix-collect-garbage --delete-older-than 14d && darwin-rebuild switch --flake $HOME/ws/nix-config#aws && home-manager switch -b backup --flake $HOME/ws/nix-config";
        rebuild-home = "home-manager switch -b backup --flake $HOME/ws/nix-config";
        rebuild-host = "darwin-rebuild switch --flake $HOME/ws/nix-config";
        rebuild-lock = "pushd $HOME/ws/nix-config && nix flake lock --recreate-lock-file && popd";
        # TODO: Support secrets management on macOS
        # modify-secret = "agenix -i ~/.ssh/id_rsa -e"; # the path relative to /secrets must be passed

        moon = "curl -s wttr.in/Moon";
        nano = "vim";
        pubip = "curl -s ifconfig.me/ip";
        #pubip = "curl -s https://api.ipify.org";
        wttr = "curl -s wttr.in && curl -s v2.wttr.in";
        wttr-bas = "curl -s wttr.in/detroit && curl -s v2.wttr.in/detroit";
      };
    };
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = stateVersion;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = platform;
}
