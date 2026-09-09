{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, python3
, tree-sitter
, installShellFiles
, maki-src ? null
}:

let
  # Pinned fallback for legacy non-flake builds (`nix-build -A maki`), where
  # the maki-src flake input isn't threaded in. The flake path (maki-src)
  # tracks my fork's latest release; this pin only matters off-flake.
  fallbackVersion = "0.4.12-gburd.1";
  fallbackSrc = fetchFromGitHub {
    owner = "gburd";
    repo = "maki";
    rev = "v${fallbackVersion}";
    hash = "sha256-HC3PbO1eWyklMmlkJl53tFy+M3x5/PbzFgoLG9rpp+0=";
  };
  useInput = maki-src != null;
in
rustPlatform.buildRustPackage {
  pname = "maki";
  # From the flake input this is the tracked commit's short rev; the actual
  # semver lives in the crate's Cargo.toml. Off-flake it's the pinned tag.
  version = if useInput then (maki-src.shortRev or "unstable") else fallbackVersion;

  src = if useInput then maki-src else fallbackSrc;

  # Vendored crates hash. When maki-src advances to a release whose
  # dependency tree changed, this must be updated (the build fails with the
  # expected value); everything else tracks the tag automatically.
  cargoHash = "sha256-MrWqmy8dCkg48+JVCAA0UWMYPOXW9Mid38RQzjJATew=";

  nativeBuildInputs = [
    pkg-config
    python3
    installShellFiles
  ];

  buildInputs = [
    openssl
    tree-sitter
  ];

  OPENSSL_NO_VENDOR = 1;

  # monty crate references ../../../README.md from src/ which doesn't
  # exist in the vendored copy — create the file it expects. The vendor
  # layout differs across nixpkgs versions (older: maki-*-vendor/monty-*/src;
  # newer: maki-*-vendor/source-git-*/monty-*/src), so match monty's src dir
  # wherever it lands and create the README it include_str!'s.
  preBuild = ''
    for d in $(find "$NIX_BUILD_TOP" -type d -path '*monty-*/src' 2>/dev/null); do
      target="$(realpath -m "$d/../../../README.md")"
      mkdir -p "$(dirname "$target")"
      touch "$target"
    done
  '';

  # Build only the main maki binary
  cargoBuildFlags = [ "--bin" "maki" ];

  # Some tests require network access
  doCheck = false;

  postInstall = ''
    # Install shell completions if generated
    if [ -f target/release/build/maki-*/out/maki.bash ]; then
      installShellCompletion --bash target/release/build/maki-*/out/maki.bash
      installShellCompletion --zsh target/release/build/maki-*/out/_maki
      installShellCompletion --fish target/release/build/maki-*/out/maki.fish
    fi
  '';

  meta = with lib; {
    description = "An efficient AI coding agent optimized for minimal context token usage";
    homepage = "https://maki.sh";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "maki";
  };
}
