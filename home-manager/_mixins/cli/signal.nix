{ desktop, lib, pkgs, ... }: {
  imports = lib.optionals (desktop != null) [
    ../desktop/signal.nix
  ];
  home.packages = [ pkgs.signal-cli ];
}
