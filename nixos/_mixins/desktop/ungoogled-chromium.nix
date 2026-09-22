# ungoogled-chromium + declaratively-pinned extensions.
#
# Replaces the previous regular-chromium setup. nixpkgs' regular `chromium` is
# built without Google API keys, so it already had no working Web Store;
# ungoogled-chromium goes further and strips the store integration outright.
# Either way, force-install-by-bare-id cannot fetch anything, so we self-host:
# each extension's CRX is fetched at a pinned version+hash into the store, a
# local update manifest is generated beside it, and the ExtensionInstallForcelist
# policy uses the "<id>;<update-xml-url>" form to install from there.
#
# Pins live in ./chromium-extensions.nix; refresh them with
# `update-chromium-extensions` (see that file's header).
{ lib, pkgs, ... }:
let
  extensions = import ./chromium-extensions.nix;

  # Only pins that have a hash are installable; a freshly-added entry with
  # sha256 = "" is skipped (with a warning) rather than failing the build, so
  # adding an id and running the refresh script are separable steps.
  pinned = lib.filterAttrs (_: v: (v.sha256 or "") != "") extensions;
  unpinned = lib.attrNames (lib.filterAttrs (_: v: (v.sha256 or "") == "") extensions);

  # Google's update service, asked for a direct CRX download. The redirect it
  # returns embeds the version, which is what the refresh script parses. (The
  # pinned version isn't part of the request -- the service always serves
  # current; reproducibility comes from the sha256 pin, and a version bump
  # upstream shows up as a hash mismatch until the refresh script runs.)
  crxUrl = id:
    "https://clients2.google.com/service/update2/crx?response=redirect"
    + "&acceptformat=crx2,crx3&prodversion=153.0&x=id%3D${id}%26uc";

  crxFor = id: meta: pkgs.fetchurl {
    name = "chromium-extension-${id}-${meta.version}.crx";
    url = crxUrl id;
    inherit (meta) sha256;
  };

  # A minimal Omaha-style update manifest pointing at the store-resident CRX.
  # Chromium reads this via the forcelist policy instead of talking to Google.
  manifestFor = id: meta:
    let crx = crxFor id meta;
    in
    pkgs.writeText "chromium-extension-${id}-update.xml" ''
      <?xml version='1.0' encoding='UTF-8'?>
      <gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
        <app appid='${id}'>
          <updatecheck codebase='file://${crx}' version='${meta.version}' />
        </app>
      </gupdate>
    '';

  forcelistEntry = id: meta: "${id};file://${manifestFor id meta}";

  # Refresh helper: re-resolve every pinned id's current version + hash and
  # rewrite chromium-extensions.nix in place. Kept as a shell script (not a
  # flake input / IFD) so it never runs at eval time.
  updateScript = pkgs.writeShellApplication {
    name = "update-chromium-extensions";
    runtimeInputs = with pkgs; [ curl nix coreutils gnused gnugrep ];
    text = ''
      # Resolve each extension id's newest version + store hash and rewrite the
      # pin file. Safe to re-run; only changed lines are touched.
      PINS="''${1:-}"
      if [ -z "$PINS" ]; then
        # default to the file next to this repo checkout
        PINS="$PWD/nixos/_mixins/desktop/chromium-extensions.nix"
      fi
      if [ ! -f "$PINS" ]; then
        echo "pin file not found: $PINS" >&2
        echo "usage: update-chromium-extensions [path/to/chromium-extensions.nix]" >&2
        exit 2
      fi

      # Extract ids from the pin file (lines like:  "<id>" = { ... };)
      ids=$(grep -oE '^  "[a-p]{32}"' "$PINS" | tr -d ' "' || true)
      if [ -z "$ids" ]; then
        echo "no extension ids found in $PINS" >&2
        exit 1
      fi

      changed=0
      for id in $ids; do
        url="https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=153.0&x=id%3D''${id}%26uc"
        # The redirect target's filename encodes the version:
        #   <ID-UPPER>_2026_920_1710_0.crx  ->  2026.920.1710.0
        final=$(curl -sI -L --max-time 60 "$url" 2>/dev/null \
          | grep -i '^location:' | tail -n1 | tr -d '\r' | awk '{print $2}')
        if [ -z "$final" ]; then
          echo "warn: $id — no redirect (delisted? network?), leaving pin alone" >&2
          continue
        fi
        ver=$(basename "$final" .crx | sed 's/^[A-Z0-9]*_//; s/_/./g')
        if [ -z "$ver" ]; then
          echo "warn: $id — could not parse version from $final" >&2
          continue
        fi
        hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -n1 || true)
        if [ -z "$hash" ]; then
          echo "warn: $id — prefetch failed, leaving pin alone" >&2
          continue
        fi
        sri=$(nix hash to-sri --type sha256 "$hash" 2>/dev/null || echo "sha256:$hash")

        cur_ver=$(grep -E "^  \"$id\"" "$PINS" | grep -oE 'version = "[^"]*"' | cut -d'"' -f2 || true)
        if [ "$cur_ver" = "$ver" ]; then
          # still refresh the hash if it was empty (newly added id)
          if grep -E "^  \"$id\"" "$PINS" | grep -q 'sha256 = ""'; then
            sed -i "/^  \"$id\"/ s|sha256 = \"\"|sha256 = \"$sri\"|" "$PINS"
            echo "pinned  $id  $ver"
            changed=1
          else
            echo "current $id  $ver"
          fi
          continue
        fi

        sed -i "/^  \"$id\"/ s|version = \"[^\"]*\"|version = \"$ver\"|" "$PINS"
        sed -i "/^  \"$id\"/ s|sha256 = \"[^\"]*\"|sha256 = \"$sri\"|" "$PINS"
        echo "updated $id  ''${cur_ver:-none} -> $ver"
        changed=1
      done

      if [ "$changed" = 1 ]; then
        echo
        echo "pins updated in $PINS — rebuild to install:"
        echo "  sudo nixos-rebuild switch --flake .#\$(hostname)"
      else
        echo
        echo "all extension pins already current"
      fi
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.unstable.ungoogled-chromium
    updateScript
  ];

  warnings = lib.optional (unpinned != [ ])
    ("chromium-extensions.nix has unpinned entries (sha256 = \"\"), skipped: "
      + lib.concatStringsSep ", " unpinned
      + ". Run `update-chromium-extensions` to pin them.");

  programs.chromium = {
    enable = true;
    # Self-hosted update manifests -> works without the Chrome Web Store.
    extensions = lib.mapAttrsToList forcelistEntry pinned;
    extraOpts = {
      "AutofillAddressEnabled" = false;
      "AutofillCreditCardEnabled" = false;
      "BuiltInDnsClientEnabled" = false;
      "DeviceMetricsReportingEnabled" = false;
      "ReportDeviceCrashReportInfo" = false;
      "PasswordManagerEnabled" = false;
      "SpellcheckEnabled" = true;
      "SpellcheckLanguage" = [ "en-US" ];
      "VoiceInteractionHotwordEnabled" = false;
      # Hard block, not just "not installed". Deleting an extension's files and
      # prefs is NOT enough when Chrome Sync is on: the account restores it on
      # the next launch (observed live -- Grammarly reappeared, version bumped,
      # seconds after removal). Policy beats sync.
      #
      # The NixOS chromium module writes extraOpts to BOTH
      # /etc/chromium/policies/managed/ AND /etc/opt/chrome/policies/managed/,
      # so this blocks the extension in Google Chrome as well as
      # ungoogled-chromium -- which is what makes the removal stick.
      "ExtensionInstallBlocklist" = [
        "kbfnbcaeplbcioakkpcpgfkobkghlhen" # Grammarly (removed by request)
      ];
    };
  };
}
