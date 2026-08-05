{ config, ... }:
# DavMail: a local gateway that presents an OAuth-only Microsoft account
# (outlook.com / Office 365) as plain IMAP/SMTP on 127.0.0.1, so a
# password-only client like neomutt can use it -- exactly the same pattern
# as the ProtonMail bridge, but for Microsoft Exchange instead of Proton.
#
# WHY this and not the bridge: the ProtonMail bridge is Proton-specific
# (it only speaks to Proton's servers); it cannot gateway Outlook or Gmail.
# DavMail is purpose-built for Microsoft Exchange/EWS + OAuth2, so it's the
# right tool for outlook.com (which dropped basic-auth IMAP in Sept 2024).
#
# NOTE: DavMail does NOT gateway Google/Gmail -- it only speaks Exchange
# protocols. The pgus Google Workspace account still needs a separate
# OAuth path (Evolution/Thunderbird native OAuth, or mutt_oauth2.py).
#
# OAUTH FLOW (first run, interactive, once): with davmail.mode=auto and
# imitateOutlook=true, DavMail pops a browser window to login.microsoftonline.com.
# You log in there using your EXISTING browser session (already signed into
# outlook.com -> basically one click / consent), DavMail captures the OAuth
# token and persists it to davmail.oauth.tokenFilePath and refreshes it
# automatically thereafter. It does NOT read tokens out of the browser's
# cookie store; it drives its own OAuth handshake through the browser.
#
# neomutt then talks plain IMAP to 127.0.0.1:1143 / SMTP to 127.0.0.1:1025
# (see accounts/outlook.muttrc). Host-local like the Proton bridge: the
# token lives on this host only, so this is floki-only for now.
{
  services.davmail = {
    enable = true;
    # Present as Outlook so Microsoft's modern-auth OAuth client id is used
    # (personal outlook.com requires the OAuth2 modern-auth path).
    imitateOutlook = true;
    settings = {
      "davmail.mode" = "auto"; # EWS + OAuth2, browser-driven login
      "davmail.url" = "https://outlook.office365.com/EWS/Exchange.asmx";
      # Local listeners. NOT the DavMail defaults (1143/1025) -- the
      # ProtonMail bridge already owns those on this host, so DavMail gets
      # its own range. DavMail rejects -1 ("Port out of range"), so every
      # listener gets a real free port even the ones neomutt doesn't use
      # (CalDAV/POP/LDAP), all on loopback. neomutt uses IMAP 1243 + SMTP
      # 1125 (see accounts/outlook.muttrc); the rest just avoid collisions.
      "davmail.imapPort" = 1243;
      "davmail.smtpPort" = 1125;
      "davmail.caldavPort" = 1180;
      "davmail.popPort" = 1210;
      "davmail.ldapPort" = 1489;
      # Bind to loopback only -- never expose the gateway off-box.
      "davmail.bindAddress" = "127.0.0.1";
      "davmail.allowRemote" = false;
      # Persist the OAuth refresh token out of the Nix store (the module
      # already defaults this to xdg.stateHome, kept explicit for clarity).
      "davmail.oauth.tokenFilePath" = "${config.xdg.stateHome}/davmail-tokens";
      "davmail.smtpSaveInSent" = true;
    };
  };
}
