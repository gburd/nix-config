{ pkgs, ... }:
{
  home.packages = with pkgs; [
    neomutt # Email client
    w3m # HTML email viewer
    lynx # Alternative HTML viewer
    urlscan # Extract URLs from email
    isync # Optional: for offline sync via mbsync
  ];

  # Neomutt main configuration
  xdg.configFile."neomutt/neomuttrc".source = ./neomuttrc;
  xdg.configFile."neomutt/mailcap".source = ./mailcap;
  xdg.configFile."neomutt/signature".source = ./signature;

  # Account-specific configurations
  xdg.configFile."neomutt/accounts/protonmail.muttrc".source = ./accounts/protonmail.muttrc;
  xdg.configFile."neomutt/accounts/gmail-personal.muttrc".source = ./accounts/gmail-personal.muttrc;
  xdg.configFile."neomutt/accounts/gmail-work.muttrc".source = ./accounts/gmail-work.muttrc;
  xdg.configFile."neomutt/accounts/fastmail.muttrc".source = ./accounts/fastmail.muttrc;
  xdg.configFile."neomutt/accounts/icloud.muttrc".source = ./accounts/icloud.muttrc;
  xdg.configFile."neomutt/accounts/outlook.muttrc".source = ./accounts/outlook.muttrc;
  xdg.configFile."neomutt/accounts/amazon.muttrc".source = ./accounts/amazon.muttrc;

  # Create cache directories for each account
  home.file = {
    ".cache/neomutt/protonmail/.keep".text = "";
    ".cache/neomutt/gmail-personal/.keep".text = "";
    ".cache/neomutt/gmail-work/.keep".text = "";
    ".cache/neomutt/fastmail/.keep".text = "";
    ".cache/neomutt/icloud/.keep".text = "";
    ".cache/neomutt/outlook/.keep".text = "";
    ".cache/neomutt/amazon/.keep".text = "";
  };
}
