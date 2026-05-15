{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.pi;
  inherit (lib) mkEnableOption mkOption types;

  settingsJson = builtins.toJSON {
    lastChangelogVersion = "0.74.0";
    defaultProvider = "amazon-bedrock";
    inherit (cfg) defaultModel;
    defaultThinkingLevel = "high";
    theme = "dark";
    quietStartup = false;
    enableInstallTelemetry = false;
    warnings = { anthropicExtraUsage = false; };
    compaction = {
      enabled = true;
      reserveTokens = 16384;
      keepRecentTokens = 20000;
    };
    retry = {
      enabled = true;
      maxRetries = 3;
      baseDelayMs = 2000;
    };
    enabledModels = [
      "us.anthropic.claude-sonnet-4-5-*"
      "us.anthropic.claude-opus-4-7*"
      "us.anthropic.claude-haiku-4-5-*"
    ];
    skills = [ "~/.kiro/skills" ];
    prompts = [ ];
    extensions = [ "~/.pi/agent/extensions" ];
    themes = [ ];
    packages = [ "npm:@tintinweb/pi-subagents" ];
    enableSkillCommands = true;
  };
in
{
  options.programs.ai.pi = {
    enable = mkEnableOption "Pi coding agent configuration";

    defaultModel = mkOption {
      type = types.str;
      default = "us.anthropic.claude-opus-4-7";
      description = "Default model for Pi provider";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "pi" ''
        # Source Bedrock bearer token from sops-decrypted secret
        if [ -r "$HOME/.config/claude-code/.bearer_token" ]; then
          export AWS_BEARER_TOKEN_BEDROCK="$(cat "$HOME/.config/claude-code/.bearer_token")"
        fi
        export AWS_REGION="''${AWS_REGION:-us-east-1}"

        # Prevent SigV4 credential chain from conflicting with bearer token auth
        unset AWS_PROFILE AWS_DEFAULT_PROFILE \
              AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
              AWS_SDK_LOAD_CONFIG

        exec ${pkgs.nodejs}/bin/npx -y @earendil-works/pi-coding-agent "$@"
      '')
    ];

    home.file = {
      ".pi/agent/settings.json".text = settingsJson;
      ".pi/agent/auth.json".text = "{}";
      ".pi/agent/extensions/agora-mcp.ts".source = ./pi-extensions/agora-mcp.ts;
      ".pi/agent/extensions/coccinelle.ts".source = ./pi-extensions/coccinelle.ts;
      ".pi/agent/extensions/context-monitor.ts".source = ./pi-extensions/context-monitor.ts;
      ".pi/agent/extensions/lsp.ts".source = ./pi-extensions/lsp.ts;
      ".pi/agent/extensions/memelord-mcp.ts".source = ./pi-extensions/memelord-mcp.ts;
      ".pi/agent/extensions/project-context.ts".source = ./pi-extensions/project-context.ts;
      ".pi/agent/extensions/safety-hooks.ts".source = ./pi-extensions/safety-hooks.ts;
    };
  };
}
