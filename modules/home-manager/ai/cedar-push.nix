# Push nix-config's Cedar policy set to the shared cedar-store whenever this
# host's home-manager generation changes it, so a switch on any host that
# enables this (floki, werk, meh) updates the store, not only meh's NixOS
# switch. The store validates a set before it replaces the old one; a rejected
# set fails this unit and the old set keeps serving.
#
#   programs.ai.cedarPush = { enable = true; tokenFile = <sops path>; };
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.cedarPush;
  policies = import ./cedar-policies.nix { inherit lib; };
  policyFile = pkgs.writeText "cedar-policies.cedar" policies.text;
  push = pkgs.writeShellScript "cedar-store-push" ''
    set -eu
    url=${lib.escapeShellArg cfg.url}
    tok=$(cat ${lib.escapeShellArg cfg.tokenFile})
    # the store may be restarting (meh switching at the same moment)
    for i in $(seq 1 12); do
      if ${pkgs.curl}/bin/curl -fsS --max-time 20 -X PUT \
          -H "Authorization: Bearer $tok" \
          --data-binary @${policyFile} "$url/v1/policies/text"; then
        echo; exit 0
      fi
      sleep 10
    done
    echo "cedar-store-push: store at $url did not accept the set" >&2
    exit 1
  '';
in
{
  options.programs.ai.cedarPush = {
    enable = lib.mkEnableOption "pushing the Cedar policy set to cedar-store on switch";
    url = lib.mkOption {
      type = lib.types.str;
      default = "http://meh.ts.burd.me:8180";
      description = "cedar-store base URL.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = "File holding the cedar-store write token.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.cedar-store-push = {
      Unit = {
        Description = "Push the nix-config Cedar policy set to cedar-store";
        After = [ "network-online.target" ];
        # A changed set is a new store path, so HM restarts this on switch.
        X-Restart-Triggers = [ "${policyFile}" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${push}";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
