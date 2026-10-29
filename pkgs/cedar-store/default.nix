{ lib, rustPlatform }:
# Minimal Cedar 4 policy store with the cedar-agent read API, so maki's
# `[cedar] agent_url` and the pi cedar extension share one policy set.
# Source lives here (not a fork of permitio/cedar-agent: that bundles
# cedar-policy 2.4 and can't parse Cedar 3+ syntax maki emits).
rustPlatform.buildRustPackage {
  pname = "cedar-store";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };
  cargoLock.lockFile = ./Cargo.lock;
  meta = {
    description = "Minimal Cedar 4 policy store speaking cedar-agent's API";
    license = lib.licenses.mit;
    mainProgram = "cedar-store";
  };
}
