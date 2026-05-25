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

  # The upstream zip ships three sibling binaries that work as a unit:
  #   kiro-cli      — small launcher; execvp()s kiro-cli-chat / kiro-cli-term via $PATH
  #   kiro-cli-chat — main chat client (~395 MB)
  #   kiro-cli-term — terminal/PTY helper (~86 MB)
  # Installing only kiro-cli leaves the launcher unable to find its peers and it
  # fails with `error: No such file or directory (os error 2)`. Install all three.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    # Locate the bin/ directory inside the extracted archive.
    bin_dir=""
    for candidate in bin kirocli/bin */bin; do
      if [ -f "$candidate/kiro-cli" ]; then
        bin_dir="$candidate"
        break
      fi
    done
    if [ -z "$bin_dir" ]; then
      # Fallback: search anywhere
      bin_dir="$(dirname "$(find . -name kiro-cli -type f | head -1)")"
    fi
    if [ -z "$bin_dir" ] || [ ! -f "$bin_dir/kiro-cli" ]; then
      echo "ERROR: kiro-cli binary not found in archive" >&2
      exit 1
    fi

    for f in kiro-cli kiro-cli-chat kiro-cli-term; do
      if [ -f "$bin_dir/$f" ]; then
        install -m755 "$bin_dir/$f" "$out/bin/$f"
      else
        echo "WARNING: $f not found in archive (kiro-cli will likely fail at runtime)" >&2
      fi
    done

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
