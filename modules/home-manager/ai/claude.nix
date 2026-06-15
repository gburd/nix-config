{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.claude;
  inherit (lib) mkEnableOption mkOption types;
  litellmKey = "${config.home.homeDirectory}/.config/litellm/keys/claude.key";
in
{
  options.programs.ai.claude = {
    enable = mkEnableOption "Claude Code (Anthropic CLI) routing through the local LiteLLM proxy";

    defaultModel = mkOption {
      type = types.str;
      # LiteLLM alias from modules/home-manager/ai/litellm.nix; resolves
      # to bedrock/converse/us.anthropic.claude-opus-4-8 with adaptive
      # thinking + output_config.effort=xhigh server-side.
      default = "claude-opus-4-8";
      description = "Default LiteLLM-aliased model id for claude-code (ANTHROPIC_MODEL).";
    };

    fastModel = mkOption {
      type = types.str;
      default = "claude-haiku-4-5";
      description = ''
        Model used by claude-code for the lightweight \"fast/small\" calls
        (haiku-class). Set as ANTHROPIC_SMALL_FAST_MODEL.
      '';
    };

    litellmUrl = mkOption {
      type = types.str;
      # claude-code appends /v1/messages itself, so this must be the
      # proxy ROOT (no /v1 suffix).
      default = "http://127.0.0.1:4000";
      description = "Base URL for the local LiteLLM proxy (Anthropic-protocol endpoint).";
    };
  };

  config = lib.mkIf cfg.enable {
    # ~/.claude/settings.json is largely user-managed (permission
    # allow-lists, hooks, plugin state, etc.) so we don't fully manage it
    # via home.file. Instead, we patch only the `env` block at activation
    # time \u2014 dropping all Bedrock plumbing and injecting the LiteLLM-
    # routing env vars. Idempotent: re-runs are a no-op once the desired
    # state is reached.
    home.activation.claudeLitellmEnv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      SETTINGS="${config.home.homeDirectory}/.claude/settings.json"
      KEY_FILE="${litellmKey}"

      if [ ! -f "$SETTINGS" ]; then
        echo "claude: $SETTINGS not present; skipping env patch (run claude once to seed it)" >&2
        exit 0
      fi
      if [ ! -r "$KEY_FILE" ]; then
        echo "claude: $KEY_FILE not readable; is litellm.service running?" >&2
        exit 0
      fi

      # Read the per-host LiteLLM virtual key fresh on every switch. Any
      # rotation since the last run is reflected automatically.
      KEY=$(${pkgs.coreutils}/bin/cat "$KEY_FILE")
      TMP=$(${pkgs.coreutils}/bin/mktemp)

      # Drop every Bedrock / AWS env var; set the LiteLLM-routing trio.
      # Use ONLY ANTHROPIC_AUTH_TOKEN (sent as `Authorization: Bearer`,
      # which the LiteLLM proxy accepts). Setting ANTHROPIC_API_KEY too
      # makes recent claude-code versions warn "Auth conflict: Both a
      # token and an API key are set", so we explicitly delete it.
      # ANTHROPIC_MODEL + ANTHROPIC_SMALL_FAST_MODEL pin the model so
      # claude-code doesn't try to fetch an inference-profile id from
      # anthropic.com's catalog.
      ${pkgs.jq}/bin/jq \
        --arg base   "${cfg.litellmUrl}" \
        --arg key    "$KEY" \
        --arg model  "${cfg.defaultModel}" \
        --arg fast   "${cfg.fastModel}" \
        '.env = ((.env // {})
          | del(
              .CLAUDE_CODE_USE_BEDROCK,
              .CLAUDE_CODE_SKIP_BEDROCK_AUTH,
              .ANTHROPIC_BEDROCK_BASE_URL,
              .AWS_BEARER_TOKEN_BEDROCK,
              .AWS_PROFILE,
              .AWS_DEFAULT_PROFILE,
              .AWS_REGION,
              .AWS_DEFAULT_REGION,
              .AWS_ACCESS_KEY_ID,
              .AWS_SECRET_ACCESS_KEY,
              .AWS_SESSION_TOKEN,
              .ANTHROPIC_API_KEY,
              ._ANTHROPIC_MODEL
            )
          | .ANTHROPIC_BASE_URL          = $base
          | .ANTHROPIC_AUTH_TOKEN        = $key
          | .ANTHROPIC_MODEL             = $model
          | .ANTHROPIC_SMALL_FAST_MODEL  = $fast)' \
        "$SETTINGS" > "$TMP" && \
        ${pkgs.coreutils}/bin/mv "$TMP" "$SETTINGS"

      ${pkgs.coreutils}/bin/chmod 600 "$SETTINGS"
      echo "claude: patched $SETTINGS env to route via LiteLLM (model=${cfg.defaultModel}, fast=${cfg.fastModel})"
    '';
  };
}
