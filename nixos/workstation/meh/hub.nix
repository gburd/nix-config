# Git hub on meh: bare repos at gburd@meh:~/hub/<repo>.git, until the NAS is
# healthy (then this moves to the NAS; clients only know `hub.url`).
#
# Every host pushes its branches to refs/hosts/<host>/* (its own namespace,
# force-updates allowed there) and may fast-forward shared branches; the
# pre-receive hook refuses anything else. Repos are created on first push by
# `hub-init <name>` (run by the client's `hub-push`), and are covered by meh's
# existing borgmatic run (/home/gburd).
{ pkgs, ... }:
let
  preReceive = pkgs.writeShellScript "hub-pre-receive" (builtins.readFile ./hub/pre-receive);
  hubInit = pkgs.writeShellScriptBin "hub-init" ''
    # hub-init <name>: create ~/hub/<name>.git if missing; (re)install the hook.
    set -eu
    case "$1" in */*|*..*|"") echo "hub-init: bad repo name '$1'" >&2; exit 2 ;; esac
    r="$HOME/hub/$1.git"
    [ -d "$r" ] || ${pkgs.git}/bin/git init -q --bare "$r"
    ${pkgs.git}/bin/git -C "$r" config receive.denyDeletes false
    ${pkgs.git}/bin/git -C "$r" config receive.denyNonFastForwards false
    ${pkgs.git}/bin/git -C "$r" config receive.advertisePushOptions true
    # the user's global core.hooksPath would otherwise replace hooks/ here,
    # and the namespace check would silently never run
    ${pkgs.git}/bin/git -C "$r" config core.hooksPath hooks
    ln -sfn ${preReceive} "$r/hooks/pre-receive"
  '';
in
{
  environment.systemPackages = [ hubInit ];
  systemd.tmpfiles.rules = [ "d /home/gburd/hub 0750 gburd users -" ];
  # Re-point every repo's hook at the current store path after a switch.
  system.activationScripts.hub-hooks.text = ''
    for r in /home/gburd/hub/*.git; do
      [ -d "$r/hooks" ] && ln -sfn ${preReceive} "$r/hooks/pre-receive"
    done
    true
  '';
}
