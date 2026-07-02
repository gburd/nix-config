{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.maki;
  inherit (lib) mkEnableOption mkOption types;

  # Shared bash allow/deny policy (single source of truth across kiro/claude/maki).
  bashAllowlist = import ./bash-allowlist.nix { inherit lib; };
  renderTomlArray = items:
    lib.concatMapStringsSep "\n" (s: "    \"${s}\",") items;

  litellmKey = "${config.home.homeDirectory}/.config/litellm/keys/maki.key";

  # Maki's dynamic-provider mechanism: drop an executable script at
  # ~/.maki/providers/<slug>; it must answer the `info`, `models`,
  # `resolve` subcommands as JSON. With base="anthropic" and a `resolve`
  # that returns `base_url`, maki routes Anthropic-protocol requests to
  # whatever URL we give it (the Anthropic provider's hardcoded
  # `MESSAGES_URL` is overridden by `auth.base_url`).
  #
  # Subcommand contract is documented at
  # https://github.com/maki-ai/maki/blob/main/site/docs/content/providers/_index.md#dynamic-providers
  litellmProviderScript = pkgs.writeShellScript "maki-litellm-provider" ''
    set -eu
    case "''${1:-}" in
      info)
        # has_auth=true so maki invokes `resolve` to discover base_url +
        # x-api-key. system_prefix is empty; the system prompt comes from
        # the agent's instructions.md.
        cat <<'JSON'
    { "display_name": "LiteLLM", "base": "anthropic", "has_auth": true }
    JSON
        ;;
      models)
        # Mirror the Anthropic models we expose on the LiteLLM proxy
        # (modules/home-manager/ai/litellm.nix). Tier mapping is just
        # cost-bracket; the first model per tier is what /new picks.
        # Models the proxy doesn't actually expose (e.g. the dropped
        # legacy ones) are intentionally absent.
        cat <<'JSON'
    [
      {"id":"claude-opus-4-8",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-fable-5",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-opus-4-7",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-opus-4-6",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-opus-4-5",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-opus-4-1",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-sonnet-5",  "tier":"medium", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-sonnet-4-6","tier":"medium", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-sonnet-4-5","tier":"medium", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-haiku-4-5", "tier":"weak",   "context_window":200000, "max_output_tokens":32000}
    ]
    JSON
        ;;
      resolve)
        # Read the per-host LiteLLM virtual key fresh each time maki
        # spawns a new agent (re-resolve on /new, retry, session load).
        # Mode-600 file populated by litellm.service's mint-keys
        # ExecStartPost; never logged or echoed.
        if [ ! -r "${litellmKey}" ]; then
          echo "litellm provider: ${litellmKey} not readable; is litellm.service running?" >&2
          exit 78  # EX_CONFIG
        fi
        KEY=$(${pkgs.coreutils}/bin/cat "${litellmKey}")
        # Maki's Anthropic provider sees `base_url` as the FULL request
        # endpoint (it does not append /v1/messages). The proxy exposes
        # the Anthropic protocol there.
        ${pkgs.jq}/bin/jq -n --arg key "$KEY" '{
          base_url: "${cfg.litellmUrl}/v1/messages",
          headers: { "x-api-key": $key }
        }'
        ;;
      login|logout|refresh)
        # No-op: auth lives in litellm.service-managed keyfiles, not
        # interactive flows. Maki re-runs `resolve` on every new agent
        # spawn, so a rotated key picks up automatically.
        echo '{}'
        ;;
      *)
        echo "unknown subcommand: ''${1:-<empty>}" >&2
        exit 64  # EX_USAGE
        ;;
    esac
  '';

  configToml = ''
    [provider]
    default_model = "${cfg.defaultModel}"
  '';

  permissionsToml = ''
        [bash]
        # Generated from ./bash-allowlist.nix — kept in sync with kiro/claude.
        deny = [
    ${renderTomlArray bashAllowlist.makiDeny}
        ]
        allow = [
    ${renderTomlArray bashAllowlist.makiAllow}
        ]

        [edit]
        deny = [
            "~/.bashrc",
            "~/.zshrc",
            "~/.ssh/**",
        ]
        allow = ["**"]

        [glob]
        allow = ["**"]

        [grep]
        allow = ["**"]

        [ls]
        allow = ["**"]

        [multi_edit]
        allow = ["**"]

        [read]
        deny = [
            "~/.ssh/**",
            "~/.gnupg/**",
            "~/.aws/**",
            "~/.config/gh/**",
            "~/.git-credentials",
            "~/.docker/config.json",
            "~/.kube/**",
            "~/.npmrc",
            "~/.pypirc",
        ]
        allow = ["**"]

        [task]
        allow = ["**"]

        [web_fetch]
        allow = [
            "domain:docs.anthropic.com",
            "domain:localhost",
            "domain:127.0.0.1",
            "domain:github.com",
            "domain:api.openai.com",
            "domain:api.anthropic.com",
        ]

        [write]
        allow = ["**"]
  '';
in
{
  options.programs.ai.maki = {
    enable = mkEnableOption "Maki AI agent configuration";

    defaultModel = mkOption {
      type = types.str;
      # Maki dynamic-provider models are namespaced as `<slug>/<model>`,
      # where <slug> is the provider script's filename
      # (~/.maki/providers/litellm here).
      default = "litellm/claude-opus-4-8";
      description = "Default model for maki (<dynamic-provider-slug>/<model>).";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.maki;
      description = "The maki package to wrap and install";
    };

    litellmUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:4000";
      description = "Base URL for the local LiteLLM proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # Wrapper: defensively unset any AWS/Bedrock plumbing that could
      # short-circuit the dynamic provider's resolved base_url and route
      # maki around the proxy. With LiteLLM in front, maki sees no AWS
      # state at all.
      (pkgs.writeShellScriptBin "maki" ''
        unset CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_SKIP_BEDROCK_AUTH \
              ANTHROPIC_BEDROCK_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_BASE_URL \
              AWS_BEARER_TOKEN_BEDROCK \
              AWS_PROFILE AWS_DEFAULT_PROFILE \
              AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
              AWS_SDK_LOAD_CONFIG
        exec ${cfg.package}/bin/maki "$@"
      '')
    ];

    home.file = {
      # Note: maki uses `~/.maki/` (the FALLBACK_DIR) when that directory
      # exists, even though XDG dirs are otherwise honoured. The dynamic
      # provider script must live there so maki's discovery picks it up —
      # and because ~/.maki/ exists, maki reads ~/.maki/config.toml with
      # HIGHER precedence than ~/.config/maki/config.toml. So manage the
      # config in BOTH places: writing ~/.maki/config.toml (nix symlink)
      # prevents a stale hand-edited copy there from shadowing the correct
      # litellm-routed config (which previously made maki talk to Bedrock
      # directly via leftover ~/.maki/.env creds).
      ".maki/providers/litellm" = {
        source = litellmProviderScript;
        executable = true;
      };
      ".maki/config.toml".text = configToml;
      ".config/maki/config.toml".text = configToml;
      ".config/maki/permissions.toml".text = permissionsToml;
    };

    # Seed the cached model selection if it doesn't exist. Maki's startup
    # path looks for ~/.maki/model first; if absent, it requires an env
    # var (ANTHROPIC_API_KEY etc.) for a built-in provider OR an explicit
    # `-m`. The `[provider].default_model` config.toml field is only the
    # /model-picker fallback, not the bootstrap default. Without this seed
    # `maki -p "..."` exits with "no provider available" on first run.
    # Idempotent: only writes if the file is missing or doesn't reference
    # our dynamic provider, so a manual /model selection is preserved.
    home.activation.seedMakiModel = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      MODEL_FILE="${config.home.homeDirectory}/.maki/model"
      DESIRED="${cfg.defaultModel}"
      if [ ! -s "$MODEL_FILE" ] || ! ${pkgs.gnugrep}/bin/grep -q '^litellm/' "$MODEL_FILE"; then
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$MODEL_FILE")"
        ${pkgs.coreutils}/bin/printf '%s' "$DESIRED" > "$MODEL_FILE"
        echo "maki: seeded $MODEL_FILE = $DESIRED"
      fi
    '';
  };
}
