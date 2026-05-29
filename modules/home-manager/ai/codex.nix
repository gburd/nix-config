{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.codex;
  inherit (lib) mkEnableOption mkOption types;

  # Codex uses TOML for MCP config in ~/.codex/config.toml
  # Format: [mcp_servers.<name>] with command/args/env fields
  configToml = ''
    # Codex configuration — managed by home-manager
    model = "${cfg.defaultModel}"
    model_reasoning_effort = "high"
    approval_mode = "auto-edit"

    [mcp_servers.memelord]
    command = "${pkgs.memelord or pkgs.writeShellScript "memelord-stub" "exec npx -y memelord \"$@\""}/bin/memelord"
    args = ["serve"]
    enabled = true

    [mcp_servers.postgresq]
    url = "https://pg.ddx.io/mcp/"
    enabled = true

    [mcp_servers.context7]
    command = "npx"
    args = ["-y", "@upstash/context7-mcp@latest"]
    enabled = true

    [mcp_servers.memory]
    command = "npx"
    args = ["-y", "@modelcontextprotocol/server-memory"]
    enabled = true

    [mcp_servers.git]
    command = "${pkgs.uv}/bin/uvx"
    args = ["--from", "mcp-server-git", "mcp-server-git"]
    enabled = true

    [mcp_servers.sequential-thinking]
    command = "npx"
    args = ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    enabled = true
  '';
in
{
  options.programs.ai.codex = {
    enable = mkEnableOption "OpenAI Codex agent configuration";

    defaultModel = mkOption {
      type = types.str;
      default = "us.anthropic.claude-opus-4-8";
      description = "Default model for Codex";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = {
      ".codex/config.toml".text = configToml;
      # Instructions deployed by steering.nix
      # Skills deployed by skills.nix
    };
  };
}
