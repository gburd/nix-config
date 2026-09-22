# fx — Vercel Labs' native coding agent (https://fx.sh/).
#
# ⚠️ DISABLED BY DEFAULT: the released build CANNOT be routed through LiteLLM.
#
# fx v0.0.10 only supports its three built-in providers -- `fx provider` literally
# answers "usage: fx provider <gateway|codex|grok>" -- and the custom
# model-connection feature this module configures is NOT in the shipped binary.
# Verified two ways on v0.0.10:
#   * `fx status --json` reports auth "missing" with
#     auth_help "fx needs access to Vercel AI Gateway", ignoring our providers
#     block, and `fx models` lists 249 GATEWAY models rather than ours.
#   * `strings` on the binary finds AI_GATEWAY_API_KEY and "gateway|codex|grok"
#     but NO "openai-chat-completions" and NO "base_url" -- the custom-provider
#     code simply isn't compiled in. Upstream's own docs say as much:
#     "Preview build required ... do not assume an installed release supports
#     these settings."
#
# So enabling this would give a broken agent that silently tries to use Vercel
# AI Gateway (and would need a Vercel account/credits) instead of our proxy.
# The wiring is kept, ready for when a release ships the feature: flip
# programs.ai.fx.enable = true and re-check `fx status --json` shows
# provider_endpoint = our proxy.
#
# Parity wiring (inert until enabled):
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

  # Private profile. fx requires connection definitions at the TOP LEVEL of
  # ~/.fx/settings.json (not a repo .fx.json / nested workspace).
  settingsFile = pkgs.writeText "fx-settings.json" (builtins.toJSON (
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
  ));
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

    # fx REFUSES a settings.json that is a symlink into the read-only store:
    # it logs "fx: config user: durable_path_unsafe" and then ignores the file
    # entirely (falling back to Vercel AI Gateway). So copy it into place as a
    # real, writable, mode-600 file at activation instead of using home.file.
    # Overwritten every switch -- treat ~/.fx/settings.json as generated.
    home.activation.fxSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${config.home.homeDirectory}/.fx"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m600 \
        ${settingsFile} "${config.home.homeDirectory}/.fx/settings.json"
    '';
  };
}
