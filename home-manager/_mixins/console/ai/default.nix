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
        pi = true;
        maki = true;
        codex = true;
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

    # OpenAI Codex agent
    codex.enable = true;

    # Hermes Agent (NousResearch self-improving agent, installed via pipx;
    # uses the same AWS_BEARER_TOKEN_BEDROCK as the other agents).
    hermes.enable = true;

    # LiteLLM Bedrock proxy (per-host, loopback only). All agents route
    # through this; the proxy is the only consumer of the bearer token.
    # See modules/home-manager/ai/litellm.nix.
    litellm.enable = true;

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

        # PostgreSQL community discussion archive (pg.ddx.io)
        # Also available via NNTP (nntp.pg.ddx.io:119/563), IMAP, web
        postgresq = {
          enable = true;
          url = "https://pg.ddx.io/mcp/";
        };

        # Persistent knowledge graph across sessions
        server-memory.enable = true;

        # Local Git operations (diff, log, blame, branch) beyond GitHub MCP
        server-git.enable = true;

        # Live version-aware library documentation
        context7.enable = true;

        # Structured multi-step reasoning for complex decisions
        sequential-thinking.enable = true;
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
