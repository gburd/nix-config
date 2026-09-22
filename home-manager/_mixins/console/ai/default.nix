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

        memelord = {
          enable = true;
          # pkgs.memelord (pkgs/memelord) bundles the npm memelord MCP server
          # + the local memelord-rollup tool (flat-pile -> pattern summaries).
          pkg = pkgs.memelord;
          # Weekly timer: distill every ~/ws project's flat memelord pile into
          # pattern summaries via the local LiteLLM proxy. pi.key is minted at
          # activation into ~/.config/litellm/keys/ and readable by the user
          # unit (not a sops path -- the key file is already local).
          rollup = {
            enable = true;
            apiKeyFile = "${config.home.homeDirectory}/.config/litellm/keys/pi.key";
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

        # Persistent knowledge graph across sessions -- REMOVED (was
        # server-memory.enable = true;): its storage file lives inside a
        # volatile npx cache dir (~/.npm/_npx/<hash>/...) that gets a fresh,
        # empty file whenever npm's resolution hash changes -- not reliably
        # persistent at all (confirmed: 1 entity, unclear survival across
        # cache invalidation). memelord below is the real persistent-memory
        # layer (project-scoped .memelord/, proven to survive sandbox sync).
        server-memory.enable = false;

        # Local Git operations (diff, log, blame, branch) beyond GitHub MCP
        server-git.enable = true;

        # Live version-aware library documentation
        context7.enable = true;

        # Structured multi-step reasoning for complex decisions
        sequential-thinking.enable = true;

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
  # isn't reliable. Fish functions shadow PATH entirely: define one per agent
  # that clears LD_PRELOAD before running the real command. Written directly
  # to conf.d via home.file (programs.fish.enable is false here, so
  # programs.fish.interactiveShellInit would be dropped — same pattern as
  # cargo.nix / lmstudio.nix).
  home.file.".config/fish/conf.d/agent-ld-preload-guard.fish".text = ''
    function pi;     env -u LD_PRELOAD (command -s pi) $argv;     end
    function claude; env -u LD_PRELOAD (command -s claude) $argv; end
    function maki;   env -u LD_PRELOAD (command -s maki) $argv;   end
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
