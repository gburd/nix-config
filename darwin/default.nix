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
    ];

    home.username = lib.mkForce username;
    home.homeDirectory = lib.mkForce "/Users/${username}";
    home.stateVersion = "24.11";

    # SSH host aliases
    programs.ssh = {
      enable = true;
      matchBlocks = {
        "aws" = {
          hostname = "80a99738d7e2";
          user = username;
        };
      };
    };

    # Git config
    programs.git = {
      enable = true;
      userName = "Greg Burd";
      userEmail = "greg@burd.me";
      lfs.enable = true;
      aliases = {
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
      # Mirrors ~/.gitconfig [core] excludesFile. NOTE: the credential helper in
      # ~/.gitconfig (a plaintext PAT echo) is deliberately NOT codified — it is
      # a secret and this repo is public; `gh auth git-credential` handles auth.
      extraConfig = {
        core.excludesFile = "~/.gitignore";
      };
    };

    # NOTE: wiring the shared emacs mixin here is deferred — its theme.nix needs
    # a `colorscheme` attr only the Linux console mixin provides (eval fails with
    # "attribute 'colorscheme' missing"), and emacs-gtk must be overridden to the
    # Cocoa build on macOS. Emacs on the aws host is a follow-up (provide the
    # colorscheme option or a darwin-tailored programs.emacs block + burd.org
    # placement, then runtime-test).

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
        rebuild-all = "sudo nix-collect-garbage --delete-older-than 14d && darwin-rebuild switch --flake $HOME/ws/nix-config && home-manager switch -b backup --flake $HOME/ws/nix-config";
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
