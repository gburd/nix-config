{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, tree-sitter
, installShellFiles
}:

rustPlatform.buildRustPackage rec {
  pname = "maki";
  version = "0.5.0"; # Update to match latest release tag

  src = fetchFromGitHub {
    owner = "gburd";
    repo = "maki";
    rev = "v${version}"; # Uses release tag
    hash = lib.fakeHash; # Replace after first build attempt
  };

  cargoHash = lib.fakeHash; # Replace after first build attempt

  nativeBuildInputs = [
    pkg-config
    installShellFiles
  ];

  buildInputs = [
    openssl
    tree-sitter
  ];

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
