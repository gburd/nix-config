# Shell for bootstrapping flake-enabled nix and home-manager
# Enter it through 'nix develop' or (legacy) 'nix-shell'

{ pkgs ? (import ./nixpkgs.nix) { overlays = [ ]; } }: {
  default = pkgs.mkShell {
    # Enable experimental features without having to specify the argument
    NIX_CONFIG = "experimental-features = nix-command flakes repl-flake";
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
  #services.pcscd.enable = true;
  services.gnupg.agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
    enableSSHSupport = true;
  };
}
