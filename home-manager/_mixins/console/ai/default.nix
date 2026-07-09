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

    # Kun Chen's agentic tools: gnhf (overnight loops), gh-axi (low-token
    # GitHub CLI), lavish-axi (interactive planning), no-mistakes (validate
    # -> clean PR pipeline), firstmate (multi-agent orchestration launcher).
    kunTools.enable = true;

    # agent-sandbox: run agents isolated (bwrap default / docker / microvm)
    # so a rogue agent can't reach SSH keys / secrets / other projects, and
    # a runaway child is memory-capped + killed alone (no OOM cascade).
    sandbox.enable = true;
    # MCP Server configuration
    mcps = {
      enable = true;
      targets = {
        default = true;
        claude = true;
        kiro = true;
        maki = true;
        pi = true;
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

  # Agent LD_PRELOAD guard (all hosts). A project devshell — e.g. the
  # PostgreSQL/libumem shells — exports LD_PRELOAD=libumem_malloc.so, which
  # SIGSEGVs the Node/native AI agents. pi in particular is launched from an
  # npx-cached bin that shadows the nix wrapper on PATH, so a wrapper/PATH fix
  # isn't reliable. Fish functions shadow PATH entirely: define one per agent
  # that clears LD_PRELOAD before running the real command. Written directly
  # to conf.d via home.file (programs.fish.enable is false here, so
  # programs.fish.interactiveShellInit would be dropped — same pattern as
  # cargo.nix / lmstudio.nix).
  home.file.".config/fish/conf.d/agent-ld-preload-guard.fish".text = ''
    function pi;     env -u LD_PRELOAD (command -s pi) $argv;     end
    function claude; env -u LD_PRELOAD (command -s claude) $argv; end
    function maki;   env -u LD_PRELOAD (command -s maki) $argv;   end
    function codex;  env -u LD_PRELOAD (command -s codex) $argv;  end
    function hermes; env -u LD_PRELOAD (command -s hermes) $argv; end
  '';

  home.packages = with pkgs; [
    awscli2
    aws-vault
    gh
    nodejs
    ssm-session-manager-plugin
    uv
  ];
}
