{ config, lib, ... }:
let
  cfg = config.programs.ai.steering;
  inherit (lib) mkEnableOption mkOption types;

  steeringFiles = {
    "coding-standards.md" = ./files/steering/coding-standards.md;
    "rust-conventions.md" = ./files/steering/rust-conventions.md;
    "workflow.md" = ./files/steering/workflow.md;
    "tools.md" = ./files/steering/tools.md;
    "aws-builder.md" = ./files/steering/aws-builder.md;
    "mcp-config.md" = ./files/steering/mcp-config.md;
    "voice.md" = ./files/steering/voice.md;
  };

  # Concatenated steering for agents that use a single instructions file
  allSteeringContent = builtins.concatStringsSep "\n\n"
    (map builtins.readFile (builtins.attrValues steeringFiles));
in
{
  options.programs.ai.steering = {
    enable = mkEnableOption "Deploy shared steering/instruction files for AI agents";

    targets = {
      kiro = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy to ~/.kiro/steering/";
      };
      claude = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy full steering to ~/.claude/CLAUDE.md";
      };
      pi = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy all steering files to ~/.pi/agent/prompts/";
      };
      maki = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy consolidated instructions to ~/.config/maki/instructions.md";
      };
      codex = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy consolidated instructions to ~/.codex/instructions.md";
      };
    };

    extraFiles = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = "Additional steering files to deploy (name -> path)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mkMerge [
      # Kiro steering files (individual files in ~/.kiro/steering/)
      (lib.mkIf cfg.targets.kiro (
        lib.mapAttrs'
          (name: path: lib.nameValuePair ".kiro/steering/${name}" { source = path; })
          (steeringFiles // cfg.extraFiles)
      ))

      # Claude global CLAUDE.md — full steering content
      (lib.mkIf cfg.targets.claude {
        ".claude/CLAUDE.md".text = allSteeringContent + ''

          See AGENTS.md for project-specific instructions.
          These standards apply equally in Claude Code, Kiro CLI, Pi, Maki, and Codex.
        '';
      })

      # Pi prompts — all steering files as individual prompts
      (lib.mkIf cfg.targets.pi (
        lib.mapAttrs'
          (name: path: lib.nameValuePair ".pi/agent/prompts/${name}" { source = path; })
          (steeringFiles // cfg.extraFiles)
      ))

      # Maki global instructions (all steering concatenated)
      (lib.mkIf cfg.targets.maki {
        ".config/maki/instructions.md".text = allSteeringContent;
      })

      # Codex instructions (all steering concatenated)
      (lib.mkIf cfg.targets.codex {
        ".codex/instructions.md".text = allSteeringContent;
      })
    ];
  };
}
