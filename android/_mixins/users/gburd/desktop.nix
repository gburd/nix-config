{ desktop, pkgs, lib, ... }: {
  imports = [
    ../../desktop/chromium.nix
    ../../desktop/discord.nix
    ../../desktop/element.nix
    ../../desktop/firefox.nix
    #../../desktop/evolution.nix
    ../../desktop/google-chrome.nix
    ../../desktop/lutris.nix
    ../../desktop/obs-studio.nix
    ../../desktop/spotify.nix
    ../../desktop/tilix.nix
    ../../desktop/vscode.nix
  ] ++ lib.optional (builtins.pathExists (../.. + "/desktop/${desktop}-apps.nix")) ../../desktop/${desktop}-apps.nix;

  environment.systemPackages = with pkgs; [
    audio-recorder
    gimp-with-plugins
    gnome-clocks
    dconf-editor
    gnome-sound-recorder
    inkscape
    libreoffice
    meld
    netflix
    pick-colour-picker
    slack
  ];

  # programs = {
  #   chromium = {
  #     extensions = [
  #       "kbfnbcaeplbcioakkpcpgfkobkghlhen" # Grammarly
  #       "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
  #       "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
  #       "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
  #       "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
  #       "edlifbnjlicfpckhgjhflgkeeibhhcii" # Screenshot Tool
  #     ];
  #   };
  # };
}
