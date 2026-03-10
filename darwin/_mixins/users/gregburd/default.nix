{ pkgs, ... }: {
  imports = [
    # Temporarily disabled to isolate build issues:
    # ../../nixos/console/auth0.nix  # network issues downloading Go deps
    # ../../nixos/console/direnv.nix
    # ../../nixos/console/kubectl.nix
    # ../../nixos/desktop/spotify.nix
  ];

  environment.systemPackages = with pkgs; [
    bazelisk
    direnv
    dive
    fish
    fishPlugins.foreign-env
    guile
    jdk11
    lazydocker
    lazygit
    mariadb
    fastfetch
    neovim
    tmux
    tokei
    tree
  ];
}
