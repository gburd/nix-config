{ config, pkgs, ... }:
{
  # All AI agents route through the local LiteLLM proxy
  # (modules/home-manager/ai/litellm.nix). The proxy is the single
  # consumer of the AWS Bedrock bearer token from sops-nix; agents
  # talk to it on 127.0.0.1:4000 with per-agent virtual keys minted at
  # activation in ~/.config/litellm/keys/<agent>.key.
  programs.ai = {
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
      # Codex 0.92+ requires YAML frontmatter (\`---\nname: …\n---\`) at the
      # top of every SKILL.md and emits a noisy warning per file when
      # missing. The upstream codex branch of
      # https://codeberg.org/ddx/skills.git ships plain markdown without
      # frontmatter (current as of 2026-06-07), so codex flags every
      # file at startup. Disable the codex branch deployment until
      # upstream adds frontmatter — codex still has full access to the
      # operator skills via ~/.codex/skills/.system/ and our local
      # skills set.
      skillsGit.branches.codex.enable = false;
    };

    # Per-agent enable flags. Each agent's nix module wires it to the
    # LiteLLM proxy and reads its key from
    # ~/.config/litellm/keys/<agent>.key. No per-agent AWS env exports
    # remain.
    claude.enable = true;
    codex.enable = true;
    hermes.enable = true;
    maki.enable = true;
    pi.enable = true;

    # LiteLLM Bedrock proxy (per-host, loopback only). Holds the
    # bearer token from sops-nix at
    # ~/.config/claude-code/.bearer_token (per-host sops.secrets in
    # home-manager/_mixins/users/gburd/hosts/<host>.nix); mints
    # per-agent virtual keys at activation. See
    # modules/home-manager/ai/litellm.nix.
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
