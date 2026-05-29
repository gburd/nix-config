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
  version = "0.3.9-gburd.1";

  src = fetchFromGitHub {
    owner = "gburd";
    repo = "maki";
    rev = "v${version}";
    hash = "sha256-ih5eKWRkp9JGlhEZc888uHJ231+FR+/GXUME3DAQY0A=";
  };

  cargoHash = "sha256-9nmCoW9q8y5CNrLqbmHqtu5UmpKxbexFvMdmuSXCDcI=";

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
  # exist in vendored copy — create the file it expects
  preBuild = ''
    for d in $NIX_BUILD_TOP/maki-*-vendor/monty-*/src; do
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
