{ inputs, config, pkgs, username, ... }: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    ../../pass
    ../../cli
    ../../nvim
    # TODO:
    # ../../productivity
    # ../../games
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

      _1password
      _1password-gui
      cfssl
      dig
      emacs
      file
      git-credential-1password
      htop
      nvi
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
      #      PAGER = "moar";
    };

    # http://rski.github.io/2021/09/05/nix-debugging.html
    # https://github.com/nix-community/home-manager/commit/0056a5aea1a7b68bdacb7b829c325a1d4a3c4259
    enableDebugInfo = true;
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
