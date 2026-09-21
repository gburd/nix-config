# fx — Vercel Labs' native coding agent (https://fx.sh/), routed through the
# per-host LiteLLM proxy like every other agent here.
#
# ⚠️ EXPERIMENTAL UPSTREAM. fx is v0.0.x and self-describes as "experimental
# (use at your own risk, we will be making frequent changes)". Worse, the
# `providers` custom-model-connection block this module writes is a documented
# *preview* feature ("do not assume an installed release supports these
# settings"). So: if fx stops honouring settings.json, or the schema moves,
# that's expected churn -- check `fx status --json` and confirm
# provider_endpoint is our proxy before assuming routing works.
#
# Parity with pi/claude/maki/kiro:
#   - models   : the LiteLLM proxy (OpenAI /v1 chat-completions protocol),
#                per-agent virtual key from ~/.config/litellm/keys/fx.key
#   - steering : ~/.fx/AGENTS.md (fx reads project/global instructions)
#   - MCP      : ~/.fx/settings.json mcpServers, from the shared mcps.nix set
#   - skills   : ~/.fx/skills (fx supports skills; shared operator set)
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.fx;
  inherit (lib) mkEnableOption mkOption types;
  litellmKey = "${config.home.homeDirectory}/.config/litellm/keys/fx.key";
in
{
  options.programs.ai.fx = {
    enable = mkEnableOption "fx (Vercel Labs native coding agent) via the local LiteLLM proxy";

    package = mkOption {
      type = types.package;
      default = pkgs.fx-agent;
      defaultText = lib.literalExpression "pkgs.fx-agent";
      description = "The fx package (pkgs/fx-agent; named fx-agent to avoid nixpkgs' fx JSON viewer).";
    };

    defaultModel = mkOption {
      type = types.str;
      # Same default as pi/claude/maki: the 1M-window Opus 5 on Bedrock via the
      # proxy. NOT gpt-6-astra -- its ~256K window wedges long sessions.
      default = "claude-opus-5";
      description = "Model id fx requests from the LiteLLM proxy.";
    };

    providerName = mkOption {
      type = types.str;
      default = "litellm";
      description = ''
        Name of the custom model connection in ~/.fx/settings.json. Select it
        with `fx provider litellm` (or FX_PROVIDER=litellm for one process).
      '';
    };

    baseUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:4000/v1";
      description = ''
        LiteLLM proxy endpoint. fx's openai-chat-completions protocol posts to
        <base_url>/chat/completions, so this includes the /v1 prefix.
      '';
    };

    mcpServers = mkOption {
      type = types.attrs;
      default =
        let m = config.programs.ai.mcps;
        in if (m.enable or false) && (m.targets.fx or false) then m.coreServers else { };
      defaultText = lib.literalExpression
        "programs.ai.mcps.coreServers (when mcps.enable && mcps.targets.fx)";
      description = ''
        MCP servers to declare in ~/.fx/settings.json. Defaults to the shared
        CORE set published by mcps.nix, so fx gets the same servers as
        pi/claude/kiro/maki.
      '';
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra keys merged into ~/.fx/settings.json.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # ONLY the launcher -- deliberately NOT cfg.package as well. The wrapper
      # execs ${cfg.package}/bin/fx by absolute store path, so the package stays
      # in the closure through that reference; adding it to home.packages too
      # puts two different bin/fx into the profile and buildEnv fails with
      # "two given paths contain a conflicting subpath".
      #
      # Launcher: export the proxy's per-agent virtual key into the env var the
      # settings.json connection names, and strip stray provider creds so fx
      # can't silently fall back to Vercel AI Gateway / a subscription login.
      (pkgs.writeShellScriptBin "fx" ''
        if [ ! -r "${litellmKey}" ]; then
          echo "fx: ${litellmKey} not readable; is litellm.service running?" >&2
          exit 78 # EX_CONFIG
        fi
        FX_LITELLM_API_KEY="$(${pkgs.coreutils}/bin/cat "${litellmKey}")"
        export FX_LITELLM_API_KEY

        # Keep fx on our proxy: unset anything that could select another
        # provider or leak Bedrock/Anthropic creds into it.
        unset AWS_BEARER_TOKEN_BEDROCK \
              AWS_PROFILE AWS_DEFAULT_PROFILE \
              AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
              ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL \
              OPENAI_API_KEY OPENAI_BASE_URL \
              VERCEL_OIDC_TOKEN AI_GATEWAY_API_KEY

        # Select our connection unless the caller asked for another.
        export FX_PROVIDER="''${FX_PROVIDER:-${cfg.providerName}}"
        export FX_MODEL="''${FX_MODEL:-${cfg.defaultModel}}"

        # Strip LD_PRELOAD: a project devshell's allocator/sanitizer interposer
        # breaks agent runtimes (same guard as pi/claude/maki).
        unset LD_PRELOAD

        exec ${cfg.package}/bin/fx "$@"
      '')
    ];

    home.file = {
      # Private profile. fx requires connection definitions at the TOP LEVEL of
      # ~/.fx/settings.json (not a repo .fx.json / nested workspace).
      ".fx/settings.json".text = builtins.toJSON (
        {
          providers.${cfg.providerName} = {
            protocol = "openai-chat-completions";
            base_url = cfg.baseUrl;
            # Bearer creds come from the NAMED env var, not the file -- the key
            # never enters the Nix store. The launcher above exports it.
            auth = {
              type = "bearer";
              env = "FX_LITELLM_API_KEY";
            };
          };
          models.${cfg.providerName} = cfg.defaultModel;
        }
        // lib.optionalAttrs (cfg.mcpServers != { }) { inherit (cfg) mcpServers; }
        // cfg.extraSettings
      );
    };
  };
}
