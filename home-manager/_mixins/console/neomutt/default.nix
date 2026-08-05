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
  # gmail-work (greg.burd@volunteer.postgresql.us) DISABLED: it's a Google
  # Workspace account whose admin has disabled app passwords, so neomutt's
  # password IMAP auth can't work; it would need an OAuth/XOAUTH2 token-
  # refresh pipeline (and the Workspace admin allowing a third-party OAuth
  # client), which isn't set up. Re-enable this + the F3 macros in neomuttrc
  # once OAuth is sorted or app passwords are permitted.
  # xdg.configFile."neomutt/accounts/gmail-work.muttrc".source = ./accounts/gmail-work.muttrc;
  xdg.configFile."neomutt/accounts/fastmail.muttrc".source = ./accounts/fastmail.muttrc;
  xdg.configFile."neomutt/accounts/icloud.muttrc".source = ./accounts/icloud.muttrc;
  # outlook (gregburd@outlook.com) DISABLED: personal outlook.com is
  # OAuth2-only and had no working password/gateway path (DavMail's
  # device-code flow is broken for personal MS accounts; Azure app /
  # mutt_oauth2.py declined). Re-enable this + the F6 macros in neomuttrc +
  # the cache dir below with a working XOAUTH2 setup.
  # xdg.configFile."neomutt/accounts/outlook.muttrc".source = ./accounts/outlook.muttrc;
  # amazon (gregburd@amazon.com) DISABLED for now (per request). Re-enable
  # this + the F7 macros in neomuttrc + the cache dir below when wanted.
  # xdg.configFile."neomutt/accounts/amazon.muttrc".source = ./accounts/amazon.muttrc;

  # Create cache directories for each account
  home.file = {
    ".cache/neomutt/protonmail/.keep".text = "";
    ".cache/neomutt/gmail-personal/.keep".text = "";
    # gmail-work cache dir omitted while that account is disabled (see above)
    # ".cache/neomutt/gmail-work/.keep".text = "";
    ".cache/neomutt/fastmail/.keep".text = "";
    ".cache/neomutt/icloud/.keep".text = "";
    # outlook cache dir omitted while that account is disabled (see above)
    # ".cache/neomutt/outlook/.keep".text = "";
    # amazon cache dir omitted while that account is disabled (see above)
    # ".cache/neomutt/amazon/.keep".text = "";
  };
}
