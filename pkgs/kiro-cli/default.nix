{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
}:

let
  version = "1.26.0";
  platform = if stdenv.hostPlatform.isLinux then "linux" else "darwin";
  arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
  sha256 = lib.fakeSha256; # Replace after first build attempt
in
stdenv.mkDerivation {
  pname = "kiro-cli";
  inherit version;

  # The official installer downloads from cli.kiro.dev
  # We fetch the binary directly instead of running the install script
  src = fetchurl {
    url = "https://cli.kiro.dev/download/${platform}/${arch}/latest";
    inherit sha256;
    name = "kiro-cli-${version}-${platform}-${arch}.tar.gz";
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    makeWrapper
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
