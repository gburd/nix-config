{ lib
, fetchFromGitHub
, rustPlatform
, pkg-config
, libpcap
}:

# netwatch — real-time network diagnostics TUI ("htop for your network").
# Not in nixpkgs (checked 2026-10-09), so built from the tagged source here.
#
# The build inputs mirror upstream's own package.nix, which the repo ships
# alongside a flake.nix: pkg-config + libpcap and a vendored Cargo.lock.
# We do NOT consume their flake as an input — it pins its own
# nixpkgs-unstable, which would drag a second nixpkgs into this closure for
# one small binary.
#
# NOTE upstream's package.nix hardcodes `version = "0.26.1"` even on the
# v0.35.3 tag (their own comment admits the label drifts), so the version
# below is taken from the git tag, not from their file.
rustPlatform.buildRustPackage rec {
  pname = "netwatch";
  version = "0.35.3";

  src = fetchFromGitHub {
    owner = "matthart1983";
    repo = "netwatch";
    tag = "v${version}";
    hash = "sha256-Fq0Nj7qd0J3ML/++3tm4O7XHkT/KMzhm/ca7ak3QYFo=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libpcap ];

  # One of 1453 unit tests cannot pass in the Nix sandbox:
  # collectors::connections::tests::controlled_polling_matrix_matches_independent_processes
  # (src/collectors/connections.rs:2254) compares a polled connection matrix
  # against independently-spawned processes, which needs live sockets and
  # real PIDs the builder does not have. 1452 pass and 3 are already ignored
  # upstream. Skip that single environment-dependent test rather than setting
  # doCheck = false, so a genuine regression in the other 1452 still fails
  # the build.
  checkFlags = [
    "--skip=collectors::connections::tests::controlled_polling_matrix_matches_independent_processes"
  ];

  meta = {
    description = "Real-time network diagnostics in your terminal";
    homepage = "https://github.com/matthart1983/netwatch";
    license = lib.licenses.mit;
    mainProgram = "netwatch";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
