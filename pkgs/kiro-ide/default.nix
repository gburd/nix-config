{ lib
, stdenv
, fetchurl
, appimageTools
, makeDesktopItem
}:

let
  version = "0.11.133";
  pname = "kiro-ide";

  desktopItem = makeDesktopItem {
    name = "kiro";
    desktopName = "Kiro IDE";
    exec = "kiro %F";
    icon = "kiro";
    comment = "AI-native IDE";
    categories = [ "Development" "IDE" ];
    mimeTypes = [ "text/plain" "inode/directory" ];
  };
in
appimageTools.wrapType2 {
  inherit pname version;

  # FIXME: Download URL is broken as of 2026-04-30
  # - Old URL: https://kiro.dev/downloads/latest/linux returns 404
  # - New infrastructure: https://prod.download.desktop.kiro.dev/ returns 403 (Access Denied)
  # - Kiro has locked down their download infrastructure
  # Possible solutions:
  # 1. Use their installer script (impure)
  # 2. Manual download and local path
  # 3. Wait for Kiro to provide stable download URLs
  src = fetchurl {
    url = "https://kiro.dev/downloads/latest/linux";
    sha256 = lib.fakeSha256; # Cannot obtain - download URL is inaccessible
    name = "kiro-${version}-linux.AppImage";
  };

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/* $out/share/applications/
  '';

  meta = with lib; {
    description = "Kiro IDE - AI-native development environment";
    homepage = "https://kiro.dev/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "kiro";
  };
}
