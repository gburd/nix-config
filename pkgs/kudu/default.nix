{ lib
, stdenv
, fetchurl
, appimageTools
, unzip
}:

# Kudu — system cleaner / scanner / startup manager (a CCleaner-style tool),
# MIT, AdventDevInc/kudu. Not in nixpkgs and not a Homebrew cask (both checked
# 2026-10-09), so built from upstream's release artifacts here.
#
# TWO PLATFORMS, TWO ARTIFACTS, because upstream ships no single portable one:
#   * Linux  -> Kudu-x86_64.AppImage via appimageTools.wrapType2, which does
#     the FHS wrapping and library patching in one step (the .deb would need
#     dpkg + a hand-built autoPatchelf closure for all of Electron).
#   * Darwin -> Kudu-3.6.1-arm64.zip, which contains a notarized Kudu.app;
#     just unpack it into $out/Applications. The AppImage cannot work here,
#     and there is no x86_64-darwin entry because the only Mac in this config
#     (aws / 80a99738d7e2) is aarch64.
#
# CAUTION, worth stating because of what this app does: Kudu's purpose is to
# delete files and change startup/system settings. On NixOS most of what a
# cleaner targets is either in the read-only /nix/store (where deleting is
# impossible or corrupts a generation) or is managed declaratively by this
# repo, so its "optimize"/"harden" actions can disagree with the config. Use
# the scanner/inspection views freely; be deliberate about anything that
# cleans.
let
  version = "3.6.1";
  pname = "kudu";

  linuxSrc = fetchurl {
    url = "https://github.com/AdventDevInc/kudu/releases/download/v${version}/Kudu-x86_64.AppImage";
    hash = "sha256-FscU/EUkKl1PlNhjtuNiWiwQrOFL541j52rAtXc+5jE=";
    name = "Kudu-${version}-x86_64.AppImage";
  };

  darwinSrc = fetchurl {
    url = "https://github.com/AdventDevInc/kudu/releases/download/v${version}/Kudu-${version}-arm64.zip";
    hash = "sha256-v75hHkSHHBT6ughnjswk0m7JvwMIiVUFgs7Gdgky06c=";
  };

  # The AppImage carries its own .desktop + icons; extract them so the app
  # appears in the launcher instead of being CLI-only.
  appimageContents = appimageTools.extractType2 {
    inherit pname version;
    src = linuxSrc;
  };

  meta = {
    description = "System cleaner, scanner and startup manager";
    homepage = "https://github.com/AdventDevInc/kudu";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-darwin" ];
    mainProgram = pname;
  };
in
if stdenv.hostPlatform.isDarwin then
  stdenv.mkDerivation
  {
    inherit pname version meta;
    src = darwinSrc;
    nativeBuildInputs = [ unzip ];
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -R *.app "$out/Applications/"
      runHook postInstall
    '';
    dontFixup = true;
  }
else
  appimageTools.wrapType2 {
    inherit pname version meta;
    src = linuxSrc;

    extraInstallCommands = ''
      mkdir -p $out/share/applications $out/share/icons
      if [ -d ${appimageContents}/usr/share/icons ]; then
        cp -r ${appimageContents}/usr/share/icons/. $out/share/icons/ || true
      fi
      for d in ${appimageContents}/*.desktop; do
        [ -e "$d" ] || continue
        install -Dm444 "$d" "$out/share/applications/$(basename "$d")"
      done
      # The shipped Exec= points at the AppImage's internal AppRun; repoint it
      # at the wrapper this derivation installs.
      substituteInPlace $out/share/applications/*.desktop \
        --replace-quiet 'Exec=AppRun' 'Exec=${pname}' \
        --replace-quiet 'Exec=kudu' 'Exec=${pname}'
    '';
  }
