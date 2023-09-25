{ config, pkgs, username, ... }:
{
  imports = [
    ../services/keybase.nix

    # TODO remove/migrate away from user mixins
    ./_mixins
    ./_mixins/desktop/gnome
    ./_mixins/productivity
    ./_mixins/pass
    ./_mixins/games
  ];

  home = {
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
      moar # Modern Unix `less`
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
    ];
    sessionVariables = {
      PAGER = "moar";
    };
  };
  programs = {
    fish = {
      shellAliases = {
        diff = "diffr";
        fast = "fast -u";
        glow = "glow --pager";
        pubip = "curl -s ifconfig.me/ip"; # "curl -s https://api.ipify.org";
        speedtest = "speedtest-go";
      };
    };
    git = {
      userEmail = "greg@burd.me";
      userName = "Greg Burd";
      signing = {
        key = "D4BB42BE729AEFBD2EFEBF8822931AF7895E82DF";
        signByDefault = true;
      };
      aliases = {
        st = "status --short";
        ci = "commit";
        co = "checkout";
        di = "diff";
        dc = "diff --cached";
        amend = "commit --amend";
        aa = "add --all";
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
        sync = "pull --rebase";
        update = "merge --ff-only origin/master";
        mend = "commit --amend --no-edit";
        unadd = "reset --";
        unedit = "checkout --";
        unstage = "reset HEAD";
        unrm = "checkout --";
        unstash = "stash pop";
        lastchange = "log -n 1 -p";
        dag = "log --graph --format='format:%C(yellow)%h%C(reset) %C(blue)\"%an\" <%ae>%C(reset) %C(magenta)%cr%C(reset)%C(auto)%d%C(reset)%n%s' --date-order";
        subdate = "submodule update --init --recursive";
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
