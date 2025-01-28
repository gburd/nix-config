{ desktop, pkgs, lib, ... }: {
  imports = [
    ../../desktop/chromium.nix
    ../../desktop/firefox.nix
    ../../desktop/google-chrome.nix
    ../../desktop/jetbrains-toolbox.nix
    ../../desktop/lutris.nix
    ../../desktop/discord.nix
    ../../desktop/spotify.nix
    ../../desktop/tilix.nix
    ../../desktop/vscode.nix
    ../../desktop/zed-editor.nix
  ]
  ++ lib.optional (builtins.pathExists (../.. + "/desktop/${desktop}.nix")) ../../desktop/${desktop}.nix
  ++ lib.optional (builtins.pathExists (../.. + "/desktop/${desktop}-apps.nix")) ../../desktop/${desktop}-apps.nix;

  environment.systemPackages = with pkgs; [
    audio-recorder
    gimp-with-plugins
    gnome-clocks
    dconf-editor
    gnome-sound-recorder
    inkscape
    irccloud
    libreoffice
    meld
    pick-colour-picker
    slack
    neovide
    zoom-us
  ];
}
