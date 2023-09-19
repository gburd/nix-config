{ pkgs ? import <nixpkgs> { } }: rec {

  # Packages with an actual source
  rgbdaemon = pkgs.callPackage ./rgbdaemon { };
  shellcolord = pkgs.callPackage ./shellcolord { };
  speedtestpp = pkgs.callPackage ./speedtestpp { };
  qt6gtk2 = pkgs.qt6Packages.callPackage ./qt6gtk2 { };

  # Personal scripts
  nix-inspect = pkgs.callPackage ./nix-inspect { };
  minicava = pkgs.callPackage ./minicava { };
  pass-wofi = pkgs.callPackage ./pass-wofi { };
  primary-xwayland = pkgs.callPackage ./primary-xwayland { };
  wl-mirror-pick = pkgs.callPackage ./wl-mirror-pick { };
  lyrics = pkgs.callPackage ./lyrics { };
  xpo = pkgs.callPackage ./xpo { };
  tly = pkgs.callPackage ./tly { };
}
