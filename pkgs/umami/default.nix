{ lib
, rustPlatform
, fetchzip
}:

# umami — log anomaly-detection CLI (gregburd/umami on Codeberg). A Rust
# workspace; the `umami` binary lives in the umami-cli member crate.
# No upstream tags yet, so pin to a commit; bump rev+hash together.
rustPlatform.buildRustPackage rec {
  pname = "umami";
  version = "0.1.0-unstable-2026-08-03";

  src = fetchzip {
    url = "https://codeberg.org/gregburd/umami/archive/ba11f864f599.tar.gz";
    hash = "sha256-898flXHQHVpIrBPY673d94hFrotuO4+pxlR5h78/Of8=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Only the CLI binary is wanted, not the library crate's test/bench harness.
  cargoBuildFlags = [ "--bin" "umami" ];

  # Tests need no network; leave the workspace check on. If it ever flakes,
  # set doCheck = false.
  doCheck = true;

  meta = {
    description = "Filter streams of log messages so only the anomalous ones show";
    homepage = "https://codeberg.org/gregburd/umami";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = "umami";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
