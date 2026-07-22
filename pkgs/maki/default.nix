{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, python3
, tree-sitter
, installShellFiles
}:

rustPlatform.buildRustPackage rec {
  pname = "maki";
  version = "0.4.1-gburd.1";

  src = fetchFromGitHub {
    owner = "gburd";
    repo = "maki";
    rev = "v${version}";
    hash = "sha256-Lt9SVuI5jdOcwQExEWe3qAD+h1eE0ax4krdO14zHSAo=";
  };

  cargoHash = "sha256-Z1xp3onGGBdRudCSyGqwGGghUZZPZ0gGSMW2Owt1wGE=";

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
