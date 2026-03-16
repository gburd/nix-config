# Optional documentation configuration
# Import this mixin to enable comprehensive man pages and documentation

{ lib, pkgs, ... }:

{
  # Install comprehensive man pages
  environment.systemPackages = with pkgs; [
    man-pages # Linux programmer's manual (sections 2, 3, 4, 5, 7, 8)
    man-pages-posix # POSIX programmer's manual
  ];

  documentation = {
    # NixOS manual and options search
    nixos.enable = lib.mkDefault true;

    # HTML documentation from packages (can be large)
    doc.enable = lib.mkDefault false;

    # GNU Info documentation (emacs-style)
    info.enable = lib.mkDefault false;

    # Development headers and pkg-config files
    dev.enable = lib.mkDefault true;

    # Man pages configuration
    man = {
      enable = true;
      # Generate whatis database for 'man -k' searches
      generateCaches = true;
    };
  };

  # Set MANPATH so man can find all documentation
  environment.variables = {
    MANPATH = lib.concatStringsSep ":" [
      "$HOME/.nix-profile/share/man"
      "/run/current-system/sw/share/man"
      "$MANPATH"
    ];
  };
}
