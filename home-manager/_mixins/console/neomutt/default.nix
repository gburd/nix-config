{ pkgs, ... }:
{
  home.packages = with pkgs; [
    neomutt # Email client
    w3m # HTML email viewer
    lynx # Alternative HTML viewer
    urlscan # Extract URLs from email
  ];

  # Neomutt configuration
  xdg.configFile."neomutt/neomuttrc".source = ./neomuttrc;
  xdg.configFile."neomutt/mailcap".source = ./mailcap;
  xdg.configFile."neomutt/signature".source = ./signature;

  # Create cache directory
  home.file.".cache/neomutt/.keep".text = "";

  # Environment variables for Fastmail credentials
  # Note: Set these in your shell profile or use a password manager
  # export FASTMAIL_USER="your.email@fastmail.com"
  # export FASTMAIL_PASS="your-app-password"
}
