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

  src = fetchurl {
    url = "https://kiro.dev/downloads/latest/linux";
    sha256 = lib.fakeSha256; # Replace after first build attempt
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
