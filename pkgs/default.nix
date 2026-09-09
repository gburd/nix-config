# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { }, inputs ? { } }: {
  auth0 = pkgs.callPackage ./auth0.nix { };
  ente-photos-desktop = pkgs.callPackage ./ente.nix { };
  charm-freeze = pkgs.callPackage ./charm-freeze.nix { };
  colibri = pkgs.callPackage ./colibri { };
  kiro-cli = pkgs.callPackage ./kiro-cli { };
  # kiro-ide = pkgs.callPackage ./kiro-ide { };  # disabled: download URL broken (fakeSha256); re-enable when Amazon restores it
  # maki 0.3.26+ (monty/ruff) needs rustc >= 1.95; stable nixpkgs is on
  # 1.91, so build it with unstable's rustPlatform (1.95). Source tracks my
  # fork's latest release via the maki-src flake input (falls back to a
  # pinned fetch for legacy non-flake `nix-build -A maki`).
  maki = pkgs.callPackage ./maki {
    inherit (pkgs.unstable) rustPlatform;
    maki-src = inputs.maki-src or null;
  };
  nix-inspect = pkgs.callPackage ./nix-inspect { };
  memelord = pkgs.callPackage ./memelord { };
  tly = pkgs.callPackage ./tly { };
  umami = pkgs.callPackage ./umami { };
  # mailspring: overridden in overlays/default.nix (modifications), not here
  # -- it wraps the EXISTING nixpkgs mailspring, which recurses if resolved
  # via callPackage against the final (additions) pkg set.
  terax-ai = pkgs.callPackage ./terax-ai { };
}
