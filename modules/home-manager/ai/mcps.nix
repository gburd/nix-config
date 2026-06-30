{ config, pkgs, lib, ... }:
let
  cfg = config.programs.ai.mcps;
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.attrsets) optionalAttrs;
  bashAllowlist = import ./bash-allowlist.nix { inherit lib; };

  ### GitHub MCP ###
  githubMcpServer = pkgs.writeShellScript "github-mcp-server" ''
    # Resolve a GitHub token from, in order: an existing env var, a configured
    # token file (e.g. a sops-nix secret), then `gh auth token`. The token-file
    # path lets headless hosts (e.g. arnold) work without an interactive
    # `gh auth login`, which is the usual reason this MCP server fails to start.
    TOKEN="''${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
    ${lib.optionalString (cfg.servers.github.tokenFile != null) ''
      if [ -z "$TOKEN" ] && [ -r "${toString cfg.servers.github.tokenFile}" ]; then
        TOKEN="$(cat "${toString cfg.servers.github.tokenFile}")"
      fi
    ''}
    if [ -z "$TOKEN" ] && command -v gh &> /dev/null; then
      TOKEN="$(gh auth token 2>/dev/null || true)"
    fi
    if [ -z "$TOKEN" ]; then
      echo "Error: no GitHub token. Set GITHUB_PERSONAL_ACCESS_TOKEN, configure" >&2
      echo "programs.ai.mcps.servers.github.tokenFile (sops), or run 'gh auth login'." >&2
      exit 3
    fi

    export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"

    ${cfg.servers.github.pkg}/bin/github-mcp-server stdio \
      --dynamic-toolsets \
      --read-only \
      "$@"
  '';

  ### llms.txt doc wrappers ###
  mcpdoc-wrapper-of = name: projectUrlMap:
    let
      urlArgs = builtins.concatStringsSep " " (
        builtins.map (name: ''"${name}:${projectUrlMap.${name}}"'')
          (builtins.attrNames projectUrlMap)
      );
    in
    # Use writeShellScript (not writeScript) so the rendered file gets a
      # `#!${runtimeShell}` shebang. Without it, kiro-cli's direct execve()
      # fails with ENOEXEC ("Exec format error (os error 8)").
    pkgs.writeShellScript "mcpdoc-wrapper-${name}" ''
      exec ${pkgs.uv}/bin/uvx --from mcpdoc mcpdoc \
        --urls \
        ${urlArgs} \
        --transport stdio \
        "$@"
    '';

  llmWrappers = lib.mapAttrs'
    (name: { url, title }:
      lib.nameValuePair name {
        command = mcpdoc-wrapper-of name {
          "${title}" = url;
        };
      })
    cfg.servers.llms-docs.sources;

  ### Memelord hooks ###
  memelordHooks = {
    SessionStart = [{
      hooks = [{
        type = "command";
        command = "memelord hook session-start";
        timeout = 10;
      }];
    }];
    PostToolUse = [{
      matcher = "*";
      hooks = [{
        type = "command";
        command = "memelord hook post-tool-use";
        timeout = 5;
      }];
    }];
    Stop = [{
      hooks = [{
        type = "command";
        command = "memelord hook stop";
        timeout = 15;
      }];
    }];
    SessionEnd = [{
      hooks = [{
        type = "command";
        command = "memelord hook session-end";
        timeout = 30;
      }];
    }];
  };

  ### MCP Server configuration file ###
  mcpJsonText = builtins.toJSON {
    inherit mcpServers;
  };

  mcpServers = { }
    // (optionalAttrs cfg.servers.filesystem.enable {
    filesystem = {
      command = "npx";
      args = [ "-y" "@modelcontextprotocol/server-filesystem" cfg.servers.filesystem.path ];
    };
  })
    // (optionalAttrs cfg.servers.llms-docs.enable llmWrappers)
    // (optionalAttrs cfg.servers.github.enable {
    github = {
      command = "${githubMcpServer}";
    };
  })
    // (optionalAttrs cfg.servers.memelord.enable {
    memelord = {
      command = "${cfg.servers.memelord.pkg}/bin/memelord";
      args = [ "serve" ];
    };
  })
    // (optionalAttrs cfg.servers.postgresq.enable {
    postgresq = {
      # type=http is required by the current MCP config schema for a
      # URL-based server; without it `claude doctor` (which validates
      # ~/.mcp.json) rejects it: "expected string received undefined".
      type = "http";
      inherit (cfg.servers.postgresq) url;
    };
  })
    # Phase 1 npm MCP servers
    // (optionalAttrs cfg.servers.server-memory.enable {
    memory = {
      command = "npx";
      args = [ "-y" "@modelcontextprotocol/server-memory" ];
    };
  })
    // (optionalAttrs cfg.servers.server-git.enable {
    git = {
      command = "${pkgs.uv}/bin/uvx";
      args = [ "--from" "mcp-server-git" "mcp-server-git" ];
    };
  })
    // (optionalAttrs cfg.servers.context7.enable {
    context7 = {
      command = "npx";
      args = [ "-y" "@upstash/context7-mcp@latest" ];
    };
  })
    // (optionalAttrs cfg.servers.sequential-thinking.enable {
    sequential-thinking = {
      command = "npx";
      args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
    };
  });

  # Claude Code user-scoped format (stored in ~/.claude.json under mcpServers)
  claudeUserMcpServers = { }
    // (optionalAttrs cfg.servers.filesystem.enable {
    filesystem = {
      type = "stdio";
      command = "npx";
      args = [ "-y" "@modelcontextprotocol/server-filesystem" cfg.servers.filesystem.path ];
      env = { };
    };
  })
    // (optionalAttrs cfg.servers.github.enable {
    github = {
      type = "stdio";
      command = "${githubMcpServer}";
      args = [ ];
      env = { };
    };
  })
    // (optionalAttrs cfg.servers.memelord.enable {
    memelord = {
      type = "stdio";
      command = "${cfg.servers.memelord.pkg}/bin/memelord";
      args = [ "serve" ];
      env = { };
    };
  })
    // (optionalAttrs cfg.servers.postgresq.enable {
    postgresq = {
      type = "http";
      inherit (cfg.servers.postgresq) url;
    };
  })
    // (optionalAttrs cfg.servers.server-memory.enable {
    memory = {
      type = "stdio";
      command = "npx";
      args = [ "-y" "@modelcontextprotocol/server-memory" ];
      env = { };
    };
  })
    // (optionalAttrs cfg.servers.server-git.enable {
    git = {
      type = "stdio";
      command = "${pkgs.uv}/bin/uvx";
      args = [ "--from" "mcp-server-git" "mcp-server-git" ];
      env = { };
    };
  })
    // (optionalAttrs cfg.servers.context7.enable {
    context7 = {
      type = "stdio";
      command = "npx";
      args = [ "-y" "@upstash/context7-mcp@latest" ];
      env = { };
    };
  })
    // (optionalAttrs cfg.servers.sequential-thinking.enable {
    sequential-thinking = {
      type = "stdio";
      command = "npx";
      args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
      env = { };
    };
  });

  ###
  # Per-project MCP gating (context-window optimization).
  #
  # github / postgresq / context7 / the llms-docs wrappers inject LARGE
  # tool schemas into every session's system prompt up front (github alone
  # is ~10-20k tokens). Loading all of them globally on Claude/Kiro/Codex
  # burns 20-40k tokens before you type anything — the main cause of
  # context overruns. So we split servers into a small CORE set (loaded
  # globally) and HEAVY servers (opt-in per project via `project-mcp`).
  #
  # CORE (global): filesystem, git, memory, sequential-thinking, memelord.
  # HEAVY (opt-in): github, postgresq, context7, + the llms-docs wrappers.
  #
  # Pi already mitigates this via pi-mcp-adapter (one proxy tool, on-demand
  # discovery), so Pi keeps the full set; only the schema-eager agents
  # (claude/kiro/default/maki) get the core-only global config.
  ###
  heavyNames = [ "github" "postgresq" "context7" ]
    ++ lib.optionals cfg.servers.llms-docs.enable (lib.attrNames llmWrappers);
  coreMcpServers = removeAttrs mcpServers heavyNames;
  coreClaudeMcpServers = removeAttrs claudeUserMcpServers heavyNames;
  # Heavy servers, in the same JSON shape ~/.mcp.json uses — written into a
  # project's ./.mcp.json by the project-mcp helper.
  heavyMcpServers = lib.filterAttrs (n: _: builtins.elem n heavyNames) mcpServers;

  coreMcpJsonText = builtins.toJSON { mcpServers = coreMcpServers; };
  coreClaudeMcpJson = builtins.toJSON coreClaudeMcpServers;
  coreMakiMcpToml = builtins.concatStringsSep "\n"
    (lib.mapAttrsToList
      (name: server:
        if server ? url then "[mcp.${name}]\nurl = \"${server.url}\"\n"
        else "[mcp.${name}]\ncommand = [${
          builtins.concatStringsSep ", " (map (s: "\"${s}\"") ([ server.command ] ++ (server.args or [ ])))
        }]\n")
      coreMcpServers);

  # `project-mcp` helper: in a project's .envrc, run e.g.
  #   use project_mcp github postgresq
  # to add the heavy server(s) to ./.mcp.json (which Claude + Pi read from
  # the project dir, merging with the user-scoped core set). Non-destructive:
  # merges into an existing ./.mcp.json rather than clobbering it. With no
  # args it lists the available heavy servers.
  projectMcpHelper = pkgs.writeShellApplication {
    name = "project-mcp";
    runtimeInputs = [ pkgs.jq pkgs.coreutils ];
    text = ''
      avail=${lib.escapeShellArg (lib.concatStringsSep " " heavyNames)}
      defs=${lib.escapeShellArg (builtins.toJSON heavyMcpServers)}
      if [ "$#" -eq 0 ]; then
        echo "usage: project-mcp <server>...   (heavy/opt-in: $avail)" >&2
        echo "adds the named MCP server(s) to ./.mcp.json for this project" >&2
        exit 0
      fi
      # Build the requested subset from the definitions.
      want='{}'
      for s in "$@"; do
        case " $avail " in
          *" $s "*) want=$(printf '%s' "$want" | jq --argjson d "$defs" --arg k "$s" '. + {($k): $d[$k]}') ;;
          *) echo "project-mcp: unknown heavy server '$s' (have: $avail)" >&2 ;;
        esac
      done
      # Merge into ./.mcp.json (create if absent), preserving any existing
      # mcpServers entries.
      existing='{"mcpServers":{}}'
      [ -f .mcp.json ] && existing=$(cat .mcp.json)
      printf '%s' "$existing" | jq --argjson w "$want" '.mcpServers = ((.mcpServers // {}) + $w)' > .mcp.json
      echo "project-mcp: added [$*] to $(pwd)/.mcp.json" >&2
    '';
  };

  # kiro-cli execute_bash.allowedCommands (anchored ^...$ regex). Single
  # source of truth shared with maki (and mirroring Claude Code's
  # permissions.allow) lives in ./bash-allowlist.nix.
  kiroAllowedBashCommands = bashAllowlist.kiroRegex;

  packages = lib.optional cfg.servers.memelord.enable cfg.servers.memelord.pkg
    ++ lib.optional cfg.targets.claude pkgs.jq;
in
{
  options.programs.ai.mcps = {
    enable = mkEnableOption "MCP server module";

    targets = {
      default = mkOption {
        type = types.bool;
        default = true;
        description = "Enables the ~/.mcp.json output config file";
      };
      claude = mkOption {
        type = types.bool;
        default = true;
        description = "Injects MCP servers into ~/.claude.json (user-scoped) for Claude Code";
      };
      kiro = mkOption {
        type = types.bool;
        default = true;
        description = "Enables the ~/.kiro/settings/mcp.json output config file for Kiro CLI";
      };
      maki = mkOption {
        type = types.bool;
        default = true;
        description = "Enables the ~/.maki/mcp.toml output config file for Maki";
      };
      pi = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enables the ~/.config/mcp/mcp.json output config file for Pi.
          Pi's MCP support (npm:pi-mcp-adapter) reads the user-global
          standard MCP config from ~/.config/mcp/mcp.json (NOT ~/.mcp.json,
          which it never looks at), so the `default` target alone leaves
          Pi with zero servers.
        '';
      };
    };

    servers = {
      llms-docs = {
        enable = mkEnableOption "mcpdoc wrapping of various llms.txt site resources";
        sources = lib.mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              url = mkOption {
                type = types.str;
                description = "URL to the llms.txt resource";
              };
              title = mkOption {
                type = types.str;
                description = "Title for the documentation";
              };
            };
          });
          default = { };
          description = "Map of llms.txt sites. Keys are used for mcp.json keys.";
        };
      };

      github = {
        enable = mkEnableOption "github-mcp-server integration";
        pkg = mkOption {
          type = types.package;
          default = pkgs.github-mcp-server or (throw "github-mcp-server package not available");
          description = "The package to use for github-mcp-server";
        };
        tokenFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Optional path to a file containing a GitHub token (e.g. a sops-nix
            secret). Used before falling back to `gh auth token`, so headless
            hosts without an interactive `gh auth login` can still run the MCP.
          '';
        };
      };

      memelord = {
        enable = mkEnableOption "memelord MCP server integration";
        pkg = mkOption {
          type = types.package;
          description = "The memelord package";
        };
      };

      filesystem = {
        enable = mkEnableOption "filesystem MCP server integration";
        path = mkOption {
          type = types.str;
          default = config.home.homeDirectory;
          description = "Root path for filesystem server access";
        };
      };

      postgresq = {
        enable = mkEnableOption "Postgr.esq/l MCP server (PostgreSQL community archive)";
        url = mkOption {
          type = types.str;
          default = "https://pg.ddx.io/mcp/";
          description = "URL for the Postgr.esq/l MCP server (canonical hostname is pg.ddx.io as of 2026-05 rebrand; postgr.esq still 301-redirects)";
        };
      };

      server-memory = {
        enable = mkEnableOption "MCP server-memory (persistent knowledge graph)";
      };

      server-git = {
        enable = mkEnableOption "MCP server-git (local Git operations)";
      };

      context7 = {
        enable = mkEnableOption "Context7 (live version-aware library docs)";
      };

      sequential-thinking = {
        enable = mkEnableOption "Sequential thinking (structured multi-step reasoning)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # project-mcp helper for adding heavy MCP servers per project (used from
    # .envrc); core servers are loaded globally, heavy ones opt-in.
    home.packages = packages ++ [ projectMcpHelper ];

    home.file = lib.mkMerge [
      (lib.mkIf cfg.targets.default {
        # CORE servers only — heavy ones (github/postgresq/context7/llms-docs)
        # are opt-in per project via `project-mcp` to keep the session floor
        # small. (Pi reads the FULL set from ~/.config/mcp/mcp.json below;
        # pi-mcp-adapter loads it on demand without the schema cost.)
        ".mcp.json".text = coreMcpJsonText;
      })
      (lib.mkIf cfg.targets.kiro {
        ".kiro/settings/mcp.json".text = coreMcpJsonText;
        # Agent config: trust all safe tools, deny destructive ones via hooks
        ".kiro/agents/default.json".text = builtins.toJSON {
          "$schema" = "https://raw.githubusercontent.com/aws/amazon-q-developer-cli/refs/heads/main/schemas/agent-v1.json";
          name = "default";
          description = "Default agent with broad tool trust (safety enforced via hooks)";
          # kiro 2.x split the schema: `tools` ENABLES tools (without it the
          # agent gets a no-op \"dummy\" tool and can't run shell/anything);
          # `allowedTools` only marks which enabled tools are auto-approved
          # (no prompt). The old config put everything in allowedTools with
          # no `tools`, so kiro 2.2.0 enabled NOTHING. List the real built-in
          # tool names + all MCP servers here to enable them.
          tools = [
            "fs_read"
            "fs_write"
            "execute_bash"
            "use_aws"
            "knowledge"
            "thinking"
            "todo_list"
            # All MCP server tools (@server = include every tool it exposes)
            "@context7"
            "@filesystem"
            "@git"
            "@github"
            "@memelord"
            "@memory"
            "@postgresq"
            "@sequential-thinking"
            "@nix"
            "@rust"
            "@python"
            "@home-manager"
          ];
          allowedTools = [
            # auto-approved (no prompt) subset of the enabled tools above
            "fs_read"
            "fs_write"
            "execute_bash"
            "use_aws"
            "knowledge"
            "thinking"
            "todo_list"
            # All MCP server tools
            "@context7"
            "@filesystem"
            "@git"
            "@github"
            "@memelord"
            "@memory"
            "@postgresq"
            "@sequential-thinking"
            "@nix"
            "@rust"
            "@python"
            "@home-manager"
          ];
          toolsSettings = {
            execute_bash = {
              # autoAllowReadonly: kiro's built-in classifier auto-approves
              # ls/cat/grep/find/git status/etc. so common inspection commands
              # don't prompt. Mutating commands still require allowedCommands
              # match (or interactive y/n).
              autoAllowReadonly = true;
              allowedCommands = kiroAllowedBashCommands;
              # Regex denylist — commands matching ^...$ are BLOCKED outright.
              # Each entry kiro wraps with ^...$ implicitly. Bias toward broader
              # patterns than the user's exact phrasing because LLMs paraphrase.
              deniedCommands = [
                # Destructive recursive removal
                "rm\\s+(-[a-zA-Z]*[rRfF][a-zA-Z]*\\s+)+.*"
                "rm\\s+--recursive.*"
                # Force-push variants (--force, --force-with-lease, -f, -f=)
                "git\\s+push.*\\s--force(-with-lease)?(\\s.*)?"
                "git\\s+push.*\\s-f(\\s.*|=.*)?"
                # History rewrites on shared refs
                "git\\s+reset\\s+--hard.*"
                "git\\s+filter-(branch|repo).*"
                "git\\s+update-ref\\s+-d\\s+refs/heads/main.*"
                # Pipe-to-shell (curl|bash, wget|sh, etc.)
                ".*\\|\\s*(bash|sh|zsh|fish)(\\s.*)?"
                # mkfs / dd to block-device patterns
                "mkfs.*"
                "dd\\s+.*of=/dev/.*"
              ];
            };
            use_aws = {
              autoAllowReadonly = true;
            };
          };
          hooks = {
            preToolUse = [{
              # kiro 2.x's shell tool is named execute_bash (was "shell");
              # the matcher must use the current tool name or the rm -rf
              # guard never fires.
              matcher = "execute_bash";
              command = "CMD=$(cat | jq -r '.tool_input.command'); if echo \"$CMD\" | grep -qE 'rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f'; then echo 'BLOCKED: Use trash instead of rm -rf' >&2; exit 2; fi";
            }];
          };
        };
      })
      (lib.mkIf (cfg.targets.kiro && cfg.servers.memelord.enable) {
        ".kiro/settings/settings.json".text = builtins.toJSON {
          hooks = memelordHooks;
        };
      })
      (lib.mkIf cfg.targets.maki {
        # CORE only (maki loads schemas eagerly like claude/kiro).
        ".maki/mcp.toml".text = coreMakiMcpToml;
      })
      (lib.mkIf cfg.targets.pi {
        # Pi's pi-mcp-adapter reads the user-global standard MCP config here
        # and discovers servers ON DEMAND (one ~200-token proxy tool, not
        # all schemas), so Pi keeps the FULL set — no context penalty.
        # Same JSON shape as ~/.mcp.json; pi never reads ~/.mcp.json.
        ".config/mcp/mcp.json".text = mcpJsonText;
      })
    ];

    # Claude Code reads user-scoped MCP servers from ~/.claude.json (mcpServers key).
    # Since ~/.claude.json is a mutable state file, we merge via activation script.
    home.activation.claudeMcpServers = lib.mkIf cfg.targets.claude (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_JSON="${config.home.homeDirectory}/.claude.json"
        MCP_PAYLOAD='${coreClaudeMcpJson}'

        if [ -f "$CLAUDE_JSON" ]; then
          # Merge mcpServers into existing ~/.claude.json
          ${pkgs.jq}/bin/jq --argjson servers "$MCP_PAYLOAD" \
            '.mcpServers = $servers' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
            && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
        else
          # Create ~/.claude.json with just mcpServers
          echo "$MCP_PAYLOAD" | ${pkgs.jq}/bin/jq '{mcpServers: .}' > "$CLAUDE_JSON"
        fi

        # Update Claude Code settings model to opus-4-8 (latest Bedrock
        # inference profile as of 2026-05-29). Also writes
        # CLAUDE_THINKING_EFFORT=high into the env block so any tool
        # launched via Claude Code's spawn surface picks it up.
        # Also injects permissions.deny rules for destructive git/shell
        # ops (force-push, hard-reset, rm -rf, pipe-to-shell, mkfs/dd).
        CLAUDE_SETTINGS="${config.home.homeDirectory}/.claude/settings.json"
        if [ -f "$CLAUDE_SETTINGS" ]; then
          ${pkgs.jq}/bin/jq '
            .model = "us.anthropic.claude-opus-4-8"
            | .env.CLAUDE_THINKING_EFFORT = "high"
            | .env.ANTHROPIC_THINKING_EFFORT = "high"
            | .env.CLAUDE_CODE_ENABLE_TELEMETRY = "false"
            | .env.DISABLE_TELEMETRY = "true"
            | .env.DISABLE_ERROR_REPORTING = "true"
            | .env.DISABLE_BUG_COMMAND = "true"
            | .env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "true"
            | .permissions.deny = (
                (.permissions.deny // []) + [
                  "Bash(rm -rf *)",
                  "Bash(rm -fr *)",
                  "Bash(rm -Rf *)",
                  "Bash(rm --recursive *)",
                  "Bash(git push --force*)",
                  "Bash(git push --force-with-lease*)",
                  "Bash(git push -f *)",
                  "Bash(git push *-f *)",
                  "Bash(git push *--force*)",
                  "Bash(git reset --hard*)",
                  "Bash(git filter-branch*)",
                  "Bash(git filter-repo*)",
                  "Bash(curl * | bash*)",
                  "Bash(curl * | sh*)",
                  "Bash(wget * | bash*)",
                  "Bash(wget * | sh*)",
                  "Bash(mkfs *)",
                  "Bash(dd * of=/dev/*)"
                ] | unique
              )
          ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" \
            && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
        fi

        # Update kiro-cli's chat.defaultModel to opus 4.8 and force
        # telemetry off (kiro ships with telemetry ENABLED by default — it
        # phones home to Amazon unless telemetry.enabled is false). cli.json
        # is a mutable state file, so create it if missing and patch it
        # otherwise. kiro uses its own model namespace with a dot
        # (claude-opus-4.8) which maps internally to us.anthropic.claude-opus-4-8.
        KIRO_CLI="${config.home.homeDirectory}/.kiro/settings/cli.json"
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$KIRO_CLI")"
        if [ ! -f "$KIRO_CLI" ]; then
          echo '{}' > "$KIRO_CLI"
        fi
        ${pkgs.jq}/bin/jq '
          ."chat.defaultModel" = "claude-opus-4.8"
          | ."telemetry.enabled" = false
        ' "$KIRO_CLI" > "$KIRO_CLI.tmp" \
          && mv "$KIRO_CLI.tmp" "$KIRO_CLI"
      ''
    );
  };
}
