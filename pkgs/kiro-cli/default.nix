{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, unzip
, gcc-unwrapped
}:

let
  # Note: Version may not match actual binary version from "latest" channel
  # Updated: 2026-04-30 - New URL structure from prod.download.cli.kiro.dev
  version = "latest";
  channel = "stable";
  arch = if stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64";
  libc = if stdenv.hostPlatform.isMusl then "-musl" else "";
  sha256 = "sha256-UzvMs9cdldXcdpqw2CgsMIhpA3GC4HQkvMq2lkSYy/M="; # Updated: 2026-05-15
in
stdenv.mkDerivation {
  pname = "kiro-cli";
  inherit version;

  # Official installer now uses prod.download.cli.kiro.dev
  # Pattern: https://prod.download.cli.kiro.dev/{channel}/latest/kirocli-{arch}-linux{-musl}.zip
  src = fetchurl {
    url = "https://prod.download.cli.kiro.dev/${channel}/latest/kirocli-${arch}-linux${libc}.zip";
    inherit sha256;
    name = "kiro-cli-${version}-${arch}-linux.zip";
  };

  nativeBuildInputs = [ unzip ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gcc-unwrapped.lib # Provides libgcc_s.so.1
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    if [ -f kiro-cli ]; then
      install -m755 kiro-cli $out/bin/kiro-cli
    elif [ -d bin ]; then
      install -m755 bin/kiro-cli $out/bin/kiro-cli
    else
      # Tarball may extract differently — find the binary
      find . -name 'kiro-cli' -type f -exec install -m755 {} $out/bin/kiro-cli \;
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Kiro CLI - AI coding agent for the terminal";
    homepage = "https://kiro.dev/cli/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "kiro-cli";
  };
}
