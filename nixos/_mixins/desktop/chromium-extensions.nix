# Chrome/Chromium extension pins for ungoogled-chromium.
#
# WHY THIS FILE EXISTS. ungoogled-chromium strips Chrome Web Store
# integration, so the usual `programs.chromium.extensions = [ "<id>" ]`
# force-install (which fetches from Google's update server) does nothing.
# The NixOS chromium module supports an alternate form, "<id>;<update-xml-url>",
# which points the ExtensionInstallForcelist policy at a SELF-HOSTED update
# manifest. We fetch each CRX at a pinned version/hash into the store and
# generate a local update manifest per extension, so extensions install on
# ungoogled-chromium with no Web Store and no network at browser start.
#
# HOW TO UPDATE. Run `update-chromium-extensions` (installed by
# desktop/ungoogled-chromium.nix, also wired to a CI workflow). It queries
# Google's update service for each id, resolves the current version from the
# CRX redirect URL, prefetches the hash, and rewrites this file. Then rebuild.
# Extensions therefore update when you refresh + switch, not silently in the
# background -- the tradeoff for reproducible, hash-verified pins.
#
# The set mirrors what's installed in Google Chrome (enumerated from
# ~/.config/google-chrome/Default/Extensions).
{
  "cdglnehniifkbagbbombnjghhcihifij" = { name = "Kagi Search"; version = "1.2.2.5"; sha256 = "sha256-weiUUUiZeeIlz/k/d9VDSKNwcQtmAahwSIHt7Frwh7E="; };
  "chphlpgkkbolifaimnlloiipkdnihall" = { name = "OneTab"; version = "2.21.0.0"; sha256 = "sha256-jCjPqfSn5su3J7AESK5YD7o3I6X6YStG+PlCmp0Qd2o="; };
  "ddkjiahejlhfcafbddmgiahcphecmpfh" = { name = "uBlock Origin Lite"; version = "2026.920.1710.0"; sha256 = "sha256-8I+FQ79dby6znBSfA7cRlNhYCTVOkLsIdhHNerGhhGo="; };
  "dhdgffkkebhmkfjojejmpbldmpobfkfo" = { name = "Tampermonkey"; version = "5.5.0.0"; sha256 = "sha256-vK7AgsQ54RxN9oP0PQfprD1EOSUdcrkcW0Uvl32sFdU="; };
  "dokcepkiahcpognlgpeeiompfhcleagb" = { name = "TradingView"; version = "2.1.0.0"; sha256 = "sha256-aNnFonP+FyyNBsSzBAEEZWmqX+/kHgVqDYoyd435Vug="; };
  "edlifbnjlicfpckhgjhflgkeeibhhcii" = { name = "Screenshot Tool"; version = "1.0.10.0"; sha256 = "sha256-x5ptjrxCdtjlo0hB8L/9w1xFJekLyiqBHsTku/pDbgQ="; };
  "gebbhagfogifgggkldgodflihgfeippi" = { name = "Return YouTube Dislike"; version = "4.0.5.0"; sha256 = "sha256-orlCwWL0GeALQYCMxrHd71wpOWNVupLk0VrtQcxYtUk="; };
  "hjdoplcnndgiblooccencgcggcoihigg" = { name = "Terms of Service; Didn't Read"; version = "5.1.1.0"; sha256 = "sha256-fSVeehqv0ydPf8o3Q45MPJxu0xS/wDi54Q90lnnyVCc="; };
  "kbfnbcaeplbcioakkpcpgfkobkghlhen" = { name = "Grammarly"; version = "14.1331.0.0"; sha256 = "sha256-feGp/IJ3mi4um1UH+r3aMRVG4qokcZeRkb3sppo85pY="; };
  "khgocmkkpikpnmmkgmdnfckapcdkgfaf" = { name = "1Password Beta"; version = "8.12.38.26"; sha256 = "sha256-MI0CjuqIoc69O+yNe956xkD2LWkcIRygJ5lMkFDMc8M="; };
  "mdjildafknihdffpkfmmpnpoiajfjnjd" = { name = "Consent-O-Matic"; version = "1.1.3.0"; sha256 = "sha256-qdMdkakBMffTyrLcPjN+Q/dfTyto5/3oEuDNJKgTvpg="; };
  "mnjggcdmjocbbbhaepdhchncahnbgone" = { name = "SponsorBlock for YouTube"; version = "6.1.6.0"; sha256 = "sha256-VYf+K2qZRhAcoN3nxu/nanVcXuW21uY9/EjH9zbNtP8="; };
  "ofpnikijgfhlmmjlpkfaifhhdonchhoi" = { name = "Accept all cookies"; version = "1.0.4.0"; sha256 = "sha256-AUgYkFXp7+GiLqrVWb5IOUMT/IHqYCdat7rT2mMzO0A="; };

  # Deliberately NOT mirrored from Chrome (Google-service or host-app tied,
  # pointless in a de-Googled browser or requires the desktop app):
  #   ghbmnnjooekpmoecnnnilnnbdlolhkhi  Google Docs Offline
  #   mmimngoggfoobjdlefbcabngfnmieonb  Google Play Books
  #   nmmhkkegccagdldgiimedpiccmgmieda  Chrome Web Store Payments
  #   hmbjbjdpkobdjplfobhljndfdfdipjhg  Zoom      (needs the Zoom desktop app)
  #   jeogkiiogjbmhklcnbgkdcjoioegiknm  Slack     (needs the Slack desktop app)
  # Add any of these here if you actually want them.
}
