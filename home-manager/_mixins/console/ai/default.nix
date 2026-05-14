{ config, pkgs, ... }:
{
  # Amazon Bedrock and MCP Server configuration
  programs.ai = {
    bedrock = {
      enable = true;
      region = "us-east-1";
      profile = "default";
      credentialsFile = config.sops.secrets."aws/credentials".path or null;
      bearerTokenFile = config.sops.secrets."aws/bearer_token_bedrock".path or null;
    };

    # Steering files (coding standards, Rust conventions, AWS patterns)
    steering = {
      enable = true;
      targets = {
        kiro = true;
        claude = true;
        maki = true;
      };
    };

    # Skills (Rust, AWS, cross-monitoring, benchmarks)
    skills = {
      enable = true;
      targets = {
        kiro = true;
        claude = true;
      };
    };

    # Maki agent configuration
    maki.enable = true;

    # Pi coding agent (pi.dev)
    pi.enable = true;

    # MCP Server configuration
    mcps = {
      enable = true;
      targets = {
        default = true;
        claude = true;
        kiro = true;
        maki = true;
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
            python = {
              url = "https://docs.python.org/3/llms.txt";
              title = "Python Documentation";
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
          path = config.home.homeDirectory;
        };

        # Agora: PostgreSQL community discussion archive (postgr.esq)
        # Also available via NNTP (mail.postgr.esq:563), IMAP, web
        agora = {
          enable = true;
          url = "https://postgr.esq/l/mcp/";
        };
      };
    };
  };

  programs.gh-dash.enable = true;

  home.packages = with pkgs; [
    awscli2
    aws-vault
    gh
    nodejs
    ssm-session-manager-plugin
    uv
  ];
}
