{ pkgs, ... }: {
  # System-level packages for gregburd on darwin
  # AI agent config (steering, skills, mcps) is in home-manager context
  # via darwin/default.nix home-manager.users block

  environment.systemPackages = with pkgs; [
    # Shells & terminal
    bash
    fish
    fishPlugins.foreign-env
    tmux
    neovim
    emacs

    # Build tools
    autoconf
    cmake
    meson
    ninja
    ccache
    gnumake
    libtool
    m4
    pkgconf

    # Languages & runtimes
    go
    gopls
    rustup
    nodejs
    python3

    # Dev tools
    clang-tools
    direnv
    dive
    git
    git-lfs
    htop
    jq
    lazydocker
    lazygit
    fastfetch
    ripgrep
    tig
    tokei
    tree

    # Database
    postgresql_16
    pgcli
    sqlite

    # AWS
    awscli2

    # Nix tools
    nixpkgs-fmt
    statix
    deadnix

    # Security
    gnupg

    # Misc
    coreutils
    wget
    xz
    zstd
  ];
}
