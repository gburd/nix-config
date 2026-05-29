{ config, pkgs, lib, ... }:
let
  cfg = config.programs.ai.mcps;
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.attrsets) optionalAttrs;

  ### GitHub MCP ###
  githubMcpServer = pkgs.writeShellScript "github-mcp-server" ''
    if ! command -v gh &> /dev/null; then
      echo "Error: github-cli not installed!" >&2
      exit 2
    fi

    GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)"
    if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
      echo "Error: github-cli is not authenticated!" >&2
      exit 3
    fi

    export GITHUB_PERSONAL_ACCESS_TOKEN

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

  # Maki uses a different TOML format: [mcp.name] with command=[] or url=""
  makiMcpToml =
    let
      renderServer = name: server:
        if server ? url then
          "[mcp.${name}]\nurl = \"${server.url}\"\n"
        else
          "[mcp.${name}]\ncommand = [${
            builtins.concatStringsSep ", "
              (map (s: "\"${s}\"") ([ server.command ] ++ (server.args or [])))
          }]\n";
    in
    builtins.concatStringsSep "\n"
      (lib.mapAttrsToList renderServer mcpServers);

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

  claudeUserMcpJson = builtins.toJSON claudeUserMcpServers;

  # Per-command allowlist for kiro-cli's execute_bash tool. Kiro evaluates each
  # entry as a regex anchored with ^...$. Mirrors the bash patterns in Claude
  # Code's permissions.allow (~/.claude/settings.json). Generated mechanically
  # from 332 Claude entries by collapsing each unique command head to a single
  # regex; sudo is intentionally excluded (always prompt for privilege
  # escalation). Combined with autoAllowReadonly=true (which catches ls/cat/
  # grep/find/etc. via kiro's built-in classifier), this brings kiro's
  # silent-trust coverage in line with Claude.
  kiroAllowedBashCommands = [
    "^7z(\\s.*)?$"
    "^TZ=\\S+(\\s.*)?$"
    "^\\[(\\s.*)?$"
    "^\\[\\[(\\s.*)?$"
    "^asdf(\\s.*)?$"
    "^avahi-browse(\\s.*)?$"
    "^aws(\\s.*)?$"
    "^az(\\s.*)?$"
    "^bc(\\s.*)?$"
    "^bunzip2(\\s.*)?$"
    "^bzip2(\\s.*)?$"
    "^cat(\\s.*)?$"
    "^claude(\\s.*)?$"
    "^column(\\s.*)?$"
    "^cp(\\s.*)?$"
    "^createdb(\\s.*)?$"
    "^crontab(\\s.*)?$"
    "^csplit(\\s.*)?$"
    "^date(\\s.*)?$"
    "^df(\\s.*)?$"
    "^direnv(\\s.*)?$"
    "^disown(\\s.*)?$"
    "^docker(\\s.*)?$"
    "^dropdb(\\s.*)?$"
    "^dstat(\\s.*)?$"
    "^du(\\s.*)?$"
    "^echo(\\s.*)?$"
    "^expr(\\s.*)?$"
    "^false(\\s.*)?$"
    "^file(\\s.*)?$"
    "^fold(\\s.*)?$"
    "^for(\\s.*)?$"
    "^free(\\s.*)?$"
    "^gcloud(\\s.*)?$"
    "^getfacl(\\s.*)?$"
    "^git(\\s.*)?$"
    "^grep(\\s.*)?$"
    "^gsutil(\\s.*)?$"
    "^gunzip(\\s.*)?$"
    "^gzip(\\s.*)?$"
    "^heroku(\\s.*)?$"
    "^http-server(\\s.*)?$"
    "^if(\\s.*)?$"
    "^iftop(\\s.*)?$"
    "^iostat(\\s.*)?$"
    "^iotop(\\s.*)?$"
    "^jest(\\s.*)?$"
    "^join(\\s.*)?$"
    "^journalctl(\\s.*)?$"
    "^less(\\s.*)?$"
    "^lsof(\\s.*)?$"
    "^make(\\s.*)?$"
    "^md5sum(\\s.*)?$"
    "^mdns-scan(\\s.*)?$"
    "^mongo(\\s.*)?$"
    "^mongod(\\s.*)?$"
    "^mongodump(\\s.*)?$"
    "^mongoexport(\\s.*)?$"
    "^mongoimport(\\s.*)?$"
    "^mongorestore(\\s.*)?$"
    "^mongosh(\\s.*)?$"
    "^mysql(\\s.*)?$"
    "^mysqladmin(\\s.*)?$"
    "^mysqldump(\\s.*)?$"
    "^mysqlimport(\\s.*)?$"
    "^nano(\\s.*)?$"
    "^nc(\\s.*)?$"
    "^nethogs(\\s.*)?$"
    "^netlify(\\s.*)?$"
    "^netstat(\\s.*)?$"
    "^nohup(\\s.*)?$"
    "^npm(\\s.*)?$"
    "^npx(\\s.*)?$"
    "^ntl(\\s.*)?$"
    "^nvm(\\s.*)?$"
    "^open(\\s.*)?$"
    "^openssl(\\s.*)?$"
    "^paste(\\s.*)?$"
    "^pg_dump(\\s.*)?$"
    "^pg_dumpall(\\s.*)?$"
    "^pg_restore(\\s.*)?$"
    "^pidof(\\s.*)?$"
    "^pip(\\s.*)?$"
    "^pip3(\\s.*)?$"
    "^pnpm(\\s.*)?$"
    "^printf(\\s.*)?$"
    "^psql(\\s.*)?$"
    "^pstree(\\s.*)?$"
    "^pwgen(\\s.*)?$"
    "^pyenv(\\s.*)?$"
    "^python(\\s.*)?$"
    "^python3(\\s.*)?$"
    "^rbenv(\\s.*)?$"
    "^redis-cli(\\s.*)?$"
    "^rvm(\\s.*)?$"
    "^screen(\\s.*)?$"
    "^seq(\\s.*)?$"
    "^sha1sum(\\s.*)?$"
    "^sha256sum(\\s.*)?$"
    "^sha512sum(\\s.*)?$"
    "^shasum(\\s.*)?$"
    "^shuf(\\s.*)?$"
    "^split(\\s.*)?$"
    "^sqlite3(\\s.*)?$"
    "^ss(\\s.*)?$"
    "^stat(\\s.*)?$"
    "^strace(\\s.*)?$"
    "^tail(\\s.*)?$"
    "^tar(\\s.*)?$"
    "^tee(\\s.*)?$"
    "^test(\\s.*)?$"
    "^time(\\s.*)?$"
    "^timedatectl(\\s.*)?$"
    "^timeout(\\s.*)?$"
    "^tmux(\\s.*)?$"
    "^tr(\\s.*)?$"
    "^true(\\s.*)?$"
    "^unxz(\\s.*)?$"
    "^unzip(\\s.*)?$"
    "^uuidgen(\\s.*)?$"
    "^vc(\\s.*)?$"
    "^vercel(\\s.*)?$"
    "^view(\\s.*)?$"
    "^vim(\\s.*)?$"
    "^vmstat(\\s.*)?$"
    "^watch(\\s.*)?$"
    "^while(\\s.*)?$"
    "^xargs(\\s.*)?$"
    "^xz(\\s.*)?$"
    "^yarn(\\s.*)?$"
    "^yes(\\s.*)?$"
    "^zip(\\s.*)?$"
  ];

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
    home.packages = packages;

    home.file = lib.mkMerge [
      (lib.mkIf cfg.targets.default {
        ".mcp.json".text = mcpJsonText;
      })
      (lib.mkIf cfg.targets.kiro {
        ".kiro/settings/mcp.json".text = mcpJsonText;
        # Agent config: trust all safe tools, deny destructive ones via hooks
        ".kiro/agents/default.json".text = builtins.toJSON {
          name = "default";
          description = "Default agent with broad tool trust (safety enforced via hooks)";
          allowedTools = [
            # All built-in tools
            "read"
            "write"
            "shell"
            "glob"
            "grep"
            "code"
            "web_search"
            "web_fetch"
            "knowledge"
            "subagent"
            "introspect"
            "todo_list"
            "use_aws"
            # Aliases
            "fs_read"
            "fs_write"
            "execute_bash"
            "fs_search"
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
              matcher = "shell";
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
        ".maki/mcp.toml".text = makiMcpToml;
      })
    ];

    # Claude Code reads user-scoped MCP servers from ~/.claude.json (mcpServers key).
    # Since ~/.claude.json is a mutable state file, we merge via activation script.
    home.activation.claudeMcpServers = lib.mkIf cfg.targets.claude (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_JSON="${config.home.homeDirectory}/.claude.json"
        MCP_PAYLOAD='${claudeUserMcpJson}'

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
