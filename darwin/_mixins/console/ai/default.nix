{ pkgs, ... }:
{
  # AI agent configuration for macOS (darwin)
  # Note: No sops-nix on darwin — credentials managed via ada CLI and env vars
  programs.ai = {
    bedrock = {
      enable = true;
      region = "us-west-2";
      profile = "asbxbedrock";
      # No credentialsFile or bearerTokenFile — managed outside nix:
      #   ada credentials update --once --account <ID> --role <ROLE> --provider conduit --profile asbxbedrock
      #   Bearer token is in ~/.claude/settings.json (managed by Claude Code itself)
    };

    steering = {
      enable = true;
      targets = {
        kiro = true;
        claude = true;
        maki = true;
      };
    };

    skills = {
      enable = true;
      targets = {
        kiro = true;
        claude = true;
      };
    };

    mcps = {
      enable = true;
      targets = {
        default = true;
        claude = true;
        kiro = true;
      };

      servers = {
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
            rust = {
              url = "https://doc.rust-lang.org/llms.txt";
              title = "Rust Documentation";
            };
          };
        };

        github = {
          enable = true;
          pkg = pkgs.github-mcp-server or pkgs.unstable.github-mcp-server;
        };

        memelord = {
          enable = true;
          pkg = pkgs.writeShellApplication {
            name = "memelord";
            runtimeInputs = [ pkgs.nodejs ];
            text = ''
              exec npx -y memelord "$@"
            '';
          };
        };

        filesystem = {
          enable = true;
          # Uses config.home.homeDirectory by default
        };
      };
    };
  };

  home.packages = with pkgs; [
    gh
    nodejs
    uv
  ];
}
