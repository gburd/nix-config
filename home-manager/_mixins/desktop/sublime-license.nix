{ config, lib, inputs, ... }:
# Shared Sublime Text + Sublime Merge license deployment.
#
# Both licenses live as home-manager sops secrets (text format — the
# "----- BEGIN LICENSE -----" form that current Sublime builds accept;
# the older binary "FLOG" blob is rejected by Sublime Merge >= 2102) in
# floki's secrets.yaml, which is encrypted to the gburd-user age key and
# therefore also decryptable on arnold (which reuses that same file).
#
# Each license is symlinked into the app's Local/ dir as
# License.sublime_license, which is exactly where Sublime Text 4 and
# Sublime Merge look for a registered license.
let
  textTarget = "${config.home.homeDirectory}/.config/sublime-text/Local/License.sublime_license";
  mergeTarget = "${config.home.homeDirectory}/.config/sublime-merge/Local/License.sublime_license";

  linkLicense = name: secretAttr: target: lib.mkIf (config.sops.secrets ? ${secretAttr}) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      LICENSE="${config.sops.secrets.${secretAttr}.path}"
      TARGET="${target}"
      if [ -f "$LICENSE" ]; then
        mkdir -p "$(dirname "$TARGET")"
        # Replace any prior file/symlink (e.g. a stale binary-format license).
        if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
          rm -f "$TARGET"
        fi
        ln -sf "$LICENSE" "$TARGET"
        echo "Linked ${name} license to $TARGET"
      else
        echo "Warning: ${name} license not found at $LICENSE"
      fi
    ''
  );
in
{
  sops = {
    defaultSopsFile = lib.mkDefault "${inputs.self}/nixos/workstation/floki/secrets.yaml";
    secrets = {
      "sublime/text-license" = {
        path = "${config.home.homeDirectory}/.config/sublime-text-license.txt";
      };
      "sublime/merge-license" = {
        path = "${config.home.homeDirectory}/.config/sublime-merge-license.txt";
      };
    };
  };

  home.activation.linkSublimeTextLicense =
    linkLicense "Sublime Text" "sublime/text-license" textTarget;
  home.activation.linkSublimeMergeLicense =
    linkLicense "Sublime Merge" "sublime/merge-license" mergeTarget;
}
