{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.maki;
  inherit (lib) mkEnableOption mkOption types;

  # Shared bash allow/deny policy (single source of truth across kiro/claude/maki).
  bashAllowlist = import ./bash-allowlist.nix { inherit lib; };
  renderTomlArray = items:
    lib.concatMapStringsSep "\n" (s: "    \"${s}\",") items;

  litellmKey = "${config.home.homeDirectory}/.config/litellm/keys/maki.key";

  # The models the LiteLLM proxy exposes to maki (litellm.nix). Edit here;
  # providers.toml below is generated from it.
  makiModelRegistry = ''
    [
      {"id":"claude-opus-5-5", "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-opus-5",   "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"gpt-6-astra",   "tier":"strong", "context_window":256000, "max_output_tokens":32000},
      {"id":"claude-opus-4-8",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-fable-5-1","tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-fable-5",  "tier":"strong", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-sonnet-5-5","tier":"medium", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-sonnet-5",  "tier":"medium", "context_window":200000, "max_output_tokens":32000},
      {"id":"claude-haiku-5-5", "tier":"weak",   "context_window":200000, "max_output_tokens":32000}
    ]'';

  # maki 0.6 dropped provider scripts (~/.maki/providers/<slug>); a custom
  # Anthropic-protocol provider in providers.toml replaces it. The key comes
  # from LITELLM_API_KEY, which the wrapper below reads from the per-host
  # LiteLLM key file at launch (maki has no key-file option).
  makiModels = builtins.fromJSON makiModelRegistry;
  providersToml = ''
    [litellm]
    display_name = "LiteLLM"
    protocol = "anthropic"
    base_url = "${cfg.litellmUrl}"
    default_model = "${cfg.defaultModel}"
  '' + lib.concatMapStrings
    (m: ''

      [[litellm.models]]
      id = "${m.id}"
      tier = "${m.tier}"
      context_window = ${toString m.context_window}
      max_output_tokens = ${toString m.max_output_tokens}
    '')
    makiModels;

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
      default = "litellm/claude-opus-5-5";
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
              AWS_SDK_LOAD_CONFIG \
              LD_PRELOAD
        if [ -z "''${LITELLM_API_KEY:-}" ] && [ -r "${litellmKey}" ]; then
          LITELLM_API_KEY=$(${pkgs.coreutils}/bin/cat "${litellmKey}")
          export LITELLM_API_KEY
        fi
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
      ".config/maki/providers.toml".text = providersToml;
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

      # Self-heal stale session provider pins. Pre-LiteLLM sessions pin
      # "model":"anthropic/..." or "bedrock/...", so resuming one (-c/-s)
      # makes maki demand an ANTHROPIC_API_KEY it doesn't have. Rewrite any
      # such pins to litellm/<model> (the only provider we configure), with a
      # one-time backup. Idempotent: only rewrites files that still have a
      # stale pin.
      SDIR="${config.home.homeDirectory}/.maki/sessions"
      if [ -d "$SDIR" ]; then
        BK="$SDIR/_pre-litellm-backup"
        for f in "$SDIR"/*.jsonl; do
          [ -f "$f" ] || continue
          if ${pkgs.gnugrep}/bin/grep -qE '"model":"(anthropic|bedrock)/' "$f"; then
            ${pkgs.coreutils}/bin/mkdir -p "$BK"
            [ -f "$BK/$(${pkgs.coreutils}/bin/basename "$f")" ] || ${pkgs.coreutils}/bin/cp "$f" "$BK/"
            ${pkgs.gnused}/bin/sed -i -E \
              -e 's#"model":"anthropic/#"model":"litellm/#g' \
              -e 's#"model":"bedrock/#"model":"litellm/#g' \
              -e 's#"model":"litellm/us\.anthropic\.#"model":"litellm/#g' \
              -e 's#"model":"litellm/bedrock\.rs"#"model":"litellm/claude-opus-4-8"#g' \
              -e 's#"model":"litellm/claude-haiku-4[.-]5"#"model":"litellm/claude-haiku-5-5"#g' \
              -e 's#"model":"litellm/claude-opus-4-"#"model":"litellm/claude-opus-4-8"#g' \
              "$f"
          fi
        done
      fi
    '';
  };
}
