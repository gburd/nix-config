{ config, pkgs, lib, ... }:
let
  cfg = config.programs.ai.mcps;
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.attrsets) optionalAttrs;

  ### GitHub MCP ###
  # The githubMcpServer package wrapper relies on auth context provided
  # by the github CLI, accessed from the user PATH. This ensures a simple
  # process to authenticate to the MCP server when necessary.
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
  # Provides utility wrapping of llms.txt resources online behind a
  # local Python server to fulfill an MCP server with more interactive
  # documentation access targeted at LLM consumption.
  mcpdoc-wrapper-of = name: projectUrlMap:
    let
      urlArgs = builtins.concatStringsSep " " (
        builtins.map (name: ''"${name}:${projectUrlMap.${name}}"'')
          (builtins.attrNames projectUrlMap)
      );
    in
    pkgs.writeScript "mcpdoc-wrapper-${name}" ''
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
  });

  packages = [ ]
    ++ (lib.optional cfg.servers.memelord.enable cfg.servers.memelord.pkg);
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
        description = "Enables the ~/.config/claude-code/mcp.json output config file for Claude Code";
      };
      kiro = mkOption {
        type = types.bool;
        default = true;
        description = "Enables the ~/.kiro/settings/mcp.json output config file for Kiro CLI";
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
          example = {
            nix = {
              url = "https://nixos.org/llms.txt";
              title = "NixOS Documentation";
            };
          };
        };
      };

      github = {
        enable = mkEnableOption "github-mcp-server integration";
        pkg = mkOption {
          type = types.package;
          default = pkgs.github-mcp-server or (throw "github-mcp-server package not available");
          description = "The package to use for github-mcp-server. Will invoke \$pkg/bin/github-mcp-server";
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
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = packages;

    home.file = lib.mkMerge [
      (lib.mkIf cfg.targets.default {
        ".mcp.json".text = mcpJsonText;
      })
      (lib.mkIf cfg.targets.claude {
        ".config/claude-code/mcp.json".text = mcpJsonText;
      })
      (lib.mkIf cfg.targets.kiro {
        ".kiro/settings/mcp.json".text = mcpJsonText;
      })
      (lib.mkIf (cfg.targets.kiro && cfg.servers.memelord.enable) {
        ".kiro/settings/settings.json".text = builtins.toJSON {
          hooks = memelordHooks;
        };
      })
    ];
  };
}
