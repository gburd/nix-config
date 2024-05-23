{ desktop, pkgs, lib, ... }: {
  imports = [
    ../../desktop/chromium.nix
    ../../desktop/chromium-extensions.nix
    ../../desktop/firefox.nix
    ../../desktop/google-chrome.nix
    ../../desktop/lutris.nix
    ../../desktop/spotify.nix
    ../../desktop/tilix.nix
    ../../desktop/vscode.nix
    ../../desktop/jetbrains-toolbox.nix
  ]
  ++ lib.optional (builtins.pathExists (../.. + "/desktop/${desktop}.nix")) ../../desktop/${desktop}.nix
  ++ lib.optional (builtins.pathExists (../.. + "/desktop/${desktop}-apps.nix")) ../../desktop/${desktop}-apps.nix;

  environment.systemPackages = with pkgs; [
    authy
    audio-recorder
    gimp-with-plugins
    gnome.gnome-clocks
    gnome.dconf-editor
    gnome.gnome-sound-recorder
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
