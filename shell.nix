{ pkgs ? (import ./nixpkgs.nix) { overlays = [ ]; } }: {
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes repl-flake";
    nativeBuildInputs = with pkgs; [
      nix
      home-manager
      git
      vim
      emacs
      tig
      tree
      ripgrep
      sops
      ssh-to-age
      gnupg
      age
      yubikey-manager
      pinentry-curses
      kubectl
    ];
  };
  services.dbus.packages = [ pkgs.gcr ];
  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    pinentryFlavor = "curses";
    enableSSHSupport = true;
  };
}
