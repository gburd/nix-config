{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.pi;
  inherit (lib) mkEnableOption mkOption types;

  settingsJson = builtins.toJSON {
    lastChangelogVersion = "0.74.0";
    defaultProvider = "amazon-bedrock";
    defaultModel = cfg.defaultModel;
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
    extensions = [ ];
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
        # Source Bedrock auth token if available
        if [ -r "$HOME/.config/claude-code/.bearer_token" ]; then
          export AWS_BEARER_TOKEN_BEDROCK="$(cat "$HOME/.config/claude-code/.bearer_token")"
        fi
        export AWS_REGION="''${AWS_REGION:-us-east-2}"
        exec ${pkgs.nodejs}/bin/npx -y @earendil-works/pi-coding-agent "$@"
      '')
    ];

    home.file = {
      ".pi/agent/settings.json".text = settingsJson;
      ".pi/agent/auth.json".text = "{}";
    };
  };
}
