{ config, lib, pkgs, ... }:
# Shared agent memory: one doobidoo/mcp-memory-service for every host's
# agents, replacing memelord's per-project Turso files (which corrupt under
# any reader but memelord and cannot be synced). See
# ~/ws/nix-config/.agent/infra-plan.md.
#
# Runs on meh for now; moves to the NAS once its pool is healthy. Clients
# reach it at http://meh.ts.burd.me:8765/mcp over the tailnet only, with
# `Authorization: Bearer <agent-memory/api-key>`.
let
  cfg = config.services.agentMemory;
  # Pinned by digest (12.4.0-slim, linux/amd64 index, 2026-10-26).
  image = "doobidoo/mcp-memory-service@sha256:fd97a56818df70fc1107ce49143a0dc324e10be9176c91a3111648f99e3fc46f";
  dataDir = "/var/lib/agent-memory";
in
{
  options.services.agentMemory = {
    enable = lib.mkEnableOption "the shared mcp-memory-service for agents";
    listenAddress = lib.mkOption {
      type = lib.types.str;
      description = "Address to publish the service on (the tailnet IP).";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8765;
    };
    backupDir = lib.mkOption {
      type = lib.types.str;
      description = ''
        Directory for the nightly consistent copy of the DB. Must be inside a
        borgmatic source (e.g. under /home/gburd), since /var is not backed up.
      '';
    };
    backupOwner = lib.mkOption {
      type = lib.types.str;
      default = "gburd";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."agent-memory/api-key" = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "docker-agent-memory.service" ];
    };
    sops.templates."agent-memory.env" = {
      content = "MCP_API_KEY=${config.sops.placeholder."agent-memory/api-key"}\n";
      restartUnits = [ "docker-agent-memory.service" ];
    };

    systemd.tmpfiles.rules = [
      # uid 1000 inside the container (it ships no user; root's HOME is 0700)
      "d ${dataDir} 0750 1000 100 -"
      "d ${dataDir}/home 0750 1000 100 -"
      "d ${dataDir}/db 0750 1000 100 -"
      "d ${dataDir}/backups 0750 1000 100 -"
    ];

    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.agent-memory = {
      inherit image;
      user = "1000:100";
      ports = [ "${cfg.listenAddress}:${toString cfg.port}:8000" ];
      environmentFiles = [ config.sops.templates."agent-memory.env".path ];
      environment = {
        MCP_MODE = "http";
        MCP_HTTP_HOST = "0.0.0.0";
        MCP_HTTP_PORT = "8000";
        MCP_ALLOW_ANONYMOUS_ACCESS = "false";
        MCP_MEMORY_STORAGE_BACKEND = "sqlite_vec";
        MCP_MEMORY_SQLITE_PATH = "/data/db/memory.db";
        MCP_MEMORY_BACKUPS_PATH = "/data/backups";
        MCP_MEMORY_SQLITE_PRAGMAS = "journal_mode=WAL,busy_timeout=15000";
        # Same embedder memelord used (384-dim), so recall behaves the same.
        MCP_EMBEDDING_MODEL = "all-MiniLM-L6-v2";
        # Nothing may rewrite or forget memories on its own; the agents
        # curate them. (Consolidation is off by default; pin it.)
        MCP_CONSOLIDATION_ENABLED = "false";
        # The ONNX model is cached under $HOME/.cache on first start.
        HOME = "/data/home";
        PYTHONUNBUFFERED = "1";
      };
      volumes = [ "${dataDir}:/data" ];
      extraOptions = [ "--health-cmd=curl -fs http://127.0.0.1:8000/api/health || exit 1" "--health-interval=60s" ];
    };
    # Start only once the tailnet address exists, or the port publish fails.
    systemd.services.docker-agent-memory = {
      after = [ "tailscaled.service" "tailscale-autoconnect.service" "sops-nix.service" ];
      wants = [ "tailscaled.service" ];
      serviceConfig.RestartSec = "10s";
    };

    # Nightly consistent copy (sqlite3 .backup through the WAL) into a
    # borgmatic-covered path, before meh's 03:30 borgmatic run. This is the
    # service's own stock-SQLite (sqlite-vec) file, not memelord's Turso.
    systemd.services.agent-memory-backup = {
      description = "Copy the agent-memory DB into the borg-covered backup dir";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "agent-memory-backup" ''
          set -eu
          dst=${cfg.backupDir}
          ${pkgs.coreutils}/bin/install -d -m 0700 -o ${cfg.backupOwner} "$dst"
          tmp="$dst/memory.db.tmp"
          ${pkgs.sqlite}/bin/sqlite3 ${dataDir}/db/memory.db ".backup '$tmp'"
          ${pkgs.sqlite}/bin/sqlite3 "$tmp" "PRAGMA integrity_check" | ${pkgs.gnugrep}/bin/grep -qx ok
          ${pkgs.coreutils}/bin/chown ${cfg.backupOwner} "$tmp"
          ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
          ${pkgs.coreutils}/bin/mv -f "$tmp" "$dst/memory.db"
        '';
      };
    };
    systemd.timers.agent-memory-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:00:00";
        Persistent = true;
      };
    };
  };
}
