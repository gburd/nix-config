{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.maki;
  inherit (lib) mkEnableOption mkOption types;

  # Shared bash allow/deny policy (single source of truth across kiro/claude/maki).
  bashAllowlist = import ./bash-allowlist.nix { inherit lib; };
  renderTomlArray = items:
    lib.concatMapStringsSep "\n" (s: "    \"${s}\",") items;

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
      # maki 0.3.9 routes Bedrock through the Anthropic provider gated by
      # CLAUDE_CODE_USE_BEDROCK=1 (set by the launcher wrapper below). The
      # model spec is "anthropic/<id>"; maki sends <id> to Bedrock verbatim,
      # so <id> must be a full us.-prefixed inference-profile id (a bare
      # "anthropic.claude-opus-4-8" is rejected for on-demand invocation).
      default = "anthropic/us.anthropic.claude-opus-4-8";
      description = "Default model for maki (anthropic/<full Bedrock inference-profile id>)";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.maki;
      description = "The maki package to wrap and install";
    };

    region = mkOption {
      type = types.str;
      default = "us-east-1";
      description = "AWS region for Bedrock (maki 0.3.9 requires AWS_REGION to be set)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # maki 0.3.9 reaches Bedrock only when CLAUDE_CODE_USE_BEDROCK=1 and
      # AWS_REGION are set, and authenticates with the sops-decrypted bearer
      # token. Wrap the binary so these are present regardless of the parent
      # shell, without exporting them globally (which bedrock.nix avoids).
      (pkgs.writeShellScriptBin "maki" ''
        if [ -r "$HOME/.config/claude-code/.bearer_token" ]; then
          export AWS_BEARER_TOKEN_BEDROCK="$(cat "$HOME/.config/claude-code/.bearer_token")"
          unset AWS_PROFILE AWS_DEFAULT_PROFILE \
                AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
                AWS_SDK_LOAD_CONFIG
        fi
        export CLAUDE_CODE_USE_BEDROCK=1
        export AWS_REGION="''${AWS_REGION:-${cfg.region}}"
        exec ${cfg.package}/bin/maki "$@"
      '')
    ];

    home.file = {
      ".config/maki/config.toml".text = configToml;
      ".config/maki/permissions.toml".text = permissionsToml;
    };
  };
}
