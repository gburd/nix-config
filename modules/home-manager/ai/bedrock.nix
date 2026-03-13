{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.bedrock;
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.ai.bedrock = {
    enable = mkEnableOption "Amazon Bedrock configuration for Claude Code";

    region = mkOption {
      type = types.str;
      default = "us-east-1";
      description = "AWS region for Bedrock API";
    };

    profile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "AWS profile to use for Bedrock authentication";
    };

    credentialsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to AWS credentials file (managed by sops-nix)";
    };

    bearerTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to AWS bearer token file (managed by sops-nix)";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      # Claude Code configuration for Bedrock
      file.".config/claude-code/config.json" = {
        text = builtins.toJSON {
          apiProvider = "bedrock";
          bedrockRegion = cfg.region;
          bedrockProfile = if cfg.profile != null then cfg.profile else "default";
        };
      };

      # Set up AWS credentials symlink if provided
      file.".aws/credentials" = lib.mkIf (cfg.credentialsFile != null) {
        source = cfg.credentialsFile;
      };

      # Activation script to inject AWS bearer token into settings.json
      activation.injectAwsBearerToken = lib.mkIf (cfg.bearerTokenFile != null) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          SETTINGS_FILE="${config.home.homeDirectory}/.claude/settings.json"
          BEARER_TOKEN_FILE="${cfg.bearerTokenFile}"

          if [ -f "$SETTINGS_FILE" ] && [ -f "$BEARER_TOKEN_FILE" ]; then
            BEARER_TOKEN=$(cat "$BEARER_TOKEN_FILE")

            # Use jq to update the env.AWS_BEARER_TOKEN_BEDROCK field
            TMP_FILE=$(${pkgs.coreutils}/bin/mktemp)
            ${pkgs.jq}/bin/jq --arg token "$BEARER_TOKEN" \
              '.env.AWS_BEARER_TOKEN_BEDROCK = $token' \
              "$SETTINGS_FILE" > "$TMP_FILE"

            ${pkgs.coreutils}/bin/mv "$TMP_FILE" "$SETTINGS_FILE"
            echo "Updated AWS_BEARER_TOKEN_BEDROCK in $SETTINGS_FILE"
          elif [ ! -f "$BEARER_TOKEN_FILE" ]; then
            echo "Warning: Bearer token file not found at $BEARER_TOKEN_FILE"
          fi
        ''
      );

      # Ensure AWS CLI is available
      packages = with pkgs; [
        awscli2
      ];
    };
  };
}
