{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.pi;
  inherit (lib) mkEnableOption mkOption types;

  settingsJson = builtins.toJSON {
    lastChangelogVersion = "0.74.0";
    defaultProvider = "amazon-bedrock";
    inherit (cfg) defaultModel;
    # "ultra" high thinking == pi's top thinking level (off/minimal/low/
    # medium/high/xhigh). xhigh is the max and what the user wants by default.
    defaultThinkingLevel = "xhigh";
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
      "us.anthropic.claude-sonnet-4-6"
      "us.anthropic.claude-opus-4-1-*"
      "us.anthropic.claude-opus-4-7"
      "us.anthropic.claude-opus-4-8"
      "us.anthropic.claude-haiku-4-5-*"
      "deepseek.v3.2"
      "us.deepseek.r1-v1:0"
      # DeepSeek V3.2 is the newest DeepSeek on Bedrock as of 2026-05-29
      # (on-demand, verified working with the bearer token). Upstream has
      # since shipped DeepSeek V4 (Pro & Flash, ~2026-05-06) but AWS has not
      # onboarded it yet. TODO: when `aws bedrock list-foundation-models`
      # shows a deepseek.v4* id (likely `deepseek.v4-pro` or similar), add it
      # here — e.g. "deepseek.v4-pro" (and/or "us.deepseek.v4-pro-*" if it is
      # inference-profile-only). Check with:
      #   aws bedrock list-foundation-models --region us-east-1 \
      #     | jq -r '.modelSummaries[].modelId | select(test("deepseek"))'
    ];
    skills = [ "~/.kiro/skills" ];
    prompts = [ "~/.pi/agent/prompts" ];
    extensions = [ "~/.pi/agent/extensions" ];
    themes = [ ];
    packages = [
      "npm:@gotgenes/pi-subagents"
      "npm:pi-mcp-adapter"
      "npm:pi-skillful"
    ];
    enableSubAgents = true;
    enableSkillCommands = true;
  };
in
{
  options.programs.ai.pi = {
    enable = mkEnableOption "Pi coding agent configuration";

    defaultModel = mkOption {
      type = types.str;
      default = "us.anthropic.claude-opus-4-8";
      description = "Default model for Pi provider";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "pi" ''
        # Source Bedrock bearer token from sops-decrypted secret
        if [ -r "$HOME/.config/claude-code/.bearer_token" ]; then
          export AWS_BEARER_TOKEN_BEDROCK="$(cat "$HOME/.config/claude-code/.bearer_token")"
          # Prevent SigV4 credential chain from conflicting with bearer token auth
          unset AWS_PROFILE AWS_DEFAULT_PROFILE \
                AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
                AWS_SDK_LOAD_CONFIG
        fi
        export AWS_REGION="''${AWS_REGION:-us-east-1}"

        # Telemetry hardening: disable the anonymous install/update ping to
        # pi.dev (belt-and-suspenders with enableInstallTelemetry=false).
        export PI_TELEMETRY=0

        # npm global prefix must be writable (Nix store is read-only)
        export NPM_CONFIG_PREFIX="''${HOME}/.npm-global"
        mkdir -p "$NPM_CONFIG_PREFIX"

        exec ${pkgs.nodejs}/bin/npx -y @earendil-works/pi-coding-agent "$@"
      '')
    ];

    home.file = {
      ".pi/agent/settings.json".text = settingsJson;
      ".pi/agent/auth.json".text = "{}";
      # Steering prompts deployed by steering.nix (all 7 files to ~/.pi/agent/prompts/)
      # Extensions that use only public Pi API and node builtins
      ".pi/agent/extensions/coccinelle.ts".source = ./pi-extensions/coccinelle.ts;
      ".pi/agent/extensions/context-monitor.ts".source = ./pi-extensions/context-monitor.ts;
      ".pi/agent/extensions/project-context.ts".source = ./pi-extensions/project-context.ts;
      ".pi/agent/extensions/safety-hooks.ts".source = ./pi-extensions/safety-hooks.ts;
    };
  };
}
