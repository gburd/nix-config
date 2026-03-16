{ config, pkgs, ... }:
{
  # Amazon Bedrock and MCP Server configuration
  programs.ai = {
    bedrock = {
      enable = true;
      region = "us-east-1";
      profile = "default";
      # credentialsFile will be set via sops-nix secret
      credentialsFile = config.sops.secrets."aws/credentials".path or null;
      # bearerTokenFile will be set via sops-nix secret
      bearerTokenFile = config.sops.secrets."aws/bearer_token_bedrock".path or null;
    };

    # MCP Server configuration
    mcps = {
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
            rust = {
              url = "https://doc.rust-lang.org/llms.txt";
              title = "Rust Documentation";
            };
            python = {
              url = "https://docs.python.org/3/llms.txt";
              title = "Python Documentation";
            };
            # Note: Add more as llms.txt becomes available for other languages
            # bash, tcl, perl, C docs may need manual MCP server configuration
          };
        };

        # Enable GitHub MCP server (requires gh CLI authentication)
        github = {
          enable = true;
          pkg = pkgs.github-mcp-server or pkgs.unstable.github-mcp-server;
        };

        # Enable memelord persistent memory via npx
        # Note: Using npx since package not in nixpkgs
        # MCP server will run: npx -y @modelcontextprotocol/server-memory
        memelord = {
          enable = true;
          pkg = pkgs.writeShellApplication {
            name = "memelord";
            runtimeInputs = [ pkgs.nodejs ];
            text = ''
              exec npx -y @modelcontextprotocol/server-memory "$@"
            '';
          };
        };
      };
    }};

    # GitHub dashboard
    # NOTE: Using built-in gh-dash module (no custom presets support)
    programs.gh-dash = {
      enable = true;
    };

    # Ensure necessary packages are installed
    home.packages = with pkgs; [
      gh # GitHub CLI for MCP server auth
      nodejs # Required for MCP servers
      uv # Required for llms.txt wrappers
    ];

    # Additional MCP servers you may want to configure manually:
    #
    # 1. filesystem - Direct file system access for Claude
    #    https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem
    #
    # 2. brave-search - Web search capabilities
    #    https://github.com/modelcontextprotocol/servers/tree/main/src/brave-search
    #
    # 3. postgres/sqlite - Database access
    #    https://github.com/modelcontextprotocol/servers/tree/main/src/postgres
    #
    # 4. sequential-thinking - Enhanced reasoning for complex problems
    #    https://github.com/modelcontextprotocol/servers/tree/main/src/sequential-thinking
    #
    # 5. puppeteer - Browser automation for testing
    #    https://github.com/modelcontextprotocol/servers/tree/main/src/puppeteer
    #
    # 6. git - Git repository operations (alternative to github MCP)
    #    https://github.com/modelcontextprotocol/servers/tree/main/src/git
    #
    # To add custom MCP servers, extend programs.ai.mcps.servers with:
    # - command: path to executable
    # - args: list of arguments (optional)
    # - env: environment variables (optional)
  }
