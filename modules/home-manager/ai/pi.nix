{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.pi;
  inherit (lib) mkEnableOption mkOption types;

  settingsJson = builtins.toJSON {
    lastChangelogVersion = "0.74.0";
    # Route through the local LiteLLM proxy
    # (modules/home-manager/ai/litellm.nix); the litellm pi-extension
    # below registers all models the proxy exposes as one provider.
    inherit (cfg) defaultProvider defaultModel;
    # Pi's own thinking-level toggle. With LiteLLM in front, thinking is
    # driven entirely by the proxy's server-side `output_config.effort`
    # (xhigh by default for all Anthropic models in litellm.nix). Pi must
    # NOT send the legacy `thinking.type.enabled` payload field that
    # LiteLLM maps `xhigh` to client-side — Opus 4.7+ rejects it with
    # 400 "thinking.type.enabled is not supported for this model. Use
    # thinking.type.adaptive and output_config.effort". So we set pi's
    # client-side level to "off"; the server-side adaptive thinking still
    # applies and we get max-effort by default.
    defaultThinkingLevel = "off";
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
    # All `litellm:*` ids the proxy exposes are enabled. The dynamic
    # extension below registers each one with metadata derived from the
    # model id, so we don't need to keep a parallel list here. We omit
    # the enabledModels filter entirely: pi applies that filter against
    # built-in providers BEFORE extensions register theirs, so any value
    # here either over-restricts (drops everything) or is misleadingly
    # ineffective.
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
      # LiteLLM alias (see modules/home-manager/ai/litellm.nix). Resolves
      # to bedrock/converse/us.anthropic.claude-opus-4-8 on the proxy
      # side with output_config.effort=xhigh. Pi's defaultModel is
      # provider-scoped (no `provider:` prefix), so just "claude-opus-4-8".
      default = "claude-opus-4-8";
      description = "Default model id for Pi (resolved within defaultProvider).";
    };

    defaultProvider = mkOption {
      type = types.str;
      default = "litellm";
      description = ''
        Default Pi provider. The custom 'litellm' provider is registered
        by the bundled pi-extensions/litellm.ts at startup. Change this
        only if you want Pi to default to a different built-in provider
        (e.g. anthropic) for some reason.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "pi" ''
        # Pi's launcher — no Bedrock env vars exported here. Auth is via
        # the per-host LiteLLM virtual key in
        # ~/.config/litellm/keys/pi.key, picked up by the litellm.ts
        # extension at startup. The local LiteLLM proxy holds the actual
        # AWS bearer token; pi never sees it.

        # Telemetry hardening: disable the anonymous install/update ping
        # to pi.dev (belt-and-suspenders with enableInstallTelemetry=false
        # in settings.json).
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
      ".pi/agent/extensions/litellm.ts".source = ./pi-extensions/litellm.ts;
      ".pi/agent/extensions/project-context.ts".source = ./pi-extensions/project-context.ts;
      ".pi/agent/extensions/safety-hooks.ts".source = ./pi-extensions/safety-hooks.ts;
    };
  };
}
