{ config, lib, pkgs, ... }:
# Shared Cedar policy store for every agent (maki `[cedar] agent_url`, the pi
# cedar extension), the companion to ./agent-memory.nix. Runs on meh for now,
# moves to the NAS once its pool is healthy.
#
# Reads (GET /v1/policies, POST /v1/is_authorized) are open on the tailnet so
# maki needs no token; writes need the sops token, so no agent can widen its
# own permissions. The policy set is generated in nix-config
# (modules/home-manager/ai/cedar-policies.nix) and pushed on every switch, so
# the repo, not the running store, is the source of truth.
let
  cfg = config.services.cedarStore;
  stateDir = "/var/lib/cedar-store";
  policies = import ../../../modules/home-manager/ai/cedar-policies.nix { inherit lib; };
  policyFile = pkgs.writeText "policies.cedar" policies.text;
  schemaFile = ../../../pkgs/cedar-store/maki.cedarschema;
in
{
  options.services.cedarStore = {
    enable = lib.mkEnableOption "the shared Cedar policy store for agents";
    listenAddress = lib.mkOption {
      type = lib.types.str;
      description = "Address to listen on (the tailnet IP).";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8180;
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."cedar-store/token" = {
      sopsFile = ./secrets.yaml;
      owner = "cedar-store";
      restartUnits = [ "cedar-store.service" ];
    };

    users.users.cedar-store = {
      isSystemUser = true;
      group = "cedar-store";
      home = stateDir;
    };
    users.groups.cedar-store = { };

    systemd.services.cedar-store = {
      description = "Shared Cedar policy store (cedar-agent API)";
      wantedBy = [ "multi-user.target" ];
      # Bind needs the tailnet address to exist.
      after = [ "tailscaled.service" "tailscale-autoconnect.service" "sops-nix.service" "network-online.target" ];
      wants = [ "tailscaled.service" "network-online.target" ];
      environment = {
        CEDAR_STORE_ADDR = "${cfg.listenAddress}:${toString cfg.port}";
        CEDAR_STORE_STATE = "${stateDir}/policies.json";
        CEDAR_STORE_SCHEMA = "${schemaFile}";
        CEDAR_STORE_TOKEN_FILE = config.sops.secrets."cedar-store/token".path;
      };
      serviceConfig = {
        ExecStart = lib.getExe pkgs.cedar-store;
        # Push the repo's policy set once the listener is up. A rejected set
        # (parse or schema error) fails the unit and the old set keeps serving.
        ExecStartPost = pkgs.writeShellScript "cedar-store-load" ''
          set -eu
          url=http://${cfg.listenAddress}:${toString cfg.port}
          for _ in $(seq 1 30); do
            ${pkgs.curl}/bin/curl -fsS "$url/health" >/dev/null 2>&1 && break
            sleep 1
          done
          tok=$(cat "$CEDAR_STORE_TOKEN_FILE")
          ${pkgs.curl}/bin/curl -fsS -X PUT \
            -H "Authorization: Bearer $tok" \
            --data-binary @${policyFile} "$url/v1/policies/text"
          echo
        '';
        User = "cedar-store";
        Group = "cedar-store";
        StateDirectory = "cedar-store";
        StateDirectoryMode = "0750";
        Restart = "on-failure";
        RestartSec = "5s";
        # Sandbox: it only needs its state dir and the network.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallFilter = [ "@system-service" "~@privileged" ];
      };
      # A new policy set (changed nix-config) means a new ExecStartPost path,
      # which restarts the unit on switch and reloads the policies.
      restartTriggers = [ policyFile ];
    };
  };
}
