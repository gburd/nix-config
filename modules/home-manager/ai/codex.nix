{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.codex;
  inherit (lib) mkEnableOption mkOption types;

  # Bake absolute paths in at Nix eval time. coreutils' `cat` is the
  # auth.command codex invokes to read the local LiteLLM virtual key
  # file — this avoids a shell-PATH dependency at runtime.
  catBin = "${pkgs.coreutils}/bin/cat";
  litellmKey = "${config.home.homeDirectory}/.config/litellm/keys/codex.key";

  # Codex uses TOML; format is documented at
  #   https://developers.openai.com/codex/config-reference
  configToml = ''
    # Codex configuration — managed by home-manager. Routes through the
    # local LiteLLM proxy (modules/home-manager/ai/litellm.nix) instead
    # of talking to Bedrock directly. Auth: a per-host virtual key
    # provisioned at activation in ~/.config/litellm/keys/codex.key,
    # read fresh on every codex invocation via auth.command (no
    # secrets in the config file or in env).

    model = "${cfg.defaultModel}"
    model_provider = "${cfg.provider}"
    model_reasoning_effort = "${cfg.reasoningEffort}"
    approval_mode = "auto-edit"

    [model_providers.${cfg.provider}]
    name = "LiteLLM (local Bedrock proxy)"
    base_url = "${cfg.litellmUrl}"
    wire_api = "responses"
    auth.command = "${catBin}"
    auth.args = ["${litellmKey}"]

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
      # LiteLLM alias (see modules/home-manager/ai/litellm.nix). Resolves
      # to bedrock/converse/us.anthropic.claude-opus-4-8 with
      # output_config.effort=xhigh on the proxy side.
      default = "claude-opus-4-8";
      description = "Default LiteLLM model alias for codex.";
    };

    reasoningEffort = mkOption {
      type = types.enum [ "minimal" "low" "medium" "high" "xhigh" ];
      default = "high";
      description = ''
        Codex's model_reasoning_effort. The proxy side caps adaptive-
        thinking models (Opus 4.x) at xhigh via output_config.effort,
        so even with codex set to high, the model thinks at its
        configured ceiling on the LiteLLM side.
      '';
    };

    provider = mkOption {
      type = types.str;
      default = "local-litellm";
      description = ''
        model_providers.<id> name for codex's custom provider definition
        below. Built-in IDs (openai, ollama, lmstudio, amazon-bedrock)
        are reserved by codex and cannot be used here.
      '';
    };

    litellmUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:4000/v1";
      description = "Base URL for the local LiteLLM proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    # codex CLI itself — nixpkgs ships it as `pkgs.codex`. Without this,
    # the rendered ~/.codex/config.toml is dead bits.
    home.packages = [ pkgs.codex ];

    home.file = {
      ".codex/config.toml".text = configToml;
      # Instructions deployed by steering.nix
      # Skills deployed by skills.nix
    };
  };
}
