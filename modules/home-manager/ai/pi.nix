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
    # Pi's client-side thinking toggle. The ACTUAL thinking is driven
    # server-side by the proxy's thinking_normalizer.py, which
    # unconditionally rewrites every request to each model's policy
    # (adaptive + output_config.effort=xhigh for Opus 4.6+/4.8) — so
    # whatever level Pi sends is overridden to max effort anyway.
    #
    # We set this to "xhigh" (not the old "off") so Pi's UI honestly
    # reflects that thinking is on at max. The old reason for "off" — that
    # Pi's legacy `thinking.type.enabled` payload made Opus 4.7+ 400 — no
    # longer applies: the normalizer now CONVERTS that legacy shape into
    # `thinking.type.adaptive` + effort before it reaches Bedrock (verified
    # HTTP 200), so sending a real level is safe.
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

        # Defensively unset any residual Bedrock / Anthropic plumbing
        # that could short-circuit our routing or surface stale
        # built-in providers in pi's TUI. arnold in particular had
        # `AWS_PROFILE=asbxbedrock` cached in its systemd-user
        # environment from a past manual setup; pi's built-in
        # amazon-bedrock provider would then try to initialise and
        # fail with "Region is missing" — a noisy red error in the TUI
        # even though the LiteLLM provider was the actual default.
        unset AWS_BEARER_TOKEN_BEDROCK \
              AWS_PROFILE AWS_DEFAULT_PROFILE \
              AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
              AWS_SDK_LOAD_CONFIG \
              ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL \
              CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_SKIP_BEDROCK_AUTH \
              ANTHROPIC_BEDROCK_BASE_URL

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
