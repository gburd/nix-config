# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  auth0 = pkgs.callPackage ./auth0.nix { };
  ente-photos-desktop = pkgs.callPackage ./ente.nix { };
  charm-freeze = pkgs.callPackage ./charm-freeze.nix { };
  kiro-cli = pkgs.callPackage ./kiro-cli { };
  # kiro-ide = pkgs.callPackage ./kiro-ide { };  # disabled: download URL broken (fakeSha256); re-enable when Amazon restores it
  # maki 0.3.26+ (monty/ruff) needs rustc >= 1.95; stable nixpkgs is on
  # 1.91, so build it with unstable's rustPlatform (1.95).
  maki = pkgs.callPackage ./maki { inherit (pkgs.unstable) rustPlatform; };
  nix-inspect = pkgs.callPackage ./nix-inspect { };
  tly = pkgs.callPackage ./tly { };
  mailspring = pkgs.callPackage ./mailspring { };
  terax-ai = pkgs.callPackage ./terax-ai { };
}
