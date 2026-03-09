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
  };

  config = lib.mkIf cfg.enable {
    # Claude Code configuration for Bedrock
    home.file.".config/claude-code/config.json" = {
      text = builtins.toJSON {
        apiProvider = "bedrock";
        bedrockRegion = cfg.region;
        bedrockProfile = if cfg.profile != null then cfg.profile else "default";
      };
    };

    # Set up AWS credentials symlink if provided
    home.file.".aws/credentials" = lib.mkIf (cfg.credentialsFile != null) {
      source = cfg.credentialsFile;
    };

    # Ensure AWS CLI is available
    home.packages = with pkgs; [
      awscli2
    ];
  };
}
