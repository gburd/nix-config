{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.maki;
  inherit (lib) mkEnableOption mkOption types;

  configToml = ''
    always_yolo = true

    [provider]
    default_model = "${cfg.defaultModel}"
  '';

  permissionsToml = ''
    [bash]
    deny = [
        "rm -rf *",
        "rm -fr *",
        "sudo *",
        "mkfs *",
        "dd *",
        "curl *|bash*",
        "wget *|bash*",
        "git push --force*",
        "git push *--force*",
        "git reset --hard*",
    ]
    allow = [
        "tar *",
        "gzip *",
        "gunzip *",
        "zip *",
        "unzip *",
        "7z *",
        "bzip2 *",
        "xz *",
        "tr *",
        "fold *",
        "column *",
        "paste *",
        "join *",
        "split *",
        "tee *",
        "xargs *",
        "printf *",
        "test *",
        "[ *",
        "[[ *",
        "true*",
        "false*",
        "seq *",
        "shuf *",
        "bc *",
        "expr *",
        "timeout *",
        "time *",
        "watch *",
        "psql *",
        "pg_dump *",
        "pg_restore *",
        "pg_dumpall*",
        "createdb *",
        "dropdb *",
        "docker exec * psql *",
        "docker exec * pg_dump *",
        "sqlite3 *",
        "redis-cli *",
        "openssl rand -hex 32*",
        "openssl rand -base64 *",
        "uuidgen*",
        "openssl x509 -noout -text -in *",
        "openssl verify *",
        "npm test *",
        "jest *",
        "npx jest *",
        "python *",
        "python3 *",
        "pip *",
        "pip3 *",
        "python -m *",
        "python3 -m *",
        "direnv *",
        "direnv allow*",
        "direnv deny*",
        "direnv status*",
        "tmux *",
        "lsof -i :*",
        "netstat -an | grep *",
        "ss -an | grep *",
        "nc -zv * *",
        "tail -f *",
        "grep -i error logs/*",
        "journalctl -xeu *",
        "df -h*",
        "du -sh *",
        "du -h --max-depth=*",
        "free -m*",
        "free -h*",
        "for * in *; do *; done*",
        "while *; do *; done*",
        "if *; then *; fi*",
        "make *",
        "yarn *",
        "pnpm *",
        "cargo *",
        "nix *",
        "nix-shell *",
        "nix-build *",
        "nixos-rebuild *",
        "home-manager *",
        "git remote show origin*",
        "git ls-remote *",
        "git fetch --prune*",
        "git gc*",
        "git reflog*",
        "md5sum *",
        "sha256sum *",
        "stat *",
        "file *",
        "aws *",
        "gcloud *",
        "az *",
        "claude *",
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
