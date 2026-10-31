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
        fx = true;
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

    # Per-agent enable flags. Each agent's nix module wires it to the
    # LiteLLM proxy and reads its key from
    # ~/.config/litellm/keys/<agent>.key. No per-agent AWS env exports
    # remain.
    claude.enable = true;
    maki.enable = true;
    pi.enable = true;
    # fx (vercel-labs/fx): DISABLED. The released v0.0.10 binary only supports
    # its built-in providers (`fx provider` = gateway|codex|grok) -- the custom
    # model-connection feature needed to route it through our LiteLLM proxy is
    # not compiled in (no "openai-chat-completions"/"base_url" strings in the
    # binary; fx status reports auth "missing" and wants Vercel AI Gateway).
    # Enabling it would just yield a broken agent. The wiring in ai/fx.nix is
    # ready -- flip this to true once a release ships the feature.
    fx.enable = false;

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

        # memelord is retired (2026-10-31): every memory is in the shared
        # agent-memory service, the .memelord DBs are deleted, and an archive
        # of them is in ~/.local/share/agent-memory-backup/ on each host.
        memelord.enable = false;

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

        # Persistent knowledge graph across sessions -- REMOVED (was
        # server-memory.enable = true;): its storage file lives inside a
        # volatile npx cache dir (~/.npm/_npx/<hash>/...) that gets a fresh,
        # empty file whenever npm's resolution hash changes -- not reliably
        # persistent at all (confirmed: 1 entity, unclear survival across
        # cache invalidation). agent-memory (on meh) is the persistent layer.
        server-memory.enable = false;

        # Local Git operations (diff, log, blame, branch) beyond GitHub MCP
        server-git.enable = true;

        # Live version-aware library documentation
        context7.enable = true;

        # Structured multi-step reasoning for complex decisions
        sequential-thinking.enable = true;

        # UI/UX design resources. Defines two heavy, per-project servers:
        # `design-guidelines` (framework-neutral: WCAG/UX rules, palettes,
        # chart + icon guidance -- the useful part for improv's egui/ratatui
        # front-end) and `ui-ux-pro` (everything, web/mobile frameworks
        # included). Neither loads until a project asks for it with
        # `use project_mcp design-guidelines` / `use project_mcp ui-ux-pro`.
        ui-ux-pro.enable = true;

        # zvec-grep (zg): local-first hybrid search (ripgrep + BM25 + vector)
        # over the workspace, exposed to every agent over MCP. Index a tree
        # once with `zg --index <dir>` before search tools return results.
        # CORE (not per-project): useful everywhere, search-only `agent`
        # toolset keeps the schema small.
        zvec-grep.enable = true;
      };
    };
  };

  programs.gh-dash.enable = true;

  # Agent LD_PRELOAD guard (all hosts). A project devshell — e.g. the
  # PostgreSQL/libumem shells — exports LD_PRELOAD=libumem_malloc.so, which
  # SIGSEGVs the Node/native AI agents. pi in particular is launched from an
  # npx-cached bin that shadows the nix wrapper on PATH, so a wrapper/PATH fix
  # isn't reliable. Shell functions shadow PATH entirely: define one per agent
  # that clears LD_PRELOAD before running the real command (`type -P` skips
  # the function itself and resolves the PATH binary).
  programs.bash.initExtra = ''
    pi()     { env -u LD_PRELOAD "$(type -P pi)" "$@"; }
    claude() { env -u LD_PRELOAD "$(type -P claude)" "$@"; }
    maki()   { env -u LD_PRELOAD "$(type -P maki)" "$@"; }
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
