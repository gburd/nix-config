{ pkgs, ... }:
{
  programs.browserpass.enable = true;
  programs.firefox = {
    enable = true;

    package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
      extraPolicies = {
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFirefoxAccounts = false;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        OfferToSaveLoginsDefault = false;
        PasswordManagerEnabled = false;
        FirefoxHome = {
          Search = true;
          Pocket = false;
          Snippets = false;
          TopSites = false;
          Highlights = false;
        };
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
        };
      };
    };

    profiles.gburd = {
      id = 0;
      bookmarks = { };
      extensions = with pkgs.inputs.firefox-addons; [
        #        autoplay-no-more
        bypass-paywalls-clean
        i-dont-care-about-cookies
        #        kagi-search-for-firefox
        clearurls
        decentraleyes
        disconnect
        duckduckgo-privacy-essentials
        floccus
        ghostery
        #        https-everywhere
        #        languagetool
        #        onetab
        privacy-badger
        privacy-badger
        privacy-redirect
        proton-pass
        react-devtools
        ublock-origin
      ];
      search = {
        force = true;
        default = "Kagi";
        engines = {
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };
          "NixOS Wiki" = {
            urls = [{ template = "https://nixos.wiki/index.php?search={searchTerms}"; }];
            iconUpdateURL = "https://nixos.wiki/favicon.png";
            updateInterval = 24 * 60 * 60 * 1000;
            definedAliases = [ "@nw" ];
          };
          "Wikipedia (en)".metaData.alias = "@wiki";
          "Google".metaData.hidden = true;
          "Amazon.com".metaData.hidden = true;
          "Bing".metaData.hidden = true;
          "eBay".metaData.hidden = true;
        };
      };
      extraConfig = ''
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
        user_pref("full-screen-api.ignore-widgets", true);
        user_pref("media.ffmpeg.vaapi.enabled", true);
        user_pref("media.rdd-vpx.enabled", true);
      '';
      userChrome = ''
        # a css
      '';
      userContent = ''
        # Here too
      '';
      settings = {
        "general.smoothScroll" = true;
        "browser.disableResetPrompt" = true;
        "browser.download.panel.shown" = true;
        "browser.download.useDownloadDir" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.shell.defaultBrowserCheckCount" = 1;
        "browser.startup.homepage" = "about:blank";
        "browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"nav-bar":["back-button","forward-button","stop-reload-button","home-button","urlbar-container","downloads-button","library-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["import-button","personal-bookmarks"]},"seen":["save-to-pocket-button","developer-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","widget-overflow-fixed-list"],"currentVersion":18,"newElementCount":4}'';
        "dom.security.https_only_mode" = true;
        "identity.fxaccounts.enabled" = false;
        "privacy.trackingprotection.enabled" = true;
        "signon.rememberSignons" = false;
      };
    };
  };

  home = {
    persistence = {
      # Not persisting is safer, but... <shrug>
      "/persist/home/gburd".directories = [ ".mozilla/firefox" ];
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "firefox.desktop" ];
    "text/xml" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };
}
