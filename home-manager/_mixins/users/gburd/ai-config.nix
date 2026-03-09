{ config, pkgs, ... }:
{
  # Amazon Bedrock configuration for Claude Code
  programs.ai.bedrock = {
    enable = true;
    region = "us-east-1";
    profile = "default";
    # credentialsFile will be set via sops-nix secret
    credentialsFile = config.sops.secrets."aws/credentials".path or null;
    # bearerTokenFile will be set via sops-nix secret
    bearerTokenFile = config.sops.secrets."aws/bearer_token_bedrock".path or null;
  };

  # MCP Server configuration
  programs.ai.mcps = {
    enable = true;
    targets = {
      default = true;
      claude = true;
    };

    servers = {
      # Enable llms.txt documentation wrappers
      llms-docs = {
        enable = true;
        sources = {
          nix = {
            url = "https://nixos.org/llms.txt";
            title = "NixOS Documentation";
          };
          home-manager = {
            url = "https://nix-community.github.io/home-manager/llms.txt";
            title = "Home Manager Documentation";
          };
        };
      };

      # Enable GitHub MCP server (requires gh CLI authentication)
      github = {
        enable = true;
        pkg = pkgs.github-mcp-server or pkgs.unstable.github-mcp-server;
      };

      # Enable memelord persistent memory
      memelord = {
        enable = true;
        pkg = pkgs.memelord;
      };
    };
  };

  # GitHub dashboard
  programs.gh-dash = {
    enable = true;
    presets = [ "personal" ];
  };

  # Ensure necessary packages are installed
  home.packages = with pkgs; [
    gh # GitHub CLI for MCP server auth
    nodejs # Required for memelord
    uv # Required for llms.txt wrappers
  ];
}
